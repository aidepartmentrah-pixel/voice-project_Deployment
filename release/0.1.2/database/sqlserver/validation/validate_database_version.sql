/*
  validate_database_version.sql
  Confirms SchemaVersion exists and has at least one row recorded.
*/

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'SchemaVersion')
BEGIN
    RAISERROR('VALIDATION FAILED — SchemaVersion table does not exist. Run install/011_record_database_version.sql.', 16, 1);
END
ELSE IF NOT EXISTS (SELECT 1 FROM SchemaVersion)
BEGIN
    RAISERROR('VALIDATION FAILED — SchemaVersion table exists but has no rows.', 16, 1);
END
ELSE
BEGIN
    DECLARE @v NVARCHAR(20) = (SELECT TOP 1 version FROM SchemaVersion ORDER BY applied_at DESC);
    PRINT 'PASS — current schema version: ' + @v;
END
GO
