# Modelo de Base de Datos

[English version](database-model.md)

Este documento describe el modelo de la versión de portfolio de **Telecom Call Center Database**.

El proyecto modela personas/prospectos, servicios de telecomunicaciones, tickets de soporte, empleados, tipologías, historial de estados, actividades, reglas de SLA y notificaciones de email pendientes.

## Vista general de entidades y relaciones

```mermaid
erDiagram
    ESTADO_PERSONA ||--o{ PERSONA : clasifica
    PERSONA ||--o{ SERVICIO : posee
    TIPO_SERVICIO ||--o{ SERVICIO : define
    ESTADO_SERVICIO ||--o{ SERVICIO : clasifica

    ESTADO_EMPLEADO ||--o{ EMPLEADO : clasifica

    PERSONA ||--o{ TICKET : genera
    EMPLEADO ||--o{ TICKET : gestiona
    ESTADO_TICKET ||--o{ TICKET : clasifica
    SERVICIO o|--o{ TICKET : relaciona
    TIPOLOGIA ||--o{ TICKET : categoriza

    TIPOLOGIA ||--o{ TIPOLOGIA_SERVICIO : permite
    TIPO_SERVICIO ||--o{ TIPOLOGIA_SERVICIO : permite

    TICKET ||--o{ ACTIVIDADES : contiene
    TICKET ||--o{ ESTADOS_HISTORICOS : registra
    TICKET ||--o{ EMAIL_NOTIFICACION : encola

    ESTADO_TICKET ||--o{ ESTADOS_HISTORICOS : estado_anterior
    ESTADO_TICKET ||--o{ ESTADOS_HISTORICOS : estado_nuevo
    ESTADO_TICKET ||--o{ EMAIL_NOTIFICACION : estado_anterior
    ESTADO_TICKET ||--o{ EMAIL_NOTIFICACION : estado_nuevo

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

## Máquina de estados del ticket

El flujo definitivo es:

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

| Código | Significado |
|---|---|
| `ABI` | Abierto |
| `EPR` | En Proceso |
| `PCL` | Pendiente de Cliente |
| `RES` | Resuelto |
| `CER` | Cerrado |

## Ciclo de estado de una persona

Las personas se crean inicialmente como prospectos.

```mermaid
stateDiagram-v2
    [*] --> PRO

    PRO --> ACT: primer servicio activo
    INA --> ACT: nuevo servicio activo
    ACT --> INA: se inactiva el ultimo servicio activo
```

| Código | Significado |
|---|---|
| `PRO` | Prospecto |
| `ACT` | Activo |
| `INA` | Inactivo |

## Modelo de SLA

El SLA no se almacena directamente en el ticket.

Pertenece a la relación de compatibilidad:

```text
Tipologia + Tipo_Servicio -> SLA (horas)
```

Para un ticket asociado a un servicio, el SLA se obtiene mediante:

```text
Ticket
  -> Servicio
      -> Tipo_Servicio
  -> Tipologia
      -> Tipologia_Servicio.SLA
```

El tiempo efectivo de resolución se calcula como:

```text
fecha de resolución
- fecha de apertura
- tiempo permanecido en PCL
```

Un ticket sin servicio no tiene un SLA asociado a un tipo de servicio en este modelo de portfolio, por lo que la verificación de SLA devuelve `NULL`.

## Integridad garantizada por la base

El modelo no depende solamente de los stored procedures.

También existen restricciones a nivel de base de datos:

- `(tipo_documento, nro_documento)` es único por persona;
- `numero_servicio` es único;
- el SLA debe ser mayor que cero;
- resolución y cierre no pueden ser anteriores a la apertura;
- el cierre no puede ser anterior a la resolución;
- un servicio asociado a un ticket debe pertenecer a la misma persona;
- el historial no puede registrar el mismo estado como anterior y nuevo;
- una notificación debe representar un cambio real de estado.

Estas restricciones complementan las reglas de negocio implementadas por los stored procedures.
