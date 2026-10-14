# Suscripciones y pagos — propuesta pendiente de aprobación

## Ciclo de vida sugerido
Borrador/pendiente de pago → activa → por vencer → vencida/en gracia (si se aprueba) → suspendida/cancelada. Los estados exactos y transiciones deben aprobarse antes de implementar.

## Cobro inicial
Pagos manuales mediante Yape o transferencia bancaria. El operador revisa el comprobante y aprueba/rechaza; **subir comprobante no activa automáticamente** una licencia. Registrar referencia, monto, moneda, periodo, responsable, fecha y auditoría. Evitar duplicidad por reintentos y aprobaciones concurrentes.

## Entitlements
Catálogo de capacidades, cuotas y complementos configurables; evaluación en API con contexto tenant confiable. La suscripción no otorga privilegios de operador ni acceso a otros tenants.

## Reglas por definir
- Mes/trimestre/año, fecha de corte y zona horaria.
- Política de gracia, suspensión y reactivación.
- Efecto de suspensión sobre lectura, descarga de datos y operaciones activas.
- Upgrade/downgrade, prorrateo, reembolso, impuestos y comprobantes.
- Política de almacenamiento de comprobantes y datos financieros.

## Seguridad y pruebas futuras
Autorización operador, aislamiento tenant, transiciones inválidas, idempotencia, concurrencia, auditoría y rechazo de evidencias falsificadas. Sin pasarela automática aprobada por ahora.
