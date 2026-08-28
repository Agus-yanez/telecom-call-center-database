/*
    Telecom Call Center Database
    Function smoke tests

    Prerequisites:
      01-create-database.sql
      02-schema.sql
      03-seed-data.sql
      04-functions.sql

    The script throws an error when an invariant is not satisfied.
*/

USE TelecomCallCenterDB;
GO

SET NOCOUNT ON;
GO

PRINT 'Running function smoke tests...';
GO

/* FN_ValidarEmail */
IF dbo.FN_ValidarEmail('ana@example.com') <> 1
    THROW 51001, 'FN_ValidarEmail rejected a valid email.', 1;

IF dbo.FN_ValidarEmail('ana@@example.com') <> 0
    THROW 51002, 'FN_ValidarEmail accepted an email with two @ characters.', 1;

IF dbo.FN_ValidarEmail('ana example.com') <> 0
    THROW 51003, 'FN_ValidarEmail accepted an email containing spaces.', 1;


/* FN_ValidarDocumento */
IF dbo.FN_ValidarDocumento('12345678') <> 1
    THROW 51004, 'FN_ValidarDocumento rejected an 8-digit document.', 1;

IF dbo.FN_ValidarDocumento('1234567') <> 1
    THROW 51005, 'FN_ValidarDocumento rejected a 7-digit document.', 1;

IF dbo.FN_ValidarDocumento('12A45678') <> 0
    THROW 51006, 'FN_ValidarDocumento accepted non-digit characters.', 1;


/* FN_GenerarNumeroServicio */
IF dbo.FN_GenerarNumeroServicio(1, 100001) <> 'TEL-100001'
    THROW 51007, 'FN_GenerarNumeroServicio returned an unexpected TEL identifier.', 1;

IF dbo.FN_GenerarNumeroServicio(2, 100002) <> 'INT-100002'
    THROW 51008, 'FN_GenerarNumeroServicio returned an unexpected INT identifier.', 1;

IF dbo.FN_GenerarNumeroServicio(3, 100003) <> 'VOIP-100003'
    THROW 51009, 'FN_GenerarNumeroServicio returned an unexpected VOIP identifier.', 1;

IF dbo.FN_GenerarNumeroServicio(99, 100004) IS NOT NULL
    THROW 51010, 'FN_GenerarNumeroServicio should return NULL for an unknown service type.', 1;


/* FN_ValidarTransicionEstado */
IF dbo.FN_ValidarTransicionEstado('ABI', 'EPR') <> 1
    THROW 51011, 'ABI -> EPR should be valid.', 1;

IF dbo.FN_ValidarTransicionEstado('ABI', 'PCL') <> 1
    THROW 51012, 'ABI -> PCL should be valid.', 1;

IF dbo.FN_ValidarTransicionEstado('EPR', 'RES') <> 1
    THROW 51013, 'EPR -> RES should be valid.', 1;

IF dbo.FN_ValidarTransicionEstado('RES', 'CER') <> 1
    THROW 51014, 'RES -> CER should be valid.', 1;

IF dbo.FN_ValidarTransicionEstado('ABI', 'CER') <> 0
    THROW 51015, 'ABI -> CER should be invalid.', 1;

IF dbo.FN_ValidarTransicionEstado('CER', 'ABI') <> 0
    THROW 51016, 'CER should not allow new transitions.', 1;


/* FN_CalcularEdad */
IF dbo.FN_CalcularEdad(CONVERT(DATE, GETDATE())) <> 0
    THROW 51017, 'FN_CalcularEdad should return 0 for a birth date equal to today.', 1;

IF dbo.FN_CalcularEdad(DATEADD(DAY, 1, CONVERT(DATE, GETDATE()))) IS NOT NULL
    THROW 51018, 'FN_CalcularEdad should return NULL for a future birth date.', 1;


/*
    Sample ticket created by 03-seed-data.sql:
      opening:     2025-06-01 09:00
      resolution:  2025-06-02 08:00  => 23 elapsed hours
      PCL:         12:00 -> 16:00    => 4 paused hours
      effective:                     => 19 hours
*/
IF dbo.FN_CalcularTiempoResolucion(1) <> 19
    THROW 51019, 'FN_CalcularTiempoResolucion should return 19 for sample ticket #1.', 1;

IF dbo.FN_VerificarCumplimientoSLA(1) <> 1
    THROW 51020, 'FN_VerificarCumplimientoSLA should report compliance for sample ticket #1.', 1;


/* Nonexistent ticket */
IF dbo.FN_CalcularTiempoResolucion(-1) IS NOT NULL
    THROW 51021, 'Resolution time should be NULL for a nonexistent ticket.', 1;

IF dbo.FN_VerificarCumplimientoSLA(-1) IS NOT NULL
    THROW 51022, 'SLA result should be NULL for a nonexistent ticket.', 1;


PRINT 'OK - All function smoke tests passed.';
GO
