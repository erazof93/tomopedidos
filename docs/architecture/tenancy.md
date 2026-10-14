# Tenancy, identidad y almacenamiento — diseño de Fase 1

## Modelo
Identity global (persona/cuenta); Tenant (restaurante); Branch (sucursal); Membership (relación identidad-tenant); permisos de sucursal y roles explícitos. Un usuario puede pertenecer a varios tenants sin compartir sus datos. Separar roles de operador SaaS de roles de restaurante.

## Roles híbridos — decisión aprobada, sin implementación
Plantillas globales controladas por Tomopedidos crean copias exclusivas por tenant.
Roles duplicables y personalizables; catálogo backend explícito y delegación limitada.
Grants tenant/branch separados: branch nula nunca implica acceso global.
Cambios sensibles auditados, último Owner activo protegido y revocación en nuevas solicitudes.
Permisos del empleado y entitlements se comprueban como dimensiones separadas.
[ADR aprobado](../decisions/ADR-001-hybrid-roles.md) y
[modelo/matriz/pruebas](roles-permissions.md) contienen el detalle bajo demanda.
Gobierno aprobado en [ADR-002](../decisions/ADR-002-role-governance-ownership.md):
propietario administra y autoriza delegados expresos; transferencia con invitación,
aceptación y verificación reforzada; Owner crítico protegido; copias independientes;
archivo solo después de revocar/reasignar todas las asignaciones activas.
Máximo de propietarios, factores de verificación, recuperación excepcional y detalles
de delegación/versionado siguen pendientes, no estas políticas generales.

## Persistencia
PostgreSQL compartido para planes estándar. Cada tabla de negocio lleva tenant_id y, cuando aplique, branch_id; claves foráneas/índices compuestos previenen referencias cruzadas. Definir asignación de tenant a almacenamiento para futura base dedicada sin implementarla ahora.

## RLS y contexto confiable
Políticas RLS de denegación por defecto; runtime de BD sin privilegios de owner/BYPASSRLS. `SET LOCAL` de tenant y, si procede, sucursal dentro de la **misma transacción/conexión** pgx que ejecuta las consultas; nunca confiar en un tenant_id arbitrario de header/body. Probar reutilización de pool, transacciones y consultas sin contexto. Revisar FORCE ROW LEVEL SECURITY cuando aplique.

## Autenticación — base aprobada y contrato propuesto
Identity global, sesiones opacas PostgreSQL, revocación server-side, CSRF/CORS restrictivo
y separación restaurante/operador son decisiones existentes confirmadas.
[ADR-003](../decisions/ADR-003-web-authentication-sessions.md) y
[contrato D1.1](web-authentication.md) registran email/contraseña Argon2id, cookies,
plazos y MFA operador aprobados. HTTP, implementación MFA y estados internos pendientes.
No sesión mutable de tenant entre pestañas ni OAuth
Google obligatorio. La sesión identifica; Membership/permisos/entitlements autorizan.
Docker Compose, Goose/sqlc y credenciales migración/runtime separadas están aprobados;
sin migraciones al arrancar API. [D2.1](d2-1-persistence-plan.md) propone el corte local,
sin implementar todavía aislamiento tenant ni convertir credenciales en permisos.

## Criterios Fase 1
Migraciones locales reversibles; pruebas reales PostgreSQL/RLS con dos tenants y
tres sucursales para el caso Celtas, con grants de cajeras y permisos adicionales
aislados. Cubrir plantillas/copias/delegación/último Owner según la matriz especializada,
revocación tras cambios de roles o membresías y fugas por conexiones reutilizadas.
Sin producción ni bases de Celtas. Son criterios pendientes, no pruebas ejecutadas.
