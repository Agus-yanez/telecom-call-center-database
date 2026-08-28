# Decisiones del trigger — refactor para portfolio

[English version](trigger-decisions.md)

El proyecto académico original incluía un trigger de notificaciones asociado a cambios de estado de tickets. La versión de portfolio conserva esa idea y la implementa de forma explícita y set-based.

## Trigger

`TRG_Ticket_GenerarNotificacion`

El trigger se ejecuta `AFTER UPDATE` sobre `dbo.Ticket`.

Cuando cambia `id_estado_ticket`, inserta una fila en `dbo.Email_Notificacion` con:

- `id_ticket`;
- estado anterior;
- estado nuevo;
- `fecha_envio = NULL`.

De esta forma, la base registra que existe una notificación pendiente. **No** se afirma que la base envíe el email por sí misma.

## Por qué `AFTER UPDATE`

La creación de un ticket ya queda representada en `Estados_Historicos` como `NULL -> ABI`. El trigger de notificaciones está pensado únicamente para cambios reales de estado posteriores a la creación, por lo que el insert inicial no genera una notificación.

## Implementación set-based

El trigger une las pseudo-tablas `inserted` y `deleted` de SQL Server y no asume que un `UPDATE` afecte una única fila.

Esto es importante porque los triggers de SQL Server se ejecutan una vez por sentencia, no una vez por fila.

## Updates sin cambio real

La condición:

`i.id_estado_ticket <> d.id_estado_ticket`

evita generar una notificación cuando una sentencia `UPDATE` toca un ticket pero deja su estado sin cambios.

## Separación de responsabilidades

- `SP_CambiarEstadoTicket` valida la transición legal y registra el historial.
- `TRG_Ticket_GenerarNotificacion` reacciona al cambio ya persistido y encola un registro de notificación.
- Una aplicación o servicio externo sería responsable de enviar el email y completar `fecha_envio`.

Esto mantiene separadas las responsabilidades de validación de negocio, auditoría y entrega de notificaciones.

## Pruebas

`tests/03-trigger-smoke-tests.sql` verifica:

1. que la creación del ticket no genere notificación;
2. que una transición válida genere una notificación pendiente;
3. que un update de otro campo no genere notificación;
4. que una segunda transición genere una segunda notificación;
5. que asignar el mismo estado no genere notificación;
6. que un `UPDATE` de múltiples filas genere una notificación por cada ticket modificado.

La prueba se ejecuta dentro de una transacción y revierte todas las filas creadas durante el escenario.
