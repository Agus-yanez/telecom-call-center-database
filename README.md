# Telecom Call Center Database

[🇦🇷 Versión en español](README.es.md)

SQL Server database project for managing **customers and prospects, telecom services, support tickets, employees, ticket typologies, SLA rules, status history, activities, and pending notifications**.

This repository is based on a **group academic project for a Database II course** and was later reviewed, normalized, tested, and documented as a public portfolio project.

---

## Overview

The database models the operational layer of a telecom call center.

Its main responsibilities include:

- managing prospects, active customers, and inactive customers;
- creating and deactivating telecom services;
- creating and assigning support tickets;
- validating ticket typologies against service types;
- enforcing a controlled ticket state machine;
- recording ticket status history;
- registering ticket activities;
- calculating effective resolution time and SLA compliance;
- queuing notification records after real ticket status changes;
- returning structured business errors through stored procedure outputs.

The project focuses exclusively on the **database layer**. It does not include a frontend, backend API, authentication system, or real email-delivery service.

---

## Tech Stack

- **Microsoft SQL Server**
- **T-SQL**
- Stored Procedures
- Scalar Functions
- Triggers
- Transactions
- Constraints
- Indexes
- SQL Server Sequences
- Mermaid diagrams for documentation

---

## Main Database Areas

### People and customer lifecycle

People are initially created as prospects:

```text
PRO -> ACT -> INA
       ^
       |
      INA
```

A prospect or inactive customer becomes active when a new active service is created.

When the last active service is deactivated, the person becomes inactive.

### Services

The sample catalog includes:

- Fixed telephony
- Internet
- VOIP

Service numbers are generated using a SQL Server sequence and service-type prefixes:

```text
TEL-100001
INT-100002
VOIP-100003
```

### Tickets

Tickets belong to a person and are owned by an active employee.

A ticket may optionally reference one of the person's services.

If a service is present, the selected ticket typology must be compatible with that service type.

The definitive ticket workflow is:

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

Where:

| Code | Meaning |
|---|---|
| `ABI` | Open |
| `EPR` | In Progress |
| `PCL` | Pending Customer |
| `RES` | Resolved |
| `CER` | Closed |

### SLA

SLA is defined by the combination:

```text
Ticket Typology + Service Type -> SLA hours
```

Effective resolution time excludes periods in which the ticket is in `PCL`.

```text
effective resolution time
=
resolution timestamp
- opening timestamp
- time spent in PCL
```

---

## Stored Procedures

The portfolio version includes the eight procedures defined by the project specification:

| Procedure | Responsibility |
|---|---|
| `SP_AltaPersona` | Creates a prospect and validates personal data |
| `SP_CrearServicio` | Creates a service and promotes the customer when required |
| `SP_InactivarServicio` | Deactivates a service and updates customer state |
| `SP_CrearTicket` | Creates a ticket and its initial history event |
| `SP_CambiarEstadoTicket` | Validates and applies ticket state transitions |
| `SP_ReasignarTicket` | Reassigns an open ticket to another active employee |
| `SP_ModificarPersona` | Applies allowed person-data modifications |
| `SP_AgregarActividad` | Adds an activity to a ticket |

Expected business-rule errors are returned through:

```text
@ErrorCode
@ErrorMessage
```

Creation procedures also return the generated entity ID where applicable.

---

## Functions

The project includes:

- `FN_ValidarEmail`
- `FN_ValidarDocumento`
- `FN_GenerarNumeroServicio`
- `FN_ValidarTransicionEstado`
- `FN_CalcularTiempoResolucion`
- `FN_VerificarCumplimientoSLA`
- `FN_CalcularEdad`

---

## Trigger

`TRG_Ticket_GenerarNotificacion` reacts to persisted ticket state changes.

It inserts a pending row into `Email_Notificacion` containing:

- ticket ID;
- previous state;
- new state;
- `fecha_envio = NULL`.

The trigger is **set-based**, supports multi-row `UPDATE` statements, and does not create notifications when unrelated ticket fields are updated.

The database does not send emails directly. Delivery would be handled by an external application or service.

---

## Database-Level Integrity

Important rules are enforced by the schema itself, not only by stored procedures:

- unique person document (`tipo_documento + nro_documento`);
- unique service number;
- positive SLA values;
- ticket resolution and closure dates cannot predate opening;
- closure cannot predate resolution;
- a ticket service must belong to the same person as the ticket;
- status-history rows must represent a real state change;
- notification rows must represent a real state change.

Supporting indexes are included for the main relationship and operational access paths.

---

## Repository Structure

```text
telecom-call-center-database/
│
├── README.md
├── README.es.md
│
├── database/
│   ├── 01-create-database.sql
│   ├── 02-schema.sql
│   ├── 03-seed-data.sql
│   ├── 04-functions.sql
│   ├── 05-stored-procedures.sql
│   ├── 06-triggers.sql
│   ├── README.md
│   └── README.es.md
│
├── tests/
│   ├── 01-functions-smoke-tests.sql
│   ├── 02-stored-procedures-smoke-tests.sql
│   ├── 03-trigger-smoke-tests.sql
│   ├── 04-end-to-end-regression-tests.sql
│   ├── README.md
│   └── README.es.md
│
└── docs/
    ├── database-model.md
    ├── database-model.es.md
    ├── business-rules.md
    ├── business-rules.es.md
    ├── project-background.md
    ├── project-background.es.md
    ├── schema-decisions.md
    ├── schema-decisions.es.md
    ├── stored-procedure-decisions.md
    ├── stored-procedure-decisions.es.md
    ├── trigger-decisions.md
    └── trigger-decisions.es.md
```

---

## Installation

Run the database scripts in this order:

```text
01-create-database.sql
02-schema.sql
03-seed-data.sql
04-functions.sql
05-stored-procedures.sql
06-triggers.sql
```

Detailed instructions:

[Database installation guide](database/README.md)

The current setup is designed for a **fresh installation** rather than an idempotent upgrade over an already initialized schema.

---

## Testing

The project includes executable SQL Server smoke and regression tests.

Recommended order:

```text
01-functions-smoke-tests.sql
02-stored-procedures-smoke-tests.sql
03-trigger-smoke-tests.sql
04-end-to-end-regression-tests.sql
```

Validated scenarios include:

- functions and validators;
- stored procedure success and failure paths;
- ticket ownership and state transitions;
- customer state promotion/demotion;
- activity creation;
- ticket reassignment;
- trigger behavior;
- multi-row updates;
- document uniqueness;
- composite service ownership;
- SLA constraints;
- date consistency;
- SLA calculation regression;
- complete customer/service/ticket lifecycle.

All current test scripts were executed successfully against Microsoft SQL Server during portfolio preparation.

[Testing documentation](tests/README.md)

---

## Documentation

- [Database model](docs/database-model.md)
- [Business rules](docs/business-rules.md)
- [Project background and attribution](docs/project-background.md)
- [Schema design decisions](docs/schema-decisions.md)
- [Stored procedure decisions](docs/stored-procedure-decisions.md)
- [Trigger decisions](docs/trigger-decisions.md)

🇦🇷 Spanish:

- [Modelo de base de datos](docs/database-model.es.md)
- [Reglas de negocio](docs/business-rules.es.md)
- [Contexto del proyecto](docs/project-background.es.md)
- [Decisiones del esquema](docs/schema-decisions.es.md)
- [Decisiones de stored procedures](docs/stored-procedure-decisions.es.md)
- [Decisiones del trigger](docs/trigger-decisions.es.md)

---

## Academic Origin and Portfolio Refactor

The underlying project originated as a **group academic assignment**.

The public portfolio version preserves that context and does not claim sole authorship of the original work.

Before publication, the project was reviewed and refactored to:

- reconcile inconsistent database-model versions;
- align ticket transitions with the written specification;
- rebuild SLA calculation;
- replace pseudo-random service identifiers with a SQL Server sequence;
- implement the documented but missing `SP_ReasignarTicket`;
- improve error handling;
- strengthen constraints and indexes;
- make the trigger set-based;
- add executable smoke and regression tests;
- document the final architecture and business rules.

More details:

[Project background](docs/project-background.md)

---

## Scope and Limitations

This repository demonstrates the database and business-rule layer only.

It does **not** include:

- call-center user interface;
- backend REST API;
- authentication or authorization system beyond database-level employee ownership rules;
- real email sending;
- production deployment scripts;
- migration/versioning tooling for an existing production database.

The sample data is intentionally synthetic.

---

## Status

**Portfolio-ready database implementation**

Validated on Microsoft SQL Server with:

- schema creation;
- seed data;
- functions;
- stored procedures;
- trigger;
- smoke tests;
- end-to-end regression tests;
- database integrity tests.
