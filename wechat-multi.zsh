#!/usr/bin/env zsh
# =============================================================================
#  WeChat Multi Instance for macOS  /  macOS 微信多开工具
# -----------------------------------------------------------------------------
#  原理：复制 WeChat.app -> 修改 Bundle ID -> 清除隔离属性 -> ad-hoc 重签名
#  说明：全部操作在本地完成，不需要关闭 SIP，不会影响原版微信
#  用法：zsh wechat-multi.zsh [-n 序号] [-o] [-f] [-h]
# =============================================================================

set -e
set -u

VERSION="1.1.0"

# ------------------------------- 默认参数 ------------------------------------
CLONE_INDEX=2                 # 生成 WeChat2.app
OPEN_AFTER=0                  # 生成后是否自动打开
FORCE=0                       # 已存在时是否强制覆盖
SRC_APP="/Applications/WeChat.app"
APP_DIR="/Applications"

# ------------------------------- 颜色输出 ------------------------------------
if [ -t 1 ]; then
    C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YLW=$'\033[33m'
    C_BLU=$'\033[34m'; C_DIM=$'\033[2m';  C_RST=$'\033[0m'
else
    C_RED=""; C_GRN=""; C_YLW=""; C_BLU=""; C_DIM=""; C_RST=""
fi

info()  { echo "${C_BLU}[信息]${C_RST} $*"; }
ok()    { echo "${C_GRN}[完成]${C_RST} $*"; }
warn()  { echo "${C_YLW}[提示]${C_RST} $*"; }
err()   { echo "${C_RED}[错误]${C_RST} $*" >&2; }

usage() {
    cat <<EOF

${C_BLU}macOS 微信多开${C_RST}  v${VERSION}

用法:
  zsh wechat-multi.zsh            生成第二个微信（WeChat2.app）
  zsh wechat-multi.zsh -n 3       生成第三个微信（WeChat3.app）
  zsh wechat-multi.zsh -n 2 -o    生成并立即打开

选项:
  -n <序号>   分身序号，默认 2，可用 2~99
  -o          生成完成后自动打开分身
  -f          目标分身已存在时直接覆盖，不再询问
  -h          显示本帮助
  -v          显示版本号

示例:
  zsh wechat-multi.zsh -n 2 -o
  zsh wechat-multi.zsh -n 3 -f

卸载:
  zsh wechat-uninstall.zsh          删除全部分身
  zsh wechat-uninstall.zsh -n 3     只删 WeChat3.app

EOF
}

# ------------------------------- 参数解析 ------------------------------------
while getopts ":n:ofhv" opt; do
    case "$opt" in
        n) CLONE_INDEX="$OPTARG" ;;
        o) OPEN_AFTER=1 ;;
        f) FORCE=1 ;;
        h) usage; exit 0 ;;
        v) echo "wechat-multi.zsh v${VERSION}"; exit 0 ;;
        \?) err "未知选项: -$OPTARG"; usage; exit 1 ;;
        :)  err "选项 -$OPTARG 需要一个参数"; exit 1 ;;
    esac
done

# ------------------------------- 参数校验 ------------------------------------
case "$CLONE_INDEX" in
    ''|*[!0-9]*) err "分身序号必须是数字，例如 -n 2"; exit 1 ;;
esac

if [ "$CLONE_INDEX" -lt 2 ] || [ "$CLONE_INDEX" -gt 99 ]; then
    err "分身序号必须在 2~99 之间（2 表示 WeChat2.app）"
    exit 1
fi

DEST_APP="${APP_DIR}/WeChat${CLONE_INDEX}.app"
NEW_BUNDLE_ID="com.tencent.xinWeChat${CLONE_INDEX}"

# --------------------------- 环境与前置检查 ----------------------------------
if [ "$(uname -s)" != "Darwin" ]; then
    err "本脚本仅支持 macOS（当前系统: $(uname -s)）"
    exit 1
fi

if [ ! -d "$SRC_APP" ]; then
    err "未找到原版微信，请确认它安装在: $SRC_APP"
    err "如果你把微信装在了别的位置，请先自行修改脚本里的 SRC_APP 变量"
    exit 1
fi

if [ ! -f "${SRC_APP}/Contents/Info.plist" ]; then
    err "微信应用结构异常，缺少 Contents/Info.plist，请重新下载安装微信"
    exit 1
fi

SRC_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" \
    "${SRC_APP}/Contents/Info.plist" 2>/dev/null || true)

if [ -z "$SRC_BUNDLE_ID" ]; then
    err "无法读取原版微信的 Bundle ID，请检查 Info.plist 权限"
    exit 1
fi

info "原版微信 Bundle ID: ${SRC_BUNDLE_ID}"

# --------------------------- 确认 /Applications 可写 -------------------------
if [ ! -w "$APP_DIR" ]; then
    warn "$APP_DIR 不可直接写入，将通过 sudo 执行复制，过程中会要求输入密码"
fi

# --------------------------- 处理已存在的分身 ---------------------------------
if [ -d "$DEST_APP" ]; then
    if [ "$FORCE" -eq 1 ]; then
        warn "已存在 ${DEST_APP}，按 -f 参数直接覆盖"
        sudo rm -rf "$DEST_APP"
    else
        warn "已存在 ${DEST_APP}，即将删除后重新生成（3 秒后继续，Ctrl+C 可取消）"
        sleep 3
        sudo rm -rf "$DEST_APP"
    fi
fi

# --------------------------- 1. 复制应用副本 ----------------------------------
info "步骤 1/5  复制微信副本 -> ${DEST_APP}"
sudo cp -R "$SRC_APP" "$DEST_APP"
ok "副本复制完成"

# --------------------------- 2. 修改 Bundle ID --------------------------------
info "步骤 2/5  修改 Bundle ID -> ${NEW_BUNDLE_ID}"
sudo /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${NEW_BUNDLE_ID}" \
    "${DEST_APP}/Contents/Info.plist"
ACTUAL_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" \
    "${DEST_APP}/Contents/Info.plist" 2>/dev/null || true)
if [ "$ACTUAL_ID" != "$NEW_BUNDLE_ID" ]; then
    err "Bundle ID 写入失败（当前值: ${ACTUAL_ID}）"
    exit 1
fi
ok "Bundle ID 已改为 ${ACTUAL_ID}"

# --------------------------- 3. 清除扩展属性 ----------------------------------
info "步骤 3/5  清除隔离属性与扩展属性"
sudo xattr -cr "$DEST_APP"
ok "扩展属性已清除"

# --------------------------- 4. ad-hoc 重签名 ---------------------------------
info "步骤 4/5  进行 ad-hoc 重签名（--force --deep --sign -）"
sudo codesign --force --deep --sign - "$DEST_APP"
ok "重签名完成"

# --------------------------- 5. 验证签名 --------------------------------------
info "步骤 5/5  校验签名有效性"
if sudo codesign -vv --deep --strict "$DEST_APP" 2>&1 | grep -q "valid on disk"; then
    ok "签名校验通过：${DEST_APP} 可以正常运行"
else
    err "签名校验未通过，请运行以下命令查看详情："
    err "  codesign -vv --deep --strict \"${DEST_APP}\""
    exit 1
fi

# --------------------------- 权限与打开 ---------------------------------------
sudo chown -R "$(id -u):$(id -g)" "$DEST_APP" 2>/dev/null || true
sudo chmod -R u+rwX "$DEST_APP" 2>/dev/null || true

echo ""
echo "${C_GRN}==============================================${C_RST}"
echo "${C_GRN}  🎉 微信第 ${CLONE_INDEX} 个分身制作完成${C_RST}"
echo "${C_GRN}==============================================${C_RST}"
echo "  应用路径 : ${DEST_APP}"
echo "  Bundle ID: ${NEW_BUNDLE_ID}"
echo ""
echo "  👉 打开方式：访达 → 应用程序 → 双击 WeChat${CLONE_INDEX}.app"
echo "  👉 可同时登录另一个微信账号，与原版互不影响"
echo ""
echo "  ${C_DIM}提示：首次打开如提示「无法验证开发者」，"
echo "        到 系统设置 → 隐私与安全性 允许一次即可${C_RST}"
echo ""

if [ "$OPEN_AFTER" -eq 1 ]; then
    info "正在打开分身微信..."
    open "$DEST_APP"
fi

exit 0
