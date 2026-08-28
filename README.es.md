# Telecom Call Center Database

[English version](README.md)

Proyecto de base de datos en SQL Server para gestionar **clientes y prospectos, servicios de telecomunicaciones, tickets de soporte, empleados, tipologías, reglas de SLA, historial de estados, actividades y notificaciones pendientes**.

Este repositorio se basa en un **proyecto académico grupal de la materia Bases de Datos II** y posteriormente fue revisado, normalizado, probado y documentado como proyecto público de portfolio.

---

## Descripción general

La base modela la capa operativa de un call center de una empresa de telecomunicaciones.

Sus principales responsabilidades incluyen:

- gestionar prospectos, clientes activos e inactivos;
- crear e inactivar servicios de telecomunicaciones;
- crear y asignar tickets de soporte;
- validar tipologías según el tipo de servicio;
- aplicar una máquina de estados controlada para tickets;
- registrar el historial de cambios de estado;
- registrar actividades realizadas sobre tickets;
- calcular tiempo efectivo de resolución y cumplimiento de SLA;
- encolar registros de notificación ante cambios reales de estado;
- devolver errores de negocio estructurados desde los stored procedures.

El proyecto se concentra exclusivamente en la **capa de base de datos**. No incluye frontend, API backend, sistema de autenticación ni un servicio real de envío de emails.

---

## Tecnologías

- **Microsoft SQL Server**
- **T-SQL**
- Stored Procedures
- Funciones escalares
- Triggers
- Transacciones
- Constraints
- Índices
- Secuencias de SQL Server
- Diagramas Mermaid para documentación

---

## Principales áreas del modelo

### Personas y ciclo de cliente

Las personas se crean inicialmente como prospectos:

```text
PRO -> ACT -> INA
       ^
       |
      INA
```

Un prospecto o cliente inactivo pasa a activo cuando se crea un nuevo servicio activo.

Cuando se inactiva su último servicio activo, la persona pasa a inactiva.

### Servicios

El catálogo de ejemplo incluye:

- Telefonía fija
- Internet
- VOIP

Los números de servicio se generan mediante una secuencia de SQL Server y prefijos según el tipo:

```text
TEL-100001
INT-100002
VOIP-100003
```

### Tickets

Los tickets pertenecen a una persona y tienen un empleado activo como dueño.

Pueden estar asociados opcionalmente a uno de los servicios de esa persona.

Si existe servicio, la tipología seleccionada debe ser compatible con su tipo.

El flujo definitivo es:

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

Donde:

| Código | Significado |
|---|---|
| `ABI` | Abierto |
| `EPR` | En Proceso |
| `PCL` | Pendiente de Cliente |
| `RES` | Resuelto |
| `CER` | Cerrado |

### SLA

El SLA se define mediante la combinación:

```text
Tipología de ticket + Tipo de servicio -> horas de SLA
```

El tiempo efectivo de resolución excluye los períodos en los que el ticket permanece en `PCL`.

```text
tiempo efectivo de resolución
=
fecha de resolución
- fecha de apertura
- tiempo en PCL
```

---

## Stored Procedures

La versión de portfolio incluye los ocho procedimientos definidos por la especificación del proyecto:

| Procedimiento | Responsabilidad |
|---|---|
| `SP_AltaPersona` | Crea un prospecto y valida sus datos |
| `SP_CrearServicio` | Crea un servicio y actualiza el estado de la persona |
| `SP_InactivarServicio` | Inactiva un servicio y actualiza el estado del cliente |
| `SP_CrearTicket` | Crea un ticket y su evento inicial de historial |
| `SP_CambiarEstadoTicket` | Valida y aplica transiciones de estado |
| `SP_ReasignarTicket` | Reasigna un ticket abierto a otro empleado activo |
| `SP_ModificarPersona` | Aplica modificaciones permitidas sobre una persona |
| `SP_AgregarActividad` | Registra una actividad sobre un ticket |

Los errores de negocio esperados se devuelven mediante:

```text
@ErrorCode
@ErrorMessage
```

Los procedimientos de creación también devuelven el ID generado cuando corresponde.

---

## Funciones

El proyecto incluye:

- `FN_ValidarEmail`
- `FN_ValidarDocumento`
- `FN_GenerarNumeroServicio`
- `FN_ValidarTransicionEstado`
- `FN_CalcularTiempoResolucion`
- `FN_VerificarCumplimientoSLA`
- `FN_CalcularEdad`

---

## Trigger

`TRG_Ticket_GenerarNotificacion` reacciona ante cambios persistidos del estado de un ticket.

Inserta una fila pendiente en `Email_Notificacion` con:

- ID del ticket;
- estado anterior;
- estado nuevo;
- `fecha_envio = NULL`.

El trigger tiene una implementación **set-based**, soporta `UPDATE` de múltiples filas y no genera notificaciones cuando se actualizan otros campos del ticket sin modificar el estado.

La base no envía emails directamente. El envío correspondería a una aplicación o servicio externo.

---

## Integridad a nivel de base de datos

Las reglas importantes no dependen únicamente de los stored procedures.

El esquema también garantiza:

- documento único por persona (`tipo_documento + nro_documento`);
- número de servicio único;
- SLA mayor que cero;
- resolución y cierre no pueden ser anteriores a la apertura;
- cierre no puede ser anterior a la resolución;
- un servicio asociado a un ticket debe pertenecer a la misma persona;
- el historial debe representar un cambio real de estado;
- las notificaciones deben representar un cambio real de estado.

También se incluyen índices de soporte para las principales relaciones y consultas operativas.

---

## Estructura del repositorio

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

## Instalación

Ejecutar los scripts en este orden:

```text
01-create-database.sql
02-schema.sql
03-seed-data.sql
04-functions.sql
05-stored-procedures.sql
06-triggers.sql
```

Guía detallada:

[Guía de instalación de la base](database/README.es.md)

La instalación actual está pensada para una **base nueva**, no como mecanismo idempotente de actualización sobre un esquema ya inicializado.

---

## Pruebas

El proyecto incluye smoke tests y pruebas de regresión ejecutables en SQL Server.

Orden recomendado:

```text
01-functions-smoke-tests.sql
02-stored-procedures-smoke-tests.sql
03-trigger-smoke-tests.sql
04-end-to-end-regression-tests.sql
```

Los escenarios validados incluyen:

- funciones y validadores;
- caminos exitosos y fallidos de stored procedures;
- ownership y transiciones de tickets;
- promoción e inactivación del estado de personas;
- creación de actividades;
- reasignación de tickets;
- comportamiento del trigger;
- updates de múltiples filas;
- unicidad de documentos;
- integridad de ownership de servicios;
- restricciones de SLA;
- coherencia de fechas;
- regresión del cálculo de SLA;
- flujo completo persona/servicio/ticket.

Todos los scripts de prueba actuales fueron ejecutados correctamente contra Microsoft SQL Server durante la preparación para portfolio.

[Documentación de pruebas](tests/README.es.md)

---

## Documentación

- [Modelo de base de datos](docs/database-model.es.md)
- [Reglas de negocio](docs/business-rules.es.md)
- [Contexto y atribución del proyecto](docs/project-background.es.md)
- [Decisiones del esquema](docs/schema-decisions.es.md)
- [Decisiones de stored procedures](docs/stored-procedure-decisions.es.md)
- [Decisiones del trigger](docs/trigger-decisions.es.md)

English:

- [Database model](docs/database-model.md)
- [Business rules](docs/business-rules.md)
- [Project background](docs/project-background.md)
- [Schema design decisions](docs/schema-decisions.md)
- [Stored procedure decisions](docs/stored-procedure-decisions.md)
- [Trigger decisions](docs/trigger-decisions.md)

---

## Origen académico y preparación para portfolio

El proyecto de base se originó como un **trabajo académico grupal**.

La versión pública conserva ese contexto y no se presenta como una atribución individual de toda la autoría original.

Antes de publicar, el proyecto fue revisado y refactorizado para:

- reconciliar versiones inconsistentes del modelo;
- alinear las transiciones con la especificación escrita;
- reconstruir el cálculo de SLA;
- reemplazar identificadores pseudoaleatorios por una secuencia de SQL Server;
- implementar `SP_ReasignarTicket`, documentado pero ausente en el script original;
- mejorar el manejo de errores;
- reforzar restricciones e índices;
- convertir el trigger en una implementación set-based;
- agregar smoke tests y pruebas de regresión ejecutables;
- documentar la arquitectura y las reglas de negocio definitivas.

Más información:

[Contexto del proyecto](docs/project-background.es.md)

---

## Alcance y limitaciones

Este repositorio demuestra únicamente la capa de base de datos y sus reglas de negocio.

No incluye:

- interfaz de usuario para call center;
- API REST backend;
- sistema de autenticación/autorización más allá de las reglas de ownership definidas en la base;
- envío real de emails;
- scripts de despliegue productivo;
- tooling de migraciones/versionado sobre una base productiva existente.

Los datos incluidos son sintéticos y se utilizan únicamente como ejemplo y soporte para pruebas.

---

## Estado

**Implementación de base de datos lista para portfolio**

Validada en Microsoft SQL Server con:

- creación de esquema;
- datos iniciales;
- funciones;
- stored procedures;
- trigger;
- smoke tests;
- pruebas end-to-end;
- pruebas de integridad de base de datos.
