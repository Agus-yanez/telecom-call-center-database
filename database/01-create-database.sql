/*
    Telecom Call Center Database
    Step 01 - Database creation

    Portfolio refactor based on the original academic project.
    Target DBMS: Microsoft SQL Server
*/

USE master;
GO

IF DB_ID(N'TelecomCallCenterDB') IS NULL
BEGIN
    CREATE DATABASE TelecomCallCenterDB;
END;
GO

USE TelecomCallCenterDB;
GO
