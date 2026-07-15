/*
  003_create_indexes.sql
  Non-clustered indexes matching the actual query patterns observed in
  node-backend/server.js (file_number lookups for duplicate-check/patient-
  lookup/response-time joins, and created_at for the dashboard's date-range
  scans and ORDER BY ... DESC). Idempotent — guarded by IF NOT EXISTS.

  HospitalUsers.username already has a unique index from its UNIQUE
  constraint (002_create_schema.sql), so no extra index is added there.
*/

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TransfusionRequests_file_number' AND object_id = OBJECT_ID('TransfusionRequests'))
    CREATE INDEX IX_TransfusionRequests_file_number ON TransfusionRequests(file_number);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TransfusionRequests_created_at' AND object_id = OBJECT_ID('TransfusionRequests'))
    CREATE INDEX IX_TransfusionRequests_created_at ON TransfusionRequests(created_at DESC);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_BloodDeliveries_file_number' AND object_id = OBJECT_ID('BloodDeliveries'))
    CREATE INDEX IX_BloodDeliveries_file_number ON BloodDeliveries(file_number);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_BloodDeliveries_created_at' AND object_id = OBJECT_ID('BloodDeliveries'))
    CREATE INDEX IX_BloodDeliveries_created_at ON BloodDeliveries(created_at DESC);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ExternalDeliveries_created_at' AND object_id = OBJECT_ID('ExternalDeliveries'))
    CREATE INDEX IX_ExternalDeliveries_created_at ON ExternalDeliveries(created_at DESC);
GO
