<!-- Preparación histórica F; estado de ejecución vigente en docs/verification.md. -->
# B2-A F — plan de verificación integral desechable

Estado: **preparación de pruebas y revisión estática; ningún Docker/SQL/Goose/fixture
ejecutado**. No B2-A migrada/provisionada/verificada. El permiso actual solo permite
preparar archivos; ejecución, credenciales, herramientas e inyección de fallos son
gates separados. Evidencia por ejecución en docs/verification.md, con destino,
actor/hash, comando, exit, aserciones, COMMIT/ROLLBACK y residuos.

## Hallazgos concretos y alcance de las copias

B1 y guards/grants C–E fijan `tomopedidos_local`. No aceptarían una base distinta;
un nombre de base tampoco identifica el cluster. Reportado antes de preparar F.
F conserva B1/A–E originales y genera copias de ensayo con reemplazo **solo de
referencias de destino**, prefijo preflight en entradas psql y guard del spec nativo.
Prepare-FStage verifica que los cuerpos de todas las funciones permanecen idénticos;
migraciones 00001–00004 se copian byte por byte. stage-manifest registra hash original,
hash derivado y número de reemplazos por archivo. No usar manifiestos C/D/E originales
como hash de archivo derivado: sus source hashes/firma/ACL sí siguen siendo exactos.
El resultado certificará cuerpos/migraciones originales y adaptación de destino,
no aplicación de los instaladores originales sobre el entorno principal.

Segundo hallazgo: migraciones usan SET LOCAL search_path pg_catalog; Compose principal
no fija tabla Goose calificada. El registro de versión dentro de esa transacción puede
no encontrar una tabla unqualified creada en migration_meta. F exige siempre
`-table migration_meta.goose_db_version` para Up/Down/status/version/validate.
No se cambia Compose principal ni migraciones. Goose v3.29.0 documenta ese flag
para schemas distintos de public: [README de la versión](https://github.com/pressly/goose/blob/v3.29.0/README.md).

Tercer hueco: C no traía Down administrativo ejecutable. F prepara control/003_c_down.sql,
que valida fuentes/owners/ACL en estado c y retira solo nueve firmas sin CASCADE.
Debe ir después de E Down y D disable/ungrant, antes de cualquier Down de A/B.
No se modifica C ni se reabre el contrato de las revocaciones.

## Destino propuesto y separación efectiva

[target.json](../../tomopedidos-api/db/verification/f/target.json) y
[Compose F](../../tomopedidos-api/db/verification/f/compose.f.yaml):

| Identificador | Valor |
| --- | --- |
| Proyecto/contexto | tp-b2a-f-20261014-r01 / default |
| Contenedor PostgreSQL | tp-b2a-f-20261014-r01-pg |
| Base | tp_b2a_f_20261014_r01 |
| cluster_name | tp-b2a-f-20261014-r01 |
| Volumen nuevo | tp-b2a-f-20261014-r01-data |
| Red exclusiva interna | tp-b2a-f-20261014-r01-net |
| Puertos host | Ninguno; nunca 55432/5432 del host |
| PostgreSQL | 18.6, server_version_num 180006, mismo digest fijado en Compose vigente |
| Goose | v3.29.0; Dockerfile vigente, builder Go1.27 separado de API Go1.26 |
| Extensiones | Solo plpgsql de initdb; SHA256 core, sin pgcrypto/uuid-ossp |
| system_identifier | PENDIENTE, no inventado ni auto-enrolled |

No clon del volumen existente, bind de PGDATA, red compartida, puerto publicado,
root .env, conexión host:55432, API, sqlc o producción. Solo dos binds read-only de
F: staged y control. Build Goose conserva Dockerfile vigente; su build/pull instala
herramientas dentro de imágenes y necesita autorización de red/build aparte.
Registrar digest/ID del builder y de la imagen resultante: tags de build no prueban
reproducibilidad por sí solos. No instalar herramientas en la PC para sortear fallos.

Se requieren credenciales F nuevas e independientes, nunca las del entorno principal.
Private env propuesto: D:\tomopedidos\.local\b2a-f\r01.private.env, todavía no creado,
F1: solo F_BOOTSTRAP_PASSWORD para compose.f.yaml. En F2/F3, compose.tools.yaml exige F_MIGRATOR_PASSWORD; ambas variables deben
estar disponibles al resolver conjuntamente ambos archivos Compose; los otros logins se configuran después de
provisionar roles mediante procedimiento privado autorizado y psql \password.
HBA host/local SCRAM, psql -W (sin password en argv), independiente por actor.
No mostrar docker compose config interpolado ni docker inspect raw: Config.Env
contiene POSTGRES_PASSWORD. Preview imprime inspect selectivo sin Environment.
No cambiar HBA a trust. sslmode disable se limita a red aislada F; no contrato TLS
de producción. No aprobación ni credencial está almacenada en archivos versionados.

## Preflight y enrollment, antes de cualquier escritura

1. Autorización separada para crear instancia/volumen/red F; confirmar imágenes,
   rutas y nombres antes de invocar Docker. Cada invocación Docker en exec_command
   independiente; no cadenas ni diagnósticos mezclados. Permisos Docker fallidos:
   registrar comando/salida/exit y parar, sin elevación ni accesos alternativos.
2. Los nombres F deben estar ausentes antes de crear. Un not-found en inspección
   de existencia es evidencia esperada, no autoriza asumir un recurso ya existente.
   Si existen, parar/revisar; no usar up, borrar ni adoptar volumen por comodidad.
3. Tras creación autorizada, capturar inspect selectivo del contenedor, red y
   volumen; guardar resultados JSON en evidencia privada, sin Config.Env. Ejecutar
   Assert-FDockerSnapshot sobre esos JSON: nombre/digest/labels exactos, proyecto F,
   red única internal y enlace por IDs, ningún puerto, volumen exacto, binds F read-only,
   no host network/privileged/foreign peers. Es checker de **snapshots**, no captura
   live ni prueba de freshness: renovarlos inmediatamente antes de operaciones.
4. control/000_identify.sql es solo lectura y exige PG18.6, base/cluster_name/actor
   bootstrap exactos, TCP 127.0.0.1:5432 dentro del contenedor y ausencia de base
   llamada tomopedidos_local en ese cluster. Obtiene pg_control_system().system_identifier.
   Revisar ese ID contra la creación fresca, volumen y evidencia principal disponible;
   pin manual en target.json tras aprobación. No se autoacepta un cluster existente.
5. control/001_preflight.sql falla ante actor/base/version/cluster/TCP/extensiones
   incorrectos, system ID pendiente o control ID distinto para bootstrap. Antes de
   cada login no elevado y cada invocación Goose, nueva conexión bootstrap compara
   control ID en el contenedor validado. Los callers no reciben privilegios nuevos
   sobre pg_control_system. Las entradas psql staged incluyen preflight antes de BEGIN
   o cualquier SQL original. El spec native lleva control ID literal; con ID pendiente
   falla. Tras enrollment, preservar manifest previo y regenerar SOLO el guard nativo
   con `Prepare-FStage.ps1 -RefreshEnrollment`; exige source/hash anterior intactos.
6. Goose usa host postgres solo en red F y DSN de base F literal; sus migraciones
   originales no se prefijan porque deben conservar bytes. La verificación bootstrap
   y snapshot inmediatamente anteriores más DSN/tabla/red fijas son gates obligatorios.
   Nada usa PGHOST/PGDATABASE heredados de root .env como fallback.

El preflight reduce errores de destino; no protege contra un administrador que
deliberadamente falsifique JSON, target o comandos. Si una barrera falla, parar y
conservar evidencia. No probar rutas alternativas hasta que alguna conecte.

## Orden exacto y checkpoints

Todos los pasos siguientes están propuestos, no ejecutados. Preview completo:
[Print-FCommands.ps1](../../tomopedidos-api/db/verification/f/Print-FCommands.ps1),
que **solo imprime** comandos. SYSTEM_ID_PENDING hace fallar psql hasta enrollment.
No es un runner con aprobación automática; ejecutar cada comando solo al aprobar
su alcance. Bootstrap SQL, Goose y callers reales son conexiones separadas.

| Paso | Aplicación/verificación | Señal requerida |
| --- | --- | --- |
| 0 | Hashes E/F, staging, Compose y snapshot físico; enrollment | Pins exactos, control ID aprobado, sin recurso compartido |
| 1 | Copias B1 001_roles y 002_schema_privileges en F únicamente | Dos COMMIT; tp_owner, migrator/tenant, cinco schemas/default ACL equivalentes |
| 2 | B1 010 metadata y 020 privilege probes adaptados | Asserts/negativos completos, ROLLBACK y sin objetos probe residuales |
| 3 | Credenciales privadas migrator/tenant; TCP independiente | session_user correcto; cuatro contraseñas equivocadas rechazadas, códigos reales |
| 4 | Build/version/validate Goose autorizados; Up-to1,2,3,4 con tabla calificada | Exit0 por paso; version1,2,3,4 reales; ownership owner, tablas/guards/índices |
| 5 | control/004 metadata; fixtures030 integridad | Definiciones contra SQL vigente, 47 negativos, positivos local64/label63/total254 y ROLLBACK |
| 6 | D role-provision; C install; D executor-grants | COMMIT por paquete; owners/hash/ACL C exactos, sin caller |
| 7 | 040 d_stage=executors | Negativos/metadatos/privilegios efectivos, ROLLBACK |
| 8 | Autorizar D enable para fixtures F; 040 enabled en conexión nueva | Siete EXECUTE normales; scopes privileged sin caller |
| 9 | fixtures060 primitivas y 061 fallos | Nueve funciones reales, stale/state/digest/audience/overflow/CAS, ROLLBACK |
| 10 | Auth credential; 070 real login migrator/auth/tenant y 041 por auth/tenant | TCP real, auth26/tenant33 42501 y ROLLBACK; no SET ROLE admin como prueba login |
| 11 | E role-provision, E install dormant y 052 dormant | Solo executor con DML mínimo; caller sin CONNECT/EXECUTE |
| 12 | Autorizar E enable para fixtures; 052 enabled | Una firma maintenance, sin auth/tenant/PUBLIC |
| 13 | Maintenance credential, 070 TCP y 071 negativos | Real login y 12 negativos 42501; sin DML ni SET ROLE ejecutores |
| 14 | E 050 retención y 051 fallos | Ocho fixtures, límites/cutoff/rollback, atomicidad/clock/isolation; ROLLBACK |
| 15 | isolationtester + spec staged, doce permutations | Outputs reales revisados, interleavings/waits y survivors; teardown sintético completo |
| 16 | Harness de fallos/commit ambiguo/contención y ACL/search_path manuales | Outcomes + cleanup de fixtures, locks/conexiones liberados, métricas y sin secretos |
| 17 | Detener/drain callers F; E disable + E Down, D disable + D ungrant, F C Down | COMMIT por paquete; nueve firmas C removidas, roles conservados |
| 18 | Goose down-to3,2,1,0 y version por paso | Código0/version3,2,1,0; no CASCADE ni eliminación de schemas B1 |
| 19 | control/002 postDown y B1 010 metadata | identity vacía de objetos, cinco schemas/ACL B1, Goose control retenido |
| 20 | Re-Up4, metadata/integridad; reinstalar C/D/E sin repetir roles/B1 | Reproducibilidad y hash/ACL iguales, sin duplicación de roles/functions |
| 21 | Informe de aceptación y comparación de artefactos/evidencia principal | PASS solo casos realmente ejecutados; pendiente cualquier manual omitido |

Si falla un paso, no avanzar ni adaptar permisos para pasar. B1 010 se ejecuta
antes de A/D y tras retirar C/D/E: durante D/E, USAGE de nuevos roles hace incompatible
su expectativa owner-only antigua. No es defecto de B1 y no se modifica el verificador.
Goose status/version pueden crear su tabla de control si no existe: tratarlos como
operaciones SQL autorizadas, no inspección inocua antes del baseline.
Después del Down0 no reprovisionar roles existentes; conservar B1 y metadata Goose.
Roles cluster se retiran solo mediante destruir instancia F, con autorización propia.

## Cobertura automatizable y pendientes manuales

Los psql tests serán automatizables con credenciales privadas cuando exista target
autorizado; ahora solo están preparados. 030 usa helper pg_temp y subtransacciones
para comprobar SQLSTATE exacto sin imprimir argumentos. 060 prueba paths con
SAVEPOINT/restauración de locks, 061 fija estados/epochs/overflow sintéticos. Sus
PHC son fixtures léxicas, no hashes de passwords reales ni prueba Argon2id/rehash
equivalente. Scopes por SET ROLE owner privilegiado son fixtures, no habilitación
de autoridad/MFA. No HTTP, Go auth, keyring/CSRF binario, UI, SSE ni negocio.

Los fixtures existentes 050/051 requieren base de sesiones vacía y ROLLBACK; spec
native setup/teardown hace COMMIT de datos sintéticos y borra solo UUID propios.
Todo se ejecuta secuencialmente salvo fases explícitas de concurrencia. Verificar
ausencia de UUID/marcas F y E después de cada script/spec, no solo exit0.

| Manual/otra herramienta | Procedimiento y aceptación |
| --- | --- |
| Credenciales/HBA reales | Revisar pg_hba_file_rules como bootstrap; SCRAM exacto, -W por actor, rechazos password incorrecto; no alterar HBA para pasar |
| isolationtester PG18 | Herramienta no presente/instalada por F. Proveer binario compatible revisado dentro de contenedor desechable, o imagen de tests revisada con misma identidad. Sin publicar puertos como atajo. Capturar expected outputs reales |
| LOCK timeout/cancelación | Solo backend F identificado (PID + run ID + system ID + application_name); A retiene Identity UPDATE, B invoca cleanup. 55P03 o 57014, rollback B, liberar A, filas intactas y locks liberados; no retries |
| Commit ambiguo | Fixtures F conocidas; proxy/harness aislado aprobado pierde ACK de COMMIT o desconecta antes de COMMIT. Nueva conexión: ausencia tras commit o presencia tras rollback; caller original outcome unknown y sin segundo lote. Sin proxy/harness, caso pendiente |
| Atomicidad instaladores | Drift de owner/source/ACL o permiso por defecto inesperado en DB F: paquete debe abortar sin leftovers. Nunca modificar privilegios reales del entorno principal |
| pg_temp/search_path | Tablas/funciones homónimas temporales en fixture controlada; referencias calificadas y search_path fijo deben seguir sin desvío. Rollback y no grants permanentes al caller |
| Retiro/commit admin ambiguo | Nueva conexión compara ausencia/presencia de funciones y fingerprints contra manifiestos; no reapply inicial ciego |
| Contención y clocks | Stress varias identities/audiencias, padres globales, p50/p95/esperas/WAL; VM reloj controlado solo autorizada, nunca reloj del host |
| Corpus completo frontera | Revisar metadata/corpus contra todos los CHECK reales; ampliar casos si la ejecución descubre frontera no cubierta, sin declarar Go/PG equivalentes por SQL solamente |

No se automatiza matar procesos/cambiar reloj/instalar proxy ni se generan credenciales.
Fixtures manuales concretas en control/fixtures/090–097: seed con COMMIT, holder
interactivo, timeout esperado 55P03, caller cancelable, pg_cancel_backend limitado
al PID/actor/base/application_name/wait F y revalidado, pausa antes de COMMIT para
harness, reconciliación de 0 o 2 filas en conexión nueva y teardown por UUID exacto.
090 exige tablas vacías. Para comparar ambos outcomes de commit ambiguo, desmontar
fixtures y volver a sembrar solo tras registrar cada resultado; no repetir cleanup
como recuperación. No ejecutar las líneas del preview consecutivamente: holder,
caller y cancel deben estar en tres conexiones según el escenario, y los casos
de ACK perdido necesitan herramienta autorizada. Un COMMIT confirmado por 095
no cuenta como prueba de commit ambiguo.
Funcionalidad dinámica, compensación de datos y toolchain externo siguen bloqueados
hasta permisos/herramientas. sqlc compile/Go test/vet/build no son aceptación SQL aquí:
db/schema/db/queries no contienen el contrato auth completo, y no se cambia ni genera
código Go como parte de preparación F. Versiones/dependencias se mantienen.

## Preservación del principal y Celtas

Ahora: no Docker/SQL/Conexiones; originales B1/A–E y Compose/Dockerfile conservados
por hashes. Root .env no se leyó, copió ni usó. Celtas no se consultó.

En ejecución F futura: conservar snapshot físico F y lista exacta de todas las
invocaciones; confirmar que solo proyecto/red/volumen/contenedor F fueron usados.
Revalidar hashes del código principal y comparar inventario F before/after. Si el
usuario autoriza aparte inspección del entorno principal, capturar identidad/volumen/
puertos y comprobaciones de lectura antes/después; no incluimos SQL ni comandos
contra la base principal en este plan. Ausencia de comandos/mounts compartidos es
evidencia de separación, **no prueba byte por byte del contenido de esas bases**.
Para Celtas, evidencia independiente proporcionada por su operador o autorización
específica futura; no acceder a sus repos, contenedores ni DB para obtenerla.
No afirmar «datos Celtas verificados intactos» sin esa evidencia.

Conservar evidencias antes de eventual eliminación de F. Destruir F (contenedor,
red/volumen) requiere autorización destructiva nueva y verificar nombres/IDs/labels
exactos. No se prepara cleanup global ni se emite `down --volumes` automático.
Down de esquema no recupera sesiones borradas tras COMMIT; backup/PITR si procede
es otro alcance. Ningún logro se declara por tener scripts preparados.

Fuentes primarias: [Goose v3.29.0](https://github.com/pressly/goose/blob/v3.29.0/README.md),
[funciones de identidad/control PostgreSQL 18](https://www.postgresql.org/docs/18/functions-info.html),
[archivos de servicio libpq](https://www.postgresql.org/docs/18/libpq-pgservice.html).

## Reanudación F1 autorizada — 2026-10-14

F1 usa únicamente compose.f.yaml (postgres), bootstrap independiente y archivo privado ignorado por Git con ACL exclusiva del usuario. No construir Goose. F2/F3 requieren añadir explícitamente -f compose.tools.yaml y su credencial migrator: el requisito obligatorio permanece. El contexto de build posterior es docker/, fuera de .local; ningún archivo privado se monta. No mostrar configuración interpolada ni Environment. La autorización F1 incluye registrar el system_identifier real después de creación fresca e identificación de solo lectura; no autoriza baseline ni migraciones. El estado histórico de preparación y flags generales false no habilitan F2. Detener ante recurso preexistente o fallo; no eliminar recursos.
