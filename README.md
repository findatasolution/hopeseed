Hạ tầng quản lý:

Hạ tầng quản lý (cập nhật - không dùng Netlify/Render, chỉ dùng dịch vụ free):
- GitHub Pages: lưu trữ mã nguồn + host toàn bộ frontend tĩnh (Settings -> Pages -> branch `main` / root) — đã bật.
- Console Neon: Postgres (managed), nguồn dữ liệu duy nhất. Neon Data API (PostgREST) của project này **bắt buộc JWT**
  qua Neon Auth/Stack Auth cho mọi request kể cả role `anonymous` — chưa cấu hình publishable key nên trang KHÔNG
  gọi thẳng Neon từ trình duyệt. Thay vào đó dùng GitHub Issues làm kênh ghi (xem bên dưới).
- ImageKit: dùng làm CDN tối ưu ảnh qua URL proxy (`tr:w-...`), không upload trực tiếp từ trình duyệt (tránh phải lộ private key).
- GitHub Issues + `gh` CLI: kênh ghi dữ liệu công khai, không cần secret/JWT nào lộ ra frontend.

Trang "Gánh hàng rong" (`ganghangrong.html`) — kiến trúc:
1. `street_vendors_schema.sql` đã chạy trên Neon (bảng `street_vendors` + RLS, role `anonymous`/`authenticated`).
2. Người dùng điền form trên `ganghangrong.html` → bấm "Gửi qua GitHub" → được chuyển sang GitHub Issue Form
   (`.github/ISSUE_TEMPLATE/gop-y-gang-hang.yml`) đã điền sẵn nội dung, chỉ cần tài khoản GitHub miễn phí để xác nhận gửi.
3. `scripts/sync_vendors.py` (chạy bằng `DATABASE_URL=<connection string> python3 scripts/sync_vendors.py`):
   - đọc các issue có label `gop-y-gang-hang` chưa `synced` → insert vào Neon với `status='pending'` → comment cảm ơn + đóng issue.
   - đọc toàn bộ `street_vendors` có `status='approved'` → ghi ra `vendors.json` ở gốc repo → commit + push.
4. `ganghangrong.html` chỉ fetch tĩnh `vendors.json` để hiển thị danh sách — không gọi Neon/JWT từ trình duyệt.
5. **Duyệt bài**: vào Neon Console -> Table Editor -> bảng `street_vendors` -> đổi `status` thành `approved`.
   Lần chạy `sync_vendors.py` tiếp theo sẽ tự cập nhật `vendors.json`.
6. `vendor-config.js` chỉ còn cấu hình ImageKit endpoint (public, an toàn).

Service cũ (auth.py, main.py, database.py, models.py, schema.sql) cần backend Python (FastAPI) — chỉ chạy được nếu sau này có nơi host miễn phí khác; hiện tại không nằm trong scope free-only.

Bảng mã màu
1. headline, slogan, subtext #120747
2. logo Gradient #63c8d0 → #77bf65 ≈ Mantis
3. Màu nút HEX #4389bd ≈ Steel Blue
4. Màu nền #bde5fe 


 