# Database Model

[🇦🇷 Versión en español](database-model.es.md)

This document describes the portfolio version of the **Telecom Call Center Database** model.

The project models people/prospects, telecom services, support tickets, employees, ticket typologies, status history, activities, SLA rules, and pending email notifications.

## Entity relationship overview

```mermaid
erDiagram
    ESTADO_PERSONA ||--o{ PERSONA : classifies
    PERSONA ||--o{ SERVICIO : owns
    TIPO_SERVICIO ||--o{ SERVICIO : defines
    ESTADO_SERVICIO ||--o{ SERVICIO : classifies

    ESTADO_EMPLEADO ||--o{ EMPLEADO : classifies

    PERSONA ||--o{ TICKET : opens
    EMPLEADO ||--o{ TICKET : owns
    ESTADO_TICKET ||--o{ TICKET : classifies
    SERVICIO o|--o{ TICKET : relates_to
    TIPOLOGIA ||--o{ TICKET : categorizes

    TIPOLOGIA ||--o{ TIPOLOGIA_SERVICIO : allows
    TIPO_SERVICIO ||--o{ TIPOLOGIA_SERVICIO : allows

    TICKET ||--o{ ACTIVIDADES : contains
    TICKET ||--o{ ESTADOS_HISTORICOS : records
    TICKET ||--o{ EMAIL_NOTIFICACION : queues

    ESTADO_TICKET ||--o{ ESTADOS_HISTORICOS : previous_state
    ESTADO_TICKET ||--o{ ESTADOS_HISTORICOS : new_state
    ESTADO_TICKET ||--o{ EMAIL_NOTIFICACION : previous_state
    ESTADO_TICKET ||--o{ EMAIL_NOTIFICACION : new_state

    ESTADO_PERSONA {
        char3 id_estado_persona PK
        varchar descripcion UK
    }

    PERSONA {
        int id_persona PK
        varchar nombre
        varchar apellido
        varchar tipo_documento
        varchar nro_documento
        varchar email
        date fecha_nacimiento
        char3 id_estado_persona FK
    }

    TIPO_SERVICIO {
        int id_tipo_servicio PK
        varchar descripcion UK
    }

    ESTADO_SERVICIO {
        char3 id_estado_servicio PK
        varchar descripcion UK
    }

    SERVICIO {
        int id_servicio PK
        int id_persona FK
        int id_tipo_servicio FK
        varchar numero_servicio UK
        varchar telefono
        varchar calle
        varchar numero
        varchar piso
        varchar depto
        datetime2 fecha_inicio
        char3 id_estado_servicio FK
    }

    ESTADO_EMPLEADO {
        char3 id_estado_empleado PK
        varchar descripcion UK
    }

    EMPLEADO {
        int id_empleado PK
        varchar nombre
        varchar apellido
        varchar login UK
        char3 id_estado_empleado FK
    }

    ESTADO_TICKET {
        char3 id_estado_ticket PK
        varchar descripcion UK
    }

    TIPOLOGIA {
        int id_tipologia PK
        varchar nombre UK
    }

    TIPOLOGIA_SERVICIO {
        int id_tipologia PK,FK
        int id_tipo_servicio PK,FK
        int SLA
    }

    TICKET {
        int id_ticket PK
        datetime2 fecha_apertura
        datetime2 fecha_cierre
        datetime2 fecha_resolucion
        int id_persona FK
        int id_empleado FK
        char3 id_estado_ticket FK
        int id_servicio FK
        int id_tipologia FK
    }

    ACTIVIDADES {
        int id_actividad PK
        int id_ticket FK
        varchar nombre
        varchar descripcion
        datetime2 fecha
    }

    ESTADOS_HISTORICOS {
        int id_historico PK
        int id_ticket FK
        char3 id_estado_anterior FK
        char3 id_estado_nuevo FK
        datetime2 fecha_cambio
    }

    EMAIL_NOTIFICACION {
        int id_notificacion PK
        int id_ticket FK
        char3 id_estado_anterior FK
        char3 id_estado_nuevo FK
        datetime2 fecha_envio
    }
```

## Ticket state machine

The definitive ticket workflow is:

```mermaid
stateDiagram-v2
    [*] --> ABI

    ABI --> EPR
    ABI --> PCL

    EPR --> ABI
    EPR --> PCL
    EPR --> RES

    PCL --> EPR
    PCL --> RES

    RES --> CER
    CER --> [*]
```

State codes:

| Code | Meaning |
|---|---|
| `ABI` | Open |
| `EPR` | In Progress |
| `PCL` | Pending Customer |
| `RES` | Resolved |
| `CER` | Closed |

## Person state lifecycle

People are initially created as prospects.

```mermaid
stateDiagram-v2
    [*] --> PRO

    PRO --> ACT: first active service
    INA --> ACT: new active service
    ACT --> INA: last active service deactivated
```

| Code | Meaning |
|---|---|
| `PRO` | Prospect |
| `ACT` | Active |
| `INA` | Inactive |

## SLA model

SLA is not stored directly on the ticket.

It belongs to the compatibility relationship:

```text
Tipologia + Tipo_Servicio -> SLA (hours)
```

For a ticket linked to a service, SLA is resolved from:

```text
Ticket
  -> Servicio
      -> Tipo_Servicio
  -> Tipologia
      -> Tipologia_Servicio.SLA
```

Effective resolution time is calculated as:

```text
resolution timestamp
- opening timestamp
- time spent in PCL
```

A ticket without a service has no applicable service-type SLA in this portfolio model, so SLA verification returns `NULL`.

## Integrity enforced by the database

The schema does not rely only on stored procedures.

Important invariants also exist at the database level:

- `(tipo_documento, nro_documento)` is unique per person;
- `numero_servicio` is unique;
- SLA must be greater than zero;
- resolution and closure cannot predate ticket opening;
- closure cannot predate resolution;
- a ticket service, when present, must belong to the same person as the ticket;
- status-history rows cannot record the same previous and new state;
- notification rows must represent a real state change.

These constraints complement the business validations implemented by the stored procedure layer.
