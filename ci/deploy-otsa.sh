#!/bin/sh
# deploy-otsa.sh — cài/upgrade gói từ repo OTSA trên .36 với auto-rollback.
# Chạy TRÊN .36. Usage: sh deploy-otsa.sh [pkgname] [commit] [run]
#   pkgname mặc định opnsense; commit/run để annotate truy vết (mặc định "manual").
#
# Khác deploy.sh (scp): bản này cài QUA repo OTSA (pkg install -r OTSA),
# không scp file. Rollback vẫn dùng pkg create (snapshot bản đang cài) -> pkg add -f.

set -u
PKG="${1:-opnsense}"
COMMIT="${2:-manual}"
RUN="${3:-manual}"
REPO="OTSA"                          # tên repo trong /usr/local/etc/pkg/repos/OTSA.conf
BACKUP_DIR="/var/cache/otsa-rollback"
GUI_URL="https://127.0.0.1/"
mkdir -p "$BACKUP_DIR"

echo "==> deploy '$PKG' từ repo $REPO"

OLDVER=$(pkg query '%v' "$PKG" 2>/dev/null || true)
BACKUP=""
if [ -n "$OLDVER" ]; then
    echo "==> backup bản đang cài: $PKG-$OLDVER"
    pkg create -q -o "$BACKUP_DIR" "$PKG" || { echo "ERR: pkg create thất bại"; exit 2; }
    BACKUP=$(ls -t "$BACKUP_DIR/${PKG}-${OLDVER}".* 2>/dev/null | head -1)
    echo "    -> $BACKUP"
fi

apply() {
    configctl webgui restart >/dev/null 2>&1 || true
}

# Khôi phục trạng thái lock ban đầu (freeze). Chỉ khóa lại nếu trước đó đã khóa.
relock() {
    [ "$WASLOCKED" = "1" ] && pkg lock -yq "$PKG" 2>/dev/null || true
}

healthcheck() {
    echo "==> health check"
    opnsense-version >/dev/null 2>&1                 || { echo "   FAIL: base"; return 1; }
    php -r 'require_once("config.inc");' 2>/dev/null || { echo "   FAIL: PHP/core"; return 1; }
    code=$(curl -sk -m 10 -o /dev/null -w '%{http_code}' "$GUI_URL" 2>/dev/null)
    case "$code" in 200|302) ;; *) echo "   FAIL: GUI HTTP=$code"; return 1 ;; esac
    echo "   OK"
}

rollback() {
    echo "==> ROLLBACK"
    if [ -n "$BACKUP" ]; then
        pkg add -f "$BACKUP" && echo "   khôi phục $PKG-$OLDVER"
    else
        pkg delete -y "$PKG" && echo "   gỡ $PKG (không có bản trước)"
    fi
    apply
    relock                                  # lùi xong vẫn giữ freeze
}

# Core thường bị 'pkg lock' để freeze. Deploy là thay đổi CÓ CHỦ ĐÍCH duy nhất
# được phép -> mở khóa trước khi cài/lùi, ghi nhớ để khóa lại sau.
WASLOCKED=$(pkg query '%k' "$PKG" 2>/dev/null || echo 0)
[ "$WASLOCKED" = "1" ] && echo "==> mở khóa $PKG để deploy (sẽ khóa lại sau)"
pkg unlock -yq "$PKG" 2>/dev/null || true

echo "==> pkg update"
pkg update -f || { echo "ERR: pkg update"; exit 1; }

# -r OTSA: ép lấy từ repo OTSA (tránh nhập nhằng priority/version với stock)
# -f: force, cài lại kể cả cùng version
echo "==> pkg install -r $REPO -fy $PKG"
if ! pkg install -r "$REPO" -fy "$PKG"; then
    echo "!!! install THẤT BẠI"
    rollback
    exit 1
fi
apply

if ! healthcheck; then
    echo "!!! health check THẤT BẠI -> rollback"
    rollback
    if healthcheck; then
        echo "==> đã rollback, hệ thống OK"
    else
        echo "!!! ROLLBACK XONG VẪN LỖI — can thiệp tay (boot environment)"
    fi
    exit 1
fi

echo "==> DONE: $PKG = $(pkg query '%v' "$PKG")"
# Gắn nguồn gốc build lên gói đã cài -> 'pkg info -A opnsense' xem được tại máy
pkg annotate -qyA "$PKG" otsa_commit "$COMMIT" 2>/dev/null || true
pkg annotate -qyA "$PKG" otsa_run    "$RUN"    2>/dev/null || true
relock                                  # khóa lại core SAU annotate -> giữ freeze
[ -n "$BACKUP" ] && echo "    rollback tay: pkg add -f $BACKUP && configctl webgui restart"
exit 0