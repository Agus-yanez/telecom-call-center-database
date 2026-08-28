/*
    Telecom Call Center Database
    Step 04 - Auxiliary functions

    Portfolio refactor based on the original academic project.
    Target DBMS: Microsoft SQL Server

    Functions preserved conceptually from the original delivery:
      - FN_ValidarEmail
      - FN_ValidarDocumento
      - FN_GenerarNumeroServicio
      - FN_ValidarTransicionEstado
      - FN_CalcularTiempoResolucion
      - FN_VerificarCumplimientoSLA
      - FN_CalcularEdad
*/

USE TelecomCallCenterDB;
GO

SET NOCOUNT ON;
GO


/* ============================================================
   1. Email validation

   This is intentionally a pragmatic business validation rather
   than a full RFC email parser. It checks:
     - non-empty value;
     - no spaces;
     - exactly one "@";
     - non-empty local and domain parts;
     - at least one "." inside the domain;
     - "." is not the first or last character of the domain.
   ============================================================ */

CREATE OR ALTER FUNCTION dbo.FN_ValidarEmail (
    @Email VARCHAR(100)
)
RETURNS BIT
AS
BEGIN
    DECLARE @resultado BIT = 0;
    DECLARE @posArroba INT;
    DECLARE @dominio VARCHAR(100);
    DECLARE @cantidadArrobas INT;

    SET @Email = LTRIM(RTRIM(@Email));

    IF @Email IS NULL OR @Email = ''
        RETURN 0;

    IF @Email LIKE '% %'
        RETURN 0;

    SET @cantidadArrobas =
        LEN(@Email) - LEN(REPLACE(@Email, '@', ''));

    IF @cantidadArrobas <> 1
        RETURN 0;

    SET @posArroba = CHARINDEX('@', @Email);

    IF @posArroba <= 1 OR @posArroba = LEN(@Email)
        RETURN 0;

    SET @dominio = SUBSTRING(
        @Email,
        @posArroba + 1,
        LEN(@Email) - @posArroba
    );

    IF CHARINDEX('.', @dominio) <= 1
        RETURN 0;

    IF RIGHT(@dominio, 1) = '.'
        RETURN 0;

    SET @resultado = 1;
    RETURN @resultado;
END;
GO


/* ============================================================
   2. Document validation

   The original project used ISNUMERIC(), which accepts values
   that are not valid document numbers in this domain.
   The portfolio version validates exactly 7 or 8 digits.
   ============================================================ */

CREATE OR ALTER FUNCTION dbo.FN_ValidarDocumento (
    @Nro_documento VARCHAR(8)
)
RETURNS BIT
AS
BEGIN
    IF @Nro_documento IS NULL
        RETURN 0;

    IF LEN(@Nro_documento) NOT BETWEEN 7 AND 8
        RETURN 0;

    IF @Nro_documento LIKE '%[^0-9]%'
        RETURN 0;

    RETURN 1;
END;
GO


/* ============================================================
   3. Service number formatting

   Important:
   SQL Server sequence consumption is intentionally performed
   by SP_CrearServicio, not inside this scalar function.

   The procedure obtains:
       NEXT VALUE FOR dbo.Seq_NumeroServicio

   and this helper converts the service type + correlativo into
   a public service number such as:
       TEL-100001
       INT-100002
       VOIP-100003

   Returning NULL for an unknown type prevents silently creating
   a generic identifier for an invalid service type.
   ============================================================ */

CREATE OR ALTER FUNCTION dbo.FN_GenerarNumeroServicio (
    @id_tipo_servicio INT,
    @correlativo BIGINT
)
RETURNS VARCHAR(20)
AS
BEGIN
    DECLARE @prefijo VARCHAR(5);

    IF @correlativo IS NULL OR @correlativo <= 0
        RETURN NULL;

    SET @prefijo =
        CASE @id_tipo_servicio
            WHEN 1 THEN 'TEL'
            WHEN 2 THEN 'INT'
            WHEN 3 THEN 'VOIP'
            ELSE NULL
        END;

    IF @prefijo IS NULL
        RETURN NULL;

    RETURN CONCAT(
        @prefijo,
        '-',
        CONVERT(VARCHAR(14), @correlativo)
    );
END;
GO


/* ============================================================
   4. Ticket state transition validation

   Definitive state machine from the academic specification:

       ABI -> EPR, PCL
       EPR -> ABI, PCL, RES
       PCL -> EPR, RES
       RES -> CER
       CER -> no transition
   ============================================================ */

CREATE OR ALTER FUNCTION dbo.FN_ValidarTransicionEstado (
    @estado_actual CHAR(3),
    @estado_nuevo CHAR(3)
)
RETURNS BIT
AS
BEGIN
    IF @estado_actual IS NULL OR @estado_nuevo IS NULL
        RETURN 0;

    IF (
        (@estado_actual = 'ABI' AND @estado_nuevo IN ('EPR', 'PCL'))
        OR
        (@estado_actual = 'EPR' AND @estado_nuevo IN ('ABI', 'PCL', 'RES'))
        OR
        (@estado_actual = 'PCL' AND @estado_nuevo IN ('EPR', 'RES'))
        OR
        (@estado_actual = 'RES' AND @estado_nuevo = 'CER')
    )
        RETURN 1;

    RETURN 0;
END;
GO


/* ============================================================
   5. Effective ticket resolution time

   Business rule:
       effective resolution time
       =
       resolution - opening - time spent in PCL

   The event-based Estados_Historicos table records transitions.
   Every row whose new state is PCL starts a paused interval.
   The next history event closes that interval.

   The result is expressed in whole hours and rounded UP so that
   partial hours are not silently ignored when evaluating an SLA.

   NULL means:
       - ticket does not exist; or
       - ticket is not resolved yet.
   ============================================================ */

CREATE OR ALTER FUNCTION dbo.FN_CalcularTiempoResolucion (
    @id_ticket INT
)
RETURNS INT
AS
BEGIN
    DECLARE @fechaApertura DATETIME2(0);
    DECLARE @fechaResolucion DATETIME2(0);
    DECLARE @minutosTotales INT;
    DECLARE @minutosPendiente INT = 0;
    DECLARE @minutosEfectivos INT;

    SELECT
        @fechaApertura = t.fecha_apertura,
        @fechaResolucion = t.fecha_resolucion
    FROM dbo.Ticket AS t
    WHERE t.id_ticket = @id_ticket;

    IF @fechaApertura IS NULL OR @fechaResolucion IS NULL
        RETURN NULL;

    IF @fechaResolucion < @fechaApertura
        RETURN NULL;

    SET @minutosTotales =
        DATEDIFF(MINUTE, @fechaApertura, @fechaResolucion);

    /*
        SQL Server does not allow an aggregate such as SUM() to contain
        a correlated scalar subquery directly inside its expression.

        OUTER APPLY resolves the next history event first; SUM() then
        operates only on ordinary columns/values.
    */
    SELECT
        @minutosPendiente = ISNULL(
            SUM(
                DATEDIFF(
                    MINUTE,
                    h.fecha_cambio,
                    COALESCE(siguiente.fecha_cambio, @fechaResolucion)
                )
            ),
            0
        )
    FROM dbo.Estados_Historicos AS h
    OUTER APPLY (
        SELECT TOP (1)
            h2.fecha_cambio
        FROM dbo.Estados_Historicos AS h2
        WHERE h2.id_ticket = h.id_ticket
          AND h2.fecha_cambio > h.fecha_cambio
          AND h2.fecha_cambio <= @fechaResolucion
        ORDER BY h2.fecha_cambio ASC
    ) AS siguiente
    WHERE h.id_ticket = @id_ticket
      AND h.id_estado_nuevo = 'PCL'
      AND h.fecha_cambio < @fechaResolucion;

    SET @minutosEfectivos =
        @minutosTotales - ISNULL(@minutosPendiente, 0);

    IF @minutosEfectivos < 0
        RETURN NULL;

    IF @minutosEfectivos = 0
        RETURN 0;

    RETURN CONVERT(
        INT,
        CEILING(CONVERT(DECIMAL(18, 2), @minutosEfectivos) / 60.0)
    );
END;
GO


/* ============================================================
   6. SLA compliance

   SLA is defined by the combination:
       ticket typology + service type

   A ticket without a service has no applicable SLA in this
   portfolio model and therefore returns NULL.

   Returns:
       1    SLA met
       0    SLA missed
       NULL not applicable / unresolved / insufficient data
   ============================================================ */

CREATE OR ALTER FUNCTION dbo.FN_VerificarCumplimientoSLA (
    @id_ticket INT
)
RETURNS BIT
AS
BEGIN
    DECLARE @cumple BIT = NULL;
    DECLARE @tiempoResolucion INT;
    DECLARE @slaRequerido INT;

    SELECT
        @slaRequerido = ts.SLA
    FROM dbo.Ticket AS t
    INNER JOIN dbo.Servicio AS s
        ON s.id_servicio = t.id_servicio
       AND s.id_persona = t.id_persona
    INNER JOIN dbo.Tipologia_Servicio AS ts
        ON ts.id_tipologia = t.id_tipologia
       AND ts.id_tipo_servicio = s.id_tipo_servicio
    WHERE t.id_ticket = @id_ticket;

    IF @slaRequerido IS NULL
        RETURN NULL;

    SET @tiempoResolucion =
        dbo.FN_CalcularTiempoResolucion(@id_ticket);

    IF @tiempoResolucion IS NULL
        RETURN NULL;

    IF @tiempoResolucion <= @slaRequerido
        SET @cumple = 1;
    ELSE
        SET @cumple = 0;

    RETURN @cumple;
END;
GO


/* ============================================================
   7. Age calculation
   ============================================================ */

CREATE OR ALTER FUNCTION dbo.FN_CalcularEdad (
    @FechaNacimiento DATE
)
RETURNS INT
AS
BEGIN
    DECLARE @hoy DATE;
    DECLARE @edad INT;

    IF @FechaNacimiento IS NULL
        RETURN NULL;

    SET @hoy = CONVERT(DATE, GETDATE());

    IF @FechaNacimiento > @hoy
        RETURN NULL;

    SET @edad = DATEDIFF(YEAR, @FechaNacimiento, @hoy);

    IF DATEADD(YEAR, @edad, @FechaNacimiento) > @hoy
        SET @edad = @edad - 1;

    RETURN @edad;
END;
GO
