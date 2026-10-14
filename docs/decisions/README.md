# Registro de decisiones — Tomopedidos

## Aprobadas como dirección arquitectónica
- SaaS independiente, brand-neutral; Celtas primer cliente futuro y repos de Celtas solo lectura.
- Go monolito modular + PostgreSQL; Chi, pgx, sqlc y migraciones SQL.
- Dos SPA React/Vite: admin de restaurantes y platform de operador.
- pnpm workspace únicamente para frontends; Go Modules para API.
- PostgreSQL compartido con aislamiento tenant; dedicada opcional futura.
- Identity global, sesiones opacas PostgreSQL y revocación server-side; Go como autoridad,
  CSRF/CORS restrictivo y fronteras restaurante/operador.
- PostgreSQL local Docker Compose, Goose/sqlc; credenciales migración/runtime separadas;
  sin migraciones al arrancar API ni SQL manual habitual en Supabase; grants pendientes.
- D2.1-A completada con evidencia usuario: PostgreSQL 18.6-bookworm, Goose v3.29.0
  y sqlc v1.31.1 mediante Docker. [Configuración y evidencia](../local-postgresql.md);
  no exige binarios Windows, grants efectivos pendientes de D2.1-B.
- [ADR-003: políticas web D1.1](ADR-003-web-authentication-sessions.md): correo/contraseña
  Argon2id configurable, cookies host-only/HttpOnly/Secure/Lax, API mismo origen por panel,
  admin 12 h/7 días y platform 15 min/8 h; CSRF prelogin/sesión, Origin estricto y actividad
  explícita. MFA operador obligatorio (WebAuthn objetivo/TOTP alternativa inicial), revocación
  global con autenticación reciente/MFA operador y audiencias/contexto separados. No implementado.
- Operación base sin Flutter/FCM; SSE para sincronización operativa.
- Operación futura aprobada: [admin único y pedidos](../architecture/restaurant-operations.md),
  [comandas](../architecture/kitchen-commands.md) y [despacho manual](../architecture/delivery-dispatch.md).
  Perfiles por permisos, aceptación manual, estados comercial/preparación separados,
  cancelación terminal con motivo/auditoría, SSE/impresión manual y repartidores/WhatsApp
  logístico; funcionalidades planificadas, sin ampliar D2.1-A.
- [ADR-001: roles híbridos](ADR-001-hybrid-roles.md): plantillas globales, copias tenant,
  duplicación/personalización, catálogo backend, scopes explícitos y roles SaaS separados;
  protección del último Owner, auditoría, revocación y entitlements independientes.
- [ADR-002: gobierno de roles y propiedad](ADR-002-role-governance-ownership.md):
  propietario y administradores autorizados, delegación expresa, transferencia con invitación/
  aceptación/verificación reforzada/auditoría, permisos críticos protegidos, copias
  independientes y archivo únicamente sin asignaciones activas.
- No deploy, producción, migración destructiva, secretos ni push sin autorización.

- [B2-D01: correo ASCII MVP](B2-decisions.md): aprobada como diseño; original/canónico,
  unicidad global y elegibilidad activa/verificada. No autoriza implementar B2.

- [B2-D02/D06](B2-decisions.md): estados/gramática/verificación y deshabilitación
  atómica; CSRF HMAC-SHA-256 vinculado a sesión. Aprobados como diseño, no implementados.

- [B2-D03–D05](B2-decisions.md): credenciales/UUID/revisión durable, formato Argon2id
  y tokens32/base64url/SHA-256 aprobados como diseño; costes definitivos no fijados.

- [B2-D07–D10](B2-decisions.md): epochs, protocolo transaccional, rol/pool auth y
  tiempo/expired_at aprobados como diseño; sin provisionar ni implementar.

## Propuestas NO aprobadas
- [Especificaciones B2](B2-decisions.md): DDL/grants/timeouts, CSRF binario/keyring,
  retención/cleanup (30 días propuesta no aprobada) y benchmark/límites Argon2id.
- [D2.1-B: esquema y RLS](../architecture/d2-1-b-schema-design.md), corte ampliado frente
  al plan anterior mínimo; roles DB, campos/constraints/helpers y pruebas por aprobar.
- [Contrato HTTP D1.1](../architecture/web-authentication.md#contratos-pendientes-de-revisión):
  rutas/DTOs/estados, nombres/persistencia cookies, TTL challenge/proof y custodia CSRF;
  implementación/enrolamiento/recuperación MFA, correo/onboarding y parámetros Argon2id.
- [Plan D2.1](../architecture/d2-1-persistence-plan.md): esquema, versiones/grants y pruebas
  locales propuestos; autorización de documentación no autoriza implementación.
- Precios, límites de planes, gracia, prorrateo, política de suspensión.
- Versiones/herramientas definitivas de migración y pruebas de integración SQL.
- Representación de dinero, redondeo y política geoespacial.
- Operaciones: transiciones exactas/recogida/cancelación, cambios de ítems publicados,
  catálogo de permisos, elegibilidad/reasignación, bloqueo de despacho antes de Lista y
  excepciones; retención/replay SSE, impresión y verificación de coordenadas.
- Inclusión de cupones/rewards en cada plan.
- Envelope/acciones de cada delegado, subdelegación, máximo de propietarios, catálogo
  crítico Owner, edición cosmética y duplicación de su definición.
- Factor/plazos/cancelación de transferencia, efecto en propietario anterior y sus
  delegaciones; procedimiento excepcional de recuperación.
- Formato de versiones y aplicación explícita a copias independientes, semántica
  in-flight/SSE y estrategia de caché sin permisos obsoletos.

## Regla
Antes de codificar una decisión abierta, documentar alternativas, riesgos, elección y evidencia. No transformar una propuesta en decisión aprobada por estar escrita aquí.
