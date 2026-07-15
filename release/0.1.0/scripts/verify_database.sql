/*
  verify_database.sql
  Convenience wrapper that runs every check in database/sqlserver/validation/
  in order and reports overall pass/fail. Intended to be invoked by
  install_database.sh/.ps1 after installation, and usable standalone
  post-restore.
*/

:setvar DB_NAME "BloodBankDB"
USE [$(DB_NAME)];
GO

PRINT '=== Validating tables ===';
:r ../database/sqlserver/validation/validate_tables.sql

PRINT '=== Validating constraints ===';
:r ../database/sqlserver/validation/validate_constraints.sql

PRINT '=== Validating indexes ===';
:r ../database/sqlserver/validation/validate_indexes.sql

PRINT '=== Validating lookup data ===';
:r ../database/sqlserver/validation/validate_lookup_data.sql

PRINT '=== Validating configuration ===';
:r ../database/sqlserver/validation/validate_configuration.sql

PRINT '=== Validating users ===';
:r ../database/sqlserver/validation/validate_users.sql

PRINT '=== Validating database version ===';
:r ../database/sqlserver/validation/validate_database_version.sql

PRINT '=== Verification complete ===';
GO
