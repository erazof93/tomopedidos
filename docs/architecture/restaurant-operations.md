# Operaciones del restaurante — fases 2, 3 y 4

Estado: **decisiones funcionales aprobadas, funcionalidades planificadas; no implementadas**.
Código vigente revisado: API solo GET /healthz; admin/platform son pantallas iniciales.
No existen pedidos, caja, repartidores, comandas ni rutas operativas implementadas.
Este registro no amplía D2.1-A ni autoriza implementación de fases posteriores.

## Panel único y navegación aprobada

`tomopedidos-admin` sirve a propietarios y empleados. Los siguientes son perfiles iniciales
de navegación; no checks de nombres de roles, roles inmutables ni autorizaciones hardcodeadas.
`tomopedidos-platform` conserva su frontera independiente para operar el SaaS.
Son menús objetivo: cada entrada se habilitará cuando exista su módulo y el actor tenga
permiso/capacidad aplicable, sin presentar funcionalidades planificadas como disponibles.

| Perfil inicial | Navegación prevista |
| --- | --- |
| Propietario | Dashboard general; Pedidos; Caja; Comandas; Productos; Reportes consolidados; Sucursales; Empleados y roles; Configuración |
| Cajera | Pedidos; Nuevo pedido; Caja; Comandas; Reportes de sucursal |
| Cocina | Comandas; Historial de preparación |

Visibilidad por permisos efectivos en el tenant/sucursal seleccionado; la API Go vuelve
a validar cada lectura/acción, incluidas llamadas directas y exportaciones. No inferir
alcance tenant de branch_id nulo ni de un nombre de perfil. Contexto explícito por solicitud,
sin cambiar una sucursal global mutable entre pestañas. RLS conserva aislamiento tenant;
Go valida alcance de sucursal. Suscripción/entitlements siguen separados de permisos.

Se mantienen [roles híbridos y delegación](roles-permissions.md),
[tenancy](tenancy.md) y ADR-001/002: personalizar una cajera no amplía sucursales ni cambia
automáticamente a todas las empleadas que comparten un rol. El menú no concede permiso.
Reportes consolidados requieren autorización tenant explícita; no unir sucursales ajenas.

## Pedido y preparación: decisiones aprobadas

Estados comerciales base: **Pendiente, Aceptado, En camino y Entregado**.
**Cancelado** es terminal controlado, con motivo y auditoría. Estado comercial distinto
del estado de preparación: En cola, Preparando y Lista pertenecen a la comanda.

La cajera acepta manualmente y envía el pedido a cocina. Un Pendiente no aparece como
comanda activa de preparación. Un Aceptado puede conservar una comanda Preparando.
Asignar/reasignar repartidor no cambia el estado comercial. La cajera confirma salida
a reparto; inicialmente el panel administrativo confirma entrega. Abrir WhatsApp no
confirma ninguna transición ni comunicación efectiva.

## Transiciones: propuesta a revisar antes de implementar

La política manual anterior está aprobada. Este grafo operativo, las precondiciones
exactas y los permisos de cada transición siguen **propuestos**, no son un contrato vigente.

| Transición candidata | Intención / límite pendiente |
| --- | --- |
| Pendiente → Aceptado | Acción manual aprobada; recomendar aceptación/publicación de comanda atómicas cuando exista cocina |
| Aceptado → En camino | Delivery: confirmación de salida por cajera aprobada; definir si repartidor asignado es obligatorio |
| En camino → Entregado | Confirmación inicial desde admin aprobada; definir evidencia, campos y responsables autorizados |
| Aceptado → Entregado | Propuesta para recoger, sin pasar artificialmente por En camino; aprobación pendiente |
| Estado permitido → Cancelado | Motivo y auditoría aprobados; estados de origen, permisos, compensaciones y efectos en cocina por aprobar |
| Entregado/Cancelado → otro estado | No habilitar en el diseño inicial; correcciones/reapertura requieren decisión explícita |

Recomendar no saltar Pendiente a despacho/entrega. No suponer autorización para cancelar
Entregado, devolución de dinero, cierre de caja o restauración de inventario. Caja aparece
en navegación, pero sus aperturas/cierres, cobros, conciliación y devoluciones no se aprueban aquí.
Pedido/comanda no deben avanzar mutuamente por coincidencia de nombres de estados.

## Permisos operativos candidatos

La mecánica híbrida está aprobada; estos identificadores son **propuestas de catálogo backend**,
no cadenas creadas por empleados ni permisos ya registrados. Scope Branch siempre incluye tenant.
El catálogo definitivo debe consolidarse con la matriz de Fase 1 antes de implementar.

| Acción | Código candidato / scope |
| --- | --- |
| Consultar/crear pedido manual | orders.read / orders.create_manual — Branch, existentes como propuestas en la matriz |
| Aceptar y enviar a cocina | orders.accept — Branch; definir si una acción conjunta requiere también permiso cocina |
| Cancelar / confirmar entrega | orders.cancel / orders.confirm_delivery — Branch, con estados/precondiciones por revisar |
| Leer/cambiar preparación/ver historial | kitchen.commands.read / kitchen.commands.update_state / kitchen.history.read — Branch |
| Impresión desde pedidos/cocina | orders.print / kitchen.commands.print — Branch |
| Administrar contactos repartidores | couriers.manage — Branch autorizado; política de edición de contacto compartido pendiente |
| Asignar/reasignar / confirmar salida | dispatch.assign / dispatch.reassign / dispatch.confirm_departure — Branch |
| Preparar enlace WhatsApp | dispatch.share_whatsapp — Branch, acceso a logística mínimo |
| Despachar con excepción de preparación | dispatch.override_preparation — Branch, solo si se aprueba la excepción |

Dashboard, productos, caja, empleados/roles y reportes conservan sus contratos futuros;
esta lista no define permisos wildcard ni acceso SaaS para el propietario. Compartir
un contacto entre sucursales no permite a una cajera editar asignaciones de otra sucursal.

## Concurrencia e integridad propuestas

Persistir tenant/branch en pedido, comanda y despacho, con referencias compuestas y
contexto confiable. Validar pertenencia, autorización vigente y versión esperada dentro
de una operación transaccional. Proponer claves de idempotencia por actor/ámbito/acción,
vinculadas al payload: mismo reintento devuelve el resultado anterior; misma clave con
otro payload se rechaza, sin sobrescribir historia. Reautorizar también los reintentos.

Registrar actor, fecha servidor UTC, entidad, ámbito, acción, estado anterior/nuevo y
motivo cuando corresponda. Definir retención, correcciones y formato monetario después;
no usar el monto de un mensaje WhatsApp como fuente contable. Eventos después del commit.
La estrategia detallada cocina/SSE está en [comandas](kitchen-commands.md); despacho y
datos compartidos en [delivery](delivery-dispatch.md).

## Dependencias y criterios futuros

Fase 2 introduce pedidos y despacho manual; Fase 3 habilita preparación real. Antes de
cocina operativa, no mostrar «enviado a cocina» sin una publicación real. Recomendar
liberación coordinada del flujo aceptación/publicación; no crear retroactivamente comandas
de todos los pedidos antiguos al habilitar Fase 3. Política para pedidos aceptados durante
la etapa intermedia pendiente de aprobación.

Criterios de aceptación posteriores, no pruebas ejecutadas:

- Una Identity con permisos en S1 no consulta ni muta S2 u otro tenant mediante URL/body.
- Navegación refleja permisos, pero llamadas directas sin permiso se rechazan en Go.
- Un permiso adicional conserva su scope; revocación se refleja en nuevas solicitudes.
- Pendiente no genera comanda activa; aceptación repetida no duplica publicaciones.
- Pedido Aceptado/comanda Preparando es combinación válida; assignment no implica salida.
- Cancelación tiene motivo/auditoría y jamás aplica compensaciones aún no aprobadas.
- Dos acciones concurrentes producen un estado/historial coherente, sin datos cruzados.

Pendientes: aprobar grafo y cancelación, recogida/entrega, permisos exactos, contratos HTTP,
acciones sobre contactos compartidos, idempotencia/versiones y detalle de caja. El plan
de implementación permanece en [ROADMAP](../../ROADMAP.md), sin autorizar trabajo funcional.

## Coherencia revisada

El roadmap anterior agrupaba delivery principalmente en Fase 4; se precisa despacho
manual en Fase 2 y cobertura avanzada en Fase 4, sin adelantar polígonos/tarifas.
No hay contradicción con roles híbridos: perfiles de menú son objetivos, no reglas por
nombre de rol. La dependencia aceptación/publicación entre fases 2 y 3 queda explícita,
con solución de liberación propuesta, no una política intermedia aprobada por omisión.
No se detectaron contratos operativos implementados que hubiera que cambiar. El alcance
y estado técnico de D2.1-A se conservan; solo se añade documentación funcional.
