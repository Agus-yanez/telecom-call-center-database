# Project Background

[🇦🇷 Versión en español](project-background.es.md)

## Origin

This repository is based on a **group academic project** developed for a Database II course.

The original delivery included:

- SQL Server DDL and initial data;
- conceptual and logical database diagrams;
- stored procedures;
- scalar functions;
- a trigger;
- a detailed written specification of validations, outputs, updates, and transaction requirements.

## Portfolio preparation

The original academic files were preserved separately as reference and were **not published as the definitive implementation without review**.

For the portfolio version, the project was reviewed, normalized, and tested against Microsoft SQL Server.

The work included:

- reconciling inconsistent versions of the ticket history model;
- aligning ticket-state transitions with the written specification;
- rebuilding SLA calculation against the definitive state model;
- replacing pseudo-random service identifiers with a SQL Server sequence;
- implementing the documented but missing `SP_ReasignarTicket`;
- improving the stored procedure error contract;
- adding database-level constraints and supporting indexes;
- rewriting the notification trigger as a set-based implementation;
- creating executable smoke and regression tests;
- documenting the final architecture and business rules.

## Authorship

The underlying academic project was a **team assignment**.

This public portfolio repository is therefore presented as a reviewed and prepared version of that academic work, not as a claim of sole authorship of the original project.

## Scope

This repository focuses on the database layer. It does not include a call-center UI, backend API, authentication system, or real email-delivery service.

`Email_Notificacion` represents notifications queued by the database. Delivery would be the responsibility of an external application or service.
