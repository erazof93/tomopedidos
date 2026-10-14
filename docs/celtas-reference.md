# Celtas como referencia — solo lectura
Celtas permanece operativo e independiente. NestJS será referencia funcional para
reconstruir módulos en Go; React aportará componentes/patrones seleccionados.
Datos y cambio de API se migran posteriormente de forma controlada en Fase 10.

## Evidencia inspeccionada
AGENTS de backend/admin/app, package.json backend e inventario relevante de módulos/features.
Revisión inicial admin: dependencias/Vite, QueryClient, utils, Button, errores y transporte SSE.
Actual: money.util.ts (centavos, límites/redondeo/descuentos), create-delivery-zone.dto.ts
(Polygon GeoJSON/validación) y extracto Flutter order_repository.dart (snapshots/tri-state).
Inventario de orders/events, reports, coupons, rewards, users, delivery y notifications.
No son auditorías funcionales completas. Sin comandos, escrituras, .env, credenciales,
Firebase options ni material de firma en Celtas.

## Matriz de reutilización futura
| Área | Referencia principal | Revisión antes del traslado |
| --- | --- | --- |
| Contratos API | Controllers/DTOs NestJS y consumidores | Métodos, errores y autorización; generar contratos nuevos |
| Pedidos | orders service/DTOs/tests | Estados, snapshots, atomicidad/idempotencia y tenant |
| Dinero | common/utils/money/tests | Representación exacta, rango/redondeo; autoridad del servidor |
| Delivery/polígonos | delivery y orders | Tarifas, coordenadas, límites geométricos y bordes |
| Cupones/rewards | coupons/rewards | Elegibilidad, acumulación, concurrencia e historial |
| Clientes | users/addresses | Separar cliente comercial de Identity; privacidad/ownership |
| Reportes | reports | Fechas, permisos, consolidación y reconciliación |
| SSE | orders/events y lib/sse-* admin | Auth/replay/reconexión/cancelación y tenant/branch |
| Flutter | Repositorios/modelos/features | Contratos/sesión sin condicionar núcleo web |
| Marketing/Firebase | notifications/adaptadores/app | Licencias, consentimiento y credenciales por cliente; sin push web |
| UI React | components/ui, features, hooks/tests | Dependencias, accesibilidad y contratos; selección concreta |

Filas = candidatos, no funcionalidades Tomopedidos. No trasladar Zustand/mapas/gráficos/
drag-and-drop/axios/Firebase sin necesidad. Conservar patrones RHF/Zod/Query y clsx/tailwind-merge.
La sesión/refresh y producción Celtas no se heredan.
Método: inventariar → acordar reglas SaaS → revisar dependencias/contratos → adaptar partes
seleccionadas → probar regresión/aislamiento → documentar diferencias.
Dry-run, reconciliación, backup, rollback y cutover requieren autorización posterior.
