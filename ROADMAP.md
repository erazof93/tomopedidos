# Roadmap propuesto
Fase 0 completada por confirmación del usuario; D2.1-A completada con flujo Docker.
Fase 1 sigue en curso; D2.1-B1 completada para PostgreSQL local.
B2–B5 pendientes de implementación; B2-D01–D10 aprobadas como diseño.
Diseño técnico final B2-A aprobado; siguiente bloque: autorizar por separado
[escritura de entrega A del plan A–F](docs/architecture/b2-a-specification.md);
B2-A/B2-B no autorizados para implementación.
Otros incrementos están pendientes y requieren aprobación.
Diseño documentado no equivale a implementación.
[Modelo comercial](docs/business/model.md). [Arquitectura](ARCHITECTURE.md).

| Fase / estado | Objetivo | Entregables | Criterios de aceptación |
| --- | --- | --- | --- |
| 0. Inicialización y herramientas — Completada según confirmación del usuario | Base verificable/reproducible | Tres proyectos, workspace pnpm, documentación y checks | Instalación estándar/lock congelado; go.sum, build/test/vet Go y checks frontend aprobados manualmente |
| 1. Identidad, tenants, sucursales y autorización — En curso: D2.1-A y D2.1-B1 completadas; B2–B5 pendientes | Aislamiento antes de datos | Contratos/sesiones, Tenant/Branch/Identity/Membership, PostgreSQL local, SQL/sqlc/RLS y catálogo central compartido | ADR auth; contexto confiable; pruebas negativas tenant/sucursal/pool/revocación; migraciones locales reversibles |
| 2. Catálogo, clientes y pedidos manuales — Planificada, no implementada | Operación principal y despacho manual | Catálogo/clientes/pedidos; repartidores en Configuración, asignación/reasignación y WhatsApp manual | Dinero/estados por aprobar; alcance tenant/branch e idempotencia; asignar/WhatsApp no confirman salida |
| 3. Comandas, estados y SSE — Planificada, no implementada | Sincronizar caja/cocina | /comandas adaptable; aceptación/publicación controlada; preparación separada, historial, SSE e impresión manual | Pendiente no activa cocina; publicación sin duplicados; imprimir no crea comanda; reconexión/resync y aislamiento probados |
| 4. Delivery, polígonos y reglas operativas — Planificada, no implementada | Cobertura avanzada | Polígonos, cobertura, zonas/tarifas y validación geométrica | Bordes/coordenadas/snapshots revisados; cálculo, pertenencia y cobertura probados; despacho anticipado/excepciones solo tras aprobación |
| 5. Plataforma, planes y suscripciones — Pendiente | Operar licencias SaaS | Panel operador, catálogo/entitlements configurables, periodicidades y pagos manuales | Reglas comerciales aprobadas; límites servidor; gracia/suspensión/reactivación; aprobación concurrente/idempotente/auditada |
| 6. Branding y personalización — Pendiente | Identidad del restaurante | Tema/branding/configuración por tenant | Assets/config aislados; accesibilidad/sanitización; sin secretos en UI |
| 7. Reportes, cupones y rewards — Pendiente | Análisis y fidelización | Reportes básicos/ampliados/consolidados, cupones/rewards | Fechas/montos reconciliados; permisos; consumo concurrente e historial |
| 8. Flutter, Firebase y Marketing opcional — Pendiente | Canal móvil contratado | App marca blanca, FCM backend, campañas/consentimientos | Núcleo sin app; sin Firebase en panel base; capacidades/canal/consentimiento; dispositivos/credenciales aislados |
| 9. CRM Premium y bases dedicadas — Pendiente | Capacidades avanzadas/enterprise | CRM/segmentación, provisión/traslado dedicado | Entitlements; límites pools; schema uniforme, reconciliación y rollback probados |
| 10. Migración Celtas y lanzamiento — Pendiente | Primer cliente controlado | Mapeos/dry-run/reconciliación/backups/cutover/rollback | Paridad/datos/contratos aprobados; autorización específica para migración/deploy; Celtas operativo hasta corte |

## Dependencias y orden
Persistencia/aislamiento antes separados se integran en Fase 1; verificar RLS antes de pedidos.
Infraestructura de entitlements se diseña en Fase 1; catálogo/flujos comerciales en Fase 5.
Fase 2 permite planificar pedidos y coordinación manual de delivery; polígonos/cobertura/
zonas/tarifas pertenecen a Fase 4. No declarar motor de delivery completo en Fase 2.
Aceptación/envío real a cocina depende de Fase 3: acordar salida coordinada o política
intermedia explícita, sin simular publicación ni generar comandas antiguas automáticamente.
Reportes consolidados dependen de permisos/sucursales. Reportes básicos podrán adelantarse
si el piloto lo necesita, sin duplicar lógica ni omitir aislamiento.
Asignación central compartida desde Fase 1; dedicadas en Fase 9.
Marketing/CRM dependen de Fase 5; móvil no condiciona Fases 1–7.
Inclusión de cupones/rewards por plan pendiente de decisión.

## Operación futura: documentación funcional aprobada

[Operaciones y navegación por permisos](docs/architecture/restaurant-operations.md),
[comandas](docs/architecture/kitchen-commands.md) y
[repartidores/despacho](docs/architecture/delivery-dispatch.md) separan decisiones,
propuestas y criterios futuros. Documentar estos módulos no autoriza implementarlos.
Portal repartidor, confirmación directa de entrega, seguimiento e impresión automática:
fase posterior por definir, sin ampliar automáticamente Fase 8 ni hacer móvil obligatorio.
El estado y alcance de D2.1-A permanecen intactos.

Cada módulo sigue la [matriz Celtas](docs/celtas-reference.md).
[D2.1-A](docs/local-postgresql.md) completada: PostgreSQL healthy/SELECT 1 y Goose
v3.29.0/sqlc v1.31.1 en Docker confirmados por usuario; Compose validado también por Codex.
No se requiere instalación Windows; no hay generación/migraciones funcionales probadas.
Siguiente hito: revisar [diseño D2.1-B](docs/architecture/d2-1-b-schema-design.md) y aprobar
alcance/esquema antes de implementar. Propone B1 rutas/roles, B2 identidad/sesiones,
B3 tenants/sucursales/membresías, B4 catálogo/grants/auditoría y B5 RLS/pruebas; alternativa
conservar B3–B5 en D3. B1 tiene aplicación/verificación local autorizada y documentada;
[cierre B1](docs/development-b1.md). Revisar decisiones de B2 (identidad/credenciales/sesiones)
antes de autorizar su implementación. B2–B5 no autorizados; sin tablas funcionales.
El roadmap no autoriza migraciones externas ni publicación.
