# ADR-002 — Gobierno de roles y propiedad

Estado: **cinco políticas aprobadas por el usuario; sin implementación**.
Complementa [ADR-001](ADR-001-hybrid-roles.md), sin sustituir roles híbridos, scopes,
catálogo backend, RLS, auditoría ni separación SaaS. No autoriza código o migraciones.

## Políticas aprobadas

| ID | Decisión | Garantía |
| --- | --- | --- |
| G1 | Propietario administra roles y autoriza administradores delegados | Backend exige autorización expresa de gestión y límites delegables de permisos/scopes; poseer un permiso no permite delegarlo |
| G2 | Transferencia solicitada por propietario autorizado, con invitación, aceptación explícita, verificación reforzada y auditoría | No concede propiedad por enviar invitación ni deja al tenant sin propietario activo |
| G3 | Propietario protegido | Editor no elimina permisos críticos; archivo/cambios no destruyen administración del tenant |
| G4 | Plantillas exclusivamente Tomopedidos; copias independientes | Modificar plantilla no modifica roles generados/duplicados existentes |
| G5 | No archivar rol con asignaciones activas | Revocar/reasignar primero; conservar relaciones e historial auditado |

Recuperación excepcional de propiedad: procedimiento separado y auditado, sin detalles
operativos aprobados. No crear bypass ni endpoint informal de recuperación.
Máximo de propietarios y demás reglas de gobierno siguen abiertos.

## Invariantes y recomendaciones técnicas

Reglas aprobadas se comprueban también al editar roles compartidos, para todos sus
empleados/sucursales afectados; no validar solo el scope de quien abre el editor.
Delegación expresa y permiso de uso son dimensiones independientes. No convertir una
copia personalizada o nombre “Propietario” en condición de Owner.
No usar branch_id nulo como comodín y no mezclar roles platform con restaurante.

Recomendaciones aún técnicas, no decisiones operativas aprobadas:
- Representar autorización de gestión y envelope delegable en registros tenant/branch
  separados de permisos operativos, con issuer propietario, estado y auditoría.
- Transferencia como workflow persistente, invitación de uso único y verificación
  reforzada comprobada por servidor. Revalidar propietario solicitante y destinatario
  al completar; efectos idempotentes/atómicos.
- Serializar cambios de propiedad/archivo/edición/grants y comprobar versiones.
  Archivo falla si aparece una asignación activa concurrente.
- Mantener role_permissions independientes de template_permissions; versionado de
  procedencia no es herencia viva. Upgrade de copia, si se habilita, es cambio explícito.
- En editor ordinario bloquear cambios estructurales del Owner; definir lista crítica
  backend antes de habilitar cualquier edición permitida.

## Contradicciones resueltas con el diseño anterior

| Texto anterior | Resolución |
| --- | --- |
| Quién administra roles y delegación todavía pendientes | G1 los aprueba; campos/acciones concretas y subdelegación siguen pendientes |
| Transferencia/aceptación/reautenticación totalmente pendientes | G2 aprueba el flujo y verificación reforzada; factor/UX/plazos y efecto sobre propietario anterior abiertos |
| Tratamiento protegido del Owner solo recomendado | G3 es obligatorio; nombres críticos, máximo y edición cosmética abiertos |
| Snapshot/independencia de plantilla solo recomendado | G4 aprueba independencia; formato de versiones/reconciliación todavía propuesto |
| Archivo con grants pendiente | G5 prohíbe archivo directo con asignaciones activas; revocar/reasignar primero |

Una regla previa decía que poseer P en S1 impide delegarlo en S2: debe leerse como
denegación **sin autorización expresa para S2**. El scope de uso no reemplaza ni crea el
scope de delegación. No añadir como requisito automático que todo permiso delegable
deba poder usarse por el administrador: ese comportamiento no fue aprobado.

## Detalles todavía pendientes

- Acciones exactas que puede gestionar cada delegado, límites de autorización,
  vencimiento, revocación y posibilidad de subdelegar (recomendar denegar por defecto).
- Permisos críticos Owner, edición cosmética y tratamiento de duplicación de su definición.
- Máximo de propietarios; si transferencia sustituye al solicitante o conserva copropiedad;
  conservación/revocación de delegaciones emitidas por propietario anterior.
- Factor y alcance de verificación reforzada, plazos/cancelación, prueba de destinatario,
  creación de Membership para invitado nuevo, y recuperación excepcional.
- Sesiones, onboarding, MFA y entorno PostgreSQL conforme al
  [inventario de pendientes](../architecture/phase1-design.md#12-decisiones-pendientes-para-autorizar-implementación).

Modelo, matriz y pruebas en [roles-permissions.md](../architecture/roles-permissions.md).
El siguiente incremento recomendado es cerrar el contrato de identidad/sesión y los
detalles críticos de gobierno mediante ADR y ejemplos, todavía sin código.
