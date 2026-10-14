# Evaluación previa de 002 — 2026-10-13

## Estado y dictamen

001 aplicado y verificado según ejecución manual informada por el usuario en PostgreSQL
18.6: COMMIT, exit 0, atributos y única membership esperados. B1 sigue incompleto.
No se ejecutó SQL en esta revisión. 002, 010, 020, Goose, credenciales y B2–B5 no autorizados.
Los scripts bootstrap se conservan sin cambios para preservar su huella.

Dictamen: **002 apto para revisión condicionada, todavía no habilitado para ejecución**.
No se observa necesidad de cambiar su SQL por los resultados de 001. Falta evidencia
actual de consumidores, ACL efectivos, ownership y ausencia de conflictos. El inventario
previo a 001 no sustituye una comprobación inmediatamente anterior a 002.

## Alcance y consumidores

| Cambio de 002 | Alcance y riesgo |
| --- | --- |
| REVOKE ALL en tomopedidos_local | Retira CONNECT, TEMP y cualquier CREATE de PUBLIC y ambos logins; devuelve solo CONNECT a migrator/runtime. Otros logins pueden perder nuevas conexiones o tablas temporales si dependían de PUBLIC. Grants propios/heredados, owner y superusuarios requieren evaluación separada. |
| REVOKE ALL en public | Quita USAGE/CREATE de PUBLIC y ambos logins. Puede romper nombres sin calificar, extensiones u objetos de public; el guard exige esquema vacío y owner compatible. No elimina grants independientes a terceros. |
| Cinco schemas | Crea schemas vacíos tp_owner; retira PUBLIC/migrator/runtime, devuelve USAGE solo a runtime en tenancy/authorization. Migrator debe SET ROLE tp_owner. Un guard aborta ante objetos, otro owner o grants ajenos en esos cinco schemas. |
| Defaults de tp_owner | Global significa todos los schemas de esta base para futuros objetos creados por tp_owner, no todo el cluster. Retira grants de tablas/secuencias/funciones y EXECUTE implícito de PUBLIC en funciones; no altera objetos existentes ni defaults de otros creadores. No endurece defaults de tipos ni de schemas. |
| Settings de logins | Cambia search_path de nuevas sesiones de esos roles solo en esta base. Revisar herramientas que esperen public; SET ROLE no aplica settings del rol destino. |

PUBLIC incluye todos los roles, incluso futuros. Revisar aplicaciones, pools, clientes
SQL, tareas programadas, backups, monitoreo, pruebas y herramientas de mantenimiento
que apunten a **esta base**, incluidos consumidores apagados o desconectados. No inferir
ausencia por public vacío, defaults sin filas o pg_stat_activity vacío. Confirmar con el
operador sus configuraciones sin copiar DSN, passwords ni environment a evidencia.
CONNECT se evalúa al abrir conexión: no desconecta sesiones existentes; USAGE revocado
tampoco garantiza bloquear búsquedas ya resueltas en sesiones abiertas. Usar sesiones
nuevas para cualquier verificación posterior autorizada.

Los roles son globales al cluster, pero estas revocaciones/defaults son locales a la base;
no cambian ACL de otras bases ni Celtas. No constituyen RLS ni aislamiento tenant.
Referencias: [privilegios PostgreSQL 18](https://www.postgresql.org/docs/18/ddl-priv.html)
y [defaults](https://www.postgresql.org/docs/18/sql-alterdefaultprivileges.html).

## Consultas preparadas y condiciones de parada

Archivo independiente de Goose y de 010/020:
[preflight_002_readonly.sql](../tomopedidos-api/db/verification/preflight_002_readonly.sql).
Solo catálogos dentro de BEGIN READ ONLY y ROLLBACK; preparado, no ejecutado ni certificado
mediante parsing PostgreSQL. No es una predicción automática exacta de ACL posteriores.
Revisar grants directos, memberships INHERIT/SET y ownership para interpretar cada rol.
Complementa el preflight existente de development-b1.md; no autoriza aplicación.

Detener si destino/versión/owner no corresponden; roles o membership difieren de 001;
public tiene objetos/owner ajeno; alguno de los cinco schemas tiene objetos/owner ajeno;
defaults tp_owner conceden a terceros; defaults de schemas de bootstrap son inesperados;
hay dependencias ajenas, ACL de parámetros/settings incompatibles o consumidores sin
clasificar. Investigar grants independientes en DB/public: 002 puede conservarlos y los
guards no garantizan ausencia de consumidores. No revocar, borrar ni apropiarse de objetos
para forzar el resultado. Ausencia de un schema debe aparecer como ausencia, no como fallo.

## Procedimiento propuesto, sin ejecución

1. Confirmar contexto default npipe local, proyecto tomopedidos-local, servicio postgres
   y puerto 127.0.0.1:55432 con los comandos de development-b1.md. No iniciar servicios.
2. En conexión nueva bootstrap/tomopedidos_local, ejecutar únicamente el preflight de
   lectura cuando esté autorizado. Usar psql -X -v ON_ERROR_STOP=1 -f -, entrada UTF-8.
   Conservar exit code y resultados sin secretos. Exigir ROLLBACK y revisar todas las filas;
   el exit 0 de este inventario no demuestra que las condiciones de continuar se cumplan.
3. Confirmar consumidores desconectados con el operador y acordar una ventana sin DDL
   ni uso ajeno de la base. Documentar impacto aceptado o mantener 002 pendiente.
4. Solo con autorización explícita de 002, releer el script y verificar SHA256:
   `2AF021298BBBF5B58B942618C543941E6D80DC46E6EDE66F195FBB3A10A6E122`.
   Aplicar únicamente esos mismos bytes en conexión nueva bootstrap, psql -X,
   ON_ERROR_STOP=1 y -f -. No repetir 001 ni encadenar otros scripts.
5. Exigir COMMIT y exit 0; guardar evidencia y detener. 010 y 020 quedan para autorización
   posterior separada; tampoco provisionar passwords ni ejecutar Goose.
6. Ante error, detener. El cierre batch revierte la transacción abierta; en interactivo,
   ROLLBACK y desconectar. Si se pierde transporte alrededor de COMMIT, resultado incierto:
   leer estado en conexión nueva antes de afirmar rollback o repetir. 001 permanece aplicado.
   No cleanup destructivo; cualquier corrección/reintento necesita revisión y autorización.

## Verificación pendiente

Resultados del nuevo preflight, consumidores confirmados, ejecución de 002 y comprobación
posterior de sus ACL/settings/defaults. 010/020, autenticación TCP y cierre B1 siguen pendientes.
