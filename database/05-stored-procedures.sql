/*
    Telecom Call Center Database
    Step 05 - Stored procedures

    Portfolio refactor based on the original academic specification.
    Target DBMS: Microsoft SQL Server

    Design decision for errors:
      - Expected business-validation failures are returned through
        @ErrorCode / @ErrorMessage and do NOT raise SQL exceptions.
      - Unexpected SQL Server errors are caught and returned through
        the same output parameters.
      - Procedures that create entities also return the generated ID.

    Original business-error ranges are preserved where possible:
      50001-50009  Person creation
      50010-50019  Service creation
      50020-50029  Service deactivation
      50030-50039  Ticket creation
      50040-50049  Ticket state changes
      50050-50059  Ticket reassignment
      50060-50069  Person modification
      50070-50079  Ticket activities
*/

USE TelecomCallCenterDB;
GO

SET NOCOUNT ON;
GO


/* ============================================================
   1. SP_AltaPersona
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.SP_AltaPersona
    @Nombre VARCHAR(50),
    @Apellido VARCHAR(50),
    @Tipo_documento VARCHAR(10),
    @Nro_documento VARCHAR(8),
    @Email VARCHAR(100) = NULL,
    @Fecha_nacimiento DATE = NULL,
    @id_persona_generado INT OUTPUT,
    @ErrorCode INT OUTPUT,
    @ErrorMessage VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @id_persona_generado = 0;
    SET @ErrorCode = 0;
    SET @ErrorMessage = '';

    SET @Nombre = LTRIM(RTRIM(@Nombre));
    SET @Apellido = LTRIM(RTRIM(@Apellido));
    SET @Tipo_documento = LTRIM(RTRIM(@Tipo_documento));
    SET @Nro_documento = LTRIM(RTRIM(@Nro_documento));
    SET @Email = NULLIF(LTRIM(RTRIM(@Email)), '');

    IF @Nombre IS NULL OR @Nombre = ''
    BEGIN
        SET @ErrorCode = 50001;
        SET @ErrorMessage = 'El nombre es obligatorio';
        RETURN;
    END;

    IF @Apellido IS NULL OR @Apellido = ''
    BEGIN
        SET @ErrorCode = 50002;
        SET @ErrorMessage = 'El apellido es obligatorio';
        RETURN;
    END;

    IF @Tipo_documento IS NULL OR @Tipo_documento = ''
    BEGIN
        SET @ErrorCode = 50003;
        SET @ErrorMessage = 'El tipo de documento es obligatorio';
        RETURN;
    END;

    IF @Nro_documento IS NULL OR @Nro_documento = ''
    BEGIN
        SET @ErrorCode = 50004;
        SET @ErrorMessage = 'El numero de documento es obligatorio';
        RETURN;
    END;

    IF dbo.FN_ValidarDocumento(@Nro_documento) = 0
    BEGIN
        SET @ErrorCode = 50005;
        SET @ErrorMessage = 'El numero de documento debe contener 7 u 8 digitos';
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM dbo.Persona
        WHERE tipo_documento = @Tipo_documento
          AND nro_documento = @Nro_documento
    )
    BEGIN
        SET @ErrorCode = 50006;
        SET @ErrorMessage = 'Ya existe una persona con ese tipo y numero de documento';
        RETURN;
    END;

    IF @Email IS NOT NULL
       AND dbo.FN_ValidarEmail(@Email) = 0
    BEGIN
        SET @ErrorCode = 50007;
        SET @ErrorMessage = 'El formato del email no es valido';
        RETURN;
    END;

    IF @Fecha_nacimiento IS NOT NULL
       AND (
            dbo.FN_CalcularEdad(@Fecha_nacimiento) IS NULL
            OR dbo.FN_CalcularEdad(@Fecha_nacimiento) < 18
       )
    BEGIN
        SET @ErrorCode = 50008;
        SET @ErrorMessage = 'La persona debe tener al menos 18 anos';
        RETURN;
    END;

    BEGIN TRY
        INSERT INTO dbo.Persona (
            nombre,
            apellido,
            tipo_documento,
            nro_documento,
            email,
            fecha_nacimiento,
            id_estado_persona
        )
        VALUES (
            @Nombre,
            @Apellido,
            @Tipo_documento,
            @Nro_documento,
            @Email,
            @Fecha_nacimiento,
            'PRO'
        );

        SET @id_persona_generado = CONVERT(INT, SCOPE_IDENTITY());
    END TRY
    BEGIN CATCH
        SET @id_persona_generado = 0;
        SET @ErrorCode = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH;
END;
GO


/* ============================================================
   2. SP_CrearServicio
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.SP_CrearServicio
    @id_persona INT,
    @id_tipo_servicio INT,
    @telefono VARCHAR(20) = NULL,
    @calle VARCHAR(100),
    @numero VARCHAR(30),
    @piso VARCHAR(10) = NULL,
    @depto VARCHAR(10) = NULL,
    @id_servicio_generado INT OUTPUT,
    @numero_servicio_generado VARCHAR(20) OUTPUT,
    @ErrorCode INT OUTPUT,
    @ErrorMessage VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @id_servicio_generado = 0;
    SET @numero_servicio_generado = '';
    SET @ErrorCode = 0;
    SET @ErrorMessage = '';

    SET @telefono = NULLIF(LTRIM(RTRIM(@telefono)), '');
    SET @calle = LTRIM(RTRIM(@calle));
    SET @numero = LTRIM(RTRIM(@numero));
    SET @piso = NULLIF(LTRIM(RTRIM(@piso)), '');
    SET @depto = NULLIF(LTRIM(RTRIM(@depto)), '');

    DECLARE @estado_persona CHAR(3);
    DECLARE @email_persona VARCHAR(100);
    DECLARE @fecha_nacimiento_persona DATE;
    DECLARE @correlativo BIGINT;

    SELECT
        @estado_persona = p.id_estado_persona,
        @email_persona = p.email,
        @fecha_nacimiento_persona = p.fecha_nacimiento
    FROM dbo.Persona AS p
    WHERE p.id_persona = @id_persona;

    IF @estado_persona IS NULL
    BEGIN
        SET @ErrorCode = 50010;
        SET @ErrorMessage = 'La persona especificada no existe';
        RETURN;
    END;

    IF @estado_persona = 'PRO'
       AND (
            @email_persona IS NULL
            OR @fecha_nacimiento_persona IS NULL
       )
    BEGIN
        SET @ErrorCode = 50011;
        SET @ErrorMessage = 'Un prospecto debe tener email y fecha de nacimiento para contratar servicios';
        RETURN;
    END;

    IF @estado_persona = 'PRO'
       AND (
            dbo.FN_ValidarEmail(@email_persona) = 0
            OR dbo.FN_CalcularEdad(@fecha_nacimiento_persona) IS NULL
            OR dbo.FN_CalcularEdad(@fecha_nacimiento_persona) < 18
       )
    BEGIN
        SET @ErrorCode = 50017;
        SET @ErrorMessage = 'Los datos del prospecto no cumplen las validaciones requeridas para contratar servicios';
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Tipo_Servicio
        WHERE id_tipo_servicio = @id_tipo_servicio
    )
    BEGIN
        SET @ErrorCode = 50012;
        SET @ErrorMessage = 'El tipo de servicio especificado no existe';
        RETURN;
    END;

    IF @id_tipo_servicio IN (1, 3)
       AND @telefono IS NULL
    BEGIN
        SET @ErrorCode = 50013;
        SET @ErrorMessage = 'El telefono es obligatorio para Telefonia fija y VOIP';
        RETURN;
    END;

    IF @id_tipo_servicio = 2
       AND @telefono IS NOT NULL
    BEGIN
        SET @ErrorCode = 50016;
        SET @ErrorMessage = 'Los servicios de Internet no deben almacenar telefono';
        RETURN;
    END;

    IF @calle IS NULL OR @calle = ''
    BEGIN
        SET @ErrorCode = 50014;
        SET @ErrorMessage = 'La calle es obligatoria';
        RETURN;
    END;

    IF @numero IS NULL OR @numero = ''
    BEGIN
        SET @ErrorCode = 50015;
        SET @ErrorMessage = 'El numero de la direccion es obligatorio';
        RETURN;
    END;

    BEGIN TRY
        /*
            SQL Server sequences are intentionally consumed outside the
            transaction semantics of the entity insert. Gaps are therefore
            possible after a failed attempt, which is acceptable because
            the sequence is an identifier generator, not a row counter.
        */
        SET @correlativo = NEXT VALUE FOR dbo.Seq_NumeroServicio;

        SET @numero_servicio_generado =
            dbo.FN_GenerarNumeroServicio(
                @id_tipo_servicio,
                @correlativo
            );

        IF @numero_servicio_generado IS NULL
        BEGIN
            SET @ErrorCode = 50018;
            SET @ErrorMessage = 'No se pudo generar el numero de servicio';
            RETURN;
        END;

        BEGIN TRANSACTION;

        INSERT INTO dbo.Servicio (
            id_persona,
            id_tipo_servicio,
            numero_servicio,
            telefono,
            calle,
            numero,
            piso,
            depto,
            id_estado_servicio
        )
        VALUES (
            @id_persona,
            @id_tipo_servicio,
            @numero_servicio_generado,
            @telefono,
            @calle,
            @numero,
            @piso,
            @depto,
            'ACT'
        );

        SET @id_servicio_generado = CONVERT(INT, SCOPE_IDENTITY());

        IF @estado_persona IN ('PRO', 'INA')
        BEGIN
            UPDATE dbo.Persona
            SET id_estado_persona = 'ACT'
            WHERE id_persona = @id_persona;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @id_servicio_generado = 0;
        SET @numero_servicio_generado = '';
        SET @ErrorCode = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH;
END;
GO


/* ============================================================
   3. SP_InactivarServicio
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.SP_InactivarServicio
    @id_servicio INT,
    @id_usuario_ejecuta INT,
    @ErrorCode INT OUTPUT,
    @ErrorMessage VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @ErrorCode = 0;
    SET @ErrorMessage = '';

    DECLARE @id_persona INT;
    DECLARE @estado_servicio CHAR(3);

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Empleado
        WHERE id_empleado = @id_usuario_ejecuta
          AND id_estado_empleado = 'ACT'
    )
    BEGIN
        SET @ErrorCode = 50020;
        SET @ErrorMessage = 'El usuario especificado no existe o no esta activo';
        RETURN;
    END;

    SELECT
        @id_persona = s.id_persona,
        @estado_servicio = s.id_estado_servicio
    FROM dbo.Servicio AS s
    WHERE s.id_servicio = @id_servicio;

    IF @id_persona IS NULL
    BEGIN
        SET @ErrorCode = 50021;
        SET @ErrorMessage = 'El servicio especificado no existe';
        RETURN;
    END;

    IF @estado_servicio <> 'ACT'
    BEGIN
        SET @ErrorCode = 50022;
        SET @ErrorMessage = 'El servicio ya esta inactivo';
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.Servicio
        SET id_estado_servicio = 'INA'
        WHERE id_servicio = @id_servicio
          AND id_estado_servicio = 'ACT';

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Servicio
            WHERE id_persona = @id_persona
              AND id_estado_servicio = 'ACT'
        )
        BEGIN
            UPDATE dbo.Persona
            SET id_estado_persona = 'INA'
            WHERE id_persona = @id_persona;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @ErrorCode = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH;
END;
GO


/* ============================================================
   4. SP_CrearTicket
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.SP_CrearTicket
    @id_persona INT,
    @id_empleado_dueno INT,
    @id_servicio INT = NULL,
    @id_tipologia INT,
    @id_ticket_generado INT OUTPUT,
    @ErrorCode INT OUTPUT,
    @ErrorMessage VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @id_ticket_generado = 0;
    SET @ErrorCode = 0;
    SET @ErrorMessage = '';

    DECLARE @id_tipo_servicio INT = NULL;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Persona
        WHERE id_persona = @id_persona
    )
    BEGIN
        SET @ErrorCode = 50030;
        SET @ErrorMessage = 'La persona especificada no existe';
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Empleado
        WHERE id_empleado = @id_empleado_dueno
          AND id_estado_empleado = 'ACT'
    )
    BEGIN
        SET @ErrorCode = 50031;
        SET @ErrorMessage = 'El empleado especificado no existe o no esta activo';
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Tipologia
        WHERE id_tipologia = @id_tipologia
    )
    BEGIN
        SET @ErrorCode = 50032;
        SET @ErrorMessage = 'La tipologia especificada no existe';
        RETURN;
    END;

    IF @id_servicio IS NOT NULL
    BEGIN
        SELECT
            @id_tipo_servicio = s.id_tipo_servicio
        FROM dbo.Servicio AS s
        WHERE s.id_servicio = @id_servicio
          AND s.id_persona = @id_persona;

        IF @id_tipo_servicio IS NULL
        BEGIN
            SET @ErrorCode = 50033;
            SET @ErrorMessage = 'El servicio especificado no existe o no pertenece a la persona';
            RETURN;
        END;

        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Tipologia_Servicio
            WHERE id_tipologia = @id_tipologia
              AND id_tipo_servicio = @id_tipo_servicio
        )
        BEGIN
            SET @ErrorCode = 50034;
            SET @ErrorMessage = 'La tipologia no es compatible con el tipo de servicio';
            RETURN;
        END;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.Ticket (
            id_persona,
            id_empleado,
            id_estado_ticket,
            id_servicio,
            id_tipologia
        )
        VALUES (
            @id_persona,
            @id_empleado_dueno,
            'ABI',
            @id_servicio,
            @id_tipologia
        );

        SET @id_ticket_generado = CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO dbo.Estados_Historicos (
            id_ticket,
            id_estado_anterior,
            id_estado_nuevo,
            fecha_cambio
        )
        VALUES (
            @id_ticket_generado,
            NULL,
            'ABI',
            SYSDATETIME()
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @id_ticket_generado = 0;
        SET @ErrorCode = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH;
END;
GO


/* ============================================================
   5. SP_CambiarEstadoTicket
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.SP_CambiarEstadoTicket
    @id_ticket INT,
    @id_estado_nuevo CHAR(3),
    @id_usuario_ejecuta INT,
    @ErrorCode INT OUTPUT,
    @ErrorMessage VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @ErrorCode = 0;
    SET @ErrorMessage = '';

    DECLARE @estado_actual CHAR(3);
    DECLARE @id_empleado_dueno INT;
    DECLARE @momento DATETIME2(0);

    SELECT
        @estado_actual = t.id_estado_ticket,
        @id_empleado_dueno = t.id_empleado
    FROM dbo.Ticket AS t
    WHERE t.id_ticket = @id_ticket;

    IF @estado_actual IS NULL
    BEGIN
        SET @ErrorCode = 50040;
        SET @ErrorMessage = 'El ticket especificado no existe';
        RETURN;
    END;

    IF @id_usuario_ejecuta <> @id_empleado_dueno
    BEGIN
        SET @ErrorCode = 50041;
        SET @ErrorMessage = 'Solo el dueno del ticket puede cambiar su estado';
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Empleado
        WHERE id_empleado = @id_usuario_ejecuta
          AND id_estado_empleado = 'ACT'
    )
    BEGIN
        SET @ErrorCode = 50042;
        SET @ErrorMessage = 'El usuario no esta activo';
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Estado_Ticket
        WHERE id_estado_ticket = @id_estado_nuevo
    )
    BEGIN
        SET @ErrorCode = 50043;
        SET @ErrorMessage = 'El estado especificado no existe';
        RETURN;
    END;

    IF dbo.FN_ValidarTransicionEstado(
        @estado_actual,
        @id_estado_nuevo
    ) = 0
    BEGIN
        SET @ErrorCode = 50044;
        SET @ErrorMessage = 'La transicion de estado no es valida';
        RETURN;
    END;

    BEGIN TRY
        SET @momento = SYSDATETIME();

        BEGIN TRANSACTION;

        /*
            The original academic rule records resolution when the
            ticket reaches RES and closure when it reaches CER.
            Because the definitive state machine requires RES -> CER,
            fecha_resolucion is preserved during closure.
        */
        UPDATE dbo.Ticket
        SET
            id_estado_ticket = @id_estado_nuevo,
            fecha_resolucion =
                CASE
                    WHEN @id_estado_nuevo = 'RES'
                         AND fecha_resolucion IS NULL
                        THEN @momento
                    ELSE fecha_resolucion
                END,
            fecha_cierre =
                CASE
                    WHEN @id_estado_nuevo = 'CER'
                        THEN @momento
                    ELSE fecha_cierre
                END
        WHERE id_ticket = @id_ticket;

        INSERT INTO dbo.Estados_Historicos (
            id_ticket,
            id_estado_anterior,
            id_estado_nuevo,
            fecha_cambio
        )
        VALUES (
            @id_ticket,
            @estado_actual,
            @id_estado_nuevo,
            @momento
        );

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        SET @ErrorCode = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH;
END;
GO


/* ============================================================
   6. SP_ReasignarTicket

   This procedure was documented in the original specification
   but was missing from STORE-PROCEDURE.sql.
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.SP_ReasignarTicket
    @id_ticket INT,
    @id_empleado_nuevo INT,
    @id_usuario_ejecuta INT,
    @ErrorCode INT OUTPUT,
    @ErrorMessage VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @ErrorCode = 0;
    SET @ErrorMessage = '';

    DECLARE @estado_ticket CHAR(3);
    DECLARE @id_empleado_actual INT;

    SELECT
        @estado_ticket = t.id_estado_ticket,
        @id_empleado_actual = t.id_empleado
    FROM dbo.Ticket AS t
    WHERE t.id_ticket = @id_ticket;

    IF @estado_ticket IS NULL
    BEGIN
        SET @ErrorCode = 50050;
        SET @ErrorMessage = 'El ticket especificado no existe';
        RETURN;
    END;

    IF @estado_ticket = 'CER'
    BEGIN
        SET @ErrorCode = 50051;
        SET @ErrorMessage = 'No se puede reasignar un ticket cerrado';
        RETURN;
    END;

    IF @id_usuario_ejecuta <> @id_empleado_actual
    BEGIN
        SET @ErrorCode = 50052;
        SET @ErrorMessage = 'Solo el dueno actual puede reasignar el ticket';
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Empleado
        WHERE id_empleado = @id_usuario_ejecuta
          AND id_estado_empleado = 'ACT'
    )
    BEGIN
        SET @ErrorCode = 50053;
        SET @ErrorMessage = 'El usuario que ejecuta la reasignacion no esta activo';
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Empleado
        WHERE id_empleado = @id_empleado_nuevo
          AND id_estado_empleado = 'ACT'
    )
    BEGIN
        SET @ErrorCode = 50054;
        SET @ErrorMessage = 'El nuevo empleado no existe o no esta activo';
        RETURN;
    END;

    IF @id_empleado_nuevo = @id_empleado_actual
    BEGIN
        SET @ErrorCode = 50055;
        SET @ErrorMessage = 'El nuevo empleado ya es el dueno del ticket';
        RETURN;
    END;

    BEGIN TRY
        UPDATE dbo.Ticket
        SET id_empleado = @id_empleado_nuevo
        WHERE id_ticket = @id_ticket;
    END TRY
    BEGIN CATCH
        SET @ErrorCode = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH;
END;
GO


/* ============================================================
   7. SP_ModificarPersona
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.SP_ModificarPersona
    @id_persona INT,
    @Nombre VARCHAR(50) = NULL,
    @Apellido VARCHAR(50) = NULL,
    @Fecha_nacimiento DATE = NULL,
    @Email VARCHAR(100) = NULL,
    @id_usuario_ejecuta INT,
    @ErrorCode INT OUTPUT,
    @ErrorMessage VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @ErrorCode = 0;
    SET @ErrorMessage = '';

    DECLARE @estado_persona CHAR(3);
    DECLARE @nombre_actual VARCHAR(50);
    DECLARE @apellido_actual VARCHAR(50);
    DECLARE @fecha_actual DATE;
    DECLARE @email_actual VARCHAR(100);
    DECLARE @email_nuevo VARCHAR(100);

    SELECT
        @estado_persona = p.id_estado_persona,
        @nombre_actual = p.nombre,
        @apellido_actual = p.apellido,
        @fecha_actual = p.fecha_nacimiento,
        @email_actual = p.email
    FROM dbo.Persona AS p
    WHERE p.id_persona = @id_persona;

    IF @estado_persona IS NULL
    BEGIN
        SET @ErrorCode = 50060;
        SET @ErrorMessage = 'La persona especificada no existe';
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Empleado
        WHERE id_empleado = @id_usuario_ejecuta
          AND id_estado_empleado = 'ACT'
    )
    BEGIN
        SET @ErrorCode = 50061;
        SET @ErrorMessage = 'El usuario no esta activo';
        RETURN;
    END;

    IF @Nombre IS NOT NULL
        SET @Nombre = LTRIM(RTRIM(@Nombre));

    IF @Apellido IS NOT NULL
        SET @Apellido = LTRIM(RTRIM(@Apellido));

    IF @Email IS NOT NULL
        SET @email_nuevo = NULLIF(LTRIM(RTRIM(@Email)), '');

    IF @Nombre IS NOT NULL
       AND ISNULL(@Nombre, '') <> ISNULL(@nombre_actual, '')
    BEGIN
        IF @estado_persona <> 'PRO'
        BEGIN
            SET @ErrorCode = 50062;
            SET @ErrorMessage = 'El nombre solo puede modificarse cuando la persona es prospecto';
            RETURN;
        END;

        IF @Nombre = ''
        BEGIN
            SET @ErrorCode = 50063;
            SET @ErrorMessage = 'El nombre no puede estar vacio';
            RETURN;
        END;
    END;

    IF @Apellido IS NOT NULL
       AND ISNULL(@Apellido, '') <> ISNULL(@apellido_actual, '')
    BEGIN
        IF @estado_persona <> 'PRO'
        BEGIN
            SET @ErrorCode = 50064;
            SET @ErrorMessage = 'El apellido solo puede modificarse cuando la persona es prospecto';
            RETURN;
        END;

        IF @Apellido = ''
        BEGIN
            SET @ErrorCode = 50065;
            SET @ErrorMessage = 'El apellido no puede estar vacio';
            RETURN;
        END;
    END;

    IF @Fecha_nacimiento IS NOT NULL
       AND (
            @fecha_actual IS NULL
            OR @Fecha_nacimiento <> @fecha_actual
       )
    BEGIN
        IF @estado_persona <> 'PRO'
        BEGIN
            SET @ErrorCode = 50066;
            SET @ErrorMessage = 'La fecha de nacimiento solo puede modificarse cuando la persona es prospecto';
            RETURN;
        END;

        IF dbo.FN_CalcularEdad(@Fecha_nacimiento) IS NULL
           OR dbo.FN_CalcularEdad(@Fecha_nacimiento) < 18
        BEGIN
            SET @ErrorCode = 50067;
            SET @ErrorMessage = 'La persona debe tener al menos 18 anos';
            RETURN;
        END;
    END;

    /*
        NULL means "parameter not supplied".
        An empty string means "clear the current email".
    */
    IF @Email IS NOT NULL
       AND ISNULL(@email_nuevo, '') <> ISNULL(@email_actual, '')
    BEGIN
        IF @email_nuevo IS NOT NULL
           AND dbo.FN_ValidarEmail(@email_nuevo) = 0
        BEGIN
            SET @ErrorCode = 50068;
            SET @ErrorMessage = 'El formato del email no es valido';
            RETURN;
        END;
    END;

    IF (
        (@Nombre IS NULL OR ISNULL(@Nombre, '') = ISNULL(@nombre_actual, ''))
        AND
        (@Apellido IS NULL OR ISNULL(@Apellido, '') = ISNULL(@apellido_actual, ''))
        AND
        (@Fecha_nacimiento IS NULL OR @Fecha_nacimiento = @fecha_actual)
        AND
        (@Email IS NULL OR ISNULL(@email_nuevo, '') = ISNULL(@email_actual, ''))
    )
    BEGIN
        SET @ErrorCode = 50069;
        SET @ErrorMessage = 'Debe especificar al menos un campo para modificar';
        RETURN;
    END;

    BEGIN TRY
        UPDATE dbo.Persona
        SET
            nombre =
                CASE
                    WHEN @Nombre IS NULL THEN nombre
                    ELSE @Nombre
                END,
            apellido =
                CASE
                    WHEN @Apellido IS NULL THEN apellido
                    ELSE @Apellido
                END,
            fecha_nacimiento =
                CASE
                    WHEN @Fecha_nacimiento IS NULL THEN fecha_nacimiento
                    ELSE @Fecha_nacimiento
                END,
            email =
                CASE
                    WHEN @Email IS NULL THEN email
                    ELSE @email_nuevo
                END
        WHERE id_persona = @id_persona;
    END TRY
    BEGIN CATCH
        SET @ErrorCode = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH;
END;
GO


/* ============================================================
   8. SP_AgregarActividad
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.SP_AgregarActividad
    @id_ticket INT,
    @Nombre VARCHAR(100),
    @Descripcion VARCHAR(100),
    @id_usuario_ejecuta INT,
    @id_actividad_generado INT OUTPUT,
    @ErrorCode INT OUTPUT,
    @ErrorMessage VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    SET @id_actividad_generado = 0;
    SET @ErrorCode = 0;
    SET @ErrorMessage = '';

    DECLARE @estado_ticket CHAR(3);
    DECLARE @id_empleado_dueno INT;

    SET @Nombre = LTRIM(RTRIM(@Nombre));
    SET @Descripcion = LTRIM(RTRIM(@Descripcion));

    SELECT
        @estado_ticket = t.id_estado_ticket,
        @id_empleado_dueno = t.id_empleado
    FROM dbo.Ticket AS t
    WHERE t.id_ticket = @id_ticket;

    IF @estado_ticket IS NULL
    BEGIN
        SET @ErrorCode = 50070;
        SET @ErrorMessage = 'El ticket especificado no existe';
        RETURN;
    END;

    IF @estado_ticket = 'CER'
    BEGIN
        SET @ErrorCode = 50071;
        SET @ErrorMessage = 'No se pueden agregar actividades a un ticket cerrado';
        RETURN;
    END;

    IF @id_usuario_ejecuta <> @id_empleado_dueno
    BEGIN
        SET @ErrorCode = 50072;
        SET @ErrorMessage = 'Solo el dueno del ticket puede agregar actividades';
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM dbo.Empleado
        WHERE id_empleado = @id_usuario_ejecuta
          AND id_estado_empleado = 'ACT'
    )
    BEGIN
        SET @ErrorCode = 50073;
        SET @ErrorMessage = 'El usuario no esta activo';
        RETURN;
    END;

    IF @Nombre IS NULL OR @Nombre = ''
    BEGIN
        SET @ErrorCode = 50074;
        SET @ErrorMessage = 'El nombre de la actividad es obligatorio';
        RETURN;
    END;

    IF @Descripcion IS NULL OR @Descripcion = ''
    BEGIN
        SET @ErrorCode = 50075;
        SET @ErrorMessage = 'La descripcion de la actividad es obligatoria';
        RETURN;
    END;

    BEGIN TRY
        INSERT INTO dbo.Actividades (
            id_ticket,
            nombre,
            descripcion,
            fecha
        )
        VALUES (
            @id_ticket,
            @Nombre,
            @Descripcion,
            SYSDATETIME()
        );

        SET @id_actividad_generado = CONVERT(INT, SCOPE_IDENTITY());
    END TRY
    BEGIN CATCH
        SET @id_actividad_generado = 0;
        SET @ErrorCode = ERROR_NUMBER();
        SET @ErrorMessage = ERROR_MESSAGE();
    END CATCH;
END;
GO
