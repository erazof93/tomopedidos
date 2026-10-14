# D2.1-B — propuesta de esquema y aislamiento PostgreSQL

Estado: **D2.1-B1 completada: 001/002 aplicados, 010/020 aprobados; TCP interno/Windows
y SET LOCAL ROLE tp_owner con identidad/search_path confirmados manualmente.
B2–B5 no implementados ni autorizados**. El diseño posterior conserva su carácter propuesto.
Estado concreto, privilegios y comandos: [preparación B1](../development-b1.md).
B2-D01 aprobada como diseño de correo; [registro consolidado B2](../decisions/B2-decisions.md).
B2-D01–D10 y recomendaciones técnicas finales B2-A aprobadas como diseño, incluidas
retención30d, ownership separado y revocaciones privilegiadas sin EXECUTE auth.
B2-A/B2-B sin autorización de implementación ni ejecución.
[Contrato B2-A y plan A–F](b2-a-specification.md): artefactos exactos/mediciones futuras,
no tablas/roles implementados ni pruebas verificadas. Parámetros D04/CSRF binario pendientes.
D2.1-A cerrada con evidencia del usuario de PostgreSQL y herramientas Docker.
Decisiones aprobadas: [ADR-003](../decisions/ADR-003-web-authentication-sessions.md),
[roles híbridos](roles-permissions.md), [gobierno](../decisions/ADR-002-role-governance-ownership.md)
y [tenancy](tenancy.md). Este documento concreta persistencia; no aprueba HTTP ni onboarding.

## Alcance y cambio respecto al plan anterior

El plan anterior limitaba D2.1-B a identidad/sesiones y ubicaba tenants/roles/RLS en D3.
La solicitud actual autoriza DISEÑAR también esos componentes. Recomendación: presentar
el esquema completo y dividir su implementación en cortes B1–B5, sujetos a aprobación,
sin considerar autorizada esta ampliación por estar documentada. Alternativa: implementar
solo B1/B2 y conservar B3–B5 como D3; los contratos HTTP y gobierno siguen en sus entregas.
No se implementará HTTP de autenticación, sesiones, tenant o roles en estos cortes.

## Inventario verificado

| Elemento vigente | Estado y consecuencia |
| --- | --- |
| API Go | go.mod 1.26.0, Chi 5.2.3, pgx/v5 5.7.6; go.sum presente; sin cambio de dependencias |
| Config | APP_ENV y HTTP_ADDR validados; sin DATABASE_URL, pool ni carga automática de .env |
| HTTP | Solo GET /healthz; DTOs/rutas auth/roles de documentos son propuestas |
| database.Executor | Solo Exec(context, SQL, args); no Query/QueryRow ni unidad de trabajo implementada |
| sqlc.yaml | schema db/schema; queries db/queries; output internal/database/sqlc; pgx/v5 |
| SQL backend | migrations/schema/queries contienen únicamente .gitkeep; ningún SQL funcional |
| Infraestructura | .env raíz, PostgreSQL 18.6 con digest, base local y loopback 55432; verificación externa |
| Goose Docker | docker/goose.Dockerfile, go install v3.29.0; sin Dockerfile raíz duplicado |
| sqlc Docker | sqlc/sqlc:1.31.1; tools/versions.json coincide |
| Montajes de herramientas | B1 corregido: Goose monta tomopedidos-api/db/migrations; sqlc solo backend en /app |
| Credenciales DB | B1 verificó migrador/runtime independientes; bootstrap reservado para aprovisionamiento |

Preflight de B1: corregir montaje Goose al directorio del backend y working_dir/bind de
sqlc a tomopedidos-api. Mantener un solo origen SQL, sin mover/copiar migraciones a raíz.
No eliminar db/ raíz ni volúmenes para corregir rutas. No exponer .env al contenedor
generador si puede montarse únicamente el backend. Pin de versiones ya está satisfecho;
digests/base images de herramientas pueden endurecerse posteriormente, sin cambiar versiones.

## Roles DB y schemas propuestos

| Rol | Privilegios previstos |
| --- | --- |
| tomopedidos_bootstrap | Solo aprovisionamiento explícito local; nunca pool API ni credencial de Goose habitual |
| tp_owner NOLOGIN | Propietario de schemas/tablas; runtime no puede asumirlo |
| tomopedidos_migrator LOGIN | Credencial separada, acceso controlado a tp_owner para DDL; sin superusuario/CREATEROLE/BYPASSRLS |
| tomopedidos_runtime LOGIN | Datos tenant mediante RLS, grants mínimos; sin ownership, DDL, CREATE, TRUNCATE ni roles privilegiados |
| tomopedidos_auth_runtime LOGIN, diseño aprobado D09; no creado | Pool auth separado; sin ownership/DDL/negocio/migración; grants por query pendientes |

Aprovisionar roles cluster con comando separado y revisable que requiere bootstrap;
no intentar CREATE ROLE desde migrador sin CREATEROLE. Goose versiona schemas/tablas,
grants/RLS; tabla de versión con ownership restringido. No incluir passwords en SQL,
Dockerfile, Git, CLI ni salida de Compose. Goose vigente fija tomopedidos_migrator;
su ejecución funcional/carga privada no se infiere del cierre B1.
Definir también GOOSE_DRIVER y datasource por variables revisadas, sin password en CLI;
las variables PG* y un comando -version no prueban que el flujo Up esté configurado.

Schemas candidatos: identity (cuentas/credenciales/sesiones), tenancy (restaurantes,
sucursales/membresías), authorization (catálogo/plantillas/copias/grants) y audit.
Revocar CREATE de consumidores en schemas compartidos, definir default privileges para
futuros objetos del mismo owner y grants explícitos. Pool platform independiente se
difiere; no usar Owner tenant como operador ni conceder catálogo SaaS a roles restaurante.

Alternativa al pool auth separado: un solo runtime con grants auth/tenant. Es más simple,
pero cualquier consulta arbitraria de esa credencial alcanza datos centrales sensibles;
requiere aceptar expresamente ese riesgo. Sesiones globales no se aíslan con tenant_id.

## Modelo relacional recomendado, aún sin DDL

UUID como IDs, timestamptz UTC, NOT NULL en relaciones obligatorias, estados cerrados y
versiones para concurrencia. Correo/estados/gramática/límites D01/D02 aprobados;
UUIDv4 Go y ciclo/revisión D03 aprobados; constraints exactos pendientes según registro B2.
Preferir ON DELETE RESTRICT y desactivación/revocación con historial, sin cascadas destructivas.

| Relación | Campos/constraints/índices candidatos |
| --- | --- |
| identity.identities | id UUIDv4 Go PK; email original + email_normalized UNIQUE; status, email_verified_at, auth_epoch, credential_revision durable, timestamps |
| identity.identity_credentials | identity_id PK/FK identities, relación opcional 0..1; password_hash PHC Argon2id v19 salt16/hash32, changed_at; sin password bruto |
| identity.sessions | id PK distinto del token, identity_id FK, audience admin/platform, token_hash UNIQUE, CSRF HMAC, auth_level/methods, epochs global/audiencia capturados, created/last_activity/idle/absolute/revoked/expired timestamps |
| identity.audience_revocations, si se aprueba | identity_id + audience PK/FK, epoch para revocación por audiencia; separado de global |
| tenancy.tenants | id PK; slug UNIQUE si se aprueba; name, status, timezone, authorization_version |
| tenancy.branches | id PK; tenant_id FK; code/name/status; UNIQUE(tenant_id,id), UNIQUE(tenant_id,code) |
| tenancy.memberships | id PK; tenant_id FK e identity_id FK; status/version/timestamps; UNIQUE(tenant_id,id), UNIQUE(tenant_id,identity_id) |
| authorization.permissions | code PK, action_scope, status, delegation_policy; backend controla catálogo, no códigos libres |
| authorization.role_templates / role_template_versions | Plantilla global con code UNIQUE; versión por plantilla; scope_kind y estado de publicación |
| authorization.role_template_permissions | FK versión y permission_code; PK de composición; publicación futura no altera copias |
| authorization.roles | id PK, tenant_id FK, code/name/scope_kind/protection_kind/status/version; UNIQUE(tenant_id,id), UNIQUE(tenant_id,code); procedencia template/version/source_role opcional |
| authorization.role_permissions | tenant_id + role_id + permission_code PK; FK compuesta Role y FK Permission; contenido independiente de plantilla |
| authorization.tenant_role_grants | tenant_id + membership_id + role_id UNIQUE; scope tenant explícito; status/version/revoked_at |
| authorization.branch_role_grants | tenant_id + branch_id + membership_id + role_id UNIQUE; branch_id NOT NULL; status/version/revoked_at |
| audit.security_audit_events | id PK, actor/entidad/tenant/branch/acción/resultado/fecha/request_id; sin tokens, hashes de password ni secretos CSRF; runtime no modifica/borra historial |

Usar identity_credentials para coincidir con el diseño general; el nombre password_credentials
del plan anterior queda como alternativa descartada del modelo propuesto, no tabla existente.
Catálogos SaaS, factores MFA, invitaciones, reset, transferencia y autorizaciones de delegación
detalladas se difieren hasta aprobar sus contratos. Registro central de storage continúa
previsto para Fase 1; no implementar bases dedicadas/pools por tenant en B.

### Integridad y scope

Grants deben referenciar Membership/Role/Branch por (tenant_id,id), no solo UUIDs sueltos.
Roles duplicados no copian grants ni protección Owner; source_role usa FK compuesta del tenant.
FK a plantilla/version global conserva procedencia, sin herencia viva.

Recomendar UNIQUE(tenant_id,id,scope_kind) en roles y columna constante scope_kind en grants:
tenant CHECK tenant; branch CHECK branch; FK completa bloquea asignar rol branch como tenant.
Un rol tenant puede contener permisos branch (Owner opera sus sucursales) y tenant; un rol
branch no contiene permisos tenant. Proponer role_permissions con scope de rol/permiso
respaldados por FKs a Role/Permission y CHECK de combinación, sin consultar tablas desde CHECK.

Índices adicionales: memberships(identity_id,status), grants(tenant_id,membership_id,status),
branch_grants(tenant_id,branch_id,status), role_permissions(tenant_id,role_id),
sessions(identity_id,audience,revoked_at), vencimiento para cleanup y audit(tenant_id,occurred_at).
FK no crea automáticamente todos los índices del lado que referencia. Revisar con consultas
reales antes de añadir índices redundantes. Unicidad global de email pertenece a Identity;
códigos branch/role no filtran otros tenants por unicidad global accidental.

### Sesiones y garantías aprobadas

Admin: idle 12 h/absoluto 7 días; platform: 15 min/8 h. Token opaco revocable, nunca roles
o tenant mutable en sesión. CHECK de audiencia/nivel y coherencia temporal; recomendar
digest SHA-256 BYTEA32 aprobado por D05. Expiración se valida al usar
la sesión, no mediante CHECK dependiente de now(). Actividad explícita no revive sesión
ni mueve ancla absoluta; polling no renueva. Epoch/emisión/revocación deben ser atómicos.

Password correcto no basta para emitir sesión platform. El esquema puede rechazar nivel
password en audiencia platform, pero no acredita que MFA ocurrió: solo código auth confiable
podrá emitirla después de un flujo MFA real aprobado. No emitir sesiones utilizables en B.
CSRF HMAC D06 y epoch por audiencia D07 aprobados; formato/codificación/runbook,
DDL/grants/timeouts/retención pendientes. Expired_at terminal D10 aprobado.
Challenges/proofs se difieren;
no inventar columnas obligatorias provisionales.

### Gobierno y auditoría

Último Owner activo protegido, permisos críticos no editables, delegación expresa y archivo
sin asignaciones activas conservan ADR-001/002. No se garantizan con un CHECK de una fila:
proponer transacciones serializadas por tenant y mutaciones críticas controladas/auditadas,
incluyendo desactivar Identity en todos sus tenants. Runtime no tendrá DML genérico que
permita eludir guards críticos; concretar procedimientos/grants y catálogo Owner antes
de habilitar aprovisionamiento activo. Fixtures no equivalen a onboarding real.

No seed de restaurantes/identidades reales. Catálogo/plantillas iniciales requieren revisión
de permisos críticos; caja/cocina/delivery quedan como módulos futuros, no seeds prematuros.
Historial de cambios y archivo conserva referencias; estados/reasignaciones no borran grants.

## RLS y unidad de trabajo propuesta

ENABLE RLS y FORCE RLS en tablas tenant, con USING y WITH CHECK de tenant confiable.
Runtime no es owner/superusuario/BYPASSRLS. Contexto ausente deniega; scope tenant explícito,
branch null/vacía jamás implica acceso consolidado. Branch/acción se valida en Go y se
proponen políticas branch cuando corresponda, sin llamar aislamiento branch a RLS tenant.

Identity validada → resolver membresía vigente y destino permitido → abrir pgx.Tx →
set_config de actor/tenant/scope con true y parámetros → consultas sqlc de esa tx → commit
o rollback explícito antes de liberar conexión. No SET de sesión ni contexto tenant en
AfterConnect. Validar alcance antes de convertir IDs de body/header en contexto confiable.
Resolver self-listing de memberships sin tenant activo mediante consulta/política dedicada
solo para la Identity validada; no abrir lectura general por una política OR demasiado amplia.

Políticas que consulten grants/memberships necesitan helpers no recursivos y matriz de
privilegios revisada. SECURITY DEFINER solo si se justifica: owner limitado, search_path
fijo, referencias qualified, EXECUTE no PUBLIC, sin SQL dinámico ni bypass genérico por tenant.
Un runtime comprometido capaz de cambiar GUC no se vuelve seguro por RLS; Go parametrizado,
frontera confiable y mínimos grants siguen necesarios. No prometer aislamiento frente a
superusuario ni exponer errores FK/UNIQUE que revelen IDs ajenos.

Fuentes: [RLS PostgreSQL 18](https://www.postgresql.org/docs/18/ddl-rowsecurity.html),
[SET LOCAL](https://www.postgresql.org/docs/18/sql-set.html) y
[sqlc WithTx](https://docs.sqlc.dev/en/latest/howto/transactions.html).

## Orden de entrega/migraciones propuesto

Los nombres siguientes son orientativos, no migraciones existentes. B1 ya preparó SQL
de bootstrap/verificación fuera de migrations; no se aplicó ni creó SQL funcional de B2–B5.

| Corte | Orden propuesto | Gate antes de aplicar |
| --- | --- | --- |
| B1 | Preflight rutas Docker; aprovisionamiento local separado de roles; 00001_schemas_privileges | Aprobar pools/roles/credenciales; bootstrap solo aprovisiona, API nunca migra al arrancar |
| B2 | 00002_identity_credentials; 00003_sessions_revocation | Aprobar email, CSRF, epochs/estados y constraints; sin login HTTP ni MFA simulado |
| B3 | 00004_tenants_branches_memberships | Aprobar estados y política de aprovisionamiento; FKs compuestas verificadas |
| B4 | 00005_permission_templates_roles; 00006_role_grants_audit | Aprobar catálogo/scope/Owner y guards sensibles antes de tenants activos |
| B5 | 00007_rls_policies_helpers; grants finales e índices | Tablas tenant con runtime sin acceso hasta políticas listas; fixtures y matriz negativa aprobadas |

Puede dividirse cada archivo para revisión. No abrir grants tenant en una migración intermedia
sin RLS. Rollback/destrucción solo en base exclusiva de pruebas desechables autorizada;
no down sobre tomopedidos_local con datos útiles. Migraciones aplicadas no se reescriben.

## Pruebas posteriores exigidas, no ejecutadas

Harness PostgreSQL 18 real, roles runtime sin bypass, dos tenants; uno con tres sucursales,
Owner tenant/cajeras branch y una Identity con membresías en ambos. Fixtures ficticias.

| Caso negativo | Resultado requerido |
| --- | --- |
| Runtime crea/ALTER/TRUNCATE, asume migrador/owner o lee credenciales desde pool tenant | Denegado; harness falla si usa superusuario por accidente |
| SELECT/UPDATE/DELETE sin filtro sobre filas tenant | Solo scope autorizado; contexto ausente/invalidado nunca abre lectura/escritura |
| INSERT o cambio tenant_id hacia otro restaurante | WITH CHECK/FK bloquean; sin efectos parciales |
| Grant combina Role/Membership/Branch ajenos | FK compuesta rechaza; branch null y rol de scope incorrecto también |
| Cajera S1 recibe permiso extra | No lectura/mutación S2/S3; consolidado solo con tenant grant válido |
| Self-listing memberships | Solo propias; no revela contactos, sesiones o membresías de otra Identity |
| Pool A→B, rollback/error/cancelación/savepoint | Sin contexto residual ni tx abandonada; consultas tenant nunca usan pool sin tx |
| Grant/membership revocado concurrentemente | Nuevas solicitudes posteriores al commit pierden autorización; in-flight no se promete retroactivo |
| Rol compartido editado fuera del envelope / archivo con grants activos | Guard rechaza; duplicación no copia grants/protección Owner |
| Dos bajas concurrentes del último Owner | Una falla, queda Owner activo; no habilitar mutación antes de tener este guard probado |
| Sesión expira exactamente en idle/absoluto; polling; revocación | Expirada denegada, polling no prolonga; nueva autorización tras revocación falla |
| Copia de plantilla vs nueva versión | Copia independiente; operador/restaurante sin catálogo cruzado |
| Fracaso de migración/constraint/auditoría | Rollback íntegro, sin token ni éxito publicado; errores sin secretos/IDs ajenos |

Después de autorizar implementación: Goose Up en base de pruebas vacía, snapshot db/schema
comparado con estado migrado, sqlc compile/generate reproducibles, go test/vet/build y
pruebas de pool/concurrencia. Esto no certifica aún CSRF/Origin/cookies/HTTP ni MFA de navegador.

## Integración posterior y aprobación requerida

Mantener sqlc.yaml como contrato actual de generación. Ampliar/sustituir Executor solo cuando
queries generadas exijan Exec/Query/QueryRow; usar WithTx, no editar output generado.
Diseñar repositorios globales auth separados de repositorios tenant. Config Go futura valida
DSN y timeouts por pool, sin cargar credenciales migrador ni cambiar /healthz por este diseño.
Contratos HTTP siguen en D1.1/roles: rutas, DTOs, estados y errors aún no implementados.

Pendientes antes de implementar: alcance B1–B5 frente a conservar B3–B5 en D3; roles/pools
auth separado; detalles de correo B2-D01 y estados; representación CSRF/claves y epochs; scopes/FKs
del catálogo; guards/permiso crítico Owner y autoría de seed; helpers RLS/self-listing;
política de archivo/historial y presupuesto de conexiones. MFA exacto, transferencia,
onboarding/reset y DB dedicada no se cierran aquí.

Recomendación de siguiente acción: aprobar alcance y decisiones de esquema; autorizar
primero B1 (rutas y roles/grants locales revisados), verificarlo y continuar por cortes.
La autorización debe indicar si incluye aplicación de migraciones sobre una base local
de pruebas; este documento no la concede. B1 modificó rutas Compose y preparó scripts;
no se ejecutó SQL ni se modificó DB/Celtas.
