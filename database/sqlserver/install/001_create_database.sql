/*
  001_create_database.sql
  Creates the BloodBankDB database if it does not already exist, then creates
  the application's SQL login + database user (DB_USER/DB_PASSWORD) if it
  doesn't already exist, granting it db_owner on the target database.

  Must be run authenticated as "sa" (or another sysadmin login) — on a brand
  new SQL Server container, DB_USER doesn't exist yet, so nothing else can
  authenticate to create it. This is the one script in the install package
  that runs with elevated credentials; every script after this one, and the
  application itself at runtime, uses DB_USER/DB_PASSWORD only.

    sqlcmd -S $(DB_SERVER),$(DB_PORT) -U sa -P $(SA_PASSWORD) -C \
           -v DB_NAME="$(DB_NAME)" -v APP_USER="$(DB_USER)" -v APP_PASSWORD="$(DB_PASSWORD)" \
           -i 001_create_database.sql

  Safe to re-run: does nothing if the database or login already exist (never
  recreates or drops an existing production database, never rotates an
  existing login's password as a side effect).
*/

-- Deliberately no `:setvar DB_NAME` default here: sqlcmd's own `:setvar`
-- unconditionally overwrites a value already passed via `-v` (the two
-- don't merge -- whichever runs last wins), so a hardcoded default here
-- would silently discard install_database.sh's own `-v DB_NAME=...`
-- every single time, regardless of what the real, Packager-computed
-- DB_NAME actually is. Invisible while DB_NAME always happened to equal
-- "BloodBankDB"; a real, latent bug the Consistent Database Identity
-- work's own derived value (voice_project, not BloodBankDB) would have
-- triggered on the very first install. install_database.sh already
-- enforces DB_NAME is set (`: "${DB_NAME:?DB_NAME is required}"`) before
-- ever invoking this script, so there is no real standalone-execution
-- case this default was actually protecting.

IF DB_ID(N'$(DB_NAME)') IS NULL
BEGIN
    PRINT 'Creating database [$(DB_NAME)]...';
    EXEC('CREATE DATABASE [$(DB_NAME)]');
END
ELSE
BEGIN
    PRINT 'Database [$(DB_NAME)] already exists — skipping creation.';
END
GO

-- ── Application login (server-level) ─────────────────────────────
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'$(APP_USER)')
BEGIN
    PRINT 'Creating login [$(APP_USER)]...';
    EXEC('CREATE LOGIN [$(APP_USER)] WITH PASSWORD = N''$(APP_PASSWORD)'', CHECK_POLICY = OFF');
END
ELSE
BEGIN
    PRINT 'Login [$(APP_USER)] already exists — leaving its password untouched.';
END
GO

-- ── Application database user + permissions (database-level) ────
USE [$(DB_NAME)];
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$(APP_USER)')
BEGIN
    PRINT 'Creating database user [$(APP_USER)] in [$(DB_NAME)]...';
    EXEC('CREATE USER [$(APP_USER)] FOR LOGIN [$(APP_USER)]');
    EXEC('ALTER ROLE db_owner ADD MEMBER [$(APP_USER)]');
END
ELSE
BEGIN
    PRINT 'Database user [$(APP_USER)] already exists in [$(DB_NAME)] — skipping.';
END
GO
