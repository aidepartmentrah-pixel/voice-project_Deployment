/*
  002_create_schema.sql
  Creates all BloodBankDB tables. Idempotent — safe to re-run against an
  existing database (every CREATE is guarded by IF NOT EXISTS), matching the
  same idempotent philosophy already used by node-backend/server.js's
  initDB() bootstrap.

  Confidence per table (see docs/DATABASE_STRUCTURE_REPORT.md for detail):
    - HospitalUsers       : CONFIRMED  — copied verbatim from server.js initDB()
    - ExternalDeliveries   : CONFIRMED  — copied verbatim from server.js initDB()
    - TransfusionRequests  : INFERRED   — reconstructed from every INSERT/UPDATE/
                             SELECT touching this table in server.js. Verify
                             against the live HCAT schema before first
                             production install.
    - BloodDeliveries      : INFERRED   — same as above, including four columns
                             (nurse_unit_*) known from server.js's own
                             ALTER TABLE ... IF NOT EXISTS migration block.
    - VoiceTranscriptions  : INFERRED, LOWEST CONFIDENCE — this table is only
                             ever INSERTed into in server.js, never SELECTed,
                             so its column list is known but nothing confirms
                             extra columns don't exist on the live table.
*/

-- ════════════════════════════════════════════════════════════════
-- HospitalUsers — CONFIRMED (verbatim from server.js initDB())
-- ════════════════════════════════════════════════════════════════
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'HospitalUsers')
BEGIN
    CREATE TABLE HospitalUsers (
        user_id       INT IDENTITY(1,1) PRIMARY KEY,
        username      NVARCHAR(50)  UNIQUE NOT NULL,
        full_name     NVARCHAR(100) NOT NULL,
        password_hash NVARCHAR(255) NOT NULL,
        role          NVARCHAR(10)  NOT NULL DEFAULT 'staff',
        active        BIT           NOT NULL DEFAULT 1,
        created_at    DATETIME      DEFAULT GETDATE()
    );
    PRINT 'Created table HospitalUsers';
END
GO

-- ════════════════════════════════════════════════════════════════
-- TransfusionRequests — INFERRED from server.js query column lists
-- ════════════════════════════════════════════════════════════════
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'TransfusionRequests')
BEGIN
    CREATE TABLE TransfusionRequests (
        request_id                 INT IDENTITY(1,1) PRIMARY KEY,
        request_date               DATE          NULL,
        request_time                NVARCHAR(10)  NULL, -- inferred type; app sends NVarChar param, verify against live column (may be TIME)
        room                       NVARCHAR(255) NULL,
        patient_name               NVARCHAR(255) NULL,
        file_number                NVARCHAR(100) NULL,
        blood_group                NVARCHAR(20)  NULL,
        rh_factor                  NVARCHAR(20)  NULL,
        diagnosis                  NVARCHAR(255) NULL,
        fpc_units                  INT           NULL,
        fpc_type                   NVARCHAR(50)  NULL,
        ffp_units                  INT           NULL,
        ffp_type                   NVARCHAR(50)  NULL,
        plt_units                  INT           NULL,
        plt_type                   NVARCHAR(50)  NULL,
        blood_unit_1               NVARCHAR(100) NULL,
        blood_unit_2               NVARCHAR(100) NULL,
        blood_unit_3               NVARCHAR(100) NULL,
        blood_unit_4               NVARCHAR(100) NULL,
        blood_unit_5               NVARCHAR(100) NULL,
        blood_unit_6               NVARCHAR(100) NULL,
        blood_unit_7               NVARCHAR(100) NULL,
        blood_unit_8               NVARCHAR(100) NULL,
        previous_transfusion       BIT           NULL,
        prev_transfusion_place     NVARCHAR(255) NULL,
        prev_transfusion_reaction  NVARCHAR(255) NULL,
        physician                  NVARCHAR(255) NULL,
        phlebotomist               NVARCHAR(255) NULL,
        life_saving                BIT           NULL,
        life_saving_physician      NVARCHAR(255) NULL,
        life_saving_time           NVARCHAR(10)  NULL,
        saved_by                   NVARCHAR(100) NULL, -- added later via server.js ALTER TABLE ... IF NOT EXISTS
        created_at                 DATETIME      DEFAULT GETDATE()
    );
    PRINT 'Created table TransfusionRequests';
END
GO

-- ════════════════════════════════════════════════════════════════
-- BloodDeliveries — INFERRED from server.js query column lists
-- ════════════════════════════════════════════════════════════════
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'BloodDeliveries')
BEGIN
    CREATE TABLE BloodDeliveries (
        delivery_id                    INT IDENTITY(1,1) PRIMARY KEY,
        patient_name                   NVARCHAR(255) NULL,
        file_number                    NVARCHAR(100) NULL,
        patient_blood_group            NVARCHAR(20)  NULL,
        patient_rh                     NVARCHAR(20)  NULL,
        room                           NVARCHAR(255) NULL,
        known_allergies                NVARCHAR(255) NULL,
        type_of_blood_requested        NVARCHAR(255) NULL,
        blood_unit_numbers             NVARCHAR(255) NULL,
        type_of_blood                   NVARCHAR(255) NULL,
        blood_unit_group               NVARCHAR(50)  NULL,
        patient_blood_group_delivery   NVARCHAR(20)  NULL,
        technician_name                NVARCHAR(255) NULL,
        orderly_name                   NVARCHAR(255) NULL,
        nurse_name                     NVARCHAR(255) NULL,
        delivery_date                  DATE          NULL,
        delivery_time                  NVARCHAR(10)  NULL,
        leakage                        NVARCHAR(50)  NULL,
        gases                          NVARCHAR(50)  NULL,
        volume                         NVARCHAR(50)  NULL,
        expiry_date                    DATE          NULL,
        temperature_c                  FLOAT         NULL,
        received_by                    NVARCHAR(255) NULL,
        nurse_unit_received_by         NVARCHAR(255) NULL, -- added via server.js ALTER TABLE ... IF NOT EXISTS
        nurse_unit_name                NVARCHAR(255) NULL, -- added via server.js ALTER TABLE ... IF NOT EXISTS
        nurse_unit_date                DATE          NULL, -- added via server.js ALTER TABLE ... IF NOT EXISTS
        nurse_unit_time                NVARCHAR(10)  NULL, -- added via server.js ALTER TABLE ... IF NOT EXISTS
        life_saving                    BIT           NULL,
        life_saving_physician          NVARCHAR(255) NULL,
        life_saving_time               NVARCHAR(10)  NULL,
        saved_by                       NVARCHAR(100) NULL, -- added via server.js ALTER TABLE ... IF NOT EXISTS
        created_at                     DATETIME      DEFAULT GETDATE()
    );
    PRINT 'Created table BloodDeliveries';
END
GO

-- ════════════════════════════════════════════════════════════════
-- VoiceTranscriptions — INFERRED, lowest confidence (write-only in app)
-- ════════════════════════════════════════════════════════════════
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'VoiceTranscriptions')
BEGIN
    CREATE TABLE VoiceTranscriptions (
        id                 INT IDENTITY(1,1) PRIMARY KEY,
        form_type          NVARCHAR(20)   NULL,
        field_name         NVARCHAR(100)  NULL,
        raw_text           NVARCHAR(MAX)  NULL,
        extracted_value    NVARCHAR(MAX)  NULL,
        language           NVARCHAR(10)   NULL,
        word_count         INT            NULL,
        extraction_method  NVARCHAR(50)   NULL,
        created_at         DATETIME       DEFAULT GETDATE()
    );
    PRINT 'Created table VoiceTranscriptions';
END
GO

-- ════════════════════════════════════════════════════════════════
-- ExternalDeliveries — CONFIRMED (verbatim from server.js initDB(),
-- including the components_json column added by its own ALTER TABLE)
-- ════════════════════════════════════════════════════════════════
IF NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'ExternalDeliveries')
BEGIN
    CREATE TABLE ExternalDeliveries (
        delivery_id        INT IDENTITY(1,1) PRIMARY KEY,
        patient_name       NVARCHAR(255) NULL,
        destination        NVARCHAR(255) NULL,
        delivery_date      DATE          NULL,
        delivery_hour      NVARCHAR(10)  NULL,
        technician_name    NVARCHAR(255) NULL,
        frbc_unit_no       NVARCHAR(100) NULL,
        frbc_blood_group   NVARCHAR(20)  NULL,
        frbc_expiry_date   DATE          NULL,
        frbc_notes         NVARCHAR(255) NULL,
        ffp_unit_no        NVARCHAR(100) NULL,
        ffp_blood_group    NVARCHAR(20)  NULL,
        ffp_expiry_date    DATE          NULL,
        ffp_notes          NVARCHAR(255) NULL,
        plt_unit_no        NVARCHAR(100) NULL,
        plt_blood_group    NVARCHAR(20)  NULL,
        plt_expiry_date    DATE          NULL,
        plt_notes          NVARCHAR(255) NULL,
        other1_component   NVARCHAR(100) NULL,
        other1_unit_no     NVARCHAR(100) NULL,
        other1_blood_group NVARCHAR(20)  NULL,
        other1_expiry_date DATE          NULL,
        other1_notes       NVARCHAR(255) NULL,
        other2_component   NVARCHAR(100) NULL,
        other2_unit_no     NVARCHAR(100) NULL,
        other2_blood_group NVARCHAR(20)  NULL,
        other2_expiry_date DATE          NULL,
        other2_notes       NVARCHAR(255) NULL,
        test_hiv           BIT           DEFAULT 0,
        test_hbsag         BIT           DEFAULT 0,
        test_hcv           BIT           DEFAULT 0,
        test_hb_core       BIT           DEFAULT 0,
        test_sts           BIT           DEFAULT 0,
        test_iat           BIT           DEFAULT 0,
        test_kell          BIT           DEFAULT 0,
        integrity          NVARCHAR(3)   NULL,
        saved_by           NVARCHAR(100) NULL,
        created_at         DATETIME      DEFAULT GETDATE(),
        components_json    NVARCHAR(MAX) NULL
    );
    PRINT 'Created table ExternalDeliveries';
END
GO
