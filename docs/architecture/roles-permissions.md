# Roles híbridos — modelo, matriz y criterios de Fase 1

Dirección aprobada: [ADR-001](../decisions/ADR-001-hybrid-roles.md).
Gobierno consolidado aprobado: [ADR-002](../decisions/ADR-002-role-governance-ownership.md).
Modelo/contratos técnicos siguientes son recomendaciones, aún sin implementación.
Caso Celtas aportado por el usuario, sin inspeccionar sus repositorios ni importar datos.

## Modelo relacional recomendado

Identity/Tenant/Branch/Membership permanecen como en el diseño general. Agregar:

| Tabla | Claves y campos propuestos | Frontera |
| --- | --- | --- |
| permissions | code PK, action_scope tenant/branch, status, delegation_policy | Catálogo global backend para restaurantes; no expresiones de usuario |
| role_templates | id PK, code UNIQUE, name, status | Global, solo Tomopedidos publica |
| role_template_versions | template_id + version PK, scope_kind, published_at, status | Versiones publicadas inmutables |
| role_template_permissions | template_id + version + permission_code PK; FK versión y permission | Composición global explícita |
| roles | id, tenant_id, code, name, scope_kind, protection_kind, status, version; UNIQUE(tenant_id,id), UNIQUE(tenant_id,code) | Copia/custom exclusiva del restaurante |
| roles (procedencia) | source_template_id/version opcionales; source_role_id opcional | Auditoría de origen; sin herencia viva |
| role_permissions | tenant_id + role_id + permission_code PK; FK compuesta Role + FK Permission | Permisos explícitos de la copia |
| tenant_role_grants | tenant_id + membership_id + role_id UNIQUE; status, version, revoked_at | Scope tenant, explícito; conservar revocaciones |
| branch_role_grants | tenant_id + branch_id + membership_id + role_id UNIQUE; status, version, revoked_at | Scope de esa branch; branch_id NOT NULL |
| platform_roles / platform_permissions / platform_grants | Catálogo y claves independientes | Ninguna FK desde roles tenant a permisos SaaS |

Representación adicional recomendada, no schema aprobado:
- role_administration_authorizations: tenant, Membership del delegado, propietario que
  autoriza, acciones de gestión permitidas, estado/version y fechas; FKs tenant compuestas.
- tenant_delegation_grants y branch_delegation_grants: autorización anterior, permission_code
  del catálogo y scope explícito; branch_id obligatorio en la segunda. El actor puede
  delegar solo en ese envelope, no por tener el permiso operativo.
- ownership_transfer_requests: tenant, propietario solicitante, destinatario vinculado,
  estado/version, aceptación/verificación y resultado. Invitación ligada a esa solicitud
  con token hash/expiración/consumo único; no password ni token bruto en auditoría.
Campos/plazos y estados concretos se cierran con contratos antes de implementar.

Roles mantienen su scope al duplicarse. No cambiar branch a tenant mediante PATCH.
Cambiar alcance requiere crear otro rol y verificar delegación/grants de ese nuevo alcance.
Roles tenant pueden incluir acciones branch con alcance explícito a sus sucursales;
roles branch no incluyen acciones tenant. Nunca confundir acción con ámbito de asignación.

source_template_id/version se guardan ambos o ninguno; FK a versión publicada.
source_role_id, si existe, usa FK(tenant_id,source_role_id) al mismo tenant.
Metadatos de origen/scope/protección solo los establece backend; no se aceptan de un body.
No usar is_system para confundir “proviene de plantilla” con “es Owner protegido”.
Plantilla inicial ordinary puede crear copia editable; Owner requiere flujo protegido separado.

FK de grants a Membership/Role/Branch incluyen tenant_id; la existencia aislada de UUID
no acredita pertenencia. Validar además scope_kind con constraints y claves auxiliares.
Roles/grants inactivos no otorgan permisos. Publicación/retirada de códigos depende del backend.
Un permiso nuevo no entra automáticamente en roles antiguos. Denegar códigos desconocidos,
retirados, wildcard o del catálogo platform. Catálogo/plantillas globales sin DML tenant.
Recomendar que retirar una plantilla impida nuevas copias, sin archivar roles existentes;
retirar un permiso del catálogo sí deniega esa acción aunque una copia aún lo referencie.
Si el código retirado es crítico del Owner, su evolución necesita una validación explícita
de las garantías de administración; no usar un cambio global para eludir la protección.

No borrar historia de roles/membresías: archivo y auditoría. Está aprobado rechazar archivo
con asignaciones activas: primero revocarlas o reasignarlas, preservando FKs e historial.
Para el guard de archivo, contar todo grant con estado activo incluso si su Membership
está suspendida; suspensión no es revocación. Impedir grants nuevos a roles archivados.
protection_kind=owner no es configurable desde edición/duplicación genérica.
Permisos críticos del Owner no se eliminan desde editor ni por cambios que destruyan las
garantías de administración. Catálogo crítico y edición cosmética aún por definir.

## Ciclo de vida y efecto de los cambios

1. Aprovisionamiento copia una versión explícita de plantillas y permisos conocidos a roles
   del tenant; operación atómica/idempotente. No crea grants amplios por defecto a empleados.
2. Duplicar genera id/code nuevos dentro del mismo tenant y copia permisos autorizados.
   No copia grants, memberships, protección Owner ni privilegios platform.
3. Personalizar valida catálogo, tipo de acción/scope y envelope de delegación vigente.
   Si la copia íntegra excede ese envelope, rechazar; no recortar silenciosamente permisos.
4. Asignar usa grant tenant o branch explícito y verifica pertenencia/autoridad sobre destino.
5. Editar un rol compartido calcula todos sus grants y recipients afectados. Si alguno
   queda fuera del alcance administrable/delegable, rechazar la edición; proponer duplicación.
6. Toda mutación sensible confirma role.version/authorization_version, audita before/after,
   motivo/actor/ámbito/request_id; nuevas solicitudes pierden los permisos retirados.
7. Archivo solo sin asignaciones activas. Reasignación a otro rol requiere validación
   completa de destino/delegación; no sustituirlo por un rol más potente automáticamente.
   Serializar el guard con nuevas asignaciones para que no quede un rol archivado activo.

Una publicación de plantilla futura no cambia copias ya existentes. Proponer reconciliación
explícita, preview del diff y validación completa antes de aplicar una versión a una copia.
Incluso una mejora de plantilla debe pasar las reglas de delegación/Owner/auditoría.
Los grants de un rol editado reciben el cambio tras commit: no es una preferencia personal.

## Delegación y prevención de escalación

Está aprobado que el propietario administre roles y autorice administradores delegados.
Puede usar un permiso y puede delegarlo son decisiones distintas. La política exige:
- Autorización de administración expresa otorgada por propietario autorizado.
- Backend verifica acciones y envelope vigente en cada alta/edición/asignación, incluidos
  todos los empleados/sucursales afectados por un rol compartido.
- No inferir delegación de un nombre de rol, permiso de uso ni pertenencia de administrador.
Recomendaciones de representación y enforcement:
- Catálogo backend clasifica códigos como delegables/protegidos/no delegables.
- Administrador necesita permiso de gestión de roles más autoridad sobre scopes de destino.
- Para cada scope afectado, permisos efectivos resultantes de cada grant deben estar dentro
  de lo que el actor puede delegar allí; no unir capacidades de tenants o sucursales distintas.
- Administrador con permiso P de uso en branch A, sin autorización expresa para delegar
  en B/tenant, no puede hacerlo. Si el propietario autoriza esa delegación explícitamente,
  comprobar ese registro; ello no concede al administrador uso operativo en B.
- El tenant que contrató una capacidad no otorga por eso autoridad de delegación al empleado.
- Self-edit/self-grant no evade controles. Leer autoridad del actor desde estado previo,
  jamás desde el rol resultante. Si editar su único rol administrativo lo reduce, futuras
  solicitudes pierden esa autoridad; evitar que un cambio la amplíe a partir de sí mismo.
- Si editar/archivar/asignar roles ocurre concurrentemente, verificar el conjunto de grants
  bajo bloqueo/versionado coherente. No validar impacto y permitir un grant nuevo ajeno
  antes del commit. Definir orden de locks; rechazar versiones obsoletas.

Un rol aún sin grants no otorga derechos. Recomendar que su creación se limite a permisos
delegables del actor en scopes administrables; toda asignación posterior vuelve a validar.
Si el actor no puede conocer el impacto completo, backend no filtra un preview parcial
para permitir la edición: rechaza y permite crear una copia bajo sus límites.

## Matriz de permisos y caso Celtas

Los códigos siguientes son **propuesta de contrato**, no catálogo implementado.
Pedidos/caja/reportes son módulos futuros; registrar/habilitar sus códigos y plantillas
cuando se aprueben esos contratos. Fase 1 valida mecánica de autorización, no implementa negocio.
Scope siempre incluye Tenant; “propia” significa la branch del grant, no el puesto o nombre.
Los perfiles de navegación aprobados y códigos candidatos de pedidos/cocina/despacho
están en [operaciones](restaurant-operations.md). Son extensiones propuestas de catálogo,
no permisos implementados ni roles hardcodeados; conservar las reglas de delegación.

| Código propuesto | Acción/scope | Brayan Owner tenant | Cajera S1 base | Cajera S1 personalizada | Cajeras S2/S3 |
| --- | --- | --- | --- | --- | --- |
| orders.read / orders.create_manual / orders.update | Branch | S1, S2 y S3 | Solo S1 | Solo S1 | Solo su branch |
| cash.read / cash.open / cash.close | Branch | S1, S2 y S3 | Solo S1 | Solo S1 | Solo su branch |
| reports.branch.read | Branch | S1, S2 y S3 | Solo S1 | Solo S1 | Solo su branch |
| reports.branch.export | Branch, extra ilustrativo | S1, S2 y S3 | No | Solo S1 si autorizado | No |
| reports.tenant.read | Tenant, consolidado | Sí en Celtas | No | No | No |
| roles.read / roles.create / roles.duplicate / roles.update / roles.archive | Tenant, gestión con controles de impacto/Owner | Sí, sujeto a invariantes aprobados | No por defecto | No por defecto | No por defecto |
| role_grants.tenant.assign / role_grants.tenant.revoke | Tenant explícito | Sí, sin vulnerar último Owner | No | No | No |
| role_grants.branch.assign / role_grants.branch.revoke | Branch | Sí, con validación de pertenencia/delegación | No por defecto | No por defecto | No por defecto |
| ownership.transfer | Tenant protegido | Solicita; aceptación/verificación obligatorias | No | No | No |
| marketing.campaigns.send / crm.contacts.read | Branch, ejemplo futuro | Exige permiso + entitlement | Sin concesión implícita | Sin concesión implícita | Sin concesión implícita |
| platform.* | Solo catálogo operador separado | No por ser Owner | No | No | No |

La fila platform.* describe una familia del catálogo SaaS, **no un permiso wildcard** ni
un identificador aceptable en un rol. Otros renglones agrupan códigos separados por legibilidad;
cada código tendrá definición única en backend.
Scope real de Marketing/CRM es pendiente de sus contratos de módulo; aquí no se aprueba
el alcance definitivo. Catalogarlos no implementa módulos ni planes.

| Operación de gobierno | Propietario autorizado | Administrador delegado | Empleado sin autorización |
| --- | --- | --- | --- |
| Autorizar administrador de roles | Sí, límites explícitos | No por defecto; subdelegación pendiente | No |
| Crear/duplicar/asignar rol ordinario | Sí, respetando catálogo/scopes/invariantes | Solo acciones y envelope expresamente autorizados | No |
| Editar rol con grants S1/S2/S3 | Validar todo el impacto | Solo si autoridad cubre TODOS los scopes/recipients afectados | No |
| Quitar permiso crítico Owner | No desde editor | No | No |
| Archivar rol con asignaciones activas | No; revocar/reasignar primero | No; revocar/reasignar dentro de sus límites | No |
| Solicitar transferencia | Sí, flujo reforzado | No por delegación de roles | No |
| Aceptar invitación de propiedad | Solo destinatario verificado | Solo si es destinatario, sin convertirse en propietario antes del flujo | Solo si es destinatario, sin grants anticipados |

Los nombres/códigos exactos siguen siendo contratos propuestos; el comportamiento de
gobierno anterior está aprobado. No se concede subdelegación implícita a administradores.

Asignaciones del caso:
- Brayan tiene Membership en Celtas y tenant_role_grant del Owner protegido: supervisa
  todas las sucursales de Celtas, no otro restaurante ni plataforma.
- Cada cajera tiene Membership en Celtas y branch_role_grant de Cajera para su sucursal.
  Compartir la definición Cajera no comparte sus scopes.
- Para una cajera de S1: duplicar Cajera en Celtas a Cajera con exportación, añadir permiso
  autorizado y sustituir su grant solo en S1. La copia no lleva asignaciones previas.
  Si conserva el rol base y recibe otro adicional, la unión también se limita a S1.
- No editar la definición compartida Cajera para ampliar solo a esa persona: cambiaría
  todos sus grants. El caso debe demostrar explícitamente que S2/S3 no adquieren el extra.

## Go, RLS, revocación, suscripciones y Owner

Go valida acción, catálogo, Membership, alcance y delegación en cada request.
RLS exige tenant/actor confiables y barrera tenant también en roles, role_permissions,
grants y procedencia de copias. Usar transacción pgx única y contexto local como en
[diseño general](phase1-design.md). Funciones/lecturas RLS no deben recursar sobre sí mismas.
Scopes branch y permisos finos se validan explícitamente; no considerar que RLS tenant
por sí sola demuestra aislamiento de sucursales o delegación correcta.
RLS no reemplaza privilegios DB: retirar DML a consumidores tenant sobre tablas globales.
[PostgreSQL RLS](https://www.postgresql.org/docs/current/ddl-rowsecurity.html).

Obligatorio: solicitudes nuevas después del commit de un cambio leen roles/grants/
membresías activos y pierden permisos retirados. No mantener permisos en sesión/JWT como
fuente autoritativa ni usar cachés antiguas como fallback. authorization_version aumenta
con permisos, grants, estados, membresías y autorizaciones de administración/delegación;
dato para concurrencia/invalidation, no sustituto
de consultar estado. Si BD falla, denegar; no reutilizar permisos viejos.
Recomendar iniciar sin caché de autorización. Caché futura requiere consistencia que mantenga
esta garantía, no simplemente un TTL. In-flight/SSE tienen política pendiente adicional.

Un empleado necesita permiso efectivo **y**, si aplica, capacidad contratada vigente.
No limpiar el rol al vencer la suscripción ni concederlo al renovar automáticamente:
la capacidad y el permiso se conservan como dimensiones independientes.

Último Owner activo es una invariancia aprobada. Conteo usa rol Owner protegido, grant
tenant, Membership/Identity activas y relaciones correctas; no nombre del rol ni permiso
ownership.transfer en un custom. No recrear Owner mediante copia/body/protection_kind falso.
Todo camino que lo elimine (revocar grant, desactivar Membership/Identity/Role) debe guardarlo.
Mutaciones owner se serializan por tenant con auditoría transaccional; desactivar Identity
debe revisar todos sus tenants afectados. No aprobar excepciones de recuperación implícitas.

Transferencia aprobada: propietario autorizado solicita, se invita al destinatario,
este acepta explícitamente, se comprueba identidad de forma reforzada y se audita.
Enviar/abrir invitación no concede propiedad. Recomendar reforzar identidad del solicitante
y destinatario; mecanismo/factores/antigüedad de verificación siguen pendientes.
Revalidar autoridad actual al completar: solicitud antigua no conserva poderes revocados.

Recomendar workflow solicitado/invitado/aceptado/verificado/completado, con cancelado/expirado,
sin afirmar que esos estados sean definitivos. Completar una sola vez; owner grant y
eventual retiro del anterior se confirman atómicamente. Nunca retirar al último Owner
antes de otorgar al nuevo. Al commit, destinatario debe tener Identity/Membership activas
en ese tenant; si llega como invitado nuevo, definir cómo activarlas dentro del flujo.
Verificar destinatario, tenant, token, expiración, aceptación y nivel reforzado en servidor.

Owner: está aprobado que no se eliminen permisos críticos desde editor ni se archive/modifique
el rol destruyendo garantías de administración. Recomendar bloquear edición estructural/
archivo del Owner desde editor ordinario; edición cosmética/duplicación de definición y
lista crítica necesitan detalle. Un rol duplicado nunca hereda condición de propietario.
Recuperación excepcional es otro procedimiento auditado, aún no definido; no bypass.
Máximo de propietarios, retención del solicitante como copropietario, destino de sus
delegaciones y plazos/cancelación siguen abiertos.

## Contratos HTTP propuestos, no vigentes

El backend actual solo declara GET /healthz. Los siguientes no están implementados:

| Método / ruta | Condición y payload conceptual |
| --- | --- |
| GET /api/v1/role-templates | Versiones publicadas para tenant audiences; solo lectura, sin roles SaaS |
| GET /api/v1/permissions | Catálogo tenant/branch conocido, scopes/política de delegación; sin creación por usuario |
| GET /api/v1/tenants/{tid}/roles | Roles que el actor puede consultar según política aprobada |
| POST /api/v1/tenants/{tid}/roles | Copia desde template_id/version; backend fija scope/procedencia, valida permisos |
| POST /api/v1/tenants/{tid}/roles/{rid}/duplicate | name/code nuevos, version de origen esperada; copia sin grants |
| PATCH /api/v1/tenants/{tid}/roles/{rid} | Nombre/permisos explícitos + versión esperada; impacto/delegación, no tenant/scope/protección |
| POST /api/v1/tenants/{tid}/roles/{rid}/archive | Rechazar asignaciones activas; integridad/historial, protección Owner y guard concurrente |
| PUT/DELETE /api/v1/tenants/{tid}/memberships/{mid}/tenant-role-grants/{rid} | Scope tenant inequívoco; Role/Membership en tenant |
| PUT/DELETE /api/v1/tenants/{tid}/branches/{bid}/memberships/{mid}/role-grants/{rid} | Scope branch no nulo; todas las referencias del tenant |

Rutas de ownership y publicación SaaS no se habilitan por estos endpoints genéricos;
sus DTOs dependen de detalles pendientes; la política de transferencia está aprobada.
Recomendar rutas distintas para solicitud/invitación, aceptación y cancelación, nunca
PATCH genérico de Membership para completar transferencia. Mantener CSRF/audience/reautenticación
para cambios sensibles según sesión propuesta. Rechazar UUID ajenos sin revelar existencia,
catalog codes no válidos, cambios de scope y conflictos de versión, con errores seguros.
Revalidar asignaciones en PUT aunque el rol ya exista. Reintentos no duplican grants.
Recomendar If-Match/version obligatorio para mutaciones de roles y guardar audit antes/después.

## Criterios de pruebas para implementar posteriormente

| Caso | Resultado exigido |
| --- | --- |
| Restaurante intenta editar/publicar plantilla global | Go/DB deniegan; ninguna copia ajena cambia |
| Publicar v2 añade permiso a v1 | Copias v1 permanecen iguales; cambios solo por flujo explícito |
| Duplicar rol de otro tenant / falsificar source_role_id | 404 seguro o FK compuesta; sin copia/grant |
| Modificar permissions/template/scope/protection_kind por body | Rechazado; catálogo/Owner solo backend |
| Code inventado, retirado, wildcard o platform | Rechazado, sin código nuevo ni concesión |
| Duplicación contiene permiso no delegable para actor | Rechazo íntegro; no recorte silencioso |
| Duplicar Cajera | Copia exclusivamente Celtas; cero grants copiados |
| Extra para cajera S1 | Permitido solo S1; cajeras S2/S3 y otros tenants sin cambios |
| Grant combina Role/Membership/Branch de tenants distintos | Go deniega y FKs compuestas bloquean |
| branch_id omitido/null o rol branch en grant tenant | Sin acceso global; tipo/scope inválido rechazado |
| Actor posee P en S1 sin autorización de delegación en S2/tenant | Denegado aunque nombres de rol coincidan |
| Actor usa P pero no puede delegarlo / no puede gestionar roles | Crear/editar/asignar denegado |
| Propietario autoriza gestión con envelope S1; actor intenta S2 | Backend deniega, sin cambios compartidos |
| Se revoca autorización de administrador, conserva permiso de uso | Nuevas solicitudes de gestión deniegan; uso no da delegación |
| Delegación expresa en S2 pero sin permiso operativo allí | Solo delegación autorizada; no lectura/operación implícita |
| Actor edita rol con grants en scopes fuera de su autoridad | Denegado incluso si controla una sucursal del rol |
| Validación de edición concurre con grant nuevo en otro scope | Sin ampliación no validada; locking/version evita TOCTOU |
| Self-edit / duplicar rol con nombre Owner / clonar flags Owner | Sin autoescalación ni condición de propietario |
| Dos bajas concurrentes de owners; desactivación global de último Owner | Una operación rechazada; queda propietario activo |
| Transferencia falla a mitad o no cumple Identity/Membership al completar | Rollback, mantiene ownership previo; sin ventana sin Owner |
| Invitación no aceptada, otro destinatario, token expirado/reutilizado | Sin propiedad ni retiro del propietario previo |
| Transferencia sin verificación reforzada o solicitante ya no Owner | Denegada aunque solicitud anterior fuese válida |
| Dos aceptaciones concurrentes del mismo traspaso | Un efecto final, auditoría coherente; ningún doble retiro/grant |
| Editor/upgrade de copia elimina permiso crítico de Owner | Denegado; garantías protegidas conservadas |
| Retirada global de código crítico deja Owner sin administración | Cambio no habilitable sin preservar garantías; ninguna copia queda desprotegida |
| Archivar con grant activo o Membership suspendida con grant activo | Denegado; suspensión no sustituye revocación |
| Reasignar a rol más potente para poder archivar | Revalidar delegación; no escalación ni borrado de historia |
| Archivo concurre con nueva asignación al mismo rol | Un orden coherente; nunca grant activo en rol archivado |
| Duplicar copia y publicar nueva plantilla | Ambas copias independientes; sin actualización automática |
| Invocar recuperación por endpoints normales de roles | Denegado; no existe bypass de procedimiento excepcional |
| Retirar permission/archivar role/revocar grant o Membership | Nuevas solicitudes tras commit deniegan, incluida otra sesión del mismo usuario |
| BD/autorización inaccesible con caché vieja | Fail closed; no permisos antiguos como fallback |
| Cambio de rol/membership en tenant A | Permisos de tenant B no cambian; keys/version por ámbito |
| Entitlement activo sin permiso / permiso sin entitlement | Acción restringida denegada en ambos casos |
| Operador intenta roles tenant o Owner intenta platform | Sin equivalencia ni FK/concesión transversal |
| SELECT/UPDATE roles/grants sin filtro; pool reutilizado A/B | RLS conserva barrera tenant; sin contexto residual |
| Cambio sensible rechazado o confirmado | Registro apropiado sin secretos; éxito y diff con mismo commit |

Pruebas reales PostgreSQL con roles runtime, HTTP con guards y unitarias de delegación.
Fixture recomendada: dos tenants; Celtas con tres branches, Brayan y tres cajeras; otra
Identity con memberships en ambos tenants; al menos dos Owners para carreras de revocación.
Validar invariantes aprobadas de Owner ya descritas; concretar UX/factores pendientes
sin inventar bypass ni tratar políticas aprobadas como opcionales.
Estos son criterios, no pruebas ejecutadas ni garantías ya implementadas.
