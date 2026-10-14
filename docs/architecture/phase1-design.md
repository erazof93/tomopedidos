# Fase 1 — propuesta técnica para revisión

Estado: diseño funcional no implementado; D2.1-A completada mediante Docker con evidencia
usuario según [guía local](../local-postgresql.md). Roles híbridos y cinco políticas de gobierno aprobados,
autenticación/sesiones y persistencia local aprobadas en ADR-003; otras elecciones
siguen propuestas. Fase 1 avanzó únicamente en infraestructura D2.1-A. Revisados código/configs y contratos
actuales de API, admin y platform; backend aún solo expone /healthz.
La Fase 0 se considera cerrada conforme a la instrucción del usuario. Los archivos actuales
PROJECT_CONTEXT/ROADMAP reflejan su cierre por confirmación del usuario y el avance
limitado D2.1-A. No se declara completada Fase 1.

## 1. Base aprobada y hallazgos

Ya aprobados: Go/Chi/pgx/sqlc, monolito modular, PostgreSQL compartido con aislamiento tenant
y dedicadas futuras; dos SPA React/TS/Vite; núcleo sin Flutter/FCM ni autenticación externa.
Tenant es restaurante; Branch es sucursal; Identity puede pertenecer a varios tenants.
Operador SaaS y restaurante deben tener permisos separados.
Roles híbridos también aprobados: plantillas globales, copias tenant iniciales, duplicación
y personalización controladas, catálogo backend y grants tenant/branch explícitos.
[ADR-001](../decisions/ADR-001-hybrid-roles.md) registra alcance aprobado y políticas pendientes.
[ADR-002](../decisions/ADR-002-role-governance-ownership.md) consolida administración
delegada, transferencia reforzada, Owner protegido, copias independientes y archivo.

Verificado en archivos:
- API: Go mínimo 1.26.0, Chi 5.2.3, pgx 5.7.6; x/crypto 0.37.0 indirecto. Solo /healthz,
  configuración/shutdown y pruebas de config/health. No auth, pools ni módulos.
- db/schema, queries y migrations contienen solo .gitkeep; sqlc preparado para pgx/v5.
  Executor solo declara Exec: no es suficiente como DBTX para futuras consultas sqlc.
- Paneles: React 19, TS 6, Vite 8, Query 5, RHF/Zod; pantallas iniciales, QueryClient vacío,
  sin cliente HTTP ni router/session provider. VITE_API_BASE_URL apunta a localhost.
- pnpm 11.22.0, Node 24, lock y go.sum presentes. Sin Firebase, Next.js ni OAuth en manifests.
- Docker ejecutable visible; daemon/imágenes no comprobados. sqlc/Goose/psql no encontrados
  en PATH. No se ejecutaron tests, servicios, instalaciones, SQL ni migraciones en este diseño.

Ya aprobados: propietario administra y autoriza delegados con envelope expreso; traspaso
con solicitud/invitación/aceptación/verificación reforzada/auditoría; garantías críticas
Owner, copias independientes y archivo solo sin asignaciones activas.
No aprueba automáticamente factores de identidad, máximo/gobierno de propietarios,
DTOs/locks ni el resto de decisiones de sesión/onboarding/PostgreSQL.

## 2. Límites de módulos y confianza

Proponer identity (credenciales/sesiones), tenancy (Tenant/Branch/Membership),
authorization (catálogo/grants/políticas), platform (operador/registro central)
y audit (eventos de seguridad). Infrastructure provee transacciones/repositorios,
HTTP adapta DTOs. No crear microservicios, buses ni jerarquías abstractas de repositorios.

Separar datos centrales de identidad/control del SaaS y datos operativos tenant.
Inicialmente comparten instancia/base PostgreSQL, con schemas y roles de BD explícitos.
Control central conserva identidades, sesiones, membresías, permisos y asignación de storage.
En Fase 1 solo existe ubicación compartida; no crear pools dedicados por tenant.

Amenazas: IDOR/BOLA, tenant/branch suplantado, grants cruzados, escalación, sesión robada,
CSRF, inyección SQL, cachés mezcladas y conexiones con contexto residual.
RLS defiende consultas mal acotadas; no garantiza aislamiento ante control arbitrario del
backend/credenciales DB o SQL que pueda cambiar todos los GUC. Parámetros SQL, mínimos
privilegios y frontera de contexto confiable siguen siendo necesarios.

## 3. Modelo relacional recomendado

UUID opacos y timestamps timestamptz. IDs no son permisos ni secretos.
Email normalizado con política explícita y unicidad global; no aplicar reglas específicas
de Gmail (puntos/+aliases). Conservar email de presentación y verificación separada.
Una ficha de cliente comercial futura no equivale a Identity.

| Relación | Campos/constraints principales | Responsabilidad |
| --- | --- | --- |
| identities | id, email_normalized UNIQUE, email, status, email_verified_at, timestamps | Cuenta global, sin rol tenant incrustado |
| identity_credentials | identity_id FK/UNIQUE, password_hash, changed_at | Credenciales separadas del perfil; nunca DTO público |
| sessions | id, identity_id, token_hash UNIQUE, audience, idle/absolute_expires_at, revoked_at, auth_level, timestamps | Sesión central de admin o platform |
| tenants | id, slug UNIQUE, name, status, timezone, authorization_version | Restaurante, no identidad |
| branches | id, tenant_id FK, code, name, status; UNIQUE(tenant_id,id), UNIQUE(tenant_id,code) | Sucursal de un tenant |
| memberships | id, tenant_id, identity_id, status, timestamps; UNIQUE(tenant_id,identity_id), UNIQUE(tenant_id,id) | Pertenencia, con revocación/reactivación auditada |
| permissions | code PK, action_scope (tenant/branch), status, delegation_policy, description | Catálogo backend; usar no implica poder delegar |
| role_templates | id, code UNIQUE, name, status | Global; restaurante solo consume, no edita |
| role_template_versions | template_id + version PK, scope_kind, published_at | Snapshot publicado; recomendar inmutabilidad |
| role_template_permissions | template_id + version + permission_code PK | Permisos explícitos de cada versión global |
| roles | id, tenant_id, code/name, scope_kind, protection_kind, status, version; UNIQUE(tenant_id,id), UNIQUE(tenant_id,code) | Copia/custom tenant; procedencia de plantilla/rol sin herencia viva |
| role_permissions | tenant_id, role_id, permission_code | Asociación M:N, catálogo revisado |
| tenant_role_grants | tenant_id, membership_id, role_id; UNIQUE de la terna | Permisos de alcance tenant |
| branch_role_grants | tenant_id, branch_id, membership_id, role_id; UNIQUE del conjunto | Permisos para esa sucursal |
| platform_memberships / platform_roles / platform_grants | identity_id y roles de operador en catálogo independiente | Alcance SaaS, nunca tenant_id comodín |
| tenant_storage_assignments | tenant_id UNIQUE, location_id, mode, schema_version | Registro central; referencia de ubicación, nunca DSN público |
| security_audit_events | actor/session identificadores internos, ámbito, acción, resultado, fecha, request_id | Historial sin tokens/passwords |

Complementos de identidad, cuando se apruebe su flujo: invitations, password_reset_tokens
y mfa_factors/recovery_codes. Tokens de invitación/reset almacenados como hashes, con
expiración, destinatario/tenant vinculados y consumo único transaccional.

Constraints importantes:
- Grants referencian Membership, Role y Branch mediante FKs compuestas con tenant_id.
  No basta con que todos sus IDs existan individualmente.
- Roles de sucursal solo incluyen acciones branch; grants tenant solo aceptan roles tenant.
  Recomendar tipos de ámbito explícitos y constraints/FKs auxiliares para verificarlo en BD,
  no solo formularios. Evitar una tabla de grants con branch_id NULL interpretado como acceso total.
- Unicidad de códigos comerciales por tenant; no unicidad global accidental que filtre
  existencia de recursos de otros restaurantes mediante errores.
- Desactivar membresías/sucursales en vez de borrar su historia.
- Owner como rol tenant protegido. Serializar transferencias/revocaciones en la fila Tenant
  e impedir dejar el restaurante sin owner activo. No asignarlo por el endpoint genérico de roles.
  Permisos críticos no eliminables desde editor ni cambios/archivo que destruyan garantías.
  Flujo obligatorio de transferencia aprobado; máximo, factores y gobierno detallado pendientes.
- Índices por tenant/sucursal y por identity_id para listar membresías propias;
  foreign keys compuestas no sustituyen índices de lectura.

Roles iniciales sugeridos: owner con alcance tenant y administrador de sucursal.
Caja/cocina y sus permisos de negocio se agregan cuando existan módulos correspondientes.
Plantillas globales no editables por restaurantes. Copias propias duplicables y
personalizables forman parte del alcance aprobado de Fase 1; no permisos wildcard.
Copias independientes sin cambios de plantilla propagados automáticamente: aprobado.
Recomendar formato de snapshot/versionado para registrar procedencia.
Modelo completo, constraints de origen, matriz y pruebas en
[roles-permissions.md](roles-permissions.md), evitando duplicar sus reglas aquí.

## 4. Autorización efectiva

La sesión autentica Identity, no selecciona globalmente un restaurante para todas las pestañas.
Cada request usa tenant_id y, cuando corresponde, branch_id del path; el servidor comprueba
Membership activa, Branch perteneciente y grant efectivo. Headers/body no cambian ese contexto.

Para acción branch: permiso concedido por rol tenant que cubre sucursales o por grant de
esa misma branch. Para acción tenant: únicamente un grant tenant apropiado.
Un administrador de branch A no ve branch B ni reportes consolidados del tenant.
Consultas de listas se acotan también; no cargar todo y ocultar filas en React.
Permisos múltiples se suman; sin deny overrides iniciales, cuyos conflictos serían más complejos.

Comprobar estado de Identity, sesión, Tenant, Membership y recurso. Denegar desconocidos.
Separar permiso de acción y entitlement comercial: ambos se exigen cuando exista módulo
contratado; no implementar planes/pagos en Fase 1.
Un endpoint de roles/grants no permite asignar ámbitos fuera de la autoridad delegable
del actor, permisos superiores ni ownership protegido. Poseer un permiso no implica poder
delegarlo. Una edición comprueba todos los grants afectados, no solo el scope del request.
Propietario puede autorizar administradores de roles, pero la autorización expresa
de gestión/delegación es distinta del permiso de uso. Su modelo propuesto aparece en
roles-permissions.md. El flujo de transferencia requiere verificación reforzada obligatoria;
su mecanismo concreto, expiración y efecto sobre propietario anterior aún no aprobados.

Obligatorio: solicitudes nuevas tras commit de cambios en roles/grants/membresías deben
reflejar permisos actuales y denegar los retirados. Recomendar lectura BD por request,
sin claims autoritativos de permisos en cookie/JWT ni fallback a caché obsoleta.
authorization_version sirve para concurrencia/invalidation, no sustituye revocación.

Garantía aprobada para nuevas solicitudes; recomendar que requests ya autorizados puedan
finalizar y acordar su semántica aparte. Para escrituras sensibles, acordar bloqueos de
filas de sesión/tenant/membresía y orden uniforme con revocación, de modo que el efecto y
la revocación tengan orden transaccional claro. Evitar upgrades de locks y probar concurrencia.
No prometer revocación retroactiva de respuestas emitidas. SSE futuro necesitará cierre
o revalidación de conexiones activas y un plazo máximo acordado.

## 5. Autenticación web y alternativas

Sesiones opacas en PostgreSQL y revocación server-side son decisiones existentes confirmadas
por el usuario en D1.1. No se reabren como elección frente a JWT para la web.
Identity global, permisos por solicitud y núcleo sin proveedor de auth siguen aprobados.
Las políticas aprobadas de email/password, cookies, expiración, MFA y logout global
están en [ADR-003](../decisions/ADR-003-web-authentication-sessions.md).
Contrato único, política de cookies, amenazas y doce ejemplos:
[web-authentication.md](web-authentication.md).
Admin: 12 h de inactividad y 7 días absolutos; platform: 15 min y 8 h, aprobados.
Solo actividad autenticada explícita renueva inactividad, nunca polling ni GET session.
Onboarding/reset/email verificado y recuperación reforzada siguen pendientes.

## 6. CSRF, CORS y sesiones separadas

CSRF/CORS restrictivo y separación de seguridad admin/platform aprobados; su protocolo
concreto sigue propuesto. D1.1 define challenge prelogin, CSRF estable por sesión,
Origin/Fetch Metadata, audiencias y cookies separadas; no MFA completo con solo password.
La autorización tenant/branch no se vuelve un estado mutable de sesión entre pestañas.
Detalle y pruebas en [contrato web](web-authentication.md#csrf-y-cors).

## 7. PostgreSQL, RLS y pgx

### Roles y bootstrap

| Rol DB propuesto | Acceso |
| --- | --- |
| tp_migrator / owner NOLOGIN | DDL/esquema; separado de web, sin credenciales en panel |
| tp_auth | Operaciones estrechas de lookup/gestión de sesiones/credenciales; sin datos operativos |
| tp_tenant | Datos/membresías autorizadas mediante RLS, sin owner/BYPASSRLS |
| tp_platform | Registro/control SaaS permitido; sin grants sobre datos operativos tenant |

Roles humanos no son roles PostgreSQL por usuario. Pools pequeños por clase de acceso,
presupuesto total de conexiones y límites/timeouts; no pool por restaurante en compartida.
Runtime sin CREATE/SET ROLE a roles privilegiados, sin DDL/TRUNCATE/REFERENCES innecesarios.

Auth/globales requieren frontera específica: permisos DB mínimos y funciones de lookup
por token/email estrictas, sin exposición HTTP de listado de credenciales.
Si se usan SECURITY DEFINER para bootstrap, owner NOLOGIN limitado, search_path seguro,
nombres schema-qualified, sin SQL dinámico y EXECUTE retirado de PUBLIC.
No crear una función genérica que reciba cualquier tenant y salte RLS.
Membresías propias pueden listarse con contexto Identity y RLS self-read, sin tenant activo.
Autorización de acciones debe estar en servicios; helpers/políticas no se llaman recursivamente.

### Políticas y transacción

RLS en tablas tenant con ENABLE y FORCE ROW LEVEL SECURITY, USING y WITH CHECK;
contexto ausente/inválido produce denegación. Políticas exigen tenant_id igual al contexto
y Membership activa del actor para ese tenant; no basta con que dos IDs coincidan.
Para datos branch comprobar alcance tenant explícitamente concedido o grant de esa branch,
con roles/grants activos; no aceptar una branch solo porque llegó en un GUC.
La autorización fina por acción permanece en el servicio. Conservar filtros explícitos en SQL.
Combinar barreras con cuidado: varias políticas permissive se unen mediante OR; una política
de owner/operador no debe abrir todos los tenants. Ownership/superusuarios/BYPASSRLS
no son roles runtime. Constraints y FK no sustituyen políticas; sus errores pueden revelar
existencia ajena, por lo que DTOs/errores se normalizan.
Referencia técnica: [PostgreSQL RLS](https://www.postgresql.org/docs/current/ddl-rowsecurity.html)
y [CREATE POLICY](https://www.postgresql.org/docs/current/sql-createpolicy.html).

Flujo obligatorio de unidad de trabajo:
1. Validar cookie/audience/sesión y obtener Identity confiable por frontera auth.
2. Resolver tenant solicitado y ubicación; iniciar transacción en pool correspondiente.
3. Establecer actor Identity validado con set_config(..., true); comprobar membresía/estado
   y scope permitido dentro de la frontera autorizada. Nunca desde IDs sin validar.
4. Establecer tenant y branch/modo autorizado dentro de esa misma transacción; branch vacío
   no significa todas. Consolidado exige permiso específico y verificación de alcance.
5. Ejecutar consultas sqlc vinculadas a pgx.Tx, nunca al pool global para datos tenant.
6. Commit si todo termina; rollback en error/panic/cancelación antes de liberar conexión.
   Limitar duración; no HTTP/email/SSE dentro de transacciones.

El tercer argumento true de set_config acota el valor a la transacción;
no usar SET de sesión/AfterConnect para un tenant. No construir SET mediante concatenación.
[PostgreSQL set_config](https://www.postgresql.org/docs/current/functions-admin.html).
sqlc provee WithTx; asociar queries a tx, sustituyendo el Executor preliminar cuando haya SQL.
[sqlc transactions](https://docs.sqlc.dev/en/latest/howto/transactions.html).
pgxpool.Begin no hace rollback automático al cancelar el contexto; limpieza explícita
con plazo limitado y contexto de cleanup válido, cerrando conexión si no puede recuperarse.
[pgxpool](https://pkg.go.dev/github.com/jackc/pgx/v5/pgxpool).

No insertar claims de branch arbitrary en GUC sin comprobar grants; pruebas SQL directas
deben demostrar no solo filtros HTTP. Políticas que consultan grants necesitan revisar
performance, privilegios, recursión y concurrencia; comenzar con scopes simples y medidos.

### Futuras dedicadas

Centralizar identidad/sesiones/autorización/asignación; una DB dedicada no contiene passwords.
No hay FKs entre bases: necesitará proyección local de tenant/branches para constraints,
versionado y sincronización controlada. Resolver storage desde servidor, nunca DSN del cliente.
Schema/políticas uniformes; no eliminar checks por ser dedicada.
Revocación y bloqueo atómico entre bases no se heredan de compartida: antes de Fase 9
definir consistencia, leases/versiones y máximo desfase, sin transacciones distribuidas.

## 8. Plataforma del operador

Namespace HTTP y audiencia distintos, servicios/autorización y pool platform separados
dentro del mismo monolito. Superadmin SaaS no es owner de todos los restaurantes.
Platform administra metadata/provisión/asignación; no pedidos/clientes/membresías a través
de rutas tenant sin autorización específica.
Proponer roles limitados provisioning/support/audit; billing se implementa en su fase.
No impersonation inicial. Soporte futuro: concesión explícita temporal por tenant,
motivo, consentimiento cuando aplique, reautenticación y auditoría; no bypass global.
Bootstrap del primer operador como procedimiento local de una sola vez, sin endpoint público,
password por defecto, secretos en seeds o credenciales hardcodeadas.

Auditoría de login/logout/revocación, permisos, invitaciones, owners y acciones platform.
Runtime sin UPDATE/DELETE sobre eventos de auditoría. Operaciones exitosas y audit event
en misma transacción; intentos rechazados deben registrarse aunque el comando haga rollback.
No logging de cookie, CSRF/reset/invite tokens, password hash o DSN.

## 9. Contratos HTTP iniciales propuestos

Versionar bajo /api/v1 para admin y /api/platform/v1 para operador.
Los nombres/DTOs son propuesta, no contratos vigentes.

| Método / ruta admin | Función / condición |
| --- | --- |
| POST /api/v1/auth/challenge | Challenge prelogin; Origin/JSON/rate limit, sin sesión autenticada |
| POST /api/v1/auth/sessions | Login admin/challenge, nueva cookie; 201 o 401 genérico; platform puede quedar MFA pendiente |
| GET /api/v1/auth/session | Identity y expiración de esta audiencia; 200/401 |
| GET /api/v1/auth/csrf | Token vinculado a sesión, no-store; no cambiar negocio |
| DELETE /api/v1/auth/session | Logout server-side/CSRF; 204 |
| DELETE /api/v1/auth/sessions | Scope current_audience/all_audiences explícito, proof reciente y CSRF |
| GET /api/v1/me/tenants | Membresías/tenants propios, metadata mínima paginada |
| GET /api/v1/tenants/{tid}/access | Capacidades/sucursales efectivas; nunca conceder por UI |
| GET/POST /api/v1/tenants/{tid}/branches | Lista filtrada / creación con permiso tenant |
| PATCH /api/v1/tenants/{tid}/branches/{bid} | Config/estado autorizado; no cambiar tenant_id |
| GET /api/v1/tenants/{tid}/memberships | Listado con permiso tenant; branch admin no recibe padrón global |
| POST /api/v1/tenants/{tid}/invitations | Invitación segura, actor con permiso de invitación |
| PATCH /api/v1/tenants/{tid}/memberships/{mid} | Estado permitido; preservar último Owner; grants por rutas explícitas |
| GET /api/v1/tenants/{tid}/roles | Roles tenant autorizados, incluidas copias personalizadas |

La especificación auth, incluyendo cookies/error/CSRF/reauth/activity/MFA, se mantiene
únicamente en [web-authentication.md](web-authentication.md#contratos-http-propuestos).
La tabla anterior es índice; no endpoints implementados.

Gestión híbrida: lectura de plantillas/catálogo, crear copia, duplicar, editar, archivar
y asignar/revocar por rutas tenant o branch distintas, propuestas en
[contratos de roles](roles-permissions.md#contratos-http-propuestos-no-vigentes).
Esas rutas no existen en el router Go actual; no se añade implementación en esta tarea.
Archivo de rol con asignaciones activas se rechaza, incluidos grants todavía activos
de membresías suspendidas. Reasignar/revocar antes, manteniendo FKs/auditoría.
La invitación de propiedad no otorga Owner sin aceptación/verificación; su workflow
está aprobado aunque DTOs/estados y mecanismo de verificación sigan propuestos.

Rutas platform: auth/challenge/sessions/session/csrf análogas pero audience platform;
GET/POST /api/platform/v1/tenants, GET/PATCH tenant metadata y GET asignación de storage.
Crear tenant solo desde platform inicialmente; alta tenant/branch/owner/asignación y auditoría
atómicas/idempotentes en compartida. Asignar dedicada no es un endpoint funcional de Fase 1.
Activación invitación/reset/MFA requieren contratos separados aprobados antes de ese corte.

Errores: 401 para sesión inválida; 403 para acción denegada sobre ámbito visible; 404
uniforme para tenant/recurso ajeno o inexistente; 409 para conflicto permitido; 429 para límites.
Envelope de error con code público estable, mensaje seguro y request_id; sin SQL/constraints.
IDs tenant/branch de path no se aceptan de nuevo como autoridad en body.
DTOs explícitos impiden mass assignment; paginación cursor/tamaño máximo.
POST provisioning usa Idempotency-Key scoped a actor/acción + hash payload.
Cambios de grants/owner se serializan; version esperado/If-Match a definir para evitar lost updates.

Paneles: client fetch con cookies y header CSRF; SessionProvider/bootstrap central por app.
Ruta protegida es UX, backend autoriza. Abort/reseteo de queries y drafts al logout/cambio
de contexto; claves Query incluyen tenant/branch. Selección por pestaña, sin tenant activo
global de sesión que cambie requests de otras pestañas. No persistir datos privados en disco.
Router explícito será nueva dependencia revisada cuando se implemente, no agregada ahora.

## 10. Herramientas, migraciones y pruebas

PostgreSQL local Docker, Goose SQL y sqlc son elecciones existentes confirmadas en D1.1.
No reabrir migrador como golang-migrate en este corte ni migrar al arrancar HTTP.
Goose permite migraciones SQL incrementales; versión CLI debe fijarse antes de usarla.
[Goose oficial](https://github.com/pressly/goose/blob/main/README.md).
PostgreSQL local efímero, sqlc/Goose fijados, binarios/containers locales reproducibles;
imagen con versión/digest y rol migrador separado. Sin instalar globalmente sin autorización.
Docker Compose local configurado en D2.1-A; imagen/digest y herramientas fijados en
[guía local](../local-postgresql.md), verificados por usuario mediante Docker; Engine de Codex bloqueado.
Credenciales runtime/migrador y grants efectivos pendientes de D2.1-B. SQLite/mocks no prueban RLS.
El [diseño B actualizado](d2-1-b-schema-design.md) propone incorporar tablas tenant/roles/RLS
antes asignadas a D3, sujeto a aprobación; este cambio de agrupación no autoriza ejecución.
No introducir Redis o proveedor de auth en este corte.

Orden SQL previsto: schemas/roles y grants → identidad/credenciales/sesiones →
Tenant/Branch/Membership → catálogo/plantillas/copias/grants/constraints → storage/auditoría →
RLS/helpers/índices y catálogo mínimo. No redactar/ejecutar SQL ahora.
Estado de aprovisionamiento evita exponer tenant sin owner/sucursal/asignación coherentes.
Rollback local probado; migraciones aplicadas inmutables, cambios posteriores incrementales.
Snapshots db/schema para sqlc comparados contra una base local migrada, evitando drift.
Fixtures de tests separadas de catálogo/bootstraps operativos, sin secretos reales.

| Prueba negativa | Resultado exigido |
| --- | --- |
| A solicita tenant/recurso B por path, body o header | 404 seguro, sin datos ni efectos |
| Identity con memberships A/B y roles distintos | No mezcla permisos por seleccionar otro tenant |
| Admin branch A lee/muta branch B o consolidado | Denegado aunque ambas sean del mismo tenant |
| FK combina membership/role/branch de distintos tenants | Constraint impide persistir grant |
| Sin actor/tenant/scope, contexto vacío/ilegítimo | SQL tenant no revela ni escribe filas |
| INSERT/UPDATE intenta tenant_id o branch_id ajeno | WITH CHECK/constraints bloquean |
| SELECT/UPDATE/DELETE masivo olvidando filtro aplicación | RLS mantiene alcance; verificar también joins/export/listas |
| Pool con MaxConns=1 alterna A/B, commit/rollback/panic/cancel | Sin contexto heredado ni transacción abierta |
| Test con rol owner/superusuario accidental | Harness falla; pruebas reales solo con runtime sin bypass |
| Logout/cambio password/Identity bloqueada | Replay cookie rechazado; permisos no sobreviven revocación |
| Membership revocada o grant retirado | Nueva evaluación deniega; otras membresías siguen válidas |
| Revocación concurrente con escritura sensible | Semántica/orden acordados, sin carrera de privilegios |
| CSRF ausente/falso, Origin null/ajeno, login CSRF | Rechazado; preflight no equivale a acceso |
| Sesión admin usada en platform y viceversa | Rechazada incluso si Identity tiene ambos roles |
| Operador consulta tabla tenant por pool platform | DB grants lo impiden; no bypass implícito |
| Grant superior, rol protegido, dos bajas de último owner | Denegación transaccional, auditoría sin secretos |
| Invitación/reset usado dos veces o por destinatario incorrecto | Solo aceptación válida única; expirado no sirve |
| Query/draft/cookie de contexto anterior en UI | Sin datos previos tras cambio/logout ni respuesta tardía mezclada |

Además, exigir la matriz negativa completa de
[roles híbridos](roles-permissions.md#criterios-de-pruebas-para-implementar-posteriormente):
edición global denegada, copias sin grants, versión de plantilla sin escalación automática,
delegación por scope, edición de rol compartido, permisos adicionales solo en S1 y
revocación inmediata para nuevas solicitudes. No son pruebas ejecutadas.

Tests de integración PostgreSQL reales y unitarios de decisiones/expiración; HTTP en
httptest y UI Testing Library. E2E cookies/CSRF entre orígenes locales antes de habilitar
login real. Probar cookies host/puerto, CORS y MFA; documentar revocación de SSE en Fase 3.
No asumir que los tests de config/health existentes verifican nada de esto.

## 11. Entregas pequeñas propuestas

No son estados de avance. Cada corte termina con criterios ejecutables y revisión antes
del siguiente; los módulos operativos y comerciales quedan fuera.

| Corte | Entregable | Gate |
| --- | --- | --- |
| D1 | ADR identidad/sesión y gobierno; políticas ADR-001/002/003 aprobadas | Cerrar HTTP, implementación MFA y detalles de gobierno; sin código hasta autorización |
| D2 | Tooling PostgreSQL local, roles, migrador/sqlc y harness | Setup reproducible local; rol web sin bypass; migración/rollback smoke |
| D3 | Tenant/Branch/Membership, catálogo/plantillas/copias/grants y RLS | FKs/scopes/procedencia y fixtures dos tenants/tres branches sin fugas ni herencia viva |
| D4 | Credenciales/sesiones propias, login/logout y CSRF | Expiración/fijación/replay/CSRF probados; sin proveedor externo |
| D5 | Guards HTTP/contexto transaccional, listas propias/acceso | Autorización HTTP y SQL conjunta; casos de scope/IDOR denegados sin fugas |
| D6 | Audiencia/platform y MFA/bootstrap; provisión mínima | Cruces admin/platform denegados; tenant/owner/asignación atómicos/auditados |
| D7 | Admin login, selector tenant/branch y client Query | UI no mezcla cachés, sesiones ni pestañas; backend sigue siendo autoridad |
| D8 | Editor/grants, revocación, archivo seguro y transferencia reforzada | Invariantes ADR-002, delegación/impacto/Celtas, último Owner y concurrencia/auditoría/E2E |

Dependencia: D2 prepara SQL; D3 puede validar RLS con fixtures antes de auth real.
D4/D5 integran contexto Identity real. D6 precede onboarding de restaurantes.
Solo cerrar Fase 1 cuando la matriz de aislamiento/revocación esté aprobada; no basta
con que un usuario pueda iniciar sesión.

## 12. Decisiones pendientes para autorizar implementación

| Tema | Recomendación | Alternativa/riesgo a resolver |
| --- | --- | --- |
| Sesión | Opaca PostgreSQL, cookies y plazos ADR-003 aprobados | Nombres/persistencia, rotación, estados internos y transporte logout |
| Topología web | API del mismo origen por panel aprobada | Hosts, proxy/HTTPS local y reglas de GET sin Origin |
| Identidad | Global propia, Membership por tenant ya aprobadas | Normalización/verificación email, bloqueo/recovery e identidad destinataria concreta |
| Administración/delegación | Propietario y delegados expresos, aprobados | Campos/envelope/acciones, subdelegación y restricciones de destinatarios/self-grants |
| Ownership | Flujo reforzado y protección crítica aprobados | Máximo owners, retiro/copropiedad del anterior, factores/plazos y recuperación excepcional |
| Revocación | Nuevas solicitudes reflejan cambios de roles/membresías, obligatorio | Recomendar BD por request; resolver in-flight/SSE/cachés sin relajar garantía |
| Operador | Sin impersonation, MFA propia | Soporte excepcional necesita flujo temporal auditado |
| Onboarding/reset | Recomendar aprovisionamiento controlado y canal probado | Primer operador/Owner, invitado nuevo, entrega/verificación, expiración y recuperación sin bypass |
| MFA/verificación reforzada | MFA operador obligatorio; WebAuthn objetivo/TOTP alternativa inicial; global requiere refuerzo | Implementación exacta, bootstrap/recovery, factor/frescura de transferencia |
| PostgreSQL | Compartida con aislamiento y Docker local ya aprobados; imagen 18.6 fijada | Roles/grants DB, políticas RLS/helpers y FKs; rollback/concurrencia |
| Tooling | Goose v3.29.0 y sqlc v1.31.1 verificados vía Docker por usuario | Corregir rutas para SQL backend, evitar drift y definir harness local |
| Sesiones idle/absolutas | Admin 12 h/7 días; platform 15 min/8 h; actividad explícita aprobados | Endpoint/lista de actividad, frecuencia, TTL challenge/proof y algoritmo atómico |
| Evolución de roles | Copias independientes y archivo sin grants activos aprobados | Formato/versiones y reconciliación explícita; comportamiento del editor Owner permitido |

Las políticas de ADR-002 no se vuelven a tratar como abiertas. Siguen pendientes:
detalles de rotación/persistencia de cookies, transporte/custodia CSRF, HTTP,
revocación in-flight/SSE y limpieza de cachés. No reabrir políticas de ADR-003.
Identidad/email/MFA/onboarding deben tener verificaciones propias; aceptar una invitación
no verifica por sí solo un buzón ni satisface el refuerzo de propiedad.

## 13. D1.1 — contrato documental preparado, no implementado

[ADR-003](../decisions/ADR-003-web-authentication-sessions.md) y
[contrato web](web-authentication.md) contienen propuestas, doce trazas ficticias, amenazas,
pruebas negativas y preguntas. Login simple no completa transferencia ni MFA obligatorio.
Router /healthz y fuentes/configs permanecen intactos; ejemplos no son pruebas ejecutadas.

Políticas A1–A10 aprobadas; gate restante: formatos HTTP, estados internos, custodia de
secretos e implementación MFA, sin cambiar decisiones de roles/propiedad.
D1.1 no se marca como implementado, ni se cierran detalles pendientes automáticamente.

Siguiente incremento propuesto: [D2.1](d2-1-persistence-plan.md), persistencia local y
sesiones con pruebas verificables. Autorizar código/migraciones por separado tras revisar
su alcance y decisiones de esquema; endpoints HTTP conservan su gate independiente.
Tenant endpoints siguen dependiendo de D3/RLS; no adelantarlos por terminar login.

El diseño D1.1 no implementó auth. Posteriormente se autorizó infraestructura D2.1-A,
con configuración y roadmap actualizados; no se ejecutó SQL ni se inspeccionó Celtas/
producción. El resto de Fase 1 conserva sus gates de autorización e implementación.
ADR-002 conserva gobierno y ADR-003 distingue base confirmada de detalles de auth propuestos.
