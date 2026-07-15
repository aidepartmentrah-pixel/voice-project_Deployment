/*
  008_seed_lookup_data.sql
  This application has no normalized lookup tables. Values such as
  blood_group, rh_factor, fpc_type/ffp_type/plt_type ("Stat" vs routine) are
  stored as free-text NVARCHAR columns populated directly from voice-parsed
  form input (see node-backend/voiceParser.js) — there is no foreign-keyed
  BloodGroups/RhFactors/Roles table anywhere in server.js.

  Per the project rule "do not redesign the database", this package does not
  introduce new lookup tables the application was never built to use. This
  file is kept as a placeholder so the install sequence numbering stays
  stable if normalized lookup tables are introduced later.
*/
