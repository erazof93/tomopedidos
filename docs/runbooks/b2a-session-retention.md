# B2-A E — retención y cleanup de sesiones

Estado: **implementado en archivos y revisado estáticamente; no aplicado ni
verificado en PostgreSQL**. No ejecutar SQL/Goose/Docker/cleanup con la autorización
actual. Aplicación, provisión, fixtures y job requieren permisos separados y target
aislado. A–D y B1 se conservan; no se habilita mantenimiento en runtime auth/tenant.

## Política implementada y consulta

Terminalidad conocida = `LEAST(idle_expires_at, absolute_expires_at, revoked_at,
expired_at)`. PostgreSQL ignora NULL en LEAST; idle/absoluto son NOT NULL y finitos.
La menor fecha conserva el vencimiento natural anterior a la detección tardía.
Se elimina solo si terminalidad <= reloj PostgreSQL posterior a locks menos
2 592 000 segundos: 30 días de duración transcurrida, independiente de timezone/DST.
Igualdad habilita cleanup. created_at no es ancla; no se inventa una fecha por epoch.
Una sesión invalidada solo por epoch conserva el mismo vencimiento natural+30d.
No existe DELETE de identidades, credenciales, epochs, auditoría ni claves CSRF.

[Función administrativa](../../tomopedidos-api/db/administration/retention/b2a-session-cleanup-v1.sql):
`identity.cleanup_sessions(integer DEFAULT 100)` devuelve examined/deleted/skipped
y checked_at, sin IDs, digests, PHC, salts o claves. Límite estricto 1–100; NULL,
0, negativos y >100 producen 22023. examined cuenta candidatos de discovery;
skipped incluye desapariciones/renovaciones previas al lock. No prueba que el backlog
esté vacío: nuevos candidatos pueden aparecer después de discovery. Cada llamada
requiere transacción READ COMMITTED nueva y corta. No retries ni loops en la función.

Discovery usa la expresión terminal exacta, orden fecha + UUID y LIMIT. El
[índice Goose 00004](../../tomopedidos-api/db/migrations/00004_session_cleanup_index.sql)
es btree sobre esa misma expresión y session_id, sin reloj, intervalos, helpers ni
predicado dinámico. Se prepara Up/Down transaccional, owner tp_owner. Falta confirmar
EXPLAIN, selectividad, coste de actualizar índice con cada actividad, buffers,
WAL y contención; no se afirma plan medido ni que el optimizador siempre lo use.

## Orden global de locks y revalidación

La función materializa como máximo 100 UUID de candidatos sin locks. Después
adquiere todas las identidades SHARE en UUID ascendente, todas las audiencias
SHARE en (identity_id, audience COLLATE C), y sesiones UPDATE en UUID ascendente.
No adquiere nuevos parent locks después de bloquear una sesión, no upgrades,
SKIP LOCKED ni locks tomados en orden de fecha mutable. Dos cleanups concurrentes
usan el mismo orden estable. C opera una sesión/scope por transacción; cualquier
flujo futuro con múltiples identidades debe conservar este protocolo global.

Relee sesiones después de esperas, comprueba evidencia de parents bloqueados y
captura clock_timestamp por fila. Recalcula terminalidad y cutoff antes de DELETE,
que repite el predicado. Una renovación legítima anterior al lock se observa; una
sesión vigente no puede satisfacer natural+30d. Después del lock, las operaciones
C esperan y revalidan; no recuperan una fila ya eliminada. Revocación por epoch
se coordina por parent locks pero no adelanta la retención ni obliga a recorrer epochs.

Si el reloj retrocede frente a observaciones anteriores del lote o una fecha de
creación/actividad/marca está en el futuro, 22008 aborta todo el lote, incluidas
eliminaciones previas de esa llamada. No es un reloj monotónico del servidor.
Deadlock, lock timeout, statement timeout, cancelación y FK nueva no se capturan
como éxito. La marca GUC local evita repetir accidentalmente cleanup en una tx;
el caller puede resetearla, por lo que no constituye frontera de autoridad: el job
confiable debe ejecutar una sola operación/tx y respetar el orden de locks.

Una sesión que ya venció hace 30 días no puede renovar legítimamente con reloj
estable; la carrera de candidato obsoleto requiere renovación previa compatible
o discontinuidad temporal. No inventar un test de renovación que viole absoluto
inmutable. Se prueba renovación vigente concurrente, detección tardía del vencimiento,
y fallo cerrado de anomalías temporales. Saltos reales del reloj requieren VM/reloj
controlado autorizado; no cambiar reloj del host ni añadir hooks al SQL productivo.

## Actor propuesto y privilegios

Nombres materializados como propuesta de E; todavía no provisionados/aprobados para
ejecución. Dos roles nuevos independientes: tomopedidos_cleanup_executor NOLOGIN,
owner solo de la función, y tomopedidos_session_maintenance LOGIN/PASSWORD NULL,
caller solo tras habilitación separada. Ambos NOINHERIT, sin atributos elevados,
memberships, defaults ni settings. Esta separación usa un ejecutor propio; no reutiliza
los ejecutores auth normales/privilegiados de D ni amplía B1.

| Actor | Derechos previstos |
| --- | --- |
| Cleanup executor | USAGE identity; SELECT(id)/UPDATE(id) en identidades; SELECT(identity_id,audience)/UPDATE(audience) en audiencias; SELECT de nueve metadatos de sesión, UPDATE(session_id) solo para locks y DELETE de sesiones |
| Maintenance caller | CONNECT local, USAGE identity, EXECUTE cleanup_sessions(integer); sin tabla/columna/epoch/secretos/DDL |
| Auth, tenant, PUBLIC, migrator | Sin EXECUTE cleanup, sin nuevos derechos ni memberships |

Los UPDATE de keys habilitan locks; B guards impiden rekeying. La función no ejecuta
UPDATE. DELETE del ejecutor permite borrar cualquier sesión si un administrador
eludiera la función mediante SET ROLE; NOLOGIN + ausencia de memberships + caller
solo EXECUTE constituyen la frontera. Superusuario sigue siendo actor confiable.
Un compromiso del mismo proceso que custodie credenciales de mantenimiento y auth
puede saltar separación de pools: ejecutar job aislado con secreto privado propio.
LOGIN con PASSWORD NULL no configura ni certifica HBA/TLS/authentication: revisar
trust/cert/peer y privilegios PUBLIC en otras bases antes de provisionar roles cluster.

## Aplicación futura y Up/Down

1. Autorizar target desechable inequívoco, host/volumen, PG18/base/usuario y operaciones
   concretas. Verificar todos los hashes del manifiesto E y dependencias incluidas;
   no asumir base correcta por nombre. A–D aplicadas/certificadas, D enabled con
   ownership, guards, constraints y ACL reales. No repetir bootstrap B1.
2. Aplicar 00004 Up por Goose conforme B1, sin instalar funciones definidoras ni roles
   por migrator. Medir plan/coste cuando esté autorizado.
3. Aplicar b2a-cleanup-role-provision-v1.sql por administrador, tras aprobar los dos
   actores. Exige roles ausentes; no otorga CONNECT/EXECUTE ni instala credenciales.
4. Aplicar b2a-session-cleanup-v1.sql por administrador: initial-only, funciones
   inexistentes, PUBLIC revocado en misma transacción, owner mínimo; permisos del
   ejecutor y aserciones de fuente, firma, default100, índice y matriz efectiva.
   Estado dormant, caller aún desconectado. No CREATE OR REPLACE ni drift repair.
5. Verificar lectura nueva y caminos funcionales bajo owner mínimo en fixtures
   aislados autorizados; pruebas de permisos/pg_temp/search_path y compile PLpgSQL.
   Después autorizar enable separado. b2a-cleanup-enable-v1.sql compara dormant
   y enabled. Las fixtures 050/051 y .spec requieren E enabled en base desechable;
   habilitación para pruebas no autoriza job real ni acceso a base existente.
6. Tras aprobar pruebas y credenciales privadas, autorizar un batch real concreto
   o política operativa explícita. b2a-cleanup-batch.sql requiere login real maintenance,
   fija timeouts candidatos, una llamada, COMMIT y solo entonces imprime counts.
   Job externo con deadline total candidato 3s, sin retry automático y commit/lote.
   El lote100 y timeouts no son resultados medidos/certificados para producción.

Reversión administrativa explícita: detener job y drenar sesiones; ejecutar disable
enabled→dormant y después b2a-session-cleanup-down-v1.sql. Retira solo función y
grants E del ejecutor, conserva roles/A–D/B1. Luego 00004 Down separado. No CASCADE,
DROP OWNED, REASSIGN OWNED, borrado automático de roles ni modificación de datos
para corregir una prueba. Quitar CONNECT/EXECUTE no cancela llamadas activas.
Reversión de esquema/grants **no restaura sesiones borradas tras COMMIT**; recuperación
de datos requiere backup/PITR autorizado y revisión propia, nunca recrear tokens o
sesiones válidas artificialmente. Error precommit: rollback/detener, no continuar.

Commit ambiguo: no afirmar counts/éxito ni repetir cleanup. Nueva conexión autorizada
verifica estado de función/roles/grants en instalación y filas fixture esperadas
en tests. En job real, sin ledger por lote ni IDs retornados no se puede atribuir
exactamente cuántas filas borró ese commit frente a otros workers: conservar outcome
unknown, pausar scheduler y revisar evidencia administrativa/backups antes de seguir.
La idempotencia de borrar filas ya ausentes no autoriza retry: otra llamada podría
borrar candidatos nuevos. No registrar digests/PHC/bind parameters/secretos en evidencia.

## Pruebas preparadas, ninguna ejecutada

[050](../../tomopedidos-api/db/verification/050_b2a_retention_concurrency.sql): ocho
fixtures (natural vieja, reciente, vigente, epoch-only vigente/vieja, detección tardía,
revocación anterior y created_at no ancla), límite1, tamaños inválidos, segunda llamada,
igualdad/microsegundo anterior a 30d y rollback que restaura filas. Transacción final
ROLLBACK. Requiere sesiones vacías y no reutilizar UUID existentes.

[051](../../tomopedidos-api/db/verification/051_b2a_cleanup_failures.sql): auth/tenant
sin EXECUTE, marca futura/clock anomaly tras primera eliminación con rollback atómico,
REPEATABLE READ rechazado antes de tocar filas. SET ROLE por bootstrap prueba permisos
efectivos, no autenticación ni SET ROLE desde login; esos negativos reales siguen
requisito operativo D/E. Fixtures y pruebas terminan ROLLBACK.

[isolation spec](../../tomopedidos-api/db/verification/isolation/b2a_cleanup.spec): doce
permutaciones con conexiones independientes: cleanup antes/después de validate/expiry,
actividad/logout vigente, epoch global/audiencia en ambos órdenes, dos workers y rollback.
Assertions de supervivencia/parents y conteos. SET ROLE privilegiado es fixture exclusiva,
no caller público para scopes C. Setup/teardown COMMIT datos sintéticos: requieren DB
totalmente desechable. Formato nativo PostgreSQL isolationtester; herramienta no instalada
ni invocada y expected output debe capturarse/revisarse al autorizar, no inventarse ahora.

Escenarios adicionales reproducibles, pendientes de harness externo/autorización:

| Caso | Barrera/inyección y aceptación |
| --- | --- |
| Lock timeout | Conexión A mantiene Identity UPDATE de fixture; B invoca batch con lock_timeout 50ms. Esperar 55P03, rollback B, liberar A; nueva conexión confirma ninguna eliminación y locks liberados |
| Cancelación / statement timeout | Mantener bloqueo como arriba; cancelar únicamente backend B identificado en DB aislada, o statement_timeout menor que lock_timeout. Esperar 57014; rollback/descartar B y verificar filas/locks |
| Commit ambiguo, servidor rollback | Invocar batch en conexión B, cortar cliente antes de COMMIT; conexión nueva debe ver filas originales, scheduler sin retry |
| Commit ambiguo, servidor commit | Enviar COMMIT y perder respuesta con proxy/harness aislado; nueva conexión debe ver ausencia de fixtures esperada. Resultado original unknown, sin counts falsos ni segundo lote |
| Dos workers/múltiples parents | Extender fixtures a varias identidades/audiencias con fechas inversas a UUID. Solapamiento controlado; comprobar fases globales, <=100 candidatos por worker, sin double-delete/deadlock esperado ni borrado de vigente |
| Grants/search_path | Login real maintenance sin DML/SET ROLE, auth/tenant sin EXECUTE, PUBLIC ACL0; pg_temp hostil en fixture admin no cambia referencias calificadas ni source hash |
| Regresión reloj durante espera | VM/reloj controlado únicamente tras autorización; rollback completo o preservación del candidato renovado, sin epoch timestamp inventado |

No se incluye desconexión/proxy/pg_cancel_backend automático: identificar backend/host y
autorizar inyección primero. Medir p50/p95, buffers/locks/WAL, duración y backlog con datos
sintéticos; decidir batch/índice/deadlines según evidencia, sin ampliar alcance a F.

Fuentes primarias revisadas: [SELECT/locks PostgreSQL 18](https://www.postgresql.org/docs/18/sql-select.html),
[índices de expresión](https://www.postgresql.org/docs/18/indexes-expressional.html),
[LEAST y NULL](https://www.postgresql.org/docs/18/functions-conditional.html).
