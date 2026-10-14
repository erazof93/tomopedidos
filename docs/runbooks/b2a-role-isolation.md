# B2-A D — provisión, grants y aislamiento

Estado: **archivos preparados y revisados estáticamente; no provisionados,
aplicados ni verificados en PostgreSQL**. La autorización actual permite escritura
y verificadores locales. Cada aplicación/prueba posterior requiere autorización
específica. No ejecutar estos scripts por tener acceso a Docker.

## Contratos y nombres conservados

[C](../../tomopedidos-api/db/administration/manifests/b2a-auth-v1.yaml) contiene
`identity.revoke_audience(bytea, text)` y `identity.revoke_global(bytea, text)`.
El pedido de D usa los nombres conceptuales `revoke_audience_privileged` y
`revoke_global_privileged`; no existen esas firmas en C. D conserva las reales,
les deniega EXECUTE a auth/tenant/PUBLIC y rechaza aliases inesperados con esos
nombres. No se renombra ni duplica C. Las nueve firmas, nombres/orden/tipos de
entrada y salida, hashes y owners coinciden con el YAML mediante el comprobador
offline [check_b2a_contracts.ps1](../../tomopedidos-api/db/verification/check_b2a_contracts.ps1).
No es un parser YAML general ni compilador PLpgSQL: falla ante el formato no soportado.

## Roles y matriz prevista

Los tres roles nuevos son NOINHERIT, NOSUPERUSER, NOCREATEDB, NOCREATEROLE,
NOREPLICATION y NOBYPASSRLS; no memberships entrantes/salientes ni settings
persistentes. NOLOGIN por sí solo no impediría SET ROLE: se comprueban memberships.
La matriz exacta por columna y los hashes están en
[manifiesto D](../../tomopedidos-api/db/administration/manifests/b2a-roles-v1.yaml).

| Actor | Login y ownership | Derechos previstos | Denegaciones |
| --- | --- | --- | --- |
| tomopedidos_auth_executor | NOLOGIN; owner siete funciones normales C | USAGE identity; SELECT por columna; INSERT columnas de sesiones; UPDATE revisión, rehash, actividad y terminalidad; UPDATE(audience) solo para locks | Sin CONNECT, epochs global/audiencia, DELETE, DDL, ownership tablas, negocio ni memberships |
| tomopedidos_auth_revoke_executor | NOLOGIN; owner dos revocaciones C | USAGE identity; SELECT por columna; UPDATE epochs identidad/audiencia y expired_at para lock/terminalidad | Sin caller operativo, credenciales, INSERT sesiones, actividad/logout, CONNECT, DELETE, DDL ni memberships |
| tomopedidos_auth_runtime | LOGIN con PASSWORD NULL; no ownership | Tras habilitación separada: CONNECT local, USAGE identity, EXECUTE siete firmas normales | Sin DML directo, scopes privilegiados, helpers, CREATE/TEMP, negocio, memberships ni grant option |
| tomopedidos_runtime tenant | B1 conservado | Ningún derecho nuevo | Sin identity ni EXECUTE C/helpers; privilegios B1 de tenancy/authorization conservados |
| PUBLIC | No es rol autenticable | Ningún derecho identity/C | Sin ACL de schema, tabla/columna, helper o función C |
| tp_owner / migrator | B1 conservado | Ownership tablas / SET ROLE owner aprobado en B1 | D no amplía memberships ni usa estas credenciales en API |

FOR SHARE/UPDATE exige SELECT y UPDATE en al menos una columna. El ejecutor
normal usa UPDATE(audience) para bloquear audiencia, con guard B que impide
rekeying; no se le da UPDATE(auth_epoch) en audiencia. SELECT de sesiones se
enumera completo porque C usa `s.*`/ROWTYPE. Los grants son por columna, sin
grants de tabla, grant option, secuencias ni permisos de mantenimiento.
Fuentes oficiales consultadas: [GRANT PostgreSQL 18](https://www.postgresql.org/docs/18/sql-grant.html),
[SELECT/locks](https://www.postgresql.org/docs/18/sql-select.html),
[funciones de privilegios](https://www.postgresql.org/docs/18/functions-info.html),
[CREATE ROLE](https://www.postgresql.org/docs/18/sql-createrole.html).
La parada ante errores y los includes se revisaron contra
[psql PostgreSQL 18](https://www.postgresql.org/docs/18/app-psql.html).

## Archivos y orden de aplicación futura

No existe script que ejecute automáticamente toda la secuencia. Todos los paquetes
administrativos son para psql con ON_ERROR_STOP, transacciones propias e includes
relativos `\ir`; revisar y fijar el hash de **cada dependencia incluida**. No usar
estos includes como scripts independientes ni incluir paquetes con BEGIN/COMMIT
dentro de otra transacción. C es SQL separado, requiere cliente con parada ante errores.

1. Identificar host, instancia/volumen aislado desechable, PostgreSQL 18, base
   tomopedidos_local y administrador tomopedidos_bootstrap. Los guards de nombre
   no identifican host/volumen. Autorizar por separado el destino y operaciones.
   Revisar B1 existente sin repetir bootstrap; comparar A/B reales con columnas,
   tipos/defaults, constraints, cuerpos de guards, índices, owners y ACL esperados.
   Los guards de D no sustituyen una certificación completa del esquema A/B.
2. Aplicar A/B por Goose, usando el migrator y SET ROLE owner conforme B1, solo
   cuando estén autorizados. Sin migración al arrancar API. Revisar hashes y
   evidencia Up/Down e integridad antes de habilitar C/D.
3. Aplicar `b2a-role-provision-v1.sql`: crea solo los tres roles nuevos, exige que
   estén ausentes y no concede derechos. No instala contraseña ni configura HBA,
   pool, secretos, TLS o método de login. Revisar roles nuevos por lectura posterior.
4. Instalar C mediante administrador autorizado; roles ya existentes, A/B
   aplicados y certificados. Ownership de funciones se fija **en C**, no en Goose
   ni corrigiendo drift mediante D. ACL inicial owner-only. No callers habilitados.
5. Aplicar `b2a-auth-grants-v1.sql`: compara estado `c`, concede columnas a ambos
   ejecutores, reitera REVOKE por nueve firmas y verifica estado `executors` antes
   de COMMIT. No concede CONNECT/USAGE/EXECUTE a auth.
6. En conexión nueva, `040_b2a_role_isolation.sql` con `d_stage=executors`:
   metadatos/privilegios efectivos, PUBLIC, tenant, memberships, inventario,
   source hashes, parámetros y retornos de C; termina ROLLBACK. Probar además
   funciones bajo sus owners mínimos con fixtures autorizados, compilación de
   todos los caminos, permisos de locks/triggers, search_path/pg_temp hostil y
   ausencia de rutas indirectas. No sustituir esto por éxito del superusuario.
7. Solo tras revisión/evidencia y **autorización de habilitación separada**, aplicar
   `b2a-auth-enable-v1.sql`: verifica `executors`, concede CONNECT/USAGE y siete
   EXECUTE normales, vuelve a comprobar `enabled` antes de COMMIT. Los scopes
   privilegiados siguen owner-only y sin caller operativo.
8. En lectura nueva repetir 040 con `d_stage=enabled`. Después de un procedimiento
   de credenciales/autenticación autorizado, ejecutar 041 en dos conexiones TCP
   autenticadas independientemente, como auth y tenant: 26 y 33 negativos
   respectivamente, esperando SQLSTATE 42501 en cada caso y ROLLBACK final.
   No usar SET ROLE desde superusuario para acreditar denegación de SET ROLE:
   ese permiso depende de session_user. Registrar actor, destino, códigos y marcas.

PUBLIC se verifica en ACL (`grantee=0`): no admite SET ROLE ni sesión propia.
Las sesiones reales también reciben derechos PUBLIC; las aserciones y negativos
se complementan. 041 no acredita login hasta ejecutarse por autenticación real.
Sus intentos DDL/DML se encapsulan en subtransacciones: denegación pasa; cualquier
éxito inesperado aborta. No intenta TRUNCATE ni modifica fixtures existentes.
No es test funcional de emisión/validación/rehash; esos fixtures siguen pendientes.

## Drift, rollback y commit ambiguo

Cada paquete exige exactamente el estado anterior, rechaza roles preexistentes,
overloads/aliases, owners/fuentes/ACL inesperados, grants amplios/heredados,
memberships, settings, default ACL y dependencia de roles en otra base. No hay
IF NOT EXISTS, ownership takeover, retries ni limpieza automática de privilegios.
Aplicar por administrador superusuario no prueba aislamiento operativo.

Error antes de COMMIT: detener, registrar salida/código y hacer rollback/cerrar
conexión; no continuar la secuencia ni ajustar privilegios para aprobar un test.
Creación de roles/grants dentro de esa transacción no se considera persistida.

Después de COMMIT, una reversión requiere nueva autorización. D incluye
`b2a-auth-disable-v1.sql` (`enabled` → `executors`) y
`b2a-auth-ungrant-v1.sql` (`executors` → `c`). Verifican estado anterior y final,
revocan exclusivamente derechos D y preservan funciones/roles/A/B/B1. Primero
detener callers y drenar transacciones: revocar EXECUTE o CONNECT no cancela
sesiones ni llamadas ya iniciadas. No hay terminación automática de conexiones.
No ejecutar reversión a c mientras haya callers activos.

Si solo se provisionaron roles, no borrarlos automáticamente después de COMMIT:
son objetos del cluster y pueden tener dependencias en otras bases. C tampoco
se desinstala con estos reversores. Una retirada completa necesita inventario y
paquete revisado aparte, sin DROP OWNED/REASSIGN OWNED/DROP CASCADE.

Commit ambiguo: no afirmar éxito, entregar secretos ni repetir paquetes. Obtener
una conexión administrativa nueva, revisar roles y comparar estados c/executors/
enabled y hashes/ACL con manifiestos. Para provisión, comprobar ausencia/presencia
y atributos exactos; para grants usar aserciones de estado seleccionadas dentro
de transacción de lectura autorizada. Conservar la primera discrepancia y parar;
no probar distintos instaladores hasta que alguno pase. Registrar evidencia nueva
antes de decidir continuar o preparar reversión.

## Límites y bloqueos

No hay secretos en archivos. PASSWORD NULL evita password login, pero LOGIN no
impide trust/cert/peer: método HBA, credenciales privadas y acceso TCP se revisan
por separado; no se propone habilitar trust. No configurar credenciales en scripts
versionados ni imprimir PHC, digest, argumentos, bind parameters o claves CSRF en
logs. Los hashes son de archivos/cuerpos, no secretos ni evidencia de PostgreSQL.

Pendientes para ejecución: target aislado y autorización concreta, certificación
A/B, provisión C/D y pruebas con roles efectivos, revisión PLpgSQL y sintaxis de
los verificadores SQL, medición de timeouts/contención, fallos y commit ambiguo,
pruebas de pg_temp/search_path y logs. El enable no implica API funcional: Go
confiable sigue debiendo probar contraseña, rehash equivalente/no degradante,
autoridad/posesión/CSRF y commit. Argon2id benchmark y CSRF binario/keyring siguen
pendientes B2-B. No admin de identidad, MFA, cleanup, E/F ni negocio en D.
