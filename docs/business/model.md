# Modelo de negocio — propuesta pendiente de aprobación

Tomopedidos.pe ofrece software por suscripción a restaurantes. Un tenant representa un negocio; puede operar una o varias sucursales. La plataforma del operador es distinta del panel del restaurante. Celtas será el primer tenant tras migración controlada, no un componente codificado de forma especial.

## Oferta base
Catálogo, clientes, pedidos manuales (teléfono/WhatsApp), gestión de estados, comandas, caja operativa, delivery por polígonos, configuración del negocio y reportes básicos, según capacidades habilitadas. La operación base no requiere Flutter, Firebase ni app de cliente.

## Planes propuestos (sin precios aprobados)
- Emprendedor: orientado a una sucursal y operación inicial.
- Profesional: mayor capacidad operativa, usuarios y reportes.
- Empresarial: múltiples sucursales, permisos y consolidación.

**No se aprueban aquí** límites numéricos, precios, cuotas, reglas de prorrateo ni qué plan incluye cupones/rewards. Deben definirse como datos configurables y validarse en backend.

## Complementos opcionales
App Flutter de marca blanca por restaurante; FCM/marketing asociado a app y consentimiento; CRM Premium; sucursales adicionales; bases dedicadas empresariales (fase posterior). Los complementos no deben alterar el funcionamiento del núcleo.

## Principios comerciales
- Plan, vigencia, estado, límites y complementos se resuelven del lado del servidor.
- No confiar en ocultar botones para controlar acceso.
- Cambios de plan, suspensión y reactivación requieren auditoría.
- Los límites de sucursales, usuarios y funciones se parametrizan; no hardcodear el plan de Celtas.

## Pendiente de decisión
Tarifas PEN, impuestos/comprobantes, condiciones contractuales, prueba gratuita, gracia, renovaciones, prorrateo, retención de datos, SLA y soporte.
