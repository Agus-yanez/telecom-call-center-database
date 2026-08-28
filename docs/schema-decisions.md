# Schema decisions — portfolio refactor

[🇦🇷 Versión en español](schema-decisions.es.md)

This document records the main database-design decisions applied while preparing the original academic project for a public portfolio repository.

## Preserved from the academic project

- SQL Server as the target DBMS.
- People can be prospects, active customers, or inactive customers.
- Services belong to people and have a service type and status.
- Tickets belong to a person, are owned by an employee, and can optionally reference a service.
- Ticket typologies can be compatible only with selected service types.
- SLA is defined by the `Tipologia_Servicio` relationship.
- Ticket status codes remain `ABI`, `EPR`, `PCL`, `RES`, and `CER`.
- Ticket activities, status history, and notification records remain part of the model.

## Corrections made for the portfolio version

### Status history

The original delivery contained two incompatible history models:

- `Fecha_inicio` / `Fecha_final`
- `Fecha_cambio`

The portfolio schema uses an event-based history:

`NULL -> ABI -> ... -> RES -> CER`

Each row records `id_estado_anterior`, `id_estado_nuevo`, and `fecha_cambio`.

### Service number generation

The original scalar function generated a pseudo-random number with `NEWID()` / `CHECKSUM()`. This does not provide a strong uniqueness guarantee and is unsuitable as the definitive identifier-generation strategy.

The portfolio schema therefore introduces `dbo.Seq_NumeroServicio`. The service-creation procedure will combine the sequence value with a service-type prefix such as `TEL-`, `INT-`, or `VOIP-`.

A `UNIQUE` constraint on `Servicio.numero_servicio` provides the final database-level guarantee.

### Ticket/service ownership

The original rules required a ticket service to belong to the ticket person, but that was validated only by stored procedures.

The portfolio schema additionally enforces this invariant through a composite foreign key:

`Ticket(id_servicio, id_persona) -> Servicio(id_servicio, id_persona)`

### Date consistency

The portfolio schema adds checks so resolution and closure cannot predate ticket opening, and closure cannot predate resolution when both values exist.

### Data types

Operational timestamps use `DATETIME2(0)` instead of legacy `DATETIME`.

### Supporting indexes

Indexes were added for the foreign-key access paths and the most relevant operational queries, including ticket ownership/state, service ownership/state, ticket history, activities, and pending notifications.

## Deferred to later steps

The following business rules remain intentionally in the stored-procedure/function layer and will be implemented in subsequent steps:

- email validation;
- adult-age validation;
- service-type-specific telephone rules;
- person state promotion/demotion;
- ticket typology compatibility;
- ticket state-machine validation;
- employee authorization;
- SLA computation excluding time spent in `PCL`;
- notification generation after ticket status changes.
