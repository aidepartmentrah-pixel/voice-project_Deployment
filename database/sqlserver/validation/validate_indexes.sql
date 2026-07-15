/*
  validate_indexes.sql
  Asserts the non-clustered indexes from 003_create_indexes.sql exist.
  Missing indexes are a performance concern, not a correctness one, so this
  prints WARNING rather than failing hard.
*/

DECLARE @missing NVARCHAR(MAX) = '';

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TransfusionRequests_file_number')
    SET @missing = @missing + 'IX_TransfusionRequests_file_number, ';
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TransfusionRequests_created_at')
    SET @missing = @missing + 'IX_TransfusionRequests_created_at, ';
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_BloodDeliveries_file_number')
    SET @missing = @missing + 'IX_BloodDeliveries_file_number, ';
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_BloodDeliveries_created_at')
    SET @missing = @missing + 'IX_BloodDeliveries_created_at, ';
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ExternalDeliveries_created_at')
    SET @missing = @missing + 'IX_ExternalDeliveries_created_at, ';

IF LEN(@missing) > 0
BEGIN
    PRINT 'WARNING — missing expected index(es): ' + @missing;
END
ELSE
BEGIN
    PRINT 'PASS — all expected indexes exist.';
END
GO
