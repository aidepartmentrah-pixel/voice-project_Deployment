/*
  007_create_triggers.sql
  No triggers exist in this application. Timestamps (created_at) are set via
  column DEFAULT GETDATE() and all derived/aggregate data (dashboard stats,
  wastage, response-times) is computed on read by server.js, not maintained
  by triggers — confirmed by inspecting the full backend source.

  This file is kept as a placeholder so the install sequence numbering stays
  stable if triggers are introduced later.
*/
