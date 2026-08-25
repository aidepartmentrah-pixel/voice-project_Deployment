/*
  rollback_initial_install.sql
  Reverses database/sqlserver/install/ — drops every table this package
  creates, in FK-safe order (none of these tables currently have foreign
  keys between them, but this order is future-proofed for when they do).

  SAFETY GUARD: refuses to run if any business table already contains rows,
  to prevent accidentally destroying real hospital data. This script is only
  intended for rolling back a failed *first* installation on a fresh
  database — not for use against a live system with real records. See
  rollback/README.md for how to roll back after production data exists
  (restore from backup instead).
*/

DECLARE @rowcount INT = (
    SELECT
        ISNULL((SELECT COUNT(*) FROM HospitalUsers),        0) +
        ISNULL((SELECT COUNT(*) FROM TransfusionRequests),  0) +
        ISNULL((SELECT COUNT(*) FROM BloodDeliveries),      0) +
        ISNULL((SELECT COUNT(*) FROM VoiceTranscriptions),  0) +
        ISNULL((SELECT COUNT(*) FROM ExternalDeliveries),   0)
    WHERE EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'HospitalUsers')
);

IF @rowcount IS NOT NULL AND @rowcount > 0
BEGIN
    RAISERROR('REFUSING TO ROLL BACK — business tables already contain %d row(s) total. This script only rolls back a failed first install on an empty database. Restore from backup instead (see scripts/restore_database.sql).', 16, 1, @rowcount);
END
ELSE
BEGIN
    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'SchemaVersion')       DROP TABLE SchemaVersion;
    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'ExternalDeliveries')  DROP TABLE ExternalDeliveries;
    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'VoiceTranscriptions')  DROP TABLE VoiceTranscriptions;
    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'BloodDeliveries')      DROP TABLE BloodDeliveries;
    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'TransfusionRequests')  DROP TABLE TransfusionRequests;
    IF EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'HospitalUsers')        DROP TABLE HospitalUsers;
    PRINT 'Rolled back initial install — all package-created tables dropped (database was empty).';
END
GO
