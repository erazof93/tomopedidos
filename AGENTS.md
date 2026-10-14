# Tomopedidos.pe — Instrucciones para Codex

## Alcance y fuentes de verdad

- Trabajar únicamente en los repositorios de Tomopedidos.pe. Celtas es independiente y solo puede consultarse como referencia de lectura cuando esté autorizado; no modificar sus repositorios, bases de datos ni contenedores.
- Priorizar código vigente, dependencias, contratos y tests sobre documentación. El backend Go define los contratos; el panel React y la plataforma del operador son consumidores.
- Consultar solo el contexto necesario: `PROJECT_CONTEXT.md` y el `AGENTS.md` del subproyecto afectado; según la tarea, `ARCHITECTURE.md`, `ROADMAP.md`, `WORKFLOW.md` y `docs/verification.md`.
- Respetar gestores de paquetes y versiones fijados por cada subproyecto; usar pnpm donde así lo establezca `package.json`. No instalar dependencias sin autorización.
- Distinguir siempre: implementado, aprobado, propuesto y verificado mediante ejecución real.
- No utilizar producción, secretos reales ni realizar deploy, git push, publicación, migraciones externas o destructivas sin autorización explícita.

## Estado de D2.1-B1 (referencia; verificar en evidencia vigente)

- D2.1-A: cerrada según el registro del proyecto.
- `001_roles.sql`: aplicado y roles verificados en PostgreSQL local.
- `002_schema_privileges.sql`: aplicado; `COMMIT` confirmado.
- `010_b1_metadata.sql`: ejecutado con `B1 metadata checks passed`, `ROLLBACK` y código 0.
- `020_b1_effective_privileges.sql`: ejecutado por Codex el 2026-10-14 con código 0, 14 negativos aprobados, `ROLLBACK` y limpieza confirmada; lecturas posteriores y repetición final de `010` aprobadas. Evidencia en `docs/verification.md`.
- Credenciales independientes y autenticación TCP interna/Windows de ambos roles: aprobadas por evidencia manual del usuario; cuatro negativos de contraseña rechazados, códigos capturados 2. Evidencia en docs/verification.md.
- D2.1-B1 completada: SET LOCAL ROLE tp_owner, identidad y search_path confirmados manualmente en sesión TCP Windows como migrator, con ROLLBACK y exit 0. B2–B5 no iniciados ni autorizados.
- Este resumen no sustituye a `docs/verification.md` ni autoriza ejecutar scripts. Actualizarlo cuando cambie el estado comprobado.

## Docker: ejecución y diagnóstico

- Ejecutar **cada invocación de Docker** en una llamada independiente a `exec_command`. No mezclarla con `Get-FileHash`, `cd`, comprobaciones u otros comandos usando `;`, `&&` o cadenas de comandos.
- Separar los diagnósticos (hash, contexto, contenedor, puerto, base de datos) y comprobar el código de salida antes de avanzar.
- Para el entorno local de Tomopedidos usar explícitamente `docker --context default` y, con Compose, `-f D:\tomopedidos\compose.yaml -p tomopedidos-local` cuando corresponda.
- No asumir acceso a Docker por éxitos en otras sesiones. Confirmar acceso y destino en la sesión actual.
- Excepción estricta: si un **script SQL concreto ya está autorizado**, puede enviarse a `psql -f -` por stdin mediante una única invocación Docker; no mezclar esa invocación con diagnósticos ni otros scripts. Comprobar el resultado de la invocación y las señales de éxito esperadas del SQL.
- Si Docker falla por permisos, informar el comando exacto, salida y código de error; detenerse. No intentar accesos alternativos, elevación, cambios de ACL, sandbox, named pipe ni Docker Desktop sin autorización.

## Autorización y seguridad de base de datos

- El acceso a Docker **no autoriza** operaciones SQL ni cambios persistentes.
- Antes de ejecutar SQL, comprobar archivo vigente, integridad, alcance, destino local, usuario y riesgos de efectos persistentes. No omitir controles por conveniencia.
- Las consultas estrictamente de lectura pueden ejecutarse dentro del alcance previamente autorizado.
- Los scripts que crean objetos incluso si terminan en `ROLLBACK`, cambios de privilegios, migraciones, credenciales y cualquier operación persistente requieren autorización específica para el alcance correspondiente.
- No repetir scripts aplicados, modificar privilegios para que una prueba pase ni avanzar a nuevas fases por inferencia.
- No ejecutar operaciones contra Celtas ni ambientes de producción.

## Evidencia y cierre

- Registrar comandos, destino, hash cuando aplique, salida relevante, código de salida, errores y resultados en `docs/verification.md`.
- Diferenciar inspección estática de pruebas dinámicas ejecutadas.
- Una prueba no se considera aprobada solo por tener salida exitosa de Docker: comprobar sus aserciones, `ROLLBACK` cuando corresponda y ausencia de residuos cuando aplique.
- Ante un error, detenerse, conservar evidencia y comunicar qué quedó pendiente, sin reintentos ni correcciones no autorizadas.
