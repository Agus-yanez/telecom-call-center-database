/*
    Telecom Call Center Database
    Stored procedure smoke tests

    Prerequisites:
      01-create-database.sql
      02-schema.sql
      03-seed-data.sql
      04-functions.sql
      05-stored-procedures.sql

    The complete test scenario is wrapped in an outer transaction and
    rolled back at the end, so entity data created by this script is not
    retained. SQL Server sequence values are not rolled back; gaps in the
    service-number sequence are therefore expected and valid.
*/

USE TelecomCallCenterDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

PRINT 'Running stored procedure smoke tests...';
GO

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ErrorCode INT;
    DECLARE @ErrorMessage VARCHAR(500);

    DECLARE @idPersona INT;
    DECLARE @idPersonaSinDatos INT;
    DECLARE @idServicio INT;
    DECLARE @numeroServicio VARCHAR(20);
    DECLARE @idTicket INT;
    DECLARE @idActividad INT;

    /* ========================================================
       1. SP_AltaPersona - success
       ======================================================== */

    EXEC dbo.SP_AltaPersona
        @Nombre = 'Portfolio',
        @Apellido = 'Test',
        @Tipo_documento = 'DNI',
        @Nro_documento = '44556677',
        @Email = 'portfolio.test@example.com',
        @Fecha_nacimiento = '1995-01-15',
        @id_persona_generado = @idPersona OUTPUT,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0 OR @idPersona <= 0
        THROW 52001, 'SP_AltaPersona failed to create a valid prospect.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Persona
        WHERE id_persona = @idPersona
          AND id_estado_persona = 'PRO'
    )
        THROW 52002, 'SP_AltaPersona did not create the person as PRO.', 1;


    /* Duplicate document must be rejected */
    DECLARE @idDuplicado INT;

    EXEC dbo.SP_AltaPersona
        @Nombre = 'Duplicate',
        @Apellido = 'Test',
        @Tipo_documento = 'DNI',
        @Nro_documento = '44556677',
        @Email = NULL,
        @Fecha_nacimiento = NULL,
        @id_persona_generado = @idDuplicado OUTPUT,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 50006 OR @idDuplicado <> 0
        THROW 52003, 'SP_AltaPersona should reject duplicate documents with error 50006.', 1;


    /* ========================================================
       2. SP_ModificarPersona - prospect modification
       ======================================================== */

    EXEC dbo.SP_ModificarPersona
        @id_persona = @idPersona,
        @Nombre = 'Portfolio Updated',
        @Apellido = NULL,
        @Fecha_nacimiento = NULL,
        @Email = NULL,
        @id_usuario_ejecuta = 1,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0
        THROW 52004, 'SP_ModificarPersona rejected a valid prospect modification.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Persona
        WHERE id_persona = @idPersona
          AND nombre = 'Portfolio Updated'
    )
        THROW 52005, 'SP_ModificarPersona did not persist the expected name.', 1;


    /* ========================================================
       3. SP_CrearServicio - success and person promotion
       ======================================================== */

    EXEC dbo.SP_CrearServicio
        @id_persona = @idPersona,
        @id_tipo_servicio = 2,
        @telefono = NULL,
        @calle = 'Avenida Portfolio',
        @numero = '100',
        @piso = NULL,
        @depto = NULL,
        @id_servicio_generado = @idServicio OUTPUT,
        @numero_servicio_generado = @numeroServicio OUTPUT,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0 OR @idServicio <= 0
        THROW 52006, 'SP_CrearServicio failed to create a valid Internet service.', 1;

    IF @numeroServicio NOT LIKE 'INT-%'
        THROW 52007, 'SP_CrearServicio returned an unexpected Internet service number.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Persona
        WHERE id_persona = @idPersona
          AND id_estado_persona = 'ACT'
    )
        THROW 52008, 'SP_CrearServicio did not promote the person to ACT.', 1;


    /* Active customers cannot change name */
    EXEC dbo.SP_ModificarPersona
        @id_persona = @idPersona,
        @Nombre = 'Forbidden Change',
        @Apellido = NULL,
        @Fecha_nacimiento = NULL,
        @Email = NULL,
        @id_usuario_ejecuta = 1,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 50062
        THROW 52009, 'SP_ModificarPersona should reject name changes for non-PRO persons.', 1;


    /* Prospect without email/birth date cannot contract service */
    EXEC dbo.SP_AltaPersona
        @Nombre = 'Incomplete',
        @Apellido = 'Prospect',
        @Tipo_documento = 'DNI',
        @Nro_documento = '55667788',
        @Email = NULL,
        @Fecha_nacimiento = NULL,
        @id_persona_generado = @idPersonaSinDatos OUTPUT,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0 OR @idPersonaSinDatos <= 0
        THROW 52010, 'Could not create the incomplete prospect needed for validation testing.', 1;

    DECLARE @idServicioFallido INT;
    DECLARE @numeroServicioFallido VARCHAR(20);

    EXEC dbo.SP_CrearServicio
        @id_persona = @idPersonaSinDatos,
        @id_tipo_servicio = 2,
        @telefono = NULL,
        @calle = 'Calle Test',
        @numero = '200',
        @piso = NULL,
        @depto = NULL,
        @id_servicio_generado = @idServicioFallido OUTPUT,
        @numero_servicio_generado = @numeroServicioFallido OUTPUT,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 50011 OR @idServicioFallido <> 0
        THROW 52011, 'SP_CrearServicio should reject incomplete prospects with error 50011.', 1;


    /* ========================================================
       4. SP_CrearTicket
       Internet + Servicio Degradado is compatible in seed data.
       ======================================================== */

    EXEC dbo.SP_CrearTicket
        @id_persona = @idPersona,
        @id_empleado_dueno = 1,
        @id_servicio = @idServicio,
        @id_tipologia = 2,
        @id_ticket_generado = @idTicket OUTPUT,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0 OR @idTicket <= 0
        THROW 52012, 'SP_CrearTicket failed to create a valid ticket.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Ticket
        WHERE id_ticket = @idTicket
          AND id_estado_ticket = 'ABI'
          AND id_empleado = 1
    )
        THROW 52013, 'SP_CrearTicket did not create the expected ABI ticket.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Estados_Historicos
        WHERE id_ticket = @idTicket
          AND id_estado_anterior IS NULL
          AND id_estado_nuevo = 'ABI'
    )
        THROW 52014, 'SP_CrearTicket did not create the initial NULL -> ABI history event.', 1;


    /* ========================================================
       5. SP_AgregarActividad
       ======================================================== */

    EXEC dbo.SP_AgregarActividad
        @id_ticket = @idTicket,
        @Nombre = 'Diagnostico inicial',
        @Descripcion = 'Actividad generada por smoke test.',
        @id_usuario_ejecuta = 1,
        @id_actividad_generado = @idActividad OUTPUT,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0 OR @idActividad <= 0
        THROW 52015, 'SP_AgregarActividad rejected a valid activity.', 1;


    /* ========================================================
       6. SP_ReasignarTicket
       ======================================================== */

    EXEC dbo.SP_ReasignarTicket
        @id_ticket = @idTicket,
        @id_empleado_nuevo = 3,
        @id_usuario_ejecuta = 1,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 50054
        THROW 52016, 'SP_ReasignarTicket should reject an inactive destination employee.', 1;

    EXEC dbo.SP_ReasignarTicket
        @id_ticket = @idTicket,
        @id_empleado_nuevo = 2,
        @id_usuario_ejecuta = 1,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0
        THROW 52017, 'SP_ReasignarTicket rejected a valid reassignment.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Ticket
        WHERE id_ticket = @idTicket
          AND id_empleado = 2
    )
        THROW 52018, 'SP_ReasignarTicket did not persist the new owner.', 1;


    /* Old owner cannot change status after reassignment */
    EXEC dbo.SP_CambiarEstadoTicket
        @id_ticket = @idTicket,
        @id_estado_nuevo = 'EPR',
        @id_usuario_ejecuta = 1,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 50041
        THROW 52019, 'SP_CambiarEstadoTicket should reject a non-owner.', 1;


    /* ========================================================
       7. SP_CambiarEstadoTicket - complete legal path
       ======================================================== */

    EXEC dbo.SP_CambiarEstadoTicket
        @id_ticket = @idTicket,
        @id_estado_nuevo = 'EPR',
        @id_usuario_ejecuta = 2,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0
        THROW 52020, 'ABI -> EPR should succeed.', 1;

    EXEC dbo.SP_CambiarEstadoTicket
        @id_ticket = @idTicket,
        @id_estado_nuevo = 'RES',
        @id_usuario_ejecuta = 2,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0
        THROW 52021, 'EPR -> RES should succeed.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Ticket
        WHERE id_ticket = @idTicket
          AND id_estado_ticket = 'RES'
          AND fecha_resolucion IS NOT NULL
          AND fecha_cierre IS NULL
    )
        THROW 52022, 'RES should set fecha_resolucion but not fecha_cierre.', 1;

    EXEC dbo.SP_CambiarEstadoTicket
        @id_ticket = @idTicket,
        @id_estado_nuevo = 'CER',
        @id_usuario_ejecuta = 2,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0
        THROW 52023, 'RES -> CER should succeed.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Ticket
        WHERE id_ticket = @idTicket
          AND id_estado_ticket = 'CER'
          AND fecha_resolucion IS NOT NULL
          AND fecha_cierre IS NOT NULL
          AND fecha_cierre >= fecha_resolucion
    )
        THROW 52024, 'CER should preserve resolution and set closure.', 1;


    /* Closed tickets reject activities */
    DECLARE @idActividadCerrada INT;

    EXEC dbo.SP_AgregarActividad
        @id_ticket = @idTicket,
        @Nombre = 'Actividad invalida',
        @Descripcion = 'No debe insertarse.',
        @id_usuario_ejecuta = 2,
        @id_actividad_generado = @idActividadCerrada OUTPUT,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 50071 OR @idActividadCerrada <> 0
        THROW 52025, 'SP_AgregarActividad should reject closed tickets.', 1;


    /* ========================================================
       8. SP_InactivarServicio
       The portfolio test person has a single active service.
       ======================================================== */

    EXEC dbo.SP_InactivarServicio
        @id_servicio = @idServicio,
        @id_usuario_ejecuta = 1,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0
        THROW 52026, 'SP_InactivarServicio rejected a valid deactivation.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Servicio
        WHERE id_servicio = @idServicio
          AND id_estado_servicio = 'INA'
    )
        THROW 52027, 'SP_InactivarServicio did not mark the service as INA.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Persona
        WHERE id_persona = @idPersona
          AND id_estado_persona = 'INA'
    )
        THROW 52028, 'SP_InactivarServicio did not inactivate the person after their last active service.', 1;


    /*
        Confirm the status history contains the complete path:
        NULL -> ABI -> EPR -> RES -> CER
    */
    IF (
        SELECT COUNT(*)
        FROM dbo.Estados_Historicos
        WHERE id_ticket = @idTicket
    ) <> 4
        THROW 52029, 'Unexpected number of status-history events for the test ticket.', 1;


    ROLLBACK TRANSACTION;

    PRINT 'OK - All stored procedure smoke tests passed.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO
