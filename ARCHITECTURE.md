# Arquitectura
## Base aprobada
Go, monolito modular, Chi HTTP, pgx/v5 PostgreSQL, sqlc y migraciones SQL versionadas.
cmd/api compone configuración/HTTP; internal contiene infraestructura. Futuros módulos
tendrán límites de dominio/aplicación/repositorios según su necesidad. Sin microservicios
prematuros. Go por sí solo no garantiza mayor rendimiento: importan SQL, índices,
transacciones, conexiones, concurrencia y arquitectura; medir antes de optimizar.

Admin y platform: React + TypeScript + Vite, Tailwind 4, UI local con patrones shadcn,
TanStack Query y formularios RHF/Zod. Pruebas Vitest/Testing Library.
Workspace pnpm mínimo: dos aplicaciones, resolución compartida y scripts coordinados;
sin paquetes UI/contratos comunes hasta comprobar su necesidad. Sin Next.js.

## Implementado frente a preparado
Implementado: configuración validada, health HTTP, shutdown y pantallas iniciales.
Preparado: dependencias/config pgx/sqlc y carpetas SQL vacías. Sin pools, schema, RLS,
auth, tenants, roles, suscripciones, pagos, SSE ni FCM.
Entorno D2.1-A completado según evidencia usuario PostgreSQL/Goose/sqlc en Docker.
[Operación y límites](docs/local-postgresql.md); API aún sin conexión SQL ni auth.
components.json y Button son una base local, no una biblioteca shadcn completa ni tema final.

## Diseño bajo demanda — pendiente de implementación
- [Tenancy, identidad y almacenamiento](docs/architecture/tenancy.md).
- [D2.1-B: propuesta de esquema y RLS](docs/architecture/d2-1-b-schema-design.md), pendiente de aprobación.
- [Eventos, contratos e integración móvil](docs/architecture/events-integrations.md).
- [Operaciones y navegación](docs/architecture/restaurant-operations.md),
  [comandas](docs/architecture/kitchen-commands.md) y [despacho](docs/architecture/delivery-dispatch.md):
  decisiones funcionales futuras; no módulos implementados.
- [Modelo comercial](docs/business/model.md) y [suscripciones/pagos](docs/business/subscriptions-payments.md).
- [Decisiones](docs/decisions/README.md) y [reutilización Celtas](docs/celtas-reference.md).

Base compartida estándar; asignación central para dedicadas opcionales.
Operador SaaS y restaurante tienen permisos separados. Capacidades comerciales en servidor.
SSE cubre eventos operativos; FCM será adaptador opcional backend para apps contratadas.
