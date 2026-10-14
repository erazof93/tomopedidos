# D2.1-B1 — preparación de roles y rutas

Estado actual: **D2.1-B1 completada para infraestructura PostgreSQL local**.
001/002 aplicados; 020, lecturas posteriores y 010 final aprobados por Codex,
con 14 negativos de privilegios, ROLLBACK y limpieza confirmados.
Credenciales independientes, TCP interno/Windows de ambos roles y cuatro negativos
de contraseña confirmados manualmente por el usuario; códigos negativos capturados 2
y positivos Windows 0. Registro: [evaluación de cierre](verification.md#d21-b1--autenticación-manual-y-evaluación-de-cierre).
SET LOCAL ROLE tp_owner e identidad/search_path en sesión TCP Windows migrator
confirmados manualmente, con ROLLBACK y exit 0; [cierre formal](verification.md#d21-b1--cierre-formal-con-evidencia-manual-de-set-role).
B2–B5 no iniciados ni autorizados. Las secciones de preparación siguientes son históricas.
Procedimiento vigente para repetir solo 010: [incidente y corrección](verification.md#incidente-010-sqlstate-42702-y-corrección-estática--2026-10-13).
Evaluación vigente de 002: [dictamen y preflight](review-002.md).
Las secciones previas de preparación e intentos conservan su contexto histórico;
no repetir 001 ni ejecutar la secuencia de etapas completa.
No se cambió el servicio PostgreSQL, su imagen, puerto ni volumen. API aún no conecta DB.

## Rutas definitivas

| Herramienta | Host | Contenedor |
| --- | --- | --- |
| Goose | tomopedidos-api/db/migrations | /migrations, solo lectura; working_dir /migrations |
| sqlc | tomopedidos-api | /app, working_dir /app; config /app/sqlc.yaml |
| sqlc schema/queries/output | db/schema, db/queries, internal/database/sqlc dentro de API | /app/db/schema, /app/db/queries, /app/internal/database/sqlc |

Goose construye desde `./docker`, con `goose.Dockerfile`: las credenciales de la raíz
quedan fuera del contexto de build. Los binds no crean rutas inexistentes.
sqlc ya no monta .env de raíz. El directorio db/
de raíz se conserva, pero Goose no lo usa. Goose/sqlc siguen v3.29.0/v1.31.1 y profile tools.
No se movieron migraciones ni generó código. Bootstrap/verification se ubican fuera del
directorio Goose y fuera del snapshot sqlc: nunca se ejecutan como migraciones automáticas.

## SQL preparado

- [001_roles.sql](../tomopedidos-api/db/bootstrap/001_roles.sql): crea roles solo si faltan;
  aborta ante atributos/membresías/ownership incompatibles; no cambia passwords existentes.
- [002_schema_privileges.sql](../tomopedidos-api/db/bootstrap/002_schema_privileges.sql):
  crea schemas vacíos propiedad de tp_owner, limita acceso DB/schema y defaults de objetos.
  Aborta si schemas pertenecen a otro owner o contienen objetos: no adopta ni borra datos.
- [010_b1_metadata.sql](../tomopedidos-api/db/verification/010_b1_metadata.sql): verifica
  atributos, membresías, CONNECT, CREATE/TEMP, ownership y acceso a schemas en read-only.
- [020_b1_effective_privileges.sql](../tomopedidos-api/db/verification/020_b1_effective_privileges.sql):
  probes de infraestructura con ROLLBACK final; permisos positivos de migrador/owner y
  denegaciones runtime para lectura, DDL, TRUNCATE, secuencias, funciones y administración.

No hay tablas de aplicación en bootstrap. El probe crea objetos de prueba únicamente
dentro de transacción que termina ROLLBACK; errores abortan y psql desconecta sin commit.
No es read-only, por lo que también requiere aprobación antes de ejecutarlo. No probarlo
como sustituto de RLS/aislamiento tenant: eso pertenece a B5.

| Rol | Ownership y privilegios preparados |
| --- | --- |
| tp_owner | NOLOGIN/NOINHERIT; propietario identity, tenancy, authorization, audit y migration_meta |
| tomopedidos_migrator | LOGIN/NOINHERIT, CONNECT; solo miembro de tp_owner con SET TRUE, INHERIT FALSE, ADMIN FALSE |
| tomopedidos_runtime | LOGIN/NOINHERIT, CONNECT y USAGE tenancy/authorization; sin membership owner ni DDL/DML |

Todos tienen NOSUPERUSER/NOBYPASSRLS/NOCREATEROLE/NOCREATEDB/NOREPLICATION.
Runtime no hereda owner; tampoco tiene TEMP, CREATE en DB/public ni acceso identity,
audit o migration_meta. No recibe permisos sobre tablas/secuencias futuras. Sus grants
concretos se decidirán junto a tablas/RLS en entregas posteriores. No se crea auth_runtime:
su pool adicional sigue pendiente de aprobación, fuera de B1.

El migrador debe asumir tp_owner explícitamente; no crea objetos con owner personal.
Goose ya configura ese cambio y search_path migration_meta mediante opciones de conexión,
driver postgres y /migrations. Así su tabla de control futura se creará bajo migration_meta
y owner tp_owner. No se crea esa tabla en este turno ni se ejecuta Goose status/up.

Defaults se aplican a objetos creados por tp_owner. Se retiran permisos PUBLIC/migrator/runtime
de futuras tablas, secuencias y funciones, globalmente y en los cinco schemas. Las revocaciones
por schema no eliminan permisos concedidos globalmente.
[Referencia PostgreSQL](https://www.postgresql.org/docs/18/sql-alterdefaultprivileges.html).
La prueba cambia session_user con SET SESSION AUTHORIZATION; SET ROLE cambia current_user.
Usar solo SET ROLE desde bootstrap superusuario
produciría un test de escalación inválido. [SET ROLE](https://www.postgresql.org/docs/18/sql-set-role.html).

Las revocaciones de PUBLIC afectan solo tomopedidos_local y sus schemas; necesitan revisión
de consumidores existentes antes de aplicar. No modifica la base/roles de Celtas.
Los roles PostgreSQL son globales al cluster: guard de nombre DB/bootstrap no convierte
roles en objetos tenant. Colisiones de nombres se rechazan, sin takeover automático.

## Credenciales y límites de ejecución

Roles nuevos se crean sin password, por lo que no pueden autenticarse por SCRAM hasta
provisión privada. .env.example tiene marcadores, incluyendo DB_MIGRATION_PASSWORD;
.env existente no se modificó. Goose no usa POSTGRES_PASSWORD de bootstrap: espera
DB_MIGRATION_PASSWORD, sin fallback. Un -version no necesita conexión ni password.

Después de aprobación, definir contraseñas propias de migrador/runtime en forma privada,
por ejemplo con psql interactivo y \password; no passwords en SQL, CLI, Git o logs.
Actualizar .env con el password migrador solo en el archivo ignorado. No reutilizar ni
cambiar password bootstrap. Sin provisionamiento privado, falla la conexión de Goose;
eso es esperado y no debe resolverse pasando credenciales bootstrap.

## Comandos pendientes — NO ejecutar antes de revisión

Solo configuración y versiones no ejecutan SQL:

```powershell
Set-Location D:\tomopedidos
docker compose config --quiet
docker compose --profile tools run --rm --no-deps goose -version
docker compose --profile tools run --rm --no-deps sqlc version
```

Aplicación futura bajo aprobación específica, una línea por paso, comprobando exit code:

```powershell
$localCompose = @('--context','default','compose','-p','tomopedidos-local')
Get-Content -Raw tomopedidos-api/db/bootstrap/001_roles.sql | docker @localCompose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U tomopedidos_bootstrap -d tomopedidos_local
if ($LASTEXITCODE -ne 0) { throw 'Falló 001; detener' }
Get-Content -Raw tomopedidos-api/db/bootstrap/002_schema_privileges.sql | docker @localCompose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U tomopedidos_bootstrap -d tomopedidos_local
if ($LASTEXITCODE -ne 0) { throw 'Falló 002; detener' }
Get-Content -Raw tomopedidos-api/db/verification/010_b1_metadata.sql | docker @localCompose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U tomopedidos_bootstrap -d tomopedidos_local
if ($LASTEXITCODE -ne 0) { throw 'Falló metadata; detener' }
Get-Content -Raw tomopedidos-api/db/verification/020_b1_effective_privileges.sql | docker @localCompose exec -T postgres psql -X -v ON_ERROR_STOP=1 -U tomopedidos_bootstrap -d tomopedidos_local
if ($LASTEXITCODE -ne 0) { throw 'Falló prueba efectiva; detener' }
```

Confirmar primero que contexto default es pipe/socket local y proyecto/base son Tomopedidos.
Estos scripts no incluyen passwords. No pasar .env como stdin a psql ni mostrar config.
Referencia histórica del procedimiento TCP, ahora aprobado mediante evidencia manual:

```powershell
# psql pregunta el password sin imprimirlo. Migrador: probar además SET ROLE tp_owner
# y SELECT session_user,current_user dentro de la sesión, sin crear tablas de aplicación.
docker compose exec postgres psql -X -h 127.0.0.1 -U tomopedidos_migrator -d tomopedidos_local -W -c 'SELECT 1;'
docker compose exec postgres psql -X -h 127.0.0.1 -U tomopedidos_runtime -d tomopedidos_local -W -c 'SELECT 1;'
```

## Evidencia y revisión requerida

Compose/rutas pueden comprobarse sin Engine; la sintaxis y efectos PostgreSQL requieren
ejecución aprobada en PostgreSQL 18. No presentar inspección estática como test SQL aprobado.
[verification.md](verification.md) registra qué se ejecutó realmente. Revisar schemas,
revocaciones PUBLIC, política de owner/SET ROLE y provisión de passwords antes de aplicar.
B2–B5, tablas funcionales, RLS y auth HTTP permanecen fuera de alcance.

## Revisión de seguridad B1 — 2026-10-13

Preparación aprobada con observaciones; ejecución PostgreSQL pendiente. No se ejecutó SQL.

- Alta, corregida: defaults globales previos de tablas/secuencias podían sobrevivir a
  revocaciones por schema. Ahora se revocan ambos niveles y metadata verifica los ACL.
- Alta, corregida: PUBLIC conservaba USAGE en public. Se revoca ALL en ese schema,
  abortando si contiene objetos o tiene otro owner. Solo afecta la base local designada.
- Media, corregida: el contexto de build Goose incluía la raíz; ahora se limita a docker.
- Media, corregida: guards y metadata cubren memberships inesperadas, opciones de
  delegación, ownership y dependencias de roles en otras bases, y privilegios de parámetros.
- Media, corregida: las pruebas comprueban ownership y 14 denegaciones runtime;
  detectan colisiones antes de crear probes y verifican limpieza después del ROLLBACK.
  Solo se captura insufficient_privilege; cualquier otro error interrumpe la prueba.

Antes de aplicar: comprobar consumidores de PUBLIC y que el cluster sea exclusivamente
local. Las revocaciones no modifican otras bases, pero los roles son globales al cluster.
Los scripts abortan ante objetos existentes o grants a terceros; no los adoptan ni eliminan.
001 y 002 tienen transacciones independientes: si 002 falla, 001 permanece aplicado.
Revisar el error antes de continuar; no hacer cleanup automático ni borrar volúmenes.

Orden propuesto, sin ejecución en esta revisión: contexto local confirmado; 001; 002;
010; 020; 010 nuevamente; provisión interactiva con \password de cada login; pruebas
TCP con -W de ambos logins. Para comprobar las opciones de Goose en una sesión migrator,
usar SET ROLE tp_owner y SET search_path TO migration_meta, pg_catalog, y consultar
session_user/current_user. La ejecución real de Goose y su tabla de control quedan
fuera de esta revisión. No usar Goose status/up ni pasar passwords como argumentos.

Riesgos residuales: sintaxis/efectos SQL sin certificar en PostgreSQL; acceso de administradores
Docker a secretos de environment; owner/migrator son actores de confianza capaces de DDL;
RLS y permisos de tablas futuras aún no implementados. No equivale a aislamiento tenant probado.

## Revisión final PostgreSQL 18 — sin ejecución

Las formas GRANT de membership ADMIN/INHERIT/SET, ALTER DEFAULT PRIVILEGES,
CREATE SCHEMA ... AUTHORIZATION y las consultas a catálogos corresponden a PostgreSQL 18.
Esto es contraste documental, no compatibilidad certificada mediante ejecución.

- SET SESSION AUTHORIZATION cambia session_user/current_user; requiere que el usuario
  autenticado originalmente sea superusuario para impersonar otro login. RESET restaura
  la identidad autenticada. Ambos están fuera de los bloques DO en 020.
- SET LOCAL ROLE tp_owner conserva session_user=migrator y verifica su opción SET.
  PostgreSQL permite estos comandos dentro de transacciones. ROLLBACK revierte los SET
  realizados en ellas. SET ROLE no aplica los settings ALTER ROLE del rol destino.
- Los DO son invoker, no SECURITY DEFINER. Los dos SET ROLE negativos son EXECUTE
  dentro de DO invoker. No se realiza COMMIT/ROLLBACK dentro de DO ni se capturan errores
  de cambio de identidad de la preparación: cualquier fallo allí interrumpe el script.
- Cada negativo solo admite insufficient_privilege (42501). Éxito inesperado produce
  P0001 no capturado; objeto ausente, sintaxis inválida u otro error también abortan.
  Se comprueban identidad runtime y catorce denegaciones. Los probes no tienen triggers,
  RLS ni funciones externas que puedan ocultar otra causa de 42501.
- Los defaults globales de funciones eliminan el EXECUTE implícito de PUBLIC; las
  revocaciones por schema solo retiran grants adicionales. No afectan objetos existentes.
  Se aplican exclusivamente al creador tp_owner. No cambian ownership existente.

Fuentes: [SESSION AUTHORIZATION](https://www.postgresql.org/docs/18/sql-set-session-authorization.html),
[ROLE](https://www.postgresql.org/docs/18/sql-set-role.html),
[SET y rollback](https://www.postgresql.org/docs/18/sql-set.html),
[DO](https://www.postgresql.org/docs/18/sql-do.html),
[EXCEPTION](https://www.postgresql.org/docs/18/plpgsql-control-structures.html#PLPGSQL-ERROR-TRAPPING).

Pendiente de prueba real: parsing SQL/PLpgSQL, cada SQLSTATE, cambios efectivos de
identidad, ownership, defaults, grants y limpieza al abortar o terminar normalmente.
La impersonación en 020 no verifica contraseñas ni pg_hba.conf; para eso están las pruebas
TCP separadas. TCP a 127.0.0.1 dentro del contenedor comprueba autenticación al puerto
5432 interno, no accesibilidad desde Windows por el puerto publicado 55432.

## Preflight propuesto de solo lectura — pendiente de autorización

No iniciar servicios automáticamente. Primero comprobar contexto, contenedor y puerto,
sin volcar docker inspect completo ni environment. Confirmar que el endpoint es local:

```powershell
Set-Location D:\tomopedidos
docker context inspect default --format '{{.Endpoints.docker.Host}}'
docker --context default compose -p tomopedidos-local ps postgres
docker --context default compose -p tomopedidos-local port postgres 5432
docker --context default compose -p tomopedidos-local exec postgres psql -X -v ON_ERROR_STOP=1 -U tomopedidos_bootstrap -d tomopedidos_local
```

En esa conexión nueva, después de aprobar el preflight, ejecutar el siguiente bloque.
No consulta pg_authid ni contraseñas; las ACL y nombres de objetos son metadatos.
No ejecutar bootstrap ni 020 como parte del preflight.

```sql
BEGIN READ ONLY;
SET LOCAL search_path TO pg_catalog;
SELECT current_database(), session_user, current_user,
       current_setting('server_version') AS server_version,
       current_setting('server_version_num') AS server_version_num,
       current_setting('password_encryption') AS password_encryption,
       inet_server_addr(), inet_server_port();
SELECT d.datname, pg_get_userbyid(d.datdba) AS owner,
       d.datistemplate, d.datallowconn, d.datacl
FROM pg_database d ORDER BY d.datname;
SELECT rolname, rolcanlogin, rolinherit, rolsuper, rolcreatedb,
       rolcreaterole, rolreplication, rolbypassrls
FROM pg_roles
WHERE rolname IN ('tomopedidos_bootstrap','tp_owner',
                  'tomopedidos_migrator','tomopedidos_runtime');
SELECT member.rolname AS member, granted.rolname AS granted_role,
       m.admin_option, m.inherit_option, m.set_option
FROM pg_auth_members m JOIN pg_roles member ON member.oid=m.member
JOIN pg_roles granted ON granted.oid=m.roleid
WHERE member.rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime')
   OR granted.rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime');
SELECT nspname, pg_get_userbyid(nspowner) AS owner, nspacl
FROM pg_namespace
WHERE nspname NOT LIKE 'pg_%' AND nspname<>'information_schema';
SELECT n.nspname, pg_describe_object(d.classid,d.objid,d.objsubid) AS object,
       d.deptype
FROM pg_depend d JOIN pg_namespace n ON n.oid=d.refobjid
WHERE d.refclassid='pg_namespace'::regclass
  AND n.nspname IN ('public','identity','tenancy','authorization','audit','migration_meta')
ORDER BY n.nspname, object;
SELECT extname, extversion, pg_get_userbyid(extowner) AS owner,
       extnamespace::regnamespace AS schema
FROM pg_extension;
SELECT pg_get_userbyid(defaclrole) AS creator, defaclnamespace,
       defaclobjtype, defaclacl
FROM pg_default_acl
WHERE defaclrole IN (SELECT oid FROM pg_roles
                    WHERE rolname IN ('tomopedidos_bootstrap','tp_owner',
                                      'tomopedidos_migrator','tomopedidos_runtime'));
SELECT r.rolname, db.datname, d.classid::regclass AS catalog,
       d.objid, d.deptype
FROM pg_shdepend d JOIN pg_roles r ON r.oid=d.refobjid
LEFT JOIN pg_database db ON db.oid=d.dbid
WHERE d.refclassid='pg_authid'::regclass
  AND r.rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime');
SELECT parname, paracl FROM pg_parameter_acl;
SELECT COALESCE(r.rolname,'ALL') AS role, COALESCE(db.datname,'ALL') AS database,
       split_part(setting,'=',1) AS setting_name
FROM pg_db_role_setting s LEFT JOIN pg_roles r ON r.oid=s.setrole
LEFT JOIN pg_database db ON db.oid=s.setdatabase
CROSS JOIN LATERAL unnest(s.setconfig) AS config(setting)
WHERE s.setrole=0 OR r.rolname IN ('tomopedidos_bootstrap','tp_owner',
                                  'tomopedidos_migrator','tomopedidos_runtime');
SELECT pid, usename, application_name, client_addr
FROM pg_stat_activity WHERE datname=current_database();
ROLLBACK;
```

Criterio de continuar: PostgreSQL 18, base tomopedidos_local no-template propiedad de
bootstrap superusuario; public vacío; cinco schemas ausentes o vacíos con owner tp_owner;
roles ausentes o compatibles; ausencia de consumidores ajenos, dependencias en otras bases,
grants inesperados y settings de seguridad incompatibles. Los settings solo muestran nombres
para evitar revelar valores arbitrarios: investigar cualquier override inesperado privadamente.
Verificar password_encryption=scram-sha-256 antes de provisionar passwords.
Si alguna condición falla, detener; no borrar objetos, apropiarse de schemas ni revocar
permisos ajenos para forzar el resultado. El preflight es una foto del estado: usar una
ventana sin otros actores DDL y conservar los guards al aplicar.

## Recuperación si 001 confirma COMMIT y 002 falla

1. Detener la secuencia. Conservar error, SQLSTATE y exit code sin secretos. No ejecutar
   010/020 ni provisionar passwords mientras 002 no haya confirmado COMMIT.
2. En ejecución batch psql con ON_ERROR_STOP, su salida cierra la conexión y revierte la
   transacción abierta de 002. En ejecución interactiva, emitir ROLLBACK y desconectar.
   Si el fallo fue de transporte alrededor de COMMIT, el resultado puede ser incierto:
   comprobar el estado antes de afirmar rollback o repetir.
3. Abrir conexión nueva y repetir el preflight de solo lectura. Los roles/membership de
   001 permanecen; no intentar deshacerlos mediante DROP ROLE, DROP OWNED o CASCADE.
   Si 001 creó logins nuevos, siguen sin password. Roles preexistentes pueden conservarlo.
4. Clasificar la causa: contexto/base equivocados, objeto/conflicto previo, defaults a
   terceros o error de sintaxis. Resolver únicamente la causa revisada; cambios sobre
   objetos existentes requieren autorización adicional. No borrar volúmenes ni datos.
5. Con estado compatible y autorización de reintento, ejecutar únicamente 002 con
   ON_ERROR_STOP en conexión nueva. Sus CREATE SCHEMA IF NOT EXISTS permiten repetir
   sobre schemas vacíos compatibles; los guards siguen bloqueando apropiación de objetos.
6. Solo tras COMMIT confirmado: 010, 020, 010; luego passwords mediante \password y
   pruebas TCP con -W. No pasar passwords en URI, argumentos, SQL versionado ni logs.

No se prepara rollback destructivo automático. B1 sigue pendiente de aprobación/aplicación.

## Aplicación por etapas preparada tras preflight del usuario

Preflight satisfactorio comunicado por el usuario: PostgreSQL 18.6, tomopedidos-local /
tomopedidos_local; roles B1 ausentes, public vacío propiedad de pg_database_owner;
solo plpgsql; sin memberships/dependencias/defaults personalizados/ACL de parámetros/settings.
Evidencia atribuida al usuario en verification.md. SQL de aplicación todavía no ejecutado.

Los cuatro scripts vigentes corresponden a ese estado; no necesitan correcciones por
este inventario. Confirmar antes de aplicar propietario de base, bootstrap superusuario
y consumidores: esos detalles no se incluyeron en el resumen recibido. No inferir que
PUBLIC carece de grants estándar porque no haya defaults personalizados.

Todos los comandos siguientes son propuestas: no ejecutar sin autorización de la etapa.
No pegar la secuencia completa para correrla automáticamente. Usar ventana sin DDL ajeno.
Preparación común fija contexto, Compose y proyecto; no inicia ni modifica contenedores:

```powershell
Set-Location D:\tomopedidos
$b1Docker = @('--context', 'default', 'compose', '-f', 'compose.yaml', '-p', 'tomopedidos-local')
$b1Endpoint = docker context inspect default --format '{{.Endpoints.docker.Host}}'
if ($LASTEXITCODE -ne 0 -or $b1Endpoint.Trim() -ne 'npipe:////./pipe/docker_engine') {
    throw 'Contexto local no confirmado; detener'
}
docker @b1Docker ps postgres
if ($LASTEXITCODE -ne 0) { throw 'Engine no disponible; detener' }
$b1Port = docker @b1Docker port postgres 5432
if ($LASTEXITCODE -ne 0 -or $b1Port.Trim() -ne '127.0.0.1:55432') {
    throw 'Puerto inesperado; detener'
}
function Invoke-B1File {
    param([Parameter(Mandatory)][ValidateSet(
        'db/bootstrap/001_roles.sql',
        'db/bootstrap/002_schema_privileges.sql',
        'db/verification/010_b1_metadata.sql',
        'db/verification/020_b1_effective_privileges.sql'
    )][string]$File)
    $b1Path = Join-Path 'D:\tomopedidos\tomopedidos-api' $File
    $b1Sql = Get-Content -Raw -Encoding UTF8 -LiteralPath $b1Path -ErrorAction Stop
    $b1Sql | docker @b1Docker exec -T postgres psql -X -v ON_ERROR_STOP=1 `
        -U tomopedidos_bootstrap -d tomopedidos_local -f -
    if ($LASTEXITCODE -ne 0) { throw "Falló $File; detener y revisar" }
}
```

Etapa 0: confirmar identidad, versión y ownership, además del inventario de consumidores
del preflight. Solo continuar si bootstrap es superusuario, propietario de la base
no-template, versión 18, y no hay consumidores ajenos afectados por PUBLIC:

```powershell
docker @b1Docker exec -T postgres psql -X -v ON_ERROR_STOP=1 `
    -U tomopedidos_bootstrap -d tomopedidos_local `
    -c 'BEGIN READ ONLY; SELECT current_database(),session_user,current_user,current_setting(''server_version''); SELECT d.datname,pg_get_userbyid(d.datdba) AS owner,d.datistemplate,r.rolsuper FROM pg_database d JOIN pg_roles r ON r.rolname=session_user WHERE d.datname=current_database(); SELECT pid,usename,application_name,client_addr FROM pg_stat_activity WHERE datname=current_database(); ROLLBACK;'
if ($LASTEXITCODE -ne 0) { throw 'Falló comprobación de destino; detener' }
```

Etapa 1: únicamente después de autorizar 001. Esperar exit 0 y COMMIT; si hay error
detener. No provisionar passwords. Los roles nuevos quedan sin password:

```powershell
Invoke-B1File 'db/bootstrap/001_roles.sql'
```

Etapa 2: continuar solo tras confirmar etapa 1 y con autorización de 002:

```powershell
Invoke-B1File 'db/bootstrap/002_schema_privileges.sql'
```

Esperar exit 0 y COMMIT. Si falla, aplicar el procedimiento de recuperación anterior;
001 permanece confirmado. No ejecutar los pasos siguientes ni cleanup automático.

Etapa 3: verificación de metadata, sin crear objetos; requiere 002 confirmado:

```powershell
Invoke-B1File 'db/verification/010_b1_metadata.sql'
```

Exigir exit 0, B1 metadata checks passed y ROLLBACK. Cualquier discrepancia detiene.

Etapa 4: requiere autorización explícita de probes que crean objetos transaccionales,
además de metadata aprobada. No está autorizada por la tarea actual:

```powershell
Invoke-B1File 'db/verification/020_b1_effective_privileges.sql'
```

Exigir exit 0, ROLLBACK y B1 probes passed and rollback cleanup confirmed. Si aparece
una autorización inesperada, SQLSTATE distinto de 42501 o falla limpieza, detener y
revisar en conexión nueva; no borrar objetos ni reintentar a ciegas.

Etapa 5: repetir metadata para confirmar el baseline posterior:

```powershell
Invoke-B1File 'db/verification/010_b1_metadata.sql'
```

Provisión de contraseñas y pruebas TCP quedan en etapa posterior bajo autorización.
No declarar B1 completado por preparación documental ni por COMMIT de 001 solamente.

## Ejecución manual limitada a 001 — autorizada, bloqueada en Codex

Autorización del usuario: únicamente 001 y consultas de lectura antes/después. Engine
deniega acceso a Codex; estos comandos no se ejecutaron. La huella corresponde al archivo
vigente releído en esta revisión. No ejecutar 002, 010, 020 ni provisionar passwords.
El precheck exige roles aún ausentes como en el preflight informado; si cambió el estado,
detener y solicitar revisión. Ante fallo o COMMIT incierto, no reintentar automáticamente.

```powershell
Set-Location D:\tomopedidos
$dc001 = @('--context','default','compose','-f','compose.yaml','-p','tomopedidos-local')
$endpoint001 = docker context inspect default --format '{{.Endpoints.docker.Host}}'
if ($LASTEXITCODE -ne 0 -or $endpoint001.Trim() -ne 'npipe:////./pipe/docker_engine') {
    throw 'Contexto local no confirmado; detener'
}
docker @dc001 ps postgres
if ($LASTEXITCODE -ne 0) { throw 'Engine no disponible; detener' }
$port001 = docker @dc001 port postgres 5432
if ($LASTEXITCODE -ne 0 -or $port001.Trim() -ne '127.0.0.1:55432') {
    throw 'Puerto inesperado; detener'
}
$file001 = 'D:\tomopedidos\tomopedidos-api\db\bootstrap\001_roles.sql'
$hash001 = '2EAA920E1DF044DDA6003FE347511F092347BBD26CEDB22EF0BB91F6CF83D5B2'
$bytes001 = [System.IO.File]::ReadAllBytes($file001)
$sha001 = [System.Security.Cryptography.SHA256]::Create()
try { $actual001 = [BitConverter]::ToString($sha001.ComputeHash($bytes001)).Replace('-','') }
finally { $sha001.Dispose() }
if ($actual001 -ne $hash001) { throw 'Script distinto del revisado; detener' }
$check001 = @'
BEGIN READ ONLY;
SET LOCAL search_path TO pg_catalog;
SELECT current_database()='tomopedidos_local'
   AND session_user='tomopedidos_bootstrap' AND current_user=session_user
   AND current_setting('server_version_num')::integer BETWEEN 180000 AND 189999
   AND EXISTS (SELECT 1 FROM pg_roles WHERE rolname=session_user AND rolsuper)
   AND EXISTS (SELECT 1 FROM pg_database WHERE datname=current_database()
                AND datdba=(SELECT oid FROM pg_roles WHERE rolname=session_user)
                AND NOT datistemplate)
   AND NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname IN
                    ('tp_owner','tomopedidos_migrator','tomopedidos_runtime'));
ROLLBACK;
'@
$ready001 = $check001 | docker @dc001 exec -T postgres psql -X -qAt -v ON_ERROR_STOP=1 `
    -U tomopedidos_bootstrap -d tomopedidos_local -f -
if ($LASTEXITCODE -ne 0 -or ($ready001 -join "`n").Trim() -ne 't') {
    throw 'Identidad, ownership, versión o roles incompatibles; detener y revisar'
}
# Aplicar los mismos bytes cuya huella se verificó. Ningún otro script.
$sql001 = [System.Text.Encoding]::UTF8.GetString($bytes001)
$output001 = $sql001 | docker @dc001 exec -T postgres psql -X -v ON_ERROR_STOP=1 `
    -U tomopedidos_bootstrap -d tomopedidos_local -f -
$exit001 = $LASTEXITCODE
$output001
if ($exit001 -ne 0 -or -not ($output001 -match '^COMMIT$')) {
    throw '001 falló o COMMIT no confirmado; detener y solicitar revisión'
}
Write-Output '001: exit 0 y COMMIT confirmados'
$verify001 = @'
BEGIN READ ONLY;
SET LOCAL search_path TO pg_catalog;
SELECT (SELECT count(*) FROM pg_roles WHERE rolname IN
         ('tp_owner','tomopedidos_migrator','tomopedidos_runtime'))=3
   AND NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname IN
                    ('tp_owner','tomopedidos_migrator','tomopedidos_runtime')
                    AND (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication
                         OR rolbypassrls OR rolinherit OR rolcanlogin<>(rolname<>'tp_owner')))
   AND (SELECT count(*) FROM pg_auth_members m JOIN pg_roles member ON member.oid=m.member
        JOIN pg_roles granted ON granted.oid=m.roleid
        WHERE member.rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime')
           OR granted.rolname='tp_owner')=1
   AND EXISTS (SELECT 1 FROM pg_auth_members m JOIN pg_roles member ON member.oid=m.member
               JOIN pg_roles granted ON granted.oid=m.roleid
               WHERE member.rolname='tomopedidos_migrator' AND granted.rolname='tp_owner'
                 AND m.set_option AND NOT m.inherit_option AND NOT m.admin_option);
ROLLBACK;
'@
$verified001 = $verify001 | docker @dc001 exec -T postgres psql -X -qAt -v ON_ERROR_STOP=1 `
    -U tomopedidos_bootstrap -d tomopedidos_local -f -
if ($LASTEXITCODE -ne 0 -or ($verified001 -join "`n").Trim() -ne 't') {
    throw 'Verificación posterior falló; detener sin correcciones automáticas'
}
$inventory001 = @'
BEGIN READ ONLY;
SET LOCAL search_path TO pg_catalog;
SELECT rolname,rolcanlogin,rolinherit,rolsuper,rolcreatedb,rolcreaterole,rolreplication,rolbypassrls
FROM pg_roles WHERE rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime') ORDER BY rolname;
SELECT member.rolname AS member,granted.rolname AS granted_role,
       m.admin_option,m.inherit_option,m.set_option
FROM pg_auth_members m JOIN pg_roles member ON member.oid=m.member
JOIN pg_roles granted ON granted.oid=m.roleid
WHERE member.rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime')
   OR granted.rolname='tp_owner';
ROLLBACK;
'@
$inventory001 | docker @dc001 exec -T postgres psql -X -v ON_ERROR_STOP=1 `
    -U tomopedidos_bootstrap -d tomopedidos_local -f -
if ($LASTEXITCODE -ne 0) { throw 'Lectura final falló; detener y revisar' }
Write-Output 'Detener aquí: 002, 010, 020, passwords y Goose no autorizados'
```
