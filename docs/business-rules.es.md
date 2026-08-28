# Reglas de Negocio

[English version](business-rules.md)

Este documento resume las reglas de negocio implementadas en la versión de portfolio de la base.

## Personas

- Una persona se identifica de forma única por `tipo_documento + nro_documento`.
- El número de documento debe contener 7 u 8 dígitos.
- El email es opcional, pero si se informa debe superar la validación del proyecto.
- La fecha de nacimiento es opcional al crear un prospecto, pero si se informa la persona debe tener al menos 18 años.
- Las personas nuevas se crean en estado `PRO` (Prospecto).
- Nombre, apellido y fecha de nacimiento solo pueden modificarse mientras la persona sea prospecto.
- El email puede modificarse independientemente del estado.
- Cuando un prospecto o una persona inactiva recibe un nuevo servicio activo, pasa a `ACT`.
- Cuando se inactiva su último servicio activo, pasa a `INA`.

## Servicios

Tipos de servicio incluidos en el catálogo de ejemplo:

1. Telefonía fija
2. Internet
3. VOIP

Reglas:

- la persona debe existir;
- un prospecto debe tener email y fecha de nacimiento válidos antes de contratar un servicio;
- Telefonía fija y VOIP requieren teléfono;
- Internet no debe almacenar teléfono;
- calle y número son obligatorios;
- los servicios se crean en estado `ACT`;
- el número de servicio se genera mediante una secuencia de SQL Server y un prefijo según el tipo;
- el número de servicio es único.

## Tickets

- Un ticket pertenece a una persona.
- Tiene un empleado activo como dueño.
- Puede estar asociado opcionalmente a un servicio.
- Si se informa servicio, debe pertenecer a la misma persona del ticket.
- Requiere una tipología existente.
- Si existe servicio, la tipología debe ser compatible con su tipo de servicio.
- Los tickets nuevos se crean en `ABI`.
- La creación registra el evento inicial `NULL -> ABI`.

## Propiedad del ticket

Solo el dueño actual y activo puede:

- cambiar el estado;
- agregar actividades;
- reasignar el ticket.

Un ticket cerrado no puede reasignarse ni recibir nuevas actividades.

El nuevo dueño debe ser un empleado activo.

## Transiciones de estados

Transiciones permitidas:

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

`CER` es terminal.

Al pasar a `RES` se completa `fecha_resolucion`.

Al pasar a `CER` se completa `fecha_cierre` y se conserva la fecha de resolución.

Cada transición exitosa se registra en `Estados_Historicos`.

## SLA

El SLA se configura para combinaciones válidas de `Tipologia + Tipo_Servicio`.

El tiempo efectivo de resolución excluye los períodos en los que el ticket permanece en `PCL`.

Un ticket cumple SLA cuando:

```text
horas efectivas de resolución <= horas de SLA configuradas
```

Un ticket sin servicio asociado no tiene SLA aplicable en este modelo.

## Notificaciones

La base de datos no envía emails directamente.

`TRG_Ticket_GenerarNotificacion` crea una fila pendiente en `Email_Notificacion` cuando cambia realmente el estado persistido de un ticket.

`fecha_envio = NULL` significa que un servicio/aplicación externo todavía no envió la notificación.

El trigger:

- no genera notificación al crear el ticket;
- ignora updates que no modifican el estado;
- ignora asignaciones del mismo estado;
- soporta updates de múltiples filas.

## Contrato de errores

Los stored procedures exponen:

```text
@ErrorCode
@ErrorMessage
```

Los procedimientos de creación también devuelven el ID generado cuando corresponde.

Los errores de negocio esperados utilizan códigos `500xx` definidos por el proyecto. Los errores inesperados de SQL Server se capturan y se devuelven mediante el mismo contrato.
