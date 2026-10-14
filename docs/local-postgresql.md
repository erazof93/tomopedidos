# PostgreSQL y herramientas Docker locales — D2.1-A

Estado: **D2.1-A completada con evidencia del usuario**: PostgreSQL 18.6 healthy,
TCP autenticado/SELECT 1, Compose válido, Goose v3.29.0 y sqlc v1.31.1 ejecutados mediante
Docker. Codex verificó archivos/configuración; su acceso Engine permanece bloqueado.
No se presenta esa ejecución Docker externa como propia. B1 tiene rutas y scripts
preparados; 001 aplicado y verificado por el usuario, 002/010/020 pendientes;
[cierre B1](development-b1.md): D2.1-B1 completada según evidencia vigente;
los estados de preparación de esta guía son históricos. B2–B5 no autorizados.

## Operación habitual desde Windows PowerShell

Desde D:\tomopedidos con contexto Docker local:

```powershell
Set-Location D:\tomopedidos
# Solo necesario si .env falta; conserva valores existentes.
node scripts/init-local-db.cjs
docker compose config --quiet
docker compose up -d --wait
docker compose ps
# Después de up para reconciliar variables del contenedor:
docker compose exec -T postgres sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -h 127.0.0.1 -X -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1;"'
# Optativo al terminar las pruebas; conserva el volumen.
docker compose stop postgres
```

Ejecutar por pasos; detenerse si falla. pg_isready/healthy prueba disponibilidad,
SELECT 1 TCP prueba contraseña. No imprimir config/inspect completos ni passwords.
No usar trust, down -v, limpiar/reinicializar volumen o tocar contenedores Celtas.
Parada es comando conservador documentado, no se afirma que Codex la haya ejecutado.

## Goose y sqlc: Docker como flujo principal

| Herramienta | Configuración vigente | Evidencia |
| --- | --- | --- |
| Goose | docker/goose.Dockerfile; go install v3.29.0 en builder golang:1.27-bookworm | Usuario ejecutó v3.29.0 |
| sqlc | Servicio Compose, imagen sqlc/sqlc:1.31.1 | Usuario ejecutó v1.31.1 |

Coinciden con tools/versions.json. Servicios bajo profile tools: el arranque habitual
solo levanta PostgreSQL; herramientas son contenedores efímeros por comando.
Único Dockerfile Goose vigente: [docker/goose.Dockerfile](../docker/goose.Dockerfile).
El Dockerfile duplicado de raíz fue eliminado por el usuario; no es parte del flujo.

```powershell
# Construir si la imagen local no existe:
docker compose --profile tools build goose
# Solo versiones; --no-deps evita arrancar/recrear PostgreSQL innecesariamente:
docker compose --profile tools run --rm --no-deps goose -version
docker compose --profile tools run --rm --no-deps sqlc version
```

No reinstalar Windows para usar Docker. scripts/db-tools.ps1 es una alternativa nativa
con versiones fijadas, conservada por compatibilidad; no es requisito para cierre.
Los tags base de build y sqlc no están fijados por digest: las versiones de herramienta
sí; endurecer digests en revisión posterior, sin afirmar builds idénticos bit a bit.

### Rutas antes de migraciones/generación

Rutas corregidas en B1: Goose monta ./tomopedidos-api/db/migrations en /migrations,
solo lectura. sqlc monta exclusivamente ./tomopedidos-api en /app y encuentra sqlc.yaml
en working_dir /app; no monta .env de raíz. Ambos rechazan origen inexistente.
Bootstrap/verification SQL están fuera de migrations/schema/queries y no se ejecutan
automáticamente. Goose espera tomopedidos_migrator/DB_MIGRATION_PASSWORD sin fallback
bootstrap; driver/datasource, owner tp_owner y search_path migration_meta preparados.
Roles/passwords no aplicados por Codex: migración/conexión pendiente. No ejecutar Goose
status/up/down/create ni sqlc generate con directorios funcionales vacíos.

## Configuración y credenciales

.env raíz es la configuración local principal; Compose la lee automáticamente.
.env.example es plantilla versionable con CHANGE_ME_LOCAL_ONLY. Init crea .env solo
si falta con password criptográfico; .env existente conserva valores y ACL. Nuevos
archivos Windows reciben ACL restringida local, sin cambios globales.
.env, .env.local, .local/, .tools/ y .cache/ están ignorados. Los respaldos antiguos
se conservan y ningún script operativo depende de ellos. No imprimirlos ni copiarlos a Git.
Go API aún no carga .env ni abre PostgreSQL. Shell variables pueden preceder a .env;
comprobar configuración sin revelar valores. [Referencia Compose](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/).

PostgreSQL 18.6-bookworm mantiene digest
sha256:afc7e2d441324c0388fa80c3d24f733b4194a4eb7f47dd8ee2b08eb1a24a647c,
loopback 55432 y volumen tomopedidos-local_postgres_data en /var/lib/postgresql.
Cambiar .env no rota password de base inicializada. El usuario confirmó que ya lo alineó;
no se requiere otra rotación. Ante divergencia futura, conservar volumen y resolver
credencial/rotación explícitamente; no ALTER ROLE automático.

DB_MIGRATION_USER/DB_RUNTIME_USER son nombres previstos, no roles/grants implementados.
No emplear bootstrap en la API. La separación efectiva espera revisión/aplicación de B1.

## Scripts y próximos pasos

init-local-db.cjs y local-db.ps1 siguen útiles para configuración/operación opcional;
ninguno ejecuta migraciones. Pruebas: node --test scripts/init-local-db.test.cjs.
Si .ps1 está restringido, usar comandos Docker directos; no cambiar ExecutionPolicy.

[Verificaciones](verification.md), [roadmap](../ROADMAP.md) y
[propuesta D2.1-B](architecture/d2-1-b-schema-design.md) son referencias vigentes.
El cierre de entorno/herramientas no implementa identidad, tenants, RLS, sesiones ni HTTP.
