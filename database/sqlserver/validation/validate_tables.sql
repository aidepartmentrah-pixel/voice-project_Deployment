/*
  validate_tables.sql
  Asserts that every table this application depends on exists. Prints PASS/
  FAIL per table and raises an error (non-zero exit for sqlcmd) if any are
  missing, so this can gate a Docker db-init service.
*/

DECLARE @missing NVARCHAR(MAX) = '';

IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'HospitalUsers')
    SET @missing = @missing + 'HospitalUsers, ';
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'TransfusionRequests')
    SET @missing = @missing + 'TransfusionRequests, ';
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'BloodDeliveries')
    SET @missing = @missing + 'BloodDeliveries, ';
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'VoiceTranscriptions')
    SET @missing = @missing + 'VoiceTranscriptions, ';
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'ExternalDeliveries')
    SET @missing = @missing + 'ExternalDeliveries, ';
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'SchemaVersion')
    SET @missing = @missing + 'SchemaVersion, ';

IF LEN(@missing) > 0
BEGIN
    RAISERROR('VALIDATION FAILED — missing table(s): %s', 16, 1, @missing);
END
ELSE
BEGIN
    PRINT 'PASS — all required tables exist.';
END
GO
