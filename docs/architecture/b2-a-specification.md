# D2.1-B2-A — especificación consolidada para aprobación humana

Estado: **diseño técnico aprobado; B2-A/B2-B no implementadas, migradas ni verificadas**.
Registro documental: 2026-10-14. [D01–D10](../decisions/B2-decisions.md) son decisiones
arquitectónicas aprobadas y no se reabren. La aprobación expresa posterior registra
ownership administrativo separado, dos ejecutores NOLOGIN, frontera de revocación,
CSRF persistido, locks/guards y retención. No autoriza escribir ni ejecutar artefactos.
Firmas/DDL/ACL exactos se materializarán en entregas revisables tras autorización.
No se crean SQL funcional, migraciones, código, roles, pools o secretos.

## Base vigente y convenciones

B1 completada según [evidencia](../verification.md): schemas y defaults restrictivos,
owner tp_owner NOLOGIN, migrator con SET a owner, runtime tenant sin acceso identity.
Migrations/schema/queries del backend todavía sin SQL funcional; Executor solo Exec,
sin pool/repositorios auth. No se presenta documentación como contrato Go implementado.
Goose v3.29.0/sqlc v1.31.1/pgx v5.7.6. Convención NNNNN_nombre.sql con Up/Down,
snapshot db/schema y queries db/queries. B1 bootstrap está fuera de Goose: no repetirlo.
Names propuestos pk_/fk_/uq_/ck_/idx_ + tabla/regla; sin convención funcional previa.

Todas las tablas e índices owner tp_owner. FK no diferibles, UPDATE/DELETE RESTRICT.
UUIDv4/variante estándar generado Go, sin default DB; timestamps timestamptz finitos.
Contadores bigint no negativos; inicial 0 salvo generación CSRF 1. Queries calificadas.
Funciones/helpers/triggers de esta especificación son contratos propuestos, no código.

## Tablas, columnas y constraints

### identity.identities

| Columna | Tipo | Nulabilidad/default | Constraint/regla |
| --- | --- | --- | --- |
| id | uuid | NOT NULL, sin default | PK, UUIDv4/variante estándar; inmutable |
| email_original | text | NOT NULL, sin default | ASCII/gramática D02, sin espacios externos, <=254 bytes |
| email_canonical | text COLLATE C | Generada STORED, NOT NULL | translate explícito A–Z→a–z; UNIQUE global |
| status | text | NOT NULL, pending | pending/active/disabled; active implica verified_at presente |
| email_verified_at | timestamptz | NULL, sin default | Finito si presente, verificación por actor autorizado |
| auth_epoch | bigint | NOT NULL, 0 | >=0, monotónico durable |
| credential_revision | bigint | NOT NULL, 0 | >=0, monotónico durable |
| created_at | timestamptz | NOT NULL, clock_timestamp | Finito, inmutable |

Correo: un @; local 1–64 bytes, segmentos no vacíos sin puntos inicial/final/dobles;
alfabeto D02 (ASCII alfanuméricos, !#$%&'*+-/=?^_, acento grave y {|}~).
Dominio <=253, al menos dos etiquetas 1–63, ASCII alfanuméricos/guion con extremos
alfanuméricos; no underscore, trailing dot, IP literal o dominio enteramente numérico.
Sin comillas/escapes/comentarios/display names/Unicode/controles. Xn-- ASCII admitido
sintácticamente sin IDNA ni promesa de entrega; no reglas por proveedor. Límite total
domina: dominio efectivo <=252 con local mínimo. Go rechaza Unicode/controles, quita
solo U+0020 externo, conserva original aceptado y transforma únicamente A–Z.
DB no normaliza entrada inválida: CHECK exige original ya aceptado. No lower locale,
citext o trim Unicode. Corpus común demuestra equivalencia después de autorización.

No DELETE de Identity. Cambio de correo/activación/rehabilitación/enviar verificación
fuera del runtime inicial; ninguna marca verificada inferida por sintaxis/DNS.

### identity.identity_credentials

| Columna | Tipo | Nulabilidad/default | Constraint/regla |
| --- | --- | --- | --- |
| identity_id | uuid | NOT NULL, sin default | PK/FK identities.id, 0..1 |
| password_hash | text | NOT NULL, sin default | PHC Argon2id v19, ASCII, máximo propuesto 256 bytes |
| changed_at | timestamptz | NOT NULL, sin default | Finito, instante servidor de escritura/rehash |

CHECK lexical PHC cerrado: argon2id/v19/m,t,p positivos, salt base64 PHC sin padding
de 22 caracteres y resultado 43 (16/32 bytes decodificados). No base64url de token.
Canonicalidad, decodificación, rangos/perfiles/costes son también responsabilidad Go.
Cap256 debe contrastarse con perfiles aceptados; es propuesta, no parámetro aprobado D04.
Crear/sustituir/eliminar incrementa revisión durable en Identity; creación inicial/cambio
semántico incrementa epoch global; rehash equivalente no revoca y es condicional.
No guard DB puede determinar equivalencia de contraseña comparando dos PHC.
Sin credencial no hay otro login; sin DELETE de runtime. Actor administrativo futuro separado.

### identity.audience_revocations

| Columna | Tipo | Nulabilidad/default | Constraint/regla |
| --- | --- | --- | --- |
| identity_id | uuid | NOT NULL, sin default | FK identities.id |
| audience | text | NOT NULL, sin default | admin/platform |
| auth_epoch | bigint | NOT NULL, 0 | >=0, monotónico durable |

PK(identity_id,audience). Dos filas atómicas con Identity; FK no garantiza su existencia.
Ausencia falla cerrado; no recreación/reset automático. Sin DELETE normal.

### identity.sessions

| Columna | Tipo | Nulabilidad/default | Constraint/regla |
| --- | --- | --- | --- |
| session_id | uuid | NOT NULL, sin default | PK UUIDv4, separado de secreto |
| identity_id | uuid | NOT NULL, sin default | FK identities.id |
| audience | text | NOT NULL, sin default | admin/platform; FK compuesta a audiencia |
| token_hash | bytea | NOT NULL, sin default | 32 bytes exactos UNIQUE; SHA-256 bytes token |
| identity_epoch | bigint | NOT NULL, sin default | >=0, snapshot inmutable |
| audience_epoch | bigint | NOT NULL, sin default | >=0, snapshot inmutable |
| authentication_level | text | NOT NULL, sin default | password/mfa; platform exige mfa |
| csrf_key_id | text COLLATE C | NOT NULL, sin default | Aprobado 1–32 bytes ASCII alfanuméricos/guion/underscore |
| csrf_generation | bigint | NOT NULL, 1 | >=1; estable en runtime inicial |
| csrf_salt | bytea | NOT NULL, sin default | Aprobado 32 bytes RNG, estable por generación |
| created_at | timestamptz | NOT NULL, sin default | Finito, t servidor al emitir |
| last_activity_at | timestamptz | NOT NULL, sin default | Finito, inicial created_at |
| idle_expires_at | timestamptz | NOT NULL, sin default | Finito, plazo por audiencia |
| absolute_expires_at | timestamptz | NOT NULL, sin default | Finito, inmutable |
| revoked_at | timestamptz | NULL, sin default | Finito si presente, terminal irreversible |
| expired_at | timestamptz | NULL, sin default | Finito si presente, terminal irreversible |

FK(identity_id,audience) referencia PK de audience_revocations, no valores de epoch.
CHECK created<=last_activity<idle<=absolute; absoluto creación+604800s admin/28800s
platform, como duraciones UTC sin depender de timezone/DST. Idle<=actividad+43200s
admin/900s platform. No CHECK de vigente ahora. Terminales pueden coexistir; no imponer
orden cronológico a sus instantes sin resolver clock rollback. Nivel mfa no prueba MFA;
frontera Go futura confiable, sin emisión platform operativa en B2.

CSRF persistido no contiene clave/MAC/token bruto. Tipos/tamaños/key_id aprobados:
texto ASCII1–32 alfanuméricos/guion/underscore, bigint>=1 inicial1 y bytea32.
Codificación binaria/version/purpose/orden/endianess, formato token,
keyring/custodia/rollout/retirada no se dan por aprobados por esta representación.

## Guards e invariantes

BEFORE UPDATE de fila, sin mutaciones cruzadas ni locks fuera de orden:
- Identity: ID/created inmutables; epoch/revisión no retroceden (incremento unitario
  propuesto, overflow falla cerrado). Transición disabled coordinada con epoch por función.
- Audiencia: claves inmutables, epoch no retrocede ni se resetea.
- Sesión: ID/identidad/audiencia/digest/creación/absoluto/snapshots inmutables;
  terminal no se borra ni cambia; ninguna actividad/idle se modifica si ya terminal.
  Una segunda causa terminal puede registrarse sin reactivar. Actividad/idle no retroceden.
  CSRF sin UPDATE en runtime inicial; rotación posterior solo mediante contrato aprobado.

CHECK no garantiza monotonicidad, filas admin/platform, incrementos por credencial,
MFA/refuerzo ni locks. Funciones/transacciones coordinan filas; Go decide contraseña,
autoridad, interacción válida, binding CSRF y permisos. Rehash no se demuestra en SQL.
No DELETE cascada ni triggers que bloqueen Identity después de credencial/sesión.

## Catálogo de operaciones y actores

S=FOR SHARE, X=FOR UPDATE. Todas READ COMMITTED; lookup preliminar no autoriza.
Argon2 fuera de locks, luego revalidar estado/revisión/epochs. Sesión X desde inicio
de validación permite expired_at sin upgrade. Pruebas de contención obligatorias.

| Operación conceptual | Actor | Orden de locks y contrato |
| --- | --- | --- |
| LookupCredential(email_canonical) | Auth | Lectura consistente hash/revisión/estado/epochs; sin autorización aún |
| IssueSession(evidencia,digest,CSRF) | Auth | Identity S→audiencia S; revalidación evidencia, t tras locks, insertar; secreto tras commit |
| ValidateSession(digest,audiencia) | Auth | Discovery→Identity S→audiencia S→sesión X; recheck digest/estado/epochs/tiempo; terminal commit→inválida |
| RecordActivity(digest,audiencia) | Auth | S→S→X, solo vigente/interacción autorizada; no extiende absoluto |
| RevokeSession(digest,audiencia) | Auth, frontera confiable de autoridad/posesión | Solo sesión del digest, S→S→X, revoked_at idempotente; conocer digest no autoriza |
| RevokeAudiencePrivileged(digest,audiencia) | Sin caller operativo habilitado en B2 | Derivar identidad de sesión validada; S→audiencia X; incremento, no barrido |
| RevokeGlobalPrivileged(digest,audiencia) | Sin caller operativo habilitado en B2 | Derivar identidad de sesión validada; Identity X; incremento, overflow no éxito |
| RehashConditional(identity_id,revision,hash esperado/nuevo) | Auth | Operación separada Identity X; CAS, revisión+1, epoch intacto |
| MarkExpired(digest,audiencia) | Auth | S→S→X; reevaluar límites, expired_at terminal |
| CreateIdentity(email)/audiencias | Admin futuro/fixtures autorizadas | Transacción única; pending inicial, dos audiencias |
| Create/Replace/RemoveCredential | Admin futuro | Identity X antes de credencial; revisión/epoch atómicos |
| DisableIdentity | Admin futuro | Identity X; estado/epoch, guards propiedad fuera de B2 público |
| CleanupSessions(candidatos) | Mantenimiento | Identity→audiencia→sesión, orden determinista, revalidar cutoff bajo locks |

PostgreSQL clock_timestamp capturado después de esperas; validar igualdad como expirada.
Si t anterior a creación/última actividad, fallo cerrado de anomalía, no fecha fabricada.
Idle nuevo=min(absoluto,max(idle anterior,t+plazo)); last_activity=max(anterior,t), solo
vigente. Marcar expiración y terminar tx antes de comunicar resultado terminal confirmado.
Transacción auth nunca abarca Argon2/red/UI/operación negocio ni duración de SSE.
Punto de autorización: revalidación final bajo locks; revocación previa commit deniega,
operación ya autorizada no se cancela retroactivamente. Sin retries iniciales.
Timeout/cancelación/deadlock termina tx/libera conexión; commit incierto no éxito/secretos.
Valores locales iniciales aprobados como candidatos sujetos a pruebas: pool wait500ms,
lock1s, statement2s, tx3s, idle-tx1s. No definitivos de producción ni mediciones realizadas.

## Funciones restringidas y fronteras aprobadas de diseño

Auth sin UPDATE general de credenciales/epochs/revisiones. Dos ejecutores NOLOGIN:
funciones normales auth y revocación privilegiada, distintos de tp_owner.
Entradas/salidas del catálogo anterior deben convertirse en firmas tipadas explícitas
antes de implementar; no nombres de tabla/columna/rol ni SQL libre. No SQL funcional aquí.

| Actor/perfil | Acceso propuesto | Denegaciones |
| --- | --- | --- |
| tomopedidos_auth_runtime LOGIN | CONNECT, USAGE identity, EXECUTE por firma de operaciones normales; lookup PHC interno; logout con autoridad/posesión | Sin DML general, DDL, ownership, negocio, membresías ejecutores/owner/migrator, revocación audiencia/global ni admin/cleanup |
| Ejecutor auth normal NOLOGIN, nombre en manifiesto | Owner funciones normales, SELECT necesario, INSERT sesiones, UPDATE acotado de actividad/terminales/revisión/rehash y permisos de locks | No owner tablas/schema, CREATE schema, negocio, privilegios elevados, revocaciones privilegiadas ni membership caller |
| Ejecutor revocación privilegiada NOLOGIN, nombre en manifiesto | Owner solo funciones audiencia/global; SELECT/locks y UPDATE mínimo de epochs | Sin caller operativo en B2; auth no EXECUTE ni SET ROLE; no ownership tablas/negocio/DDL |
| tomopedidos_identity_admin LOGIN, propuesta futura | Solo funciones admin autorizadas; sin usar owner/migrator en API | No habilitado/provisionado ni endpoints en B2; guards último Owner pendientes |
| Soporte administrativo futuro | DML/funciones de su corte, por revisión separada | No se aprueba crear otro ejecutor ni habilitar administración por este plan |
| Mantenimiento, perfil pendiente | SELECT metadatos/DELETE sesiones elegibles mediante función estrecha | Nunca Identity/credenciales/epochs/auditoría, ni secretos/logs |
| tomopedidos_runtime tenant | Sin acceso identity/functions auth | Conserva frontera B1 |
| tp_owner/migrator | Ownership de tablas y migraciones explícitas B1 | Nunca credencial normal API |

SECURITY DEFINER con ejecutor mínimo distinto de tp_owner. Search_path fijo pg_catalog
y pg_temp al final; objetos calificados. EXECUTE revocado PUBLIC en misma transacción,
otorgado por firma a caller concreto. Sin SQL dinámico, funciones genéricas o fallback.
Role creation/ownership assignment privilegiados son provisión separada, no inferidos
de SET ROLE tp_owner. Auth no puede SET ROLE ejecutor; NOLOGIN solo no basta.
Privilegios de fila/locks (SELECT+UPDATE) pertenecen al ejecutor, no se conceden UPDATE
arbitrario a auth para habilitar locks. Queries/firmas y negativos requieren revisión.

Triggers solo guards de fila; funciones coordinan mutaciones. Función rehash no prueba
equivalencia de contraseña: Go confiable sigue verificándola. Función IssueSession no
acredita MFA por aceptar un nivel: B2 no ofrece sesión platform operativa. Pool separado
no protege frente a compromiso completo del proceso. Riesgos residuales explícitos.

## Índices por consulta

| Índice | Consulta/coste justificado |
| --- | --- |
| PKs y UNIQUE email canónico/digest | Lookup credencial/sesión y integridad, sin índice duplicado |
| sessions(identity_id,audience,created_at DESC,session_id) | ListSessionMetadata interno administrativo y FK/recorrido por identidad |
| sessions(csrf_key_id,absolute_expires_at) | KeyReferences para retirada conservadora de claves |
| Sesión fecha terminal efectiva + session_id, expresión exacta por cerrar | Cleanup por cutoff; condicionado a aprobar retención/query |

No índices de epoch para barrer sesiones; revocación cambia contador. No índice
parcial dependiente de now. Helpers puros de gramática pueden proponerse IMMUTABLE
invoker, pero solo si no leen tablas/GUC/reloj; alcance/query sqlc debe verificarse.

## Retención y limpieza — política de 30 días aprobada como diseño

Política aprobada: 30 días desde primera terminalidad conocida (menor vencimiento natural
idle/absoluto o marca explícita). Expired_at es detección, no necesariamente fecha
natural. Logout usa revoked_at. Revocación por epoch no tiene fecha por sesión:
conservar hasta vencimiento natural+retención salvo terminalización posterior.
No prometer 30 días exactos desde toda revocación global. Exactitud adicional exige
historial de invalidación/materialización, otra aprobación; no inventar fecha.
Alternativas previas inmediato/7/90 días conservan trazabilidad; 30 días seleccionados.

Cleanup actor separado, 100 filas/lote como candidato aprobado sujeto a medición,
no resultado medido; orden global, relectura
cutoff tras locks, commit/lote; error detiene, sin retries. Selección preliminar
no autoriza DELETE. SKIP LOCKED solo alternativa de mantenimiento, no autenticación.
No limpiar sesión válida; correr contra activity/validación no elimina renovación válida.
Claves no las borra cleanup: retener mientras existan sesiones válidas dependientes,
o criterio conservador hasta absoluto. History inválido no exige conservar clave.
No DELETE Identity/credenciales/epochs/auditoría; auditoría/retención propia futura.

## Separación de procedimientos aprobada; ejecución no autorizada

1. Autorizar escritura de A/B: Goose tablas/guards/índices owner tp_owner. No funciones
   definidoras de otro owner como migraciones normales del migrator actual.
2. Autorizar escritura de C: paquete administrativo versionado con firmas/cuerpos,
   hashes/versiones previas y nuevas, owners/search_path/ACL y aserciones exactas.
3. Autorizar separadamente provisión de auth y dos ejecutores NOLOGIN, sin ampliar
   roles B1. Credenciales privadas solo por procedimiento específico aprobado.
4. Administrador local explícitamente autorizado aplica paquete de funciones dentro
   de una sola transacción: guards destino/drift, crear/reemplazar, retirar PUBLIC,
   fijar SECURITY DEFINER/search_path, asignar owner mínimo, verificar ACL/atributos.
   No cambios temporales de owner ni memberships del migrador como atajo.
5. Grants executor/caller versionados y administrativos, separados de Goose: EXECUTE
   normal por firma; revocaciones privilegiadas sin caller operativo B2. Habilitar
   caller solo después de ownership/privilegios/aserciones correctos.
6. Commit solo tras aserciones; lecturas nuevas y evidencia después. Actualizaciones
   compatibles vía administrador y CREATE OR REPLACE con propiedades explícitas;
   incompatible usa firma nueva y transición revisada, no DROP CASCADE.
7. Error precommit: rollback/detener sin retry; commit ambiguo no afirmar resultado,
   resolver por lectura nueva. Reversión posterior mediante paquete anterior como
   nueva transición autorizada, no corrección automática.

Ningún intervalo con definer tp_owner ejecutable por runtime. Revocaciones de grants
no cancelan invocaciones ya iniciadas; transición incompatible necesita drenaje definido.
Goose no controla como aplicadas las definiciones del paquete administrativo: su versión,
hash/ownership/ACL se registran separadamente. Runbook exacto será artefacto C revisado.
Goose transaccional Up/Down; no NO TRANSACTION inicial. Down en base exclusiva desechable
autorizada, orden inverso, no borra schemas B1. Sin migración al arrancar API.
No repetir/modificar 001/002/010/020. B2-B consulta mediante pgx.Tx/sqlc.WithTx futura;
Executor actual no se presenta como suficiente repositorio implementado.

## Plan de aceptación futuro

| Grupo | Casos obligatorios |
| --- | --- |
| Positivos | Identity+dos audiencias atómicas; credencial opcional; emisión/validación/actividad/logout/scopes; rehash CAS; terminalidad persistida |
| Integridad negativa | Corpus correo Go/PG y límites; PHC/base64/UUID/digest/CSRF inválidos; FK/duplicados/nulls/infinite time; estado/nivel inválido; missing rows/overflow; epoch snapshot no impide revocar |
| Guards | Absoluto/digest/creación/keys inmutables; counters no disminuyen; terminal no se borra; actividad tras terminal deniega; segundo terminal no reactiva |
| Concurrencia | Emisión vs global/audiencia/disabled/password; rehash vs cambio; logout/actividad/validación; expiración y retroceso reloj; cleanup vs actividad y FK; sin upgrades/deadlocks por orden |
| Contención | Varias peticiones de una sesión y varias cajeras; medir p50/p95/esperas, transacciones cortas; no mantener locks durante SSE/negocio/Argon2 |
| Seguridad definer | PUBLIC/auth/tenant sin DML general/admin; SET ROLE executor denegado; search_path/pg_temp hostile; firmas/overloads/dynamic SQL; ownership/DDL/negocio denegados |
| Fallos | RNG, timeout/cancelación/deadlock/rollback/commit ambiguo; conexiones liberadas, no retries/secretos/success falsos; rehash no degrada |
| Cleanup/keys | Cutoff/lote/relectura, epoch sin fecha no adelantada, ninguna Identity/credencial/epoch/auditoría borrada, clave necesaria preservada |
| Reproducibilidad | Up/Down solo DB desechable; metadata/ownership/ACL, snapshot/sqlc/Go checks futuros aprobados; no B1 repetido ni producción |

Avisos/reautenticación/pedidos/SSE requieren pruebas posteriores propias. No se afirma
PASS por este plan; ninguna prueba B2 ejecutada.

## Diseño aprobado y especificaciones pendientes

La aprobación expresa cubre las recomendaciones finales de diseño y las trece
precisiones del usuario; no afirma equivalencia criptográfica/autoridad demostrada en SQL.
Restan materializar DDL/helpers, firmas/retornos/manifiestos ACL, nombres de ejecutores,
runbook, corpus y plan ejecutable de pruebas en entregas revisables. Cap PHC256 y
expresiones concretas deben comprobarse con perfiles; no parámetros Argon2 medidos.
No reabrir D01–D10 ni llamar aprobado un artefacto SQL que todavía no existe.
Benchmark/costes D04 y CSRF binario/token/keyring/runbook completo bloquean B2-B;
no bloquean representar PHC si se aprueba separar gates. Roles de soporte y funciones
aprobados como diseño no son recursos existentes. Escritura/aplicación/provisión/tests
y operación cleanup requieren autorizaciones específicas, ninguna concedida aquí.

## Plan de implementación A–F — no autorizado

Rutas siguientes son archivos previstos, no creados. SQL/runtime/test scripts solo se
escribirán después de autorización correspondiente. No Go en este trabajo documental.

| Entrega | Archivos previstos | Dependencias | Cierre/pruebas requeridas | Riesgos | Autorización adicional |
| --- | --- | --- | --- | --- | --- |
| A — tablas/constraints | db/migrations/00001_identity_credentials.sql y 00002_audience_sessions.sql; snapshots revisados db/schema/identity.sql y identity_sessions.sql; docs de contrato | B1 confirmado, D01–D10/diseño final. CSRF persistido cerrado; sin caller auth necesario para escribir | Cuatro tablas/tipos/defaults/FK/UNIQUE/CHECK y ownership; corpus de fronteras/email/PHC/UUID/timestamps/epochs. Validación estática en PR; ejecución solo tras permiso | Expresiones regex/PHC, canonización y defaults no certificados hasta PostgreSQL | Escribir archivos A; separado preparar target desechable y ejecutar migraciones/pruebas. No provisión implícita |
| B — guards/índices | 00003_identity_guards_indexes.sql; snapshot soporte; db/verification/030_b2a_integrity.sql y corpus fixtures propuestos | A revisado; queries concretas justifican índices; helpers guards invoker bajo tp_owner | Inmutabilidad/monotonicidad/terminalidad, sin locks cruzados; negativos de restore/overflow; FK y plan índices | CHECK no prueba coordinación; no trigger con mutaciones entre tablas. Scripts de prueba pueden escribir fixtures y requieren permiso | Escribir B/scripts; aplicar y ejecutar fixtures solo en DB desechable autorizada |
| C — funciones/manifiesto | db/administration/b2a-auth-functions-v1.sql; manifests/b2a-auth-v1.yaml; docs/runbooks/b2a-function-lifecycle.md, nombres propuestos | A/B, firmas/retornos revisados. Escritura independiente de existencia de roles; aplicación depende D/provisión | Paquete administrativo normal/privilegiado con owner/ACL/search_path/hash/drift/rollback; pruebas static y futuras temp/search_path/indirect calls | Definer privilege y evolución; digest no acredita posesión, SQL no prueba rehash/MFA | Escribir C/runbook; no aplicar ni usar bootstrap hasta autorización concreta |
| D — provisión/grants/aislamiento | db/administration/b2a-role-preflight.sql y b2a-auth-grants-v1.sql; manifiesto roles/permisos; 040_b2a_role_isolation.sql; docs privadas sin secretos | C aprobado; A/B aplicados al target autorizado para pruebas | Auth/two executors, sin B1 ampliado; auth no audiencia/global; EXECUTE por firma, no DML general; SET ROLE/PUBLIC/tenant/admin negativos | Crear roles cluster es persistente; uso accidental bootstrap o permisos heredados. Rol/provisión/grants separados | Escribir artefactos D; autorizar provisionar roles, proporcionar credenciales privadas, aplicar C/grants y correr negativos por separado |
| E — cleanup/retención/concurrencia | db/administration/b2a-session-cleanup-v1.sql y runbook; índice Goose 00004_session_cleanup_index.sql solo si query lo necesita; 050_b2a_retention_concurrency.sql/harness futuro | A–D verificados para ejecutar; actor mantenimiento especificado sin nueva provisión inferida; política30d aprobada | Cutoff natural/terminal/epochs, 100 candidato medido, relectura locks, clave válida conservada. Carreras activity/validation/logout/cleanup | Actor cleanup puede destruir sesiones; no fechas epoch inventadas; clocks y batch pressure | Escribir E/harness; aprobar provisión mantenimiento si requerida; tests/cleanup desechable y operación real siempre separados |
| F — integración/aceptación | docs/verification.md, informe aceptación B2-A, manifests de evidencia; snapshot/sqlc configs sin cambio de versiones; harness db/verification previsto | A–E completados con evidencia, target/códigos/aserciones completos | Migraciones Up/Down en DB desechable; ownership/ACL/corpus/negativos/concurrencia/contención y runbook rollback. sqlc compile y Go checks solo si artefactos relevantes/autorizados; no claim auth Go implementada | Infraestructura local no demuestra HTTP/MFA/SSE ni B2-B; pruebas como superusuario no acreditan restricciones | Autorizar conjunto preciso de checks/tests; cierre B2-A solo con resultados reales, no por este plan |

### Gates y bloqueo real de entrega A

No bloqueo arquitectónico que obligue reabrir D01–D10. Para **comenzar a escribir A**,
falta autorización expresa de escritura funcional: esta autorización solo documentación.
DDL/regex/helpers se producirán como resultado revisable de A, no se exige ejecutarlos
ni provisionar auth antes de poder escribirlos. No benchmark definitivo necesario
para representar PHC ni contrato binario completo para columnas CSRF aprobadas.

Para **ejecutar A**, se requiere destino desechable inequívoco, baseline equivalente B1,
preflight vigente/usuario/hashes/scope y autorización SQL específica. No repetir B1
en tomopedidos_local por inferencia. B2-B exige benchmark/límites D04, CSRF binario/keyring
y pool/repositories futuros; aprobación de diseño B2-A no autoriza ese código.

Gates separados: (1) escribir artefactos, (2) provisionar roles/credenciales,
(3) ejecutar Goose, (4) aplicar paquete privilegiado/ACL, (5) ejecutar tests/fixtures,
(6) operar cleanup. Down/test fixture/delete incluso desechable requieren autorización.
No operación real de cleanup implícita en aprobar pruebas E o retención30d.
