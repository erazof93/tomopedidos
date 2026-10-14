# Comandas — diseño funcional de Fase 3

Estado: **funcionalidad planificada, no implementada**. Decisiones operativas aprobadas
en [operaciones](restaurant-operations.md). No existen rutas HTTP o UI de cocina vigentes.

## Alcance aprobado

Vista `/comandas` en la misma aplicación admin, adaptable a computadora, tablet y celular.
Estados iniciales de preparación: **En cola, Preparando, Lista**. La cajera acepta y envía
el pedido a cocina de forma controlada; pedido Pendiente no entra como comanda activa.
El estado de preparación no sustituye el estado comercial del pedido.

Cada comanda incluye identificador estable, pedido de origen, tenant/sucursal, productos,
cantidades, modificadores, observaciones e historial de estados. SSE sincroniza caja y
cocina. Impresión manual desde pedidos y cocina, independiente de crear/publicar comandas.
Preparación para estaciones de cocina e impresión automática, como evolución futura.

## Presentación propuesta

Computadora: columnas/listas por estado; tablet: controles táctiles y filtros accesibles;
celular: lista por estado con detalle y acciones legibles, sin depender de drag-and-drop.
Mostrar identificador, sucursal, antigüedad, ítems/cantidades/modificadores y observaciones;
no enviar dirección, teléfono, pagos u otros datos de cliente si cocina no los necesita.
Historial por permisos y sucursal; un selector visual no amplía autorización.

Recomendar acciones explícitas «Iniciar preparación» y «Marcar lista», feedback de conflictos
y estado de conexión SSE. Si hay pérdida de sincronización, advertir y reconciliar contra
API; comportamiento para mutaciones offline requiere aprobación. No confirmar cambios
solo con una animación optimista ni prometer orden temporal a partir del reloj del navegador.

## Ciclo y publicación propuestos

En cola → Preparando → Lista es el recorrido recomendado; transiciones exactas, regreso
a estados anteriores y saltos no están aprobados. No añadir estado Cancelada de preparación
sin revisión: cancelación comercial requiere definir retiro de cola, trabajo ya iniciado,
retención histórica y notificación a cocina. No eliminar historial como compensación.

Proponer inicialmente una comanda activa por pedido/sucursal, identidad estable y snapshot
de ítems al publicar. Cardinalidad, pedidos con agregados después de aceptación, lotes,
reenvíos y estaciones requieren aprobación; no crear una comanda nueva al reimprimir.
Aceptar/publicar idealmente en una misma transacción; si publicación es asíncrona, mantener
intención durable y estado «pendiente de publicación» explícito, sin declarar envío exitoso
antes de persistirlo. Elección entre ambas alternativas pendiente.

## Eventos y concurrencia: recomendación técnica

Operación autorizada + versión esperada + idempotencia; mismo reintento no crea otra
comanda ni otra transición. Bloqueo/versionado coordina aceptación simultánea, cambios
de preparación y cancelación. Historial y evento se persisten con el efecto confirmado.

Proponer eventos `kitchen.command_published`, `kitchen.preparation_changed` y evento
de invalidación por cancelación, cuyo nombre/payload dependerá de esa política. Envelope
recomendado: event_id, tenant_id, branch_id, command_id/order_id, aggregate_version,
occurred_at y tipo; enviar solo campos autorizados. Nombres/DTOs no son contratos vigentes.

SSE emite después del commit. Recomendar outbox transaccional cuando se requiera que un
crash entre commit y emisión no pierda notificaciones. Consumidores toleran duplicados,
usan ID/versión y hacen resync del estado autorizado. No prometer entrega exactamente una
vez ni usar SSE como fuente de verdad. Retención/replay, cursor opaco, gaps, orden entre
entidades y política de revalidación de permisos/sesión durante el stream quedan pendientes.
No mantener permisos retirados indefinidamente: definir cierre/revalidación acotada.

Cada suscripción SSE se autoriza por tenant/sucursal y audiencia admin; sin datos de otros
scopes en eventos, errores o historial. Reconexión vuelve a autorizar; heartbeat/polling
no renueva automáticamente sesiones. Misma política de auth de [ADR-003](../decisions/ADR-003-web-authentication-sessions.md).
Fundamento transversal en [eventos e integraciones](events-integrations.md).

## Impresión manual

Decisión aprobada: imprimir desde pedidos o cocina no crea, duplica ni vuelve a publicar
comandas; usar el identificador estable. Reimprimir deliberadamente puede producir otra
copia física y debe distinguirse de reintentar la misma solicitud lógica.
Si un pedido aún no tiene comanda, imprimir el documento del pedido no debe crear una
para poder imprimir; formato y contenido de ese documento siguen por definir.

Recomendar documento imprimible asociado a comanda/versión, permiso de impresión y
registro de intento/reimpresión sin datos innecesarios. Print job e idempotency key si hay
servidor de impresión futuro; no atribuir al diálogo del navegador garantía de impresión
física exactamente una vez. Abrir/cerrar diálogo no demuestra papel impreso. Tecnología,
formatos, impresoras, auditoría de impresión y selección de estaciones quedan por revisar.

## Criterios de aceptación futuros

- Pendiente nunca aparece activo; aceptación/publicación repetida conserva un solo efecto.
- Dos cocineros actualizan una versión: se resuelve conflicto sin doble historial ni salto.
- Preparación no cambia automáticamente pedido a En camino o Entregado.
- Impresión/reimpresión conserva identidad y cantidad de comandas, incluso tras reintento.
- SSE duplicado/desconectado/fuera de orden converge con resync, sin fugas entre sucursales.
- Revocación de permisos/sesión bloquea nuevas solicitudes y cumple política de stream definida.
- Uso por teclado/táctil y vista móvil validables; cocina recibe únicamente datos necesarios.
- Cancelación concurrente no produce comanda fantasma; resultado depende de política aprobada.

Estaciones, impresión automática y seguimiento desde portal repartidor son posteriores;
no condicionan comandas manuales iniciales. Ningún criterio fue ejecutado como prueba.
