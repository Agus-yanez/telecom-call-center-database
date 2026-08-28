# Decisiones del esquema — refactor para portfolio

[English version](schema-decisions.md)

Este documento registra las principales decisiones de diseño aplicadas al preparar el proyecto académico original para un repositorio público de portfolio.

## Elementos preservados del proyecto académico

- SQL Server como motor de base de datos objetivo.
- Las personas pueden ser prospectos, clientes activos o clientes inactivos.
- Los servicios pertenecen a personas y tienen tipo y estado.
- Los tickets pertenecen a una persona, son gestionados por un empleado y pueden referenciar opcionalmente un servicio.
- Las tipologías de tickets pueden ser compatibles únicamente con determinados tipos de servicio.
- El SLA se define mediante la relación `Tipologia_Servicio`.
- Los estados de ticket se mantienen como `ABI`, `EPR`, `PCL`, `RES` y `CER`.
- Las actividades, el historial de estados y los registros de notificaciones continúan formando parte del modelo.

## Correcciones realizadas para la versión de portfolio

### Historial de estados

La entrega original contenía dos modelos incompatibles de historial:

- `Fecha_inicio` / `Fecha_final`
- `Fecha_cambio`

El esquema de portfolio utiliza un historial basado en eventos:

`NULL -> ABI -> ... -> RES -> CER`

Cada fila registra `id_estado_anterior`, `id_estado_nuevo` y `fecha_cambio`.

### Generación del número de servicio

La función escalar original generaba un número pseudoaleatorio mediante `NEWID()` / `CHECKSUM()`. Ese enfoque no ofrece una garantía fuerte de unicidad y no resulta adecuado como estrategia definitiva de generación de identificadores.

Por eso, el esquema de portfolio incorpora `dbo.Seq_NumeroServicio`. El stored procedure de creación combina el valor de la secuencia con un prefijo según el tipo de servicio, por ejemplo `TEL-`, `INT-` o `VOIP-`.

Una restricción `UNIQUE` sobre `Servicio.numero_servicio` aporta la garantía final a nivel de base de datos.

### Ownership entre ticket y servicio

Las reglas originales exigían que un servicio asociado a un ticket perteneciera a la misma persona del ticket, pero esa validación estaba planteada únicamente en los stored procedures.

El esquema de portfolio también refuerza esta invariante mediante una foreign key compuesta:

`Ticket(id_servicio, id_persona) -> Servicio(id_servicio, id_persona)`

### Coherencia de fechas

El esquema de portfolio agrega checks para impedir que las fechas de resolución o cierre sean anteriores a la apertura, y para impedir que el cierre sea anterior a la resolución cuando ambas fechas existen.

### Tipos de datos

Los timestamps operativos utilizan `DATETIME2(0)` en lugar del tipo heredado `DATETIME`.

### Índices de soporte

Se agregaron índices para los principales caminos de acceso mediante foreign keys y consultas operativas, incluyendo ownership/estado de tickets, ownership/estado de servicios, historial de tickets, actividades y notificaciones pendientes.

## Reglas implementadas en capas posteriores

Las siguientes reglas se mantienen intencionalmente en la capa de funciones y stored procedures:

- validación de email;
- validación de mayoría de edad;
- reglas de teléfono según tipo de servicio;
- promoción e inactivación del estado de una persona;
- compatibilidad entre tipología y servicio;
- validación de la máquina de estados de tickets;
- autorización del empleado;
- cálculo de SLA excluyendo el tiempo en `PCL`;
- generación de notificaciones ante cambios de estado.
