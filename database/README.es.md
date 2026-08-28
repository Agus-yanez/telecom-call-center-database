# Instalación reproducible

[English version](README.md)

La base de datos está dividida intencionalmente en scripts ordenados en lugar de utilizar un único dump opaco.

Ejecutá estos archivos en orden sobre Microsoft SQL Server:

1. `01-create-database.sql`
2. `02-schema.sql`
3. `03-seed-data.sql`
4. `04-functions.sql`
5. `05-stored-procedures.sql`
6. `06-triggers.sql`

Los scripts actuales están diseñados para una **instalación nueva** del esquema.

`01-create-database.sql` crea `TelecomCallCenterDB` únicamente si la base todavía no existe. El resto de los scripts utiliza sentencias `CREATE` normales, por lo que volver a ejecutar la instalación completa sobre una base ya inicializada no se considera un mecanismo idempotente de actualización.

Para reinicios durante desarrollo, utilizá una base descartable o eliminá y recreá explícitamente `TelecomCallCenterDB` antes de volver a ejecutar la instalación ordenada.

Después de la instalación, ejecutá los scripts ubicados en `../tests/` para validar la base.
