#!/usr/bin/env zsh
# =============================================================================
#  WeChat IPA Patcher for TrollStore  /  巨魔商店微信分身 IPA 制作工具
# -----------------------------------------------------------------------------
#  用途：在 Mac 上修改「砸壳（decrypted）」版微信 IPA 的 Bundle ID，
#        重新打包后通过隔空投送发送到 iPhone / iPad，用 TrollStore 安装。
#
#  前置条件（缺一不可）：
#    1. iPhone / iPad 系统为 iOS 14.0 ~ 16.6.1 或 17.0，且已安装 TrollStore
#    2. 已有【砸壳解密】后的 WeChat.ipa（App Store 直接下载的加密包不可用）
#    3. Mac 已安装 p7zip:  brew install p7zip
#
#  风险提示：
#    · 修改客户端存在被微信风控、限制功能甚至封号的可能，请勿用于主力账号
#    · 修改 Bundle ID 后分身【收不到 iOS 系统推送】，后台消息会延迟
#    · 微信每次更新都需要重新导出砸壳包并重新执行本脚本
# =============================================================================

set -u

VERSION="1.1.0"
OUTPUT_NAME="WeChat_Troll_Clone.ipa"
TMP_DIR="./wechat_tmp"
NEW_BUNDLE_ID="com.tencent.xin.troll2"
ORIG_IPA=""

if [ -t 1 ]; then
    C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YLW=$'\033[33m'
    C_BLU=$'\033[34m'; C_RST=$'\033[0m'
else
    C_RED=""; C_GRN=""; C_YLW=""; C_BLU=""; C_RST=""
fi

info() { echo "${C_BLU}[信息]${C_RST} $*"; }
ok()   { echo "${C_GRN}[完成]${C_RST} $*"; }
warn() { echo "${C_YLW}[提示]${C_RST} $*"; }
err()  { echo "${C_RED}[错误]${C_RST} $*" >&2; }

usage() {
    cat <<EOF

巨魔商店微信分身 IPA 制作工具 v${VERSION}

用法:
  zsh wechat-troll-patch.zsh WeChat.ipa
  zsh wechat-troll-patch.zsh WeChat.ipa -b com.tencent.xin.troll3 -o WeChat3.ipa

选项:
  -b <BundleID>   自定义 Bundle ID，默认 com.tencent.xin.troll2
  -o <文件名>     自定义输出文件名，默认 ${OUTPUT_NAME}
  -h              显示帮助

制作完成后:
  1. 通过隔空投送 / 文件共享把输出 IPA 传到 iPhone
  2. 在 iPhone 上选择「用 TrollStore 打开」安装

EOF
}

# ------------------------------- 参数解析 ------------------------------------
POSITIONAL=()
while [ $# -gt 0 ]; do
    case "$1" in
        -b) NEW_BUNDLE_ID="$2"; shift 2 ;;
        -o) OUTPUT_NAME="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        -*) err "未知选项: $1"; usage; exit 1 ;;
        *)  POSITIONAL+=("$1"); shift ;;
    esac
done

if [ ${#POSITIONAL[@]} -eq 0 ]; then
    err "缺少输入文件"
    usage
    exit 1
fi

ORIG_IPA="${POSITIONAL[0]}"

if [ ! -f "$ORIG_IPA" ]; then
    err "文件不存在: ${ORIG_IPA}"
    exit 1
fi

if [ "$(uname -s)" != "Darwin" ]; then
    err "本脚本仅支持 macOS"
    exit 1
fi

# ------------------------------- 依赖检查 ------------------------------------
if ! command -v 7z >/dev/null 2>&1; then
    err "未检测到 7z 命令，请先安装 p7zip："
    err "  brew install p7zip"
    exit 1
fi

if ! command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
    err "系统缺少 PlistBuddy，无法修改 Info.plist"
    exit 1
fi

# ------------------------------- 解压 IPA ------------------------------------
rm -rf "$TMP_DIR"
mkdir -p "$TMP_DIR"

info "解压 IPA: ${ORIG_IPA}"
if ! 7z x "$ORIG_IPA" -o"$TMP_DIR" -y >/dev/null; then
    rm -rf "$TMP_DIR"
    err "解压失败，IPA 文件可能损坏"
    exit 1
fi

PLIST_PATH="${TMP_DIR}/Payload/WeChat.app/Info.plist"
if [ ! -f "$PLIST_PATH" ]; then
    rm -rf "$TMP_DIR"
    err "未找到 Payload/WeChat.app/Info.plist"
    err "请确认：①是微信 IPA  ②是【砸壳解密】包，App Store 加密包不可用"
    exit 1
fi

OLD_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$PLIST_PATH" 2>/dev/null || true)
info "原始 Bundle ID: ${OLD_BUNDLE_ID:-未知}"

if [ "$OLD_BUNDLE_ID" = "$NEW_BUNDLE_ID" ]; then
    warn "Bundle ID 与目标相同，可能已修改过，仍将继续打包"
fi

# ------------------------------- 修改 Bundle ID ------------------------------
info "修改 Bundle ID -> ${NEW_BUNDLE_ID}"
if ! /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${NEW_BUNDLE_ID}" "$PLIST_PATH"; then
    rm -rf "$TMP_DIR"
    err "Bundle ID 修改失败"
    exit 1
fi

# 同步修改展示名，避免桌面与原版微信同名难以区分
DEFAULT_CN_NAME="微信分身"
if /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${DEFAULT_CN_NAME}" "$PLIST_PATH" 2>/dev/null; then
    info "应用显示名已改为「${DEFAULT_CN_NAME}」"
else
    warn "显示名修改失败（不影响安装，可忽略）"
fi

# ------------------------------- 重新打包 ------------------------------------
rm -f "$OUTPUT_NAME"
info "重新打包 -> ${OUTPUT_NAME}"
cd "$TMP_DIR" || exit 1
if ! 7z a -tzip -mx=9 "../${OUTPUT_NAME}" Payload >/dev/null; then
    cd ..
    rm -rf "$TMP_DIR"
    err "打包失败"
    exit 1
fi
cd ..

rm -rf "$TMP_DIR"

echo ""
echo "${C_GRN}==============================================${C_RST}"
echo "${C_GRN}  ✅ 分身 IPA 打包完成${C_RST}"
echo "${C_GRN}==============================================${C_RST}"
echo "  输出文件 : $(pwd)/${OUTPUT_NAME}"
echo "  BundleID : ${NEW_BUNDLE_ID}"
echo ""
echo "  👉 隔空投送到 iPhone → 选择「用 TrollStore 打开」安装"
echo "  👉 设备需为 iOS 14.0~16.6.1 或 17.0 且已安装 TrollStore"
echo ""
echo "  ${C_YLW}⚠️ 分身无系统推送、存在封号风险，请勿用于主力账号${C_RST}"
echo ""

exit 0
