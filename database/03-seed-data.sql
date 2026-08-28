/*
    Telecom Call Center Database
    Step 03 - Initial / sample data

    The seed data is intentionally coherent with the definitive schema
    and the documented business rules.
*/

USE TelecomCallCenterDB;
GO

SET NOCOUNT ON;
GO

/* ============================================================
   States
   ============================================================ */

INSERT INTO dbo.Estado_Persona (id_estado_persona, descripcion)
VALUES
    ('ACT', 'Activo'),
    ('INA', 'Inactivo'),
    ('PRO', 'Prospecto');
GO

INSERT INTO dbo.Estado_Ticket (id_estado_ticket, descripcion)
VALUES
    ('ABI', 'Abierto'),
    ('EPR', 'En Proceso'),
    ('PCL', 'Pendiente de Cliente'),
    ('RES', 'Resuelto'),
    ('CER', 'Cerrado');
GO

INSERT INTO dbo.Estado_Servicio (id_estado_servicio, descripcion)
VALUES
    ('ACT', 'Activo'),
    ('INA', 'Inactivo');
GO

INSERT INTO dbo.Estado_Empleado (id_estado_empleado, descripcion)
VALUES
    ('ACT', 'Activo'),
    ('INA', 'Inactivo');
GO


/* ============================================================
   Service types and ticket typologies
   ============================================================ */

INSERT INTO dbo.Tipo_Servicio (id_tipo_servicio, descripcion)
VALUES
    (1, 'Telefonia fija'),
    (2, 'Internet'),
    (3, 'VOIP');
GO

INSERT INTO dbo.Tipologia (id_tipologia, nombre)
VALUES
    (1, 'Reimpresion de Factura'),
    (2, 'Servicio Degradado'),
    (3, 'Baja de Servicio'),
    (4, 'Facturacion de Cargos Erroneos'),
    (5, 'Cambio de Velocidad'),
    (6, 'Mudanza de Servicio');
GO

INSERT INTO dbo.Tipologia_Servicio (id_tipologia, id_tipo_servicio, SLA)
VALUES
    (1, 2, 24),
    (2, 2, 48),
    (3, 1, 72),
    (3, 3, 72),
    (4, 1, 24),
    (4, 2, 24),
    (5, 2, 36),
    (6, 1, 36);
GO


/* ============================================================
   Employees
   ============================================================ */

INSERT INTO dbo.Empleado (nombre, apellido, login, id_estado_empleado)
VALUES
    ('Laura', 'Rodriguez', 'laura.r', 'ACT'),
    ('Juan', 'Amanzo', 'juan.a', 'ACT'),
    ('Paula', 'Lopez', 'paula.l', 'INA');
GO


/* ============================================================
   People
   ============================================================ */

INSERT INTO dbo.Persona (
    nombre,
    apellido,
    tipo_documento,
    nro_documento,
    email,
    fecha_nacimiento,
    id_estado_persona
)
VALUES
    ('Ana', 'Perez', 'DNI', '12345678', 'ana@example.com', '1985-03-15', 'ACT'),
    ('Juan', 'Rodriguez', 'DNI', '87654321', 'juan@example.com', '1990-05-10', 'INA'),
    ('Maria', 'Gonzalez', 'DNI', '11223344', NULL, NULL, 'PRO');
GO


/* ============================================================
   Services
   ============================================================ */

DECLARE @seqTelefonia BIGINT = NEXT VALUE FOR dbo.Seq_NumeroServicio;
DECLARE @seqInternet BIGINT = NEXT VALUE FOR dbo.Seq_NumeroServicio;

INSERT INTO dbo.Servicio (
    id_persona,
    id_tipo_servicio,
    numero_servicio,
    telefono,
    calle,
    numero,
    piso,
    depto,
    fecha_inicio,
    id_estado_servicio
)
VALUES
(
    1,
    1,
    CONCAT('TEL-', RIGHT('000000' + CAST(@seqTelefonia AS VARCHAR(20)), 6)),
    '01123456789',
    'Calle Falsa',
    '123',
    '1',
    'A',
    '2025-05-15 09:00:00',
    'ACT'
),
(
    2,
    2,
    CONCAT('INT-', RIGHT('000000' + CAST(@seqInternet AS VARCHAR(20)), 6)),
    NULL,
    'Calle Verdadera',
    '456',
    '2',
    'B',
    '2025-05-20 10:00:00',
    'INA'
);
GO


/* ============================================================
   Sample resolved ticket

   Ticket #1 uses:
   - Person #1
   - Service #1: Telefonia fija
   - Typology #4: Facturacion de Cargos Erroneos
   - SLA: 24 hours

   Total elapsed time: 23 hours
   Time in PCL:          4 hours
   Effective resolution: 19 hours
   Expected SLA result: compliant
   ============================================================ */

INSERT INTO dbo.Ticket (
    fecha_apertura,
    fecha_cierre,
    fecha_resolucion,
    id_persona,
    id_empleado,
    id_estado_ticket,
    id_servicio,
    id_tipologia
)
VALUES
(
    '2025-06-01 09:00:00',
    NULL,
    '2025-06-02 08:00:00',
    1,
    1,
    'RES',
    1,
    4
);
GO

INSERT INTO dbo.Estados_Historicos (
    id_ticket,
    id_estado_anterior,
    id_estado_nuevo,
    fecha_cambio
)
VALUES
    (1, NULL,  'ABI', '2025-06-01 09:00:00'),
    (1, 'ABI', 'EPR', '2025-06-01 09:30:00'),
    (1, 'EPR', 'PCL', '2025-06-01 12:00:00'),
    (1, 'PCL', 'EPR', '2025-06-01 16:00:00'),
    (1, 'EPR', 'RES', '2025-06-02 08:00:00');
GO

INSERT INTO dbo.Actividades (
    id_ticket,
    nombre,
    descripcion,
    fecha
)
VALUES
    (1, 'Revision de facturacion', 'Se revisaron los cargos asociados al servicio.', '2025-06-01 10:00:00'),
    (1, 'Solicitud de informacion', 'Se solicito documentacion adicional al cliente.', '2025-06-01 12:00:00'),
    (1, 'Correccion aplicada', 'Se corrigio el cargo reportado y se valido el resultado.', '2025-06-02 07:30:00');
GO

/*
    Email_Notificacion is intentionally not seeded.
    It will be populated by TRG_Ticket_GenerarNotificacion when ticket
    status changes are executed through the application workflow.
*/
