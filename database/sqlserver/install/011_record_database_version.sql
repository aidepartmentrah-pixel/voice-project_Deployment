/*
  011_record_database_version.sql
  Creates SchemaVersion (new — nothing in this application recorded a schema
  version before this package existed) and records the initial version.

  Every future migration in database/sqlserver/migrations/ must append its
  own row here after applying, so `SELECT MAX(version)` always reflects the
  live schema. See database/sqlserver/migrations/README.md.
*/

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'SchemaVersion')
BEGIN
    CREATE TABLE SchemaVersion (
        version     NVARCHAR(20) PRIMARY KEY,
        applied_at  DATETIME     NOT NULL DEFAULT GETDATE(),
        description NVARCHAR(255) NULL
    );
    PRINT 'Created table SchemaVersion';
END
GO

IF NOT EXISTS (SELECT 1 FROM SchemaVersion WHERE version = '1.0.0')
BEGIN
    INSERT INTO SchemaVersion (version, description)
    VALUES ('1.0.0', 'Initial SQL Server Database Package for voice-project (BloodBankDB) — RAH Lab');
    PRINT 'Recorded initial schema version 1.0.0';
END
GO
