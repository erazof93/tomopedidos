# Automatización local propuesta — 2026-10-13

## Acceso y configuración

Dentro del sandbox Windows actual, CodexSandboxOffline puede ejecutar Docker CLI,
pero no leer config.json ni conectar al pipe. Fuera del sandbox, la ejecución puntual
aprobada usa erazof y funciona. Mantener el sandbox y pedir aprobación por comando que
necesite Engine. No cambiar ACL, grupos, pipe, Docker Engine ni ejecutar como administrador.
No cambiar el contexto global: usar siempre --context default, compose.yaml explícito
y proyecto tomopedidos-local. El contexto implícito de erazof observado es desktop-linux.

La documentación oficial permite reglas de comandos para excepciones fuera del sandbox.
Propuesta sin instalar: permitir solo inspecciones específicas revisadas, por ejemplo
el prefijo completo de `docker --context default compose -f compose.yaml -p tomopedidos-local ps`.
Las reglas permiten argumentos adicionales tras el prefijo: revisar alcance y ejemplos
positivos/negativos antes de aprobarlas. Nunca autorizar prefijos generales docker,
docker compose, exec, psql o PowerShell. Una regla exec/psql permitiría SQL arbitrario;
BEGIN READ ONLY en un comando concreto no limita otros comandos futuros.
Si las políticas administradas impiden excepciones, mantener la ejecución manual.

No se instaló regla persistente ni se cambió configuración. Los modos de sandbox Windows
son alternativas oficiales, pero cambiar de modo no garantiza acceso al pipe. Para
diagnóstico adicional de configuración, /status y /debug-config permiten al operador
revisar restricciones efectivas; no volcar configuraciones con valores privados.

Fuentes consultadas con OpenAI Docs:
[sandbox Windows](https://learn.chatgpt.com/docs/windows/windows-sandbox),
[reglas](https://learn.chatgpt.com/docs/agent-configuration/rules).

## Procedimiento futuro

1. Identificar autorización funcional y límites de cada tarea. Acceso técnico al Engine
   no autoriza cambios de infraestructura ni SQL. Mantener fuente principal de contratos
   en backend Go; consultar AGENTS del subproyecto afectado.
2. Comprobar disponibilidad de CLI/Compose en sandbox. Para Engine, usar la excepción
   puntual aprobada o una regla específica previamente revisada. No cambiar configuración
   para sortear errores; ante denegación, detener y dejar evidencia.
3. Fijar destino: contexto default, proyecto tomopedidos-local, postgres, base
   tomopedidos_local y puerto 127.0.0.1:55432. Inspeccionar estado/health antes de conectar;
   no usar up/start/restart, inspect completo, config completo ni logs con secretos.
4. Revisar SQL concreto antes de autorizarlo: SELECT de catálogos sin funciones con
   efectos, sin archivos externos ni inclusión de otros scripts. Conectar con psql -X,
   ON_ERROR_STOP=1, en conexión nueva, BEGIN READ ONLY y ROLLBACK. Pedir excepción fuera
   del sandbox que cubra exactamente esas consultas. No mostrar pg_authid, passwords,
   environment, DSN, query text de terceros ni credenciales. No reutilizar 010 si la tarea
   excluye expresamente repetirlo. Bootstrap se limita aquí a las lecturas autorizadas;
   un rol específico de inspección es una propuesta futura que requeriría autorización
   independiente para crearlo/configurarlo, no una implementación actual.
5. Para tests aprobados, ejecutar checks existentes de docs/development.md dentro del
   workspace. API: go test ./... y go vet ./..., toolchain local y cachés locales;
   no migraciones ni integración externa por defecto. Frontends: pnpm 11.22.0 fijado,
   scripts existentes, dependencias presentes y sin instalación automática. Si falta
   toolchain/dependencias o acceso, detener; instalación/red requieren revisión aparte.
   Confirmar antes que los tests seleccionados no actúan sobre servicios o datos externos.
6. Registrar comando/consulta, destino, identidad, modo sandbox o excepción aprobada,
   exit code, resultados y límites. Separar ejecución propia de evidencia manual del
   usuario. Una consulta satisfactoria de metadata no prueba credenciales TCP, denegaciones
   efectivas ni RLS. Detener ante discrepancias sin aplicar correcciones automáticas.

## Autorización adicional

Cada operación que cree/modifique roles, schemas, tablas, permisos, datos o credenciales
necesita autorización explícita separada. También 020 (probes transaccionales), pruebas
TCP de logins pendientes, ejecución Goose, cambios de configuración/reglas persistentes,
instalaciones y modificaciones de infraestructura requieren revisar su alcance antes
de actuar. Deploy, push, Celtas y B2–B5 siguen excluidos en la tarea actual.
Los tests y procedimientos de este documento son propuestas, no ejecuciones de esta sesión.
