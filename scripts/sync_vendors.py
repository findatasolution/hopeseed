"""
Đồng bộ dữ liệu "Gánh hàng rong" mà không cần backend/server nào chạy 24/7.

Luồng:
  1. Đọc các GitHub Issue có label `gop-y-gang-hang` (do người dùng gửi qua
     .github/ISSUE_TEMPLATE/gop-y-gang-hang.yml) chưa có label `synced`.
  2. Parse nội dung issue, INSERT vào bảng street_vendors trên Neon với status='pending'.
  3. Comment cảm ơn + gắn label `synced` + đóng issue (tránh xử lý lại).
  4. Đọc toàn bộ street_vendors có status='approved' (admin tự duyệt trong Neon Console),
     ghi ra vendors.json ở gốc repo để ganghangrong.html fetch tĩnh (không cần auth/API key).
  5. Nếu vendors.json thay đổi, git commit + push.

Yêu cầu: biến môi trường DATABASE_URL (connection string Neon) và `gh` CLI đã đăng nhập.
Không hardcode bất kỳ secret nào trong file này hay trong git history.
"""
import json
import os
import re
import subprocess
import sys

REPO = "findatasolution/hopeseed"
LABEL = "gop-y-gang-hang"
SYNCED_LABEL = "synced"
VENDORS_JSON_PATH = os.path.join(os.path.dirname(__file__), "..", "vendors.json")
IMAGEKIT_ENDPOINT = "https://ik.imagekit.io/o2u9hny2s"

FIELD_LABELS = [
    ("name", "Tên gánh hàng / người bán"),
    ("description", "Mô tả - bán gì"),
    ("address", "Địa chỉ mô tả"),
    ("maps_url", "Link Google Maps"),
    ("category", "Loại món (dùng để hiện icon trên bản đồ)"),
    ("opening_hours", "Giờ mở bán (tuỳ chọn)"),
    ("facebook_url", "Link Facebook (tuỳ chọn)"),
    ("instagram_url", "Link Instagram (tuỳ chọn)"),
    ("tiktok_url", "Link TikTok (tuỳ chọn)"),
    ("contact_email", "Email hỗ trợ"),
    ("contact_phone", "Số điện thoại hỗ trợ"),
]
REQUIRED_FIELDS = {"name", "description", "address", "maps_url", "contact_email", "contact_phone"}

# Mỗi "Loại món" map sang 1 icon có thật trong ImageKit, thư mục /hopeseed/platform_assets
# (xác nhận từ Media Library ngày 2026-06-30). "Khác"/giá trị không khớp sẽ dùng DEFAULT_ICON_SLUG.
# Phải giữ đúng các nhãn (key) trùng với options trong .github/ISSUE_TEMPLATE/gop-y-gang-hang.yml
# và trong <select id="v_category"> của index.html.
CATEGORY_ICON_SLUGS = {
    "Bánh mì": "banhmi",
    "Bắp luộc": "bapluoc",
    "Cà phê": "caphe",
    "Cà phê trứng": "caphetrung",
    "Chè": "che",
    "Đậu hũ / Tàu hũ": "dauhu",
    "Kem": "kem",
    "Nem chua / Cuốn": "nemchua",
    "Nước mía": "nuocmia",
    "Nước sấu": "nuocsau",
    "Phở / Bún": "pho",
    "Sinh tố": "sinhto",
    "Trà tắc": "tratac",
    "Xôi": "xoi",
}
DEFAULT_ICON_URL = f"{IMAGEKIT_ENDPOINT}/hopeseed/platform_assets/maincharactor.png"


def category_icon_url(category: str | None) -> str | None:
    slug = CATEGORY_ICON_SLUGS.get(category or "")
    if not slug:
        return DEFAULT_ICON_URL
    return f"{IMAGEKIT_ENDPOINT}/hopeseed/platform_assets/{slug}.png"


def run_gh(args):
    result = subprocess.run(["gh", *args, "-R", REPO], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args)} failed: {result.stderr}")
    return result.stdout


def parse_issue_body(body: str) -> dict:
    sections = re.split(r"\n###\s+", "\n" + body.strip())
    label_to_value = {}
    for section in sections:
        if not section.strip():
            continue
        lines = section.split("\n", 1)
        label = lines[0].strip()
        value = lines[1].strip() if len(lines) > 1 else ""
        if value == "_No response_":
            value = ""
        label_to_value[label] = value

    data = {}
    for key, label in FIELD_LABELS:
        data[key] = label_to_value.get(label, "").strip() or None
    return data


def fetch_open_issues():
    out = run_gh(["issue", "list", "--label", LABEL, "--state", "open",
                  "--json", "number,body,labels", "--limit", "100"])
    issues = json.loads(out)
    new_issues = []
    for issue in issues:
        label_names = {l["name"] for l in issue["labels"]}
        if SYNCED_LABEL not in label_names:
            new_issues.append(issue)
    return new_issues


def insert_pending(cur, data: dict, issue_number: int) -> bool:
    missing = [k for k in REQUIRED_FIELDS if not data.get(k)]
    if missing:
        run_gh(["issue", "comment", str(issue_number),
                "--body", f"Thiếu thông tin bắt buộc: {', '.join(missing)}. "
                          f"Vui lòng mở issue mới và điền đầy đủ. Issue này sẽ được đóng."])
        run_gh(["issue", "edit", str(issue_number), "--add-label", SYNCED_LABEL])
        run_gh(["issue", "close", str(issue_number)])
        return False

    data["image_url"] = category_icon_url(data.get("category"))

    cur.execute(
        """
        INSERT INTO street_vendors
            (name, description, address, maps_url, image_url, category, opening_hours,
             facebook_url, instagram_url, tiktok_url, contact_email, contact_phone, status)
        VALUES (%(name)s, %(description)s, %(address)s, %(maps_url)s, %(image_url)s,
                %(category)s, %(opening_hours)s,
                %(facebook_url)s, %(instagram_url)s, %(tiktok_url)s, %(contact_email)s, %(contact_phone)s,
                'pending')
        """,
        data,
    )
    run_gh(["issue", "comment", str(issue_number), "--body",
            "Cảm ơn bạn! Thông tin đã được ghi nhận và đang chờ duyệt. "
            "Sau khi duyệt, gánh hàng sẽ xuất hiện trên bản đồ trong vòng vài giờ."])
    run_gh(["issue", "edit", str(issue_number), "--add-label", SYNCED_LABEL])
    run_gh(["issue", "close", str(issue_number)])
    return True


def sync_issues_to_db(conn):
    cur = conn.cursor()
    issues = fetch_open_issues()
    inserted = 0
    for issue in issues:
        data = parse_issue_body(issue["body"] or "")
        if insert_pending(cur, data, issue["number"]):
            inserted += 1
    conn.commit()
    cur.close()
    return inserted


def export_approved_to_json(conn):
    cur = conn.cursor()
    cur.execute(
        """
        SELECT name, description, address, maps_url, lat, lng, image_url,
               facebook_url, instagram_url, tiktok_url, contact_email, contact_phone, created_at,
               tags, opening_hours, category
        FROM street_vendors
        WHERE status = 'approved'
        ORDER BY created_at DESC
        """
    )
    cols = [d.name for d in cur.description]
    rows = [dict(zip(cols, row)) for row in cur.fetchall()]
    for r in rows:
        r["created_at"] = r["created_at"].isoformat()
    cur.close()

    new_content = json.dumps(rows, ensure_ascii=False, indent=2)
    old_content = None
    if os.path.exists(VENDORS_JSON_PATH):
        with open(VENDORS_JSON_PATH, encoding="utf-8") as f:
            old_content = f.read()

    if new_content != old_content:
        with open(VENDORS_JSON_PATH, "w", encoding="utf-8") as f:
            f.write(new_content)
        return True
    return False


def git_commit_and_push():
    repo_root = os.path.join(os.path.dirname(__file__), "..")
    subprocess.run(["git", "add", "vendors.json"], cwd=repo_root, check=True)
    diff = subprocess.run(["git", "diff", "--cached", "--quiet"], cwd=repo_root)
    if diff.returncode == 0:
        return False
    subprocess.run(["git", "commit", "-m", "chore: sync vendors.json from Neon"], cwd=repo_root, check=True)
    subprocess.run(["git", "push", "origin", "main"], cwd=repo_root, check=True)
    return True


def main():
    import psycopg2

    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        print("DATABASE_URL is not set", file=sys.stderr)
        sys.exit(1)

    conn = psycopg2.connect(database_url)
    try:
        inserted = sync_issues_to_db(conn)
        print(f"Synced {inserted} new issue(s) into street_vendors (pending).")

        changed = export_approved_to_json(conn)
        print(f"vendors.json {'updated' if changed else 'unchanged'}.")

        if changed and git_commit_and_push():
            print("Pushed vendors.json update.")
    finally:
        conn.close()


if __name__ == "__main__":
    main()
