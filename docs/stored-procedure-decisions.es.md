# Decisiones de stored procedures — refactor para portfolio

[English version](stored-procedure-decisions.md)

La versión de portfolio conserva los ocho stored procedures definidos en la especificación académica original.

## Procedimientos

1. `SP_AltaPersona`
2. `SP_CrearServicio`
3. `SP_InactivarServicio`
4. `SP_CrearTicket`
5. `SP_CambiarEstadoTicket`
6. `SP_ReasignarTicket`
7. `SP_ModificarPersona`
8. `SP_AgregarActividad`

`SP_ReasignarTicket` estaba presente en la especificación escrita pero faltaba en el archivo original `STORE-PROCEDURE.sql`, por lo que fue implementado para la versión de portfolio.

## Contrato de errores

El proyecto académico ya definía los outputs `@ErrorCode` y `@ErrorMessage`. El refactor de portfolio los convierte en el contrato público explícito de errores:

- los fallos esperados de reglas de negocio devuelven un código `500xx` definido por el proyecto;
- los errores de validación esperados no generan una segunda excepción SQL;
- los errores inesperados de base de datos se capturan y devuelven utilizando el número y mensaje de error de SQL Server.

Esto evita el patrón original `RAISERROR -> CATCH -> ERROR_NUMBER()`, que podía reemplazar un código propio del proyecto por un número genérico de SQL Server.

## Transacciones

Las transacciones se mantienen únicamente en procedimientos que coordinan múltiples escrituras relacionadas:

- `SP_CrearServicio`
- `SP_InactivarServicio`
- `SP_CrearTicket`
- `SP_CambiarEstadoTicket`

Las operaciones de una sola fila permanecen sin transacción explícita a nivel de procedimiento, respetando la intención de la especificación original.

## Reglas adicionales de consistencia

- `SP_CrearTicket` registra el evento inicial de historial como `NULL -> ABI`.
- `SP_CambiarEstadoTicket` respeta la máquina de estados definitiva implementada por `FN_ValidarTransicionEstado`.
- `fecha_resolucion` se establece al pasar a `RES`.
- `fecha_cierre` se establece al pasar de `RES` a `CER`.
- `SP_AgregarActividad` escribe sobre la columna definitiva `Actividades.fecha`.
- Los servicios de Internet rechazan un teléfono informado en lugar de descartarlo silenciosamente.
- La creación de un servicio para un prospecto exige email válido, fecha de nacimiento y mayoría de edad.
- Los identificadores de servicio consumen `dbo.Seq_NumeroServicio` y se formatean mediante `FN_GenerarNumeroServicio`.

## Pruebas

`tests/02-stored-procedures-smoke-tests.sql` cubre tanto flujos exitosos como fallos de validación relevantes.

La prueba se ejecuta dentro de una transacción externa y revierte los datos creados al finalizar. Las secuencias de SQL Server no son transaccionales, por lo que la secuencia de números de servicio puede avanzar durante la prueba; este comportamiento es esperado.
