# 微信多开（macOS）

> 简介：**在 Mac 上生成一个可以独立登录第二个微信账号的 `WeChat2.app`，不需要关闭 SIP，不需要第三方工具，一条命令完成。**

<p>
  <img src="https://img.shields.io/badge/platform-macOS%2011%2B-blue" alt="platform">
  <img src="https://img.shields.io/badge/shell-zsh-green" alt="shell">
  <img src="https://img.shields.io/badge/license-MIT-lightgrey" alt="license">
  <img src="https://img.shields.io/badge/PRs-welcome-brightgreen" alt="prs">
</p>

---

## 目录

- [功能特性](#功能特性)
- [系统要求](#系统要求)
- [快速开始](#快速开始)
- [使用方法](#使用方法)
- [工作原理](#工作原理)
- [卸载分身](#卸载分身)
- [常见问题](#常见问题)
- [项目结构](#项目结构)
- [免责声明](#免责声明)
- [License](#license)

---

## 功能特性

| 功能 | 说明 |
| --- | --- |
| 🚀 一条命令 | `zsh wechat-multi.zsh` 自动完成复制、改 ID、重签名 |
| 🔢 任意多开 | `-n 3` 生成 `WeChat3.app`，最多支持到 `WeChat99` |
| 🪶 零第三方依赖 | 只用 macOS 自带 `PlistBuddy`、`codesign`、`xattr` |
| 🔒 不破坏原版 | 只操作副本，`/Applications/WeChat.app` 完全不受影响 |
| ✅ 自动校验 | 每次签名后自动执行 `codesign -vv --deep --strict` 验证 |
| 🧹 一键清理 | `wechat-uninstall.zsh` 删除全部或指定分身 |
| 📱 巨魔扩展 | 附带 `wechat-troll-patch.zsh`，可在 Mac 上制作 iPhone 用的分身 IPA |

---

## 系统要求

- macOS 11 Big Sur 及以上（Intel / Apple Silicon 均可）
- 已安装官方微信，默认路径 `/Applications/WeChat.app`
- 联网下载微信即可，无需开发者账号、无需关闭 SIP
- 需要管理员密码（脚本内部使用 `sudo`）

---

## 快速开始

### 方式一：克隆仓库

```zsh
git clone https://github.com/<你的用户名>/Double-MacWechat.git
cd Double-MacWechat
chmod +x scripts/*.zsh
zsh scripts/wechat-multi.zsh
```

### 方式二：只下脚本

```zsh
curl -O https://raw.githubusercontent.com/<你的用户名>/Double-MacWechat/main/scripts/wechat-multi.zsh
chmod +x wechat-multi.zsh
zsh wechat-multi.zsh
```

> ⚠️ **不要双击运行脚本**，也不要直接复制脚本文本粘到终端。
> 请始终用 `zsh 脚本名` 的方式执行，否则 zsh 可能报 `event not found: /bin/bash`。

运行完成后，`/Applications` 里会多出 `WeChat2.app`：

```
✅ 复制微信副本            -> /Applications/WeChat2.app
✅ Bundle ID 改为 com.tencent.xinWeChat2
✅ 清除隔离属性
✅ ad-hoc 重签名
✅ 签名校验通过
🎉 微信第 2 个分身制作完成
```

打开「访达 → 应用程序 → WeChat2.app」，登录另一个微信号即可。两个微信可以**同时在线，消息互不干扰**。

---

## 使用方法

### 制作分身

```zsh
# 生成第二个微信（默认）
zsh wechat-multi.zsh

# 生成第三个微信
zsh wechat-multi.zsh -n 3

# 生成并立即打开
zsh wechat-multi.zsh -n 2 -o

# 分身已存在时直接覆盖，不再等待
zsh wechat-multi.zsh -n 2 -f
```

| 参数 | 含义 | 默认值 |
| --- | --- | --- |
| `-n <序号>` | 分身序号，决定 `WeChat<序号>.app` 与 Bundle ID | `2` |
| `-o` | 生成完成后自动打开分身 | 关闭 |
| `-f` | 目标分身已存在时静默覆盖 | 关闭（会等 3 秒） |
| `-h` | 显示帮助 | — |
| `-v` | 显示版本号 | — |

### 卸载分身

```zsh
zsh wechat-uninstall.zsh        # 删除全部分身
zsh wechat-uninstall.zsh -n 3   # 只删除 WeChat3.app
```

> 清理脚本内置保护：**永远不会删除原版 `/Applications/WeChat.app`**。

---

## 工作原理

微信在 macOS 上是一个标准的 `.app` 包，只要满足「独立 Bundle ID + 有效签名」，系统就认为它是两个不同应用，可以同时运行、各自登录账号。

脚本执行的 5 个步骤：

| 步骤 | 命令 | 作用 |
| --- | --- | --- |
| 1 | `cp -R WeChat.app WeChat2.app` | 复制出独立的应用副本 |
| 2 | `PlistBuddy -c "Set :CFBundleIdentifier …"` | 改成唯一标识，避免与原版冲突 |
| 3 | `xattr -cr WeChat2.app` | 清除 quarantine 等扩展属性 |
| 4 | `codesign --force --deep --sign -` | ad-hoc 本地重签名，让系统认可这份包 |
| 5 | `codesign -vv --deep --strict` | 校验签名有效性 |

因为签名是 **ad-hoc（本地）签名**，没有任何证书会过期，也不需要 Apple 开发者账号。

---

## 常见问题

<details>
<summary><b>提示「无法打开，因为无法验证开发者」</b></summary>

打开「系统设置 → 隐私与安全性」，在页面下方找到被拦截的 `WeChat2`，点击「仍要打开」。
只需授权一次。
</details>

<details>
<summary><b>粘贴脚本到终端报 <code>event not found: /bin/bash</code></b></summary>

这是 zsh 把 `#!` 开头的行当成了历史命令展开。解决办法：

```zsh
setopt interactive_comments
```

或者更推荐：把脚本存成文件后执行 `zsh 脚本文件`，不要整段粘贴。
</details>

<details>
<summary><b>微信更新之后分身失效 / 版本落后</b></summary>

微信升级后原版应用被替换，分身仍是旧版本。重新执行一次即可：

```zsh
zsh wechat-multi.zsh -f
```

如果旧分身里已经登录了账号、存有聊天记录，请先备份
`~/Library/Containers/com.tencent.xinWeChat2/`，否则重建后数据会丢失。
</details>

<details>
<summary><b>分身和原版共用同一个数据目录？</b></summary>

不会。改过 Bundle ID 后，系统的沙盒目录随之分开：

```
原版：~/Library/Containers/com.tencent.xinWeChat/
分身：~/Library/Containers/com.tencent.xinWeChat2/
```

两个微信的聊天记录、登录态完全独立。
</details>

<details>
<summary><b>会被封号吗？</b></summary>

原理上是复制官方客户端并要求系统承认它是另一个 App，客户端本身未被篡改，因此风险远低于第三方重打包客户端。但**任何非官方多开都存在被风控识别的可能**，请勿把重要账号作为唯一登录方式；日常建议把主号放原版微信。

更多问题见 [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)。
</details>

---

## 项目结构

```
Double-MacWechat/
├── README.md                       # 项目说明
├── LICENSE                         # MIT 协议
├── .gitignore
├── scripts/
│   ├── wechat-multi.zsh            # 主脚本：生成微信分身
│   ├── wechat-uninstall.zsh        # 清理脚本：删除分身
│   └── wechat-troll-patch.zsh      # 扩展：为 TrollStore 制作分身 IPA
└── docs/
    └── TROUBLESHOOTING.md          # 排错手册
```

### 关于 `wechat-troll-patch.zsh`（可选扩展）

这个脚本和 Mac 多开无关，用途是**在 Mac 上修改「砸壳版」微信 IPA 的 Bundle ID 并重新打包**，供 iPhone / iPad 的 TrollStore（巨魔商店）安装，实现手机端双开。

使用门槛较高，请先确认：

1. 设备系统为 **iOS 14.0 ~ 16.6.1 或 17.0**，且已安装 TrollStore
2. 已有**砸壳解密**的微信 IPA（App Store 下载的加密包无法修改）
3. Mac 已安装 p7zip：`brew install p7zip`

```zsh
zsh scripts/wechat-troll-patch.zsh WeChat.ipa
```

风险明显高于 Mac 方案：**分身没有 iOS 系统推送**、微信更新需重新制作、存在风控封号可能，仅建议小号测试。

---

## 免责声明

本项目仅用于**个人同一设备上登录自己拥有的多个微信账号**，以学习 macOS 应用签名机制为目的。

- 请遵守《腾讯微信软件许可及服务协议》及当地法律法规
- 禁止用于账号交易、批量养号、营销刷量等行为
- 使用本脚本产生的一切后果（包括但不限于账号受限、数据丢失、系统异常）由使用者自行承担
- 本项目与腾讯公司无任何关联

---

## License

[MIT](LICENSE) © 2026 ChanHu

---

<details>
<summary>English</summary>

**WeChat Multi-Instance for macOS** — create an independent `WeChat2.app` so you can stay signed into a second WeChat account on the same Mac.

```zsh
zsh scripts/wechat-multi.zsh -n 2 -o
```

No SIP disabling, no third-party tools: the script copies the app bundle, rewrites `CFBundleIdentifier`, strips quarantine attributes, and re-signs it ad-hoc with the system `codesign`. The original `/Applications/WeChat.app` is never touched.

Requires macOS 11+ and an official WeChat installation. Use at your own risk; this project is not affiliated with Tencent.

</details>
