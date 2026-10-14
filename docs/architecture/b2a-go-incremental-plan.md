# Autenticación Go sobre B2-A — plan incremental propuesto

Fecha: 2026-10-14. Alcance de este trabajo: lectura, análisis y documentación.
No código implementado, conexiones PostgreSQL, Docker, migraciones, instalaciones,
benchmarks ni tests ejecutados. Los incrementos G1–G7 de este documento son propuestas
para autorización separada; no cambian los nombres de las entregas A–F.

## 1. Estado comprobado y precedencia de fuentes

El código Go vigente define los contratos HTTP implementados. SQL C/D/E y sus
manifiestos definen las firmas y límites de persistencia. Las decisiones aprobadas
interpretan su semántica; los ejemplos HTTP documentales no sustituyen código.
La evidencia F1–F6-C registra ejecución PostgreSQL exclusivamente en F; aquí no se
revalidó ningún cluster ni se extrapola ese resultado a tomopedidos_local.

Fuentes inspeccionadas:

- `tomopedidos-api/cmd/api/main.go`, `internal/config`, `internal/httpapi`,
  `internal/database/doc.go`, `go.mod`, `sqlc.yaml`, `db/schema`, `db/queries`.
- `db/administration/b2a-auth-functions-v1.sql`, manifiestos auth/roles/retention v1
  y evidencia `db/verification/f/control/f6/F6B_RESULTS.md`, `F6C_RESULTS.md`.
- [B2-A](b2-a-specification.md), [D01–D10](../decisions/B2-decisions.md),
  [ADR-003](../decisions/ADR-003-web-authentication-sessions.md) y
  [contrato web propuesto](web-authentication.md).

`PROJECT_CONTEXT.md`, cabeceras históricas de especificación/ADR y manifiestos
originales todavía dicen «no aplicado» o mencionan el destino local. Son antecedentes
del diseño, no evidencia contraria al cierre F ni autorización para desplegar en local.
No se modificaron esas fuentes ni se reutilizarán sus destinos como defaults del Go.

| Área | Código existente inspeccionado | Falta |
|---|---|---|
| Arranque | HTTP, señales, shutdown10s; ReadHeader5s/Read15s/Write15s/Idle60s | Composición de auth/repositorios/pools; readiness de dependencias |
| Configuración | APP_ENV y HTTP_ADDR, defaults/validación | DSN por rol, límites/presupuestos, cookies/orígenes/keyring; sin secretos actuales de auth |
| HTTP | chi v5.2.3; RequestID/Recoverer; **GET /healthz** | Todo endpoint, middleware y DTO auth; límites/rate limit/CSRF/CORS |
| PostgreSQL | pgx v5.7.6 declarado; interfaz Executor con solo Exec | Pool, BeginTx, Query/QueryRow/Scan, repositorios y transacciones reales |
| sqlc | Configuración v2, destino pgx/v5 | schema/queries contienen solo .gitkeep; no código generado |
| Criptografía | x/crypto v0.37.0 indirecta en go.mod | Parser/verify Argon2id, perfiles, RNG/token/CSRF y gestión de claves |
| Tests | TestHealth; TestLoad con seis subcasos | Tests de auth, DB, criptografía, navegador y fallos reales del cliente Go |

Go mínimo declarado1.26.0. No se cambia versión ni se instalan dependencias por
este plan. Los módulos Go de harness F5/F6 son herramientas de verificación, no
implementación reutilizable del backend auth ni prueba de sus pools/HTTP.

## 2. Mapa exacto SQL → operaciones Go propuestas

Todas las firmas siguientes existen en C, salvo cleanup que pertenece a E.
Los nombres Go son propuestas internas, no APIs implementadas. Consultas calificadas
y parametrizadas; sin SQL libre aportado por consumidores.

Se denomina aquí **S** al retorno común SQL real:
`(result text, session_id uuid, identity_id uuid, audience text,
authentication_level text, csrf_key_id text, csrf_generation bigint,
csrf_salt bytea, checked_at timestamptz, idle_expires_at timestamptz,
absolute_expires_at timestamptz, current_identity_epoch bigint,
current_audience_epoch bigint)`.
Es una abreviatura documental, no un nuevo tipo PostgreSQL. En salidas negativas
los metadatos pueden ser NULL: no escanearlos a tipos Go obligatorios ni asumir
identidad/CSRF disponibles cuando result no habilita esos campos.

| Firma SQL real | Inputs en orden y retorno | Operación Go propuesta / caller |
|---|---|---|
| `identity.lookup_credential(text,text)` | email canónico,audiencia → identity_id,password_hash,credential_revision,identity_epoch,audience_epoch | LookupCredential; auth; 0 filas=no evidencia, no es autenticación |
| `identity.issue_session(uuid,bigint,bigint,bigint,text,uuid,bytea,text,bytea)` | identidad,revisión esperada,epoch global esperado,epoch audiencia esperado,audiencia,UUID sesión,digest32,key_id,salt32 → result,session_id,created_at,idle_expires_at,absolute_expires_at | IssueSession; auth; **solo admin**, nivel password fijado por SQL |
| `identity.validate_session(bytea,text)` | digest,audiencia → S | ValidateSession; auth; no renueva idle, puede persistir detección terminal |
| `identity.record_activity(bytea,text)` | digest,audiencia → S | RecordActivity; auth; solo interacción autorizada, no cambia absoluto |
| `identity.revoke_session(bytea,text)` | digest,audiencia → S | RevokeSession; auth; autoridad/posesión y CSRF se acreditan en Go |
| `identity.mark_expired(bytea,text)` | digest,audiencia → S | MarkExpired; auth; operación interna opcional, no endpoint de limpieza |
| `identity.rehash_conditional(uuid,bigint,text,text)` | identidad,revisión esperada,PHC esperado,nuevoPHC → result,credential_revision | RehashConditional; auth; equivalencia/no degradación se acreditan en Go |
| `identity.revoke_audience(bytea,text)` | digest,audiencia → S | Revocación privilegiada futura; **sin caller operativo** |
| `identity.revoke_global(bytea,text)` | digest,audiencia → S | Revocación privilegiada futura; **sin caller operativo** |
| `identity.cleanup_sessions(integer DEFAULT 100)` | lote1..100 → examined,deleted,skipped,checked_at | Worker de mantenimiento separado; no método del servicio web auth |

Retornos result observados en SQL: issue=`issued/invalid/clock_anomaly`;
validate=`valid/invalid/expired/clock_anomaly`; activity=`activity_recorded/...`;
logout=`revoked/...`; mark=`not_expired/invalid/expired/clock_anomaly`;
rehash=`rehashed/unchanged/not_applied/clock_anomaly`.
Revocaciones privilegiadas usan `audience_revoked/global_revoked` y negativos comunes.
Enums desconocidos, cardinalidad inesperada o NULL inconsistente fallan cerrado;
no convertir cualquier fila o «SQL sin error» en éxito de dominio.

El rol LOGIN `tomopedidos_auth_runtime` tiene exactamente las siete firmas normales,
sin DML directo ni membresía en ejecutores. Owners NOLOGIN:
`tomopedidos_auth_executor` (siete) y `tomopedidos_auth_revoke_executor` (dos).
Los nombres conceptuales con sufijo `_privileged` no son firmas SQL invocables.
Auth, tenant y PUBLIC no ejecutan las dos revocaciones; no habilitarlas para completar Go.

### Datos que el contrato no proporciona

Validación no devuelve email, Membership, permisos tenant, nombre ni privilegios SaaS.
Lookup tampoco devuelve email ni constituye prueba de contraseña. La respuesta
de sesión propuesta debe limitarse a identity.id y metadatos permitidos; el ejemplo
web con identity.email necesita otra decisión/contrato y no autoriza SELECT directo.
No hay funciones para challenge prelogin, proofs recientes, MFA, registro,
verificación de correo, cambio/recuperación de password o inventario de claves CSRF.
No se inventarán ni se sustituirán por bootstrap/DML desde la API.

## 3. Arquitectura mínima propuesta y pools

Flujo: router → controles HTTP → servicio auth → repositorio tipado → transacción
pgx/sqlc → función autorizada. Políticas puras de correo/token/PHC/CSRF separadas
de transporte y SQL. `cmd/api` compone; paquetes internos propuestos `auth`,
`database`/adaptador auth y `httpapi`. Los nombres se fijarán en cada entrega.

El servicio no recibe SQL ni roles configurables por request. Identidad/audiencia
se derivan de ruta y validación; ningún identity_id/epoch/authentication_level del
body acredita autoridad. No mantener tenant/sucursal mutable en sesión ni roles
autoritativos cacheados; autenticación global no concede acceso tenant.

| Uso | Credencial/pool propuesto | Límite |
|---|---|---|
| API auth | Pool exclusivo `tomopedidos_auth_runtime` | Siete funciones; sin negocio/DML/SET ROLE |
| API tenant futura | Pool independiente `tomopedidos_runtime` cuando exista su repositorio | Sin identity ni funciones auth; no pool auth como fallback |
| Mantenimiento | Proceso/worker separado con `tomopedidos_session_maintenance` | Solo cleanup; no credencial en el proceso web |
| Migración/administración | Fuera de API | Sin bootstrap/migrator/tp_owner/ejecutores en configuración runtime |

Configurar credenciales distintas, budgets y máximos independientes; rechazar
identidad privilegiada/rol distinto al previsto en futura validación de arranque.
Nada de migraciones, grants o rol automático al arrancar. Verificar configuración
real y search_path, sin considerar el username de un DSN prueba suficiente.
No cargar `.env` raíz/F ni inferir destino por nombre o copiar credenciales del harness.
Futuras integraciones exigen autorización de destino aislado y preflight fresco.
Separar pools limita privilegios accidentales; no aísla un proceso completamente comprometido.

Executor actual no basta: hace falta contrato interno acotado de transacción/consulta
y tests con dobles. `sqlc.WithTx` será futuro, no código existente. Antes de generar,
resolver con prueba offline cómo sqlc1.31.1 representa funciones TABLE, NULL/UUID/bigint/
timestamptz y firmas administrativas. Los archivos C incluyen metacomandos psql y
no son automáticamente un schema sqlc válido. Snapshot solo para compilación,
derivado de fuentes aprobadas, nunca otra migración ni función aplicada en runtime.
No rellenar db/schema con una copia ejecutable que diverja de Goose/C.

## 4. Flujos Go sobre los contratos existentes

### Login admin

1. Ruta fija audiencia admin; Origin, JSON/tamaño/rate limit y challenge prelogin
   válidos antes de verificar contraseña. El challenge necesita contrato propio,
   aún pendiente; no ofrecer login browser sin esa protección.
2. Canonizar conforme D01/D02: rechazar controles/Unicode, quitar solo U+0020 externo,
   gramática/límites en bytes, minúsculas solo A–Z; conservar puntos/+.
3. Lookup en transacción corta READ COMMITTED; 0 filas produce categoría pública
   uniforme para ausente/inactivo/no verificado/sin credencial. PHC/evidencia nunca salen.
4. Verificar PHC/contraseña con cupo Argon2 fuera de transacción y locks; capturar
   revisión y ambos epochs del lookup. Igualar trabajo negativo según presupuesto
   que se apruebe, sin alegar latencia perfectamente indistinguible.
5. Rehash opcional solo después de verificar equivalencia: si se habilita, calcular
   nuevoPHC fuera de locks y CAS en transacción propia. `rehashed` confirmado permite
   usar la revisión retornada; conservar los epochs del lookup original. `not_applied`,
   error o commit incierto no permiten continuar con evidencia refrescada sin verificar
   de nuevo la contraseña. No unir rehash e issue en una transacción ni degradar perfil.
   Sin necesidad de rehash, usar revisión original. Este orden requiere aceptación en G4.
6. Generar session_id UUIDv4 independiente, token32 RNG, digest SHA-256 de bytes
   originales y salt CSRF32, con key_id activo conocido. Issue en nueva transacción
   con los cuatro valores de evidencia exactos. SQL revalida estado/revisión/epochs.
7. Solo `issued` más COMMIT confirmado habilita Set-Cookie/éxito. No adoptar epochs
   nuevos con una contraseña verificada antes de una revocación. No retry automático.
   Entrega HTTP fallida tras commit puede dejar una sesión no entregada: no supone
   rollback ni justifica un bypass para buscarla/borrarla con privilegios de admin.

El flujo no crea identidades/credenciales ni activa cuentas. En producción requiere
un procedimiento de alta/verificación ya aprobado; en integración futura, solo fixtures.

### Validación, renovación y logout

Cookie de audiencia correcta → decodificación canónica exacta → SHA-256 → Validate
en su propia transacción. `valid` confirmado permite un contexto interno mínimo;
`expired` puede haber escrito expired_at y debe COMMIT antes de responder terminalidad
confirmada. `invalid` no revela si fue desconocida, revocada o epoch obsoleto.
Nunca cachear validación como autorización permanente. Las acciones ya autorizadas
no se cancelan retroactivamente por una revocación posterior.

Para activity/logout: Origin primero; Validate y COMMIT para obtener binding vigente;
CSRF después; solo entonces ejecutar RecordActivity/RevokeSession en **otra**
transacción de una operación, que revalida locks/epochs/tiempo. Comparar identidad,
sesión y binding retornado con el autorizado antes de COMMIT de la mutación; si no
coinciden, rollback/fallo cerrado. No hacer Validate+Revoke dentro de la misma tx.
Si la carrera devuelve `expired`, confirmar la marca terminal antes del 401 propuesto;
si no hay autoridad CSRF no revocar ni renovar. El digest por sí solo no es autorización.

GET session/csrf, polling, preflight y heartbeat no invocan RecordActivity. Actividad
solo por operación explícita autorizada, sin prueba infalible de presencia humana.
Admin12h/7d y platform15min/8h son límites aprobados SQL; Go no calcula un nuevo
absoluto ni renueva cookies para eludirlo. Logout normal usa revoked_at, no DELETE.
MarkExpired no sustituye cleanup ni autoriza consultas privilegiadas.

### Revocación por epoch / platform

Las sesiones con epoch viejo fallan cerrado según SQL. Auth no actualiza epochs.
No publicar logout-all, revocación de audiencia, deshabilitación ni cambio de
credencial usando pools privilegiados como atajo. Requieren contrato futuro de
autoridad reciente, MFA operador, proof y actor/caller independiente aprobado.
No emitir sesiones platform: issue rechaza esa audiencia y no existe emisor MFA.
Conservar pruebas de denegación y separación de audiencia; pertenencia SaaS es
distinta de Owner de restaurante y aún no tiene implementación/contrato operativo.

## 5. Criptografía y transporte

**Aprobado:** Argon2id PHCv19, salt16/hash32, sin pepper inicial; password sin
normalizar/truncar. Faltan perfiles definitivos/techo de verificación, longitud máxima
de password, concurrencia/cola/memoria/latencias. Candidatos de benchmark:
19456KiB,t2,p1;65536KiB,t2,p1;65536KiB,t3,p1. No convertirlos en defaults productivos.
Parser PHC estricto y canónico antes de reservar memoria, perfiles explícitos,
comparación constante, RNG que falla cerrado. Context cancelado no garantiza parar
Argon2 ya iniciado: retener cupo hasta terminar, no lanzar trabajo ilimitado desacoplado.

**Aprobado:** token de32 bytes crypto/rand, base64url canónica sin padding43 caracteres,
digest32 SHA-256 sobre bytes originales. Rechazar tamaño/alfabeto/padding/no canónico;
no hash del texto base64, JWT, refresh token o secreto en URL/log. Cookie es el canal
propuesto; PHC/digest/keys/tokens/password nunca en logs/trazas/errores.

**Cookies aprobadas:** host-only, Secure, HttpOnly, SameSite=Lax. Propuestos
`__Host-tp_admin`, Path=/ y persistencia hasta absoluto; nombres exactos/HTTPS local/
proxy/Max-Age siguen por aprobar. Cookie de otra audiencia no promueve privilegios.
No desactivar Secure para acelerar pruebas. Expiración DB prevalece sobre navegador.
No Set-Cookie auth en error/unknown; no afirmar logout confirmado si no hay commit.

**CSRF aprobado:** HMAC-SHA-256 con clave independiente fuera de DB/repo, ligado a
purpose/sesión/identidad/audiencia/generación/salt; Origin estricto y hmac.Equal.
Persistidos key_id ASCII1..32, generación1 inicial y salt32. Token estable por
generación; no rotarlo al consultar; clave desconocida/binding inválido deniega.
Faltan formato binario/versionado/longitudes/endianess, transporte exacto, keyring/
custodia/rollout/retirada/compromiso. No definirlos como aprobados por este plan.
Auth no tiene query para inventariar referencias a claves: diseñar retirada
conservadora y procedimiento administrativo autorizado, no SELECT general desde API.
Prelogin necesita purpose, consumo/replay, TTL y almacenamiento/actor propios;
las cuatro tablas/funciones actuales no proporcionan ese estado. Decidir persistencia
y operación antes de habilitar HTTP; no sumar tabla/memoria multiinstancia sin aprobación.

## 6. Transacciones, budgets y errores ambiguos

Una operación funcional por tx corta READ COMMITTED; lookup/rehash/issue separados.
Sin READ ONLY para validación: puede marcar expiración. Sin Argon2, red/UI/negocio/SSE
dentro de tx. Configuración SET LOCAL de budgets no cuenta como otra operación auth.
Usar context por adquisición/operación y deadline total de request; coordinarlo con
HTTP WriteTimeout actual15s, cola Argon2 y varias tx. Candidatos aprobados para medir:
pool500ms/lock1s/statement2s/tx3s/idle-tx1s; no valores de producción ya medidos.

Definir resultado de infraestructura separado del dominio: confirmado,
abortado/rollback confirmado o **desconocido**. Una fila positiva antes de Commit
no confirma operación. SQLSTATE de error conocido no basta si el transporte pierde
la confirmación de COMMIT. Si commit devuelve rechazo/rollback conocido, no éxito;
si transporte/deadline deja desenlace incierto, no token/cookie/success/retry ciego.
Colisión23505,55P03,57014,40P01,22003,25000 y errores desconocidos tienen mapeo
interno estable; no enviar textos PostgreSQL/constraints ni parámetros al cliente.

Después de error: no más SQL de negocio en tx abortada; intentar rollback con
contexto de limpieza acotado e independiente del request cancelado. Devolver
conexión al pool solo si quedó limpia; si limpieza/estado no se acreditan, descartarla
según contrato real pgx. Deadline/cancel en pgx no se considera rollback confirmado
por inferencia. Probar comportamiento real de la versión fijada, incluido estado idle.
Cerrar HTTP o Docker CLI no prueba que el servidor canceló/abortó.

Propuesta HTTP genérica503 para dependencia/timeout/clock_anomaly/unknown, sin
éxito falso ni detalles SQL. No usar Retry-After como permiso para repetir operaciones
auth no idempotentes automáticamente. Correlación por request_id/categoría sin secretos.
Reconciliar por una nueva validación cuando exista cookie ya entregada; una emisión
sin token entregado no tiene query privilegiada de recuperación para auth. Documentar
sesión huérfana posible y recuperación operativa separada, sin inventar idempotencia.
Un fallo opcional de rehash no debe confundirse con confirmación de login/issue.

## 7. Propuesta HTTP, aún sin implementar ni aprobar como contrato

Se reutiliza la familia propuesta en web-authentication.md. Solo `/healthz` existe.
BASE admin propuesto `/api/v1`; namespace platform futuro `/api/platform/v1`.
Audiencia fijada por router/origen, nunca por body/query/header cliente arbitrario.

| Método/ruta propuesta | Función/flujo | Gate / respuesta propuesta |
|---|---|---|
| POST BASE/auth/challenge | Estado prelogin aún inexistente | Bloqueado hasta contrato propio;201 propuesto |
| POST BASE/auth/sessions | Lookup→Argon2→rehash opcional→Issue | Solo admin, tras challenge/CSRF;201, cookie tras commit |
| GET BASE/auth/session | Validate | 200 identity.id/metadatos;401 uniforme, sin email/roles/tenant |
| GET BASE/auth/csrf | Validate→binding HMAC | 200,no-store, sin renovar idle, control origen/fetch metadata |
| POST BASE/auth/session/activity | Validate→CSRF→RecordActivity | 200 con deadlines confirmados; no polling automático |
| DELETE BASE/auth/session | Validate→CSRF→RevokeSession | 204 solo commit confirmado; sesión inválida401 propuesto |
| DELETE BASE/auth/sessions | Revocación privilegiada por scope | No publicar: caller/proof/autoridad pendientes |
| POST BASE/auth/reauthentications, auth/mfa/verify | Contratos aún inexistentes | No publicar ni simular MFA/platform |

JSON estricto y acotado, desconocidos/trailing JSON rechazados; sin credenciales
en query; no-store también en errores; origen allowlist exacta por namespace,
CORS sin wildcard con credenciales, política de GET sin Origin pendiente.
Códigos propuestos:401 credenciales/sesión inválidas;403 Origin/CSRF;422 payload;
429 límite;503 dependencia/unknown. Logout repetido401 frente a204 idempotente,
envelope/request_id y nombres finales de cookie requieren aceptación expresa.

## 8. Entregas pequeñas y criterios de aceptación propuestos

Cada fila requiere autorización separada. Integración real/benchmarks no quedan
autorizados por preparar este documento. No iniciar HTTP para esquivar gates.

| Entrega | Trabajo acotado | Criterios verificables / gate |
|---|---|---|
| G1 — núcleo puro | Correo D01/D02, audience/resultados tipados, UUIDv4/token32/digest; errores Confirmed/Aborted/Unknown; contratos internos sin adaptador conectado | Unitarios/corpus/fuzz: bytes/límites, RNG fallido,43-char canónico, UUID/secretos independientes, resultados desconocidos; stdlib/sin DB/endpoints/keys |
| G2 — adaptador transaccional | Config auth separada, runnerpgx y wrappers normales tipados; resolver schema/sqlc offline | Dobles: Begin/Scan/Commit/Rollback/cancel y cada rama de Commit; nullable/resultados/cardinalidad; no reintentos ni APIs de admin. No abrir pool desde main todavía |
| G3 — integración del cliente Go | Conectar solo a destino desechable autorizado; actor real auth/negativos/recuperación | Gate de autorización DB independiente; repetir solo garantías específicas del nuevo adapter: roles reales, pins/target, tx/pool limpio,55P03/57014/commitambiguo por transporte Go, sin cambiar SQL ni grants |
| G4 — contraseña/login interno | Parser PHC, benchmark autorizado, perfiles/límites, verify/cupo, rehashCAS, evidencia→Issue | Perfiles aprobados y pruebas hostiles; Argon2 fuera de locks, cupo retenido al cancelar, no cookie/token antes de commit, races revisión/epochs. Sin HTTP ni platform |
| G5 — CSRF/cookies/prelogin | Cerrar especificación binaria/keyring, custodia, Origin y challenge, DTOs/errores/hosts/HTTPS | Vectores conocidos/binding/rotación/fallo de clave, replay/multiinstancia y navegador; almacenamiento prelogin necesita aprobación propia si exige SQL. Sin nuevos grants implícitos |
| G6 — HTTP admin | Handlers/middleware login/session/csrf/activity/logout y composición final | Contrato Go aprobado y tests de router/integración/navegador; GET no renueva, CSRF malo no muta, audiencia no cruza, rate limit/DBfallida/unknown no éxito, sin secretos |
| G7 — futuros separados | MFA/platform, revocaciones privilegiadas, identidad/credenciales admin y tenant authorization | Solo tras contratos/actores/proofs/MFA aprobados. No ampliar auth7 ni aprovisionar roles por inferencia |

G2 puede preparar configuración y fábricas con dobles, sin instanciar pools reales; solo G3 ejecuta
integración tras permiso explícito. G4 no usa perfiles históricos/candidatos como
hechos productivos; puede cerrar parser/tests antes de que se apruebe el benchmark.
G5 tiene un gate de diseño propio, no promete implementar un challenge sin storage.

### Matriz de pruebas necesaria

- Unitarias/fuzz: gramática común Go/DDL; PHC/base64/UUID/CSRF malformados y límites
  antes de asignar memoria; resultados SQL/NULL; RNG/keys ausentes; email genérico;
  logs/errores/Set-Cookie sin secretos; JSON/origen/audiencia y rate limit.
- Adapter con dobles: error de Begin/Scan/Commit, rollback fallido, Commit desconocido,
  context ya cancelado, cupos/cleanup, no reutilizar tx abortada ni retry; expiración
  confirma marca antes del resultado público; no respuesta exitosa por fila provisional.
- Integración Go futura: firmas/ACL y auth real, prohibición de DML/privilegios,
  digest→Scan tipado/NULL, rehashCAS/revisión/epoch, pool limpio tras timeout/cancel/
  desconexión/commitambiguo, ninguna adquisición como bootstrap ni destino implícito.
- Seguridad HTTP/navegador: loginCSRF/challenge replay, cookie host-only/Secure/
  HttpOnly/SameSite, Origin exacto y GET, no cache, múltiples pestañas, renovación
  legítima frente a polling/revocación, sesión ajena/otro tenant sin concesión implícita.
- Las pruebas SQL F son evidencia de persistencia; no sustituyen ni se reejecutan
  completas por defecto. Repetir carreras concretas solo donde intervenga nuevo Go.
  MFA/operador/registro/reset/SSE tienen aceptación aparte, sin afirmar cobertura actual.

## 9. Riesgos, decisiones pendientes y primera autorización sugerida

Bloqueos para HTTP completo: perfiles/benchmarks Argon2id y budgets; formato/keyring
CSRF/retirada; contrato/storage prelogin sin soporte en SQL actual; DTOs/errores/
cookies/orígenes/HTTPS local; protección de fuerza bruta multinstancia y política de
password; tratamiento de emisión entregada tarde/commit incierto; sqlc/nullable;
MFA/platform/emisor y revocaciones privilegiadas sin caller. No son incompatibilidades
que justifiquen cambiar C/D/E: el runtime inicial es deliberadamente más estrecho.

**Primera entrega recomendada para autorizar: G1, núcleo puro.** Alcance: nuevo
paquete interno auth y sus tests; validación/canonicalización ASCII exacta, tipos de
audiencia/resultados e incertidumbre, token32/base64url/SHA-256 y UUIDv4 mediante
stdlib. Contratos internos sin abrir conexiones ni modificar main/router/config actual.
No elegir PHC productivo, formato CSRF, nombres cookie o endpoints en este corte.

Aceptación G1: corpus de fronteras64/65,254/255,63/64; tabs/Unicode/puntos consecutivos y
espacios internos rechazados; +/puntos conservados; RNG falla cerrado; decodificación
canónica43, digest de bytes; UUIDv4 independiente; Unknown jamás equivale a éxito;
sin logs secretos, conexiones, DSN, claves, nuevos módulos ni llamadas SQL.
Checks previstos cuando se autorice código: tests/fuzz acotado, vet y build offline
del módulo con dependencias locales, sin descarga/toolchain ni conexión DB.
Entregar diff pequeño, resultados reales y lista de gates restantes. Ningún archivo
de implementación ni test G1 se creó por este trabajo documental.

El cierre PostgreSQL probado F1–F6-C se conserva. La autenticación Go/HTTP B2-A/B2-B
no está implementada ni verificada por este plan; no declarar B2-A completa.
