# ADR-003 — Autenticación web y sesiones (D1.1)

Estado: **políticas D1.1 aprobadas; detalles HTTP y MFA pendientes; no implementado**.
La preparación documental de D1.1 no completa su implementación ni inicia endpoints.
La instrucción actual confirma como aprobadas decisiones que el diseño anterior aún
presentaba como recomendaciones; se actualiza su clasificación, sin alterar ADR-001/002.

## Base aprobada que se conserva

- Identity global separada de Membership, roles y permisos tenant/branch.
- Sesiones opacas en PostgreSQL y revocación server-side; Go autoriza cada solicitud.
- Protección CSRF, CORS restrictivo y separación restaurante/operador.
- PostgreSQL local mediante Docker, migraciones SQL Goose y generación Go con sqlc.
- Núcleo independiente de Flutter/Firebase/proveedor externo de autenticación.
- Gobierno de roles/propiedad de [ADR-001](ADR-001-hybrid-roles.md) y
  [ADR-002](ADR-002-role-governance-ownership.md).

## Decisiones aprobadas de D1.1

| ID | Decisión aprobada | Detalle pendiente |
| --- | --- | --- |
| A1 | Correo/contraseña con Argon2id configurable; B2-D01/D02 aprueban política ASCII, gramática/límites y elegibilidad | Envío/flujo de verificación, política de contraseña, formato/benchmark y límites de coste |
| A2 | Cookies host-only, HttpOnly, Secure, SameSite=Lax | Nombres, prefijo __Host-, Path=/ y persistencia del navegador |
| A3 | Admin: inactividad 12 h, duración absoluta 7 días | Algoritmo atómico de renovación, rotación y limpieza |
| A4 | Platform: inactividad 15 min, duración absoluta 8 h | Mismas garantías, sin heredar plazos admin |
| A5 | Audiencias separadas; sesiones opacas PostgreSQL revocables | Namespaces, cookies y representación de estados |
| A6 | CSRF prelogin y por sesión; Origin estricto; D06 aprueba HMAC vinculado a sesión y clave independiente | Codificación/token/runbook de claves; prelogin/challenges y GET sin Origin; sin implementación |
| A7 | Revocación global exige autenticación reciente y MFA para identidades operadoras | Rutas, scopes, frescura, proof, estados y semántica de logout repetido |
| A8 | MFA obligatorio para operadores; WebAuthn/passkeys objetivo y TOTP alternativa inicial | Implementación exacta, enrolamiento, primer operador y recuperación |
| A9 | Autorización tenant/sucursal en cada solicitud | Sin contexto global mutable entre pestañas; pruebas y mecanismo transaccional |
| A10 | API del mismo origen por panel; renovación solo por actividad autenticada explícita | HTTPS local/proxy, orígenes concretos y señal de actividad; polling/consulta de sesión no renuevan |

No se escoge JWT como sesión web: sesiones opacas ya están aprobadas. Protocolos móviles
futuros podrán usar transporte propio con audiencia separada, sin definirlo en D1.1.
MFA obligatorio no significa implementación elegida ni disponible. La verificación
reforzada de transferencia de ADR-002 conserva su flujo propio; login MFA no la sustituye.

## Persistencia aprobada

PostgreSQL local mediante Docker Compose, migraciones SQL versionadas con Goose y código
Go generado con sqlc. Credenciales de migración y runtime separadas. El arranque normal
de la API no ejecuta migraciones; consultas manuales en Supabase no son el mecanismo
habitual de evolución del esquema. Versiones, grants y esquema concreto siguen por revisar.

## Contrato y fundamento

La política, modelo de estados, contratos HTTP, doce ejemplos y pruebas negativas están
en [web-authentication.md](../architecture/web-authentication.md). Es la referencia única
para detalles D1.1; el diseño general solo conserva el índice.

D05 aprueba token opaco aleatorio de 256 bits y SHA-256 de bytes originales en BD; permisos
consultados aparte y revocación efectiva en nuevas solicitudes. Cookies evitan exponer
credenciales de sesión a JavaScript; expiración se valida en servidor.
[OWASP Session Management](https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html).
Origin/CSRF se validan además de SameSite; CORS no constituye autenticación.
[OWASP CSRF](https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html).

## Consolidación B2

[B2-D01](B2-decisions.md#b2-d01--política-inicial-de-correos-electrónicos) aprueba
correo ASCII, original/canónico, trim externo y lowercase ASCII, unicidad global,
sin reglas por proveedor y autenticación normal solo con identidad activa/verificada.
Admite identidades pendientes/sin credencial; no implementa login ni envío de correo.
D02 aprueba pending/active/disabled, gramática/límites y epoch global atómico al
deshabilitar, sin resurrección. D06 aprueba HMAC-SHA-256 ligado a sesión, clave externa,
Origin/fallo cerrado y hmac.Equal; codificación, token y runbook pendientes.
D03–D05 aprobadas como diseño: credencial 0..1/UUIDv4/revisión durable, PHC Argon2id
versión 19 salt16/hash32 y tokens32/base64url/SHA-256 tras commit confirmado.
D07–D10 aprobadas como diseño: epochs global/audiencia, locks READ COMMITTED,
auth independiente y tiempo PostgreSQL/expired_at terminal. DDL/grants/timeouts,
CSRF binario/keyring, retención y Argon2id definitivo/límites pendientes.
Retención de 30 días solo propuesta. Avisos/reautenticación/SSE requisitos futuros.
B2-A/B2-B no autorizados. No se implementan envío, prelogin, MFA o step-up.

## Aprobaciones necesarias y siguiente incremento

A1–A10 registran las políticas aprobadas, no aprobación automática de DTOs, rutas,
códigos HTTP ni propuestas criptográficas/operativas adicionales. Los detalles abiertos
están en el [contrato web](../architecture/web-authentication.md#contratos-pendientes-de-revisión).
No hay instalación, servicios ni migraciones en este trabajo.

Se propone [D2.1: persistencia local y sesiones](../architecture/d2-1-persistence-plan.md),
con criterios y límites verificables. Código y migraciones requieren autorización específica;
los guards tenant posteriores dependen de D3 y sus pruebas RLS. D2.1-A fue autorizado
posteriormente solo para entorno/herramientas; [estado operativo](../local-postgresql.md).
