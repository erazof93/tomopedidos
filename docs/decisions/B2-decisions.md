# D2.1-B2 — registro consolidado de decisiones

Estado: **B2-D01–D10 aprobadas como diseño; ninguna implementación B2 autorizada**.
Diseño técnico B2-A final aprobado: ownership separado, dos ejecutores, revocación
privilegiada sin caller, CSRF persistido, locks/guards y retención30d. Artefactos exactos,
mediciones D04 y CSRF binario/keyring siguen pendientes; ninguna escritura funcional autorizada.
Registro documental: 2026-10-14, a partir de aprobación expresa del usuario.
No existe autorización de implementación de B2-A ni B2-B. No hay migraciones,
código, provisión de roles ni pruebas dinámicas de B2 realizadas por este registro.
B1 está completada para PostgreSQL local; ver [evidencia](../verification.md).
Base: [ADR-003](ADR-003-web-authentication-sessions.md), [ADR-001](ADR-001-hybrid-roles.md),
[ADR-002](ADR-002-role-governance-ownership.md), [diseño B](../architecture/d2-1-b-schema-design.md).

[Especificación B2-A y plan A–F](../architecture/b2-a-specification.md): recomendaciones
finales aprobadas expresamente como diseño, no implementadas ni verificadas. Revocar
por digest requiere frontera confiable de autoridad/posesión: conocer digest no autoriza.
Auth sin EXECUTE de audiencia/global; provisión/paquete de funciones/ACL separados de
Goose. No ampliar B1. B2-A/B2-B continúan no autorizados para implementación.

## B2-D01 — política inicial de correos electrónicos

**Aprobada por el usuario para el MVP. No implementada.**

- Mercado inicial: Perú; admitir direcciones ASCII. No restringe por dominio .pe.
- Conservar correo original y almacenar versión canónica.
- Canonizar eliminando espacios externos y convirtiendo letras ASCII a minúsculas.
- Garantizar unicidad global del correo canónico, independiente del restaurante.
- No eliminar puntos, etiquetas + ni aplicar equivalencias de proveedores.
- Rechazar formatos inválidos, espacios internos, Unicode en la dirección y longitudes excesivas.
- Permitir identidades pendientes o sin credencial; impedir autenticación normal hasta
  que estén activas y su correo esté verificado. Autenticación por contraseña requiere
  además una credencial existente y válida; su ausencia no habilita otro método.
- Soporte Unicode: evolución futura, fuera del MVP.

Compatible con ADR-003: concreta normalización/verificación previamente abiertas;
no cambia Argon2id, MFA, audiencias, cookies ni plazos. Compatible con ADR-001/002:
correo identifica una cuenta global, no concede Membership, Owner ni privilegios SaaS.
B1 no fija política de correos ni contiene tablas de aplicación: no hay incompatibilidad.
El código Go vigente no implementa login ni canonización: no hay contrato ejecutable contrario.
Lowercase de la parte local es política de identidad del producto, no equivalencia
universal de todos los servidores de correo; puede unificar buzones que distingan case.

Implicación de esquema: correo original/canónico, unicidad global y verificación;
La aprobación inicial D01 no fijó gramática, máximos ni espacios exactos; D02 los
concreta posteriormente. DDL/checks definitivos y flujo operativo no implementados.
No autoriza envío de correos, onboarding ni cambios de correo.

Criterios futuros: variantes ASCII de case/espacios externos colisionan; + y puntos
se conservan; Unicode/espacios internos/formato inválido/exceso se rechazan; identidad
pendiente o no verificada no autentica normalmente; ausencia de credencial impide
password login. Pruebas aún no ejecutadas; no se generan cuentas ni correos reales.

## B2-D02 — estados, validación y verificación aprobados

**Aprobada por el usuario como diseño; no implementada.**

Estados pending, active, disabled. Active requiere email_verified_at presente.
Pending puede estar verificada y pendiente de habilitación; verificar correo no
activa automáticamente ni concede acceso, Membership, Owner o privilegios SaaS.
Autenticación normal exige active y correo verificado; por contraseña exige además
credencial válida. Platform conserva pertenencia operadora y MFA obligatorio.
Deshabilitación cambia estado e incrementa epoch global en la misma transacción;
nuevas autorizaciones tras commit deniegan sesiones. Rehabilitar no resucita sesiones
con epoch anterior. No se garantiza cancelación retroactiva de acciones autorizadas.
Conservar correo/verificación/relaciones al deshabilitar; guards de último Owner
siguen siendo requisito de un futuro flujo, no un bypass habilitado por B2.

Validación/canonización: rechazar Unicode y controles, incluidos tabs/CR/LF externos;
retirar exclusivamente espacios ASCII U+0020 externos. Email_original conserva case
y caracteres aceptados, sin espacios externos; email_canonical convierte A–Z a a–z.
Unicidad global permanente, sin reglas de proveedor ni eliminación de puntos/+.

Gramática restringida aprobada conforme al análisis anterior:
- Un único @; local y dominio no vacíos; sin display names, comentarios, listas,
  comillas ni escapes. Local: segmentos no vacíos separados por puntos; sin puntos
  inicial/final/consecutivos. Caracteres de segmento: letras ASCII, dígitos,
  !#$%&'*+-/=?^_, acento grave y {|}~.
- Dominio con al menos dos etiquetas; letras ASCII, dígitos y guion, inicio/final
  alfanuméricos. Sin etiquetas vacías, underscore, punto final ni literales IP;
  rechazar dominio enteramente numérico. Sin restricción .pe ni lista fija de TLD.
- Etiquetas ASCII xn-- admitidas si cumplen esta gramática; sin conversión Unicode
  ni promesa de validación IDNA/deliverability. Unicode de entrada sigue rechazado.
- Máximos simultáneos: dirección 254 bytes, local 64, dominio 253, etiqueta 63.
  El límite total domina: local de 1 byte + @ deja máximo efectivo 252 al dominio;
  el límite independiente 253 no autoriza exceder 254. Medir después del trim externo.

Representación de verificación: email_verified_at nullable, sin boolean redundante;
marca solo de proceso autorizado, no derivada de sintaxis/DNS. Constraints y Go deben
compartir gramática/ASCII/bytes/correspondencia original-canónico; NOT NULL obligatorio
y CHECK active implica verificación. No CHECK dinámico now ni prueba de entrega.
DDL exacto y transición/protocolo concurrente quedan por especificar; no ejecutados.
Sin envío de verificación, recuperación, activación pública ni cambio público de correo.

Aceptación futura: fronteras 64/65, 254/255 y 63/64; corpus Go/PostgreSQL equivalente,
invalidación de pending/disabled/no verificada, ausencia de credencial, unicidad,
deshabilitación concurrente con emisión/actividad y rehabilitación sin resurrección.

## B2-D06 — HMAC CSRF aprobado como diseño

**Aprobada por el usuario como diseño; no implementada.**

- HMAC-SHA-256 ligado a identidad, sesión, audiencia, generación y salt.
- Clave independiente del propósito CSRF, fuera de PostgreSQL y repositorios.
- Token estable por generación, sin TTL propio; solo válido con sesión/identidad
  vigentes, audiencia correcta y epochs/revocación/expiración válidos.
- Key_id selecciona clave; rotación conserva claves mientras existan sesiones válidas
  que las referencien. No extender sesiones ni aceptar binding incorrecto.
- Origin estricto, fallo cerrado, comparación de MAC con hmac.Equal.
- No implementar prelogin, MFA ni step-up; esos futuros propósitos no reutilizan
  indistintamente el binding de una sesión autenticada.

**Especificaciones pendientes, no funcionalidades implementadas:** codificación binaria
no ambigua/versionada (tamaños/orden/purpose), formato exacto y límites del token/key_id,
tamaño de clave/salt, generación inicial, DDL, keyring/proveedor de custodia, rollout
multiinstancia, retirada/compromiso/retención y recuperación operativa. La política
de mantener claves con sesiones válidas sí está aprobada; su runbook no lo está.
No se aprobó AES-GCM como mecanismo seleccionado ni se generaron claves.

Aceptación futura: tokens cruzados/manipulados, claves ausentes, sesiones expiradas/
revocadas/disabled, rotación multiinstancia, Origin inválido, igualdad constante del
MAC, estabilidad entre pestañas y ausencia de secretos en logs. No pruebas ejecutadas.

## Matriz histórica de propuestas antes de aprobar D03–D05

Se conserva trazabilidad: D03–D05 de esta tabla fueron aprobadas posteriormente
con las precisiones siguientes; D07–D10 permanecen propuestas.

| ID | Decisión por aprobar | Alternativas y recomendación propuesta | Riesgo, esquema y aceptación futura |
| --- | --- | --- | --- |
| B2-D03 | Credenciales, UUID y ciclo de vida | Relación opcional 0..1; nombre identity.identity_credentials frente a password_credentials; recomendar el primero, exclusivo de contraseña en este corte. UUIDv4 criptográfico en Go frente a UUID DB; versión de credencial y FK RESTRICT, sin borrado público. | La optionalidad básica está aprobada en D01; falta representación, UUID, cambios/rehash y retención. No saltarse guards de último Owner al desactivar identidad. Pruebas de FK, ausencia, duplicados y versión concurrente. |
| B2-D04 | Formato Argon2id, límites y benchmark | PHC versionado frente a formato propio; proponer PHC, salt 16 bytes y salida 32 bytes. Perfil inicial de medición: m=19456 KiB,t=2,p=1; comparar con 64 MiB,t=2/3,p=1. Sin pepper inicial propuesto. | Parámetros definitivos sujetos a benchmark, no aprobados. Aprobar política de contraseña, límite de bytes sin truncar/normalizar, techo de parámetros y cola/concurrencia antes de uso. Medir p50/p95, memoria y cancelación con fixtures; parser hostil y parámetros enormes rechazados antes de asignar recursos. |
| B2-D05 | Tokens opacos y entrega | Proponer 32 bytes de crypto/rand, base64url sin padding, SHA-256 sobre bytes originales y BYTEA de 32 bytes UNIQUE. Alternativa HMAC para digest. ID independiente del token; secreto solo tras commit confirmado. | No reutilizar SHA-256 para password. Fallo RNG/rollback/commit ambiguo sin token publicado. Constraints y tests de formato, duplicados, fallos y ausencia de secretos. |
| B2-D07 | Revocación global y por audiencia | Epoch global frente a actualización de todas las sesiones; recomendar epoch global. Epoch por audiencia solo si se aprueba current_audience; propuesta incluir ambos para ese alcance. Logout individual mediante revoked_at. | Elegir alcance; BIGINT no negativo, filas por identidad/audiencia y snapshots de epochs. Ausencia de fila falla cerrada. Pruebas de global/audiencia/individual, otra identidad y overflow. Refuerzo reciente/MFA operador de ADR-003 sigue obligatorio en futura frontera pública. |
| B2-D08 | Protocolo transaccional | READ COMMITTED con bloqueos frente a serializable/control optimista; recomendar orden identidad → audiencia → sesión. Argon2 fuera de locks, revalidar versión/epochs bajo locks; emisión y validación con compartidos, revocación relevante con exclusivos, actividad serializada por sesión. | Contención y deadlocks; precisar consultas/grants/timeouts y tratamiento de errores antes de B2-B. No adoptar epoch nuevo con evidencia antigua. Carreras emisión/revocación/actividad/credencial, cancelación y rollback; sin caché de seguridad como fallback. |
| B2-D09 | Rol auth y privilegios | Runtime único frente a tomopedidos_auth_runtime independiente; recomendar rol/pool auth propio sin membership owner/migrator, ownership ni bypass. SELECT necesario, INSERT de sesiones y UPDATE acotado a actividad/revocación/epochs; altas/cambios de credenciales fuera del runtime inicial. | CONNECT/USAGE/grants por consulta, incluidos permisos necesarios para locks, se deben concretar. Owner tp_owner; runtime tenant conserva denegación identity. Provisión cluster separada de migraciones: migrator no tiene CREATEROLE. Pruebas negativas de rol/grants y rechazo bootstrap en API. |
| B2-D10 | Tiempo y alcance B2-A/B2-B | Proponer PostgreSQL como reloj, clock_timestamp una vez después de locks; igualdad con límite expira. B2-A esquema/constraints/índices/ownership/contrato de grants; B2-B sqlc/pgx/primitivas internas y fixtures, sin HTTP. | Aprobar constraints exactos, fuente temporal, clock rollback, catálogo de queries, índices y gates. Up/down solo en DB desechable autorizada; B2-B no genera sesiones utilizables ni cuentas reales. Pruebas temporales/concurrencia, sqlc/test/vet/build posteriores bajo autorización. |

## B2-D06 — comparación histórica y especificación pendiente

Propuesta HMAC: persistir csrf_key_id, csrf_generation y salt aleatorio por sesión.
Reproducir token con HMAC-SHA-256 sobre una codificación no ambigua y versionada de
purpose, ID sesión, ID identidad, audience, generation y salt. No usar correo mutable
ni exponer token de acceso o digest como identificador CSRF. Clave exclusiva del propósito
CSRF fuera de BD/repositorio; comparación constante. El salt no requiere confidencialidad.
Esto no obliga a usar double-submit cookie; mecanismo de transporte HTTP queda aparte.

| Aspecto | HMAC vinculado a sesión | AES-256-GCM de secreto aleatorio |
| --- | --- | --- |
| Garantía | Autenticidad/binding; impredecible sin clave. No cifra mensajes. | Confidencialidad e integridad del secreto; AAD liga sesión/identidad/audiencia. |
| Persistencia | key_id, generación y salt; token reproducible, sin ciphertext ni secreto bruto. | key_id, nonce y ciphertext/tag; secreto recuperable al descifrar. |
| Nonces | Salt aleatorio sin requisito de unicidad criptográfica GCM; binding por sesión. | Nonce debe ser único bajo cada clave; reuso rompe garantías. |
| Rotación rutinaria | Nuevas sesiones usan clave nueva. Sesiones antiguas conservan key_id y token estable mientras viva la clave. | Nuevas sesiones usan clave nueva; antiguos secretos pueden recifrarse sin cambiar el token del navegador. |
| Retirada de clave | Conservar hasta vencimiento/revocación de sesiones dependientes; migrar key_id cambia token y exige coordinación entre pestañas. | Recifrar permite retirar clave tras migración validada de todos los registros; operación adicional con nonces nuevos. |
| Compromiso | Revocar sesiones dependientes y retirar clave; no seguir aceptando tokens antiguos por conveniencia. | Recifrar no neutraliza secretos ya expuestos: también requiere revocación/rotación de sesiones afectadas. |
| Operación | Keyring, versionado y binding; no proceso de descifrado/recifrado. | Keyring, AAD, nonces, descifrado y eventual job de recifrado. |
| Fallo | Clave desconocida o binding inválido deniega; nunca fallback sin CSRF. | Clave ausente/tag inválido deniega; nunca aceptar plaintext como fallback. |
| Pruebas | Cambios de sesión/audiencia/purpose/salt/generación/key_id; stable token, rotación y multiinstancia. | Alteración de ciphertext/AAD/nonce/tag, unicidad de nonce, recifrado, claves ausentes y multiinstancia. |

Selección posteriormente **aprobada como diseño**: HMAC para este MVP. La comparación
anterior conserva la trazabilidad de alternativas; no deja AES como selección pendiente.
Codificación, formato y operación siguen pendientes. AES sigue siendo una alternativa
si se requiere recifrar conservando exactamente el secreto durante retirada de claves.
Ninguna opción elimina Origin estricto, verificación de audiencia/sesión vigente,
CSRF prelogin futuro ni riesgos de XSS. Salt y generación persisten estables durante
lecturas; elevación/rotación de sesión cambia binding conforme al futuro contrato aprobado.
Retención de claves contempla expiración máxima admin 7 días/platform 8 horas y ventana
operativa explícita; nunca extiende validez de sesiones.

Fuentes: [OWASP CSRF](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html)
respalda binding HMAC a sesión; [NIST GCM](https://csrc.nist.gov/pubs/sp/800/38/d/final)
define cifrado autenticado y requisitos de IV. La recomendación MVP es juicio del proyecto,
no selección automática impuesta por estas fuentes.

## Reglas propuestas de sesión, no implementación

Sesión válida requiere identidad activa/verificada, audiencia correcta, epochs vigentes,
revoked_at ausente y t menor que idle_expires_at y absolute_expires_at.
Admin 12 h/7 días y platform 15 min/8 h son políticas ya aprobadas.
Actividad solo sobre sesión vigente: idle nuevo limitado por absoluto y sin retroceder
el vencimiento previo; last_activity tampoco retrocede. Igualdad expira; lookup/polling
no renuevan; ancla absoluta inmutable. Instante t tomado tras locks.
Invariantes estáticos: tiempos obligatorios/coherentes y longitudes de digest;
no CHECK de vigencia dependiente de now(). Detalles finales pendientes en D10.

## Trazabilidad y gates

D01 permite identidad sin credencial: esa optionalidad ya no es decisión pendiente.
Representación 0..1, UUID y ciclo de vida se aprobaron después en D03;
estados y gramática en D02, sin atribuirlos retroactivamente a D01.
Identidades/sesiones no almacenan tenant activo mutable, permisos o condición Owner.
No confundir políticas aprobadas con rutas HTTP, MFA o autorización B2-A/B2-B.

El antiguo password_credentials es referencia histórica del nombre de diseño
identity_credentials aprobado en D03; no se declara tabla implementada.
Textos históricos de B1 sobre roles no verificados/Goose bootstrap son superados por
Compose y evidencia de cierre. La ejecución real de Goose y configuración privada de
su consumidor siguen fuera de lo demostrado por B1; no se infieren de login exitoso.

Antes de diseñar migraciones: cerrar especificaciones persistentes de D01–D10,
incluyendo CSRF/epochs/grants y constraints. Costes Argon2 definitivos
requieren benchmark futuro autorizado; el formato de almacenamiento puede revisarse antes.
Luego autorizar por separado diseño/implementación B2-A, aplicación en DB desechable,
provisión auth y B2-B. Esta documentación no concede ninguna de esas autorizaciones.

## Revisión histórica — D03, D04 y D05 antes de aprobación

Esta matriz conserva alternativas previas; las decisiones aprobadas posteriores
se especifican abajo. No autoriza implementación ni ejecución.

| Decisión | Contrato y alternativas | Recomendación concreta para revisar | Impacto/riesgo | Aceptación futura |
| --- | --- | --- | --- | --- |
| D03 — relación/nombre | Optionalidad aprobada; 0..1 o múltiples credenciales; nombre previo password_credentials | identity.identity_credentials con identity_id PK/FK; una contraseña por identidad, no tabla genérica MFA | FK RESTRICT, hash obligatorio si existe fila; identidad sin credencial no tiene password login | Ausencia, huérfana/duplicada, estados D02 y FK |
| D03 — IDs | UUID Go o DB; v4 o v7 | UUIDv4 con aleatoriedad criptográfica en Go, separado de secreto de sesión | Seleccionar implementación sin instalar dependencias; ID no autentica | RNG fallido, formato, duplicados y separación ID/token |
| D03 — ciclo | Hard delete, desactivación, versión | Versionar credencial y changed_at; cambio/remoción semánticos incrementan epoch global atómicamente. Rehash equivalente no revoca; comparación optimista impide sobrescribir un cambio concurrente | Retención y auditoría por resolver; no activar cambio/recuperación públicos ni eludir Owner | Cambio vs emisión, rehash vs cambio, rollback y no resurrección |
| D04 — formato | PHC autocontenido o columnas separadas; pepper opcional | PHC Argon2id versionado; salt 16 bytes, salida 32; sin pepper inicial propuesto | Parser estricto, parámetros y longitudes acotados; nunca truncar/normalizar password | Hash válido/inválido, parámetros hostiles, salts diferentes |
| D04 — costes/benchmark | Perfil único o escalonado | Medir 19 MiB,t=2,p=1 y 64 MiB,t=2/3,p=1; concurrencia 1/2/4; p50/p95, RSS, cola y cancelación. NO fijar aún perfil definitivo | Política de password, máximo bytes, límites de parámetros/memoria/concurrencia, hardware y objetivos requieren aprobación; contexto cancelado no garantiza interrumpir Argon2 ya iniciado | Benchmark posterior autorizado; exceso rechazado antes de reservar; cola acotada y ninguna respuesta con secretos |
| D05 — generación/digest | SHA-256 o HMAC; raw token en DB descartado | crypto/rand 32 bytes, transporte base64url sin padding; SHA-256 de bytes originales; BYTEA32 UNIQUE, ID independiente | No pepper/keyring extra para token aleatorio; no usar SHA-256 para contraseñas | RNG, longitud, decodificación canónica, duplicado y no exposición |
| D05 — entrega/fallos | Entrega antes o después de commit | Entrega solo tras commit confirmado; rollback/commit ambiguo no publica token ni éxito. No reintento ciego | Posible sesión huérfana sin secreto entregado, expira/limpia según política posterior. Retención/cleanup por aprobar | Commit/rollback/cancelación/ambigüedad, concurrencia y logs sin secretos |

No se generaron UUID, tokens, contraseñas ni perfiles medidos. D04 definitivo depende
del benchmark autorizado, no de la aprobación de un formato documental.

## B2-D03 — credenciales y UUID aprobados como diseño

Fuente: aprobación expresa del usuario; registro documental 2026-10-14.
No implementada. Identity.identity_credentials con relación opcional 0..1,
identity_id PK/FK; exclusiva de contraseña, no tabla genérica de factores MFA.
UUIDv4 criptográfico generado en Go. Ausencia de credencial no habilita otro login.

Credential_revision durable en Identity: crear, sustituir y eliminar credencial
incrementan revisión, sin reinicio al recrear fila. Cambios semánticos de contraseña
incrementan auth_epoch global atómicamente. Rehash equivalente incrementa revisión
sin revocar sesiones y es condicional a la revisión/credencial verificadas para no
sobrescribir una nueva. Protocolo de emisión/concurrencia exacto pendiente en D08.

Compatible D01/D02/ADR-003: active/verificado sigue obligatorio; credencial global
no concede Membership/Owner. Sin cambio público de password/recuperación/registro.
DDL, constraints/FK/retención/auditoría y consultas condicionales por especificar.
Pruebas futuras: FK/duplicados/ausencia, UUID/RNG, cambio/remoción/recreación vs
emisión, rehash vs cambio, rollback y denegación tenant de datos sensibles.

## B2-D04 — Argon2id aprobado como diseño

PHC autocontenido Argon2id versión 19, salt aleatorio 16 bytes y hash 32 bytes;
sin pepper inicial. Perfiles explícitos de creación/verificación; parser estricto
y límites antes de ejecutar Argon2id. Rehash oportunista seguro sin degradación.
No normalizar/truncar password ni registrar password/hash/salt en logs.

Candidatos aprobados para benchmark futuro, no perfiles de runtime elegidos:

| Memoria | Iteraciones | Paralelismo |
| --- | --- | --- |
| 19 MiB (19456 KiB) | 2 | 1 |
| 64 MiB (65536 KiB) | 2 | 1 |
| 64 MiB (65536 KiB) | 3 | 1 |

**Pendientes de benchmark y aprobación:** parámetros definitivos, límites de
contraseña/concurrencia/cola/memoria/latencia, techos de verificación y perfiles
históricos aceptados. Benchmark no realizado ni autorizado por este registro.
Cancelar contexto no garantiza detener Argon2 iniciado; conservar cupo hasta terminar.
Pruebas futuras: PHC/perfiles hostiles, salts, límites/cola/cancelación, comparación
constante, rehash concurrente y mediciones reproducibles. Formato puede especificarse
sin presentar costes como medidos o aprobados definitivamente.

## B2-D05 — tokens opacos aprobados como diseño

32 bytes de RNG criptográfico, base64url canónica sin padding (43 caracteres),
SHA-256 de bytes originales. Solo digest32 con UNIQUE en DB; session_id independiente.
Secreto entregado solo tras commit confirmado; commit ambiguo falla cerrado sin
reintento ciego. RNG fallido/rollback no permiten fallback o publicación de token.
No tokens en logs/trazas/URLs/respuestas públicas ordinarias; futura entrega mediante
cookies seguras. No cookies/endpoints implementados. D06 mantiene clave/binding propios.
Estado server-side de identidad/audiencia/epochs/expiración/revocación sigue necesario.
Constraints/queries, colisiones, retención/cleanup y transporte exacto por especificar.
Pruebas futuras: longitud/decodificación canónica, digest/UNIQUE, RNG, rollback,
commit ambiguo/entrega fallida, expiración/revocación y ausencia de secretos.

## Matriz histórica — D07–D10 antes de aprobación

Se conservan alternativas previas. D07–D10 fueron aprobadas posteriormente con las
precisiones siguientes; esta tabla histórica no autoriza ejecución ni implementación.

| ID | Contrato vigente y alternativas | Recomendación propuesta | Riesgos/impacto y aprobación pendiente | Aceptación futura |
| --- | --- | --- | --- | --- |
| D07 | D02/D03 obligan epoch global atómico en disabled/cambio semántico; ADR-003 exige revocación/refuerzo. Epoch vs barrido de sesiones | Epoch global durable no negativo; individual mediante revoked_at; añadir epoch por audiencia solo si se aprueba current_audience | Scope, tipos/overflow, filas iniciales, retención/auditoría e in-flight por aprobar. Falta de fila falla cerrado; logout no elimina Membership/Owner ni evita MFA/refuerzo | Global ambas audiencias; individual solo sesión; audiencia opcional aislada; otra identidad intacta; sin resurrección |
| D08 | D03 revisión y D05 commit; serializable vs locks explícitos vs control optimista | READ COMMITTED y orden identidad → audiencia → sesión; compartidos para validar/emitir y exclusivos para revocación relevante; actividad/logout serializados por sesión; Argon2 fuera de locks y revalidación posterior | Concretar queries/grants/locks/timeouts, CAS de rehash, punto de autorización y errores/reintentos. No adoptar epoch nuevo con evidencia vieja; no retry ciego ante commit ambiguo | Carreras emisión/revocación/disabled/actividad/rehash; deadlock/cancelación/rollback; pool liberado; sin fallback de seguridad obsoleto |
| D09 | B1 niega identity a runtime tenant; rol único vs auth separado vs funciones | Rol/pool auth independiente, sin membership owner/migrator/BYPASSRLS; CONNECT/USAGE identity, SELECT necesario, INSERT sesiones, UPDATE acotado | Matriz por query/columnas y locks; lectura de hashes sensible; mantenimiento separado; no grants automáticos de cambio password. Aprobar atributos/pool/custodia. Provisión cluster separada: migrator no CREATEROLE | Tenant no lee hashes/sesiones; auth no negocio/DDL/SET ROLE; API rechaza bootstrap/migrator |
| D10 | Plazos/igualdad expirada ADR-003; reloj Go vs tiempo PostgreSQL por operación | clock_timestamp una vez tras locks, timestamptz UTC; activity vigente con límite absoluto sin retroceder; B2-A esquema/constraints/índices/ownership y B2-B sqlc/pgx/primitivas/fixtures | Constraints, reloj retrocedido, queries/índices, keyring D06, cleanup y gates por aprobar. No CHECK dinámico; no HTTP/cuentas reales/sesiones platform operativas ni migración al arrancar API | Fronteras exactas, espera de locks, clock rollback, polling no renueva, reproducibilidad y aislamiento DB desechable |

Pendientes actuales: especificaciones de implementación, no aprobación arquitectónica
D07–D10. D01–D10 aprobadas no equivalen a B2 implementado; B2-A/B2-B no autorizados.

## B2-D07–D10 — aprobación arquitectónica

Fuente: aprobación expresa del usuario, registro documental 2026-10-14.
Diseño aprobado, no implementado ni verificado mediante pruebas B2.

### D07 — epochs y revocación

Auth_epoch global y epoch por audiencia durables, monotónicos y no negativos.
Filas admin/platform creadas atómicamente con Identity; no conceden acceso platform.
Sesiones capturan ambos epochs. Logout individual mediante revoked_at.
Primera creación de contraseña incrementa epoch global; rehash equivalente no revoca.
Filas ausentes y overflow fallan cerrado; no reset, wrap ni revocación afirmada ante
fallo. Rehabilitación no resucita sesiones con epoch antiguo. D03 conserva revisión
durable distinta de epoch: rehash cambia revisión sin invalidar sesiones.
Iniciales/tipos/constraints/incrementos y protocolo excepcional de overflow por especificar.
Snapshots de epochs no deben impedir incrementar contadores mediante una FK al valor actual.

### D08 — transacciones y concurrencia

READ COMMITTED con bloqueos explícitos, orden identidad → audiencia → sesión.
Argon2 fuera de bloqueos; revalidar estado, credential_revision y epochs después.
No upgrades compartido→exclusivo; adquirir modo requerido desde el inicio.
Rehash condicional en operación separada. Punto de autorización: última revalidación
de estado/epochs/sesión/tiempo bajo los bloqueos correspondientes antes de permitir
la operación. Revocación confirmada antes de ese punto deniega; no se promete cancelar
retroactivamente una operación ya autorizada. Locks/queries exactos por especificar.
Sin retries automáticos iniciales. Deadlock/cancelación/timeout abortan y terminan tx,
liberando conexión; no reutilizar tx abandonada. Commit ambiguo no entrega secretos
ni afirma éxito. Límites de duración/lock/timeout y error mapping siguen pendientes.

### D09 — rol y pool auth

Rol independiente tomopedidos_auth_runtime y pool auth separado; sin DDL, ownership,
migración, privilegios elevados ni acceso a datos operativos. Tp_owner conserva
ownership; migraciones futuras via migrator asumiendo owner conforme B1.
Grants concretos pendientes de derivación por query/tabla/columna/operación y pruebas
negativas, incluidos permisos necesarios para locks. Provisión del rol/credenciales
requiere autorización separada; migrator no tiene CREATEROLE. No rol/pool creado.
Pool separado no aísla frente al compromiso completo del mismo proceso Go.

### D10 — tiempo, expiración y operación

PostgreSQL como autoridad; capturar clock_timestamp después de adquirir bloqueos.
Admin idle 12 h/absoluto 7 días; platform idle 15 min/absoluto 8 h.
Igualdad con límite expira; absolute_expires_at inmutable.
Expired_at terminal persistido aprobado: expiración detectada nunca vuelve a validar,
aunque retroceda el reloj. No equivale a reloj monotónico ni a detectar todas las
expiraciones exactamente al vencer; comparación temporal sigue obligatoria.
Protocolo de marcado terminal sin upgrades de locks requiere especificación.
SSE/polling/timers/reconexiones no renuevan idle. Actividad interactiva autorizada
puede renovar sin superar absoluto; no revive revoked/expired/disabled.

Reautenticación anticipada, avisos, sustitución de sesión y recuperación operativa
son requisitos futuros, no endpoints/UX implementados. No extender absoluto en
silencio. Varias cajeras requieren identidades/sesiones independientes; expiración
no elimina pedidos confirmados. Recuperación tras autenticar debe revalidar permisos
y recuperar estado autoritativo antes de restablecer SSE; idempotencia/replay/resync
siguen contratos futuros. SSE no es autoridad ni prueba actividad humana.

## Bloqueos priorizados antes de autorizar B2-A

| Prioridad | Especificación pendiente | Resultado revisable requerido |
| --- | --- | --- |
| 1 | DDL exacto | Campos/tipos/nullability/defaults/PK/FK/UNIQUE/CHECK de identidad, credential_revision, credencial PHC, epochs/audiencias, sesiones, revoked_at/expired_at y CSRF; índices ligados a queries. Monotonicidad/ancla absoluta no se garantizan con simple CHECK no negativo |
| 2 | Contrato CSRF persistente | Tamaños/versión/generación/salt/key_id, codificación binaria no ambigua y formato token; política keyring/custodia/rotación. Especificar qué bloquea esquema y qué bloquea runtime |
| 3 | Queries y grants | Operaciones necesarias, locks exactos y grants por query; frontera auth/tenant y mantenimiento. Pruebas negativas diseñadas, no ejecutadas; provisión separada |
| 4 | Transacciones y tiempo | Queries/relectura tras locks, estado terminal de expiración, no upgrades, overflow, límites tx/lock/statement timeout y cancelación; sin retry inicial/commit ambiguo cerrado |
| 5 | Retención e índices de limpieza | Política30d/terminalidad conocida aprobada posteriormente; query/índice/medición y operación por revisar. Sin borrar contadores/sesiones válidas ni retirar claves necesarias |
| 6 | Alcance/autorización y targets | B2-A esquema/constraints/índices/ownership/contrato de grants; B2-B acceso interno sqlc/pgx/primitivas/fixtures. Diseño, implementación, aplicación DB desechable y provisión independientes; no migraciones al arrancar API |

El coste definitivo Argon2 no bloquea almacenar PHC en B2-A. Sí bloquea B2-B junto
a máximos de contraseña/memoria/concurrencia/latencia, benchmark autorizado,
queries/grants/pool y CSRF binario/keyring/runbook. No existe autorización B2-A/B2-B.

### Retención de 30 días — aprobación de diseño posterior

Política posteriormente aprobada: 30 días desde primera terminalidad conocida
(marca explícita o vencimiento natural). Si solo epoch invalida y no hay fecha
individual, puede conservarse hasta vencimiento natural+30d; no inventar fecha.
Expired_at de detección no cambia el vencimiento natural anterior; no usar created_at/job.
Alternativas: menos retención minimiza datos; más facilita incidentes y auditoría.
No aplicar 30 días a Identity, credenciales, epochs, pedidos ni auditoría sin contrato
propio. No retener secretos brutos; digest/metadatos siguen sensibles. Retención de
claves CSRF depende de sesiones válidas, no del período histórico de sesiones inválidas.
Alcance/plazo/ancla aprobados; query/índice/actor/medición de lotes y operación requieren
artefactos revisados y autorización. Lote100 candidato sujeto a medición, no benchmark.

### Aceptación futura, no ejecutada

Epoch global/audiencia/individual con aislamiento, filas ausentes/overflow sin éxito
falso, rehabilitación sin resurrección; carreras emisión/cambio/revocación/actividad,
CAS de rehash y locks sin upgrade; cancelación/deadlock/timeout/commit ambiguo sin
secretos ni tx residuales. Negativos tenant/auth/owner/migrator. Tiempo exacto,
esperas y retroceso de reloj con expired_at terminal; actividad automática no renueva.
DDL/queries/sqlc reproducibles y targets desechables autorizados. Avisos/pedidos/SSE
requieren pruebas futuras propias y no se declaran cubiertos por B2.
