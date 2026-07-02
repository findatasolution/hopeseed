-- Schema cho trang "Gánh hàng rong". Chạy trong Neon Console -> SQL Editor.
-- Đăng nhập thật (email/mật khẩu) qua Neon Auth (Stack Auth) - bật ở Neon Console -> Auth.
-- Frontend gọi thẳng Neon Data API bằng JWT của phiên đăng nhập, không qua backend nào.

CREATE TABLE IF NOT EXISTS street_vendors (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name            TEXT NOT NULL,              -- tên gánh hàng / tên người bán
  description     TEXT,                       -- bán gì, đặc điểm (tuỳ chọn)
  address         TEXT NOT NULL,              -- địa chỉ mô tả (vd: "vỉa hè trước số 12 Lê Lợi")
  maps_url        TEXT NOT NULL,              -- link Google Maps (chia sẻ địa điểm)
  lat             DOUBLE PRECISION,
  lng             DOUBLE PRECISION,
  image_url       TEXT,                       -- icon theo "Loại món" - DB tự gán (xem trigger bên dưới)
  social_url      TEXT,                       -- 1 link mạng xã hội bất kỳ (FB/IG/TikTok/YouTube...)
  contact_email   TEXT NOT NULL,              -- HIỂN THỊ CÔNG KHAI - DB tự ép theo email tài khoản đăng nhập
  contact_phone   TEXT,                       -- sđt hỗ trợ (tuỳ chọn) - HIỂN THỊ CÔNG KHAI nếu có
  status          TEXT NOT NULL DEFAULT 'pending', -- pending | approved | rejected
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  tags            TEXT[],                     -- vd: {banhmi,comtam} - điền tay trong Neon Console
  opening_hours   TEXT,                       -- vd: "06:30 - 10:30"
  category        TEXT                        -- loại món, dùng để chọn icon cố định trên giao diện
);

CREATE INDEX IF NOT EXISTS idx_street_vendors_status ON street_vendors(status);
ALTER TABLE street_vendors ENABLE ROW LEVEL SECURITY;

-- Chỉ role "authenticated" (đã đăng nhập email/mật khẩu thật) mới gửi được thông tin mới.
GRANT SELECT, INSERT ON street_vendors TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE street_vendors_id_seq TO authenticated;
-- anonymous chỉ còn quyền đọc (hiện chưa dùng tới vì trang đọc qua vendors.json tĩnh).
GRANT SELECT ON street_vendors TO anonymous;

CREATE POLICY authenticated_insert_pending ON street_vendors
  FOR INSERT TO authenticated WITH CHECK (status = 'pending');

CREATE POLICY authenticated_select_approved ON street_vendors
  FOR SELECT TO authenticated USING (status = 'approved');

CREATE POLICY anon_select_approved ON street_vendors
  FOR SELECT TO anonymous USING (status = 'approved');

-- Trigger: không tin dữ liệu client gửi cho 2 trường nhạy cảm này -
-- DB tự lấy đúng email của tài khoản đang đăng nhập (chống mạo danh),
-- và tự suy ra image_url từ "Loại món" (đồng bộ cho cả luồng ghi trực tiếp lẫn
-- luồng cũ qua GitHub Issue + scripts/sync_vendors.py).
CREATE OR REPLACE FUNCTION street_vendors_before_insert()
RETURNS trigger AS $$
DECLARE
  jwt_email text;
  slug text;
BEGIN
  BEGIN
    jwt_email := auth.jwt() ->> 'email';
  EXCEPTION WHEN OTHERS THEN
    jwt_email := NULL;
  END;
  IF jwt_email IS NOT NULL THEN
    NEW.contact_email := jwt_email;
  END IF;

  IF NEW.image_url IS NULL THEN
    slug := CASE NEW.category
      WHEN 'Bánh bò' THEN 'banhbo'
      WHEN 'Bánh chuối ép' THEN 'banhchuoiep'
      WHEN 'Bánh chuối nếp nướng' THEN 'banhchuoinepnuong'
      WHEN 'Bánh mì' THEN 'banhmi'
      WHEN 'Bánh tai yến' THEN 'banhtaiyen'
      WHEN 'Bắp luộc' THEN 'bapluoc'
      WHEN 'Cà phê' THEN 'caphe'
      WHEN 'Cà phê trứng' THEN 'caphetrung'
      WHEN 'Chè' THEN 'che'
      WHEN 'Đậu hũ / Tàu hũ' THEN 'dauhu'
      WHEN 'Kem' THEN 'kem'
      WHEN 'Nem chua / Cuốn' THEN 'nemchua'
      WHEN 'Nước mía' THEN 'nuocmia'
      WHEN 'Nước sấu' THEN 'nuocsau'
      WHEN 'Phở / Bún' THEN 'pho'
      WHEN 'Sinh tố' THEN 'sinhto'
      WHEN 'Trà tắc' THEN 'tratac'
      WHEN 'Xôi' THEN 'xoi'
      WHEN 'Xe ôm' THEN 'xeom'
      WHEN 'Trái cây' THEN 'traicay'
      ELSE NULL
    END;
    NEW.image_url := 'https://ik.imagekit.io/o2u9hny2s/hopeseed/platform_assets/'
      || COALESCE(slug, 'maincharactor') || '.png';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_street_vendors_before_insert
BEFORE INSERT ON street_vendors
FOR EACH ROW EXECUTE FUNCTION street_vendors_before_insert();

-- Duyệt bài (đổi status -> 'approved') thực hiện thủ công trong Neon Console -> Table Editor,
-- hoặc bằng SQL Editor: UPDATE street_vendors SET status = 'approved' WHERE id = <id>;


-- ===== Thả tim ủng hộ (1 lượt/tài khoản/gánh/ngày) =====
CREATE TABLE IF NOT EXISTS street_vendor_hearts (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  vendor_id   BIGINT NOT NULL REFERENCES street_vendors(id) ON DELETE CASCADE,
  user_id     TEXT NOT NULL,              -- Stack Auth user id (auth.jwt()->>'sub'), DB tự gán
  hearted_on  DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (vendor_id, user_id, hearted_on)  -- chặn thả tim trùng trong cùng 1 ngày
);
CREATE INDEX IF NOT EXISTS idx_hearts_vendor_day ON street_vendor_hearts(vendor_id, hearted_on);
ALTER TABLE street_vendor_hearts ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT ON street_vendor_hearts TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE street_vendor_hearts_id_seq TO authenticated;

CREATE POLICY authenticated_insert_heart ON street_vendor_hearts
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY authenticated_select_hearts ON street_vendor_hearts
  FOR SELECT TO authenticated USING (true);

CREATE OR REPLACE FUNCTION street_vendor_hearts_force_user()
RETURNS trigger AS $$
DECLARE
  jwt_sub text;
BEGIN
  BEGIN
    jwt_sub := auth.jwt() ->> 'sub';
  EXCEPTION WHEN OTHERS THEN
    jwt_sub := NULL;
  END;
  IF jwt_sub IS NOT NULL THEN
    NEW.user_id := jwt_sub;
  END IF;
  NEW.hearted_on := CURRENT_DATE;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_hearts_force_user
BEFORE INSERT ON street_vendor_hearts
FOR EACH ROW EXECUTE FUNCTION street_vendor_hearts_force_user();


-- ===== Xét duyệt thông tin (cộng đồng tự duyệt - đủ 3 lượt thì tự công khai) =====
CREATE TABLE IF NOT EXISTS street_vendor_approvals (
  id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  vendor_id   BIGINT NOT NULL REFERENCES street_vendors(id) ON DELETE CASCADE,
  user_id     TEXT NOT NULL,              -- Stack Auth user id, DB tự gán
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (vendor_id, user_id)             -- 1 tài khoản chỉ duyệt 1 lần / gánh (không theo ngày)
);
ALTER TABLE street_vendor_approvals ENABLE ROW LEVEL SECURITY;

GRANT SELECT, INSERT ON street_vendor_approvals TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE street_vendor_approvals_id_seq TO authenticated;

CREATE POLICY authenticated_insert_approval ON street_vendor_approvals
  FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY authenticated_select_approvals ON street_vendor_approvals
  FOR SELECT TO authenticated USING (true);

-- Cho phép tài khoản đã đăng nhập xem cả các gánh đang "pending" (để xét duyệt),
-- không chỉ "approved" như policy authenticated_select_approved ở trên.
CREATE POLICY authenticated_select_pending ON street_vendors
  FOR SELECT TO authenticated USING (status = 'pending');

CREATE OR REPLACE FUNCTION street_vendor_approvals_before_insert()
RETURNS trigger AS $$
DECLARE
  jwt_sub text;
BEGIN
  BEGIN
    jwt_sub := auth.jwt() ->> 'sub';
  EXCEPTION WHEN OTHERS THEN
    jwt_sub := NULL;
  END;
  IF jwt_sub IS NOT NULL THEN
    NEW.user_id := jwt_sub;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_approvals_before_insert
BEFORE INSERT ON street_vendor_approvals
FOR EACH ROW EXECUTE FUNCTION street_vendor_approvals_before_insert();

-- Đủ 3 lượt duyệt -> tự chuyển status sang 'approved' (chạy với quyền owner qua
-- SECURITY DEFINER nên không cần cấp UPDATE trên street_vendors cho role authenticated).
CREATE OR REPLACE FUNCTION street_vendor_approvals_after_insert()
RETURNS trigger AS $$
DECLARE
  cnt int;
BEGIN
  SELECT count(*) INTO cnt FROM street_vendor_approvals WHERE vendor_id = NEW.vendor_id;
  IF cnt >= 3 THEN
    UPDATE street_vendors SET status = 'approved' WHERE id = NEW.vendor_id AND status = 'pending';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_approvals_after_insert
AFTER INSERT ON street_vendor_approvals
FOR EACH ROW EXECUTE FUNCTION street_vendor_approvals_after_insert();

-- Sau khi tạo bảng mới, Neon Data API có thể mất 30-60s (đôi khi lâu hơn, nhiều node cache
-- độc lập) để nhận diện (schema cache). Có thể ép reload sớm hơn bằng:
--   NOTIFY pgrst, 'reload schema';
-- nhưng vẫn nên thử lại vài lần nếu gặp lỗi "Could not find the table ... in the schema cache".
