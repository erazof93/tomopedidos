# Desarrollo local
## Frontends — exclusivamente pnpm
Node 24 (>=24 <25) y pnpm 11.22.0; packageManager fijado en raíz y aplicaciones.
Workspace de admin/platform con lock único previsto en raíz. Go no pertenece al workspace JS.
store/cache pnpm quedan en .cache/pnpm; no modificar cachés globales ni copiar paquetes.
verifyDepsBeforeRun: error evita que ejecutar un check instale dependencias automáticamente.

Desde raíz, con dependencias disponibles:
```powershell
pnpm install
pnpm install --frozen-lockfile
pnpm run type-check
pnpm run lint
pnpm run format:check
pnpm run test
pnpm run build
```
La instalación estándar fue completada manualmente; conservar pnpm-lock.yaml real junto a package.json y comprobar que no esté ignorado.
Después usar instalación congelada. No crear locks ficticios ni importar indiscriminadamente
el lock de Celtas. No usar npm, pnpx/corepack para instalar otras versiones globales ni
instalaciones manuales. Ante build scripts nuevos, revisar paquetes antes de autorizar
allowBuilds; no habilitar globalmente todos los scripts de dependencias.

Dev optativo: pnpm run dev:admin (5173) o pnpm run dev:platform (5174), loopback.
También pnpm --filter tomopedidos-admin run <script> (o platform).
pnpm run format escribe; checks/build crean artefactos locales.
Estado actualizado (2026-10-13): instalación pnpm y --frozen-lockfile aprobadas manualmente; type-check, lint, test y build aprobados en ambos frontends. format:check no consta ejecutado en la evidencia compartida. Véase verification.md.

## API
Go mínimo 1.26.0 en go.mod; instalado 1.27.2, sin cambio de versión ni toolchain descargado.
En esta sesión Windows no actualizó PATH; usar ejecutable absoluto:
```powershell
Set-Location D:\tomopedidos\tomopedidos-api
$env:GOTOOLCHAIN = 'local'
$env:GOENV = 'off'
$env:GOCACHE = 'D:\tomopedidos\.cache\go\build'
$env:GOMODCACHE = 'D:\tomopedidos\.cache\go\mod'
$env:GOTMPDIR = 'D:\tomopedidos\.cache\go\tmp'
New-Item -ItemType Directory -Path $env:GOTMPDIR -Force | Out-Null
& 'C:\Program Files\Go\bin\go.exe' mod tidy
& 'C:\Program Files\Go\bin\gofmt.exe' -w cmd internal
& 'C:\Program Files\Go\bin\go.exe' test ./...
& 'C:\Program Files\Go\bin\go.exe' vet ./...
& 'C:\Program Files\Go\bin\go.exe' build -o '..\.cache\go\api.exe' ./cmd/api
```
Variables solo del proceso, sin modificar Windows global. Cuando PATH sea actualizado por
una sesión nueva, go/gofmt bastan. No desactivar sum.golang.org ni usar replaces para evadir red.
go mod tidy y go mod verify finalizaron correctamente en PowerShell; comprobar que go.sum esté presente y versionable.
Para prueba sin red del único paquete autónomo: go test ./internal/config y go vet ./internal/config.

APP_ENV=development y HTTP_ADDR=127.0.0.1:8080 por defecto. API no conecta PostgreSQL,
no pide DATABASE_URL y no carga .env automáticamente; usa variables del proceso.
.env.example es plantilla. Frontends validan VITE_API_BASE_URL con Zod y aún no llaman API.
VITE_* es público; nunca secretos.

## SQL
db/migrations: SQL versionado con convención Goose Up/Down; db/schema: snapshot revisado;
db/queries: consultas sqlc; salida internal/database/sqlc con pgx/v5.
Todavía vacíos. D2.1-A cerró con Goose/sqlc mediante Docker según evidencia usuario;
binarios Windows son optativos. No ejecutar generación vacía ni migraciones sin aprobación.
[PostgreSQL local y herramientas PowerShell](local-postgresql.md) es la guía operativa única.
No se configuran bases externas en esta fase.

[Workspace pnpm](https://pnpm.io/workspaces),
[settings/build](https://pnpm.io/settings/build),
[toolchains Go](https://go.dev/doc/toolchain).
