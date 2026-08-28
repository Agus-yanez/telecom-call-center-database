# Business Rules

[🇦🇷 Versión en español](business-rules.es.md)

This document summarizes the business rules implemented by the portfolio version of the database.

## People

- A person is uniquely identified by `tipo_documento + nro_documento`.
- Document numbers must contain 7 or 8 digits.
- Email is optional, but when supplied it must pass the project email validation.
- Birth date is optional at initial prospect creation, but when supplied the person must be at least 18 years old.
- New people are created with state `PRO` (Prospect).
- Name, surname, and birth date can be changed only while the person is a prospect.
- Email can be changed regardless of person state.
- When a prospect or inactive person receives a new active service, the person becomes `ACT`.
- When the last active service is deactivated, the person becomes `INA`.

## Services

Supported service types in the sample catalog:

1. Fixed telephony
2. Internet
3. VOIP

Rules:

- the person must exist;
- a prospect must have valid email and birth date before contracting a service;
- fixed telephony and VOIP require a telephone number;
- Internet must not store a telephone number;
- street and address number are mandatory;
- services are created as `ACT`;
- service numbers are generated through a SQL Server sequence and a type prefix;
- service numbers are unique.

## Tickets

- A ticket belongs to a person.
- A ticket has an active employee owner.
- A ticket can optionally reference a service.
- If a service is supplied, it must belong to the same person as the ticket.
- A ticket requires an existing typology.
- If a service is supplied, the typology must be compatible with the service type.
- New tickets start in `ABI`.
- Ticket creation records the initial history event `NULL -> ABI`.

## Ticket ownership

Only the current active owner can:

- change ticket state;
- add activities;
- reassign the ticket.

A closed ticket cannot be reassigned and cannot receive new activities.

The new owner in a reassignment must be an active employee.

## Ticket state transitions

Allowed transitions:

```text
ABI -> EPR
ABI -> PCL

EPR -> ABI
EPR -> PCL
EPR -> RES

PCL -> EPR
PCL -> RES

RES -> CER
```

`CER` is terminal.

When a ticket enters `RES`, `fecha_resolucion` is set.

When it enters `CER`, `fecha_cierre` is set while the resolution timestamp is preserved.

Every successful state transition is added to `Estados_Historicos`.

## SLA

SLA is configured for valid `Tipologia + Tipo_Servicio` combinations.

Effective resolution time excludes periods where the ticket is in `PCL`.

A ticket meets its SLA when:

```text
effective resolution hours <= configured SLA hours
```

A ticket without a linked service has no applicable SLA in this model.

## Notifications

The database does not send email directly.

`TRG_Ticket_GenerarNotificacion` inserts a pending row in `Email_Notificacion` whenever a persisted ticket state actually changes.

`fecha_envio = NULL` means the notification has not yet been sent by an external application/service.

The trigger:

- ignores ticket creation;
- ignores updates unrelated to status;
- ignores same-state assignments;
- supports multi-row UPDATE statements.

## Error contract

Stored procedures expose:

```text
@ErrorCode
@ErrorMessage
```

Creation procedures also return the generated entity ID when applicable.

Expected business errors use project-defined `500xx` codes. Unexpected SQL Server errors are caught and returned through the same output contract.
