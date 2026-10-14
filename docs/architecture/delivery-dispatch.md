# Repartidores y despacho — Fase 2, cobertura avanzada en Fase 4

Estado: **decisiones funcionales aprobadas, módulos planificados; no implementados**.
La gestión manual no requiere app Flutter, Firebase, WhatsApp Business API ni portal repartidor.
[Operaciones](restaurant-operations.md) define permisos candidatos y estado comercial;
[comandas](kitchen-commands.md) define preparación independiente.

## Registro aprobado: Configuración → Repartidores

| Dato inicial | Significado |
| --- | --- |
| Nombre | Contacto operativo |
| Teléfono WhatsApp con código de país | Canal para abrir conversación, no identidad autenticada |
| Sucursales asignadas | Pertenencia dentro de un tenant; no referencias cruzadas |
| Activo/inactivo | Habilitación del contacto |
| Disponibilidad operativa | Dato separado de activo/inactivo; valores exactos pendientes |
| Propio/externo | Tipo operativo, sin conceder permisos |
| Observaciones | Opcionales; evitar secretos y datos personales innecesarios |

Inicialmente el repartidor es un contacto sin cuenta. No crear Identity/Membership a partir
de su teléfono. Cuenta con identidad, audiencia/permisos limitados y aceptación/entrega
directa es evolución futura, con autenticación y contrato propios.

Proponer contacto exclusivo tenant y asociación compuesta tenant/branch para elegibilidad.
Una sucursal asignada no equivale a acceso al panel. Política de administración de contactos
compartidos, visibilidad de teléfono, unicidad/normalización y catálogo de disponibilidad
requieren aprobación. Cajera de S1 no puede editar datos/asignaciones de S2 por esa relación.

## Asignación y salida aprobadas

Desde Pedidos se selecciona/asigna repartidor elegible para la sucursal, con permisos
y alcance vigentes. Registrar repartidor asignado, usuario asignador, fecha/hora, historial
de reasignaciones y fecha/hora de salida a reparto. Asignar no cambia a En camino.
La cajera confirma salida; entrega inicial se confirma desde admin.

Recomendar verificar activo, pertenencia al tenant/sucursal y disponibilidad al confirmar
asignación, no solo al listar candidatos. Qué disponibilidad bloquea asignación, si se
permite retirar una asignación y reasignar tras salida, o cambiar sucursal con historial
activo son decisiones abiertas. No asumir «externo» como excepción a pertenencia/permisos.

Idempotencia por acción/ámbito/payload y versión del despacho recomendadas: doble clic o
reintento conserva una asignación y un hecho histórico; reasignación deliberada cambia
destino conservando actor/fechas/anterior/nuevo. Dos cajeras concurrentes no sobrescriben
silenciosamente. No borrar historia al desactivar al contacto; política ante salida ya
registrada y cambios posteriores pendiente. Confirmar salida es una acción independiente.

**Restricción pendiente:** impedir despacho si preparación no está Lista, permitiendo
excepción con permiso específico, motivo y auditoría. No está aprobada ni se impone como
invariante actual. Definir quién puede exceptuar, pedidos sin cocina y efecto de cambios
concurrentes antes de implementarla; ni asignación ni WhatsApp eluden ese futuro control.

## Acción aprobada «Enviar por WhatsApp»

Abrir conversación del repartidor seleccionado con mensaje prellenado. Incluir solamente
identificador del pedido, sucursal, dirección, referencia, enlace Google Maps si existen
coordenadas verificadas, monto pendiente cuando corresponda, medio de pago e instrucciones
logísticas relevantes. No incluir datos de tarjeta/cuenta, credenciales, historial del
cliente, documento de identidad o teléfono/nombre del cliente por defecto.

Abrir el enlace **no acredita envío, recepción, lectura, aceptación, salida ni entrega**.
No registrar «mensaje enviado» a partir de clic; si se audita, describir «acción de apertura
solicitada», sin guardar innecesariamente el mensaje completo. Sin integración Business API.

Propuesta de transporte: `https://wa.me/{numero_internacional_solo_digitos}?text={texto_codificado}`,
con validación de formato/número y codificación del texto, según
[WhatsApp Click to Chat](https://faq.whatsapp.com/5913398998672934). El texto queda editable
por el usuario y puede quedar expuesto en URLs/historial externos: recomendar vista previa
mínima antes de abrir la conversación. Política de retención/privacidad pendiente.

Google Maps: enlace de búsqueda propuesto
`https://www.google.com/maps/search/?api=1&query={latitud},{longitud}` con coordenadas
validadas y codificación de parámetros, conforme a [Maps URLs](https://developers.google.com/maps/documentation/urls/get-started).
No incorporar SDK, credenciales ni Google OAuth. Definir fuente, validación/rangos, orden
latitud/longitud y qué significa «verificadas» antes de generar el enlace. Coordenadas
ausentes/no verificadas: omitir enlace, conservar dirección/referencia; no inventar ubicación.
No interpretar que existir coordenadas demuestra cobertura por polígonos.

Ejemplo ilustrativo de mensaje, sin datos reales ni números de cliente/repartidor:

```text
Pedido PED-DEMO-104 — Sucursal Centro
Dirección: DIRECCIÓN_DEMO
Referencia: REFERENCIA_DEMO
Maps: ENLACE_VALIDADO (solo si corresponde)
Pendiente de cobro: MONTO_Y_MONEDA (solo si corresponde)
Medio de pago: MEDIO_DEMO
Instrucciones: INDICACIÓN_LOGÍSTICA_DEMO
```

No asumir que pendiente de cobro es igual al total del pedido ni que un importe cero
significa pago validado. Monto/medio deben provenir del estado autorizado del sistema;
reglas de cobro, conciliación o cambios después de abrir el mensaje siguen pendientes.

## Fases y criterios posteriores

Fase 2: contactos, asignación/reasignación y WhatsApp manual. Fase 3: preparación/cocina
integrada y sincronización. Fase 4: polígonos, cobertura, zonas y tarifas; no confundir
coordinación manual con un motor de cobertura implementado. Criterios futuros:

- Contacto/branch/pedido de otro tenant rechazados; cajera S1 no consulta ni despacha S2.
- Elegibilidad se revalida; disponibilidad/estado concurrentes se resuelven según política aprobada.
- Reintentos no duplican asignaciones y reasignaciones conservan historia.
- Asignar y abrir WhatsApp no producen salida; confirmación registra actor/fecha servidor.
- Mensaje no contiene campos fuera de la logística aprobada; sin coordenadas fiables no hay Maps.
- Importe procede de datos autorizados; teléfono y texto se validan/codifican sin insertar URLs arbitrarias.
- Control preparación Lista y excepciones solo se prueban después de aprobar su política.
- Fase 4 prueba bordes, orden de coordenadas, pertenencia de zonas y snapshots de tarifa.

Portal repartidor, confirmación directa de entrega, seguimiento y app de reparto quedan
para una fase posterior por definir. No se presuponen tracking en vivo, consentimientos,
precios de APIs, impresión automática ni una nueva licencia comercial aprobada.
