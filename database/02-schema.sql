/*
    Telecom Call Center Database
    Step 02 - Schema

    This schema keeps the core domain model of the original academic project
    while normalizing names, constraints, history tracking, and indexes.

    Target DBMS: Microsoft SQL Server
*/

USE TelecomCallCenterDB;
GO

SET NOCOUNT ON;
GO

/* ============================================================
   Catalog tables
   ============================================================ */

CREATE TABLE dbo.Estado_Persona (
    id_estado_persona CHAR(3) NOT NULL,
    descripcion VARCHAR(30) NOT NULL,

    CONSTRAINT PK_Estado_Persona
        PRIMARY KEY (id_estado_persona),

    CONSTRAINT UQ_Estado_Persona_Descripcion
        UNIQUE (descripcion)
);
GO

CREATE TABLE dbo.Estado_Empleado (
    id_estado_empleado CHAR(3) NOT NULL,
    descripcion VARCHAR(20) NOT NULL,

    CONSTRAINT PK_Estado_Empleado
        PRIMARY KEY (id_estado_empleado),

    CONSTRAINT UQ_Estado_Empleado_Descripcion
        UNIQUE (descripcion)
);
GO

CREATE TABLE dbo.Estado_Servicio (
    id_estado_servicio CHAR(3) NOT NULL,
    descripcion VARCHAR(20) NOT NULL,

    CONSTRAINT PK_Estado_Servicio
        PRIMARY KEY (id_estado_servicio),

    CONSTRAINT UQ_Estado_Servicio_Descripcion
        UNIQUE (descripcion)
);
GO

CREATE TABLE dbo.Estado_Ticket (
    id_estado_ticket CHAR(3) NOT NULL,
    descripcion VARCHAR(30) NOT NULL,

    CONSTRAINT PK_Estado_Ticket
        PRIMARY KEY (id_estado_ticket),

    CONSTRAINT UQ_Estado_Ticket_Descripcion
        UNIQUE (descripcion)
);
GO

CREATE TABLE dbo.Tipo_Servicio (
    id_tipo_servicio INT NOT NULL,
    descripcion VARCHAR(30) NOT NULL,

    CONSTRAINT PK_Tipo_Servicio
        PRIMARY KEY (id_tipo_servicio),

    CONSTRAINT UQ_Tipo_Servicio_Descripcion
        UNIQUE (descripcion)
);
GO

CREATE TABLE dbo.Tipologia (
    id_tipologia INT NOT NULL,
    nombre VARCHAR(100) NOT NULL,

    CONSTRAINT PK_Tipologia
        PRIMARY KEY (id_tipologia),

    CONSTRAINT UQ_Tipologia_Nombre
        UNIQUE (nombre)
);
GO


/* ============================================================
   Relationship tables
   ============================================================ */

CREATE TABLE dbo.Tipologia_Servicio (
    id_tipologia INT NOT NULL,
    id_tipo_servicio INT NOT NULL,
    SLA INT NOT NULL,

    CONSTRAINT PK_Tipologia_Servicio
        PRIMARY KEY (id_tipologia, id_tipo_servicio),

    CONSTRAINT FK_TipologiaServicio_Tipologia
        FOREIGN KEY (id_tipologia)
        REFERENCES dbo.Tipologia (id_tipologia),

    CONSTRAINT FK_TipologiaServicio_TipoServicio
        FOREIGN KEY (id_tipo_servicio)
        REFERENCES dbo.Tipo_Servicio (id_tipo_servicio),

    CONSTRAINT CK_TipologiaServicio_SLA_Positivo
        CHECK (SLA > 0)
);
GO


/* ============================================================
   Main entities
   ============================================================ */

CREATE TABLE dbo.Persona (
    id_persona INT IDENTITY(1,1) NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    apellido VARCHAR(50) NOT NULL,
    tipo_documento VARCHAR(10) NOT NULL,
    nro_documento VARCHAR(8) NOT NULL,
    email VARCHAR(100) NULL,
    fecha_nacimiento DATE NULL,
    id_estado_persona CHAR(3) NOT NULL,

    CONSTRAINT PK_Persona
        PRIMARY KEY (id_persona),

    CONSTRAINT UQ_Persona_Documento
        UNIQUE (tipo_documento, nro_documento),

    CONSTRAINT FK_Persona_EstadoPersona
        FOREIGN KEY (id_estado_persona)
        REFERENCES dbo.Estado_Persona (id_estado_persona),

    CONSTRAINT CK_Persona_Nombre_NoVacio
        CHECK (LEN(LTRIM(RTRIM(nombre))) > 0),

    CONSTRAINT CK_Persona_Apellido_NoVacio
        CHECK (LEN(LTRIM(RTRIM(apellido))) > 0),

    CONSTRAINT CK_Persona_TipoDocumento_NoVacio
        CHECK (LEN(LTRIM(RTRIM(tipo_documento))) > 0),

    CONSTRAINT CK_Persona_Documento_Formato
        CHECK (
            LEN(nro_documento) BETWEEN 7 AND 8
            AND nro_documento NOT LIKE '%[^0-9]%'
        )
);
GO

CREATE TABLE dbo.Empleado (
    id_empleado INT IDENTITY(1,1) NOT NULL,
    nombre VARCHAR(50) NOT NULL,
    apellido VARCHAR(50) NOT NULL,
    login VARCHAR(50) NOT NULL,
    id_estado_empleado CHAR(3) NOT NULL,

    CONSTRAINT PK_Empleado
        PRIMARY KEY (id_empleado),

    CONSTRAINT UQ_Empleado_Login
        UNIQUE (login),

    CONSTRAINT FK_Empleado_EstadoEmpleado
        FOREIGN KEY (id_estado_empleado)
        REFERENCES dbo.Estado_Empleado (id_estado_empleado),

    CONSTRAINT CK_Empleado_Nombre_NoVacio
        CHECK (LEN(LTRIM(RTRIM(nombre))) > 0),

    CONSTRAINT CK_Empleado_Apellido_NoVacio
        CHECK (LEN(LTRIM(RTRIM(apellido))) > 0),

    CONSTRAINT CK_Empleado_Login_NoVacio
        CHECK (LEN(LTRIM(RTRIM(login))) > 0)
);
GO

/*
    A SQL Server sequence replaces the original random service-number
    generation approach. The stored procedure layer will combine this
    correlativo with the service-type prefix.
*/
CREATE SEQUENCE dbo.Seq_NumeroServicio
    AS BIGINT
    START WITH 100001
    INCREMENT BY 1
    NO CYCLE;
GO

CREATE TABLE dbo.Servicio (
    id_servicio INT IDENTITY(1,1) NOT NULL,
    id_persona INT NOT NULL,
    id_tipo_servicio INT NOT NULL,
    numero_servicio VARCHAR(20) NOT NULL,
    telefono VARCHAR(20) NULL,
    calle VARCHAR(100) NOT NULL,
    numero VARCHAR(30) NOT NULL,
    piso VARCHAR(10) NULL,
    depto VARCHAR(10) NULL,
    fecha_inicio DATETIME2(0) NOT NULL
        CONSTRAINT DF_Servicio_FechaInicio DEFAULT (SYSDATETIME()),
    id_estado_servicio CHAR(3) NOT NULL,

    CONSTRAINT PK_Servicio
        PRIMARY KEY (id_servicio),

    CONSTRAINT UQ_Servicio_NumeroServicio
        UNIQUE (numero_servicio),

    /*
        This alternate key allows Ticket to enforce that an optional
        service belongs to the same person as the ticket.
    */
    CONSTRAINT UQ_Servicio_IdServicio_IdPersona
        UNIQUE (id_servicio, id_persona),

    CONSTRAINT FK_Servicio_Persona
        FOREIGN KEY (id_persona)
        REFERENCES dbo.Persona (id_persona),

    CONSTRAINT FK_Servicio_TipoServicio
        FOREIGN KEY (id_tipo_servicio)
        REFERENCES dbo.Tipo_Servicio (id_tipo_servicio),

    CONSTRAINT FK_Servicio_EstadoServicio
        FOREIGN KEY (id_estado_servicio)
        REFERENCES dbo.Estado_Servicio (id_estado_servicio),

    CONSTRAINT CK_Servicio_NumeroServicio_NoVacio
        CHECK (LEN(LTRIM(RTRIM(numero_servicio))) > 0),

    CONSTRAINT CK_Servicio_Calle_NoVacia
        CHECK (LEN(LTRIM(RTRIM(calle))) > 0),

    CONSTRAINT CK_Servicio_Numero_NoVacio
        CHECK (LEN(LTRIM(RTRIM(numero))) > 0)
);
GO

CREATE TABLE dbo.Ticket (
    id_ticket INT IDENTITY(1,1) NOT NULL,
    fecha_apertura DATETIME2(0) NOT NULL
        CONSTRAINT DF_Ticket_FechaApertura DEFAULT (SYSDATETIME()),
    fecha_cierre DATETIME2(0) NULL,
    fecha_resolucion DATETIME2(0) NULL,
    id_persona INT NOT NULL,
    id_empleado INT NOT NULL,
    id_estado_ticket CHAR(3) NOT NULL,
    id_servicio INT NULL,
    id_tipologia INT NOT NULL,

    CONSTRAINT PK_Ticket
        PRIMARY KEY (id_ticket),

    CONSTRAINT FK_Ticket_Persona
        FOREIGN KEY (id_persona)
        REFERENCES dbo.Persona (id_persona),

    CONSTRAINT FK_Ticket_Empleado
        FOREIGN KEY (id_empleado)
        REFERENCES dbo.Empleado (id_empleado),

    CONSTRAINT FK_Ticket_EstadoTicket
        FOREIGN KEY (id_estado_ticket)
        REFERENCES dbo.Estado_Ticket (id_estado_ticket),

    CONSTRAINT FK_Ticket_Tipologia
        FOREIGN KEY (id_tipologia)
        REFERENCES dbo.Tipologia (id_tipologia),

    /*
        When id_servicio is present, the composite FK guarantees that
        the service belongs to id_persona. A NULL service remains valid.
    */
    CONSTRAINT FK_Ticket_ServicioPersona
        FOREIGN KEY (id_servicio, id_persona)
        REFERENCES dbo.Servicio (id_servicio, id_persona),

    CONSTRAINT CK_Ticket_ResolucionPosteriorApertura
        CHECK (
            fecha_resolucion IS NULL
            OR fecha_resolucion >= fecha_apertura
        ),

    CONSTRAINT CK_Ticket_CierrePosteriorApertura
        CHECK (
            fecha_cierre IS NULL
            OR fecha_cierre >= fecha_apertura
        ),

    CONSTRAINT CK_Ticket_CierrePosteriorResolucion
        CHECK (
            fecha_cierre IS NULL
            OR fecha_resolucion IS NULL
            OR fecha_cierre >= fecha_resolucion
        )
);
GO


/* ============================================================
   Audit and operational tables
   ============================================================ */

CREATE TABLE dbo.Estados_Historicos (
    id_historico INT IDENTITY(1,1) NOT NULL,
    id_ticket INT NOT NULL,
    id_estado_anterior CHAR(3) NULL,
    id_estado_nuevo CHAR(3) NOT NULL,
    fecha_cambio DATETIME2(0) NOT NULL
        CONSTRAINT DF_EstadosHistoricos_FechaCambio DEFAULT (SYSDATETIME()),

    CONSTRAINT PK_Estados_Historicos
        PRIMARY KEY (id_historico),

    CONSTRAINT FK_EstadosHistoricos_Ticket
        FOREIGN KEY (id_ticket)
        REFERENCES dbo.Ticket (id_ticket),

    CONSTRAINT FK_EstadosHistoricos_EstadoAnterior
        FOREIGN KEY (id_estado_anterior)
        REFERENCES dbo.Estado_Ticket (id_estado_ticket),

    CONSTRAINT FK_EstadosHistoricos_EstadoNuevo
        FOREIGN KEY (id_estado_nuevo)
        REFERENCES dbo.Estado_Ticket (id_estado_ticket),

    CONSTRAINT CK_EstadosHistoricos_CambioReal
        CHECK (
            id_estado_anterior IS NULL
            OR id_estado_anterior <> id_estado_nuevo
        )
);
GO

CREATE TABLE dbo.Email_Notificacion (
    id_notificacion INT IDENTITY(1,1) NOT NULL,
    id_ticket INT NOT NULL,
    id_estado_anterior CHAR(3) NOT NULL,
    id_estado_nuevo CHAR(3) NOT NULL,
    fecha_envio DATETIME2(0) NULL,

    CONSTRAINT PK_Email_Notificacion
        PRIMARY KEY (id_notificacion),

    CONSTRAINT FK_EmailNotificacion_Ticket
        FOREIGN KEY (id_ticket)
        REFERENCES dbo.Ticket (id_ticket),

    CONSTRAINT FK_EmailNotificacion_EstadoAnterior
        FOREIGN KEY (id_estado_anterior)
        REFERENCES dbo.Estado_Ticket (id_estado_ticket),

    CONSTRAINT FK_EmailNotificacion_EstadoNuevo
        FOREIGN KEY (id_estado_nuevo)
        REFERENCES dbo.Estado_Ticket (id_estado_ticket),

    CONSTRAINT CK_EmailNotificacion_CambioReal
        CHECK (id_estado_anterior <> id_estado_nuevo)
);
GO

CREATE TABLE dbo.Actividades (
    id_actividad INT IDENTITY(1,1) NOT NULL,
    id_ticket INT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(100) NOT NULL,
    fecha DATETIME2(0) NOT NULL
        CONSTRAINT DF_Actividades_Fecha DEFAULT (SYSDATETIME()),

    CONSTRAINT PK_Actividades
        PRIMARY KEY (id_actividad),

    CONSTRAINT FK_Actividades_Ticket
        FOREIGN KEY (id_ticket)
        REFERENCES dbo.Ticket (id_ticket),

    CONSTRAINT CK_Actividades_Nombre_NoVacio
        CHECK (LEN(LTRIM(RTRIM(nombre))) > 0),

    CONSTRAINT CK_Actividades_Descripcion_NoVacia
        CHECK (LEN(LTRIM(RTRIM(descripcion))) > 0)
);
GO


/* ============================================================
   Supporting indexes
   ============================================================ */

CREATE INDEX IX_Servicio_Persona_Estado
    ON dbo.Servicio (id_persona, id_estado_servicio);
GO

CREATE INDEX IX_Ticket_Persona
    ON dbo.Ticket (id_persona);
GO

CREATE INDEX IX_Ticket_Empleado_Estado
    ON dbo.Ticket (id_empleado, id_estado_ticket);
GO

CREATE INDEX IX_Ticket_Servicio
    ON dbo.Ticket (id_servicio)
    WHERE id_servicio IS NOT NULL;
GO

CREATE INDEX IX_Ticket_Tipologia
    ON dbo.Ticket (id_tipologia);
GO

CREATE INDEX IX_EstadosHistoricos_Ticket_Fecha
    ON dbo.Estados_Historicos (id_ticket, fecha_cambio);
GO

CREATE INDEX IX_Actividades_Ticket_Fecha
    ON dbo.Actividades (id_ticket, fecha);
GO

CREATE INDEX IX_EmailNotificacion_Pendiente
    ON dbo.Email_Notificacion (id_ticket, id_notificacion)
    WHERE fecha_envio IS NULL;
GO
