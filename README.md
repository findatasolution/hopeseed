Hạ tầng quản lý:

Hạ tầng quản lý (cập nhật - không dùng Netlify/Render, chỉ dùng dịch vụ free):
- GitHub Pages: lưu trữ mã nguồn + host toàn bộ frontend tĩnh (Settings -> Pages -> branch `main` / root)
- Console Neon: Postgres (managed). Dùng **Neon Data API** (PostgREST) để frontend gọi thẳng REST API vào DB, không cần backend riêng
- ImageKit: dùng làm CDN tối ưu ảnh qua URL proxy (`tr:w-...`), không upload trực tiếp từ trình duyệt (tránh phải lộ private key)

Trang "Gánh hàng rong" (`ganghangrong.html`):
1. Chạy `street_vendors_schema.sql` trong Neon Console -> SQL Editor để tạo bảng + Row Level Security.
2. Bật Data API trong Neon Console -> Settings -> Data API, lấy endpoint + anon key.
3. Điền endpoint/anon key/ImageKit ID thật vào `vendor-config.js`.
4. Bật GitHub Pages cho repo, trang sẽ chạy tại `https://<user>.github.io/<repo>/ganghangrong.html`.

Service cũ (auth.py, main.py, database.py, models.py, schema.sql) cần backend Python (FastAPI) — chỉ chạy được nếu sau này có nơi host miễn phí khác; hiện tại không nằm trong scope free-only.

Bảng mã màu
1. headline, slogan, subtext #120747
2. logo Gradient #63c8d0 → #77bf65 ≈ Mantis
3. Màu nút HEX #4389bd ≈ Steel Blue
4. Màu nền #bde5fe 


 