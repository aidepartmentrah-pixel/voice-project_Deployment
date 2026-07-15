/*
  009_seed_configuration.sql
  This application has no application-configuration table — all
  configuration (DB connection, JWT secret, Whisper service URL) is supplied
  through environment variables read by node-backend/db.js and server.js,
  not stored in the database.

  This file is kept as a placeholder so the install sequence numbering stays
  stable if a configuration table is introduced later.
*/
