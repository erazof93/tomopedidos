# B2-A C — ciclo de vida de funciones administrativas v1

Estado: **artefactos escritos y revisión estática; no aplicados ni verificados en PostgreSQL**.
Autorización actual: escribir C. No autoriza provisión, Goose, SQL, pruebas, grants
efectivos o B2-B. D01–D10 permanecen aprobadas sin modificaciones.

Paquete: [SQL v1](../../tomopedidos-api/db/administration/b2a-auth-functions-v1.sql).
Inventario/ACL: [manifiesto](../../tomopedidos-api/db/administration/manifests/b2a-auth-v1.yaml).
Base: [especificación B2-A](../architecture/b2-a-specification.md).

## Separación de artefactos y actores

Goose instala exclusivamente A/B (00001–00003). C no está en db/migrations,
no tiene directivas Goose y no modifica B1. La provisión de roles, permisos de
tablas/columnas y habilitación de callers pertenecen a D y requieren autorizaciones
separadas. No se habilita administrador de identidades ni mantenimiento.

Los nombres materializados para los ejecutores son tomopedidos_auth_executor y
tomopedidos_auth_revoke_executor: NOLOGIN, NOINHERIT, sin atributos elevados,
memberships ni CREATE en identity. No se crean por C. Un administrador local
superusuario explícitamente autorizado hace la instalación y futuras actualizaciones;
no se amplía migrator ni se usa tp_owner como owner de estas funciones.

El instalador fija el destino tomopedidos_local/PostgreSQL 18 y session_user/current_user
tomopedidos_bootstrap. Eso no demuestra host/contenedor/volumen: el operador debe
verificar el destino antes de cualquier aplicación autorizada. Para pruebas desechables
usar instancia aislada con esa base/roles; no reutilizar la base local existente por
inferencia ni cambiar el guard de destino improvisadamente.

## Inventario de firmas

Todas son identity.*, PL/pgSQL, VOLATILE, PARALLEL UNSAFE, SECURITY DEFINER,
search_path fijo pg_catalog, pg_temp; no SQL dinámico. Firmas/retornos completos
y nombres de argumentos están en el manifiesto.

| Firma | Owner | Caller después de D |
| --- | --- | --- |
| `identity.lookup_credential(text, text)` | tomopedidos_auth_executor | auth, solo tras grants y pruebas |
| `identity.issue_session(uuid, bigint, bigint, bigint, text, uuid, bytea, text, bytea)` | tomopedidos_auth_executor | auth, solo tras grants y pruebas |
| `identity.validate_session(bytea, text)` | tomopedidos_auth_executor | auth, solo tras grants y pruebas |
| `identity.record_activity(bytea, text)` | tomopedidos_auth_executor | auth, solo tras grants y pruebas |
| `identity.revoke_session(bytea, text)` | tomopedidos_auth_executor | auth, solo tras grants y pruebas |
| `identity.mark_expired(bytea, text)` | tomopedidos_auth_executor | auth, solo tras grants y pruebas |
| `identity.revoke_audience(bytea, text)` | tomopedidos_auth_revoke_executor | Ninguno operativo en B2 |
| `identity.revoke_global(bytea, text)` | tomopedidos_auth_revoke_executor | Ninguno operativo en B2 |
| `identity.rehash_conditional(uuid, bigint, text, text)` | tomopedidos_auth_executor | auth, solo tras grants y pruebas |

Inmediatamente después de C: solo EXECUTE del owner en ACL, además de las facultades
administrativas implícitas del superusuario. NOLOGIN no impide por sí solo SET ROLE:
el preflight rechaza memberships entrantes/salientes de los tres roles C.
Ningún caller obtiene EXECUTE mediante este paquete. No hay helpers definer compartidos
que permitan llegar indirectamente a una función privilegiada.

## Contratos de llamada y resultados

- LookupCredential devuelve cero/una fila con PHC, revisión y epochs en una única
  lectura consistente, para identidad activa/verificada con credencial y ambas filas
  de audiencia. No autoriza login. PHC y evidencia solo circulan internamente.
- IssueSession acepta identidad, revisión/epochs esperados, audiencia, session_id,
  digest y representación CSRF. Verifica estado/revisión/epochs/credencial bajo locks.
  Solo emite admin/password; platform devuelve invalid. El token, UUID/salt y digest
  se generan en Go antes de iniciar la transacción. No se acepta token bruto ni clave CSRF.
- ValidateSession, RecordActivity, RevokeSession y MarkExpired reciben digest/audiencia;
  discovery no autoriza. Devuelven una fila con result y metadatos tipados. En denegación
  los metadatos permanecen NULL. Resultados positivos respectivos: valid,
  activity_recorded, revoked y not_expired. expired persiste expired_at cuando detecta
  vencimiento natural; invalid no prueba la causa, clock_anomaly falla cerrado.
- RevokeSession solo opera sobre la sesión vigente identificada por digest/audiencia.
  La posesión/autoridad y CSRF los valida Go confiable antes de invocarla. Conocer digest
  no autoriza. Repetir tras revocación devuelve invalid sin cambiar la marca:
  idempotencia del estado, sin prometer nuevamente una revocación exitosa.
- MarkExpired no renueva actividad. Igualdad con idle/absoluto expira. Los resultados
  expired requieren commit de la marca; hacer rollback impediría su persistencia.
- RevokeAudience/Global derivan identidad de la sesión validada, no de un ID arbitrario.
  Devuelven audience_revoked/global_revoked y epochs actuales incrementados; no alteran
  snapshots. No habilitar callers en B2: SQL no prueba autenticación reciente/MFA,
  autoridad operadora ni autorización de revocación privilegiada.
- RehashConditional requiere revisión y PHC anterior iguales bajo Identity X y
  credencial X. Devuelve rehashed/revisión nueva; unchanged si PHC idéntico;
  not_applied si cambió la evidencia/estado o no existe fila; clock_anomaly deniega.
  No crea credenciales ni cambia epoch. Equivalencia y no degradación las prueba Go.
  Es operación separada; nunca mantener locks durante Argon2id.
- Los contadores agotan con SQLSTATE 22003; no wrap/reset/éxito. Conflicto de emisión
  genera 23505; rechazo estático de emisión/rehash genera 23514 con mensaje genérico.
  No capturar/reintentar deadlock, cancelación o timeout como éxito.

No exposición HTTP, autorización tenant, MFA, verificación de correo, administración
de identidades, listado administrativo, KeyReferences ni cleanup se implementan en C.
Los índices B anticipan esas consultas documentadas; no obligan a habilitarlas.

## Bloqueos, tiempo y commit

Una sola operación con locks por transacción READ COMMITTED, corta; no combinar
varias sesiones/scopes en orden arbitrario. PostgreSQL retiene locks hasta finalizar
la transacción, no hasta retornar la función. El caller futuro debe respetarlo.

| Operación | Locks en orden |
| --- | --- |
| Issue | Identity SHARE → audiencia SHARE → INSERT sesión |
| Validate/activity/logout/expiry | discovery sin lock → Identity SHARE → audiencia SHARE → sesión UPDATE |
| RevokeAudience | discovery → Identity SHARE → audiencia UPDATE → sesión UPDATE |
| RevokeGlobal | discovery → Identity UPDATE → audiencia SHARE → sesión UPDATE |
| Rehash | Identity UPDATE → credencial UPDATE |

Sin upgrades. Se captura clock_timestamp después de los locks necesarios, se rechaza
tiempo anterior a creación/última actividad y se revalidan estado/snapshots/deadlines.
No se inventa fecha de invalidación por epoch. D permite UPDATE(expired_at) al ejecutor
privilegiado para locks de sesión y persistencia de expiración, sin actividad/logout.

El punto de autorización es la revalidación final bajo estos locks. El resultado no
cancela operaciones ya autorizadas. La futura API solo comunica éxito/entrega token
tras commit confirmado. En expired también confirma commit antes de comunicar la
detección persistida. Rollback o commit ambiguo: sin secreto/éxito/retry ciego.

El paquete administrativo usa candidatos lock_timeout 1s, statement_timeout 2s e
idle-in-transaction 1s, locales a su transacción; no configura pools ni sesiones futuras.
B2-B deberá fijar límites locales y deadline total candidato 3s (pool 500ms); no hay
mediciones ni parámetros de producción certificados. No Argon2id, negocio/red/SSE
dentro de transacciones con locks.

## Instalación inicial — solo tras autorización separada

1. Revisar paquete/manifiesto y hashes A/B/C; identificar host/instancia/base/usuario.
   Confirmar columnas/constraints/guards/owners/ACL reales contra A/B, no solo nombres.
   Asegurar cliente con parada ante errores y sin auto-retry, parámetros/resultados
   sensibles excluidos de logs/trazas y capturas. Revisar también logs PostgreSQL:
   en errores pueden registrar statements/bind parameters; mensajes genéricos no
   sustituyen esa política. No mostrar PHC/digests en evidencia.
2. Provisionar por D los roles sin memberships/CREATE/atributos elevados. Es una
   operación independiente autorizada, con credenciales privadas para auth runtime.
   No utilizar owner/migrator/bootstrap como credencial de API.
3. Ejecutar C por administrador autorizado en una sola transacción. Preflight valida
   destino/roles/owners/guards y rechaza cualquier nombre ya existente u overload.
   Los checks de nombres no sustituyen los hashes/metadata completos del paso 1.
4. Crear funciones, retirar EXECUTE de PUBLIC/auth/tenant/migrator por firma y asignar
   el owner NOLOGIN mínimo. Todo es invisible externamente hasta commit; nunca habilitar
   una función todavía owned por el administrador o tp_owner al runtime.
5. Las aserciones previas al commit comprueban fuente SHA-256 LF normalizada,
   owner, definer/lenguaje/volatilidad/parallel/search_path y ACL owner-only. Una
   ACL heredada para otro destinatario aborta; no se corrige automáticamente.
6. Verificar por lectura nueva postcommit las mismas firmas/fuentes/owners/ACL.
   C no concede aún permisos de tablas ni EXECUTE a callers. D deriva/aplica los
   permisos del manifiesto, verifica negativos y después habilita SOLO las siete
   firmas normales por firma exacta, sin GRANT OPTION.
7. Registrar target/hashes/resultado y código reales. No afirmar PASS funcional
   hasta pruebas autorizadas con roles efectivos distintos del superusuario.

## Actualización futura y recuperación

v1 es instalador inicial: no reejecutarlo para actualizar o solucionar una transición.

Preparar un paquete v2 independiente y revisado con firma/retorno/properties y hashes
de fuente anterior/nueva, owner/ACL anterior y esperado, dependencias y rollback.
Fuente hash: SHA-256 de prosrc UTF-8, CRLF convertido a LF, conservando LF inicial/final.
El hash de archivo es de sus bytes exactos, distinto del hash de fuente de cada función.

El administrador autorizado verifica drift antes de reemplazar: firmas, fuente/hash,
owner, search_path, ACL/callers exactos y estado de roles/tablas. Si no coincide,
abort/detener, sin sobrescribir deriva. Dentro de una única transacción usa
CREATE OR REPLACE para firma/retorno compatibles, indicando explícitamente todas
las propiedades de seguridad; preserva owners mínimos y reconstruye/valida ACL
por firma. No requiere memberships nuevas del migrator ni cambios temporales de owner.

Cambio incompatible: firma versionada nueva y transición revisada con drenaje de
callers/conexiones si procede; no DROP CASCADE. Quitar grants no cancela invocaciones
ya comenzadas. No habilitar la nueva firma hasta owners/permisos/aserciones correctos.
Verificar fuente nueva/ACL/owners antes de commit y por lectura nueva después.

Error precommit: rollback y detener; cerrar/descartar conexión si no puede confirmarse
su estado. No corregir permisos ni reintentar automáticamente. Commit ambiguo:
no afirmar aplicación; comparar por nueva conexión fuente/owner/ACL con manifiestos
anterior/nuevo antes de decidir otra acción. Tras commit confirmado, reversión mediante
otro paquete autorizado que verifica versión nueva y reinstala la anterior; no hay
Down Goose de C ni rollback automático. Preservar las versiones/hashes previos.

## Pruebas pendientes y bloqueos operativos

Requieren destino desechable aislado, provisión/grants y ejecución expresamente autorizados:
firmas/compilación PLpgSQL, instalación atómica/fallo/ACL por defecto inesperada/upgrade,
roles efectivos y permisos UPDATE por columna necesarios para FOR SHARE/UPDATE,
tenant/PUBLIC/auth sin DML/DDL/SET ROLE/revoke scopes, pg_temp/search_path hostil,
fechas límite/retroceso/terminalidad, overflow/filas ausentes, evidencia stale tras
Argon2, CAS vs cambio de contraseña, emisión/revoke/logout/activity/expiry concurrentes,
contención y liberación por timeout/cancelación/deadlock, rollback y commit ambiguo.
Comprobar que errores/logs no contienen PHC/digests y que no se entrega secreto antes
de commit. No tests ni comandos de aplicación se ejecutaron al escribir C.

A/B no requieren cambios para las funciones escritas: timestamps/guards permiten
actualizaciones legítimas, snapshots permanecen intactos y permisos no son DML general
del caller. Los guards por sí solos no impiden al owner eludir coordinación de
credenciales/disabled, cambiar etiquetas de nivel o desactivar triggers: actor
administrativo y DML mínimos son parte de la frontera, no garantías de A/B aisladas.

La especificación/registro/contexto/ADR conservan encabezados históricos anteriores
a las autorizaciones de escritura A/B/C; ADR-003 también describe 30 días como
propuesta, aunque el contrato consolidado los aprueba. Se reporta discrepancia
documental sin modificar decisiones ni documentación ajena al alcance C.
No existe todavía contrato Go ejecutable de auth/pool/sqlc; B2-B sigue sin autorización.

## Referencias comprobadas

[PostgreSQL 18 CREATE FUNCTION](https://www.postgresql.org/docs/18/sql-createfunction.html):
search_path seguro y ACL transaccional; CREATE OR REPLACE conserva ownership/ACL
y no cambia tipos de retorno.
[SELECT](https://www.postgresql.org/docs/18/sql-select.html):
row locks requieren SELECT y UPDATE en al menos una columna.
[ALTER FUNCTION](https://www.postgresql.org/docs/18/sql-alterfunction.html):
administración de ownership por actor autorizado, sin ampliar migrator.

