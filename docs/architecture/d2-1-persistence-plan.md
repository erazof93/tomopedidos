# D2.1 — Plan de persistencia local y sesiones

Estado: **D2.1-A y B1 completadas; B2-A/B2-B no autorizados**.
B2-D01–D10 y diseño técnico final B2-A aprobados; [plan A–F](b2-a-specification.md).
Sin escritura funcional/provisión/ejecución autorizada; B2-A no implementada ni verificada.
Políticas aprobadas: [ADR-003](../decisions/ADR-003-web-authentication-sessions.md).
Contrato HTTP y amenazas: [D1.1](web-authentication.md). Operación/evidencia D2.1-A:
[guía local](../local-postgresql.md). D2.1-B/C/D permanecen propuestos.
La solicitud posterior incorpora diseño de tenants/roles/RLS a una posible D2.1-B ampliada:
[propuesta de esquema](d2-1-b-schema-design.md). Implementación y ampliación requieren aprobación.

## Alcance recomendado

El alcance mínimo anterior proponía PostgreSQL local Docker Compose, migraciones mínimas
Goose, sqlc/pgx y sesiones internas, sin tablas tenant/roles. D2.1-A ya cerró; la nueva
propuesta B incorpora diseño tenant/roles/RLS por solicitud del usuario y necesita aprobación.
Sin endpoints auth, UI de login, MFA, onboarding ni negocio en los cortes de persistencia.
No confundir persistencia de sesiones con autenticación web operativa ni RLS implementado.

El entorno y roles/schemas/privilegios locales B1 están verificados. Esquema funcional B2,
sesiones, queries y migraciones necesitan autorización posterior; no se iniciaron.

## Decisiones previas al código

| Tema | Recomendación a revisar |
| --- | --- |
| Herramientas | Fijar versión/imagen y digest PostgreSQL, versiones Goose/sqlc y forma de ejecución local; no instalar globalmente |
| Entorno | Puerto publicado solo en loopback, base/volumen locales identificables; separar desarrollo y pruebas desechables |
| Credenciales | Dos credenciales distintas, ejemplos sin secretos; secretos locales ignorados, sin copiar archivos Celtas |
| Esquema | D01/D02 fijan correo, estados y gramática/límites; aprobar DDL/constraints/índices restantes antes de escribir SQL |
| Secretos | D05 aprueba token32/base64url canónica/SHA-256; D06 CSRF HMAC, formato/codificación/runbook pendientes |
| Credenciales web | Argon2id configurable aprobado; fijar parámetros iniciales mediante benchmark local, salt/formato versionado y límites de coste |
| Revocación | D07/D08 aprueban epochs global/audiencia y locks READ COMMITTED; especificar queries/grants/timeouts |
| Estados MFA | No crear sesión platform plenamente autenticada sin evidencia MFA; el método exacto sigue pendiente |

No introducir login público, valores por defecto de producción ni fallback que ignore
fallos DB. No utilizar una excepción HTTP para eludir cookies Secure aprobadas.

## Modelo mínimo propuesto

| Entidad | Campos/garantías a concretar |
| --- | --- |
| identities | ID global, correo original/canónico, estado, timestamps y versión de revocación; sin permisos tenant |
| identity_credentials (nombre aprobado D03; antes password_credentials) | PK/FK opcional 0..1 a identidad, PHC Argon2id v19 salt16/hash32 y fecha de cambio; revisión durable en Identity; nunca contraseña ni DTO público del hash |
| sessions | ID público distinto del token, FK identity, audiencia cerrada, token_hash único, datos CSRF protegidos, nivel/métodos autenticación, creación/actividad, vencimientos idle/absoluto y revocación |
| Estado de revocación | Versión global y, si se aprueba scope por audiencia, versión de audiencia; datos capturados al emitir sesión |

Proponer CHECKs de audiencia/estado y coherencia temporal, FKs e índices para lookup
por hash y revocación por identidad/audiencia. No persistir roles efectivos ni un tenant
activo mutable en sesiones. La representación exacta de estados requiere revisión.

Challenges prelogin/MFA y proofs de reautenticación son parte del diseño D1.1, pero
recomendamos diferir sus tablas al incremento HTTP/MFA después de aprobar purpose,
scope, consumo, TTL y custodia CSRF. Si se incluyen en D2.1, esa ampliación requiere
aprobar primero esos detalles y sus pruebas de carrera/replay. No definir factores
WebAuthn/TOTP provisionalmente en el esquema de este corte.

No exponer desactivación de identidad ni cambio de contraseña: sus efectos sobre
propiedad requieren guards futuros. Revocar sesiones no elimina membresías ni propietarios.

## Privilegios y transacciones

Migrador administra el esquema; runtime no es propietario, superusuario ni BYPASSRLS,
no tiene DDL ni posibilidad de asumir el rol migrador. Grants explícitos mínimos para
tablas/secuencias necesarias y protección de futuras tablas de auditoría. Las credenciales
de migración no se cargan en el arranque normal de la API. PostgreSQL documenta que
superusuarios/BYPASSRLS eluden RLS y propietarios normalmente también:
[políticas RLS oficiales](https://www.postgresql.org/docs/current/ddl-rowsecurity.html).

Identity/sesiones son globales: no aplicarles ingenuamente RLS tenant antes de resolver
identidad. La frontera auth necesita lookup por secreto de sesión/credencial; definir
consultas estrechas y prohibir acceso HTTP arbitrario por identity_id. Un rol auth adicional
es opcional y requeriría justificar grants/pool separados; no es condición aprobada.

Generar consultas sqlc compatibles con pgx y ejecutar cada operación atómica en la misma
transacción/conexión. Recomendación: no caché de estado de seguridad durante este corte.
Tras commit de revocación, una nueva autorización debe fallar; peticiones previamente
autorizadas tienen semántica independiente pendiente, no revocación retroactiva garantizada.

Coordinar emisión/revocación mediante versión y bloqueo transaccional a revisar: una
emisión concurrente no puede escapar a una revocación ya comprometida usando evidencia
anterior. Fallos o rollback no publican token, sesión ni revocación ficticia.

Renovación solo con actividad autenticada explícita, sesión vigente y audiencia correcta:
idle nuevo limitado al máximo absoluto, sin revivir expiradas/revocadas. Lookup/polling
no actualizan actividad. Usar reloj servidor UTC consistente, con reloj controlable solo
en pruebas; nunca admitir timestamps del cliente como autoridad.

## Incrementos pequeños y verificables

| Corte propuesto | Entregable futuro | Criterio de cierre |
| --- | --- | --- |
| D2.1a — Entorno y herramientas | Compose local, configuración validada/ejemplos y ejecución Goose/sqlc fijada | Base desechable accesible solo localmente, credenciales separadas y comandos documentados; sin migración al arrancar API |
| D2.1b — Esquema mínimo | SQL versionado de identities/credentials/sessions y estado de revocación aprobado | Up desde vacío y rollback en base exclusiva de pruebas; constraints y privilegios verificados |
| D2.1c — Acceso y sesiones internas | Consultas sqlc/pgx y lógica interna de emisión/lookup/actividad/revocación | Expiración exacta, audiencias y revocación/concurrencia probadas; no rutas HTTP nuevas |
| D2.1d — Evidencia | Harness integración local y registro reproducible de comandos/resultados | Go test/vet/build, generación consistente y pruebas negativas completas; limitaciones declaradas |

Operaciones de contraseña internas, si se incluyen, solo hashing/verificación con fixtures,
sin creación de cuentas reales ni API de registro. No generar sesiones platform utilizables
en runtime antes de disponer del flujo MFA aprobado; fixtures MFA son exclusivamente de pruebas.

## Garantías y pruebas de aceptación futuras

Estas pruebas no se han ejecutado en el trabajo documental.

| Riesgo | Evidencia exigida para cerrar D2.1 |
| --- | --- |
| Escalada DB | Runtime no puede crear/alterar esquema, asumir migrador ni eludir futuras políticas; migración usa otra credencial |
| Secretos | Tokens, contraseñas, CSRF y hashes de credenciales no aparecen en logs/errores; acceso a datos sensible limitado |
| Vencimiento | Justo antes del límite válido; en igualdad o después inválido; idle y absoluto por audiencia, usando reloj controlado |
| Renovación accidental | Lookup/polling repetidos no extienden idle; actividad explícita sí, sin superar máximo absoluto |
| Resurrección | Actividad posterior a vencimiento/revocación falla; carreras actividad/logout no restablecen sesión |
| Cruce de audiencia | Token admin no valida platform ni a la inversa; sesión no tiene contexto tenant mutable |
| Revocación | Actual afecta solo su sesión; global afecta todas las audiencias propias; otra identidad permanece intacta |
| Carrera de emisión | Evidencia previa/epoch viejo no emite sesión válida después del commit de revocación |
| Consistencia | Rollback deja estado anterior; fallo DB deniega, sin éxito falso ni fallback a permisos viejos |
| Integridad | Token_hash duplicado, FK inválida, audiencia desconocida y tiempos incoherentes rechazados |
| Pool | Transacciones terminan en commit/rollback y liberan conexión incluso ante cancelación/error |
| Reproducibilidad | Up en vacío, down/up solo en DB desechable y generación sqlc consistente; tests funcionan sin producción |

Comandos futuros a registrar: ejecución local Compose y Goose explícita sobre base de
pruebas, generación sqlc, `go test ./...`, `go vet ./...` y `go build ./...`.
Documentar variables/targets sin imprimir DSNs con secretos. Nunca ejecutar down ni
limpiar volúmenes sobre una base con datos útiles como parte del arranque o test habitual.

Las pruebas negativas tenant/RLS con conexiones reutilizadas pertenecen a D3; los controles
Origin/CSRF/cookies/logout HTTP a D4; MFA real al incremento operador. D2.1 no puede
declarar esos controles aprobados por pruebas internas de sesiones.

## Coherencia, riesgos y límites

No contradice ADR-001/002: permisos/delegación y protección del último propietario
siguen independientes del login. Entitlements no se incorporan a credenciales ni cookies.
La política MFA aprobada refuerza seguridad operador y no reemplaza transferencia auditada.

Las discrepancias encontradas eran clasificaciones antiguas: plazos, cookies, MFA y
Compose aparecían pendientes; se actualizan como aprobados. Persistencia de cookies,
TTL challenges/proofs y DTOs no quedan aprobados por esa corrección.

Riesgos abiertos: parámetros Argon2id costosos pueden agotar recursos; CSRF recuperable
requiere custodia definida; lectura/modificación concurrente necesita protocolo probado;
tests internos no prueban navegador/TLS. La API sigue con /healthz y sin auth operativa.

Cierre D2.1 requiere evidencia local y revisión de alcance; no completa Fase 1 ni autoriza
producción. D2.1-A ya cerró con evidencia Docker del usuario; el próximo paso es revisar esquema/
estados y autorizar específicamente D2.1-B y posteriores. Formatos HTTP pueden revisarse en paralelo.
