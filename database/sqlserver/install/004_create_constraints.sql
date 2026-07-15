/*
  004_create_constraints.sql
  Constraints beyond what's already declared inline in 002_create_schema.sql
  (PRIMARY KEY / UNIQUE / DEFAULT are already on the CREATE TABLE statements).

  HospitalUsers.role: server.js's POST/PUT /users handlers only ever write
  'admin' or 'staff' (see the validRole ternary in server.js). Adding this
  CHECK constraint documents that invariant in the schema itself.

  NOTE: if this script is ever run against a live database that somehow
  already contains a role value outside ('admin','staff'), the ALTER TABLE
  will fail loudly rather than silently corrupting data — that is
  intentional. Investigate the offending rows before re-running.
*/

IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE name = 'CK_HospitalUsers_role' AND parent_object_id = OBJECT_ID('HospitalUsers')
)
BEGIN
    ALTER TABLE HospitalUsers
        ADD CONSTRAINT CK_HospitalUsers_role CHECK (role IN ('admin', 'staff'));
END
GO
