// Cấu hình kết nối Neon Data API + ImageKit cho trang "Gánh hàng rong".
// Các giá trị dưới đây an toàn để public (đã bị giới hạn quyền bởi Row Level Security
// trong street_vendors_schema.sql) — KHÔNG được dán private key/secret key vào đây.

window.HOPESEED_NEON_DATA_API = "https://YOUR-PROJECT.dataapi.neon.tech"; // Neon Console -> Settings -> Data API
window.HOPESEED_NEON_ANON_KEY = "YOUR_ANON_KEY";                          // Neon Console -> Settings -> Data API -> anon key

// Endpoint ImageKit dùng để tối ưu ảnh từ link gốc (không upload trực tiếp, không cần private key).
// Ví dụ: https://ik.imagekit.io/o2u9hny2s
window.HOPESEED_IMAGEKIT_ENDPOINT = "https://ik.imagekit.io/YOUR_IMAGEKIT_ID";

// Trả về URL ảnh đã qua ImageKit (resize/optimize) từ 1 URL ảnh gốc bất kỳ.
window.hopeseedImageProxy = function (originalUrl, width) {
  if (!originalUrl) return "";
  const w = width || 480;
  return `${window.HOPESEED_IMAGEKIT_ENDPOINT}/tr:w-${w},q-80/${originalUrl}`;
};
