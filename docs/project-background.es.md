# Contexto del Proyecto

[English version](project-background.md)

## Origen

Este repositorio se basa en un **proyecto académico grupal** desarrollado para una materia de Bases de Datos II.

La entrega original incluía:

- DDL y datos iniciales para SQL Server;
- diagramas conceptual y lógico;
- stored procedures;
- funciones escalares;
- un trigger;
- una especificación detallada de validaciones, outputs, actualizaciones y requisitos de transacciones.

## Preparación para portfolio

Los archivos académicos originales se conservaron por separado como referencia y **no se publicaron como implementación definitiva sin una revisión previa**.

Para la versión de portfolio se revisó, normalizó y probó el proyecto sobre Microsoft SQL Server.

El trabajo incluyó:

- reconciliar versiones incompatibles del modelo de historial de tickets;
- alinear las transiciones de estados con la especificación escrita;
- reconstruir el cálculo de SLA sobre el modelo definitivo;
- reemplazar identificadores pseudoaleatorios de servicios por una secuencia de SQL Server;
- implementar `SP_ReasignarTicket`, documentado pero ausente en el script original;
- mejorar el contrato de errores de los stored procedures;
- agregar restricciones de integridad e índices de soporte;
- reescribir el trigger de notificaciones con una implementación set-based;
- crear smoke tests y pruebas de regresión ejecutables;
- documentar la arquitectura y las reglas de negocio definitivas.

## Autoría

El proyecto académico de base fue un **trabajo grupal**.

Por ese motivo, este repositorio público de portfolio se presenta como una versión revisada y preparada de ese trabajo académico, no como una atribución individual de toda la autoría original.

## Alcance

Este repositorio se concentra en la capa de base de datos. No incluye interfaz de call center, API backend, sistema de autenticación ni un servicio real de envío de emails.

`Email_Notificacion` representa notificaciones encoladas por la base. El envío sería responsabilidad de una aplicación o servicio externo.
