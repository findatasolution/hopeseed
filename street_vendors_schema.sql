-- Bảng dữ liệu cho trang "Gánh hàng rong"
-- Chạy file này trong Neon Console -> SQL Editor.
-- Sau khi chạy xong, bật "Data API" cho project trong Neon Console (Settings -> Data API)
-- để frontend có thể gọi thẳng REST API vào bảng này (không cần backend riêng).

CREATE TABLE IF NOT EXISTS street_vendors (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name            TEXT NOT NULL,              -- tên gánh hàng / tên người bán
  description     TEXT,                       -- bán gì, đặc điểm
  address         TEXT NOT NULL,              -- địa chỉ mô tả (vd: "vỉa hè trước số 12 Lê Lợi")
  maps_url        TEXT NOT NULL,              -- link Google Maps (chia sẻ địa điểm)
  lat             DOUBLE PRECISION,
  lng             DOUBLE PRECISION,
  image_url       TEXT,                       -- icon theo "Loại món" (map sẵn trong sync_vendors.py)
  social_url      TEXT,                       -- 1 link mạng xã hội bất kỳ (FB/IG/TikTok/YouTube...)
  contact_email   TEXT NOT NULL,              -- email hỗ trợ - HIỂN THỊ CÔNG KHAI (KHÔNG lưu số tài khoản ngân hàng)
  contact_phone   TEXT,                       -- sđt hỗ trợ (tuỳ chọn) - HIỂN THỊ CÔNG KHAI nếu có
  status          TEXT NOT NULL DEFAULT 'pending', -- pending | approved | rejected
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  tags            TEXT[],                     -- vd: {banhmi,comtam} - điền tay trong Neon Console
  opening_hours   TEXT,                       -- vd: "06:30 - 10:30" - điền tay trong Neon Console
  category        TEXT                        -- loại món, dùng để chọn icon cố định trên giao diện
);

CREATE INDEX IF NOT EXISTS idx_street_vendors_status ON street_vendors(status);

-- Bật Row Level Security
ALTER TABLE street_vendors ENABLE ROW LEVEL SECURITY;

-- Neon Data API dùng role "anonymous" (request không kèm JWT) / "authenticated" (có JWT).
-- Cấp quyền bảng trước, RLS policy bên dưới sẽ giới hạn lại theo dòng (row).
GRANT SELECT, INSERT ON street_vendors TO anonymous;
GRANT USAGE, SELECT ON SEQUENCE street_vendors_id_seq TO anonymous;

-- Cho phép bất kỳ ai (chưa đăng nhập) GỬI thông tin mới.
-- status luôn ép về 'pending' bất kể client gửi gì, để tránh tự duyệt bài của mình.
CREATE POLICY anon_insert_pending ON street_vendors
  FOR INSERT
  TO anonymous
  WITH CHECK (status = 'pending');

-- Cho phép bất kỳ ai chỉ XEM các gánh hàng đã được duyệt (approved).
CREATE POLICY anon_select_approved ON street_vendors
  FOR SELECT
  TO anonymous
  USING (status = 'approved');

-- Không cấp quyền UPDATE/DELETE cho anonymous.
-- Duyệt bài (đổi status -> 'approved') thực hiện thủ công trong Neon Console -> Table Editor,
-- hoặc bằng SQL Editor:
--   UPDATE street_vendors SET status = 'approved' WHERE id = <id>;
