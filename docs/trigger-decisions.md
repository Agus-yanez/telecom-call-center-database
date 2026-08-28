# Trigger decisions — portfolio refactor

The original academic project included a notification trigger associated with ticket status changes. The portfolio version keeps that idea and makes the implementation explicit and set-based.

## Trigger

`TRG_Ticket_GenerarNotificacion`

The trigger runs `AFTER UPDATE` on `dbo.Ticket`.

When `id_estado_ticket` changes, it inserts one row into `dbo.Email_Notificacion` with:

- `id_ticket`
- previous state
- new state
- `fecha_envio = NULL`

The database therefore records that a notification is pending. It does **not** claim to send email itself.

## Why `AFTER UPDATE`

Ticket creation is already represented in `Estados_Historicos` as `NULL -> ABI`. The notification trigger is intended only for actual state changes after creation, so an initial ticket insert does not create a notification.

## Set-based implementation

The trigger joins SQL Server's `inserted` and `deleted` pseudo-tables and does not assume that an UPDATE affects only one row.

This is important because SQL Server triggers fire once per statement, not once per row.

## No-op updates

The condition:

`i.id_estado_ticket <> d.id_estado_ticket`

prevents a notification when an UPDATE statement touches a ticket but leaves the state unchanged.

## Separation of responsibilities

- `SP_CambiarEstadoTicket` validates the legal state transition and records history.
- `TRG_Ticket_GenerarNotificacion` reacts to a persisted state change and queues a notification record.
- An external application/service would later send the email and populate `fecha_envio`.

This keeps business validation, auditing, and notification delivery as separate concerns.

## Testing

`tests/03-trigger-smoke-tests.sql` verifies:

1. ticket creation does not notify;
2. a valid state transition creates one pending notification;
3. a non-status update does not notify;
4. a second state transition creates a second notification;
5. assigning the same state does not notify;
6. a multi-row UPDATE generates one notification per changed ticket.

The test runs in a transaction and rolls back all rows created during the scenario.
