#!/usr/bin/env zsh
# =============================================================================
#  WeChat Multi Instance Cleaner  /  微信分身清理工具（macOS）
# -----------------------------------------------------------------------------
#  用法：zsh wechat-uninstall.zsh [-n 序号] [-y]
#        不带 -n 时清理 /Applications 下所有 WeChat2..WeChat99 分身
# =============================================================================

set -u

VERSION="1.1.0"
APP_DIR="/Applications"
TARGET_INDEX=""

if [ -t 1 ]; then
    C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YLW=$'\033[33m'; C_RST=$'\033[0m'
else
    C_RED=""; C_GRN=""; C_YLW=""; C_RST=""
fi

info() { echo "${C_YLW}[信息]${C_RST} $*"; }
ok()   { echo "${C_GRN}[完成]${C_RST} $*"; }
err()  { echo "${C_RED}[错误]${C_RST} $*" >&2; }

usage() {
    cat <<EOF

微信分身清理工具 v${VERSION}

用法:
  zsh wechat-uninstall.zsh          删除全部分身（WeChat2.app ~ WeChat99.app）
  zsh wechat-uninstall.zsh -n 3     只删除 WeChat3.app

注意:
  原版 /Applications/WeChat.app 永远不会被删除。

EOF
}

while getopts ":n:h" opt; do
    case "$opt" in
        n) TARGET_INDEX="$OPTARG" ;;
        h) usage; exit 0 ;;
        \?) err "未知选项: -$OPTARG"; usage; exit 1 ;;
        :)  err "选项 -$OPTARG 需要一个参数"; exit 1 ;;
    esac
done

if [ "$(uname -s)" != "Darwin" ]; then
    err "本脚本仅支持 macOS"
    exit 1
fi

FOUND=0

remove_one() {
    local app_path="$1"
    [ -d "$app_path" ] || return 0
    # 安全兜底：绝不删除原版微信
    if [ "$app_path" = "${APP_DIR}/WeChat.app" ]; then
        return 0
    fi
    info "删除 ${app_path}"
    sudo rm -rf "$app_path"
    FOUND=$((FOUND + 1))
}

if [ -n "$TARGET_INDEX" ]; then
    case "$TARGET_INDEX" in
        ''|*[!0-9]*) err "分身序号必须是数字"; exit 1 ;;
    esac
    if [ "$TARGET_INDEX" -lt 2 ]; then
        err "序号必须 >= 2，原版微信不会被删除"
        exit 1
    fi
    remove_one "${APP_DIR}/WeChat${TARGET_INDEX}.app"
else
    for i in $(seq 2 99); do
        remove_one "${APP_DIR}/WeChat${i}.app"
    done
fi

echo ""
if [ "$FOUND" -eq 0 ]; then
    info "没有找到需要删除的分身应用"
else
    ok "已清理 ${FOUND} 个微信分身，原版微信保留不变"
fi
echo ""

exit 0
