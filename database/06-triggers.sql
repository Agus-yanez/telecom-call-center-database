/*
    Telecom Call Center Database
    Step 06 - Triggers

    Portfolio refactor based on the original academic project.
    Target DBMS: Microsoft SQL Server

    Trigger:
      TRG_Ticket_GenerarNotificacion

    Purpose:
      Register a pending notification whenever a ticket changes state.

    Notes:
      - The trigger is set-based and supports multi-row UPDATE statements.
      - It does not create notifications for INSERT operations.
      - It ignores UPDATE statements where id_estado_ticket does not change.
      - fecha_envio remains NULL until an external notification process
        actually sends the message.
*/

USE TelecomCallCenterDB;
GO

SET NOCOUNT ON;
GO

CREATE OR ALTER TRIGGER dbo.TRG_Ticket_GenerarNotificacion
ON dbo.Ticket
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO dbo.Email_Notificacion (
        id_ticket,
        id_estado_anterior,
        id_estado_nuevo,
        fecha_envio
    )
    SELECT
        i.id_ticket,
        d.id_estado_ticket,
        i.id_estado_ticket,
        NULL
    FROM inserted AS i
    INNER JOIN deleted AS d
        ON d.id_ticket = i.id_ticket
    WHERE i.id_estado_ticket <> d.id_estado_ticket;
END;
GO
