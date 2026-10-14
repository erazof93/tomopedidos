# Contexto permanente
Tomopedidos.pe es un SaaS independiente para restaurantes. Celtas Fast Food será el primer
cliente mediante migración posterior; permanece operativo e independiente.

Estado real: API Go con configuración validada y /healthz; admin y platform son pantallas
iniciales React. No hay PostgreSQL conectado, auth, tenants, permisos ni módulos de negocio.
Fase 0 y D2.1-A completadas. Compose usa .env raíz; PostgreSQL/SELECT 1 y Goose/sqlc
Docker verificados por usuario, evidencia en docs/verification.md. Fase 1 sigue en curso;
B1 completada: 001/002 aplicados; 020, lecturas posteriores y 010 final aprobados por
Codex el 2026-10-14; 14 negativos de privilegios y limpieza tras rollback confirmados.
Arranque del contenedor existente y preflight SCRAM verificados por Codex.
Credenciales independientes, TCP interno y Windows de ambos roles y cuatro negativos
de contraseña aprobados por evidencia manual del usuario; ver docs/verification.md.
SET LOCAL ROLE tp_owner e identidad/search_path en sesión TCP Windows migrator
confirmados manualmente, con ROLLBACK y exit 0. API aún no conecta PostgreSQL.
B2-D01–D10 y diseño técnico final B2-A aprobados, incluida retención30d.
Plan A–F en docs/architecture/b2-a-specification.md; artefactos no escritos ni
autorizados. Argon2id definitivo/mediciones y CSRF binario/keyring pendientes.
B2-A/B2-B no autorizados para implementación. Nueva ejecución SQL y B2–B5
requieren autorización; ver docs/development-b1.md.

Admin será el panel de tenant/sucursal; platform, el panel privado del operador SaaS.
El núcleo funciona sin app móvil; Flutter, FCM/Marketing y CRM son capacidades opcionales.

Bajo demanda: [arquitectura](ARCHITECTURE.md), [modelo comercial](docs/business/model.md),
[decisiones](docs/decisions/README.md), [roadmap](ROADMAP.md),
[desarrollo](docs/development.md), [auditoría](docs/audit.md) y [verificación](docs/verification.md).
