# Suite de pruebas SQL

[English version](README.md)

La versión de portfolio incluye smoke tests y pruebas de regresión ejecutables en SQL Server.

## Orden de ejecución

Primero ejecutá los scripts de base de datos:

1. `database/01-create-database.sql`
2. `database/02-schema.sql`
3. `database/03-seed-data.sql`
4. `database/04-functions.sql`
5. `database/05-stored-procedures.sql`
6. `database/06-triggers.sql`

Luego ejecutá las pruebas:

1. `tests/01-functions-smoke-tests.sql`
2. `tests/02-stored-procedures-smoke-tests.sql`
3. `tests/03-trigger-smoke-tests.sql`
4. `tests/04-end-to-end-regression-tests.sql`

Cada script de prueba finaliza con un mensaje explícito `OK - ... passed.` cuando el resultado es correcto.

## Cobertura

### Funciones

- validación de email;
- validación de documento;
- formato de números de servicio;
- transiciones de estados de tickets;
- cálculo de edad;
- tiempo efectivo de resolución;
- cumplimiento de SLA.

### Stored procedures

- alta de personas y validación de documento duplicado;
- modificación de prospectos;
- creación de servicios y promoción del estado de la persona;
- reglas de validación de servicios;
- creación de tickets e historial inicial;
- creación de actividades;
- reasignación de tickets;
- operaciones restringidas al dueño del ticket;
- progresión legal de estados;
- fechas de resolución y cierre;
- inactivación de servicios e inactivación del estado de la persona.

### Trigger

- no genera notificación al crear un ticket;
- genera notificación ante cambios reales de estado;
- no genera notificación ante updates no relacionados;
- no genera notificación al asignar el mismo estado;
- soporta `UPDATE` de múltiples filas.

### Regresión end-to-end e integridad

- ciclo completo persona/servicio/ticket;
- cantidad esperada de eventos de historial y notificaciones;
- foreign key compuesta para ownership ticket/servicio;
- unicidad del documento;
- restricción de SLA positivo;
- coherencia de fechas de tickets;
- compatibilidad entre servicio y tipología;
- escenario de regresión del cálculo de SLA.

## Comportamiento de las transacciones

Los datos creados por las pruebas se revierten con `ROLLBACK`.

Las secuencias de SQL Server no son transaccionales, por lo que `dbo.Seq_NumeroServicio` puede avanzar durante las pruebas. Los saltos en los números de servicio generados son esperables y no se consideran fallos.
