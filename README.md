Hạ tầng quản lý:

Hạ tầng quản lý (cập nhật - không dùng Netlify/Render, chỉ dùng dịch vụ free):
- GitHub Pages: lưu trữ mã nguồn + host toàn bộ frontend tĩnh (Settings -> Pages -> branch `main` / root) — đã bật.
- Console Neon: Postgres (managed), nguồn dữ liệu duy nhất.
- **Neon Auth (Stack Auth)**: đăng nhập thật bằng email/mật khẩu, miễn phí, không cần backend riêng. Bật ở
  Neon Console -> Auth. Frontend chỉ dùng `Stack Auth Project ID` + `Publishable Client Key` (an toàn để public,
  gọi thẳng REST API `https://api.stack-auth.com/api/v1/...`). **Không bao giờ** đưa `Secret Server Key` vào code.
- **Neon Data API** (PostgREST): sau khi đăng nhập, form "Đóng góp thông tin" và nút "thả tim" gọi POST thẳng vào
  Data API bằng JWT của phiên đăng nhập (role Postgres `authenticated`). Mọi request đều cần JWT hợp lệ — role
  `anonymous` không tự có JWT trừ khi tự dựng thêm cơ chế ẩn danh (chưa làm, xem mục "Giới hạn" bên dưới).
- ImageKit: CDN ảnh tĩnh sẵn có trong `/hopeseed/platform_assets` (icon món ăn, mascot, icon mặt trời) - không upload
  từ trình duyệt, không cần private key.
- GitHub Issues + `gh` CLI: kênh ghi dữ liệu *cũ*, vẫn giữ `scripts/sync_vendors.py` chạy nền để xuất `vendors.json`
  tĩnh cho tab "Bản đồ" đọc (xem bên dưới) - không còn dùng để nhận submission mới từ form.

Trang web hiện chỉ còn **1 trang duy nhất**: `index.html` — "Gánh hàng rong", có 3 tab (Bản đồ / Đóng góp thông tin /
Xét duyệt thông tin) trên cùng 1 trang. Kiến trúc:

1. `street_vendors_schema.sql` đã chạy trên Neon: bảng `street_vendors` (RLS, role `authenticated`/`anonymous`),
   bảng `street_vendor_hearts` (thả tim, 1 lượt/tài khoản/gánh/ngày), bảng `street_vendor_approvals` (xét duyệt
   cộng đồng), các trigger ép dữ liệu nhạy cảm theo JWT đăng nhập thay vì tin client (`contact_email`, `user_id`
   của lượt thả tim/duyệt) - chống mạo danh.
2. **Đóng góp thông tin**: người dùng đăng ký/đăng nhập email+mật khẩu thật ngay trên trang (Stack Auth REST API)
   → điền form → bấm Gửi → JS POST thẳng vào Neon Data API (`status='pending'`). Không qua GitHub nữa.
3. **Xét duyệt thông tin**: bất kỳ tài khoản đã đăng nhập nào cũng xem được danh sách gánh hàng đang `pending`
   (đọc trực tiếp Data API, không qua `vendors.json` vì cần thấy ngay) và bấm "Duyệt" nếu đã kiểm chứng thông tin
   đúng. Đủ **3 lượt duyệt** (3 tài khoản khác nhau) → trigger DB tự chuyển `status` sang `approved`, không cần
   admin can thiệp. Admin vẫn có thể tự duyệt/từ chối thủ công trong Neon Console khi cần (vd: gánh spam).
4. **Thả tim**: mỗi dòng gánh hàng có số tim hôm nay + icon mặt trời (sáng rõ khi ≥100 tim, tối/xám khi 0 tim) +
   nút tim (♥) — bấm thì POST thẳng vào `street_vendor_hearts`, cũng cần đăng nhập (dùng chung phiên).
5. `scripts/sync_vendors.py` (chạy bằng `DATABASE_URL=<connection string> python3 scripts/sync_vendors.py`):
   - đọc các GitHub issue cũ (nếu còn) có label `gop-y-gang-hang` chưa `synced` → insert Neon `status='pending'`.
   - đọc `street_vendors` có `status='approved'` (kèm số tim hôm nay từ `street_vendor_hearts`) → ghi `vendors.json`.
   - tự chạy mỗi giờ qua 1 trigger lịch (không cần GitHub Actions secret).
6. Tab "Bản đồ" fetch tĩnh `vendors.json` để hiển thị danh sách (đọc không cần đăng nhập) — phần ghi (đóng góp,
   thả tim, duyệt) và tab "Xét duyệt thông tin" gọi Data API trực tiếp, cần đăng nhập.
7. Icon "Loại món" + ảnh mặc định/mascot lấy trực tiếp từ `image_url` (DB tự gán qua trigger, xem
   `CATEGORY_ICON_SLUGS`-tương-đương trong SQL), không qua proxy/transform nào.

**Giới hạn đã biết**:
- Token ẩn danh của Stack Auth (`/auth/anonymous/sign-up`) bị Neon Data API từ chối với lỗi "jwk not found" — chưa
  rõ nguyên nhân (có thể do JWKS cache chưa hỗ trợ audience `:anon`). Vì vậy phần đọc dữ liệu công khai (tab Bản đồ)
  vẫn dùng `vendors.json` tĩnh thay vì gọi Data API trực tiếp như phần ghi.
- Bảng mới tạo trên Data API cần ~30-90s (đôi khi lâu hơn - quan sát thấy nhiều node cache độc lập, có request
  thành công xen kẽ request lỗi "Could not find the table ... in the schema cache" trong cùng vài chục giây) để
  được nhận diện đồng đều. Có thể ép reload sớm hơn bằng `NOTIFY pgrst, 'reload schema';` nhưng vẫn nên thử lại
  vài lần / chờ thêm nếu vẫn gặp lỗi này ngay sau khi tạo bảng.
- Đôi lúc trigger DB không lấy được email từ `auth.jwt()` (transient, nguyên nhân chưa xác định trong
  `pg_session_jwt`) - đã vá bằng cách client gửi kèm `contact_email` (giải mã từ JWT phía trình duyệt) làm giá trị
  dự phòng; server vẫn ưu tiên ghi đè bằng `auth.jwt()` khi đọc được, nên không thể mạo danh email người khác.

Service quyên góp bệnh viện cũ (auth.py, main.py, database.py, models.py, schema.sql, requirements.txt + các trang trong
`archive/`: index.html, hopestories.html, campaigns.html, monitor.html) **không còn nằm trên site công khai** —
đã chuyển vào `archive/` để giữ lại code, không xoá, vì cần backend Python (FastAPI) chạy ở đâu đó (không còn dùng Render)
mới hoạt động lại được. Các bảng DB liên quan (campaign_owners, hospitals, media, patient_bills, patients, raise_tickets,
regions, ticket_updates, users) vẫn còn trên Neon, đang rỗng/không dùng, giữ nguyên phòng khi cần dùng lại.

Bảng mã màu
1. headline, slogan, subtext #120747
2. logo Gradient #63c8d0 → #77bf65 ≈ Mantis
3. Màu nút HEX #4389bd ≈ Steel Blue
4. Màu nền #bde5fe 


 