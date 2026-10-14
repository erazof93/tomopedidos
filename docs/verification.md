# Verificación — Fase 0 (registro histórico y actualización)

> **Estado vigente:** consultar «Actualización de evidencia» al final. Los bloqueos descritos a continuación son históricos, no el estado actual del equipo.
Este registro sustituye el estado de inicialización. Los checks frontend aprobados entonces
usaron preparación manual; no son evidencia de los cambios ni de una instalación pnpm actual.

## Entorno real
Node v24.19.0; pnpm 11.22.0; ejecutable pnpm existente en WinGet, sin instalación global.
Go go1.27.2 windows/amd64 en C:/Program Files/Go/bin/go.exe, mínimo go.mod 1.26.0.
Get-Command go no lo encuentra en esta sesión. PATH de máquina leído incluye Go/bin;
PATH del proceso no. Inferencia: sesión anterior a la instalación/cambio de PATH.
No se cambió PATH global ni se instaló otro Go.

go env leído: GOROOT C:/Program Files/Go, GOPATH C:/Users/erazof/go,
GOMOD D:/tomopedidos/tomopedidos-api/go.mod, GOPROXY https://proxy.golang.org,direct,
GOSUMDB sum.golang.org, GOTOOLCHAIN local, GOOS windows, GOARCH amd64.
Para verificaciones se fijaron solo variables del proceso: GOENV=off y GOCACHE/GOMODCACHE/
GOTMPDIR en D:/tomopedidos/.cache/go. Checks tras tidy usan GOPROXY=off para no repetir red.

## Comandos de auditoría anterior (antecedente, no ejecuciones nuevas)
| Comando / revisión | Resultado |
| --- | --- |
| Get-Content AGENTS primero; inventario rg/Get-ChildItem y lectura de archivos seleccionados | Instrucciones, configs, SQL y docs contrastados |
| Get-Command go/pnpm/node; lectura de PATH máquina/proceso; ruta estándar Go | Go instalado fuera del PATH de sesión |
| go.exe version; go.exe env (claves listadas arriba); pnpm --version; node --version | Versiones/env comprobados |
| gofmt.exe -w cmd internal; gofmt.exe -l cmd internal | Formato aplicado; lista final vacía |
| go.exe mod tidy | Exit 1, sockets bloqueados hacia proxy.golang.org para Chi/pgx; sin go.sum |
| go.exe test ./... | Exit 1 por entradas/dependencias no resueltas; config sí pasó |
| go.exe vet ./... | Exit 1 por dependencias sin go.sum |
| go.exe build -o ../.cache/go/api.exe ./cmd/api | Exit 1 por dependencias sin go.sum; sin binario |
| go.exe test ./internal/config | Exit 0; prueba de carga con seis subcasos aprobada |
| go.exe vet ./internal/config | Exit 0 |
| pnpm list -r --depth -1 | Reconoce raíz y dos aplicaciones |
| pnpm install --ignore-scripts --fetch-retries=0 --fetch-timeout=10000 --reporter=append-only | Falla ERR_PNPM_META_FETCH_FAIL; red registro bloqueada (antes/después de normalizar manifests) |
| pnpm install --offline --frozen-store --lockfile-only --ignore-scripts --store-dir D:/.pnpm-store --reporter=append-only | Falla ERR_PNPM_NO_OFFLINE_META; metadatos insuficientes, store externo solo lectura |
| pnpm install --frozen-lockfile --ignore-scripts --fetch-retries=0 --fetch-timeout=10000 --reporter=append-only | Falla ERR_PNPM_NO_LOCKFILE; ningún lock inventado |
| pnpm run type-check (config inicial pnpm) | Intentó instalación automática y encontró EACCES; detenido sin ejecutar tsc |
| pnpm run type-check (verifyDepsBeforeRun: error) | Bloqueado ERR_PNPM_VERIFY_DEPS_BEFORE_RUN; checks no ejecutados |
| pnpm config get verify-deps-before-run | error; evita instalaciones implícitas en checks |
| node .cache/audit-local.cjs | PASS: 18 documentos, 35 enlaces locales válidos, manifests fijados/coherentes, sin integraciones frontend prohibidas, SQL de negocio ni instalaciones manuales activas |

Los intentos de instalación no descargaron/resolvieron una instalación completa. Las copias
manuales previas y builds fueron movidos a .cache/legacy-bootstrap dentro del workspace,
con rutas verificadas; paquetes auxiliares viejos .cache/local-packages quedan inactivos.
No se copió código ni paquetes de Celtas durante esta auditoría.
Sin pnpm-lock.yaml, package-lock.json, go.sum o node_modules activos al cierre.

## Pendientes / no ejecutado
- Instalación estándar completa, lock real y verificación congelada.
- Build/lint/formato/test frontend actuales: no ejecutados tras migrar porque no hay instalación.
- Build/test/vet Go completos: intentados y bloqueados; no declararlos aprobados.
- sqlc/Goose no en PATH; generate no ejecutado porque schema/queries están vacíos.
- Pruebas PostgreSQL/RLS, SSE/auth/pagos/licencias y migraciones: fases futuras.
- Auditoría de vulnerabilidades, E2E/navegador y benchmarks: no realizados.
- Sin dev servers, API persistente, bases externas, producción, secretos, cambios Celtas,
  deploy, publicación, git init/commit/push o cambios globales.

## Cierre de Fase 0
Resolver acceso autorizado al registro/proxy, ejecutar instalación pnpm y go mod tidy,
conservar lock/sum y repetir checks completos. Después solicitar aprobación para comenzar
Fase 1; contratos/auth/aislamiento local primero. No se empezó esa fase.

## Diagnóstico de red actual
**Confirmado:** DNS funciona; las conexiones salientes TCP/443 de esta ejecución son
rechazadas por permisos, antes de TLS. Node devuelve EACCES (connect, errno -4092 para
Go proxy/sumdb); Go devuelve connectex con el texto reproducido abajo.
El entorno de ejecución tiene red restringida: causa probable principal del bloqueo.
No se pudo identificar la regla concreta ni atribuirla a firewall/antivirus del equipo.
No demuestra que la conexión a Internet del equipo fuera de esta sesión esté averiada.

| Servicio oficial | DNS Node / Windows | TCP Node | TLS / HTTPS Node | curl Windows |
| --- | --- | --- | --- | --- |
| registry.npmjs.org | Resuelve; 12 direcciones IPv4 | EACCES | EACCES antes de handshake | Exit 7, HTTP 000 |
| proxy.golang.org | Resuelve; 1 dirección IPv4 | EACCES | EACCES antes de handshake | Exit 7, HTTP 000 |
| sum.golang.org | Resuelve; 1 dirección IPv4 | EACCES | EACCES antes de handshake | Exit 7, HTTP 000 |

No hubo HTTP 401/403/404, errores de certificado ni negociación TLS completada.
Por tanto no se verificó la cadena/fecha/certificado remoto, ni la existencia de cada
versión publicada. No interpretar HTTP 000 como respuesta del servidor.

### Configuración revisada (sin secretos)
- Go, Node y pnpm mantienen las versiones anteriores, comprobadas de nuevo.
  Go/bin figura en PATH de máquina, no en PATH de proceso; ruta absoluta disponible.
- go env efectivo: GOPROXY oficial https://proxy.golang.org,direct y GOSUMDB sum.golang.org,
  ambos activos. GOPRIVATE/GONOPROXY/GONOSUMDB/GOINSECURE/GOFLAGS sin configurar.
  GOTOOLCHAIN=local solo en el proceso; Go mínimo 1.26.0 compatible con instalado 1.27.2.
- HTTP_PROXY/HTTPS_PROXY/ALL_PROXY/NO_PROXY sin configurar en proceso, usuario o máquina.
  WinHTTP informa acceso directo; WinINET sin proxy ni PAC configurados.
- pnpm apunta exactamente a https://registry.npmjs.org/; proxy/https-proxy/ca/cafile
  sin override. strict-ssl sin override (no deshabilitado); verifyDepsBeforeRun=error.
- NODE_TLS_REJECT_UNAUTHORIZED/NODE_EXTRA_CA_CERTS/NODE_OPTIONS, SSL_CERT_FILE/SSL_CERT_DIR
  y overrides NPM_CONFIG_REGISTRY/PROXY/HTTPS_PROXY/STRICT_SSL sin configurar.
- Windows: 44 raíces visibles por almacén CurrentUser/LocalMachine. Node/OpenSSL 3.5.7:
  120 CA por defecto/bundled y 73 CA de sistema. Son inventario local, no prueba de
  confianza del certificado remoto. curl usa Schannel; Node usa OpenSSL; ambos fallan antes de TLS.
- No se mostraron tokens, passwords, contenido de .env ni configuraciones completas de usuario.

### Comandos actuales y resultados
| Comando / prueba | Resultado |
| --- | --- |
| Get-Command go/pnpm/node/curl.exe, ruta estándar; go.exe version, node --version, pnpm --version, curl.exe --version | Herramientas disponibles; Go por ruta absoluta |
| go.exe env -json con claves seleccionadas y salida saneada | Defaults oficiales activos, sin overrides inseguros |
| Lectura de presencia de variables en Process/User/Machine y propiedades WinINET | Sin proxy/CA overrides; no se modificaron variables globales |
| netsh.exe winhttp show proxy (salida reducida) | Exit 0; acceso directo |
| Resolve-DnsName -Type A para los tres hosts | Todos resuelven |
| node .cache/network-diagnostic.cjs | DNS, TCP, TLS con rejectUnauthorized=true, HTTPS y config pnpm saneada; reporte local generado |
| Inventario Cert:/CurrentUser/Root, Cert:/LocalMachine/Root y tls.getCACertificates | Almacenes accesibles; certificado remoto no evaluable |
| curl.exe --head --silent --show-error --connect-timeout 4 --max-time 8 --output NUL --write-out 'http_code=%{http_code}\n' URL, para tres endpoints oficiales | Todos exit 7, http_code=000 |
| pnpm install --ignore-scripts --fetch-retries=0 --fetch-timeout=10000 --reporter=append-only | Exit 1, ERR_PNPM_META_FETCH_FAIL, sin instalación/lock |
| go.exe mod tidy (caches dentro del workspace, GOENV=off, GOTOOLCHAIN=local) | Exit 1, connectex: acceso a socket prohibido; sin go.sum |
| node .cache/audit-local.cjs; comprobación de lock/sum/node_modules | PASS estático: 18 documentos, 35 enlaces; archivos de dependencias e instalaciones activas ausentes |

Errores exactos actuales (endpoints públicos, sin credenciales):
```text
[ERR_PNPM_META_FETCH_FAIL] GET https://registry.npmjs.org/@testing-library%2Fjest-dom: fetch failed
Get "https://proxy.golang.org/github.com/go-chi/chi/v5/@v/v5.2.3.zip": dial tcp 172.217.192.141:443: connectex: An attempt was made to access a socket in a way forbidden by its access permissions.
Get "https://proxy.golang.org/github.com/jackc/pgx/v5/@v/v5.7.6.zip": dial tcp 172.217.192.141:443: connectex: An attempt was made to access a socket in a way forbidden by its access permissions.
Node TCP: EACCES; syscall connect; errno -4092 (proxy/sumdb).
curl: (7) Failed to connect to registry.npmjs.org:443 after 29 ms: Could not connect to server
```

### Clasificación y pendientes
Permisos de salida: confirmado. DNS: funciona. TLS: no evaluable, sin evidencia de fallo.
Proxy: no configurado en fuentes revisadas; una política corporativa que lo exija no se ha
demostrado. Versiones: herramientas compatibles; dependencias publicadas no comprobadas
por imposibilidad de contactar registros. PATH Go: problema independiente, resuelto para
estos comandos mediante ruta absoluta; no explica EACCES de pnpm.

La instalación no se completó. Sin pnpm-lock.yaml, go.sum, node_modules nuevos o binarios.
Build/test/vet completos y checks frontend no se repitieron: bloqueo sin cambios de código.
Las pruebas de configuración Go aprobadas son las de la auditoría anterior.
Solo se actualizaron verification.md y audit.md; ROADMAP no cambió porque Fase 0 conserva
el estado “En curso, bloqueo parcial”. Evidencia temporal saneada en .cache/network-diagnostic.*.

### Pasos seguros para el equipo
1. Abrir una terminal PowerShell normal del equipo y ejecutar las mismas pruebas de abajo.
   Esto compara entornos; no requiere administrador ni desactivar controles.
2. Si allí funciona, ejecutar instalaciones/checks desde esa terminal y conservar resultados.
   Revisar el permiso de red autorizado del entorno del agente para ejecuciones futuras.
3. Si allí también falla, revisar con el responsable de red/seguridad las políticas de
   salida TCP/443 para los ejecutables Go/Node/pnpm y los servicios oficiales. Verificar
   si la organización exige proxy; obtener configuración autorizada, sin publicarla.
   No desactivar firewall/TLS ni sustituir registros. Seguir redirects oficiales a CDN
   solo mediante las herramientas oficiales y la política aprobada.
4. Si tras restaurar TCP aparece un error TLS, entonces revisar reloj y cadena de confianza
   conforme a la política del equipo; no instalar certificados arbitrarios ni usar -k.

Prueba manual (sin servicios persistentes):
```powershell
Set-Location D:\tomopedidos
foreach ($hostName in @('registry.npmjs.org', 'proxy.golang.org', 'sum.golang.org')) {
  Resolve-DnsName -Name $hostName -Type A
}
$urls = @(
  'https://registry.npmjs.org/react',
  'https://proxy.golang.org/github.com/go-chi/chi/v5/@v/v5.2.3.info',
  'https://sum.golang.org/lookup/github.com/go-chi/chi/v5@v5.2.3'
)
foreach ($url in $urls) {
  & curl.exe --head --silent --show-error --connect-timeout 4 --max-time 8 --output NUL --write-out 'http_code=%{http_code}\n' $url
  if ($LASTEXITCODE -ne 0) { throw 'HTTPS bloqueado; detener y revisar conectividad' }
}
```

Solo si HTTPS funciona, completar desde el workspace sin cambiar configuración global:
```powershell
Set-Location D:\tomopedidos
pnpm install
if ($LASTEXITCODE -ne 0) { throw 'Instalación pnpm incompleta' }
pnpm install --frozen-lockfile
if ($LASTEXITCODE -ne 0) { throw 'Lockfile no verificado' }
foreach ($script in @('type-check', 'lint', 'format:check', 'test', 'build')) {
  pnpm run $script
  if ($LASTEXITCODE -ne 0) { throw "Falló $script" }
}
$goExe = 'C:\Program Files\Go\bin\go.exe'
$env:GOTOOLCHAIN = 'local'
$env:GOENV = 'off'
$env:GOCACHE = 'D:\tomopedidos\.cache\go\build'
$env:GOMODCACHE = 'D:\tomopedidos\.cache\go\mod'
$env:GOTMPDIR = 'D:\tomopedidos\.cache\go\tmp'
New-Item -ItemType Directory -Path $env:GOTMPDIR -Force | Out-Null
Set-Location D:\tomopedidos\tomopedidos-api
& $goExe mod tidy
if ($LASTEXITCODE -ne 0) { throw 'Dependencias Go sin resolver' }
& $goExe mod verify
if ($LASTEXITCODE -ne 0) { throw 'Integridad Go no verificada' }
$unformatted = & 'C:\Program Files\Go\bin\gofmt.exe' -l cmd internal
if ($LASTEXITCODE -ne 0 -or $unformatted) { throw 'Revisar formato Go' }
& $goExe test ./...
if ($LASTEXITCODE -ne 0) { throw 'Fallaron pruebas Go' }
& $goExe vet ./...
if ($LASTEXITCODE -ne 0) { throw 'Falló go vet' }
& $goExe build -o '..\.cache\go\api.exe' ./cmd/api
if ($LASTEXITCODE -ne 0) { throw 'Falló build Go' }
```

Si pnpm informa build scripts sin revisar, detenerse y seguir docs/development.md;
no aprobarlos todos automáticamente. Registrar salida/códigos de cada check. Un lock
congelado prueba coherencia de la instalación con el lock, no un build idéntico entre sistemas.
Fase 0 solo se cierra después de resolver dependencias y aprobar todos los checks.
No comenzar Fase 1 sin aprobación del usuario.

Revisión documental final: auditoría estática aprobada sobre 18 documentos y 36 enlaces
locales; ROADMAP conserva su fecha/contenido y estado de Fase 0. Locks/sum/binario ausentes.
Parser PowerShell: los dos bloques de comandos manuales tienen sintaxis válida; se analizaron
sin ejecutar sus instalaciones ni checks.


## Actualización de evidencia — 2026-10-13 (usuario, PowerShell externo a Codex)
- `pnpm install` y `pnpm install --frozen-lockfile`: aprobados.
- `pnpm -r type-check`, `pnpm -r lint`, `pnpm -r test` y `pnpm -r build`: aprobados en admin y platform; tests iniciales, no pruebas funcionales SaaS.
- En `tomopedidos-api`: `go mod tidy`, `go mod download`, `go test ./...`, `go vet ./...`, `go build ./...`: aprobados.
- `go mod verify`: `all modules verified`.
- No consta ejecución de `pnpm run format:check`, ni revisión directa de `git status`/`.gitignore`, ni prueba de PostgreSQL/RLS.
- La evidencia anterior de red bloqueada describe el entorno de Codex en ese momento; no invalida las verificaciones posteriores desde PowerShell.
- Cierre Fase 0 condicionado a verificar existencia/versionabilidad de `pnpm-lock.yaml` y `tomopedidos-api/go.sum`, ejecutar formato si es criterio de aceptación y registrar cierre en ROADMAP.

## D2.1-A — 2026-10-13, verificaciones de Codex

Este registro describe el estado actual y prevalece sobre los bloqueos de Fase 0
históricos. Fase 0 completada según confirmación del usuario; locks reales presentes
(`pnpm-lock.yaml`: 101607 bytes; `tomopedidos-api/go.sum`: 2297 bytes).
Fase 1 iniciada solo en D2.1-A; no se repitieron checks Go/frontend sin cambios de código.

| Comando / inspección | Resultado real |
| --- | --- |
| `Get-Command docker,go` | Docker en PATH; Go no en PATH de esta sesión |
| `docker version` | Cliente 29.8.1/API 1.56; acceso al daemon denegado, exit 1 |
| `docker compose version` | Compose v5.5.1 disponible, exit 0; warning de lectura config Docker |
| `docker compose ls --format json` | Acceso al motor denegado; no lista obtenida |
| `docker --config D:\tomopedidos\.cache\docker compose version` | No encuentra plugin Compose bajo ese config alternativo; no se adopta esta opción |
| `docker --context default context inspect default --format '{{.Endpoints.docker.Host}}'` | Named pipe local `npipe:////./pipe/docker_engine`, exit 0 |
| `C:\Program Files\Go\bin\go.exe version` | go1.27.2 windows/amd64, exit 0 |
| `Invoke-RestMethod` a Docker Hub tag 18.6-bookworm, timeout 15 s | `No es posible conectar con el servidor remoto` |
| `scripts/local-db.ps1 -Action Config` | Bloqueado por política de scripts, antes de ejecutar contenido |
| `scripts/db-tools.ps1 -Action Install` | Mismo bloqueo; ninguna instalación a través del script |
| `Get-ExecutionPolicy` / `Get-ExecutionPolicy -List` | Política efectiva Restricted; scopes Undefined; no se modificó |
| Parser PowerShell de ambos scripts | Sin errores de sintaxis; no prueba ejecución operativa |
| `docker compose --env-file .env.example -f compose.yaml config --quiet` | Válido, exit 0, sin motor ni secretos |
| `docker compose ... config --format json` | Config normalizada en `.cache/d2-1-a-compose.json`; revisión puerto, healthcheck, secreto y volumen correcta |
| `docker --context default compose --project-name tomopedidos-local --env-file .env.example -f compose.yaml config --quiet` | Válido tras fijar digest y contexto/proyecto, exit 0 |
| `go install github.com/pressly/goose/v3/cmd/goose@v3.29.0` | Falló por permisos de socket HTTPS hacia proxy.golang.org, exit 1 |
| `go install github.com/sqlc-dev/sqlc/cmd/sqlc@v1.31.1` | Mismo bloqueo de red, exit 1 |

Los intentos Go usaron ejecutable absoluto, GOTOOLCHAIN=local, GOENV=off, CGO_ENABLED=0,
GOBIN por versión en `.tools/` y GOCACHE/GOMODCACHE/GOTMPDIR dentro del workspace;
variables limitadas al proceso del comando. No se alteraron go.mod/go.sum de la API.

Errores exactos relevantes, sin valores sensibles:

```text
WARNING: Error loading config file: open C:\Users\erazof\.docker\config.json: Access is denied.
permission denied while trying to connect to the docker API at npipe:////./pipe/docker_engine
No se puede cargar el archivo [...] porque la ejecución de scripts está deshabilitada en este sistema.
Get "https://proxy.golang.org/github.com/pressly/goose/v3/cmd/goose/@v/v3.29.0.info": dial tcp 172.217.192.141:443: connectex: An attempt was made to access a socket in a way forbidden by its access permissions.
Get "https://proxy.golang.org/github.com/sqlc-dev/sqlc/cmd/sqlc/@v/v1.31.1.info": dial tcp 172.217.192.141:443: connectex: An attempt was made to access a socket in a way forbidden by its access permissions.
```

Causas verificadas: permisos de acceso al config/motor Docker, política PowerShell y
restricción de socket de la sesión. No evidencia de incompatibilidad de versiones,
error TLS o fallo PostgreSQL: la instalación/arranque no llegaron a esas etapas.
La atribución concreta al sandbox frente a política del equipo es una inferencia;
no prueba que Docker Desktop esté detenido. No se cambiaron ACLs ni reglas globales.

Consulta web de fuentes oficiales confirmó versiones Go de herramientas y permitió
obtener el digest del índice PostgreSQL desde docker-library/repo-info; esto no demuestra
conectividad del shell al registry. Compose final fija versión y digest, host 127.0.0.1,
puerto 55432, healthcheck pg_isready y volumen `/var/lib/postgresql` para PostgreSQL 18.

No realizadas: pull/arranque/readiness/SELECT PostgreSQL, versiones ejecutables de
Goose/sqlc, migraciones, generación sqlc, grants/RLS o checks de auth. No se crearon
secretos locales, roles ni tablas; directorios SQL conservan únicamente .gitkeep.
No se eliminaron volúmenes ni se inició D2.1-B. D2.1-A configurado y parcialmente verificado,
no completado. Pasos manuales seguros y comandos en [guía local](local-postgresql.md).

Revisión final del incremento: config JSON actualizado tras fijar digest, contexto y
proyecto; assertions de loopback, digest, healthcheck, secret file y mount aprobadas.
Parser: 2 scripts y 4 bloques PowerShell de la guía válidos. Versiones JSON correctas;
62 enlaces locales en 13 documentos válidos; reglas ignore de secretos/tools/cache/
artefactos presentes. Verificación estática únicamente, sin git check-ignore porque
no existe .git raíz. `.env.local` y `.local/` no fueron creados; 0 archivos SQL nuevos.

## D2.1-A — reintento de verificación final, 2026-10-13

Resultado: **parcialmente verificado, no completado**. Esta evidencia corresponde a
la sesión de Codex después de la preparación Windows indicada por el usuario; no
certifica ni invalida resultados de su PowerShell externo. ROADMAP no cambia de estado.

| Comando / comprobación ejecutada | Resultado |
| --- | --- |
| `docker --context default context inspect default --format '{{.Endpoints.docker.Host}}'` | Exit 0; endpoint local `npipe:////./pipe/docker_engine` |
| `docker --context default version` | Exit 1; cliente 29.8.1/API 1.56 disponible, acceso Engine denegado |
| `docker compose version` | Exit 0; Compose v5.5.1 |
| `Get-ExecutionPolicy` | `Restricted` |
| `docker --context default compose -p tomopedidos-local --env-file .env.example -f compose.yaml config --quiet` | Exit 0; Compose válido, sin arrancar ni requerir secreto |
| `scripts/local-db.ps1 -Action Config` | Exit 1; ejecución .ps1 bloqueada antes de entrar al script |
| `scripts/db-tools.ps1 -Action Versions` | Exit 1; mismo bloqueo de ejecución .ps1 |
| `Test-Path .env.local` y `.local/postgres/bootstrap-password.txt` | Ambos False; configuración local/secreto ausentes en este workspace |
| Lectura `tools/versions.json` y Test-Path de ejecutables fijados | Goose v3.29.0/sqlc v1.31.1 fijados; ambos ejecutables ausentes en .tools por versión |
| Lectura de scripts, Compose y ROADMAP | Sin modificaciones; alcance D2.1-A y estado parcialmente verificado conservados |

Errores concretos:

```text
WARNING: Error loading config file: open C:\Users\erazof\.docker\config.json: Access is denied.
permission denied while trying to connect to the docker API at npipe:////./pipe/docker_engine
No se puede cargar el archivo D:\tomopedidos\scripts\local-db.ps1 porque la ejecución de scripts está deshabilitada en este sistema.
No se puede cargar el archivo D:\tomopedidos\scripts\db-tools.ps1 porque la ejecución de scripts está deshabilitada en este sistema.
```

Se detuvo el paso Docker tras fallo Engine: no se ejecutaron up/pull, healthcheck,
pg_isready, SELECT 1 ni stop. No se iniciaron servicios en este intento; el acceso
bloqueado tampoco permite comprobar el estado de contenedores preexistentes.
No se eliminaron volúmenes. No se intentó reinstalar herramientas ni generar secretos
porque se estaba verificando el entorno existente. Sin SQL/migraciones ni D2.1-B.

Solución mínima: reintentar acceso al contexto local desde PowerShell con acceso normal
al motor Docker Desktop. El error actual demuestra denegación de acceso de esta sesión,
no que el motor esté detenido; no modificar ACLs/globales ni asumir que iniciar Docker
resuelve necesariamente la restricción de Codex. Si el PowerShell externo funciona y
Codex no, ejecutar allí las verificaciones y aportar sus salidas no sensibles.

Para herramientas ausentes, instalar las versiones exactas en .tools mediante los
comandos oficiales de la [guía local](local-postgresql.md), después comprobar `-version`
(Goose) y `version` (sqlc). La guía también tiene comandos directos si .ps1 está bloqueado;
no aplicar ExecutionPolicy Bypass ni evaluar scripts para eludir la política.
Preparar .env.local y secretos con el flujo local documentado, preservando archivos existentes.

Comprobación adicional pendiente, después de arrancar y verificar health en ese entorno:

```powershell
docker --context default compose -p tomopedidos-local --env-file .env.local -f compose.yaml exec -T postgres psql -X -v ON_ERROR_STOP=1 -U tomopedidos_bootstrap -d tomopedidos_local -c 'SELECT 1;'
# Al terminar las pruebas, incluso si alguna comprobación falla:
docker --context default compose -p tomopedidos-local --env-file .env.local -f compose.yaml stop postgres
docker --context default compose -p tomopedidos-local --env-file .env.local -f compose.yaml ps --all
```

Estos comandos son instrucciones pendientes, no ejecución acreditada. Cierre D2.1-A
requiere Engine accesible, Compose/start/health y SELECT 1 aprobados, binarios fijados
verificados desde PowerShell y parada confirmada sin eliminar volúmenes. Ninguna
verificación no realizada se marca como aprobada. Solo se actualizó este documento.

## D2.1-A — corrección automática de credenciales locales, 2026-10-13

Diagnóstico confirmado: .local/postgres/bootstrap-password.txt era un DIRECTORIO VACÍO,
no un archivo regular de 1 byte. Get-Item/lstat confirmó Directory y Get-ChildItem contó
0 entradas; ReadAllBytes devolvió Access denied por intentar leer un directorio como archivo.
ACL original heredada permitía Modify, sin evidencia de un deny explícito. La atribución
histórica a creación automática de bind source por Docker es probable, no demostrada:
no hay acceso Engine para inspeccionar montajes/logs históricos.

Defecto confirmado del script anterior: comprobaba solo Test-Path y preservaba cualquier
ruta existente, incluidas carpetas, sin validar archivo/contenido. Corregido mediante
inicializador Node ejecutable desde PowerShell sin cambiar ExecutionPolicy. Usa 32 bytes
criptográficos, Base64 sin BOM/newline, creación exclusiva y preservación de passwords.
Solo reemplaza placeholder directorio VACÍO, conservándolo como respaldo dentro de .local;
rechaza directorio no vacío, symlink, archivo inválido o ilegible sin regenerar contraseña.

Método: POSTGRES_PASSWORD_FILE permanece, con bind read-only y create_host_path:false;
se retiran Docker Secrets de Compose para controlar explícitamente archivo/montaje.
Imagen PostgreSQL 18.6 y digest, puerto 127.0.0.1:55432 y volumen de datos no cambiaron.
No trust. .env.local contiene configuración de ejemplo, no passwords. Secrets en .local.

| Verificación / comando ejecutado | Resultado real |
| --- | --- |
| Get-Item/Get-ChildItem/Get-Acl/ReadAllBytes | Directorio vacío confirmado; lectura como archivo denegada |
| node --version | v24.19.0 |
| node scripts/init-local-db.cjs | Exit 0; placeholder conservado, 3 archivos de 44 bytes y .env.local creados sin imprimir secretos |
| ACL de archivos de credenciales/configuración | Herencia desactivada, grants solo cuenta actual, owner del workspace, SYSTEM y Administradores; sin ACL global modificada |
| Segunda ejecución inicial del inicializador | Detectó fallo al reescribir ACL ya restringida; se detuvo sin cambiar passwords |
| Diagnóstico Set-Acl repetido | Error SeSecurityPrivilege; solucionado evitando cambios de ACL si ya cumple exactamente la política |
| node scripts/init-local-db.cjs después del ajuste | Exit 0; fingerprints comparados únicamente en memoria: los 3 passwords conservados |
| node --check scripts/init-local-db.cjs | Exit 0 |
| node --test scripts/init-local-db.test.cjs | 3 pruebas aprobadas: reparar carpeta vacía/idempotencia, preservar archivo inválido y preservar carpeta no vacía |
| Parser PowerShell local-db.ps1 | Sintaxis válida; archivo .ps1 no ejecutado por política Restricted |
| docker --context default compose -p tomopedidos-local --env-file .env.local -f compose.yaml config --quiet | Exit 0 |
| docker --context default version | Exit 1: permission denied al named pipe local; config Docker también Access denied |
| Test-Path ejecutables Goose/sqlc fijados | Ausentes |
| go install Goose v3.29.0 y sqlc v1.31.1, GOBIN local | Ambos fallan por socket HTTPS prohibido hacia proxy.golang.org; sin fallback ni cambio de toolchain |
| Revisión .gitignore | .env.*, .local/, .cache/ y .tools/ ignorados; .env.example exceptuado |

Las pruebas usan fixtures exclusivamente en .cache, sin datos de restaurantes ni DB.
No se registraron contraseñas ni fingerprints. No se sobrescribieron passwords válidos,
no se eliminaron respaldos, no se tocaron volúmenes ni contenedores de Celtas.

Error Engine: permission denied while trying to connect to the docker API at
npipe:////./pipe/docker_engine. Error instalación Go: connectex: An attempt was made to
access a socket in a way forbidden by its access permissions. No evidencia de error TLS.

No ejecutados por bloqueo Engine: up/pull, healthy, SELECT 1 y stop. No se iniciaron
servicios en este turno y no se puede certificar el estado de contenedores preexistentes.
No se ejecutaron migraciones, no se crearon roles/tablas ni se implementó D2.1-B.
D2.1-A sigue parcialmente verificado, no completado. La corrección de archivo/permisos
sí fue aplicada y probada; que Compose valide no demuestra que PostgreSQL funcione.
Procedimiento actualizado en docs/local-postgresql.md; ROADMAP no se marca completado.

Comprobación final: config JSON validó bind read-only/create_host_path:false, puerto localhost:55432 y ausencia de trust; bloques PowerShell de la guía con sintaxis válida y tres archivos locales legibles. Sin imprimir config ni secretos.

## D2.1-A — adopción de .env principal, 2026-10-13

Este registro sustituye el procedimiento operativo anterior basado en .env.local y
archivos de secretos. Las secciones anteriores conservan evidencia histórica, no
instrucciones actuales. La guía vigente es docs/local-postgresql.md.

Evidencia del usuario: `docker compose --env-file .env.local up -d --wait postgres`,
`Copy-Item .env.local .env` y `docker compose up -d --wait` finalizaron correctamente;
PostgreSQL 18.6, tomopedidos-local-postgres-1 healthy y 127.0.0.1:55432. No equivale a
una conexión TCP autenticada: el volumen se inicializó con otra fuente de credenciales.

Inspección actual: Compose ya estaba editado por el usuario para usar POSTGRES_DB,
POSTGRES_USER y POSTGRES_PASSWORD desde variables, sin secret/bind anterior. Se conservó
compose.yaml sin cambios. .env y .env.local presentes; inspección sin publicar valores.
La plantilla .env.example contenía una contraseña local: reemplazada por CHANGE_ME_LOCAL_ONLY.
No se cambió la contraseña interna de PostgreSQL ni el contenido de .env/.env.local.

Cambios: init-local-db.cjs solo crea/valida .env; generación criptográfica exclusivamente
si falta, sin crear .env.local ni .local. local-db.ps1 usa .env automáticamente, sin
--env-file ni fallback a plantilla, y Check usa TCP con PGPASSWORD desde variables del
contenedor reconciliado por Start/up. La ACL de .env existente se conserva; restricción
solo en archivos nuevos. Un intento inicial de reescribir ACL existente fue denegado,
sin modificar valores; se eliminó esa operación innecesaria para archivos existentes.
Los respaldos anteriores se preservan para posible recuperación de credenciales.

| Comando / verificación ejecutada | Resultado real |
| --- | --- |
| node --check scripts/init-local-db.cjs | Exit 0 |
| node --test scripts/init-local-db.test.cjs | 4 pruebas aprobadas: nueva configuración/idempotencia/sin archivos legacy; preservar .env/.env.local; rechazar marcador/ausencia; rechazar directorio |
| node scripts/init-local-db.cjs sobre configuración real | Exit 0; valores existentes conservados, hashes comparados en memoria sin imprimirlos |
| docker compose config --quiet | Exit 0, carga .env automáticamente |
| docker --context default version | Exit 1: permission denied al Engine npipe local; config Docker también Access denied |
| docker --context default compose -p tomopedidos-local ps | Exit 1 por mismo acceso denegado; no listado obtenido |
| Parser local-db.ps1 y bloques PowerShell de guía | Sintaxis válida; .ps1 no ejecutado por política Restricted |
| Binarios fijados .tools/goose/v3.29.0 y .tools/sqlc/v1.31.1 | Ausentes; no se puede acreditar versión ejecutada |
| Git check-ignore --no-index en fixture .cache con .gitignore raíz | .env, .env.local, .local/, .cache/ y .tools/ ignorados; .env.example no ignorado |
| Escaneo de credenciales en 91 archivos candidatos versionables | No halló valores actuales ni de los 3 secretos anteriores; valores no impresos |

No existe .git en la raíz: no se puede afirmar estado de staging ni historial; se
verificaron reglas efectivas en un repositorio desechable dentro del workspace y se
escaneó contenido candidato. La plantilla ya no contiene credenciales reales.

Bloqueo confirmado Engine: permission denied while trying to connect to the docker API
at npipe:////./pipe/docker_engine. No se realizaron up, healthy independiente, SELECT 1
ni stop en esta sesión. No se iniciaron ni detuvieron contenedores, incluidos Celtas.
La prueba TCP queda NO VERIFICADA, no se afirma que la contraseña coincida ni que falle.

Ante fallo de autenticación desde el entorno del usuario: conservar volumen, recuperar
privadamente la credencial anterior y alinear .env, o proponer rotación interna no
destructiva con autorización adicional. Ningún script altera la contraseña guardada.
Sin migraciones, tablas, cambios de volumen ni D2.1-B. D2.1-A permanece parcialmente
verificado hasta acreditar conexión TCP y herramientas fijadas.

## D2.1-A — herramientas pendientes y PostgreSQL confirmado por usuario, 2026-10-13

Evidencia externa confirmada por el usuario: Compose lee .env; PostgreSQL 18.6 healthy,
127.0.0.1:55432, base tomopedidos_local, usuario tomopedidos_bootstrap y SELECT 1 correcto
tras alinear la contraseña interna con .env. La rotación la realizó el usuario, no Codex;
no se registró su valor. La conexión ya no queda pendiente como requisito del usuario.
Codex no repitió SELECT 1 porque su Engine sigue inaccesible.

Versiones declaradas comprobadas: tools/versions.json fija Goose v3.29.0 y sqlc v1.31.1.
API mantiene go 1.26.0, Chi v5.2.3, pgx v5.7.6 y dependencias existentes; Go instalado
1.27.2. Sin cambios de versión ni de go.mod/go.sum, sin instalación global/toolchain nuevo.
No hay ejecutables Goose/sqlc en rutas .tools fijadas ni comandos disponibles en PATH.

| Ejecución propia de Codex | Resultado |
| --- | --- |
| go.exe version, ruta absoluta | go1.27.2 windows/amd64, exit 0 |
| scripts/db-tools.ps1 -Action Install | Exit 1; Restricted impide ejecutar .ps1 antes de entrar al script |
| go install github.com/pressly/goose/v3/cmd/goose@v3.29.0 | Exit 1 por socket HTTPS prohibido hacia proxy.golang.org |
| go install github.com/sqlc-dev/sqlc/cmd/sqlc@v1.31.1 | Exit 1 por la misma restricción |
| node --test scripts/init-local-db.test.cjs | 4 pruebas aprobadas, exit 0 |
| Parser PowerShell db-tools.ps1 y local-db.ps1 | Ambos válidos; no equivale a ejecución funcional de los wrappers |
| docker compose config --quiet | Exit 0; .env automático |
| docker --context default version | Cliente 29.8.1, exit 1 por acceso Engine denegado |

Los comandos directos se ejecutaron con GOTOOLCHAIN=local, GOENV=off, CGO_ENABLED=0,
GOBIN por herramienta/versión y caches del workspace, solo en el proceso de cada comando;
son la alternativa documentada del proyecto, sin evaluar .ps1 ni cambiar ExecutionPolicy.

Errores exactos de instalación:

```text
Get "https://proxy.golang.org/github.com/pressly/goose/v3/cmd/goose/@v/v3.29.0.info": dial tcp 172.217.192.141:443: connectex: An attempt was made to access a socket in a way forbidden by its access permissions.
Get "https://proxy.golang.org/github.com/sqlc-dev/sqlc/cmd/sqlc/@v/v1.31.1.info": dial tcp 172.217.192.141:443: connectex: An attempt was made to access a socket in a way forbidden by its access permissions.
permission denied while trying to connect to the docker API at npipe:////./pipe/docker_engine
```

Instalaciones completadas: NINGUNA. Versiones runtime de Goose/sqlc: NO VERIFICADAS;
las versiones declaradas no se presentan como ejecutadas. Sin mirrors, bypass TLS,
modificaciones globales, migraciones, cambios de password/volumen o D2.1-B.

D2.1-A permanece parcialmente verificada. Para cerrar falta exclusivamente instalar
ambos binarios locales fijados y acreditar goose -version / sqlc version desde PowerShell.
Bloqueos de Codex: política .ps1, socket de red y Engine; la evidencia PostgreSQL del
usuario se acepta diferenciada. No se exige repetirla como ejecución propia para cerrar.

Desde D:\tomopedidos, si la política del PowerShell del usuario permite scripts:

```powershell
.\scripts\db-tools.ps1 -Action Install
.\scripts\db-tools.ps1 -Action Versions
```

Verificación directa después de instalación:

```powershell
& .\.tools\goose\v3.29.0\goose.exe -version
& .\.tools\sqlc\v1.31.1\sqlc.exe version
```

Si .ps1 está bloqueado, la instalación directa sin cambios globales está en la sección
«Scripts opcionales y herramientas» de [guía local](local-postgresql.md).
No ejecutar Goose status/up ni generación sqlc con carpetas SQL vacías para cerrar este corte.

## Cierre D2.1-A — evidencia Docker del usuario, 2026-10-13

Estado: COMPLETADA para entorno/herramientas, sin completar Fase 1 ni autorizar D2.1-B.
Esta actualización reemplaza el requisito anterior de instalar binarios Windows:
Docker satisface el flujo aprobado, con versiones fijadas. No se reinstaló ninguna herramienta.

| Criterio | Evidencia y autor |
| --- | --- |
| Compose válido | Usuario confirmó; Codex repitió docker compose config --quiet, exit 0 |
| PostgreSQL local / healthcheck | Usuario confirmó PostgreSQL 18.6 healthy, 127.0.0.1:55432 |
| TCP autenticado / SELECT 1 | Usuario confirmó éxito tras alinear password interno con .env; Codex no realizó la rotación |
| Goose fijado y ejecutable | Usuario confirmó v3.29.0 ejecutado mediante Docker; docker/goose.Dockerfile fija ese módulo |
| sqlc fijado y ejecutable | Usuario confirmó v1.31.1 ejecutado mediante Docker; Compose usa sqlc/sqlc:1.31.1 |
| Plantilla/credenciales | .env principal ignorado; .env.example marcador; comprobaciones ignore/escaneo previas aprobadas, sin nuevos secretos |
| Procedimiento reproducible | Guía Docker actualizada; profiles tools y comandos versión sin dependencias, no instala Windows |
| Directorios SQL previstos | Backend migrations/schema/queries con .gitkeep; rutas reales inventariadas para preflight B |

Inspección Codex: tools/versions.json coincide; Dockerfile vigente docker/goose.Dockerfile
presente; Dockerfile/goose.Dockerfile de raíz ausentes. rg no halló referencias activas
a Dockerfile eliminado. Runtime/config/backend sin pools ni SQL funcional; router solo
GET /healthz. No se ejecutaron migraciones, builds de herramientas ni queries SQL.
Docker --context default version aún falla por permission denied al named pipe local:
Codex no confirma versiones Docker por ejecución propia, acepta evidencia identificada
como usuario. Pruebas anteriores de inicializador/ignore mantienen alcance ya registrado.

Hallazgos para D2.1-B, no garantías ya probadas: Goose monta root db/migrations en vez
de tomopedidos-api/db/migrations; sqlc requiere workdir/config del backend. Version -version/
version no prueba migraciones/generación. Corregir esos mounts y credencial migrador
antes de ejecutar SQL; por ahora ningún SQL funcional existe. Scripts nativos siguen
como alternativa y no impiden cierre Docker. Base images sqlc/build no tienen digest,
riesgo de reconstrucción a documentar, sin confundir pin de versión con igualdad binaria.

Propuesta D2.1-B en docs/architecture/d2-1-b-schema-design.md: esquema/roles/RLS y
pruebas por cortes; diseño solamente. No se crean archivos .sql ni roles/tablas ni se
modifica Compose/código/configuración de producción. Sin cambios de datos, volúmenes,
contraseña o Celtas; no deploy/push. Implementación y aplicación local necesitan aprobación.

Revisión documental de cierre por Codex: 72 enlaces locales comprobados en 11 documentos, 2 bloques PowerShell Docker con sintaxis válida, pins Docker coherentes y único Dockerfile Goose vigente confirmado. SQL backend sigue sin archivos .sql; no pruebas DB/RLS nuevas ni generación ejecutada.

## Preparación D2.1-B1 — 2026-10-13

Autorización vigente: corregir rutas y preparar SQL/verificaciones, SIN ejecutar SQL.
D2.1-A permanece completada; B1 preparado y pendiente de revisión/aplicación, no se
acreditan roles/grants efectivos. B2–B5 no implementados.

Archivos nuevos: bootstrap/001_roles.sql y 002_schema_privileges.sql; verification/
010_b1_metadata.sql y 020_b1_effective_privileges.sql bajo tomopedidos-api/db. Fuera de
Goose migrations y sqlc schema/queries. Bootstrap no contiene CREATE TABLE ni passwords.
Probes de infraestructura de 020 solo para aprobación posterior, con ROLLBACK y manejo
correcto de session_user para SET ROLE; ninguna prueba SQL se ejecutó ahora.

Compose corrigió Goose a backend/db/migrations -> /migrations read-only y sqlc a
backend -> /app, sqlc.yaml en working_dir /app. Driver/datasource Goose usa migrator,
DB_MIGRATION_PASSWORD separado y owner tp_owner explícito, no credencial bootstrap.
.env.example saneada a marcador y campo privado futuro; .env real no modificado.
El bloque completo postgres de Compose se comparó con baseline previo por hash en
memoria: idéntico (imagen/digest, puerto/volumen/configuración sin cambios).

| Comando / validación propia | Resultado |
| --- | --- |
| docker compose config --quiet | Exit 0 |
| docker compose --profile tools config --format json | Exit 0; consumido en memoria, sin imprimir ni guardar valores de configuración |
| Assertions de binds/workdirs/driver/role/context/puerto | Aprobadas, targets reales existentes y create_host_path:false |
| Comparación bloque postgres contra baseline anterior | Idéntico; solo servicios tools modificados |
| node --test scripts/init-local-db.test.cjs | 4 pruebas aprobadas, exit 0 |
| Revisión estática de 4 SQL preparados | Guard local/ON_ERROR_STOP presentes; bootstrap sin CREATE TABLE; verificaciones sin COMMIT |
| Revisión migrations/schema/queries | Siguen sin archivos .sql; no generación ni tablas funcionales |
| docker --context default version | Exit 1, permission denied al npipe; config Docker Access denied |

No ejecutados: psql, bootstrap, verificación SQL, Goose/sqlc contenedores, migraciones,
up/stop/restart. No se tocó PostgreSQL ni servicios/volúmenes Celtas. Sintaxis y efectos
SQL no certificados por parser PostgreSQL: revisión documental contra fuentes oficiales,
inspección estática solamente. Defaults y negativos requieren prueba real aprobada.
Se citó schema "authorization" porque es keyword reservada de PostgreSQL.
Provisión privada de passwords nuevos y pool auth adicional siguen pendientes; scripts
no crean auth_runtime, no cambian passwords existentes y rechazan colisiones de roles.
Comandos exactos pendientes y alcance de revocaciones: [B1](development-b1.md).

Revisión final B1: 42 enlaces locales válidos y sintaxis PowerShell de comandos futuros válida; escaneo de archivos versionables B1 sin valores actuales/anteriores de credenciales. Reglas ignore conservadas. Compose volvió a validar con exit 0. Ningún SQL fue ejecutado.

## Revisión de seguridad D2.1-B1 — 2026-10-13

Resultado estático: aprobado con observaciones tras correcciones; B1 no completado.
Se reforzaron defaults globales, PUBLIC, guards/membresías/ownership y probes negativos.
Goose build context ahora es docker; PostgreSQL conserva exactamente su bloque Compose.

| Validación propia | Resultado real |
| --- | --- |
| docker compose config --quiet | Exit 0; advertencia Access denied sobre configuración Docker del usuario |
| docker compose --profile tools config --format json | Exit 0; leído exclusivamente en memoria, sin revelar environment |
| Assertions Node de contexto/rutas/PGUSER/opciones owner y hash PostgreSQL | Aprobadas |
| Estructura de cuatro SQL: guards, pares de dollar quotes, rollback y ausencia de tablas bootstrap | Aprobada; no es validación con parser PostgreSQL |
| Cinco enlaces locales de development-b1 y escaneo de credenciales actuales en archivos B1 | Aprobados |

No se ejecutó SQL, psql, Goose, sqlc, ni conexión PostgreSQL. No se iniciaron/detuvieron
contenedores, no se modificaron bases, contraseñas ni volúmenes. No se verificaron efectos
SQL o autenticación real. Guards y probes deben ejecutarse solo tras aprobación específica.
Detalles y orden pendiente: [development-b1.md](development-b1.md). Roadmap sin cambios; B2–B5 fuera de alcance.

## Revisión final de compatibilidad documental B1 — 2026-10-13

Cuatro SQL contrastados con documentación oficial PostgreSQL 18: GRANT memberships,
SESSION AUTHORIZATION/ROLE/RESET/SET y rollback, DO invoker, EXCEPTION y defaults.
No se certifica compatibilidad real: no hubo parser ni ejecución PostgreSQL.

Cambio mínimo en 020: asserts de identidad migrator/owner y runtime, P0001 explícito
para éxito indebido y contador que exige 14 insufficient_privilege (42501).
001, 002 y 010 no cambiaron en esta revisión. Manual corrigió la distinción entre
session_user/current_user y añadió preflight de solo lectura y recuperación de fallo parcial.

Validaciones propias: cuatro bloques PowerShell parseados sin errores; assertions Node
de cuatro SQL, catorce negativos, estructura read-only del preflight y cinco enlaces
locales aprobadas. El primer checker rechazó por exceso de alcance el literal
'pg_authid'::regclass usado para identificar dependencias, sin consultar ese catálogo;
se corrigió el checker para detectar FROM/JOIN pg_authid y la repetición aprobó.
No se ejecutó ninguno de los comandos documentados ni SQL, psql, Goose o conexión DB.
No se modificaron Compose, base, roles, esquemas, tablas, passwords, volúmenes ni roadmap.

Pendientes: preflight real, aplicación aprobada y resultados efectivos de grants/defaults,
identidades, 14 SQLSTATE, rollback y autenticación TCP. B1 no completado; B2–B5 no iniciados.

## Intento de preflight B1 autorizado — 2026-10-13

Autorización exclusiva de preflight de lectura; aplicación B1 no autorizada.

| Comando propio | Resultado |
| --- | --- |
| docker context inspect default --format '{{.Endpoints.docker.Host}}' | Endpoint npipe:////./pipe/docker_engine; advertencia Access denied al config Docker del usuario |
| docker --context default compose -p tomopedidos-local ps postgres | Exit 1: permission denied while trying to connect to the docker API at npipe:////./pipe/docker_engine |
| docker --context default compose -p tomopedidos-local config --format json | Exit 0; consumido en memoria sin revelar environment |
| Assertions Node de destino configurado y bloque SQL documentado | Aprobadas: proyecto/base/login/puerto previstos; único bloque BEGIN READ ONLY...ROLLBACK con funciones built-in de metadatos |

Destino configurado: tomopedidos-local, tomopedidos_local, tomopedidos_bootstrap,
127.0.0.1:55432. Endpoint Docker local confirmado; contenedor y destino PostgreSQL
en ejecución no identificados porque Engine deniega acceso. No se intentó eludirlo.
No se ejecutó SQL, psql, consulta de puerto, bootstrap, probes, Goose ni migraciones.
Sin inventario real de objetos/ACL/membresías/consumidores; conflictos desconocidos.
Dictamen: preflight bloqueado, evidencia insuficiente para recomendar aplicar B1.
No implica una falla PostgreSQL ni requiere cambiar SQL sin resultados reales.
Sin cambios de contenedores, configuración, contraseñas, datos o volúmenes. Roadmap intacto.
El usuario debe ejecutar solo el preflight documentado desde PowerShell con acceso Docker
y compartir las salidas de metadatos, sin .env, environment completo ni contraseñas.

## Preflight B1 confirmado por el usuario y preparación de aplicación — 2026-10-13

Fuente: resultados comunicados por el usuario de su ejecución satisfactoria desde
PowerShell. No es ejecución propia de Codex ni se recibió aquí una salida completa.
Destino confirmado por el usuario: PostgreSQL 18.6, Compose tomopedidos-local,
base tomopedidos_local. Transacción de lectura terminó con ROLLBACK sin errores.

| Inventario aportado | Resultado |
| --- | --- |
| Roles B1 / memberships / dependencias | Inexistentes |
| Esquemas de usuario | Solo public, propietario pg_database_owner |
| Objetos dependientes en esquemas inspeccionados | Ninguno |
| Extensiones | Solo plpgsql |
| ACL de parámetros / defaults personalizados / settings por rol o base | Ninguno |

Los cuatro scripts vigentes se releen y corresponden a ese estado inicial: 001 crea
roles sin passwords; 002 crea schemas vacíos sin adoptar objetos, limita ACL y defaults;
010 verifica baseline; 020 crea probes dentro de transacción con ROLLBACK y 14 denegaciones.
No se requieren cambios SQL por el inventario aportado. No se afirman ACL efectivos
posteriores ni compatibilidad de aplicación probada.

No se aportaron aquí detalle de propietario/atributos de la base, ACL estándar completas
ni inventario de sesiones consumidoras. Confirmar bootstrap superusuario y propietario de
base no-template y ausencia de consumidores ajenos inmediatamente antes de aplicar;
los guards permanecen obligatorios. La ausencia de defaults personalizados no significa
ausencia de grants estándar a PUBLIC.

Dictamen: preparado para solicitar autorización explícita de 001; no autorizado ni aplicado.
Procedimiento por etapas y condiciones de parada: development-b1.md. B1 no completado.
En esta tarea Codex solo leyó archivos, actualizó documentación y validó estáticamente
los bloques PowerShell. No ejecutó Docker, SQL, Goose ni consultas PostgreSQL.
Sin cambios en cuatro SQL, Compose, contraseñas, bases, contenedores, volúmenes o roadmap.

## Autorización limitada a 001 — intento bloqueado — 2026-10-13

Usuario autoriza solo 001_roles.sql y consultas de lectura antes/después. Scripts vigentes
releídos; contenido de 001 corresponde a la revisión previa, sin modificarlo.
SHA256 vigente: 2EAA920E1DF044DDA6003FE347511F092347BBD26CEDB22EF0BB91F6CF83D5B2.

- Get-FileHash 001_roles.sql -Algorithm SHA256: huella obtenida.
- docker context inspect default --format '{{.Endpoints.docker.Host}}': npipe local
  npipe:////./pipe/docker_engine; advertencia Access denied al config Docker del usuario.
- docker --context default compose -f compose.yaml -p tomopedidos-local ps postgres:
  exit 1, permission denied while trying to connect to the docker API at ese npipe.

Se detuvo el intento ante el bloqueo, sin eludirlo. No se pudo confirmar desde Codex
identidad actual, superusuario/ownership o ausencia actual de conflictos en PostgreSQL.
No se ejecutó SQL, 001 ni ninguna verificación posterior. No hay exit 0/COMMIT de aplicación.
Comandos manuales con prechecks, huella, aplicación única y lecturas posteriores preparados
en development-b1.md; pendientes de ejecución por usuario. No se ejecutaron 002/010/020,
Goose, provisionamiento de passwords ni cambios sobre servicios/datos/volúmenes.
B1 sin completar; no se avanzó B2–B5. Ante errores reales, nueva revisión sin cleanup.

## 001 aplicado y verificado por el usuario; evaluación de 002 — 2026-10-13

Fuente: ejecución manual desde PowerShell comunicada por el usuario contra PostgreSQL
18.6 local. 001_roles.sql confirmó **COMMIT y exit 0**. Consultas posteriores confirmaron:

| Rol | Atributos verificados |
| --- | --- |
| tp_owner | NOLOGIN, NOINHERIT, NOSUPERUSER, NOCREATEDB, NOCREATEROLE, NOREPLICATION, NOBYPASSRLS |
| tomopedidos_migrator | LOGIN, NOINHERIT, NOSUPERUSER, NOCREATEDB, NOCREATEROLE, NOREPLICATION, NOBYPASSRLS |
| tomopedidos_runtime | LOGIN, NOINHERIT, NOSUPERUSER, NOCREATEDB, NOCREATEROLE, NOREPLICATION, NOBYPASSRLS |

Única membresía informada: tomopedidos_migrator → tp_owner, ADMIN FALSE,
INHERIT FALSE, SET TRUE. **001 aplicado y verificado; B1 no completado**.
Esta evidencia sustituye el estado pendiente del intento anterior; no es ejecución de
Codex ni se recibió aquí salida completa. No implica passwords provisionados ni prueba TCP.
Huella del archivo 001 conservado en esta revisión:
`2EAA920E1DF044DDA6003FE347511F092347BBD26CEDB22EF0BB91F6CF83D5B2`.

Implementación documental: estado actualizado; [dictamen de 002](review-002.md) y
[consultas previas de lectura](../tomopedidos-api/db/verification/preflight_002_readonly.sql)
preparados. Decisión aprobada: cierre de 001 basado en resultados aportados.
Propuesta: evaluar consumidores y ACL actuales antes de solicitar autorización de 002.
Verificación pendiente: ejecutar/revisar preflight; consumidores desconectados; 002,
010/020 y autenticación TCP. Sin SQL ejecutado por Codex en esta tarea, ni cambios de
bootstrap, credenciales, esquemas, tablas, Celtas, deploy, push o avance B2–B5.

## Incidente 010: SQLSTATE 42702 y corrección estática — 2026-10-13

Evidencia aportada por el usuario: 001 aplicado y verificación de roles aprobada;
002_schema_privileges.sql confirmó COMMIT y exit 0 en PostgreSQL 18.6 local.
010 falló con SQLSTATE 42702: `column reference "r.oid" is ambiguous`, en el IF
que comprueba memberships de runtime, inline_code_block línea 24. No se recibió salida
completa ni se ejecutó SQL desde Codex. COMMIT de 002 no equivale a metadata aprobada.

Causa raíz: la variable PL/pgSQL `r record` utilizada por los FOR comparte nombre con
el alias SQL `pg_roles r`. En `JOIN pg_roles r ON r.oid=m.member`, `r.oid` puede ser
el campo del record o la columna del alias. El record proviene previamente de pg_roles
y contiene oid. El patrón también aparecía en el IF de delegación del migrador y en
las consultas de dependencias/ownership, aunque la primera excepción impidió alcanzarlas.

Implementación: únicamente renombres de variables en 010 y sus usos:
`r → v_row`, `name → v_name`, `expected_owner → v_expected_owner`.
Los alias SQL r/m/member/granted/d/p/a/n permanecen; ninguno coincide con las variables
declaradas. No se cambia variable_conflict ni se suprime el error mediante configuración.
No hay cambios de predicados, mensajes, privilegios, destinatarios ni condiciones de fallo.

Validaciones estáticas realizadas:

- Archivo completo inspeccionado: declaraciones, FOR/FOREACH, SELECT INTO STRICT,
  columnas sin calificar, alias y referencias de record. Sin otro conflicto identificado.
- Comparación del contenido anterior y posterior invirtiendo solo los tres renombres:
  idéntico al normalizar finales de línea. Se conservan las 18 instrucciones RAISE EXCEPTION,
  ON_ERROR_STOP, BEGIN READ ONLY, search_path pg_catalog, salida de éxito y ROLLBACK.
- 020 revisado completo: sus únicas variables, statement y denied_count, no comparten
  nombre con alias/columnas de sus consultas. EXECUTE statement usa la variable PL/pgSQL;
  el SQL dinámico no interpola identificadores de variables. Sin cambios; conserva
  14 denegaciones, captura exclusiva insufficient_privilege y controles de limpieza.
- SHA256 de 001 y 002 idénticos a la revisión anterior; 020 idéntico antes/después:
  `A78A76800290D2D644EBFBFD8C7453834C2D5B87208AF12574B9AB8EF4A80FD8`.
- Bloque PowerShell siguiente analizado con System.Management.Automation.Language.Parser,
  sin ejecutarlo. Sin errores de sintaxis. No se certificó parsing SQL/PLpgSQL en PostgreSQL.

Nueva huella SHA256 de 010:
`221FCCC631324B164658B2478AE0A9441D07898DE976A492313C1E4A89216516`.

Propuesta para repetición manual exclusiva de 010. Usar una conexión nueva; la conexión
batch anterior cerrada revierte su transacción de lectura abortada. Si quedó abierta una
sesión interactiva del intento, salir de ella antes de repetir. No ejecutar 001/002/020.

```powershell
Set-Location D:\tomopedidos
$dc010 = @('--context','default','compose','-f','compose.yaml','-p','tomopedidos-local')
$endpoint010 = docker context inspect default --format '{{.Endpoints.docker.Host}}'
if ($LASTEXITCODE -ne 0 -or $endpoint010.Trim() -ne 'npipe:////./pipe/docker_engine') {
    throw 'Contexto local no confirmado; detener'
}
docker @dc010 ps postgres
if ($LASTEXITCODE -ne 0) { throw 'Engine no disponible; detener' }
$port010 = docker @dc010 port postgres 5432
if ($LASTEXITCODE -ne 0 -or $port010.Trim() -ne '127.0.0.1:55432') {
    throw 'Puerto inesperado; detener'
}
$file010 = 'D:\tomopedidos\tomopedidos-api\db\verification\010_b1_metadata.sql'
$hash010 = '221FCCC631324B164658B2478AE0A9441D07898DE976A492313C1E4A89216516'
$bytes010 = [IO.File]::ReadAllBytes($file010)
$sha010 = [Security.Cryptography.SHA256]::Create()
try { $actual010 = [BitConverter]::ToString($sha010.ComputeHash($bytes010)).Replace('-','') }
finally { $sha010.Dispose() }
if ($actual010 -ne $hash010) { throw '010 distinto del revisado; detener' }
$sql010 = [Text.Encoding]::UTF8.GetString($bytes010)
$output010 = $sql010 | docker @dc010 exec -T postgres psql -X -v ON_ERROR_STOP=1 `
    -U tomopedidos_bootstrap -d tomopedidos_local -f -
$exit010 = $LASTEXITCODE
$output010
if ($exit010 -ne 0 -or -not ($output010 -match 'B1 metadata checks passed') `
    -or -not ($output010 -match '^ROLLBACK$')) {
    throw '010 no aprobado; detener y conservar error/SQLSTATE'
}
Write-Output '010: exit 0, resultado de éxito y ROLLBACK confirmados; detener aquí'
```

Pendiente: ejecución satisfactoria de este 010 corregido por el usuario en PostgreSQL
18.6. **010 no aprobado; B1 no completado**. 020, Goose y B2–B5 no ejecutados.
No se modificaron bootstrap, roles, permisos, esquemas, datos, credenciales ni Celtas.

## Diagnóstico Docker y lecturas B1 ejecutadas por Codex — 2026-10-13

Evidencia manual nueva aportada por el usuario: 010 corregido ejecutado satisfactoriamente
en PostgreSQL 18.6 con `B1 metadata checks passed`, ROLLBACK y exit 0. **010 aprobado según
esa ejecución manual**; no se repitió desde Codex. 001/002 permanecen aplicados.

### Diagnóstico ejecutado

| Comprobación | Resultado |
| --- | --- |
| Workspace/shell | D:\tomopedidos; Windows PowerShell 5.1.26100.9444 |
| Identidad dentro del sandbox | DESKTOP-LOQ761F\CodexSandboxOffline |
| Docker CLI | Ejecutable localizado en instalación DockerDesktop de erazof; 29.8.1, build 4a63305 |
| Docker Compose | v5.5.1 |
| Contexto implícito dentro del sandbox | default, con advertencia de config.json inaccesible; no prueba que sea el contexto guardado del usuario |
| Context inspect default | Endpoint npipe:////./pipe/docker_engine; metadata accesible pese a la advertencia |
| compose ps postgres dentro del sandbox | exit 1, permission denied al conectar al named pipe; advertencias Access denied en C:\Users\erazof\.docker\config.json |
| Mismo compose ps postgres fuera del sandbox con aprobación puntual | exit 0; tomopedidos-local-postgres-1, servicio postgres, Up/healthy, postgres:18.6-bookworm fijado por digest, 127.0.0.1:55432→5432 |
| Identidad fuera del sandbox | DESKTOP-LOQ761F\erazof |
| Contexto implícito fuera del sandbox | desktop-linux; todas las operaciones de proyecto usaron --context default |
| compose ps y port postgres 5432 fuera del sandbox | Solo postgres listado, healthy; puerto 127.0.0.1:55432; exit 0 |

Comando principal repetido tras aprobación de excepción puntual:
`docker --context default compose -f compose.yaml -p tomopedidos-local ps postgres`.
Se solicitaron dos excepciones: primero inspección de estado; después inspecciones y
consultas SELECT concretas de catálogos. Ambas devolvieron ejecución satisfactoria.
No se solicitó prefijo persistente. No se leyó ni mostró contenido de Docker config,
secretos o environment de contenedores. La consulta de variables Docker seleccionadas
no produjo entradas; su ausencia no implica permisos de acceso al Engine.

Dictamen de acceso: **sí, operativo fuera del sandbox con aprobación puntual; no dentro
del sandbox actual**. CLI instalada/funcional; config.json y pipe tienen denegaciones
distintas. La diferencia de identidad y el éxito fuera del sandbox apuntan a restricciones
del usuario/token/perfil de sandbox, no a Engine detenido ni Compose ausente. No se
inspeccionaron ACL para atribuir una entrada concreta ni se cambiaron permisos Windows.
Leer metadata del contexto no acredita acceso al Engine. El error de config.json por
sí solo tampoco demuestra la causa del pipe; el fallo de conexión se comprobó por separado.

### Lecturas PostgreSQL ejecutadas

Tras aprobación puntual, psql -X -v ON_ERROR_STOP=1, conexión nueva bootstrap/local,
BEGIN READ ONLY, search_path pg_catalog, SELECT de catálogos y ROLLBACK. Exit 0.
No se invocó ningún archivo SQL 001/002/010/020 ni Goose.

| Lectura | Resultado propio de Codex |
| --- | --- |
| Versión/base/session_user/current_user | 18.6 (Debian 18.6-1.pgdg12+2); tomopedidos_local; ambos usuarios tomopedidos_bootstrap |
| Tres roles | tp_owner NOLOGIN; migrator/runtime LOGIN; todos NOINHERIT y sin superuser/createdb/createrole/replication/bypassrls |
| Membresías que involucran roles B1 | Única fila migrator→tp_owner; ADMIN FALSE, INHERIT FALSE, SET TRUE |
| Cinco schemas | identity, tenancy, authorization, audit, migration_meta; todos owner tp_owner |
| ACL de cinco schemas | tp_owner USAGE/CREATE; runtime USAGE solo tenancy/authorization; sin PUBLIC ni migrator |
| public | Owner pg_database_owner; ACL solo pg_database_owner USAGE/CREATE |
| Privilegios efectivos DB de ambos logins | CONNECT TRUE, CREATE FALSE, TEMP FALSE |
| Owner/ACL de base | tomopedidos_bootstrap; owner CREATE/TEMP/CONNECT; ambos logins CONNECT; sin PUBLIC |
| Defaults tp_owner | Una fila global de funciones, solo tp_owner EXECUTE; sin filas de defaults de tablas/secuencias |

Estas lecturas respaldan el baseline inspeccionado; no sustituyen pruebas de denegaciones
020 ni autenticación TCP de roles. No verifican RLS ni aislamiento tenant.
Huellas de 001/002/010/020 verificadas por lectura de archivos, iguales a las registradas
anteriormente. Ninguno de esos cuatro scripts fue modificado en esta tarea.

### Propuesta y pendientes

[Procedimiento de automatización futura](verification-automation.md): mantener sandbox,
aprobaciones puntuales para SELECT revisados y reglas muy acotadas para inspecciones si
se autorizan después. La documentación oficial de
[sandbox Windows](https://learn.chatgpt.com/docs/windows/windows-sandbox) describe usuarios
de menor privilegio en el modo legacy elevated, y las
[reglas de Codex](https://learn.chatgpt.com/docs/agent-configuration/rules) permiten excepciones
de comandos fuera del sandbox. Configuración efectiva no modificada; no se garantiza
que cambiar de implementación otorgue acceso Docker. No habilitar Full Access ni permitir
prefijos docker/exec/psql generales para automatizar lecturas.

Pendientes: aprobación e instalación de cualquier regla/configuración futura; tests
futuros seleccionados (no ejecutados hoy); 020 no autorizado; autenticación TCP pendiente.
B1 no completado; B2–B5 no iniciados. No cambios de base, roles, permisos, schemas, datos,
credenciales, Docker Engine, contenedores, volúmenes, ACL/grupos Windows, Celtas, deploy o push.

## D2.1-B1 — ejecución autorizada de 020 detenida en preflight — 2026-10-13

Autorización del usuario: ejecutar exclusivamente 020, consultas de lectura previas y
posteriores, repetición final de 010 sin cambios y registro de evidencia. No autoriza
repetir 001/002, provisionar credenciales, ejecutar Goose ni avanzar a B2–B5.

### Revisión ejecutada y aprobada

Leídos PROJECT_CONTEXT.md, AGENTS.md raíz/API, development-b1.md y ambos scripts
completos. Las huellas vigentes coinciden con las previamente registradas:

| Script | SHA256 |
| --- | --- |
| 010_b1_metadata.sql | 221FCCC631324B164658B2478AE0A9441D07898DE976A492313C1E4A89216516 |
| 020_b1_effective_privileges.sql | A78A76800290D2D644EBFBFD8C7453834C2D5B87208AF12574B9AB8EF4A80FD8 |

020 conserva BEGIN, ON_ERROR_STOP, guard de destino/superusuario/colisiones,
impersonación migrator/owner y runtime, 14 pruebas negativas y ROLLBACK.
Cada negativo captura exclusivamente insufficient_privilege (SQLSTATE 42501);
un éxito indebido lanza P0001 y cualquier otro error interrumpe la ejecución.
El contador exige exactamente 14 denegaciones. Las operaciones de prueba están
contenidas en la transacción: tabla, fila, secuencia y función SQL SELECT 1 nuevas,
sin triggers ni funciones externas añadidas por el script. No contiene COMMIT ni
operaciones persistentes fuera de esa transacción; después del ROLLBACK solo lee
catálogos y comprueba restauración de identidad y limpieza. No se modificó el SQL.
Esta revisión estática no sustituye la ejecución ni inspección del entorno real.
010 conserva BEGIN READ ONLY, controles de metadata, mensaje de éxito y ROLLBACK.

### Comandos ejecutados y bloqueo

Entorno: D:\tomopedidos, PowerShell de Codex, contexto explícito default,
Compose D:\tomopedidos\compose.yaml, proyecto explícito tomopedidos-local.

1. Lecturas locales de instrucciones/documentación/scripts: exit 0.
2. `Get-FileHash tomopedidos-api/db/verification/010_b1_metadata.sql,tomopedidos-api/db/verification/020_b1_effective_privileges.sql -Algorithm SHA256`: huellas obtenidas satisfactoriamente.
3. `docker --context default compose -f D:\tomopedidos\compose.yaml -p tomopedidos-local ps postgres`: exit 1. La llamada PowerShell que agrupó huellas y este comando terminó con exit 1 por Docker.

Salida completa del comando Docker:

```text
WARNING: Error loading config file: open C:\Users\erazof\.docker\config.json: Access is denied.
WARNING: Error loading config file: open C:\Users\erazof\.docker\config.json: Access is denied.
permission denied while trying to connect to the docker API at npipe:////./pipe/docker_engine
```

Las reglas allow declaradas en la sesión incluyen el comando Compose ps utilizado,
pero esta invocación no obtuvo acceso real al Engine. No hubo solicitud de aprobación
individual. El éxito de los tres comandos Docker en el turno anterior es evidencia
histórica; no acredita acceso en esta invocación. No se identifica aquí la causa de
la diferencia ni se atribuye la denegación a una regla concreta.

### Pruebas pendientes y estado

Preflight real incompleto: no se pudo confirmar salud, puerto publicado exacto,
identidad/base/versión desde PostgreSQL ni inventario actual de tres roles y cinco
schemas. Se detuvo ante el primer fallo Docker, sin reintento ni elevación.
No se ejecutaron consultas PostgreSQL, 020 ni repetición de 010.

- 020: no ejecutado; no es un fallo de pruebas SQL. Positivas ejecutadas: 0; negativas ejecutadas: 0 de 14 previstas.
- SQLSTATE 42501: captura conservada en el script; sin evidencia dinámica nueva.
- ROLLBACK y ausencia de residuos: no verificados en esta tarea; no se crearon objetos de prueba.
- Ownership, membresías, atributos y privilegios posteriores: no verificados en esta tarea.
- 010: aprobación manual previa conservada; repetición por Codex pendiente.
- D2.1-B1: parcial, no completado. Autenticación TCP y provisión privada de credenciales permanecen pendientes según development-b1.md; B2–B5 no iniciados.

Implementación: únicamente este registro documental. Decisión aprobada: alcance de
020 y lecturas especificado por el usuario. Propuesta: resolver el acceso efectivo
de esta sesión a Docker y retomar desde el preflight completo, conservando los scripts.
No se cambiaron roles, ACL, schemas, datos, Compose, contenedores, imágenes, volúmenes,
credenciales ni sistemas de Celtas; sin migraciones, deploy o push.

## D2.1-B1 — nuevo preflight de 020 detenido por advertencia de acceso — 2026-10-13

Alcance aprobado: 020 sin modificaciones, preflight y consultas posteriores de lectura,
010 final y evidencia. Leídos AGENTS raíz/API, PROJECT_CONTEXT y scripts completos.
No se ejecutó SQL. Cada comando Docker se ejecutó en llamada independiente.

Revisión estática aprobada: 020 conserva BEGIN, ON_ERROR_STOP, 14 negativos con captura
exclusiva insufficient_privilege (42501), P0001 ante éxito indebido, contador exacto,
ROLLBACK y controles posteriores de identidad/limpieza. Las operaciones sobre objetos
nuevos están dentro de la transacción; no hay COMMIT ni efectos externos en el script.
Después del ROLLBACK solo hay comprobaciones de catálogos y SELECT de resultado.
010 conserva BEGIN READ ONLY y ROLLBACK. Ningún script fue modificado.

SHA256:
- 020: A78A76800290D2D644EBFBFD8C7453834C2D5B87208AF12574B9AB8EF4A80FD8.
- 010: 221FCCC631324B164658B2478AE0A9441D07898DE976A492313C1E4A89216516.

| Comprobación ejecutada | Exit | Resultado |
| --- | --- | --- |
| Lecturas locales y Get-FileHash de 020/010 | 0 | Huellas coincidentes con las aprobadas |
| `docker --context default ps` | 0 | Engine accesible; tomopedidos-local-postgres-1 Up 3 hours (healthy), 127.0.0.1:55432->5432/tcp |
| `docker context inspect default --format '{{.Endpoints.docker.Host}}'` | 0 | Endpoint local, pero advertencia Access is denied sobre config.json |

Salida completa de inspección de contexto:

```text
WARNING: Error loading config file: open C:\Users\erazof\.docker\config.json: Access is denied.
npipe:////./pipe/docker_engine
```

Se detuvo ante la advertencia de permisos, conforme a la condición de parada del
preflight y AGENTS. Exit 0 no elimina la denegación de configuración. No hubo fallo
del Engine en ps; context inspect no consulta Engine. No se solicitó aprobación,
elevación ni reintento. La diferencia de acceso entre llamadas permanece sin explicar.

Preflight incompleto: Compose ps, consulta exacta de puerto y confirmación PostgreSQL
de base/usuario/versión no ejecutadas. Estado healthy/puerto observado solo mediante ps.
020 no ejecutado: 0 positivas y 0 de 14 negativas; 42501 solo inspeccionado estáticamente.
ROLLBACK, residuos y metadata posterior no verificados dinámicamente en esta tarea.
010 no repetido; aprobación manual previa conservada. B1 sigue parcial; autenticación
TCP pendiente. B2–B5 no iniciados. Próximo paso propuesto: resolver la inconsistencia
de acceso de contexto y retomar preflight completo; no repetir 001/002.

Implementación: únicamente este registro. Sin cambios en SQL, roles, privilegios,
PostgreSQL, credenciales, Docker, Windows, Celtas; sin Goose, deploy ni push.

## Docker CLI — advertencia no bloqueante e identidad — 2026-10-13

Leídos AGENTS raíz/API. Inspección de lectura del proceso PowerShell: exit 0;
identidad DESKTOP-LOQ761F\CodexSandboxOffline, Windows PowerShell 5.1.26100.9444,
ejecutable C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe.
DOCKER_CONFIG, DOCKER_CONTEXT y DOCKER_HOST ausentes en ese proceso. No se mostraron
secretos ni contenido de config.json. Esta identidad corresponde a la inspección;
no se puede atribuir automáticamente a procesos Docker lanzados en otras llamadas.

Cada Docker se ejecutó en llamada independiente, modo predeterminado, sin solicitud
de elevación ni aprobación. La herramienta no informó identidad/token efectivos ni
si una regla allow cambió el entorno de ejecución de cada comando Docker.

| Comando | Exit | Salida estándar relevante | Advertencias | Error bloqueante |
| --- | --- | --- | --- | --- |
| `docker --context default ps` | 0 | Dos contenedores activos; postgres local healthy | Ninguna observada | Ninguno |
| `docker --context default compose -f D:\tomopedidos\compose.yaml -p tomopedidos-local ps postgres` | 0 | tomopedidos-local-postgres-1, postgres:18.6-bookworm, Up 3 hours (healthy), 127.0.0.1:55432->5432/tcp | Ninguna observada | Ninguno |

exec_command entrega salida agregada; clasificación por contenido, no captura separada
física de stdout/stderr. Engine y Compose accesibles en estas invocaciones.
La advertencia previa de context inspect (exit 0 y endpoint local devuelto) fue no
bloqueante para esa operación. No acredita Engine inaccesible. Las operaciones locales
actuales no mostraron la advertencia ni fallaron; no se demuestra config.json legible
ni corrección permanente. No se repitió context inspect: no estaba en la lista permitida.

Corrección propuesta, no aplicada: revisar primero las identidades y el encaminamiento
por reglas de cada ejecución. Si se confirma que la CLI usa un perfil Docker ajeno al
usuario efectivo, alinear su configuración con un perfil propio autorizado y legible,
sin copiar credenciales ni ampliar ACL del perfil de erazof. Requiere evaluación y
autorización separadas; no se cambiaron permisos, variables, configuración ni reglas.
La dependencia del proceso/token es hipótesis compatible con la evidencia, no causa
confirmada. No hubo SQL, cambios PostgreSQL, Docker Desktop, Celtas, deploy ni push.
Solo se añadió este registro documental. 020 sigue pendiente, B1 parcial.

## D2.1-B1 — preflight 020 detenido en consulta de puerto — 2026-10-13

Autorizado: 020, preflight, limpieza de lectura, 010 final y evidencia. Leídos AGENTS
raíz/API, PROJECT_CONTEXT y 020 vigente. Revisión estática: BEGIN, ON_ERROR_STOP,
14 negativos con captura exclusiva insufficient_privilege (42501), contador exacto,
P0001 ante éxito indebido, ROLLBACK y controles posteriores de identidad/limpieza intactos.
Las operaciones de prueba sobre objetos nuevos son transaccionales; sin COMMIT ni
funciones externas añadidas. Ningún script modificado.

SHA256 obtenido (lecturas/huellas exit 0):
- 020: A78A76800290D2D644EBFBFD8C7453834C2D5B87208AF12574B9AB8EF4A80FD8.
- 010: 221FCCC631324B164658B2478AE0A9441D07898DE976A492313C1E4A89216516.

Cada comando Docker se ejecutó en una llamada independiente a exec_command:

| Comando | Exit | Resultado |
| --- | --- | --- |
| `docker --context default ps` | 0 | Engine accesible; postgres local healthy, puerto observado 127.0.0.1:55432->5432; sin advertencias |
| `docker --context default compose -f D:\tomopedidos\compose.yaml -p tomopedidos-local ps postgres` | 0 | Proyecto/servicio local identificado; healthy, imagen postgres:18.6-bookworm por digest; sin advertencias |
| `docker --context default compose -f D:\tomopedidos\compose.yaml -p tomopedidos-local port postgres 5432` | 1 | Advertencias de config.json y denegación real al Engine |

Salida completa del comando fallido:

```text
WARNING: Error loading config file: open C:\Users\erazof\.docker\config.json: Access is denied.
WARNING: Error loading config file: open C:\Users\erazof\.docker\config.json: Access is denied.
permission denied while trying to connect to the docker API at npipe:////./pipe/docker_engine
```

Los comandos ps acreditan acceso efectivo en sus invocaciones. La consulta port no
completó la operación: este fallo sí incluye denegación al Engine, además de advertencias
secundarias. No se generaliza el fallo a todos los comandos ni se afirma causa confirmada.
Sin aprobación individual, elevación ni reintento. Detenido antes de SQL.

Preflight incompleto: puerto exacto observado en ps, pero comprobación port fallida;
identidad/base/versión dentro de PostgreSQL no confirmadas en esta tarea.
020 no ejecutado: 0 positivas, 0 de 14 negativas. SQLSTATE 42501 y ROLLBACK solo
inspeccionados estáticamente; sin evidencia dinámica nueva. No se crearon probes.
Ausencia de residuos y baseline posterior no comprobados; 010 no repetido, conserva
aprobación manual previa. B1 parcial; autenticación TCP pendiente; B2–B5 no iniciados.

Implementación: únicamente este registro. Propuesta: diagnosticar por qué las reglas
permiten ps pero port pierde acceso, y retomar preflight completo una vez resuelto.
Sin cambios de scripts, roles, privilegios, credenciales, PostgreSQL, Docker, Windows,
Celtas; sin 001/002, Goose, deploy ni push.

## Diagnóstico de reglas Docker y perfil Windows — 2026-10-13

Sin SQL ni cambios de configuración. Leídos AGENTS raíz/API y habilidad openai-docs;
contrastadas https://learn.chatgpt.com/docs/agent-configuration/rules y
https://learn.chatgpt.com/docs/windows/windows-sandbox.

Inspecciones de lectura: procesos PID 5384 y 13768, ambos
DESKTOP-LOQ761F\CodexSandboxOffline; USERPROFILE C:\Users\erazof,
HOMEDRIVE C:, HOMEPATH \Users\erazof; DOCKER_CONFIG/CONTEXT/HOST ausentes.
Segundo proceso: CodexSandboxUsers, Usuarios, integridad media, sin Administradores
habilitado en salida whoami /groups. config.toml muestra windows.sandbox=elevated:
esto es implementación de sandbox, no prueba de privilegios administrativos del comando.
La primera inspección terminó exit 1 por rg sobre D:\tomopedidos\.codex inexistente;
la segunda exit 0. No se expusieron secretos ni configuraciones completas.

Archivo leído: C:\Users\erazof\.codex\rules\docker-safe.rules. Tiene allow para
Docker --context default ps y el Compose ps postgres exacto con -f y -p.
No contiene allow para Compose port con esos argumentos ni context inspect.
Las reglas Compose de comandos directos no coinciden cuando -f/-p preceden al verbo.
La lista de prefijos autorizados expuesta por esta sesión presenta la misma diferencia.
Política efectiva de sesión: granular, sandbox_approval/rules deshabilitados.
No se comprobó exhaustivamente cada capa gestionada ni log de decisión del ejecutor.

Pruebas Docker nuevas, cada una independiente, sin solicitud de aprobación:
- docker --context default ps: exit 0; dos contenedores activos, sin advertencias.
- docker --context default compose -f D:\tomopedidos\compose.yaml -p tomopedidos-local ps postgres: exit 0; postgres:18.6-bookworm por digest, healthy, 127.0.0.1:55432->5432; sin advertencias.
No se repitió port fallido ni se ejecutó context inspect. Identidad/perfil del proceso
Docker no informados por exec_command: no se asigna el token de otra llamada a estas.

Demostrado: procesos de inspección distintos con mismo usuario/perfil heredado;
reglas de distinta cobertura; Engine/Compose operativos para ps. La ruta config.json
coincide con el perfil heredado aunque la identidad sea sandbox. Advertencia de archivo
y error de named pipe son recursos distintos; arreglar uno no garantiza arreglar otro.
Documentación oficial: allow dirige comandos fuera del sandbox sin preguntar; no
modifica permisos del sistema. El legacy elevated usa cuentas de sandbox restringidas.
Hipótesis fuerte: encaminamiento diferente por coincidencia de prefijos, no azar del
Engine. Falta traza del ejecutor/token por comando para certificar causalidad completa.

Propuesta pendiente de aprobación: añadir únicamente una regla exacta persistente para
Docker --context default compose -f D:\tomopedidos\compose.yaml -p tomopedidos-local
port postgres 5432, revisar su match con el evaluador oficial y comprobar en sesión nueva.
Si se requiere context inspect, regla separada exacta. Mantener sandbox global y ACL;
no allow general docker/exec/psql. Excepciones salen del sandbox para esos comandos,
por tanto requieren aprobación expresa. Si toda ejecución debe permanecer dentro del
sandbox, esta propuesta no satisface ese requisito: investigar alternativa oficialmente
soportada, sin prometer acceso al pipe. No aplicado. No copiar credenciales ni cambiar
DOCKER_CONFIG como solución al pipe. 020 pendiente, B1 parcial.
## D2.1-B1 — preflight 020 detenido por acceso a configuración Docker — 2026-10-14

Autorización vigente del usuario: ejecutar 020 sin cambios, preflight obligatorio,
lecturas posteriores, repetición final de 010 y registro de evidencia. No autoriza
001/002, Goose, credenciales, autenticación TCP, B2–B5 ni cambios de reglas o permisos.

Leídos AGENTS.md raíz/API, PROJECT_CONTEXT.md, registro de verificación reciente
y archivos completos 020/010. Lecturas locales y Get-FileHash: exit 0.

SHA256 vigente:
- 020_b1_effective_privileges.sql: A78A76800290D2D644EBFBFD8C7453834C2D5B87208AF12574B9AB8EF4A80FD8.
- 010_b1_metadata.sql: 221FCCC631324B164658B2478AE0A9441D07898DE976A492313C1E4A89216516.

Revisión estática de 020: conserva ON_ERROR_STOP, BEGIN, guard de base/bootstrap
superusuario/colisiones, impersonación migrator/owner y runtime, creación de tabla,
fila, secuencia y función dentro de la transacción y 14 pruebas negativas.
Captura exclusivamente insufficient_privilege (SQLSTATE 42501), exige contador 14
y genera P0001 ante éxito inesperado. No contiene COMMIT. ROLLBACK precede a
comprobaciones de identidad/limpieza y al mensaje final; después solo hay lecturas.
010 conserva BEGIN READ ONLY, aserciones de metadata, mensaje final y ROLLBACK.
Ningún archivo SQL fue modificado. Esto no constituye evidencia dinámica.

Única invocación Docker, en llamada independiente a exec_command:

```powershell
docker --context default context inspect default --format '{{.Endpoints.docker.Host}}'
```

Código de salida: 0. Salida completa:

```text
WARNING: Error loading config file: open C:\Users\erazof\.docker\config.json: Access is denied.
npipe:////./pipe/docker_engine
```

El endpoint devuelto corresponde al contexto local default. La advertencia acredita
denegación de lectura de configuración; no demuestra fallo del Engine, que esta
invocación no consulta. Se detuvo conforme a AGENTS.md y al requisito de parar ante
fallos del preflight. No hubo solicitud de aprobación individual, reintento,
elevación ni acceso alternativo.

Preflight incompleto: no ejecutados Compose ps/port ni consultas de base, usuario
y versión. Salud de postgres y puerto 127.0.0.1:55432 no verificados hoy; tampoco
tomopedidos_local, tomopedidos_bootstrap o PostgreSQL 18.6 desde el servidor.

020 no ejecutado: positivas ejecutadas 0, negativas ejecutadas 0/14; captura 42501
y ROLLBACK solo revisados estáticamente. No se crearon objetos de prueba en esta
tarea. Ausencia de residuos y propietarios/privilegios posteriores no comprobados.
010 no repetido. D2.1-B1 continúa parcial: 020 y autenticación TCP pendientes;
B2–B5 no iniciados. Único cambio realizado: este registro documental.


## D2.1-B1 — evidencia manual de 020 y lectura posterior bloqueada — 2026-10-14

Fuente manual: el usuario informa ejecución anterior de 020 con `ROLLBACK` y
`B1 probes passed and rollback cleanup confirmed`. No se recibió salida completa,
fecha de esa ejecución ni código de salida; no es ejecución de Codex. El mensaje
final del script revisado depende de los 14 negativos y del control de limpieza.
No se repitió 020. 010 conserva su aprobación manual anterior (exit 0, mensaje
B1 metadata checks passed y ROLLBACK); no se repitió en esta tarea.

Inspección estática nueva: leídos AGENTS raíz/API, PROJECT_CONTEXT,
development-b1 y evidencia B1; revisados 010/020 vigentes. Huellas comprobadas:
- 010: 221FCCC631324B164658B2478AE0A9441D07898DE976A492313C1E4A89216516.
- 020: A78A76800290D2D644EBFBFD8C7453834C2D5B87208AF12574B9AB8EF4A80FD8.

Evidencia Docker del turno anterior en esta sesión: context inspect default,
ps, info, Compose ps postgres y Compose port postgres 5432 ejecutados por separado,
todos exit 0 sin aprobaciones. Endpoint npipe:////./pipe/docker_engine;
Docker Desktop 29.8.1; tomopedidos-local-postgres-1 healthy, puerto 127.0.0.1:55432.
Info mostró aviso informativo de obsolescencia del plugin docker sandbox; sin
advertencias de acceso en esas cinco invocaciones. Esto no acredita Compose exec.

Preparado `.cache/b1-postchecks-readonly.sql`: BEGIN READ ONLY, search_path pg_catalog,
SELECT de identidad/versión, owner/ACL de base y schemas, roles/membresías, privilegios
efectivos CONNECT/CREATE/TEMP y USAGE/CREATE, defaults, dependencias de schemas,
ausencia de probes/función/schema prohibido y búsqueda de nombres __tp_b1_;
ROLLBACK. Solo consultas de catálogos y funciones built-in de metadata; no crea
objetos, cambia roles ni concede privilegios. SQL no validado por PostgreSQL.
SHA256: 02DCDF1215D272AC10526A0F2121D51DE5D8206C0A592C086B2518967C16501D.

Único intento Docker nuevo (llamada independiente, sin aprobación solicitada):

```powershell
Get-Content -Raw .cache/b1-postchecks-readonly.sql | docker --context default compose -f D:\tomopedidos\compose.yaml -p tomopedidos-local exec -T postgres psql -X -v ON_ERROR_STOP=1 -U tomopedidos_bootstrap -d tomopedidos_local -f -
```

Exit 1. Salida completa:

```text
WARNING: Error loading config file: open C:\Users\erazof\.docker\config.json: Access is denied.
WARNING: Error loading config file: open C:\Users\erazof\.docker\config.json: Access is denied.
permission denied while trying to connect to the docker API at npipe:////./pipe/docker_engine
```

Detenido sin reintento, elevación ni acceso alternativo. No se ejecutó SQL ni se
confirmó identidad/base/versión desde PostgreSQL. Las reglas expuestas permiten los
cinco diagnósticos, pero no incluyen Compose exec; causa exacta del encaminamiento
no certificada. La autorización de lectura del usuario no resuelve este permiso.
No se ampliaron reglas globales ni se modificó configuración.

Pendientes para cerrar verificación posterior de privilegios: ejecutar y revisar
las consultas preparadas (ownership, ACL y ausencia actual de residuos) y ejecutar
010 final sin cambios, exigiendo exit 0, mensaje de éxito y ROLLBACK. La limpieza
manual informada de 020 no sustituye esa nueva foto posterior. B1 sigue parcial:
autenticación TCP/provisión privada permanecen pendientes y fuera de esta tarea.
No hay migraciones, cambios de roles/privilegios, credenciales, 001/002, Goose,
B2–B5, Celtas, deploy o push. Cambios locales: consultas preparadas y este registro.

## Acceso Docker y conectividad PostgreSQL — 2026-10-14

Autorización: cuatro diagnósticos Docker separados y únicamente SELECT de identidad
 y versión. Inspección de compose.yaml y evidencia previa para confirmar destino
local y usuario; no se leyeron secretos. Cada invocación se ejecutó por separado.

1. `docker --context default context inspect default --format '{{.Endpoints.docker.Host}}'`
   Exit 0; salida: `npipe:////./pipe/docker_engine`.
2. `docker --context default ps`
   Exit 0; `tomopedidos-local-postgres-1`, imagen `postgres:18.6-bookworm`,
   estado `Up 4 hours (healthy)`, puerto `127.0.0.1:55432->5432/tcp`.
   También se listó `mysqldb`; no se accedió a él.
3. `docker --context default compose -f D:\tomopedidos\compose.yaml -p tomopedidos-local ps postgres`
   Exit 0; servicio postgres healthy, contenedor `tomopedidos-local-postgres-1`,
   imagen fijada a sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c.
4. `docker --context default compose -f D:\tomopedidos\compose.yaml -p tomopedidos-local port postgres 5432`
   Exit 0; salida: `127.0.0.1:55432`.
5. `docker --context default compose -f D:\tomopedidos\compose.yaml -p tomopedidos-local exec -T postgres psql -X -v ON_ERROR_STOP=1 -U tomopedidos_bootstrap -d tomopedidos_local -c "SELECT current_database(), current_user, version();"`
   Exit 0; una fila:
   - current_database: `tomopedidos_local`
   - current_user: `tomopedidos_bootstrap`
   - version: `PostgreSQL 18.6 (Debian 18.6-1.pgdg12+2) on x86_64-pc-linux-gnu, compiled by gcc (Debian 12.2.0-14+deb12u1) 12.2.0, 64-bit`

Sin errores ni advertencias en las cinco invocaciones. Conectividad comprobada
mediante psql dentro del contenedor; no verifica autenticación TCP desde el host
ni roles migrator/runtime. No se ejecutaron scripts, migraciones ni consultas
adicionales; no se modificaron datos, roles, permisos o configuraciones.
El único cambio local es este registro. Esta comprobación no cierra D2.1-B1.

## D2.1-B1 — 020 ejecutado y verificaciones posteriores aprobadas — 2026-10-14

Autorización expresa del usuario: ejecutar 020 vigente sin modificaciones, lecturas
posteriores y repetición final de 010. Leídos AGENTS raíz/API, PROJECT_CONTEXT,
evidencia vigente, Compose y procedimiento development-b1. No se ejecutaron
001/002, Goose, provisión de credenciales, autenticación TCP ni B2–B5.

Inspección estática: 020 conserva ON_ERROR_STOP, guard de base/bootstrap superusuario
y colisiones; BEGIN contiene creación de tabla/fila/secuencia/función e impersonación
migrator/owner/runtime. Las 14 pruebas negativas capturan exclusivamente
insufficient_privilege (SQLSTATE 42501); éxito inesperado produce P0001 y cualquier
otro error aborta. Exige denied_count=14. Sin COMMIT. ROLLBACK precede al control
de restauración de identidad y limpieza, y al mensaje final. 010 usa BEGIN READ ONLY.
No se modificaron los scripts SQL.

SHA256:
- 020: A78A76800290D2D644EBFBFD8C7453834C2D5B87208AF12574B9AB8EF4A80FD8
- 010: 221FCCC631324B164658B2478AE0A9441D07898DE976A492313C1E4A89216516
- Lecturas .cache/b1-postchecks-readonly.sql: 02DCDF1215D272AC10526A0F2121D51DE5D8206C0A592C086B2518967C16501D
Lecturas de archivos y hashes: exit 0.

Preflight ejecutado, cada invocación Docker en exec_command independiente:
1. `docker --context default context inspect default --format '{{.Endpoints.docker.Host}}'`
   Exit 0; npipe:////./pipe/docker_engine.
2. `docker --context default compose -f D:\tomopedidos\compose.yaml -p tomopedidos-local ps postgres`
   Exit 0; tomopedidos-local-postgres-1, servicio postgres, healthy,
   postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c,
   127.0.0.1:55432->5432/tcp.
3. `docker --context default compose -f D:\tomopedidos\compose.yaml -p tomopedidos-local port postgres 5432`
   Exit 0; 127.0.0.1:55432.
4. `docker --context default compose -f D:\tomopedidos\compose.yaml -p tomopedidos-local exec -T postgres psql -X -v ON_ERROR_STOP=1 -U tomopedidos_bootstrap -d tomopedidos_local -c "SELECT current_database(), session_user, current_user, version(), current_setting('server_version') AS server_version, (SELECT rolsuper FROM pg_roles WHERE rolname=current_user) AS bootstrap_superuser;"`
   Exit 0; base tomopedidos_local, session_user/current_user tomopedidos_bootstrap,
   bootstrap_superuser=t, PostgreSQL 18.6 (Debian 18.6-1.pgdg12+2), x86_64, 64-bit.

Ejecución real 020, única invocación sin diagnósticos mezclados:
```powershell
Get-Content -Raw -Encoding UTF8 -LiteralPath D:\tomopedidos\tomopedidos-api\db\verification\020_b1_effective_privileges.sql | docker --context default compose -f D:\tomopedidos\compose.yaml -p tomopedidos-local exec -T postgres psql -X -v ON_ERROR_STOP=1 -U tomopedidos_bootstrap -d tomopedidos_local -f -
```
Exit 0. Salida completa:
```text
BEGIN
SET
DO
SET
SET
CREATE TABLE
INSERT 0 1
CREATE SEQUENCE
CREATE FUNCTION
DO
 value 
-------
     1
(1 row)

RESET
SET
DO
ROLLBACK
DO
                     result                      
-------------------------------------------------
 B1 probes passed and rollback cleanup confirmed
(1 row)
```

Positivas aprobadas en ejecución: migrator asume tp_owner, crea tabla, inserta una
fila, crea secuencia y función; aserciones de identidad/ownership pasan; SELECT
devuelve 1. Negativas aprobadas 14/14: SELECT, INSERT, UPDATE, DELETE, CREATE TABLE,
CREATE TEMP TABLE, CREATE SCHEMA, ALTER TABLE, TRUNCATE, nextval, llamada de función,
SET ROLE tp_owner, SET ROLE migrator y ALTER ROLE tp_owner LOGIN. El DO negativo
terminó sin error y el mensaje final fue alcanzado. La captura de 42501 queda
acreditada por el manejador exclusivo y la aserción de contador; no hay log individual
de SQLSTATE por prueba. ROLLBACK y DO posterior de limpieza/identidad confirmados.

Lecturas posteriores en conexión nueva:
```powershell
Get-Content -Raw -Encoding UTF8 -LiteralPath D:\tomopedidos\.cache\b1-postchecks-readonly.sql | docker --context default compose -f D:\tomopedidos\compose.yaml -p tomopedidos-local exec -T postgres psql -X -v ON_ERROR_STOP=1 -U tomopedidos_bootstrap -d tomopedidos_local -f -
```
Exit 0; BEGIN READ ONLY y ROLLBACK. Salida completa:
```text
BEGIN
SET
 current_database  |     session_user      |     current_user      |            version            
-------------------+-----------------------+-----------------------+-------------------------------
 tomopedidos_local | tomopedidos_bootstrap | tomopedidos_bootstrap | 18.6 (Debian 18.6-1.pgdg12+2)
(1 row)

      datname      |         owner         | datistemplate |                                                                   datacl                                                                   
-------------------+-----------------------+---------------+--------------------------------------------------------------------------------------------------------------------------------------------
 tomopedidos_local | tomopedidos_bootstrap | f             | {tomopedidos_bootstrap=CTc/tomopedidos_bootstrap,tomopedidos_migrator=c/tomopedidos_bootstrap,tomopedidos_runtime=c/tomopedidos_bootstrap}
(1 row)

       rolname        | rolcanlogin | rolinherit | rolsuper | rolcreatedb | rolcreaterole | rolreplication | rolbypassrls 
----------------------+-------------+------------+----------+-------------+---------------+----------------+--------------
 tomopedidos_migrator | t           | f          | f        | f           | f             | f              | f
 tomopedidos_runtime  | t           | f          | f        | f           | f             | f              | f
 tp_owner             | f           | f          | f        | f           | f             | f              | f
(3 rows)

        member        | granted_role | admin_option | inherit_option | set_option 
----------------------+--------------+--------------+----------------+------------
 tomopedidos_migrator | tp_owner     | f            | f              | t
(1 row)

       rolname        | connect | create | temp 
----------------------+---------+--------+------
 tomopedidos_migrator | t       | f      | f
 tomopedidos_runtime  | t       | f      | f
(2 rows)

    nspname     |       owner       |                        nspacl                         |       rolname        | usage | create 
----------------+-------------------+-------------------------------------------------------+----------------------+-------+--------
 audit          | tp_owner          | {tp_owner=UC/tp_owner}                                | tomopedidos_migrator | f     | f
 audit          | tp_owner          | {tp_owner=UC/tp_owner}                                | tomopedidos_runtime  | f     | f
 authorization  | tp_owner          | {tp_owner=UC/tp_owner,tomopedidos_runtime=U/tp_owner} | tomopedidos_migrator | f     | f
 authorization  | tp_owner          | {tp_owner=UC/tp_owner,tomopedidos_runtime=U/tp_owner} | tomopedidos_runtime  | t     | f
 identity       | tp_owner          | {tp_owner=UC/tp_owner}                                | tomopedidos_migrator | f     | f
 identity       | tp_owner          | {tp_owner=UC/tp_owner}                                | tomopedidos_runtime  | f     | f
 migration_meta | tp_owner          | {tp_owner=UC/tp_owner}                                | tomopedidos_migrator | f     | f
 migration_meta | tp_owner          | {tp_owner=UC/tp_owner}                                | tomopedidos_runtime  | f     | f
 public         | pg_database_owner | {pg_database_owner=UC/pg_database_owner}              | tomopedidos_migrator | f     | f
 public         | pg_database_owner | {pg_database_owner=UC/pg_database_owner}              | tomopedidos_runtime  | f     | f
 tenancy        | tp_owner          | {tp_owner=UC/tp_owner,tomopedidos_runtime=U/tp_owner} | tomopedidos_migrator | f     | f
 tenancy        | tp_owner          | {tp_owner=UC/tp_owner,tomopedidos_runtime=U/tp_owner} | tomopedidos_runtime  | t     | f
(12 rows)

 creator  | defaclnamespace | defaclobjtype |       defaclacl       
----------+-----------------+---------------+-----------------------
 tp_owner |               0 | f             | {tp_owner=X/tp_owner}
(1 row)

 nspname | object | deptype 
---------+--------+---------
(0 rows)

 table_absent | sequence_absent | forbidden_table_absent | function_absent | forbidden_schema_absent 
--------------+-----------------+------------------------+-----------------+-------------------------
 t            | t               | t                      | t               | t
(1 row)

 nspname | relname | relkind 
---------+---------+---------
(0 rows)

 nspname | proname 
---------+---------
(0 rows)

ROLLBACK
```
Interpretación: tabla/secuencia/tabla prohibida/función/schema prohibido ausentes
(cinco valores t); búsqueda global de relaciones y funciones __tp_b1_ sin filas;
sin dependencias de objetos en los seis schemas consultados. Los cinco schemas B1
siguen bajo tp_owner; runtime solo USAGE tenancy/authorization y sin CREATE;
migrator sin USAGE/CREATE directo; public bajo pg_database_owner sin acceso directo
de ambos logins. CONNECT sí y CREATE/TEMP no para ambos. Única membresía migrator
a tp_owner con SET=t, INHERIT=f, ADMIN=f. Defaults de función solo tp_owner.

Verificación final ejecutada:
```powershell
Get-Content -Raw -Encoding UTF8 -LiteralPath D:\tomopedidos\tomopedidos-api\db\verification\010_b1_metadata.sql | docker --context default compose -f D:\tomopedidos\compose.yaml -p tomopedidos-local exec -T postgres psql -X -v ON_ERROR_STOP=1 -U tomopedidos_bootstrap -d tomopedidos_local -f -
```
Exit 0. Salida completa:
```text
BEGIN
SET
DO
          result           
---------------------------
 B1 metadata checks passed
(1 row)

ROLLBACK
```

Sin errores ni advertencias en las invocaciones Docker de esta tarea; sin reintentos.
Verificación efectiva 020 y metadata final 010 aprobadas por ejecución de Codex.
D2.1-B1 sigue parcial: provisión privada de credenciales y autenticación TCP pendientes,
fuera de alcance. No acredita aislamiento tenant/RLS ni conexión DB de la API.
Sin cambios persistentes de datos, roles, schemas, permisos o configuración.
Cambios locales documentales: este registro y resumen de estado en AGENTS.md.

## Diagnóstico de PostgreSQL detenido — 2026-10-14

Autorización: diagnóstico de solo lectura y arranque condicional no destructivo,
solo tras comprobar volumen Tomopedidos y ausencia de recreación o dudas sobre datos.
Leídos AGENTS.md raíz, PROJECT_CONTEXT.md, compose.yaml y evidencia reciente.
No se leyeron archivos de credenciales ni se modificó configuración.

Cada invocación Docker se ejecutó en exec_command independiente:

1. `docker --context default context inspect default --format '{{.Endpoints.docker.Host}}'`
   Exit 0: `npipe:////./pipe/docker_engine`.
2. `docker --context default info --format 'ServerVersion={{.ServerVersion}} OSType={{.OSType}} Name={{.Name}}'`
   Exit 0: `ServerVersion=29.8.1 OSType=linux Name=docker-desktop`.
3. `docker --context default ps -a`
   Exit 0: contenedor `252f48ba3abc`, `tomopedidos-local-postgres-1`,
   imagen `postgres:18.6-bookworm`, `Exited (255) 3 minutes ago`,
   puerto configurado `127.0.0.1:55432->5432/tcp`.
   El listado global mostró otros contenedores, incluido celtas-db;
   no se inspeccionaron ni operaron recursos de Celtas.
4. `docker --context default compose -f D:\tomopedidos\compose.yaml -p tomopedidos-local ps -a postgres`
   Exit 0: mismo contenedor, servicio postgres, `Exited (255) 4 minutes ago`;
   imagen fijada a sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c;
   puerto configurado `127.0.0.1:55432->5432/tcp`.
5. Inspección selectiva intentada:

```powershell
docker --context default inspect tomopedidos-local-postgres-1 --format 'State={{json .State}} Mounts={{json .Mounts}} Image={{.Config.Image}} Project={{index .Config.Labels "com.docker.compose.project"}} Service={{index .Config.Labels "com.docker.compose.service"}} ConfigFiles={{index .Config.Labels "com.docker.compose.project.config_files"}} ConfigHash={{index .Config.Labels "com.docker.compose.config-hash"}}'
```

Exit 1. Salida completa:

```text
template parsing error: template: :1: function "com" not defined
```

Error de interpretación de plantilla, no de permisos. Se detuvo conforme a
AGENTS.md, sin reintento, corrección ni recuperación.

Conclusión comprobada: PostgreSQL está detenido y sigue asociado al proyecto
tomopedidos-local; una lista ps sin -a vacía no acredita eliminación ni pérdida
de datos. Código 255 por sí solo no identifica la causa de parada; logs pendientes.
Inspección estática Compose: volumen lógico postgres_data montado en
/var/lib/postgresql; nombre esperado tomopedidos-local_postgres_data.
Existencia, etiquetas, montaje real, contenido y exclusividad del volumen no
comprobados; no se puede certificar aún que el arranque cumpla las condiciones.

No se inició PostgreSQL. No se ejecutaron consultas SQL, pruebas TCP, scripts,
Goose, cambios de credenciales, HBA, Compose, volúmenes, deploy ni push.
Pendientes: inspección selectiva corregida bajo autorización de continuación,
verificación del volumen y sus consumidores, logs recientes sin secretos,
evaluación de recreación y, solo si es seguro, arranque autorizado y verificaciones
de healthy, puerto, identidad/versión, tres roles y cinco schemas por lectura.
Único cambio: este registro documental.

## Continuación de diagnóstico del contenedor detenido — 2026-10-14

Autorización expresa: corregir sintaxis de inspect y consultar estado, montajes,
volumen y logs; no iniciar, reconciliar, modificar recursos ni ejecutar SQL.
Leídos AGENTS.md raíz, compose.yaml y evidencia previa. Cada comando Docker
ejecutado en exec_command independiente; todos exit 0, sin errores de permisos.

### Comandos ejecutados

```powershell
docker --context default inspect tomopedidos-local-postgres-1 --format 'State={{json .State}} Mounts={{json .Mounts}} Image={{.Config.Image}} Labels={{json .Config.Labels}} RestartPolicy={{json .HostConfig.RestartPolicy}} Memory={{.HostConfig.Memory}} MemorySwap={{.HostConfig.MemorySwap}} PortBindings={{json .HostConfig.PortBindings}}'
```

La plantilla evita claves entre comillas dentro de index y no consulta Config.Env.
Estado: exited, Running=false, Paused=false, Restarting=false, Dead=false,
Pid=0, ExitCode=255, Error vacío, OOMKilled=false.
StartedAt=2026-10-14T01:22:54.66748375Z;
FinishedAt=2026-10-14T12:47:14.451941919Z.
Health=starting, FailingStreak=0, Log=[]: no acredita salud actual.
RestartPolicy=no, MaximumRetryCount=0; Memory=0 y MemorySwap=0
(sin límites explícitos en estos campos; no acredita ausencia de presión del host).
Imagen postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c.
PortBindings: 127.0.0.1:55432 hacia 5432/tcp, configurado, sin listener comprobado.

Etiquetas: proyecto tomopedidos-local, servicio postgres,
config_files=D:\tomopedidos\compose.yaml, working_dir=D:\tomopedidos,
environment_file=D:\tomopedidos\.env.local, Compose 5.5.1.
Config-hash=47875cfe9d2f7a576a2f40e7adb46b0b9e33d3fe7af30c32d802cb11011b29fb.
No se leyeron valores de .env.local ni .env ni se compararon hashes actuales de Compose.

Montaje real: Type=volume, Name=tomopedidos-local_postgres_data,
Source=/var/lib/docker/volumes/tomopedidos-local_postgres_data/_data,
Destination=/var/lib/postgresql, Driver=local, Mode=rw, RW=true.
Coincide con postgres_data:/var/lib/postgresql del Compose vigente y proyecto fijado.

```powershell
docker --context default volume inspect tomopedidos-local_postgres_data
```

Exit 0. Volumen existente, Driver=local, Scope=local, Options=null,
CreatedAt=2026-10-14T00:58:28Z, Mountpoint coincidente con Source.
Etiquetas: com.docker.compose.project=tomopedidos-local,
com.docker.compose.volume=postgres_data, com.docker.compose.version=5.5.1,
com.docker.compose.config-hash=3ff8075d5ec54df463d3af659e5693f74c07d4708dae7dcc82b6bbef0816a8d8.

```powershell
docker --context default logs --timestamps --tail 160 tomopedidos-local-postgres-1
```

Exit 0. Se filtraron antes de mostrar líneas con indicadores de secretos,
URI PostgreSQL y encabezados STATEMENT/DETAIL/CONTEXT. No se guardó un volcado
de secretos ni se ejecutaron sentencias presentes en logs.
Evidencia relevante del extracto:

```text
2026-10-14T01:22:54.995227381Z PostgreSQL Database directory appears to contain a database; Skipping initialization
2026-10-14 01:22:55.088 UTC [1] LOG: starting PostgreSQL 18.6 (Debian 18.6-1.pgdg12+2)
2026-10-14 01:22:55.109 UTC [32] LOG: database system was shut down at 2026-10-14 01:22:53 UTC
2026-10-14 01:22:55.117 UTC [1] LOG: database system is ready to accept connections
2026-10-14 03:41:05.707 UTC [13656] ERROR: column reference "r.oid" is ambiguous at character 60
2026-10-14 05:17:59.940 UTC [30] LOG: checkpoint complete
```

El error SQL es histórico, coincidente con el incidente 010 ya registrado;
después hay checkpoints exitosos. No es un error nuevo de este diagnóstico.
Última línea recibida: checkpoint de 05:17:59 UTC, anterior a FinishedAt.
No aparecen mensajes de shutdown, PANIC, incompatibilidad de versión,
corrupción o agotamiento de disco en el extracto consultado. Esto no certifica
integridad del cluster ni descarta problemas que no quedaron registrados.

```powershell
docker --context default ps -a --filter volume=tomopedidos-local_postgres_data --format '{{.ID}} {{.Names}} {{.Status}}'
```

Exit 0. Único consumidor registrado: 252f48ba3abc,
tomopedidos-local-postgres-1, Exited (255) 8 minutes ago.
No se inspeccionaron ni modificaron recursos de Celtas.

### Evaluación y recomendación, sin ejecución

Contenedor detenido, volumen persistente presente y asociado inequívocamente
al proyecto por etiquetas/montaje; no eliminado ni asociado a otro proyecto.
La causa exacta del código 255 no está registrada en State.Error ni en el
extracto de logs. Interrupción externa/Engine es una hipótesis compatible,
no un hecho verificado. OOMKilled=false no descarta presión de recursos del host.
No hay evidencia observada de corrupción o incompatibilidad; no se inspeccionó
el contenido del volumen ni se verificó integridad con PostgreSQL detenido.

Recomendación para aprobación: docker --context default start tomopedidos-local-postgres-1.
Arranca el contenedor existente sin reconciliar Compose ni reemplazar montaje,
imagen o variables. PostgreSQL escribirá en el volumen y podría efectuar
recuperación WAL por la terminación no explicada; riesgo no nulo.
Preferible a compose up en este punto: el contenedor fue creado con .env.local,
y un up sin --env-file podría usar .env y proponer recreación por divergencias.
No se comprobó que exista divergencia; no se afirma que Compose vaya a recrear.
Si un futuro arranque falla, detener y conservar evidencia, sin reintentos.

No se inició PostgreSQL ni se ejecutó Compose up, SQL, pruebas TCP, Goose,
scripts bootstrap, cambios de credenciales, ACL, HBA, configuración, recursos,
deploy o push. Único cambio documental: este registro, según AGENTS.md.

## Arranque autorizado detenido por salud unhealthy en preflight — 2026-10-14

Autorización expresa: docker --context default start tomopedidos-local-postgres-1,
previa confirmación inmediata de identidad/proyecto/volumen; posteriores lecturas
de estado, salud, puerto, logs y SQL. Condición explícita de parada: unhealthy,
entre otras. Leídos AGENTS.md raíz/API y evidencia reciente.

Única invocación Docker, en exec_command independiente:

```powershell
docker --context default inspect tomopedidos-local-postgres-1 --format 'ID={{.Id}} Name={{.Name}} State={{json .State}} Mounts={{json .Mounts}} Labels={{json .Config.Labels}} Image={{.Config.Image}}'
```

Exit 0, sin errores ni advertencias. Identidad:
252f48ba3abc0bec996376b89e6ed84f52ccb8ae2b56bda77c30dda0020f8fec,
Name=/tomopedidos-local-postgres-1, proyecto tomopedidos-local, servicio postgres.
Imagen fijada postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c.
Volumen real tomopedidos-local_postgres_data, Driver=local, RW=true,
Source=/var/lib/docker/volumes/tomopedidos-local_postgres_data/_data,
Destination=/var/lib/postgresql. Conserva etiquetas Compose, incluido .env.local.

Estado actual: Status=exited, Running=false, Pid=0, ExitCode=0,
Error vacío, OOMKilled=false, Dead=false, Restarting=false, Paused=false.
StartedAt=2026-10-14T12:57:19.676599468Z;
FinishedAt=2026-10-14T12:57:51.08755202Z.
Health.Status=unhealthy, FailingStreak=0. Los cinco registros de healthcheck
recibidos, entre 12:57:29 y 12:57:50 UTC, tienen ExitCode=0 y salida
127.0.0.1:5432 - accepting connections. Estos resultados no anulan el estado
unhealthy ni acreditan salud de un contenedor actualmente detenido.

Las marcas de tiempo y ExitCode cambiaron respecto del diagnóstico previo:
hubo otro inicio y terminación no ejecutados por Codex en esta tarea.
Actor, motivo y causa de unhealthy no determinados. No se infiere corrupción
ni cierre limpio de PostgreSQL únicamente a partir de ExitCode=0.

Se detuvo inmediatamente por la condición unhealthy, antes del comando start.
Arranque autorizado NO ejecutado; no tiene código de salida en esta tarea.
No se realizaron más invocaciones Docker, logs ni SQL. Puerto no comprobado
nuevamente; PostgreSQL 18.6/base/roles/schemas no verificados por SQL en este turno.
No hubo errores de permisos, reintentos, correcciones automáticas, Compose up,
restart, recreación, cambios de variables/imagen/volumen/credenciales ni acceso
a Celtas. Provisión de passwords y pruebas TCP siguen pendientes.
Único cambio: este registro documental. Se requiere autorización específica
para investigar el nuevo estado antes de retomar el arranque.

## Arranque del contenedor existente y lecturas aprobadas — 2026-10-14

El usuario confirmó que el inicio/parada aproximadamente a las 07:57 Lima
fueron manuales desde Docker Desktop. Esa secuencia es esperada; no requiere
investigación adicional. Autorizó expresamente start y verificaciones posteriores,
aclarando que unhealthy mientras está detenido no impide por sí solo el arranque.

Cada invocación Docker se ejecutó en exec_command independiente. Todas exit 0,
sin errores de permisos ni advertencias. No se consultaron secretos.

### Arranque autorizado

```powershell
docker --context default start tomopedidos-local-postgres-1
```

Exit 0; salida completa: `tomopedidos-local-postgres-1`.

### Estado, salud, volumen y puerto

```powershell
docker --context default inspect tomopedidos-local-postgres-1 --format 'State={{json .State}} Mounts={{json .Mounts}} Ports={{json .NetworkSettings.Ports}} Labels={{json .Config.Labels}}'
```

Exit 0. Status=running, Running=true, Pid=1282, Error vacío,
OOMKilled=false, Dead=false, Restarting=false.
StartedAt=2026-10-14T13:01:16.020509171Z (08:01:16 Lima).
Health.Status=healthy, FailingStreak=0. Dos healthchecks posteriores al arranque
a las 13:01:21 y 13:01:26 UTC con ExitCode=0 y
`127.0.0.1:5432 - accepting connections`; no se depende de registros antiguos.
Proyecto tomopedidos-local, servicio postgres; etiquetas Compose conservadas.
Montaje: volumen tomopedidos-local_postgres_data, Driver=local, RW=true,
Source=/var/lib/docker/volumes/tomopedidos-local_postgres_data/_data,
Destination=/var/lib/postgresql. Puerto publicado:
5432/tcp -> HostIp=127.0.0.1, HostPort=55432.

### Logs de este arranque

```powershell
docker --context default logs --timestamps --since 2026-10-14T13:01:16Z tomopedidos-local-postgres-1
```

Exit 0. Filtro preventivo de líneas con indicadores de secretos/sentencias antes
de mostrarlas; la salida recibida no requirió omisiones. Evidencia relevante:

```text
2026-10-14T13:01:16.191284185Z PostgreSQL Database directory appears to contain a database; Skipping initialization
2026-10-14 13:01:16.226 UTC [1] LOG: starting PostgreSQL 18.6 (Debian 18.6-1.pgdg12+2)
2026-10-14 13:01:16.244 UTC [32] LOG: database system was shut down at 2026-10-14 12:57:51 UTC
2026-10-14 13:01:16.251 UTC [1] LOG: database system is ready to accept connections
```

También registra listeners IPv4/IPv6 en 5432 y socket Unix.
Sin errores, advertencias, mensajes de recuperación WAL, corrupción ni recuperación
fallida en los logs consultados de este arranque. Reconoce el cierre manual anterior
y reutiliza el directorio existente, sin inicializar un cluster nuevo.

### Consultas SQL exclusivamente de lectura

Destino: contenedor confirmado tomopedidos-local-postgres-1, base explícita
tomopedidos_local, usuario tomopedidos_bootstrap; psql por socket Unix, sin -h.
SQL revisado antes de ejecución: BEGIN READ ONLY, SELECT de versión/identidad,
catálogos pg_roles y pg_namespace y función built-in de owner; ROLLBACK.
Sin archivo SQL ni scripts de bootstrap; no aplica hash de script.

```powershell
docker --context default exec tomopedidos-local-postgres-1 psql -X -v ON_ERROR_STOP=1 -U tomopedidos_bootstrap -d tomopedidos_local -c "BEGIN READ ONLY; SELECT current_setting('server_version') AS server_version, current_database() AS database, session_user, current_user; SELECT rolname, rolcanlogin FROM pg_catalog.pg_roles WHERE rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime') ORDER BY rolname; SELECT nspname, pg_catalog.pg_get_userbyid(nspowner) AS owner FROM pg_catalog.pg_namespace WHERE nspname IN ('identity','tenancy','authorization','audit','migration_meta') ORDER BY nspname; ROLLBACK;"
```

Exit 0. Salida: BEGIN; una fila de identidad con
server_version=18.6 (Debian 18.6-1.pgdg12+2), database=tomopedidos_local,
session_user=current_user=tomopedidos_bootstrap.
Tres filas de roles: tomopedidos_migrator LOGIN=t,
tomopedidos_runtime LOGIN=t, tp_owner LOGIN=f.
Cinco filas de schemas: audit, authorization, identity, migration_meta y tenancy,
todos con owner=tp_owner. ROLLBACK confirmado.
Se verificaron los valores y nombres, no solo el código de salida.

Resultado: contenedor existente iniciado y healthy, mismo volumen/puerto,
PostgreSQL 18.6/base/roles/schemas confirmados por ejecución real.
No certifica todas las ACL ni integridad exhaustiva; no repite 010/020.
No se ejecutó Compose up/restart/recreación, migraciones, Goose, cambios de roles,
privilegios, variables, imagen, volumen o credenciales; no acceso a Celtas,
deploy o push. Provisión privada y autenticación TCP siguen pendientes; B1 parcial.
Único cambio de archivo: este registro documental.

## D2.1-B1 — preflight de autenticación TCP, solo lectura — 2026-10-14

Autorización expresa: diagnóstico de configuración, HBA y atributos no sensibles;
sin provisión ni pruebas de autenticación. Leídos AGENTS.md raíz/API y evidencia
vigente. Cada invocación Docker en exec_command independiente; todas exit 0,
sin errores ni advertencias. No se consultó pg_authid, verificadores, Config.Env
ni opciones HBA potencialmente sensibles.

### Destino confirmado

```powershell
docker --context default inspect tomopedidos-local-postgres-1 --format 'Status={{.State.Status}} Health={{.State.Health.Status}} Mounts={{json .Mounts}} Ports={{json .NetworkSettings.Ports}} Labels={{json .Config.Labels}}'
```

Exit 0: running, healthy, proyecto tomopedidos-local/servicio postgres.
Volumen tomopedidos-local_postgres_data en /var/lib/postgresql, Driver=local,
RW=true; Source=/var/lib/docker/volumes/tomopedidos-local_postgres_data/_data.
Puerto 5432/tcp publicado exclusivamente en 127.0.0.1:55432.

### Configuración, HBA y roles

SQL revisado antes de ejecución: transacción READ ONLY, SELECT de settings,
pg_hba_file_rules sin options, pg_roles sin passwords, membresías y ROLLBACK.
Sin archivo/script SQL; no aplica hash. Conexión por socket Unix con bootstrap.

```powershell
docker --context default exec tomopedidos-local-postgres-1 psql -X -v ON_ERROR_STOP=1 -U tomopedidos_bootstrap -d tomopedidos_local -c "BEGIN READ ONLY; SELECT current_database(), session_user, current_user, current_setting('server_version') AS server_version, current_setting('password_encryption') AS password_encryption, current_setting('listen_addresses') AS listen_addresses, current_setting('port') AS port, current_setting('hba_file') AS hba_file, pg_conf_load_time() AS configuration_loaded_at; SELECT rule_number, file_name, line_number, type, database, user_name, address, netmask, auth_method, error FROM pg_catalog.pg_hba_file_rules ORDER BY rule_number NULLS LAST, file_name, line_number; SELECT rolname, rolcanlogin, rolinherit, rolsuper, rolcreatedb, rolcreaterole, rolreplication, rolbypassrls FROM pg_catalog.pg_roles WHERE rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime') ORDER BY rolname; SELECT member.rolname AS member, granted.rolname AS granted_role, m.admin_option, m.inherit_option, m.set_option FROM pg_catalog.pg_auth_members m JOIN pg_catalog.pg_roles member ON member.oid=m.member JOIN pg_catalog.pg_roles granted ON granted.oid=m.roleid WHERE member.rolname IN ('tp_owner','tomopedidos_migrator','tomopedidos_runtime') OR granted.rolname='tp_owner'; ROLLBACK;"
```

Exit 0; BEGIN y ROLLBACK confirmados. Identidad:
tomopedidos_local, session_user=current_user=tomopedidos_bootstrap,
server_version=18.6 (Debian 18.6-1.pgdg12+2).
password_encryption=scram-sha-256, listen_addresses=*, port=5432,
hba_file=/var/lib/postgresql/18/docker/pg_hba.conf,
configuration_loaded_at=2026-10-14 13:01:16.205915+00.

Siete reglas, todas del mismo archivo, sin errores de parsing (error NULL):

| Orden | Línea | Tipo | Base | Usuario | Dirección | Método |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 117 | local | all | all | socket Unix | trust |
| 2 | 119 | host | all | all | 127.0.0.1/32 | scram-sha-256 |
| 3 | 121 | host | all | all | ::1/128 | scram-sha-256 |
| 4 | 124 | local | replication | all | socket Unix | trust |
| 5 | 125 | host | replication | all | 127.0.0.1/32 | scram-sha-256 |
| 6 | 126 | host | replication | all | ::1/128 | scram-sha-256 |
| 7 | 128 | host | all | all | all | scram-sha-256 |

Roles: migrator/runtime LOGIN=t; tp_owner LOGIN=f.
Los tres: INHERIT=f, SUPERUSER=f, CREATEDB=f, CREATEROLE=f,
REPLICATION=f, BYPASSRLS=f. Única membresía consultada:
tomopedidos_migrator -> tp_owner, ADMIN=f, INHERIT=f, SET=t.

### Antigüedad HBA y CONNECT

SQL revisado: solo metadatos de archivo HBA mediante pg_stat_file y privilegio
CONNECT mediante función built-in; sin lectura del contenido de secretos.

```powershell
docker --context default exec tomopedidos-local-postgres-1 psql -X -v ON_ERROR_STOP=1 -U tomopedidos_bootstrap -d tomopedidos_local -c "BEGIN READ ONLY; SELECT (pg_stat_file(current_setting('hba_file'))).modification AS hba_modified_at, pg_conf_load_time() AS configuration_loaded_at, (pg_stat_file(current_setting('hba_file'))).modification <= pg_conf_load_time() AS hba_not_newer_than_configuration_load; SELECT rolname, has_database_privilege(rolname, current_database(), 'CONNECT') AS can_connect FROM pg_catalog.pg_roles WHERE rolname IN ('tomopedidos_migrator','tomopedidos_runtime') ORDER BY rolname; ROLLBACK;"
```

Exit 0; BEGIN y ROLLBACK. hba_modified_at=2026-10-14 01:14:25+00,
configuration_loaded_at=2026-10-14 13:01:16.205915+00;
hba_not_newer_than_configuration_load=t. CONNECT=t para ambos logins.

### Interpretación y límites

La primera regla coincidente decide la autenticación, sin fallback.
TCP interno a 127.0.0.1:5432 para tomopedidos_local/migrator o runtime:
regla 2. IPv6 loopback: regla 3. Desde Windows 127.0.0.1:55432 llega al
puerto 5432 del contenedor; la IP cliente efectiva depende del forwarding Docker.
Si se observa loopback aplicaría 2/3; para otra IP aplicaría 7. Todas estas
rutas requieren SCRAM según el archivo consultado. Las reglas replication
no corresponden a conexiones ordinarias a tomopedidos_local.

trust solo afecta sockets Unix: no usar psql sin host para demostrar contraseña.
listen_addresses=* dentro del contenedor no cambia el bind externo loopback;
la regla 7 también permite autenticación desde clientes de redes Docker alcanzables.
password_encryption configura nuevos verificadores, no certifica que los roles
ya tengan contraseña. No se investigó existencia ni formato de verificadores.

pg_hba_file_rules refleja el archivo actual, no una copia de las reglas cargadas.
Sin errores y con modificación anterior a la carga, evidencia consistente con
su aplicación al arranque; autenticación real no certificada sin pruebas futuras.
Referencia: https://www.postgresql.org/docs/18/auth-pg-hba-conf.html y
https://www.postgresql.org/docs/18/view-pg-hba-file-rules.html.

Recomendación propuesta, no ejecutada: dos contraseñas independientes en gestor
privado, provisión humana interactiva con psql \password por rol después de
aprobación específica, sin secretos en SQL literal, CLI, historial ni logs.
\password modifica persistentemente el rol; no elude la autorización de ALTER ROLE.
Conservar bootstrap; usar posteriormente una terminal privada sin transcripción.
Verificar password_encryption en esa misma sesión antes de provisionar.
Guardar credencial migrator solo en el archivo privado realmente usado por Goose
(contenedor actual registra .env.local; no asumir .env sin comprobar flujo), con
ACL y exclusión Git verificadas. Runtime puede permanecer en gestor fuera del repo
hasta aprobar su consumidor. No cambiar HBA ni Compose: no se observa necesidad.

Aprobaciones pendientes: provisión de ambos roles, escritura privada de credenciales
y cualquier ajuste de ACL local concreto, pruebas positivas/negativas TCP en las
dos rutas y eventual instalación de cliente host. No repetir 001/002/010/020.
Único cambio persistente de esta tarea: registro documental autorizado.
Sin cambios de PostgreSQL, Docker, credenciales, roles, HBA, volúmenes ni Celtas;
sin migraciones, deploy, push, B2–B5. B1 sigue parcial.

## D2.1-B1 — autenticación manual y evaluación de cierre

Fecha de registro documental: 2026-10-14. Las fechas/horas de las pruebas manuales
no fueron aportadas; no se les asigna la fecha de este registro como ejecución.
Fuente: confirmación expresa del usuario en la conversación. No es ejecución
de Codex ni se dispone aquí de transcripciones completas o comandos exactos
para todas las pruebas. Se registra solo el resultado y código expresamente informado.

### Evidencia manual nueva

Destino informado: contexto Docker default, contenedor tomopedidos-local-postgres-1,
PostgreSQL 18.6, base tomopedidos_local. El usuario confirma credenciales independientes
de tomopedidos_migrator y tomopedidos_runtime; no se registran contraseñas,
verificadores, método/comando de provisión ni ubicación de almacenamiento no confirmados.

| Comprobación manual | Resultado informado | Código informado |
| --- | --- | --- |
| TCP interno 127.0.0.1:5432, migrator | Autenticación exitosa | No aportado |
| TCP interno 127.0.0.1:5432, runtime | Autenticación exitosa | No aportado |
| Migrator con contraseña incorrecta | Rechazo correcto | Véase nota de códigos negativos |
| Runtime con contraseña incorrecta | Rechazo correcto | Véase nota de códigos negativos |
| Migrator con contraseña de runtime | Rechazo correcto | Véase nota de códigos negativos |
| Runtime con contraseña de migrator | Rechazo correcto | Véase nota de códigos negativos |
| Test-NetConnection -ComputerName 127.0.0.1 -Port 55432 | TcpTestSucceeded : True | No aportado |
| Cliente Windows D:\tools\pgsql\bin\psql.exe | Versión 18.6 | No aportado |
| Windows -> 127.0.0.1:55432, migrator | Autenticación, identidad/base correctas, PostgreSQL 18.6 y ROLLBACK | 0 |
| Windows -> 127.0.0.1:55432, runtime | Autenticación, identidad/base correctas, PostgreSQL 18.6 y ROLLBACK | 0 |

Nota: el usuario informa que las pruebas negativas con código capturado devolvieron
2. No se aportó una salida individual que permita atribuir un código capturado a
cada intento; los cuatro rechazos sí están confirmados expresamente. No se inventa
SQLSTATE ni texto exacto de error. El código por sí solo no prueba rechazo de password;
se combina con la confirmación manual del rechazo correcto.

Direcciones internas observadas en las pruebas Windows: 172.29.0.1 y 172.29.0.2.
No se atribuye cada dirección a una columna o rol no especificado; son diagnóstico
del forwarding y no contratos fijos ni valores que deban exigirse en futuras pruebas.
La conectividad Test-NetConnection se distingue de la autenticación PostgreSQL,
que está confirmada separadamente para ambos roles desde Windows.

### Evidencia anterior, referenciada sin duplicar

La sección [020 ejecutado y verificaciones posteriores aprobadas](#d21-b1--020-ejecutado-y-verificaciones-posteriores-aprobadas--2026-10-14)
ya documenta ejecución de Codex, exit 0, las 14 denegaciones de privilegios,
ROLLBACK, limpieza, lecturas posteriores y 010 final aprobado. No se copia ni
se repite esa ejecución. El [preflight TCP](#d21-b1--preflight-de-autenticación-tcp-solo-lectura--2026-10-14)
documenta SCRAM, HBA, LOGIN/atributos/membresías y CONNECT por lecturas de Codex.

### Criterios y dictamen

Se revisaron AGENTS.md raíz/API, PROJECT_CONTEXT.md, ROADMAP.md,
docs/development-b1.md, propuesta de esquema D2.1-B, Compose y los cuatro scripts
001/002/010/020 vigentes mediante inspección estática. No se ejecutó Docker ni SQL
en esta tarea. Los scripts y configuración no se modificaron.

| Criterio del alcance local B1 | Estado/evidencia |
| --- | --- |
| Rutas Goose/sqlc y separación de bootstrap/verification | Preparadas/revisadas en el registro B1; Compose vigente consistente |
| Roles, membresías, cinco schemas, ownership, ACL y defaults | Aplicación 001/002 y metadata 010 previamente documentadas |
| Privilegios efectivos y rechazo runtime | 020 aprobado con 14 negativos y limpieza; registro previo |
| Metadata y ausencia de residuos después del probe | Lecturas y 010 final aprobados; registro previo |
| Configuración TCP SCRAM y atributos restringidos | Preflight de lectura ejecutado por Codex; registro previo |
| Credenciales independientes y autenticación de ambos logins | Confirmación manual y positivos TCP internos/Windows |
| Rechazo de credenciales incorrectas y cruzadas | Cuatro negativos manuales confirmados; códigos capturados 2 |
| SET ROLE tp_owner e identidad en sesión TCP autenticada migrator; search_path migration_meta, pg_catalog | Pendiente de evidencia específica según development-b1.md |

Dictamen: verificaciones de autenticación local aprobadas según evidencia manual;
D2.1-B1 permanece parcialmente completada por la última comprobación de sesión
migrator requerida en development-b1.md (comentario de prueba TCP y revisión de
seguridad B1). 020 ya confirma SET ROLE y ownership mediante SET SESSION AUTHORIZATION
desde bootstrap; no se invalida esa prueba, pero no se presenta como ejecución de
la comprobación adicional en una conexión autenticada directamente como migrator.
No se aportó resultado de esa sesión ni de search_path; no se infiere a partir del
éxito de login. Basta registrar evidencia manual específica o realizar la comprobación
bajo autorización; no requiere repetir bootstrap ni 020, ni crear objetos.

La ejecución real de Goose/tabla de control sigue fuera de este cierre, según la
guía B1; la carga privada de su credencial tampoco se da por verificada por login.
Conexión DB de API, tablas de aplicación, auth HTTP, RLS, aislamiento tenant y B2–B5
no están implementados ni autorizados por este registro; no son criterios cumplidos
por autenticación PostgreSQL. Fase 1 no se declara completada.

Cambios exclusivamente documentales: este registro y resúmenes de estado en
AGENTS.md, PROJECT_CONTEXT.md, docs/development-b1.md, ROADMAP.md y encabezado de
docs/architecture/d2-1-b-schema-design.md. Se conservan los registros históricos.
No se accedió a secretos ni a Celtas; sin cambios PostgreSQL/Docker/HBA/Compose,
migraciones, roles, permisos, contenedores, deploy o push.

## D2.1-B1 — cierre formal con evidencia manual de SET ROLE

Fecha de registro documental: 2026-10-14; fecha/hora de ejecución manual no aportadas.
Fuente: resultados confirmados por el usuario, no ejecución de Codex.
Conexión Windows mediante psql 18.6, autenticada como tomopedidos_migrator
contra tomopedidos_local por 127.0.0.1:55432. No se inventa comando CLI.
SQL exacto informado, no ejecutado en esta tarea:

```sql
BEGIN READ ONLY;
SELECT 'ANTES' AS etapa, session_user, current_user,
       current_setting('search_path') AS search_path;
SET LOCAL ROLE tp_owner;
SELECT 'DESPUES' AS etapa, session_user, current_user,
       current_setting('search_path') AS search_path;
ROLLBACK;
```

| Etapa | session_user | current_user | search_path |
| --- | --- | --- | --- |
| ANTES | tomopedidos_migrator | tomopedidos_migrator | migration_meta, pg_catalog |
| DESPUES | tomopedidos_migrator | tp_owner | migration_meta, pg_catalog |

SET LOCAL ROLE exitoso, ROLLBACK confirmado y $LASTEXITCODE=0, según el usuario.
Satisface el pendiente de la evaluación anterior: identidad autenticada migrator
conservada, asunción explícita de tp_owner y search_path esperado antes/después.
Es coherente con SET TRUE/INHERIT FALSE/ADMIN FALSE y con el search_path definido
por 002. No implica creación de objetos; ownership efectivo ya está verificado en
020. No se infiere una consulta posterior al ROLLBACK que no fue informada.

Dictamen actualizado: **D2.1-B1 completada para el alcance PostgreSQL local**.
La matriz de la evaluación anterior queda cumplida: rutas/separación de herramientas,
roles/schemas/ACL/defaults, 010, 020 y limpieza, preflight SCRAM, credenciales
independientes, positivos TCP internos/Windows, cuatro negativos de contraseña y
comprobación de sesión migrator ahora aportada. No se duplica evidencia ni se repiten
001/002/010/020. La distinción entre evidencia manual y ejecución anterior de Codex
se conserva en sus registros respectivos. No quedan criterios pendientes de B1.

Fuera del cierre: ejecución Goose/tabla de control, configuración privada de su
consumidor, conexión DB de la API, tablas funcionales, auth HTTP, RLS y B2–B5.
No se declara Fase 1 completada ni se autoriza el siguiente corte.
Próximo bloque recomendado: revisar B2 identidad/credenciales/sesiones, cerrar
decisiones de email, estados, CSRF/claves, epochs y constraints y obtener aprobación
específica antes de implementar o migrar.

Inspección documental de Codex en esta tarea: resúmenes y criterios vigentes revisados;
contrato SQL contrastado con los scripts ya inspeccionados en la evaluación anterior.
Una búsqueda adicional con globs de rutas SQL falló (rg, Windows os error 123:
nombre de archivo/directorio o sintaxis de etiqueta del volumen incorrectos).
No fue denegación de permisos; no se reintentó ni se corrigió el comando.
No afecta la evidencia SQL anterior ni la nueva ejecución manual confirmada.
Cambios exclusivamente documentales de estado; sin SQL, Docker, infraestructura,
credenciales, secretos, migraciones, deploy, push ni acceso a Celtas.

## D2.1-B2 — B2-D01 aprobada y consolidación documental — 2026-10-14

Fuente de aprobación de diseño: instrucción expresa del usuario. B2-D01 establece
correo ASCII para MVP Perú, original/canónico, trim externo y lowercase ASCII,
unicidad global, sin equivalencias de proveedores; rechazo de formato inválido,
espacios internos, Unicode y exceso de longitud. Admite identidades pendientes/sin
credencial; autenticación normal exige identidad activa y correo verificado.
No se interpreta como aprobación de gramática exacta, máximos numéricos, estados
concretos, flujo de verificación ni implementación.

Inspección estática: AGENTS raíz, contexto, ADR-003, registro de decisiones,
diseño D2.1-B, plan de persistencia, contrato web y roadmap. Lecturas/búsquedas
PowerShell/rg exit 0; sin errores de permisos. Compatibilidad: concreta pendientes
de ADR-003, no modifica gobierno ADR-001/002 ni contratos PostgreSQL B1.
Código actual sin autenticación: no se afirma verificación ejecutable de D01.

Creado docs/decisions/B2-decisions.md como registro canónico: D01 aprobada;
D02–D10 pendientes, con alternativas, recomendaciones, riesgos/esquema y pruebas
futuras. Incluye comparación CSRF HMAC vinculado a sesión/AES-256-GCM, recomendación
HMAC pendiente de aprobación, keyring/rotación/binding/fallo cerrado. Se consultaron
fuentes oficiales OWASP CSRF/password y NIST GCM, enlazadas en ese documento.
Argon2id definitivo sujeto a benchmark futuro autorizado; no benchmark ejecutado.

Sincronizados ADR-003, docs/decisions/README.md, diseño B, plan de persistencia,
contrato web, PROJECT_CONTEXT.md y ROADMAP.md. Corregidas referencias históricas
a roles B1 no verificados/Goose bootstrap y diferencia password_credentials frente
al nombre propuesto identity_credentials. Sin cambio del cierre ni duplicación
de pruebas B1; no se declara ejecución Goose ni carga privada de credenciales.

Cambios exclusivamente documentales. B2-A/B2-B sin autorización de implementación;
D02–D10 requieren revisión humana. Sin código, migraciones, SQL, Docker, tests,
infraestructura, roles, credenciales, secretos, deploy, push ni acceso a Celtas.

## D2.1-B2 — aprobación documental D02/D06 y propuesta D03–D05 — 2026-10-14

Fuente: aprobación expresa del usuario como diseño, no implementación.
D02: pending/active/disabled, active requiere correo verificado; verificación no
concede acceso/membresías; deshabilitación incrementa epoch global atómicamente
y rehabilitación no resucita sesiones. Gramática ASCII restringida del análisis
anterior y máximos 254 total/64 local/253 dominio/63 etiqueta; original conserva
case sin espacios externos. Sin envío, recuperación ni activación pública.

D06: HMAC-SHA-256 ligado a identidad/sesión/audiencia/generación/salt, clave CSRF
independiente fuera de DB/repositorios, token estable por generación sin TTL propio,
rotación por key_id y retención mientras existan sesiones válidas dependientes,
Origin estricto, fallo cerrado y hmac.Equal. Codificación binaria, formato exacto
del token y procedimiento operativo de rotación siguen especificaciones pendientes.
No prelogin, MFA ni step-up implementados.

Inspección estática de registro B2, ADR-003, contexto/roadmap y contratos; lecturas
y búsquedas PowerShell/rg exit 0, sin errores de permisos. Compatible con D01 y
ADR-003; no cambia B1 ni implica implementación de sesiones. Corregidas clasificaciones
antiguas de D02/D06 y texto de token CSRF aleatorio de sesión frente a HMAC aprobado.
password_credentials sigue nombre histórico; identity_credentials continúa propuesta D03.

Actualizados docs/decisions/B2-decisions.md, ADR-003, registro de decisiones,
PROJECT_CONTEXT.md, ROADMAP.md, diseño B, plan de persistencia y contrato web.
Preparada matriz D03–D05 con contratos, alternativas, recomendaciones, riesgos,
esquema y aceptación futura; no decisiones aprobadas nuevas. D04 definitivo depende
de benchmark autorizado. D03–D05/D07–D10 y especificaciones D02/D06 pendientes.
B2-A/B2-B no autorizados. No SQL, Docker, tests, código/migraciones, roles,
credenciales, infraestructura, deploy, push o acceso a Celtas.

## D2.1-B2 — aprobación de diseño D03–D05 y matriz D07–D10 — 2026-10-14

Fuente: aprobación expresa del usuario. D03 aprueba identity.identity_credentials
0..1 PK/FK identity_id, UUIDv4 criptográfico Go y credential_revision durable en
Identity. Crear/sustituir/eliminar incrementan revisión; cambios semánticos de
password incrementan epoch global atómicamente; rehash equivalente condicional
incrementa revisión sin revocar. Ausencia no habilita otro login.

D04 aprueba PHC v19, salt16/hash32, sin pepper, perfiles explícitos de creación/
verificación, parser/límites antes de Argon2 y rehash seguro sin degradación.
Candidatos benchmark: 19 MiB/t2/p1, 64 MiB/t2/p1, 64 MiB/t3/p1.
Parámetros definitivos y límites de password/concurrencia/memoria/latencia pendientes
de benchmark y aprobación; no se midieron ni se autoriza benchmark por este registro.

D05 aprueba RNG32, base64url canónica sin padding de 43 caracteres, SHA-256 de
bytes originales y solo digest32 UNIQUE, session_id independiente. Entrega después
de commit confirmado; commit ambiguo falla cerrado sin retry ciego. Sin tokens en
logs/trazas/URLs/respuestas públicas ordinarias; futura integración cookie segura.

Inspección documental y búsquedas PowerShell/rg exit 0, sin errores de permisos.
Compatible con ADR-003, D01/D02 y HMAC CSRF D06 independiente. Primer parche
documental compuesto rechazado por contexto/orden de hunks; sin cambios aplicados
en ese intento ni error de permisos. Ediciones posteriores aplicadas y referencias
revisadas mediante lectura, sin tests. Corregidas clasificaciones históricas de
D03–D05/nombre de credencial y de formato token/Argon2 todavía como recomendaciones.

Registro B2 actualizado conservando matrices previas como históricas; nueva matriz
D07–D10 pendiente: revocación, transacciones, rol auth y tiempo/alcance B2-A/B2-B,
con alternativas/riesgos/aceptación futura. Otros archivos actualizados: ADR-003,
índice de decisiones, PROJECT_CONTEXT.md, ROADMAP.md, diseño B, plan de persistencia
y contrato web. Solo decisiones de diseño, no funcionalidades implementadas.
Pendientes: D07–D10, especificaciones D02/D06 y parámetros operativos D04.
B2-A/B2-B no autorizados; sin SQL, Docker, tests, código/migraciones, roles, pools,
credenciales, infraestructura, deploy, push ni acceso a Celtas.

## D2.1-B2 — aprobación de diseño D07–D10 y bloqueos B2-A — 2026-10-14

Fuente: aprobación expresa del usuario, exclusivamente documental.
D01–D10 quedan aprobadas como diseño, ninguna funcionalidad B2 implementada.
D07: epochs global/audiencia durables monotónicos no negativos; filas admin/platform
atómicas con Identity, snapshots ambos en sesiones, logout revoked_at; primera
contraseña incrementa global, rehash no revoca; ausencia/overflow falla cerrado,
sin resets ni revocación afirmada ante fallo.
D08: READ COMMITTED/locks identidad→audiencia→sesión, Argon2 fuera, revalidación
posterior estado/revisión/epochs; no upgrades; rehash separado condicional;
autorización bajo locks, sin retroactividad prometida ni retries iniciales;
commit ambiguo no éxito/secretos. D09: rol/pool auth independiente sin negocio,
ownership/DDL/migración/elevación; grants/query y provisión por autorizar separados.
D10: tiempo PostgreSQL tras locks; admin12h/7d, platform15min/8h; igualdad expira,
absoluto inmutable, expired_at terminal persistido, automático no renueva;
actividad interactiva autorizada limitada a absoluto. Avisos/reautenticación y
recuperación operativa/SSE siguen futuros; no endpoints ni SSE implementados.

Registro consolidado actualizado: matrices previas históricas y aprobación vigente
separadas; lista priorizada de DDL, CSRF, queries/grants, límites transaccionales,
retención/cleanup y gates de autorización B2-A/B2-B. Evaluación de 30 días para
sesiones inválidas marcada NO aprobada; no se aplica a cuentas/epochs/pedidos/claves.
Parámetros/límites Argon2id y benchmark permanecen pendientes; no bloquean representar
PHC en esquema, sí uso runtime B2-B. DDL D02/CSRF/keyring aún por especificar.

Lecturas/búsquedas locales exit 0, sin errores de permisos. Contradicciones de estado
D07–D10 y rol auth recomendado pendiente corregidas; código vigente sin pools/sesiones
no contradice diseño, solo evidencia ausencia de implementación. Registro, ADR-003,
índice de decisiones, contexto, roadmap, diseño B, plan y contrato web sincronizados.
Sin duplicar pruebas B1. No SQL/Docker/tests/código/migraciones/roles/pools/credenciales,
infraestructura, deploy, push ni acceso a Celtas. B2-A/B2-B siguen no autorizados.

## D2.1-B2-A — especificación documental propuesta — 2026-10-14

Autorización: consolidar documentación técnica y corregir referencia histórica B1
del README SQL; no implementación. Leídos AGENTS raíz/API, README SQL, registro B2,
evidencia vigente, contexto/roadmap y encabezado del diseño. Lecturas exit 0, sin
errores de permisos. Evidencia B1 confirma 002 aplicado y 010/020 aprobados;
el README aún decía pendientes: corregido solo ese texto y enlace al contrato B2-A.
Scripts B1 no modificados ni repetidos.

Creado docs/architecture/b2-a-specification.md como propuesta para aprobación humana:
cuatro tablas/columnas/defaults/checks/FK/índices, canonicalización ASCII, guards,
catálogo de operaciones/locks/actores, funciones restringidas/ejecutores NOLOGIN,
grants por firma y provisión separada, plan de aceptación futura. D01–D10 permanecen
aprobadas, sin convertir recomendaciones técnicas o 30 días de retención en aprobación.

Pendientes explícitos: firmas/queries/privilegios de ejecutores y asignación ownership,
DDL/guards, tamaños CSRF/capPHC, contención/timeouts, ancla/lotes/índice cleanup y gates.
SECURITY DEFINER no prueba equivalencia de rehash ni MFA: frontera Go sigue confiable.
Revocación epoch sin fecha por sesión no permite inferir 30 días exactos; propuesta
conservadora hasta expiración natural o terminalidad explícita. Ningún PASS dinámico.

Referencias actualizadas en registro B2, diseño D2.1-B y ROADMAP; documentación
histórica conservada. No SQL funcional/migraciones/código/roles/pools/secretos,
Docker/SQL/tests, deploy/push/producción ni acceso a Celtas.
B2-A/B2-B no autorizados; solo cambios documentales.

## D2.1-B2-A — diseño técnico aprobado y plan A–F — 2026-10-14

Fuente: aprobación expresa del usuario de recomendaciones finales de diseño y
trece precisiones; autorización exclusivamente documental. D01–D10 no se modifican.
Se registra ownership de funciones administrativo/versionado/transaccional separado
de Goose/B1; dos ejecutores NOLOGIN mínimos; auth sin EXECUTE global/audiencia y
privilegiadas sin caller operativo B2. Logout requiere frontera confiable de autoridad/
posesión: digest no acredita autorización. CSRF textoASCII1–32/generación>=1/salt32,
locks S→S→X cortos y guards sin orden inverso aprobados como diseño.

Retención30d desde terminalidad conocida aprobada; epoch sin fecha individual puede
conservar hasta natural+30d, sin afectar Identity/credenciales/epochs/auditoría.
Cleanup actor separado, lote100 candidato a medir; timeouts locales candidatos no
definitivos de producción. No se declaró benchmark, provisión o prueba B2 realizada.

Actualizados contrato B2-A, registro B2, diseño B, plan persistencia, contexto y roadmap.
Plan A–F: A tablas/constraints, B guards/índices/integridad, C paquete administrativo
funciones/manifiesto, D provisión/grants/aislamiento, E cleanup/concurrencia,
F aceptación integral. Cada entrega define archivos futuros/dependencias/criterios/
pruebas/riesgos/permisos separados; no archivos funcionales creados.
Funciones/grants de otro owner ya no se proponen como Goose normal del migrator B1.
Sin ampliación de B1 ni bootstrap repetido. Lecturas locales exit0, sin permisos fallidos.

Bloqueo para comenzar escritura A: autorización específica aún no concedida.
DDL exacto será resultado revisable, no requiere provisionar auth o ejecutar antes.
Ejecución requiere target desechable/baseline/preflight/autorización SQL propios.
Benchmark D04 y CSRF binario/keyring continúan bloqueando B2-B, no almacenamiento PHC.
Sin SQL funcional/código/migraciones/Docker/SQL/tests/roles/credenciales/cleanup,
deploy/push/producción o acceso a Celtas. B2-A no implementada/migrada/verificada.

## D2.1-B2-A — entrega C escrita; revisión estática — 2026-10-14

Autorización del usuario: escribir funciones y manifiesto C; sin aplicación SQL,
provisión, grants efectivos, Docker, migraciones ni pruebas PostgreSQL. A/B ya
escritas según el usuario; Codex volvió a leer sus archivos y comprobar sus hashes,
sin repetir bootstrap B1 ni afirmar ejecución de A/B.

Creado tomopedidos-api/db/administration/b2a-auth-functions-v1.sql, instalación
administrativa inicial transaccional fuera de Goose: nueve firmas/retornos explícitos,
siete normales y dos revocaciones privilegiadas sin caller operativo. Ownership
previsto tomopedidos_auth_executor / tomopedidos_auth_revoke_executor NOLOGIN;
ningún rol creado. SQL contiene retiro de EXECUTE por firma y aserciones de owner,
fuente/ACL/search_path, pero no se ejecutó: ningún permiso efectivo modificado.
SHA-256 del archivo: D22C52F086E06A7AFEE3CC59C57C1F03631EA74446FD9315D15A79F392B023C2.

Creado manifiesto db/administration/manifests/b2a-auth-v1.yaml con firmas,
retornos, fuentes SHA-256 LF normalizadas, dependencias/hashes, owners previstos,
ACL inicial owner-only y matriz de permisos por columna pendiente de D. Creado
runbook docs/runbooks/b2a-function-lifecycle.md: instalación/actualización/drift,
rollback/commit ambiguo, contratos, locks, logging y plan de pruebas no ejecutado.

Verificaciones Codex reales: lecturas Get-Content/rg, inspección local de directorios,
Get-FileHash SHA256 y cálculo estático de hashes de nueve cuerpos con SHA256 .NET.
Últimas llamadas de lecturas/hashes exit 0. La búsqueda de raíces fue:
Get-ChildItem -LiteralPath D:\tomopedidos -Force -Recurse -Filter .git -ErrorAction Stop
(solo lectura, exit 0). Encontró únicamente
D:\tomopedidos\.cache\ignore-check-20342382-7a79-40f3-8be3-633d197d98df\.git,
un repositorio temporal, sin raíz Git del proyecto. No se usó ese repo ni git init/diff.
Una lectura opcional del directorio docs/runbooks aún inexistente devolvió exit 1
antes de crearlo; no hubo error de permisos ni operación PostgreSQL/Docker.

Hashes A/B conservados:
- 00001: AC7CA512915A8290FE20D5A3003C30BCD78407AB55DCC630923A65EADDAF4258.
- 00002: 13909AD7561780C9CC55A38A8B789A64D12C511E7A94BB4ACDA3036F12BB3F83.
- 00003: B1DC89967190A919E861F1B7FD77EB6E8EFCA9BA44DDA35B30C4D14AB7621B31.

Sin incompatibilidad que requiera modificar A/B. Discrepancias documentales:
encabezados antiguos aún niegan escritura B2, y ADR-003 dice retención30d propuesta,
aunque el contrato consolidado la aprueba. Reportadas en runbook sin reabrir D01–D10.
Go/sqlc aún no ofrecen contratos ejecutables auth/pool; C no los implementa.

Pendientes: revisión humana de firmas/ACL, destino desechable y autorizaciones de
aplicación/provisión/D, compilación PLpgSQL y pruebas reales de integridad/aislamiento/
concurrencia/contención/fallos. Frontera Go para contraseña/rehash/autoridad/CSRF,
Argon2id benchmark y CSRF binario/keyring permanecen pendientes B2-B.
No credenciales/token bruto/clave CSRF/datos reales en artefactos o evidencia.
C escrita y revisada estáticamente; NO aplicada, operativa ni verificada en PostgreSQL.
No limpieza, producción, deploy, push, código Go ni acceso a Celtas.

## B2-A C — recuperación después del reinicio — 2026-10-14

Alcance autorizado: inspección y correcciones de C, hashes/diffs y revisión
estática. Prohibidos SQL, Goose, Docker, PostgreSQL, provisión/grants efectivos,
cambios B1, deploy/push y acceso a Celtas. Destino de esta revisión: únicamente
archivos locales de D:\tomopedidos; ninguna conexión a base de datos.

Estado recuperado: C ya estaba escrita, con paquete SQL administrativo v1,
manifiesto y runbook completos, y registro de revisión estática anterior en esta
misma evidencia. El paquete termina en COMMIT; contiene nueve definiciones,
retiros de EXECUTE y asignaciones de owner por firma, preflight y aserciones
finales. Esto describe texto existente, no ejecución ni permisos efectivos.
No se encontraron archivos temporales/backup/merge relacionados con C en la
búsqueda efectuada. No se duplicaron ni reescribieron artefactos funcionales.

Integridad comprobada mediante Get-FileHash -Algorithm SHA256 sobre
tomopedidos-api/db/migrations/*.sql y
tomopedidos-api/db/administration/b2a-auth-functions-v1.sql (exit 0):

| Archivo | SHA-256 actual, igual al registro previo y manifiesto |
| --- | --- |
| 00001_identity_credentials.sql | AC7CA512915A8290FE20D5A3003C30BCD78407AB55DCC630923A65EADDAF4258 |
| 00002_audience_sessions.sql | 13909AD7561780C9CC55A38A8B789A64D12C511E7A94BB4ACDA3036F12BB3F83 |
| 00003_identity_guards_indexes.sql | B1DC89967190A919E861F1B7FD77EB6E8EFCA9BA44DDA35B30C4D14AB7621B31 |
| b2a-auth-functions-v1.sql | D22C52F086E06A7AFEE3CC59C57C1F03631EA74446FD9315D15A79F392B023C2 |

Lecturas Get-Content -Encoding utf8, rg --files y rg -n: contexto raíz/API,
decisiones B2, especificación A–F, evidencia, A/B y los tres artefactos C;
lecturas/inventario exit 0. Revisados estáticamente contratos, locks ordenados,
tiempo tras locks, epochs, terminalidad, rehash separado y fronteras de autoridad.
Conservadas D01–D10 y retención30d aprobadas. Encabezados históricos que niegan
escritura B2 siguen desactualizados, como ya advierte el runbook; no se cambió
documentación de otras entregas ni se interpretaron como autorización de ejecución.
El prompt anterior no está disponible en esta sesión: su alcance se recuperó
del registro previo de C, especificación y runbook, limitado por el permiso actual.

git status --short y git -C tomopedidos-api status --short devolvieron
"fatal: not a git repository (or any of the parent directories): .git".
Se emitieron dentro de llamadas de lectura cuyo último comando devolvió 0;
no se capturó por separado el código de Git. No hay diff Git disponible,
no se creó un repositorio ni se utilizó el repositorio temporal de .cache.

Comprobador auxiliar PowerShell/.NET en memoria: regex de CREATE FUNCTION,
SHA256 sobre cuerpo UTF-8 normalizado LF y comparación textual de returns_sql.
Terminó con exit 1 y "Return mismatch: lookup_credential". El patrón de
extracción de entrada YAML restringía el contenido a una línea antes de buscar
la siguiente firma, por lo que no extrajo el bloque completo. No acredita
un retorno SQL incorrecto. Se detuvo sin reintentar ni modificar artefactos;
no se declara aprobada la comprobación automatizada completa de nueve cuerpos
y retornos. La coincidencia del hash del archivo SQL completo sí fue comprobada
independientemente antes de este error. No se ejecutó ningún contenido SQL.

Único archivo modificado durante recuperación: docs/verification.md, mediante
adición de este registro. C recuperada como entrega escrita; no se identificó
escritura funcional pendiente ni incompatibilidad que justifique modificar A/B.
Pendiente revisión humana y comprobación estática automatizada completa;
compilación PLpgSQL, instalación, ownership/ACL efectivos, aislamiento,
concurrencia y fallos siguen sin verificación PostgreSQL y requieren autorización
separada y destino desechable. No se avanzó a D/E/F ni B2-B.

## D2.1-B2-A — entrega D preparada; revisión estática — 2026-10-14

Autorización vigente del usuario: escribir/revisar D y corregir verificadores
auxiliares no destructivos. No ejecutar SQL/Goose/Docker/PostgreSQL, provisionar
roles, modificar permisos efectivos, B1/A/B/C, cleanup, deploy/push ni Celtas.
Destino de todo trabajo ejecutado: archivos locales de D:\tomopedidos.

Inspeccionados AGENTS raíz/API, PROJECT_CONTEXT, decisiones B2, especificación
A–F, evidencia, migraciones A/B, bootstrap B1 y SQL/manifiesto/runbook C.
Lecturas Get-Content -Encoding utf8 y rg locales exit 0. Los encabezados
históricos de documentación se conservan; prevalece la autorización actual
de escritura D sin inferir permiso de ejecución. No hay diff Git del proyecto.

Discrepancia de nombres reportada antes de escribir D: el pedido menciona
revoke_audience_privileged/revoke_global_privileged, pero C declara
identity.revoke_audience(bytea, text) e identity.revoke_global(bytea, text).
Se preservaron contratos C. D revoca/deniega las firmas reales y sus aserciones
rechazan aliases inesperados con el sufijo privileged. No se duplicaron funciones.

Archivos nuevos, todos preparados/no aplicados:

- db/administration/b2a-role-preflight.sql: include de aserciones administrativas/B1.
- db/administration/b2a-role-provision-v1.sql: provisión inicial separada de tres roles.
- db/administration/b2a-assert-state.sql: metadatos y privilegios efectivos por estado.
- db/administration/b2a-auth-grants-v1.sql: derechos mínimos de ejecutores, sin caller.
- db/administration/b2a-auth-enable-v1.sql: habilitación independiente del caller.
- db/administration/b2a-auth-disable-v1.sql: reversión enabled → executors.
- db/administration/b2a-auth-ungrant-v1.sql: reversión executors → c.
- db/administration/manifests/b2a-roles-v1.yaml: roles, matriz por columna/firma,
  etapas y veinte hashes de archivos/dependencias. Rutas db bajo tomopedidos-api.
- db/verification/040_b2a_role_isolation.sql: assertions de lectura, ROLLBACK.
- db/verification/041_b2a_caller_negatives.sql: intentos por login real, ROLLBACK;
  26 negativos auth y 33 tenant preparados, ninguno ejecutado.
- db/verification/check_b2a_contracts.ps1: reemplaza comprobación auxiliar fallida
  de recuperación; formato YAML restringido, sin cliente DB ni dependencias externas.
- db/verification/check_b2a_delivery_d.ps1: grants/pins/includes/inventario offline.
- docs/runbooks/b2a-role-isolation.md: orden, prerrequisitos, rollback, drift,
  commit ambiguo, autenticación privada y pruebas pendientes.

Roles previstos: tomopedidos_auth_executor y tomopedidos_auth_revoke_executor
NOLOGIN; tomopedidos_auth_runtime LOGIN con PASSWORD NULL, sin autenticación
configurada. Todos NOINHERIT y sin atributos elevados, memberships ni settings.
No se ejecutó CREATE ROLE ni se estableció contraseña. NOLOGIN no se considera
garantía de denegación de SET ROLE por sí solo: memberships se verifican aparte.

Grants previstos: quince grupos exactos SELECT/INSERT/UPDATE por columna conforme
al manifiesto C, USAGE identity a ejecutores; siete EXECUTE normales + CONNECT/
USAGE al caller solo en paquete enable separado. Sin tabla completa, grant option,
DELETE, mantenimiento, secuencias, CREATE/TEMP, negocio ni memberships. Dos scopes
privilegiados owner-only, sin caller operativo. Tenant/PUBLIC sin identity/C.
Ownership se valida contra C, no se cambia por D; B1 conserva roles/schema/default ACL.
Permiso UPDATE(audience) normal sirve para FOR SHARE y queda limitado por guard B;
no se le concede epoch de audiencia. Ejecutor privilegiado tiene UPDATE(expired_at)
para lock y terminalidad, sin actividad/logout/credenciales.

Verificaciones estáticas efectivamente ejecutadas:

1. `& ./tomopedidos-api/db/verification/check_b2a_contracts.ps1`, exit 0:
   PASS para nueve firmas; compara tipos/nombres/orden de parámetros y retornos,
   source SHA-256 UTF-8/LF y owners, y hashes de bytes exactos A/B/C. Ninguna
   discrepancia real SQL/YAML. No afirma parseo YAML general ni compilación SQL.
2. `& ./tomopedidos-api/db/verification/check_b2a_delivery_d.ps1`, exit 0:
   PASS 15 grupos de columna frente al plan C, siete EXECUTE normales solamente,
   revokes privilegiados, pins y dependencias de includes existentes, inventario
   de negativos/ROLLBACK y ausencia de cambios funcionales/default ACL en paquetes D.
   Repetido tras corregir metacomando psql de variable ausente; exit 0 final.
3. Get-FileHash -Algorithm SHA256, lecturas y revisión textual de todos los SQL
   nuevos, manifiesto/runbook/verificadores: exit 0. No SQL enviado a un cliente.

SHA-256 finales:

- D manifiesto: A1962156E42F4D121A350A9A2FC2608F204D684F21A2B01090C05758858A7CDB.
- B1 001, sin editar: 2EAA920E1DF044DDA6003FE347511F092347BBD26CEDB22EF0BB91F6CF83D5B2.
- B1 002, sin editar: 2AF021298BBBF5B58B942618C543941E6D80DC46E6EDE66F195FBB3A10A6E122.
- A/B 00001–00003 y C SQL coinciden con hashes registrados en recuperación;
  C YAML/runbook también fijados en el manifiesto D, sin modificar sus bytes.
- Los veinte hashes individuales restantes están en pinned_files del manifiesto D.

Incidencias locales conservadas: intento `python --version` devolvió exit 1 con
"Python was not found". No instalación ni retry; se usó PowerShell/.NET existente.
Primera generación auxiliar del manifiesto devolvió exit 1 porque la ruta relativa
a docs/runbooks usaba cinco niveles superiores en lugar de cuatro. No escribió
manifiesto incompleto ni ejecutó SQL; corregida bajo autorización explícita de
auxiliares no destructivos. Generación corregida y verificadores exit 0.
Revisión de documentación oficial PostgreSQL 18 detectó que `\quit 3` no es un
metacomando de salida con código documentado; 040 usa valor missing cuando falta
la variable y su guard SQL produce error bajo ON_ERROR_STOP. Corrección solo D,
recalculados pins; no se ejecutó psql para comprobarlo.

Referencias técnicas revisadas online: documentación oficial PostgreSQL 18 GRANT,
SELECT, functions-info, CREATE ROLE y psql; enlaces en runbook D. Revisión documental
no equivale a ejecución. No se consultaron sistemas externos de Celtas.

Pendientes/bloqueos de ejecución: autorización concreta y target aislado inequívoco,
aplicación/certificación completa A/B y C, provisión y grants efectivos, compilación
PLpgSQL y sintaxis real de scripts, caminos de funciones con permisos de locks/
triggers, search_path/pg_temp e indirect calls, 040 y negativos TCP independientes,
credenciales/HBA/TLS privados, timeouts/contención/fallos y commit ambiguo reales.
LOGIN/PASSWORD NULL no certifica aislamiento de autenticación: trust/cert/peer se
revisan separadamente. Los roles son del cluster; revisar también privilegios PUBLIC
y acceso potencial a otras bases antes de provisionar, sin corregir otras bases
por estos paquetes. La API confiable, Argon2id y CSRF/keyring siguen pendientes B2-B.

Solo docs/verification.md se modificó entre archivos existentes; trece archivos D
nuevos. No B1/A/B/C funcionales/documentales reescritos. D preparada/revisada
estáticamente, NO provisionada, aplicada ni verificada en PostgreSQL. Sin avance
a E/F, cleanup, producción, deploy/push ni Celtas.

## D2.1-B2-A — entrega E escrita; revisión estática — 2026-10-14

Autorización: crear/revisar archivos funcionales E. No ejecución SQL, Goose,
Docker, PostgreSQL, provisión, permisos efectivos ni cleanup; sin B1/A–D,
Celtas, deploy o push. Trabajo ejecutado únicamente sobre D:\tomopedidos.
Inspeccionados instrucciones raíz/API, PROJECT_CONTEXT, decisiones B2/retención,
especificación A–F, migraciones A/B, contratos reales C, provisión/grants/aserciones
D y runbook D. Lecturas Get-Content/rg locales con exit 0.

Antes de escribir, `& ./tomopedidos-api/db/verification/check_b2a_delivery_d.ps1`
dio exit 0: nueve contratos C, quince grupos de columna D, pins/dependencias
A–D/B1. No incompatibilidad que requiriera modificar esas entregas. E se coloca
en administration/retention para conservar el inventario administrativo D; sus
aserciones de derechos también rechazarían EXECUTE de E a auth/tenant.

Quince archivos nuevos:

- tomopedidos-api/db/migrations/00004_session_cleanup_index.sql: Up/Down índice E.
- tomopedidos-api/db/administration/retention/b2a-session-cleanup-v1.sql: función
  administrativa inicial, owner/grants mínimos del ejecutor, caller dormant.
- En el mismo directorio: b2a-cleanup-assert.sql, b2a-cleanup-role-provision-v1.sql,
  b2a-cleanup-enable-v1.sql, b2a-cleanup-disable-v1.sql,
  b2a-session-cleanup-down-v1.sql y b2a-cleanup-batch.sql.
- tomopedidos-api/db/administration/manifests/b2a-retention-v1.yaml: política,
  firmas, roles propuestos/grants y quince pins, incluyendo manifiesto D que fija
  transitivamente A–C/B1. Sin secretos ni credenciales reales.
- tomopedidos-api/db/verification/050_b2a_retention_concurrency.sql,
  051_b2a_cleanup_failures.sql y 052_b2a_cleanup_metadata.sql.
- tomopedidos-api/db/verification/isolation/b2a_cleanup.spec.
- tomopedidos-api/db/verification/check_b2a_delivery_e.ps1.
- docs/runbooks/b2a-session-retention.md.

Política materializada: menor fecha entre idle_expires_at, absolute_expires_at,
revoked_at y expired_at; conservar hasta esa terminalidad + 2 592 000 segundos
(30 días transcurridos). LEAST ignora marcas NULL; no se usa created_at ni fecha
inventada de epoch. Epoch-only usa vencimiento natural+30d. Detección tardía no
pospone el vencimiento anterior. Igualdad con cutoff elegible. La función no lee
epochs, PHC, digest/token_hash ni datos CSRF y solo DELETE de identity.sessions.
No eliminación de Identity/credenciales/epochs/auditoría/claves por cleanup.

Firma: identity.cleanup_sessions(integer DEFAULT 100), RETURNS TABLE
(examined integer, deleted integer, skipped integer, checked_at timestamptz).
Límite candidato100 y cap1–100; discovery acotada, cutoff PostgreSQL, padres SHARE
por fases globales ordenadas (todas identidades, luego todas audiencias), sesiones
UPDATE por UUID; sin upgrade ni SKIP LOCKED. Relectura tras esperas, evidencia de
locks de parents y reloj/cutoff por fila; DELETE repite predicado. Retroceso observado
o timestamps futuros producen 22008 y abortan todo lote; errores no se capturan
como éxito. Una llamada/tx corta READ COMMITTED, sin retries y counts solo tras
COMMIT confirmado. GUC local evita uso accidental repetido, no es autoridad.

Índice btree idx_sessions_cleanup_terminal: expresión LEAST exacta + session_id,
sin reloj/now()/intervalos en definición; Goose Up/Down owner tp_owner, no función
definer ni roles por Goose. Uso/coste no certificado: falta EXPLAIN, mediciones
WAL/buffers/actividad/contención y batch/deadline bajo ejecución autorizada.

Actores nuevos propuestos, no provisionados: tomopedidos_cleanup_executor NOLOGIN
owner de una función, y tomopedidos_session_maintenance LOGIN/PASSWORD NULL caller
solo tras enable separado. Ambos NOINHERIT, atributos elevados deshabilitados,
sin memberships/default ACL/settings. Executor: SELECT de keys de padres y nueve
metadatos de sesión, UPDATE(keys) solo para permisos de locks y DELETE sesiones.
B guards impiden rekeying. Caller: CONNECT/USAGE/EXECUTE por una firma, sin tablas.
Auth/tenant/PUBLIC/migrator sin EXECUTE E. Privilegios efectivos todavía no cambiados.
La propuesta requiere aprobación de provisión/credenciales y target propios.

Pruebas preparadas, ninguna ejecutada:

- 050: ocho fixtures de retención, epoch-only vigente/vieja, marca tardía, ancla
  distinta de created_at, batch1 y tamaños inválidos, segunda llamada, frontera
  temporal/NULL y rollback de filas. Final ROLLBACK.
- 051: denegaciones auth/tenant, marca futura tras primera eliminación que debe
  revertir el lote completo, REPEATABLE READ rechazado; transacciones ROLLBACK.
- 052: metadatos/ACL/default100/fuente/índice/guards E y baseline D, lectura/ROLLBACK.
- .spec: doce permutaciones PostgreSQL isolationtester: validate/expiry antes/después
  de cleanup, renovación/logout vigente, global/audiencia en ambos órdenes,
  dos workers y rollback. Setup/teardown escriben/borran solo fixtures sintéticas
  y requieren base totalmente desechable. No isolationtester instalado/invocado;
  expected outputs reales pendientes. SET ROLE admin es fixture, no prueba de login.
- Runbook: escenarios de lock timeout 55P03, cancelación/statement timeout 57014,
  commit ambiguo en ambos resultados del servidor, stress de múltiples parents,
  pg_temp/ACL/login real y discontinuidad temporal. Harness externo/inyección
  siguen pendientes; no se automatiza corte de conexiones ni cambio del reloj.

Validaciones estáticas realmente ejecutadas:

`powershell -NoProfile -File ./tomopedidos-api/db/verification/check_b2a_delivery_e.ps1`
exit 0: encadena contratos C y checker D, confirma A–D intactos; firma/default/
retorno/owner y source hash E, quince pins/includes existentes, DELETE solo sesiones,
30d/cap100, expresión de índice igual a discovery, fases globales de locks,
enable solo maintenance, doce permutaciones sin steps inexistentes/duplicados.
Son comprobaciones textuales/hash, no parser SQL/compilación o pruebas PostgreSQL.
Revisados manualmente SQL completos de función, grants/assertions, Up/Down/job,
fixtures/spec, y compatibilidad con constraints/guards A/B y protocolo C/D.
Lecturas, rg, generación local/pins y Get-FileHash exit 0.

Hashes finales:

- Source E UTF-8/LF: D24C85C89BF7227E77192DCB21A207172BFB9BDE4699B39DCF3AC35288F8B9B7.
- Manifiesto E: C8BEDEA0A4F0F954B631D32E4C78E916C096FB115B579A6A006FDA8F288AFB72.
- 00004: 37BE379E0D91F8ACA0C75A36E6D4B0E39697B8EE9B219BDD479D8C52FF95E223.
- Todos los bytes B1/A–D siguen iguales a pins previos D; no se editó ningún
  artefacto de esas entregas. Pins individuales E en manifiesto, exit 0 verificador.

Incidencia local: primera invocación del checker E tuvo ParserError de Windows
PowerShell 5 (MissingEndParenthesisAfterStatement) al iniciar continuaciones de
condiciones con -or. No ejecutó el cuerpo del checker ni SQL. La llamada contenía
Get-FileHash después y devolvió exit 0 global; NO se interpretó como PASS del checker.
Se corrigió sintaxis solo del archivo E nuevo y actualizó su pin dentro del alcance
de creación/revisión E. Invocación posterior en proceso independiente: exit 0 y
marcas PASS E/C/D reales. No dependencia instalada ni permisos/elevación usados.

Fuentes oficiales PostgreSQL 18 consultadas online: SELECT/locks, índices de expresión,
LEAST/NULL; enlaces en runbook. Revisión documental no demuestra ejecución.

Recuperación prevista: rollback/stop antes de commit; disable y drain, Down administrativo
y 00004 Down después de autorización. Down no restaura sesiones borradas tras COMMIT.
Backup/PITR y retirada cluster de roles requieren inventario/autorización aparte.
Commit ambiguo: outcome unknown, detener scheduler, nueva conexión y reconciliar,
sin claims de counts ni retry ciego. Sin ledger por lote no se atribuye cantidad exacta
frente a otros workers. No se añade ledger/telemetría sensible fuera del contrato.

Pendientes: A–E aplicadas/certificadas en target autorizado, provisión/enable y login
real independientes, compilación PLpgSQL/scripts/spec, negativos permisos efectivos,
EXPLAIN y medición, carreras/harness de fallos/commit/reloj y múltiples identities,
HBA/TLS/secretos privados y autorización de job real. No E aplicada ni verificada
en PostgreSQL. Sin limpieza real, modificación B1/A–D, Celtas, deploy/push o avance F.
Único archivo existente modificado durante E: docs/verification.md (esta adición).

## D2.1-B2-A — entrega F preparada; no ejecución PostgreSQL — 2026-10-14

Permiso vigente: inspección local de solo lectura y preparación de scripts/fixtures/
documentación F. No SQL, Docker, Goose, tests PostgreSQL, creación/eliminación de
instancias/bases/roles/volúmenes, credenciales, cleanup, B1/A–E, Celtas, deploy/push.
Todo comando ejecutado aquí fue lectura/hash o preparación/verificación offline
de archivos bajo D:\tomopedidos. Ninguna conexión o invocación Docker ocurrió.

Leídos AGENTS raíz/API, PROJECT_CONTEXT, especificación A–F/decisiones, Compose,
goose.Dockerfile, go.mod/sqlc.yaml, B1 001/002/010/020, migraciones 00001–00004,
paquetes/manifiestos/verificadores C/D/E y runbooks. Versiones vigentes: PostgreSQL
18.6-bookworm con digest de Compose, Goose v3.29.0 y builder Go1.27; API Go1.26,
sqlc1.31.1 sin cambios ni generación. SQL usa funciones SHA256 core/UUID externos;
no requiere pgcrypto/uuid-ossp. Baseline F exige solo plpgsql inicial.

Incompatibilidades/huecos reportados antes de preparar adaptación:

1. B1 y guards/grants C–E fijan tomopedidos_local; no aceptan DB distinta ni
   identifican cluster por ese nombre. F usa base distinta y copias de ensayo
   controladas, sin editar originales. Solo cambia referencias al destino y añade
   preflight fuera de cuerpos de funciones; migraciones conservan bytes exactos.
2. SET LOCAL search_path pg_catalog en migraciones puede impedir registrar versión
   Goose si la tabla se usa sin calificar; Compose principal no fija ese nombre.
   Comandos F exigen -table migration_meta.goose_db_version, conforme README Goose
   v3.29.0. No Compose principal/migraciones modificados. Riesgo estático, no fallo
   PostgreSQL observado en este turno.
3. C carecía de Down administrativo executable. F control/003_c_down.sql valida
   hash/owner/ACL en estado c y retira exactamente sus nueve firmas, sin CASCADE,
   después de E Down/D disable-ungrant y antes de Down Goose.
4. B1 010 espera ACL de schemas owner-only; no sirve mid-D/E, donde existen nuevos
   USAGE. Se planifica antes de A/D y tras retirada C/D/E, sin editar B1.

Destino PROPUESTO, no creado: proyecto/container/network/volume con prefijo
tp-b2a-f-20261014-r01; DB tp_b2a_f_20261014_r01, cluster_name del run ID, PG180006,
context default, red nueva internal sin puertos publicados ni recursos principales.
System_identifier NULL/PENDIENTE, no inventado ni auto-enrolled. Credenciales F
independientes pendientes; root .env no leída/copied/usada. No baseline B1 aplicado.

Artefactos en tomopedidos-api/db/verification/f y runbook:

- target.json, compose.f.yaml, f-manifest.json (63 pins de preparación/dependencias).
- Prepare-FStage.ps1, stage-manifest.json y stage-target-diff.txt: treinta SQL/spec
  derivados para F, hashes de originales/derivados/reemplazos, comparación de cuerpos;
  staging reproducible no destructivo, sin sobrescribir deriva. Native spec bloqueado
  con __F_SYSTEM_ID_PENDING__ hasta enrollment manual revisado.
- staged/: B1/C/D/E y verificadores copiados con destino F; cuatro migraciones
  byte-idénticas 00001–00004. No son nuevas migraciones del producto ni doble aplicación.
- control/000_identify.sql y 001_preflight.sql: lectura/enrollment y fallo cerrado
  por base/cluster/version/actor/TCP/extensiones/ID. Control ID real verificado por
  bootstrap antes de cada caller/Goose; no otorgar pg_control_system a runtimes.
- control/002_post_down.sql, 003_c_down.sql, 004_migration_metadata.sql.
- control/fixtures/030_integrity.sql: positivos local64/label63/total254/dots+tag,
  corpus 47 rechazos SQLSTATE y guards, helper pg_temp, ROLLBACK.
- control/fixtures/060_auth_primitives.sql y 061_fail_closed.sql: nueve caminos
  SQL C con savepoints separados, emisión/validación/actividad/logout/expiry/scopes/
  rehash, stale/state/digest/audience/overflow/CAS. Fixtures PHC léxicas/digests
  sintéticos, no prueba de contraseña, Argon2id, CSRF, MFA ni autoridad Go. ROLLBACK.
- control/fixtures/070_real_login.sql y 071_maintenance_negatives.sql: TCP real,
  contextos de cuatro logins y doce negativos de maintenance. D 041 conserva sus
  26 auth/33 tenant negativos en copia adaptada, siempre conexiones independientes.
- control/fixtures/090–097: seed COMMIT sintético, holder interactivo, timeout55P03,
  caller cancelable57014, cancelación SOLO PID/base/actor/application_name/wait F
  revalidado, pausa para harness de ACK perdido, reconciliación 0/2 filas en conexión
  nueva y teardown por UUID exacto. PREPARADOS, no ejecutados/cancelados backends.
- Assert-FDockerSnapshot.ps1 y Test-FSnapshotGuard.ps1; tres JSON SINTÉTICOS de
  prueba bajo synthetic-snapshots, no inspecciones reales Docker.
- Print-FCommands.ps1 (solo imprime propuestas, no invoca comandos) y Check-F.ps1.
- docs/runbooks/b2a-f-disposable-verification.md: fases 0–21, checkpoints/orden
  exacto Up/Down/Re-Up, permisos, manuales/herramientas, integridad principal/Celtas.

Orden futuro fijado: crear/enrollar F por autorización → baseline B1 equivalente
solo en F → B1 metadata/probes → credenciales migrator/tenant → Goose Up1,2,3,4
con tabla calificada y version por paso → integridad/metadata → D roles/C install/
D grants/aislamiento executors → D enable para fixtures/paths/logins/negativos →
E roles/install dormant/metadata/enable para fixtures → retention/failures/native
concurrency/fault harness → drain E disable/Down, D disable/ungrant, F C Down →
Goose Down3,2,1,0 y verificación B1 → Re-Up sin reprovisionar roles ni repetir B1.
El plan no ejecuta automáticamente este orden ni configura credenciales/herramientas.

Verificaciones realmente ejecutadas (solo offline):

- powershell -NoProfile -File ./tomopedidos-api/db/verification/f/Prepare-FStage.ps1,
  exit0: 30 SQL/spec staged, cuatro migraciones originales exactas, cuerpos de
  funciones sin cambios. Repetido solo tras añadir diff local, exit0; no SQL.
- powershell -NoProfile -File ./tomopedidos-api/db/verification/f/Test-FSnapshotGuard.ps1,
  exit0: 1 snapshot sintético positivo y 8 negativos rechazados (proyecto principal,
  volumen compartido, puerto, red externa, bind writable, peer externo, imagen e ID
  de red incorrectos). NO evidencia de identidad/acceso Docker real.
- powershell -NoProfile -File ./tomopedidos-api/db/verification/f/Print-FCommands.ps1,
  exit0: imprimió comandos previstos, todos con contexto/proyecto/container/base F
  explícitos, tabla Goose calificada, psql -X/-W/ON_ERROR_STOP y SYSTEM_ID_PENDING.
  Incluye inspect selectivo SIN Config.Env. Ningún comando impreso se ejecutó.
- powershell -NoProfile -File ./tomopedidos-api/db/verification/f/Check-F.ps1,
  exit0 final: encadena checkers C/D/E con PASS, confirma fuentes/pins intactos,
  staging/hashes/includes, aislamiento estructural Compose, cuatro migraciones
  byte-idénticas, nueve Drop C, preview calificado, sintaxis PS y 63 pins F. No es
  compilador SQL, Goose validate, Docker config ni test PostgreSQL.
- Get-Content/rg/Get-FileHash y lecturas finales de preflight/spec: exit0 salvo
  lectura opcional de rutas inexistentes descrita abajo.

Hashes F finales:

- f-manifest.json: 7BA113A415186D35BB5820B105D96C302C3CD031DA8DE072D7E9FB150060FA39.
- stage-manifest.json: 4A49956A8AC28C5E811A13E6E998056C766A33C926629B5B63E64FFAA7A955CD.
- target.json: FBAEDBC5C6904E6A868976780B33795051DAC7CEF928A42EF3EB6BD44CDFFA15.
- compose.f.yaml: 141FC0A5EFE9504CE08AF1A8224F15B34A8BF4A7D0FA49AE4966900D67A4DE4C.
- B1/A–E/Compose principal/goose.Dockerfile conservan pins previos; inventario y
  hashes de fuentes por archivo en stage-manifest/F-manifest. No Git diff disponible;
  diff de adaptación F preparado explícitamente, sin editar fuentes.

Incidencias de inspección: búsqueda rg opcional de tomopedidos-api/.gitignore y
.dockerignore reportó rutas inexistentes, exit1; no retry a esas rutas ni creación
de archivos faltantes. .gitignore raíz se leyó después como fuente independiente.
No operación SQL/Docker fallida ni permisos intentados. Consultas web a rutas
internas Goose inexistentes devolvieron404; no se basó implementación en ellas.
README v3.29.0/CLI y documentación PostgreSQL18 de identidad/control/libpq sí
consultados como fuentes primarias, enlaces en runbook. No dependencia instalada.

Bloqueos para ejecutar: permiso específico creación/env/SQL/fixtures/Goose/grants/
credenciales; acceso/destino Docker actual no probado; volumen nuevo y PG18.6 reales,
system ID aprobado, SCRAM privado, build Goose, isolationtester18 compatible y
harness de commit ACK/reloj/stress. Manuales no omitibles para cierre integral.
PLpgSQL/scripts/spec todavía sin compilación/runtime. Goose status/version también
pueden crear metadata: no tratarlos como consulta inocua antes de autorización.

Principal/Celtas: no acceso actual a sus DB/containers ni .env, sin recursos
compartidos propuestos. Hashes prueban preservación de artefactos inspeccionados,
NO contenido de bases. Evidencia independiente de su operador o permiso de lectura
separado sería necesario para afirmar contenidos intactos; no se emiten consultas
contra esos sistemas. Retirada destructiva de F requiere autorización independiente,
IDs/labels exactos y conservar evidencia; ningún down --volumes automático.

Originales B1/A–E, root Compose/Dockerfile sin modificación. Nuevos artefactos F
incluyen copias deliberadas de ensayo; único archivo existente modificado:
docs/verification.md por esta adición. F preparada; B2-A NO migrada, provisionada,
aplicada ni verificada en PostgreSQL. Sin SQL/Docker/Goose/cleanup/credenciales,
contenedores/roles/bases creados o eliminados, Celtas, deploy ni push.

## F1 — parada antes de creación por prerrequisito de credenciales — 2026-10-14

Autorización limitada recibida: crear/arrancar solo recursos Docker F aprobados,
identificar PostgreSQL mediante lecturas y ejecutar preflight; sin B1, Goose,
roles adicionales, paquetes C/D/E, cleanup ni eliminación de recursos.
Condición expresa: cualquier discrepancia debe reportarse antes de crear.

Inspección local mediante Get-Content -Encoding utf8 de compose.f.yaml,
target.json, control/000_identify.sql, control/001_preflight.sql, runbook y
f-manifest.json; Test-Path del archivo privado propuesto. Llamada exit 0.
Test-Path D:\tomopedidos\.local\b2a-f\r01.private.env devolvió False.
No se leyó root .env ni credenciales del entorno principal.

Coincidencias estáticas: proyecto tp-b2a-f-20261014-r01, contenedor
tp-b2a-f-20261014-r01-pg, base tp_b2a_f_20261014_r01, red interna
tp-b2a-f-20261014-r01-net, volumen tp-b2a-f-20261014-r01-data,
sin ports, binds read-only exclusivamente F. Imagen fijada
postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c.
Servicios definidos: postgres y goose con profile tools; ningún servicio o recurso
Celtas. DSN Goose fija base F/red F, sin fallback al principal.
No se comprobaron aún existencia/exclusividad real de recursos ni digest runtime.

Bloqueo detectado y comunicado antes de invocar Docker: el Compose preparado
requiere F_BOOTSTRAP_PASSWORD y F_MIGRATOR_PASSWORD mediante interpolaciones
obligatorias; su runbook exige ambas al resolver Compose. El archivo privado
no existe. F1 solo autoriza PostgreSQL; todavía no requiere ni autoriza rol
migrator adicional. No se generó credencial migrator para satisfacer un servicio
fuera de F1 ni se cambió el Compose sobre la marcha. Los flags históricos false
del manifiesto no se trataron como revocación de la autorización F1 del usuario.

Estado real: ejecución detenida por condición del usuario; NINGUNA invocación
Docker/SQL/Goose realizada en F1. No recursos, roles, bases ni credenciales creados.
Salud, imagen/digest en ejecución, system_identifier y preflight NO comprobados.
No se aplicó B1 ni B2-A, no se eliminaron recursos ni se accedió al principal/Celtas.

Paso pendiente propuesto: revisar una definición F1 exclusiva de postgres sin
requerimiento migrator, conservar los mismos nombres/digest/red/volumen/binds y
preflight, y establecer solo credencial bootstrap F nueva mediante procedimiento
privado. Reportar/revisar ese ajuste antes de retomar creación, conforme a la parada
expresa. Luego confirmar Docker/destino/existencia de nombres en esta sesión,
crear solo F, identificar cluster y ejecutar lecturas/preflight. No adelantar B1.


## F1 — corrección y parada por comprobación Git — 2026-10-14

Autorización vigente: infraestructura F, credencial bootstrap privada, creación exclusiva Docker F y lecturas/preflight. No baseline B1, Goose, roles adicionales ni cleanup.

Configuración corregida: compose.f.yaml contiene solo postgres y exige únicamente F_BOOTSTRAP_PASSWORD. Nuevo compose.tools.yaml conserva Goose, DSN exclusivo F y F_MIGRATOR_PASSWORD obligatoria para etapas posteriores. Print-FCommands.ps1 usa ambos archivos exclusivamente para los comandos futuros Goose. Runbook actualizado; f-manifest.json repinó solamente estos archivos F/documentación, agregando el archivo tools. No cambios a B1/A–E, staged SQL ni migraciones. Check-F.ps1 exit 0: contratos 9/9 SQL/YAML, checks D/E/F y cuatro migraciones byte-identical aprobados estáticamente; no es verificación PostgreSQL.

Invocaciones Docker separadas, todas exit 0:
- docker --context default version: cliente/servidor 29.8.1, contexto default, Linux amd64.
- docker --context default container ls -a --filter name=tp-b2a-f-20261014-r01 --format '{{.Names}}': salida vacía.
- docker --context default network ls --filter name=tp-b2a-f-20261014-r01-net --format '{{.Name}}': salida vacía.
- docker --context default volume ls --filter name=tp-b2a-f-20261014-r01-data --format '{{.Name}}': salida vacía.

No recursos F preexistentes detectados. Configuración estática conserva imagen/digest aprobados, red interna exclusiva, volumen nuevo, dos binds F read-only y ausencia de puertos. Archivo privado fuera de esos binds y del contexto de build docker/. Ninguna consulta a tomopedidos_local ni Celtas.

Se generó una credencial independiente mediante RNG criptográfico (48 bytes) en D:\tomopedidos\.local\b2a-f\r01.private.env. ACL de directorio y archivo restringida al usuario actual, herencia del archivo deshabilitada. No contraseña impresa ni incluida en argumentos/logs/documentación. No se generó credencial migrator.

ERROR y parada: `git check-ignore -- .local/b2a-f/r01.private.env`, ejecutado en D:\tomopedidos, devolvió exit 128 y `fatal: not a git repository (or any of the parent directories): .git`. El comando envolvente terminó exit 1 mediante guard `Private file not ignored`. La regla .local/ existe en .gitignore, pero la exclusión efectiva mediante Git no quedó comprobada. No se hizo reintento ni corrección posterior a este fallo. La credencial privada permanece en disco; no se eliminó ni sobrescribió.

Estado: NO Docker Compose up/build/pull, NO recursos creados, NO SQL ni preflight ejecutado. Digest runtime, versión PostgreSQL, base real, system_identifier y ausencia runtime de puertos pendientes. Imagen declarada: postgres:18.6-bookworm@sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c. Target/system_identifier continúa sin modificar. F2 bloqueada hasta resolver comprobación de archivo privado y completar F1 con nueva revisión de ausencia de recursos. No B2-A migrada ni verificada.
