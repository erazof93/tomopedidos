# ADR-001 — Roles híbridos por tenant y sucursal

Estado: **decisión funcional aprobada por el usuario; diseño no implementado**.
No autoriza código, migraciones ni inicio de Fase 1. Sustituye la propuesta anterior
de limitar el primer alcance a plantillas sin personalización.
Consolidación posterior: [ADR-002](ADR-002-role-governance-ownership.md) aprueba
administración delegada, transferencia, protección del Owner, copias independientes
y archivo sin asignaciones activas. Sus reglas prevalecen sobre propuestas anteriores.

## Decisión e invariantes aprobados

Tomopedidos controla plantillas globales predefinidas y el catálogo explícito de permisos.
Cada restaurante recibe roles propios creados desde esas plantillas, puede duplicar roles
y personalizar permisos dentro de la autoridad delegable del administrador.
Los grants son explícitos de tenant o branch. Los roles SaaS son completamente independientes.
Plantillas globales no editables por restaurantes; una copia nunca pertenece a dos tenants.
branch_id NULL no concede alcance global. Ownership conserva siempre un último propietario
activo. Cambios sensibles auditados; nuevas solicitudes reflejan revocaciones ya confirmadas.
Autorización Go y RLS tenant son complementarias; entitlements se validan por separado.

## Alternativas descartadas por esta decisión

| Alternativa | Motivo |
| --- | --- |
| Roles globales compartidos/editables por restaurantes | Riesgo de modificar permisos de otros tenants |
| Solo roles fijos sin personalización | No cubre diferencias de operación ni permisos adicionales de una cajera |
| Cada tenant inventa permisos/texto ejecutable | Impide contratos y validación backend confiables |
| Overrides individuales o ACL por recurso desde el inicio | Complejidad adicional; duplicación/grants por scope cubren el caso dado |

## Recomendaciones técnicas para implementar tras aprobación

- Copias independientes sin herencia viva: aprobado por ADR-002. Recomendar publicar
  versiones inmutables y guardar procedencia; formato de versionado todavía propuesto.
- Tablas separadas para grants tenant/branch; FKs compuestas con tenant_id.
- Permiso de uso distinto de capacidad de delegación. Validar scope y catálogo en crear,
  duplicar, editar y asignar; editar un rol requiere validar todos sus grants afectados.
- Owner protegido con tratamiento explícito, jamás deducido de nombre del rol.
- Roles/permissions/grants y evento de auditoría en la misma transacción.
  Nueva lectura de autorización desde BD; versionado para concurrencia, no claims obsoletos.

Detalles únicos de modelo, matriz, contratos propuestos y pruebas:
[roles-permissions.md](../architecture/roles-permissions.md).
Integración con sesión/RLS: [phase1-design.md](../architecture/phase1-design.md).

## Pendientes de aprobación

No siguen pendientes las cinco políticas de ADR-002. Sí sus detalles: envelope/acciones
delegables y subdelegación; catálogo crítico/edición cosmética/duplicación Owner; máximo
de propietarios y efecto sobre propietario anterior; factor/plazos de transferencia
y recuperación excepcional. Versionado/reconciliación de copias y política in-flight/SSE
siguen propuestos. La revocación para nuevas solicitudes continúa siendo obligatoria.
No asignar gestión de roles a cajeras por defecto ni por tener permisos operativos.

## Consecuencias y riesgos

Personalización sin cruzar tenants, con más validaciones de edición, delegación y concurrencia.
Un rol compartido dentro del tenant puede afectar varios empleados: revisar impacto completo
o duplicarlo para cambios puntuales. Contar permisos sin comprobar scope produce escalación.
No usar entitlements contratados para otorgar automáticamente permisos a empleados.

Principios de mínimo privilegio, denegación por defecto y comprobación por solicitud:
[OWASP Authorization](https://cheatsheetseries.owasp.org/cheatsheets/Authorization_Cheat_Sheet.html).
