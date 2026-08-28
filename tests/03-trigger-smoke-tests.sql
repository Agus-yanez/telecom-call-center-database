/*
    Telecom Call Center Database
    Trigger smoke tests

    Prerequisites:
      01-create-database.sql
      02-schema.sql
      03-seed-data.sql
      04-functions.sql
      05-stored-procedures.sql
      06-triggers.sql

    The test scenario is wrapped in a transaction and rolled back.
*/

USE TelecomCallCenterDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

PRINT 'Running trigger smoke tests...';
GO

BEGIN TRY
    BEGIN TRANSACTION;

    DECLARE @ErrorCode INT;
    DECLARE @ErrorMessage VARCHAR(500);
    DECLARE @idTicket INT;

    /* ========================================================
       1. Create a ticket.
          Ticket creation itself must NOT generate a notification,
          because the trigger is AFTER UPDATE only.
       ======================================================== */

    EXEC dbo.SP_CrearTicket
        @id_persona = 1,
        @id_empleado_dueno = 1,
        @id_servicio = 1,
        @id_tipologia = 4,
        @id_ticket_generado = @idTicket OUTPUT,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0 OR @idTicket <= 0
        THROW 53001, 'Could not create the ticket required for trigger testing.', 1;

    IF EXISTS (
        SELECT 1
        FROM dbo.Email_Notificacion
        WHERE id_ticket = @idTicket
    )
        THROW 53002, 'Ticket creation should not generate a status-change notification.', 1;


    /* ========================================================
       2. ABI -> EPR must create exactly one pending notification.
       ======================================================== */

    EXEC dbo.SP_CambiarEstadoTicket
        @id_ticket = @idTicket,
        @id_estado_nuevo = 'EPR',
        @id_usuario_ejecuta = 1,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0
        THROW 53003, 'ABI -> EPR failed during trigger testing.', 1;

    IF (
        SELECT COUNT(*)
        FROM dbo.Email_Notificacion
        WHERE id_ticket = @idTicket
    ) <> 1
        THROW 53004, 'ABI -> EPR should generate exactly one notification.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Email_Notificacion
        WHERE id_ticket = @idTicket
          AND id_estado_anterior = 'ABI'
          AND id_estado_nuevo = 'EPR'
          AND fecha_envio IS NULL
    )
        THROW 53005, 'The ABI -> EPR notification contains unexpected values.', 1;


    /* ========================================================
       3. Updating a non-status field must NOT create a notification.
       ======================================================== */

    UPDATE dbo.Ticket
    SET id_empleado = 2
    WHERE id_ticket = @idTicket;

    IF (
        SELECT COUNT(*)
        FROM dbo.Email_Notificacion
        WHERE id_ticket = @idTicket
    ) <> 1
        THROW 53006, 'A non-status UPDATE should not create a notification.', 1;


    /* ========================================================
       4. EPR -> PCL by the new owner must create a second one.
       ======================================================== */

    EXEC dbo.SP_CambiarEstadoTicket
        @id_ticket = @idTicket,
        @id_estado_nuevo = 'PCL',
        @id_usuario_ejecuta = 2,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0
        THROW 53007, 'EPR -> PCL failed during trigger testing.', 1;

    IF (
        SELECT COUNT(*)
        FROM dbo.Email_Notificacion
        WHERE id_ticket = @idTicket
    ) <> 2
        THROW 53008, 'EPR -> PCL should generate a second notification.', 1;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Email_Notificacion
        WHERE id_ticket = @idTicket
          AND id_estado_anterior = 'EPR'
          AND id_estado_nuevo = 'PCL'
          AND fecha_envio IS NULL
    )
        THROW 53009, 'The EPR -> PCL notification contains unexpected values.', 1;


    /* ========================================================
       5. Direct no-op assignment of the same state must not notify.
       ======================================================== */

    UPDATE dbo.Ticket
    SET id_estado_ticket = id_estado_ticket
    WHERE id_ticket = @idTicket;

    IF (
        SELECT COUNT(*)
        FROM dbo.Email_Notificacion
        WHERE id_ticket = @idTicket
    ) <> 2
        THROW 53010, 'Assigning the same state should not generate a notification.', 1;


    /* ========================================================
       6. Multi-row UPDATE support.

          Create two additional tickets and update both states in one
          statement. A correct trigger must insert two notifications.
       ======================================================== */

    DECLARE @idTicket2 INT;
    DECLARE @idTicket3 INT;

    EXEC dbo.SP_CrearTicket
        @id_persona = 1,
        @id_empleado_dueno = 1,
        @id_servicio = 1,
        @id_tipologia = 4,
        @id_ticket_generado = @idTicket2 OUTPUT,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0 OR @idTicket2 <= 0
        THROW 53011, 'Could not create ticket #2 for the multi-row trigger test.', 1;

    EXEC dbo.SP_CrearTicket
        @id_persona = 1,
        @id_empleado_dueno = 1,
        @id_servicio = 1,
        @id_tipologia = 4,
        @id_ticket_generado = @idTicket3 OUTPUT,
        @ErrorCode = @ErrorCode OUTPUT,
        @ErrorMessage = @ErrorMessage OUTPUT;

    IF @ErrorCode <> 0 OR @idTicket3 <= 0
        THROW 53012, 'Could not create ticket #3 for the multi-row trigger test.', 1;

    UPDATE dbo.Ticket
    SET id_estado_ticket = 'EPR'
    WHERE id_ticket IN (@idTicket2, @idTicket3);

    IF (
        SELECT COUNT(*)
        FROM dbo.Email_Notificacion
        WHERE id_ticket IN (@idTicket2, @idTicket3)
          AND id_estado_anterior = 'ABI'
          AND id_estado_nuevo = 'EPR'
          AND fecha_envio IS NULL
    ) <> 2
        THROW 53013, 'The trigger did not handle a multi-row status update correctly.', 1;


    ROLLBACK TRANSACTION;

    PRINT 'OK - All trigger smoke tests passed.';
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO
