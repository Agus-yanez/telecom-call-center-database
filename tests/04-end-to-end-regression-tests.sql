/*
    Telecom Call Center Database
    Step 09 - End-to-end / integrity regression tests

    Prerequisites:
      01-create-database.sql
      02-schema.sql
      03-seed-data.sql
      04-functions.sql
      05-stored-procedures.sql
      06-triggers.sql

    Purpose:
      Validate the main business flow and database-level integrity rules
      after all schema objects have been installed.

    Notes:
      - Test data is wrapped in a transaction and rolled back.
      - SQL Server SEQUENCE values are not rolled back; gaps are expected.
*/

USE TelecomCallCenterDB;
GO

SET NOCOUNT ON;
/*
    XACT_ABORT remains OFF in this regression script because several
    test cases intentionally provoke FK / UNIQUE / CHECK violations and
    catch them to verify database-level integrity. With XACT_ABORT ON,
    an expected constraint error can leave the outer transaction
    uncommittable and invalidate subsequent test cases.
*/
SET XACT_ABORT OFF;
GO

PRINT 'Running end-to-end and integrity regression tests...';
GO

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ErrorCode INT;
    DECLARE @ErrorMessage VARCHAR(500);
    DECLARE @idPersona INT;
    DECLARE @idServicio INT;
    DECLARE @numeroServicio VARCHAR(20);
    DECLARE @idTicket INT;
    DECLARE @idActividad INT;

    /* ========================================================
       1. Full business flow
       Prospect -> Active customer -> Service -> Ticket
       -> Activity -> State flow -> Closed -> Service inactive
       -> Person inactive
       ======================================================== */

    EXEC dbo.SP_AltaPersona
        @Nombre = 'Integration',
        @Apellido = 'Test',
        @Tipo_documento = 'DNI',
        @Nro_documento = '66778899',
        @Email = 'integration.test@example.com',
        @Fecha_nacimiento = '1992-04-10',
        @id_persona_generado = @idPersona OUTPUT,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0 OR @idPersona <= 0
        THROW 54001, 'Could not create the integration-test person.', 1;

    EXEC dbo.SP_CrearServicio
        @id_persona = @idPersona,
        @id_tipo_servicio = 2,
        @telefono = NULL,
        @calle = 'Avenida Integracion',
        @numero = '500',
        @piso = NULL,
        @depto = NULL,
        @id_servicio_generado = @idServicio OUTPUT,
        @numero_servicio_generado = @numeroServicio OUTPUT,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0 OR @idServicio <= 0
        THROW 54002, 'Could not create the integration-test service.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Persona
        WHERE id_persona = @idPersona
          AND id_estado_persona = 'ACT'
    )
        THROW 54003, 'Creating a service should promote the prospect to ACT.', 1;

    EXEC dbo.SP_CrearTicket
        @id_persona = @idPersona,
        @id_empleado_dueno = 1,
        @id_servicio = @idServicio,
        @id_tipologia = 2,
        @id_ticket_generado = @idTicket OUTPUT,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0 OR @idTicket <= 0
        THROW 54004, 'Could not create the integration-test ticket.', 1;

    EXEC dbo.SP_AgregarActividad
        @id_ticket = @idTicket,
        @Nombre = 'Diagnostico',
        @Descripcion = 'Prueba end-to-end del flujo de actividad.',
        @id_usuario_ejecuta = 1,
        @id_actividad_generado = @idActividad OUTPUT,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0 OR @idActividad <= 0
        THROW 54005, 'Could not add an activity to the integration-test ticket.', 1;

    EXEC dbo.SP_CambiarEstadoTicket
        @id_ticket = @idTicket,
        @id_estado_nuevo = 'EPR',
        @id_usuario_ejecuta = 1,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0
        THROW 54006, 'ABI -> EPR failed in the end-to-end flow.', 1;

    EXEC dbo.SP_CambiarEstadoTicket
        @id_ticket = @idTicket,
        @id_estado_nuevo = 'PCL',
        @id_usuario_ejecuta = 1,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0
        THROW 54007, 'EPR -> PCL failed in the end-to-end flow.', 1;

    EXEC dbo.SP_CambiarEstadoTicket
        @id_ticket = @idTicket,
        @id_estado_nuevo = 'EPR',
        @id_usuario_ejecuta = 1,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0
        THROW 54008, 'PCL -> EPR failed in the end-to-end flow.', 1;

    EXEC dbo.SP_CambiarEstadoTicket
        @id_ticket = @idTicket,
        @id_estado_nuevo = 'RES',
        @id_usuario_ejecuta = 1,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0
        THROW 54009, 'EPR -> RES failed in the end-to-end flow.', 1;

    EXEC dbo.SP_CambiarEstadoTicket
        @id_ticket = @idTicket,
        @id_estado_nuevo = 'CER',
        @id_usuario_ejecuta = 1,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0
        THROW 54010, 'RES -> CER failed in the end-to-end flow.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Ticket
        WHERE id_ticket = @idTicket
          AND id_estado_ticket = 'CER'
          AND fecha_resolucion IS NOT NULL
          AND fecha_cierre IS NOT NULL
    )
        THROW 54011, 'The end-to-end ticket did not finish in a consistent closed state.', 1;

    IF (
        SELECT COUNT(*)
        FROM dbo.Estados_Historicos
        WHERE id_ticket = @idTicket
    ) <> 6
        THROW 54012, 'The end-to-end ticket should contain six history events.', 1;

    IF (
        SELECT COUNT(*)
        FROM dbo.Email_Notificacion
        WHERE id_ticket = @idTicket
          AND fecha_envio IS NULL
    ) <> 5
        THROW 54013, 'The end-to-end ticket should contain five pending notifications.', 1;

    EXEC dbo.SP_InactivarServicio
        @id_servicio = @idServicio,
        @id_usuario_ejecuta = 1,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0
        THROW 54014, 'Could not deactivate the integration-test service.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Persona
        WHERE id_persona = @idPersona
          AND id_estado_persona = 'INA'
    )
        THROW 54015, 'The person should become INA after their last active service is deactivated.', 1;


    /* ========================================================
       2. Database-level integrity:
          ticket/service ownership composite foreign key
       ======================================================== */

    BEGIN TRY
        INSERT INTO dbo.Ticket (
            id_persona,
            id_empleado,
            id_estado_ticket,
            id_servicio,
            id_tipologia
        )
        VALUES (
            2,      -- person #2
            1,
            'ABI',
            1,      -- service #1 belongs to person #1
            4
        );

        THROW 54016, 'The database accepted a ticket linked to another person''s service.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 54016
            THROW;

        IF ERROR_NUMBER() <> 547
            THROW 54017, 'Unexpected error while validating ticket/service ownership.', 1;
    END CATCH;


    /* ========================================================
       3. Database-level integrity:
          duplicate document unique key
       ======================================================== */

    BEGIN TRY
        INSERT INTO dbo.Persona (
            nombre,
            apellido,
            tipo_documento,
            nro_documento,
            email,
            fecha_nacimiento,
            id_estado_persona
        )
        VALUES (
            'Duplicate',
            'Document',
            'DNI',
            '12345678', -- already exists in seed data
            NULL,
            NULL,
            'PRO'
        );

        THROW 54018, 'The database accepted a duplicate person document.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 54018
            THROW;

        IF ERROR_NUMBER() NOT IN (2601, 2627)
            THROW 54019, 'Unexpected error while validating document uniqueness.', 1;
    END CATCH;


    /* ========================================================
       4. Database-level integrity:
          positive SLA constraint
       ======================================================== */

    BEGIN TRY
        UPDATE dbo.Tipologia_Servicio
        SET SLA = 0
        WHERE id_tipologia = 4
          AND id_tipo_servicio = 1;

        THROW 54020, 'The database accepted a non-positive SLA.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 54020
            THROW;

        IF ERROR_NUMBER() <> 547
            THROW 54021, 'Unexpected error while validating the SLA CHECK constraint.', 1;
    END CATCH;


    /* ========================================================
       5. Database-level integrity:
          resolution cannot precede opening
       ======================================================== */

    BEGIN TRY
        UPDATE dbo.Ticket
        SET fecha_resolucion = DATEADD(DAY, -1, fecha_apertura)
        WHERE id_ticket = 1;

        THROW 54022, 'The database accepted a resolution timestamp before ticket opening.', 1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 54022
            THROW;

        IF ERROR_NUMBER() <> 547
            THROW 54023, 'Unexpected error while validating ticket date constraints.', 1;
    END CATCH;


    /* ========================================================
       6. Business layer:
          incompatible typology/service combination rejected
       ======================================================== */

    DECLARE @ticketInvalido INT;

    EXEC dbo.SP_CrearTicket
        @id_persona = 1,
        @id_empleado_dueno = 1,
        @id_servicio = 1,      -- Telefonia fija
        @id_tipologia = 2,     -- Servicio Degradado: only Internet in seed
        @id_ticket_generado = @ticketInvalido OUTPUT,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 50034 OR @ticketInvalido <> 0
        THROW 54024, 'SP_CrearTicket should reject incompatible typology/service combinations.', 1;


    /* ========================================================
       7. Function regression:
          known seeded SLA scenario remains stable
       ======================================================== */

    IF dbo.FN_CalcularTiempoResolucion(1) <> 19
        THROW 54025, 'Seeded ticket #1 no longer returns 19 effective resolution hours.', 1;

    IF dbo.FN_VerificarCumplimientoSLA(1) <> 1
        THROW 54026, 'Seeded ticket #1 should still comply with its SLA.', 1;


    ROLLBACK TRANSACTION;

    PRINT 'OK - All end-to-end and integrity regression tests passed.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO
