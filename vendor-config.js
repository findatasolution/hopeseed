// Cấu hình cho trang "Gánh hàng rong".
// Không có Neon Data API/JWT ở đây nữa — việc gửi thông tin đi qua GitHub Issue Form
// (xem ganghangrong.html + .github/ISSUE_TEMPLATE/gop-y-gang-hang.yml),
// và scripts/sync_vendors.py ghi dữ liệu đã duyệt ra vendors.json tĩnh.

// Endpoint ImageKit dùng để tối ưu ảnh từ link gốc (proxy URL, không upload trực tiếp,
// không cần private key nên an toàn để public trong file này).
window.HOPESEED_IMAGEKIT_ENDPOINT = "https://ik.imagekit.io/o2u9hny2s";

// Trả về URL ảnh đã qua ImageKit (resize/optimize) từ 1 URL ảnh gốc bất kỳ.
window.hopeseedImageProxy = function (originalUrl, width) {
  if (!originalUrl) return "";
  const w = width || 480;
  return `${window.HOPESEED_IMAGEKIT_ENDPOINT}/tr:w-${w},q-80/${originalUrl}`;
};
