Hạ tầng quản lý:

Hạ tầng quản lý (cập nhật - không dùng Netlify/Render, chỉ dùng dịch vụ free):
- GitHub Pages: lưu trữ mã nguồn + host toàn bộ frontend tĩnh (Settings -> Pages -> branch `main` / root) — đã bật.
- Console Neon: Postgres (managed), nguồn dữ liệu duy nhất. Neon Data API (PostgREST) của project này **bắt buộc JWT**
  qua Neon Auth/Stack Auth cho mọi request kể cả role `anonymous` — chưa cấu hình publishable key nên trang KHÔNG
  gọi thẳng Neon từ trình duyệt. Thay vào đó dùng GitHub Issues làm kênh ghi (xem bên dưới).
- ImageKit: dùng làm CDN tối ưu ảnh qua URL proxy (`tr:w-...`), không upload trực tiếp từ trình duyệt (tránh phải lộ private key).
- GitHub Issues + `gh` CLI: kênh ghi dữ liệu công khai, không cần secret/JWT nào lộ ra frontend.

Trang web hiện chỉ còn **1 trang duy nhất**: `index.html` — "Gánh hàng rong", có 2 tab (Bản đồ / Đóng góp thông tin) trên cùng 1 trang. Kiến trúc:
1. `street_vendors_schema.sql` đã chạy trên Neon (bảng `street_vendors` + RLS, role `anonymous`/`authenticated`).
2. Người dùng điền form ở tab "Đóng góp thông tin" → bấm "Gửi qua GitHub" → được chuyển sang GitHub Issue Form
   (`.github/ISSUE_TEMPLATE/gop-y-gang-hang.yml`) đã điền sẵn nội dung, chỉ cần tài khoản GitHub miễn phí để xác nhận gửi.
3. `scripts/sync_vendors.py` (chạy bằng `DATABASE_URL=<connection string> python3 scripts/sync_vendors.py`):
   - đọc các issue có label `gop-y-gang-hang` chưa `synced` → insert vào Neon với `status='pending'` → comment cảm ơn + đóng issue.
   - đọc toàn bộ `street_vendors` có `status='approved'` → ghi ra `vendors.json` ở gốc repo → commit + push.
   - tự chạy mỗi giờ qua 1 trigger lịch (không cần GitHub Actions secret).
4. Tab "Bản đồ" chỉ fetch tĩnh `vendors.json` để hiển thị danh sách — không gọi Neon/JWT từ trình duyệt.
5. **Duyệt bài**: vào Neon Console -> Table Editor -> bảng `street_vendors` -> đổi `status` thành `approved`.
   Lần chạy `sync_vendors.py` tiếp theo (tối đa 1 tiếng) sẽ tự cập nhật `vendors.json`.
6. Icon hiển thị trên thẻ/chi tiết gánh hàng lấy trực tiếp từ `image_url` (URL ImageKit có sẵn do
   `sync_vendors.py` map từ "Loại món" - xem `CATEGORY_ICON_SLUGS`), không qua proxy/transform nào.

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


 