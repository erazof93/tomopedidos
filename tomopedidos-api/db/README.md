# SQL (sin tablas funcionales)
Entorno y tooling D2.1-A preparados; 001_roles.sql aplicado y verificado por el usuario.
Sin tablas de aplicación ni migraciones funcionales aplicadas; D2.1-B1 completada
para roles, cinco schemas vacíos, privilegios y autenticación PostgreSQL local.
B2–B5 no iniciados ni autorizados; evidencia en ../../docs/verification.md.
Migraciones futuras: NNNNN_nombre.sql con -- +goose Up / -- +goose Down.
Mantener db/schema como snapshot SQL revisado para sqlc; no duplicar lógica de aplicación.
No ejecutar migraciones externas. Diseñar y probar RLS antes de introducir datos de tenants.

[Guía local y comandos PowerShell](../../docs/local-postgresql.md). Goose y sqlc fijados
en tools/versions.json; no usar latest. B1 prepara bootstrap/verification fuera de Goose;
[privilegios y evidencia B1](../../docs/development-b1.md). 002 aplicado y 010/020 aprobados
según docs/verification.md; no repetir scripts. [Especificación B2-A propuesta](../../docs/architecture/b2-a-specification.md),
sin autorización de implementación ni ejecución.
No ejecutar bootstrap, pruebas SQL ni Goose status/up/down sin autorización de ejecución.
La API no migra al arrancar; migrations/schema/queries siguen sin SQL funcional.

