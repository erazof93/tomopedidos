# Auditoría de consolidación — 2026-10-13

> **Estado vigente:** consultar «Actualización de evidencia» al final. Los bloqueos anteriores son antecedentes históricos.
## Hallazgos verificados y tratamiento
| Área | Estado observado | Resultado / pendiente |
| --- | --- | --- |
| Estructura | API/admin/platform separados; AGENTS por aplicación | Conservada; workspace JS mínimo añadido |
| Go | Ejecutable 1.27.2 instalado; mínimo 1.26.0 | Compatible; usar ruta absoluta por PATH de sesión desactualizado |
| Dependencias Go | Chi 5.2.3 / pgx 5.7.6, sin go.sum | Tidy bloqueado por red; no cambiar versiones ni fabricar checksums |
| HTTP | Solo GET /healthz, recuperación/request ID, shutdown y timeouts | Sin negocio; health prueba liveness, no PostgreSQL ni readiness |
| PostgreSQL/sqlc | Sin DSN/pool/schema/queries/migraciones; YAML apunta a pgx/v5 | Preparación intencional, no persistencia ni RLS implementado |
| Abstracción DB | Executor contiene solo Exec | No confundir con DBTX sqlc; futuras consultas usarán interfaz generada/pgx |
| Frontend | Dos pantallas iniciales; alias Vite portable, TS strict, Tailwind 4, Vitest/jsdom | Configs conservadas; instalación actual no comprobada |
| UI | components.json + Button local | Preparación compatible con patrón shadcn, no librería/tema completo |
| Gestor | Sin packageManager/lock; node_modules manuales | pnpm 11.22.0 fijado; backups fuera de rutas activas; instalación bloqueada |
| Dependencias UI | radix-ui agregaba primitives no usados; Testing Library DOM implícito | Reemplazado por @radix-ui/react-slot 1.3.3; DOM 10.4.1 explícito |
| Dependencias preparadas | RHF/resolver aún no usados, Query sin consultas, Button sin pantalla consumidora | Conservar por stack autorizado; no implementar formularios ficticios |
| Scripts/checks | Dev/build/lint/type-check/test/formato presentes | Scripts raíz coordinan; pnpm no reinstala automáticamente al ejecutar checks |
| Documentación | npm y Go ausente descritos como vigentes; roadmap anterior | Corregido; índices mínimos y documentos técnicos/comerciales bajo demanda |
| Seguridad base | Sin Firebase/Next.js/OAuth Google/push ni .env reales en fuentes activas | Mantener núcleo independiente; verificación estática actual en verification.md |

Versiones directas se conservan salvo la sustitución funcional de Radix y peer DOM.
No hubo actualización por fallo de red. Versiones CLI sqlc/Goose/PostgreSQL aún sin fijar;
no se instalaron globalmente. Configs React no prueban compatibilidad de toda la resolución
transitiva: hace falta instalar y ejecutar checks estándar.

## Inferencias/riesgos técnicos — no fallos demostrados
- WriteTimeout de 15 s impediría SSE persistente; ajustar por ruta/política en Fase 3.
- Executor solo Exec no basta para sqlc futuro; no agregar abstracciones hasta tener SQL.
- Shared PostgreSQL necesita pruebas RLS reales; documentación no demuestra aislamiento.
- Sin locks/sums, reproducibilidad pendiente. Los checks frontend anteriores no validan cambios actuales.
- HTTP/env cubiertos solo por pruebas iniciales; no hay navegador/E2E ni autenticación.
- Copias auxiliares retiradas están bajo .cache ignorada; no reutilizarlas para afirmar instalación estándar.

## Propuestas pendientes
ADR de sesión/CSRF/CORS/SSE, herramientas SQL, política de dinero/geo y criterios de contratos
compartidos. Planes 1/1/3 sucursales, bundles, gracia/prorrateo y efectos de suspensión siguen
propuestos; no tienen precios ni reglas implementadas.
Detalles en [decisiones](decisions/README.md). Evidencia: [verificación](verification.md).

## Cambios concretos
Raíz: AGENTS, contexto/arquitectura/roadmap, package.json y pnpm-workspace.yaml.
Aplicaciones: AGENTS, package.json y Button; backend: formato de config_test.go.
Docs: auditoría, arquitectura/tenancy y eventos, business/model y suscripciones/pagos,
decisiones consolidadas, referencia Celtas, desarrollo y verificación.
Fuentes de negocio y configuración sqlc/go.mod/env/HTTP conservadas.
node_modules/dist iniciales movidos a .cache/legacy-bootstrap; sin borrado de archivos ajenos.

## Diagnóstico de red posterior — 2026-10-13
Confirmado en esta ejecución: DNS resuelve registry.npmjs.org, proxy.golang.org y
sum.golang.org, pero TCP/443 falla con EACCES antes de TLS. curl Windows/Schannel también
falla (exit 7, HTTP 000); Go reproduce connectex “socket ... forbidden by its access permissions”.
pnpm vuelve a fallar con ERR_PNPM_META_FETCH_FAIL. No hay evidencia de incompatibilidad
de herramientas, error de DNS o certificado como causa de estos fallos.

Causa probable principal: restricción de red del entorno de ejecución. La regla concreta
(sandbox/política de seguridad/firewall/antivirus) no fue identificada; no atribuirla
exclusivamente a Windows ni afirmar falta de Internet fuera de esta sesión.
No hay proxy/PAC configurado en fuentes revisadas. Registries/proxy Go y sumdb son oficiales;
TLS no se deshabilitó. Almacenes CA locales disponibles, cadena remota no evaluable.
Go instalado por ruta absoluta sigue siendo compatible; PATH de sesión es un problema distinto.

Instalación y cierre Fase 0 continúan bloqueados: sin lock, go.sum, node_modules activos
o binario. Checks completos no repetidos ante el mismo bloqueo; resultados anteriores
no se presentan como actuales. Diagnóstico, errores exactos y comandos manuales seguros
en [verification.md](verification.md). No cambiaron fuente, manifests, arquitectura,
modelo comercial ni estado del roadmap; no se inició Fase 1.


## Actualización de evidencia — 2026-10-13 (usuario, PowerShell externo a Codex)
- `pnpm install` y `pnpm install --frozen-lockfile`: aprobados.
- `pnpm -r type-check`, `pnpm -r lint`, `pnpm -r test` y `pnpm -r build`: aprobados en admin y platform; tests iniciales, no pruebas funcionales SaaS.
- En `tomopedidos-api`: `go mod tidy`, `go mod download`, `go test ./...`, `go vet ./...`, `go build ./...`: aprobados.
- `go mod verify`: `all modules verified`.
- No consta ejecución de `pnpm run format:check`, ni revisión directa de `git status`/`.gitignore`, ni prueba de PostgreSQL/RLS.
- La evidencia anterior de red bloqueada describe el entorno de Codex en ese momento; no invalida las verificaciones posteriores desde PowerShell.
- Cierre Fase 0 condicionado a verificar existencia/versionabilidad de `pnpm-lock.yaml` y `tomopedidos-api/go.sum`, ejecutar formato si es criterio de aceptación y registrar cierre en ROADMAP.

## D2.1-A — actualización vigente 2026-10-13

Autorizado únicamente entorno/herramientas. Compose válido con PostgreSQL 18.6-bookworm
fijado por digest oficial, puerto loopback, healthcheck, secret file y volumen propio.
Scripts PowerShell y Goose v3.29.0/sqlc v1.31.1 preparados para instalación local sin
cambiar PATH ni dependencias API. Sin SQL funcional ni API de autenticación.

Separación prevista: bootstrap privilegiado exclusivamente inicialización; migrador y
runtime distintos, secretos locales ignorados. Esos dos roles/grants todavía no existen.
Los scripts conservan archivos preexistentes y no incluyen borrado de volúmenes.
Contexto Docker/proyecto fijados; scripts rechazan motores remotos.

Verificado: Docker/Compose clientes presentes, Go 1.27.2 por ruta absoluta, Compose
normalizado y sintaxis PowerShell válidos. Bloqueado: pipe/config Docker, ejecución .ps1
(Restricted) y descarga Go por restricción de socket. No se desactivaron controles.
Digest obtenido de fuente web oficial; pull local y ejecución de binarios aún pendientes.
No se generaron secretos, no se arrancó PostgreSQL y no se ejecutaron migraciones.

Fase 0 completada por confirmación del usuario; Fase 1 solo avanza D2.1-A, parcialmente
verificado. Estado y resultados actuales sustituyen afirmaciones históricas de locks
inexistentes: pnpm-lock.yaml y go.sum sí están presentes. Sin .git raíz, no se puede
informar git status real; .gitignore contempla secretos, cache, tools y artefactos.
Pendiente ejecutar desde PowerShell con acceso normal los pasos de la [guía local](local-postgresql.md)
y registrar evidencia antes de cerrar D2.1-A. D2.1-B necesita autorización independiente.
[Comandos y errores exactos](verification.md), sección D2.1-A.

## Configuración local vigente — .env principal

Compose actual (editado por usuario) usa variables desde .env automáticamente y ya no
monta secretos anteriores. Scripts adaptados; .env existente y .env.local conservados,
sin rotación interna de PostgreSQL. Plantilla saneada con marcador sin contraseña real.
Cuatro pruebas de inicialización y validación Compose aprobadas. Git ignore efectivo y
escaneo de contenido candidato verificados; sin .git raíz no se acredita historial/staging.
Healthy/puerto aportados por usuario; Engine inaccesible a Codex, TCP autenticado pendiente.
Goose/sqlc fijados todavía no disponibles. Procedimiento vigente: docs/local-postgresql.md;
evidencia detallada en docs/verification.md. Alcance D2.1-A sin ampliar a D2.1-B.

## Estado vigente tras cierre D2.1-A

D2.1-A completada con evidencia identificada del usuario de PostgreSQL/TCP y Goose/sqlc
Docker; no se requieren binarios Windows. Las afirmaciones anteriores de herramientas
pendientes corresponden a verificaciones históricas de Codex. Acceso Engine de Codex
sigue bloqueado. Rutas de SQL de herramientas y grants migrador/runtime se revisan como
preflight D2.1-B; no se ejecutó SQL ni se completó Fase 1. Inventario y propuesta en
[diseño B](architecture/d2-1-b-schema-design.md); evidencia en [verification.md](verification.md).
