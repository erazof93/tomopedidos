# D1.1 — Contrato propuesto de autenticación web

Estado: **políticas D1.1 aprobadas; contratos HTTP propuestos; no implementado**.
Base aprobada y propuestas separadas en [ADR-003](../decisions/ADR-003-web-authentication-sessions.md).
Router Go vigente: solo GET /healthz. Config actual valida APP_ENV/HTTP_ADDR, sin conexión
SQL ni sesiones. Paneles tienen pantallas iniciales/QueryClient, sin auth/client HTTP.
No se modifica ese comportamiento. Dominios, IDs, tokens y contraseña de ejemplos son
fixtures ficticias: no se conectó a ellos ni se generaron credenciales reales.

## Política aprobada y detalles recomendados

Email/contraseña autentican Identity global; estado de Membership y permisos se comprueba
por tenant/branch después. Sin selección de restaurante en login. Roles no van en cookie.
[B2-D01 aprobada](../decisions/B2-decisions.md): ASCII, original/canónico, espacios externos
eliminados y lowercase ASCII, unicidad global, sin equivalencias de proveedor;
autenticación normal requiere identidad activa y correo verificado. D02 aprueba
gramática/límites y estados; envío/flujo operativo de verificación y onboarding
siguen sin implementación. No modificar password por trim
ni registrar credenciales. D04 aprueba PHC Argon2id v19, salt16/hash32 y perfiles
explícitos; parámetros definitivos/límites de entrada y recursos requieren benchmark
y aprobación. Rate limiting HTTP por cuenta/IP confiable sigue por especificar.
401 genérico para credencial incorrecta, Identity inexistente o bloqueada; evitar enumeración.
No registro público, cambio de password, reset, onboarding o transferencia completos en D1.1.

### Cookies, orígenes y audiencias

| Panel | Namespace API propuesto | Cookie autenticada | Cookie prelogin/MFA |
| --- | --- | --- | --- |
| admin | /api/v1 | __Host-tp_admin | __Host-tp_admin_login |
| platform | /api/platform/v1 | __Host-tp_platform | __Host-tp_platform_login |

HttpOnly, Secure, SameSite=Lax y ausencia de Domain están aprobados. Path=/, nombres y
prefijo __Host- son propuestas. D05 aprueba token criptográfico32/base64url canónica
sin padding/SHA-256 de bytes originales, ID separado y entrega tras commit confirmado;
no token en JSON ordinario ni URL. UUIDv4 D03 es identificador, no secreto de sesión.
El prefijo __Host- requiere Secure, Path=/ y ausencia de Domain. Cookies no se aíslan por
puerto; hosts/nombres/audience/importancia de Origin se prueban también en dev.
[MDN Set-Cookie](https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/Set-Cookie).

API del mismo origen por panel está aprobada. Hosts ilustrativos: https://admin.tomopedidos.example y
https://platform.tomopedidos.example, cada uno con /api del mismo origen dirigido al monolito.
Son nombres reservados ilustrativos, no hosts configurados ni producción.
Namespace/host autorizado determina audiencia en servidor; body/headers arbitrarios no la eligen.
Validar Host y forwarded headers solo de proxies explícitamente confiables.
Cookie de admin nunca autentica rutas platform ni otra identidad; otros nombres se ignoran.

Sesión persistente admin propuesta: Max-Age inicial 604800, anclado al máximo absoluto;
no renovar ese plazo cada lectura. Cookie platform propuesta: Max-Age inicial 28800.
Al rotar cookie por step-up, Max-Age se limita al tiempo absoluto restante, sin abrir
otra ventana de siete días/ocho horas. Login completo nuevo tiene su propio ancla.
Servir TLS real/local de confianza sin desactivar verificación. El proyecto todavía usa
HTTP loopback Vite: HTTPS/proxy local necesita aprobación/config posterior.
La política Secure se conserva en desarrollo: preparar HTTPS local sin desactivar TLS ni
modificar confianza global en este trabajo. No persistir tokens de acceso en storage de React.

### Tiempo y actividad

Plazos de sesiones admin/platform y actividad explícita aprobados. TTL de challenges,
espera MFA y proofs, rotación y endpoint de actividad siguen propuestos.

| Estado | Inactividad | Máximo |
| --- | --- | --- |
| Challenge prelogin | Sin renovación por consultas | 10 min desde emisión |
| Espera de MFA | Sin actividad que prolongue | 5 min desde validar password |
| Sesión admin | 12 h | 7 días desde autenticación completa |
| Sesión platform | 15 min | 8 h desde autenticación completa |
| Proof de reautenticación | Uso único | 5 min, ligado a operación/scope |

Expira cuando now >= idle_expires_at o now >= absolute_expires_at. D10 aprueba
clock_timestamp PostgreSQL después de locks y expired_at terminal: expiración detectada
no resucita al retroceder reloj. DDL/protocolo de marcado terminal pendientes.
Fecha/reloj del servidor,
instantes UTC. Actividad no cambia el ancla absoluta. Rotar identificador al autenticar,
completar MFA/reautenticar; step-up no resetea la duración máxima de la sesión existente.

Proponer POST /auth/session/activity con CSRF para reportar interacción de UI, limitada en
frecuencia: solo sesión aún válida y min(now+idle,absolute). Polling, GET session/csrf,
preflight y heartbeat SSE no renuevan idle; no enviar activity en timer automático.
Timers/reconexiones/tráfico automático tampoco renuevan. D10 registra avisos y
reautenticación anticipada como requisitos futuros, sin reset silencioso del absoluto.
Sustitución de sesión, recuperación de pedidos confirmados y restauración SSE después
de autenticar/revalidar permisos requieren contratos futuros; no implementados en B2.
La señal no demuestra presencia humana: su política reduce renovación accidental,
no impide a quien robó una sesión mantener actividad. Algoritmo/concurrencia por aprobar.
Si el usuario no quiere endpoint activity, acordar lista precisa de operaciones que renuevan;
no definir “cualquier request” sin considerar TanStack Query/polling.

12 h/7 días favorecen turnos largos, pero aumentan exposición en caja compartida.
Platform tiene plazos propios aprobados; MFA no elimina el riesgo de robo de sesión.
Cerrar navegador no garantiza revocación; logout y estado DB son la autoridad.

## Estados y datos server-side recomendados

Sesión autenticada: id no secreto, identity_id, audience, token_hash, csrf_token protegido,
created_at, last_activity_at, idle_expires_at, absolute_expires_at, revoked_at,
authentication_level/methods y auth_epoch. Session IDs y tokens de acceso son distintos.
No almacenar tenant/branch mutable, permisos efectivos ni contraseña en esta tabla.
CSRF asociado a sesión, disponible solo por frontera auth para responder al titular;
no es token de acceso y no se publica en logs/URLs. [B2-D06 aprobada como diseño](../decisions/B2-decisions.md#b2-d06--hmac-csrf-aprobado-como-diseño)
selecciona HMAC-SHA-256 vinculado a sesión, con clave externa y hmac.Equal.
Codificación, token, runbook de claves y factores MFA quedan pendientes; sin implementación.

Prelogin: registro separado auth_challenges con token_hash, audience, purpose (login/reauth),
csrf_token, expires_at, attempts/consumed_at; identity_id solo después de verificar password.
Challenge reauth también liga sesión actual y operación/scope; no intercambiar propósitos.
Transición recomendada:
challenge anónimo → password verificado → sesión admin activa; o →
MFA pendiente platform → MFA verificado → sesión platform activa.
Token y CSRF cambian al elevar estado. Sesión previa/prelogin no se transforma aceptando
un token del cliente. Reusar challenge válido puede evitar carreras entre pestañas;
no renovar su vencimiento. Resolver dos bootstraps simultáneos con rebootstrap acotado.

Para MFA obligatorio aprobado: password correcto NO crea sesión platform plenamente
autenticada. Pending cookie solo habilita verificar/enrolar conforme a flujo aprobado;
no metadatos tenant, roles SaaS ni acceso platform. No hay flag client-side skip_mfa.
Operador sin factor requiere onboarding/enrolamiento seguro antes de obtener privilegios.
Onboarding/password por sí solos no acreditan haber completado dos factores.

Revocación: lookup server-side por cada request, sin caché obsoleta como fallback.
Logout actual revoca esa sesión y elimina solo su cookie. Nuevas solicitudes tras commit
se rechazan. Revocar Membership/Role retira ese ámbito, no todas las sesiones globales.
Desactivar Identity/cambiar credenciales siguen guards de propiedad y política específica;
logout no revoca Membership ni quita la condición de Owner.
Fallo DB: 503 y fail closed, no 204 de logout falso ni acceso con estado viejo.

## CSRF y CORS

CSRF de sesión derivado HMAC y estable durante una generación, aprobado en D06.
El transporte JSON no-store/memoria cliente/X-CSRF-Token sigue propuesto; no es cookie
de acceso. CSRF aleatorio prelogin/challenge permanece propuesta de otro corte.
GET csrf recupera el mismo token; no lo rota para invalidar otras pestañas.
Login compara token del prelogin cookie; logout/activity/reauth usan token de sesión.
Al crear sesión nueva se invalida challenge y su CSRF; al cambiar fase MFA se emite otro.

Bootstrap POST challenge carece de token previo: excepción estrecha para crear contexto
anónimo, exige Origin exacto, JSON y límites. No autentica, revoca ni cambia sesión existente.
Si ya hay sesión válida de esa audiencia, proponer 409 SESSION_ALREADY_ACTIVE para evitar
cambiar Identity inadvertidamente; cambio de cuenta empieza por logout protegido.
Login con challenge expirado/consumido requiere bootstrap nuevo, nunca excepción CSRF.

En todos los métodos mutadores web: Origin exactamente igual al permitido para host/audiencia,
incluyendo esquema/puerto, no wildcard/substrings/suffix ni Origin null/ausente.
Verificar CSRF aun con Origin válido; SameSite no basta. Fetch Metadata es defensa adicional.
En GET privados, comprobar Origin si existe y bloquear Fetch Metadata cross-site;
GET csrf requiere Origin permitido o Sec-Fetch-Site: same-origin, para soportar fetch
same-origin que normalmente no adjunta Origin. Política legacy/navegadores por aprobar.
[OWASP CSRF](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html).

Mismo origen por panel es la topología aprobada. Una futura excepción cross-origin requiere
revisión separada; la política restrictiva propuesta para ese caso es:
allowlist concreta por namespace, Allow-Credentials:true, métodos/headers mínimos,
Vary: Origin y preflight sin cookies/autenticación obligatoria. Un origen admin permitido
no se permite por ello en rutas platform. No reflejar Origin indiscriminadamente.
En preflight ajeno proponer 403 sin Allow-Origin; en mutación ajena denegar sin efectos.
No tratar CORS como barrera a clientes no browser: necesitan autenticación/autorización.
No eximir controles web por User-Agent Flutter/móvil ni aceptar bearer como bypass de CSRF.
Allowlist de este corte: GET/POST/DELETE/OPTIONS y headers Content-Type, X-CSRF-Token,
X-Reauthentication-Token. Allow-Origin responde un único origen permitido, nunca *;
preflight válido puede retornar 204, sin elevar sesión. No hace falta exponer Set-Cookie
a JavaScript. [MDN CORS](https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/CORS).

Respuestas auth privadas/error: Cache-Control:no-store; JSON cuando tengan body,
request_id seguro; ningún Set-Cookie exitoso ante CSRF/Origin inválidos.
No GET para cambios de cuenta/logout/propiedad. CSRF no protege ante XSS del propio origen;
sanitización/CSP y control de dependencias siguen necesarios.

## Logout global y reautenticación

Proponer DELETE /auth/sessions con scope enum current_audience o all_audiences, sin default
silencioso. Siempre solo Identity actual, nunca identity_id/tenant_id libre en body.
Ambos revocan también la sesión actual. all_audiences abarca admin/platform de esa Identity.
Verificación reciente mediante proof server-side ligado a sesión/operación/scope, uso único;
MFA obligatorio para logout global si Identity es operadora, aun desde admin.
No basta con que body declare auth_level elevado.

POST /auth/reauthentications verifica password y, si aplica, MFA; retorna proof solo
cuando estén completos. MFA puede seguir flujo limitado 202, nunca proof utilizable
al verificar solo password. Formato de factores/UX todavía pendiente.
La finalización rota cookie/token/CSRF de la sesión, preserva su ancla absoluta
y devuelve nuevo CSRF junto al proof; el cliente usa ambos actualizados al revocar.
No usar challenge MFA de login para reauth ni cambiar el scope/purpose registrado.
Proof enviado por X-Reauthentication-Token y validado transaccionalmente al revocar.
Auditar sin tokens. Recomendar auth_epoch por Identity y revocación de challenges MFA/
proofs ya ligados a Identity: evitar que un login pendiente vuelva a emitir sesión antigua.
Definir epoch por audiencia para current_audience y global para all_audiences.
Login nuevo iniciado después con credenciales válidas sigue flujo normal; no bloquear cuenta.

Servidor solo puede borrar cookies del host que responde. Las otras cookies pueden quedar
en el navegador, pero sus sesiones están revocadas y dan 401 en nueva solicitud.
Otros paneles/pestañas limpian datos Query/drafts cuando detectan revocación; sincronización
de UX no sustituye estado DB. SSE futuro precisa deadline de revalidación/cierre.
Requests ya autorizados/in-flight requieren semántica aparte; no prometer retiro retroactivo.

## Alternativas MFA y verificación reforzada

| Método | Ventaja | Coste/riesgo | Evaluación propuesta |
| --- | --- | --- | --- |
| WebAuthn/passkeys con verificación de usuario | Resistencia a phishing, sin proveedor auth obligatorio | HTTPS/RP/orígenes, enrolamiento/compatibilidad y recuperación | Preferido para platform si entorno lo permite |
| Password + TOTP local | Operación propia, menor integración inicial | Phishing, clock/replay, secreto cifrado y protección de claves | Alternativa inicial viable con librería revisada |
| Password + SMS/email OTP | Familiar | Canales externos, interceptación/recuperación más débiles | No mecanismo base recomendado |

No llamar MFA a repetir password ni a aceptación de invitación. TOTP requiere limitar
intentos/replay y proteger secreto; WebAuthn verifica challenge/origin/RP y usuario.
Recovery codes de un solo uso y gestión de pérdida de factor requieren procedimiento
auditado/reforzado, no soporte que simplemente desactive MFA. Elegir biblioteca/versiones
al definir la implementación exacta; WebAuthn/passkeys es el objetivo aprobado y TOTP
la alternativa inicial aprobada. No desarrollar algoritmos criptográficos propios.
[OWASP MFA](https://cheatsheetseries.owasp.org/cheatsheets/Multifactor_Authentication_Cheat_Sheet.html).
Validación WebAuthn según [especificación W3C](https://www.w3.org/TR/webauthn-3/).
Transferencia ADR-002 necesita verificación reforzada vinculada al acto/destinatario;
un login MFA antiguo no satisface automáticamente frescura/aceptación de transferencia.

## Contratos HTTP propuestos

En la tabla BASE = /api/v1 o /api/platform/v1, fijado por ruta/audiencia.
Body JSON estricto: rechazar campos desconocidos, credentials/token nunca en query.
401 SESSION_INVALID no distingue expirada/revocada/desconocida públicamente.
403 ORIGIN_DENIED/CSRF_INVALID deniega sin mutación; 409 estados incompatibles;
422 payload inválido; 429 limitado; 503 dependencia no disponible.
Challenge prelogin ausente, expirado o consumido: 403 AUTH_CHALLENGE_INVALID y bootstrap
nuevo; no probar password ni conceder cookie. No reutilizar códigos de sesión autenticada.
Orden: resolver audiencia/origen y límites → validar contexto sesión/challenge/CSRF →
credentials/MFA/proof → commit → respuesta. No publicar sesión/token antes del commit.

| Método / ruta | Body y precondición | Éxito propuesto |
| --- | --- | --- |
| POST BASE/auth/challenge | {}; Origin/JSON permitidos, sin sesión activa en esa audiencia | 201 cookie prelogin + csrf_token/expires_at |
| POST BASE/auth/sessions | {email,password}; cookie prelogin + X-CSRF-Token | Admin 201 sesión; platform propuesto 202 pending MFA |
| POST BASE/auth/mfa/verify | Pending cookie/CSRF; method/proof según factor aprobado | 201 sesión completa; no consume automáticamente proof de propiedad |
| GET BASE/auth/session | Cookie autenticada vigente y audiencia correcta | 200 identity mínima/session expiración; no permisos/tenant activo |
| GET BASE/auth/csrf | Sesión autenticada + control de origen/fetch metadata | 200 token CSRF estable; no renueva idle |
| DELETE BASE/auth/session | Cookie autenticada + Origin + CSRF | 204 después de revocar y borrar cookie actual |
| DELETE BASE/auth/sessions | {scope}; cookie + Origin/CSRF + proof reciente | 204 tras revocar scope propio y borrar cookie actual |
| POST BASE/auth/reauthentications | {purpose:"revoke_sessions",scope,password}; Origin/CSRF | 201 proof + cookie/CSRF rotados; 202 si falta MFA, sin proof válido |
| POST BASE/auth/session/activity | {}; sesión vigente + Origin/CSRF | 200 nuevos tiempos limitados por absolute |

GET session no lista roles globalmente ni pertenece a un tenant. Membresías propias y
access tenant/branch tienen contratos aparte, con permisos actuales y RLS.
Login acepta sesión global aun sin tenants para onboarding previsto; acceso tenant sigue denegado.
Platform exige además pertenencia SaaS activa. No inferirla del rol Owner del restaurante.

Logout repetido de sesión ya revocada/expirada: proponer 401 SESSION_INVALID y limpiar
cookie de esa audiencia, sin repetir efectos. No afirmar éxito mientras DB es inaccesible.
Sesión inválida se valida antes de CSRF para no revelar token/Identity del registro.

## Ejemplos request/response — ficticios, no ejecuciones

Todos son propuestas. T0 = 2026-10-13T12:00:00Z. Tokens DEMO no cumplen requisitos de
producción. Headers de seguridad/no-store se mantienen también cuando se omiten por brevedad.
Las respuestas incluyen request_id estable por request, sin IDs internos de constraints.
La política temporal mostrada corresponde a los plazos aprobados admin 12 h/7 días;
los mensajes y estados HTTP siguen siendo ejemplos propuestos.

### E1. Bootstrap CSRF antes de login

```http
POST /api/v1/auth/challenge HTTP/1.1
Host: admin.tomopedidos.example
Origin: https://admin.tomopedidos.example
Content-Type: application/json

{}

HTTP/1.1 201 Created
Cache-Control: no-store
Content-Type: application/json
Set-Cookie: __Host-tp_admin_login=PRELOGIN_DEMO; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=600

{"data":{"csrf_token":"CSRF_PRELOGIN_DEMO","expires_at":"2026-10-13T12:10:00Z"},"request_id":"r1"}
```

### E2. Login admin válido a T0

```http
POST /api/v1/auth/sessions HTTP/1.1
Host: admin.tomopedidos.example
Origin: https://admin.tomopedidos.example
Content-Type: application/json
Cookie: __Host-tp_admin_login=PRELOGIN_DEMO
X-CSRF-Token: CSRF_PRELOGIN_DEMO

{"email":"persona@example.test","password":"PASSWORD_DEMO"}

HTTP/1.1 201 Created
Cache-Control: no-store
Content-Type: application/json
Set-Cookie: __Host-tp_admin=SESSION_ADMIN_DEMO; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=604800
Set-Cookie: __Host-tp_admin_login=; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=0

{"data":{"identity":{"id":"11111111-1111-4111-8111-111111111111","email":"persona@example.test"},"session":{"audience":"admin","authentication_level":"password","idle_expires_at":"2026-10-14T00:00:00Z","absolute_expires_at":"2026-10-20T12:00:00Z"},"csrf_token":"CSRF_SESSION_DEMO"},"request_id":"r2"}
```

### E3. Credenciales inválidas con challenge y CSRF válidos

```http
POST /api/v1/auth/sessions HTTP/1.1
Host: admin.tomopedidos.example
Origin: https://admin.tomopedidos.example
Content-Type: application/json
Cookie: __Host-tp_admin_login=PRELOGIN_OTHER_DEMO
X-CSRF-Token: CSRF_PRELOGIN_OTHER_DEMO

{"email":"persona@example.test","password":"PASSWORD_INVALID_DEMO"}

HTTP/1.1 401 Unauthorized
Cache-Control: no-store
Content-Type: application/json

{"error":{"code":"AUTH_INVALID_CREDENTIALS","message":"No se pudo iniciar sesión."},"request_id":"r3"}
```

No cookie autenticada. Challenge queda válido dentro de límite de intentos/tiempo;
cuenta inexistente/bloqueada da misma categoría de error, sin indicar memberships.

### E4. Consulta de sesión sin renovar idle

```http
GET /api/v1/auth/session HTTP/1.1
Host: admin.tomopedidos.example
Sec-Fetch-Site: same-origin
Cookie: __Host-tp_admin=SESSION_ADMIN_DEMO

HTTP/1.1 200 OK
Cache-Control: no-store
Content-Type: application/json

{"data":{"identity":{"id":"11111111-1111-4111-8111-111111111111","email":"persona@example.test"},"session":{"audience":"admin","authentication_level":"password","idle_expires_at":"2026-10-14T00:00:00Z","absolute_expires_at":"2026-10-20T12:00:00Z"}},"request_id":"r4"}
```

No tenant_id activo mutable ni permisos como snapshot autoritativo.

### E5. Recuperar CSRF desde otra pestaña, sin rotarlo

```http
GET /api/v1/auth/csrf HTTP/1.1
Host: admin.tomopedidos.example
Sec-Fetch-Site: same-origin
Cookie: __Host-tp_admin=SESSION_ADMIN_DEMO

HTTP/1.1 200 OK
Cache-Control: no-store
Content-Type: application/json

{"data":{"csrf_token":"CSRF_SESSION_DEMO"},"request_id":"r5"}
```

### E6. Logout actual

```http
DELETE /api/v1/auth/session HTTP/1.1
Host: admin.tomopedidos.example
Origin: https://admin.tomopedidos.example
Cookie: __Host-tp_admin=SESSION_ADMIN_DEMO
X-CSRF-Token: CSRF_SESSION_DEMO

HTTP/1.1 204 No Content
Cache-Control: no-store
Set-Cookie: __Host-tp_admin=; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=0
```

Revocación confirmada antes de 204. No body JSON ni efectos sobre Membership/Owner.

### E7. Replay después de logout, o sesión expirada

```http
GET /api/v1/auth/session HTTP/1.1
Host: admin.tomopedidos.example
Sec-Fetch-Site: same-origin
Cookie: __Host-tp_admin=SESSION_ADMIN_DEMO

HTTP/1.1 401 Unauthorized
Cache-Control: no-store
Content-Type: application/json
Set-Cookie: __Host-tp_admin=; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=0

{"error":{"code":"SESSION_INVALID","message":"Vuelve a iniciar sesión."},"request_id":"r7"}
```

### E8. Logout con CSRF incorrecto y sesión distinta todavía activa

```http
DELETE /api/v1/auth/session HTTP/1.1
Host: admin.tomopedidos.example
Origin: https://admin.tomopedidos.example
Cookie: __Host-tp_admin=SESSION_ADMIN_OTHER_DEMO
X-CSRF-Token: CSRF_WRONG_DEMO

HTTP/1.1 403 Forbidden
Cache-Control: no-store
Content-Type: application/json

{"error":{"code":"CSRF_INVALID","message":"Solicitud no autorizada."},"request_id":"r8"}
```

No revocación ni borrado de cookie; evita logout forzado.

### E9. Cookie admin enviada a platform no es sesión de operador

```http
GET /api/platform/v1/auth/session HTTP/1.1
Host: platform.tomopedidos.example
Sec-Fetch-Site: same-origin
Cookie: __Host-tp_admin=SESSION_ADMIN_OTHER_DEMO

HTTP/1.1 401 Unauthorized
Cache-Control: no-store
Content-Type: application/json

{"error":{"code":"SESSION_INVALID","message":"Vuelve a iniciar sesión."},"request_id":"r9"}
```

Fixture adversarial: navegador normal no enviaría la cookie host-only de otro host.
Además probar token admin puesto manualmente bajo nombre platform: audiencia DB lo rechaza.

### E10. Origin ajeno aunque cookie/CSRF de prueba sean válidos

```http
DELETE /api/v1/auth/session HTTP/1.1
Host: admin.tomopedidos.example
Origin: https://otro.example
Cookie: __Host-tp_admin=SESSION_ADMIN_OTHER_DEMO
X-CSRF-Token: CSRF_SESSION_OTHER_DEMO

HTTP/1.1 403 Forbidden
Cache-Control: no-store
Content-Type: application/json

{"error":{"code":"ORIGIN_DENIED","message":"Solicitud no autorizada."},"request_id":"r10"}
```

Sin Allow-Origin, Set-Cookie ni efectos. No probarlo contra hosts reales.

### E11. Revocar todas las sesiones de la Identity, proof reforzado completo

```http
DELETE /api/v1/auth/sessions HTTP/1.1
Host: admin.tomopedidos.example
Origin: https://admin.tomopedidos.example
Content-Type: application/json
Cookie: __Host-tp_admin=SESSION_ADMIN_REAUTH_DEMO
X-CSRF-Token: CSRF_SESSION_REAUTH_DEMO
X-Reauthentication-Token: REAUTH_ALL_AUDIENCES_DEMO

{"scope":"all_audiences"}

HTTP/1.1 204 No Content
Cache-Control: no-store
Set-Cookie: __Host-tp_admin=; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=0
```

Precondición: proof recién emitido para esta sesión/Identity/scope/purpose; MFA completo
si la Identity es operadora, conforme a la política aprobada. Replay del proof falla.
Sin proof completo: 403 REAUTHENTICATION_REQUIRED, sin revocación parcial.
Cookie platform podría permanecer físicamente, pero su sesión ya no autoriza.

### E12. Platform: password válido deja MFA pendiente, sin sesión privilegiada

```http
POST /api/platform/v1/auth/sessions HTTP/1.1
Host: platform.tomopedidos.example
Origin: https://platform.tomopedidos.example
Content-Type: application/json
Cookie: __Host-tp_platform_login=PRELOGIN_PLATFORM_DEMO
X-CSRF-Token: CSRF_PRELOGIN_PLATFORM_DEMO

{"email":"operador@example.test","password":"PASSWORD_OPERATOR_DEMO"}

HTTP/1.1 202 Accepted
Cache-Control: no-store
Content-Type: application/json
Set-Cookie: __Host-tp_platform_login=MFA_PENDING_DEMO; Path=/; Secure; HttpOnly; SameSite=Lax; Max-Age=300

{"data":{"authenticated":false,"next":"mfa","csrf_token":"CSRF_MFA_PENDING_DEMO","expires_at":"2026-10-13T12:05:00Z"},"request_id":"r12"}
```

Solo para operador con factor ya enrolado, bajo la decisión de MFA obligatorio. No emite
cookie __Host-tp_platform ni prueba nivel MFA completo; otros casos usan onboarding limitado.

## Amenazas y pruebas negativas propuestas

| Amenaza / caso | Resultado requerido al implementar |
| --- | --- |
| Fuerza bruta/enumeración por email/status | Rate limit; error uniforme; password work limitado sin bloqueo perpetuo abusivo |
| Fijación: pretoken elegido, reuse tras login o MFA | Identificador generado server-side, challenge consumido, niveles aislados |
| Login CSRF, cookie prelogin sin token o token de otra fase | Rechazo; no session/login exentos por conveniencia |
| Logout/activity sin CSRF u Origin válido | 403 sin borrar/revocar/renovar sesión |
| Origin suffix/trailing host/null/puerto distinto | Validación exacta; namespace no cruza allowlists |
| Same-site desde subdominio no permitido | Denegado por Origin/CSRF; SameSite no habilita acceso |
| GET csrf de origen ajeno; respuesta cacheada | Denegación de acceso, no-store y token sin logs/URL |
| Polling/heartbeat renueva sesión o activity revive expirada | No extiende idle; expiradas denegadas; absolute siempre limita |
| now igual a idle/absolute; relojes cliente alterados | Expirada por reloj server; pruebas exactas de frontera |
| Logout y requests/login MFA pendientes concurrentes | Nuevas autorizaciones posteriores al commit fallan; pending previo invalidado |
| DELETE global intenta otra Identity/scope sin proof/MFA | Rechazo sin revocación parcial; proof ligado/único |
| DB caída durante auth/logout | 503 fail closed; sin éxito falso ni sesión creada antes de commit |
| Admin token bajo nombre platform, o audience en body | 401; ninguna promoción por nombre/campo cliente |
| Password platform válido sin MFA, replay OTP/challenge | Sin privilegio SaaS; límites/replay según factor |
| Reset/recovery de factor evita refuerzo de ownership | Denegado; procedimiento separado aprobado |
| Cambiar tenant en pestaña A altera B | Contexto por request; claves Query/drafts y Membership independientes |
| Rol/Membership revocado con cookie aún válida | Identidad puede seguir autenticada; acción tenant retirada deniega |
| Native User-Agent elimina CSRF del endpoint web | Rechazo; transporte móvil futuro tiene frontera propia |
| XSS/robo de sesión/bloqueo del puesto | HttpOnly no evita acciones same-origin; CSP, logout accesible y plazos revisados |
| Roles guardados en JWT/cache después de cambio | No fuente de verdad; nuevas solicitudes usan estado vigente |

Fixtures HTTP/BD/local navegador, no producción. E1–E12 son ejemplos documentales, no
tests aprobados. La implementación futura deberá probar cookies reales, clocks controlados,
dos audiencias, concurrencia y dos tenants con permisos distintos.

## Compatibilidad futura y puntos de aprobación

Dominio de Identity/sesiones puede reutilizarse por clientes nativos con audience mobile y
transporte seguro elegido después; no añadir bearer/refresh/OAuth en endpoints web ahora.
La ausencia de Origin de un móvil no permite eximir un endpoint browser existente.
Núcleo no depende de Flutter/FCM. SSE web futuro usa sesión cookie de su audiencia,
autorización por scope y expiración/revalidación acordadas, sin token en query.

No se reabren las políticas aprobadas D01/D02/D06. Requieren revisión flujo operativo
de verificación, política de contraseña y benchmark Argon2id; nombres/persistencia de
cookies y configuración HTTPS local; custodia CSRF; implementación/enrolamiento/recovery
MFA; frescura del refuerzo y semántica in-flight/SSE. La transferencia sigue ADR-002.

## Contratos pendientes de revisión

Todas las rutas, DTOs, estados y ejemplos anteriores siguen propuestos. La aprobación de
seguridad no equivale a aprobación del formato de transporte.

| Área | Propuesta a revisar | Decisión pendiente |
| --- | --- | --- |
| Bootstrap | POST /auth/challenge, 201; challenge activo al iniciar login | TTL 10 min, reutilización/carreras y 409 SESSION_ALREADY_ACTIVE |
| Login | POST /auth/sessions, admin 201; platform 202 MFA pendiente | Campos/normalización, errores genéricos y DTO limitado; ningún acceso operador antes de MFA |
| MFA | POST /auth/mfa/verify, 201 al completar | Payload por factor, estado pendiente 5 min, enrolamiento y recuperación; no escoger biblioteca aún |
| Lecturas | GET /auth/session y /auth/csrf, 200 sin renovar inactividad | Campos públicos, CSRF estable, tratamiento de GET sin Origin/Fetch Metadata |
| Logout actual | DELETE /auth/session, 204 | Sesión ya expirada/revocada: 401 propuesto frente a 204 idempotente; borrado de cookie |
| Revocación | DELETE /auth/sessions con scope explícito | Body DELETE frente a POST de acción; current_audience/all_audiences; revocación global siempre reforzada |
| Reautenticación | POST /auth/reauthentications, 201/202 y header proof | Frescura 5 min propuesta, uso único, binding de operación/scope y rotación cookie/CSRF |
| Actividad | POST /auth/session/activity, 200 | Endpoint frente a lista explícita de operaciones; límites de frecuencia, respuesta y concurrencia |
| Formatos | Envelope data/error y request_id, instantes UTC | Códigos 401/403/409/422/429/503, enum de errores, validación de JSON y Retry-After |
| Transporte | Namespaces admin/platform y cookies distintas | Nombres exactos, prefijo __Host-, Path=/, persistencia, hosts/proxy y preflight 204/403 |

Recomendación: aprobar primero campos de persistencia/estados internos para D2.1;
cerrar estos formatos antes de D4 HTTP, sin publicar endpoints provisionales como estables.

## Siguiente incremento implementable, después de aprobación

El [plan D2.1](d2-1-persistence-plan.md) precisa infraestructura local, esquema mínimo,
sesiones, garantías y pruebas. Implementación requiere autorización separada. DTOs HTTP
después en D4; acceso tenant solo después de D3 y pruebas RLS. No se inició ninguna entrega.
