# Stored procedure decisions — portfolio refactor

[🇦🇷 Versión en español](stored-procedure-decisions.es.md)

The portfolio version keeps the eight stored procedures defined in the original academic specification.

## Procedures

1. `SP_AltaPersona`
2. `SP_CrearServicio`
3. `SP_InactivarServicio`
4. `SP_CrearTicket`
5. `SP_CambiarEstadoTicket`
6. `SP_ReasignarTicket`
7. `SP_ModificarPersona`
8. `SP_AgregarActividad`

`SP_ReasignarTicket` was present in the written specification but missing from the original `STORE-PROCEDURE.sql`, so it has been implemented for the portfolio version.

## Error contract

The academic project already defined `@ErrorCode` and `@ErrorMessage` outputs. The portfolio refactor makes them the explicit public error contract:

- business-rule failures return a project-defined `500xx` code;
- expected validation errors do not raise a second SQL exception;
- unexpected database errors are caught and returned using SQL Server's error number and message.

This avoids the original `RAISERROR -> CATCH -> ERROR_NUMBER()` pattern that could overwrite a project-defined code with a generic SQL Server error number.

## Transactions

Transactions remain limited to procedures that coordinate multiple related writes:

- `SP_CrearServicio`
- `SP_InactivarServicio`
- `SP_CrearTicket`
- `SP_CambiarEstadoTicket`

Single-row operations remain non-transactional at the procedure level, matching the original specification.

## Additional consistency rules

- `SP_CrearTicket` records the initial history event as `NULL -> ABI`.
- `SP_CambiarEstadoTicket` follows the definitive state machine implemented by `FN_ValidarTransicionEstado`.
- `fecha_resolucion` is set on transition to `RES`.
- `fecha_cierre` is set on transition from `RES` to `CER`.
- `SP_AgregarActividad` writes to the definitive `Actividades.fecha` column.
- Internet services reject a supplied telephone instead of silently discarding it.
- Creating a service for a prospect requires a valid email, birth date, and adult age.
- Service identifiers consume `dbo.Seq_NumeroServicio` and are formatted through `FN_GenerarNumeroServicio`.

## Testing

`tests/02-stored-procedures-smoke-tests.sql` exercises both successful flows and important validation failures.

The test runs inside an outer transaction and rolls back its entity data at the end. SQL Server sequences are not transactional, so the service-number sequence can advance after the test; this is expected.
