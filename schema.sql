-- Quy ước chung
CREATE EXTENSION IF NOT EXISTS citext;            -- để email case-insensitive

-- Danh mục
CREATE TABLE regions (
  region_id   SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE hospitals (
  hospital_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        VARCHAR(200) NOT NULL,
  region_id   SMALLINT NOT NULL REFERENCES regions(region_id),
  address     VARCHAR(255),
  hospital_url TEXT,
  hospital_bank_account1 TEXT,
  hospital_bank1 TEXT,
  hospital_bank_account2 TEXT,
  hospital_bank2 TEXT
);

-- Bệnh nhân / người ủng hộ / người gây quỹ
CREATE TABLE patients (
  patient_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  full_name   VARCHAR(150),
  phone       VARCHAR(50) UNIQUE,
  created_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE users (
  users_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  email         TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  phone         VARCHAR(50) UNIQUE,
  created_at    TIMESTAMP NOT NULL DEFAULT NOW()
);

-- CREATE TABLE donors (
--   donor_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
--   email         TEXT UNIQUE NOT NULL,
--   password_hash TEXT NOT NULL,
--   phone         VARCHAR(50) UNIQUE,
--   created_at    TIMESTAMP NOT NULL DEFAULT NOW()
-- );

-- CREATE TABLE campaign_owners (
--   fundraiser_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
--   email         TEXT UNIQUE NOT NULL,
--   password_hash TEXT NOT NULL,
--   phone         VARCHAR(50) UNIQUE,
--   role          VARCHAR(30) DEFAULT 'fundraiser',
--   created_at    TIMESTAMP NOT NULL DEFAULT NOW()
-- );

-- Hóa đơn chi tiết tại bệnh viện (tùy chọn)
CREATE TABLE patient_bills (
  patient_bill_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  patient_id      BIGINT NOT NULL REFERENCES patients(patient_id),
  hospital_id     BIGINT NOT NULL REFERENCES hospitals(hospital_id),
  hospital_patient_code VARCHAR(100),           -- mã bệnh viện cấp cho bệnh nhân
  bed_no         VARCHAR(30),
  total_amount   NUMERIC(15,2) CHECK (total_amount >= 0),
  currency       VARCHAR(3) DEFAULT 'VND',
  issued_at      DATE,
  raw_document   JSONB                           -- lưu cấu trúc bill nếu có
);

-- Media/Document gắn với chiến dịch
CREATE TABLE media (
  media_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  kind         VARCHAR(30) NOT NULL,            -- 'image','video','doc'
  url          TEXT NOT NULL,
  title        VARCHAR(200),
  metadata     JSONB,
  created_at   TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Ticket kêu gọi quyên góp
CREATE TYPE ticket_status AS ENUM ('draft','published','funding','funded','closed','rejected');
CREATE TABLE raise_tickets (
  raise_ticket_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  patient_id      BIGINT NOT NULL REFERENCES patients(patient_id),
  fundraiser_id   BIGINT NOT NULL REFERENCES campaign_owners(fundraiser_id),
  hospital_id     BIGINT NOT NULL REFERENCES hospitals(hospital_id),
  main_type       VARCHAR(100) NOT NULL,         -- vd: 'chữa bệnh'
  sub_type        VARCHAR(100),
  unit_price      NUMERIC(15,2) CHECK (unit_price >= 0),         -- 1 unit = 100,000đ chẳng hạn
  total_price_need NUMERIC(15,2) CHECK (total_price_need >= 0),
  total_unit_need NUMERIC(15,2) GENERATED ALWAYS AS ( 
      CASE WHEN unit_price IS NOT NULL AND unit_price > 0 
           THEN total_price_need / unit_price 
           ELSE NULL END) STORED,
  finish_unit     NUMERIC(15,2) DEFAULT 0 CHECK (finish_unit >= 0),
  start_date      DATE DEFAULT CURRENT_DATE,
  description     TEXT,
  status          ticket_status NOT NULL DEFAULT 'draft',
  patient_bill_id BIGINT REFERENCES patient_bills(patient_bill_id),
  document_folder_id BIGINT REFERENCES media(media_id),           -- nếu dùng 1 record trỏ tới folder
  video_url       TEXT,
  video_thanks_url TEXT,
  created_by_id   BIGINT REFERENCES campaign_owners(fundraiser_id),   -- người tạo (có thể = fundraiser_id)
  updated_at      TIMESTAMP NOT NULL DEFAULT NOW(),
  created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_raise_ticket_status ON raise_tickets(status);
CREATE INDEX idx_raise_ticket_patient ON raise_tickets(patient_id);

-- Lịch sử cập nhật (minh bạch)
CREATE TABLE ticket_updates (
  update_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  raise_ticket_id BIGINT NOT NULL REFERENCES raise_tickets(raise_ticket_id) ON DELETE CASCADE,
  content         TEXT NOT NULL,
  created_by      BIGINT REFERENCES campaign_owners(fundraiser_id),
  created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Quyên góp
CREATE TYPE payment_status AS ENUM ('initiated','paid','failed','refunded');
CREATE TABLE donate_tickets (
  donate_ticket_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  donor_id         BIGINT NOT NULL REFERENCES donors(donor_id) ON DELETE RESTRICT,
  raise_ticket_id  BIGINT NOT NULL REFERENCES raise_tickets(raise_ticket_id) ON DELETE CASCADE,
  patient_id       BIGINT NOT NULL REFERENCES patients(patient_id),
  amount           NUMERIC(15,2) NOT NULL CHECK (amount > 0),
  currency         VARCHAR(3) NOT NULL DEFAULT 'VND',
  provider         VARCHAR(50),                   -- VNPay/Momo/Stripe...
  provider_txn_id  VARCHAR(100),                  -- để đối soát
  status           payment_status NOT NULL DEFAULT 'initiated',
  paid_at          TIMESTAMP,
  raw_response     JSONB,
  created_at       TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_donate_ticket_ticket ON donate_tickets(raise_ticket_id);
CREATE INDEX idx_donate_ticket_donor ON donate_tickets(donor_id);
CREATE INDEX idx_donate_ticket_status ON donate_tickets(status);
