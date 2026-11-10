# 排错手册

本文收集 macOS 微信多开脚本执行过程中可能遇到的报错与对应处理方式。

---

## 一、脚本执行阶段

### 1. `zsh: event not found: /bin/bash`

**原因**：直接把 `#!` 开头的脚本文本粘贴进 zsh 交互终端，`!` 被当成历史命令展开。

**处理**：

```zsh
# 方案 A：关闭交互注释展开（仅当前会话生效）
setopt interactive_comments

# 方案 B（推荐）：脚本存成文件后执行
chmod +x wechat-multi.zsh
zsh wechat-multi.zsh
```

---

### 2. `zsh: permission denied: ./wechat-multi.zsh`

**原因**：脚本文件缺少执行权限，或所在路径带 quarantine 标记。

**处理**：

```zsh
chmod +x wechat-multi.zsh
xattr -d com.apple.quarantine wechat-multi.zsh 2>/dev/null || true
```

---

### 3. `未找到原版微信 /Applications/WeChat.app`

**原因**：微信未安装，或安装在非默认路径。

**处理**：

```zsh
# 确认微信实际位置
mdfind "kMDItemCFBundleIdentifier == 'com.tencent.xinWeChat'"
```

如果路径不同，编辑脚本第一段的 `SRC_APP` 变量指向真实路径。

---

### 4. `sudo: a password is required` / 卡在输入密码

**原因**：`sudo` 需要交互输入管理员密码，而脚本被非交互方式调用。

**处理**：在真实终端里手动执行脚本，并在提示 `Password:` 时输入密码（输入过程不显示字符，属正常现象）。

---

### 5. `cp: /Applications/WeChat.app: Operation not permitted`

**原因**：终端没有「完全磁盘访问权限」或「App 管理」权限。

**处理**：

1. 打开「系统设置 → 隐私与安全性 → 完全磁盘访问权限」
2. 把「终端」（或 iTerm）加入列表并打开开关
3. 完全退出终端后重新打开，再次执行脚本

---

### 6. `PlistBuddy: Set: Entry, ":CFBundleIdentifier", Does Not Exist`

**原因**：`Info.plist` 结构异常，或被指向了错误的文件。

**处理**：

```zsh
/usr/libexec/PlistBuddy -c "Print" /Applications/WeChat.app/Contents/Info.plist | head -30
```

确认原版 `Info.plist` 中存在 `CFBundleIdentifier`。若原版本身异常，请重新下载安装微信。

---

### 7. `codesign_allocate: ... cannot allocate memory` 或签名中途失败

**原因**：磁盘空间不足，或 `/Applications` 目录权限异常。

**处理**：

```zsh
df -h /Applications
ls -ld /Applications
```

清理空间后重新执行；权限异常时执行：

```zsh
sudo chown root:wheel /Applications
sudo chmod 775 /Applications
```

---

### 8. 校验输出 `invalid signature` / `code object is not signed at all`

**原因**：`--deep` 重签名被中断，或副本继承了损坏的扩展属性。

**处理**：

```zsh
sudo rm -rf /Applications/WeChat2.app
zsh wechat-multi.zsh -f
```

若仍失败，检查是否有安全软件（如某些杀软、企业 MDM 策略）阻止修改 `/Applications`。

---

## 二、运行阶段

### 9. 打开提示「无法验证开发者」/「已损坏，应该移到废纸篓」

**处理**：

- 先在「系统设置 → 隐私与安全性」页面底部点击「仍要打开」
- 若提示「已损坏」，说明签名不完整，执行：

```zsh
sudo xattr -cr /Applications/WeChat2.app
sudo codesign --force --deep --sign - /Applications/WeChat2.app
```

---

### 10. 分身打开后闪退

**排查顺序**：

1. 确认 Bundle ID 已改成功：

   ```zsh
   /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" \
       /Applications/WeChat2.app/Contents/Info.plist
   ```

   应输出 `com.tencent.xinWeChat2`

2. 确认签名有效：

   ```zsh
   codesign -vv --deep --strict /Applications/WeChat2.app
   ```

3. 查看崩溃日志：

   ```zsh
   ls -t ~/Library/Logs/DiagnosticReports | grep -i wechat | head -3
   ```

4. 若原版微信同时运行且出现相互踢出，说明 Bundle ID 未生效，删除分身重建。

---

### 11. 分身和原版互相顶掉登录态

**原因**：两个应用的 `CFBundleIdentifier` 相同，系统认为是同一个 App。

**处理**：重新执行 `zsh wechat-multi.zsh -f`，并确认第 2 步输出的 Bundle ID 不是 `com.tencent.xinWeChat`。

---

### 12. 微信升级后分身打不开 / 版本落后

**原因**：分身是旧版本的副本，微信版本迭代后可能与服务端协议不匹配。

**处理**：

```zsh
# 先备份分身数据（重要！）
cp -R ~/Library/Containers/com.tencent.xinWeChat2 ~/Desktop/xinWeChat2_backup

# 重建分身
zsh wechat-multi.zsh -n 2 -f
```

重建后数据目录不会被自动覆盖，若新分身首次启动是空数据，把备份目录内的内容恢复到对应 Containers 目录即可。

---

### 13. 想彻底清除分身及数据

```zsh
zsh wechat-uninstall.zsh -n 2
rm -rf ~/Library/Containers/com.tencent.xinWeChat2
rm -rf ~/Library/Application\ Support/com.tencent.xinWeChat2
```

---

## 三、巨魔扩展脚本（wechat-troll-patch.zsh）

### 14. `未检测到 7z 命令`

```zsh
brew install p7zip
```

未安装 Homebrew 时先装 Homebrew：

```zsh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 15. `未找到 Payload/WeChat.app/Info.plist`

**原因**：输入的不是微信 IPA，或使用了 App Store 的加密包。

**处理**：必须使用**砸壳（decrypted）**后的 IPA。加密包内的 `Info.plist` 虽存在，但可执行文件被 FairPlay 加密，修改后无法运行。

### 16. 巨魔安装后启动闪退

常见原因：

- Bundle ID 与设备上已安装的应用重复 → 换一个 ID 重新打包
- IPA 未真正砸壳 → 重新导出砸壳包
- 系统版本超出 TrollStore 支持范围 → 无法解决

---

## 四、仍然无法解决？

提交 Issue 时请附上：

1. `sw_vers` 输出（系统版本）
2. `uname -m` 输出（芯片架构）
3. 完整终端报错文本
4. 微信版本号（微信 → 关于微信）

```zsh
sw_vers && uname -m
```
