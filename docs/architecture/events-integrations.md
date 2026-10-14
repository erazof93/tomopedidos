# Eventos e integraciones — diseño propuesto

## SSE operacional
SSE para pedidos, comandas y estados entre caja, cocina y múltiples sesiones del admin. Autenticación y autorización por tenant/sucursal; reconexión y re-sincronización. No asumir que SSE garantiza entrega cuando el navegador está desconectado.

## Consistencia
Emitir eventos solo tras commit; estudiar outbox duradero, ids/event replay y resync antes de Fase 3. Revisar timeouts HTTP específicos para conexiones SSE. Evitar duplicar acciones ante reintentos.
Diseño operativo de publicación/preparación, concurrencia, impresión y eventos propuestos:
[comandas](kitchen-commands.md). Estado comercial y preparación son ciclos independientes;
[WhatsApp manual](delivery-dispatch.md) abre conversación, sin acreditar envío ni transición.

## Móvil opcional
Flutter por marca cuando se contrate. Backend FCM como adaptador opcional; aislar credenciales por tenant, permisos y consentimiento. No incorporar Firebase Web Messaging al panel base.

## Contratos
API Go será fuente de verdad para nuevos contratos; documentar esquemas, errores, idempotencia, paginación y versiones. Revisar NestJS Celtas y consumidores Flutter/React como referencia, sin copiar contratos automáticamente.
