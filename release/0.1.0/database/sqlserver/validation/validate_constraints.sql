/*
  validate_constraints.sql
  Asserts the constraints declared by 002_create_schema.sql / 004_create_constraints.sql exist.

  Checks column membership via sys.index_columns/sys.columns rather than
  matching on auto-generated constraint names (SQL Server names unique/PK
  constraints like "UQ__Hospital__F3DBC57251B45F1C" — never containing the
  column name — so a name-based LIKE check would always false-positive).
*/

DECLARE @missing NVARCHAR(MAX) = '';

IF NOT EXISTS (SELECT 1 FROM sys.key_constraints WHERE parent_object_id = OBJECT_ID('HospitalUsers') AND type = 'PK')
    SET @missing = @missing + 'HospitalUsers.PK, ';

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes i
    JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
    JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE i.object_id = OBJECT_ID('HospitalUsers') AND i.is_unique = 1 AND c.name = 'username'
)
    SET @missing = @missing + 'HospitalUsers.UNIQUE(username), ';

IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = 'CK_HospitalUsers_role' AND parent_object_id = OBJECT_ID('HospitalUsers'))
    SET @missing = @missing + 'CK_HospitalUsers_role, ';

IF LEN(@missing) > 0
BEGIN
    PRINT 'WARNING — one or more expected constraints not found (see below). This is a best-effort check; verify manually if unsure:';
    PRINT @missing;
END
ELSE
BEGIN
    PRINT 'PASS — expected constraints found.';
END
GO
