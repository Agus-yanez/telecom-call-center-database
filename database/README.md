# Reproducible installation

[🇦🇷 Versión en español](README.es.md)

The database is intentionally split into ordered scripts instead of a single opaque dump.

Run these files in order against Microsoft SQL Server:

1. `01-create-database.sql`
2. `02-schema.sql`
3. `03-seed-data.sql`
4. `04-functions.sql`
5. `05-stored-procedures.sql`
6. `06-triggers.sql`

The current scripts are designed for a **fresh installation** of the schema.

`01-create-database.sql` creates `TelecomCallCenterDB` only when the database does not already exist. The remaining schema script uses ordinary `CREATE` statements, so rerunning the complete installation on an already initialized database is intentionally not treated as an idempotent upgrade mechanism.

For development resets, use a disposable database or explicitly drop/recreate `TelecomCallCenterDB` before running the ordered installation again.

After installation, execute the scripts under `../tests/` to validate the database.
