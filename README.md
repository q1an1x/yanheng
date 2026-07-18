# 言衡 Yanheng

言衡是面向 [sub2api](https://github.com/Wei-Shaw/sub2api) 管理员的 macOS 菜单栏工具。它把账号供给、上游滚动用量窗口和 token 流量放在一个原生弹层里，首先回答一个运营问题：**现在是否需要补账号？**

应用代码、API 编排和统计逻辑全部使用言序编写；通用 macOS 能力由 [yanxu-macos-ui](https://github.com/yanxulang/yanxu-macos-ui) 提供。当前发布制品支持 macOS 13 或更高版本的 Apple Silicon Mac。

## 功能

- 汇总账号的 `status`、`schedulable` 与平台分布；
- 显示可用账号数、可用率和平台分布；
- 从账号 `extra` 读取 sub2api 用量窗口，兼容 Codex 规范化 5h/7d 字段与 Anthropic 被动采样；
- 按阈值给出“供给充足 / 余量偏紧 / 需要补充”的直接建议；
- 在今天、7 天和总计之间切换输入、输出、缓存读写、请求、Token 与实际消费；
- 展示模型分布、请求明细，以及启用 Ops 监控时的综合健康评分、TTFT、SLA 和 QPS/TPS；
- 支持手动刷新和 1–60 分钟自动刷新；
- “连接与预警”使用独立设置窗口，数值阈值可直接查看和调整；
- 首次手动启动显示欢迎页；启用登录启动时以 `--background` 静默运行，不打扰桌面；
- 管理员 API Key 仅保存在 macOS Keychain。

## 使用

1. 从 [Releases](https://github.com/q1an1x/yanheng/releases) 下载 DMG 或 ZIP。
2. 将“言衡”拖入“应用程序”，首次启动时在 Finder 中右键应用并选择“打开”。
3. 点击菜单栏的天平图标，在弹层底部点击“连接与预警…”打开独立设置窗口。
4. 填写 sub2api 服务根地址，例如 `https://sub2api.example.com`，以及系统设置中的管理员 API Key。
5. 调整最少可用账号、最低可用率和 5h/7d 余量阈值，依次点击“保存设置”和“测试连接”。

服务地址可以是公网、局域网或 VPN fake-IP 地址；应用清单允许常见的 `198.18.0.0/15` 特殊测试网段，实际请求仍只发送到你填写的地址。

当前制品没有使用 Apple Developer ID 公证。Release 同时提供 `SHA256SUMS`，请在可信下载来源下核对摘要。

## 指标口径

“可用账号”要求账号为 active、允许调度、未过期，且当前不在限流、过载或临时不可调度窗口。可用率以 sub2api 返回的全部账号为分母。

5h/7d 平均余量按报告对应窗口的账号等权计算：`平均(100 - utilization)`。Codex 优先读取账号列表中的 `codex_5h_used_percent` 与 `codex_7d_used_percent`；Anthropic 使用 `session_window_utilization` 与 `passive_usage_7d_utilization`。日常刷新不主动探测上游。没有报告某个窗口的账号不进入该窗口平均值，但仍进入账号可用率。

周期统计使用 `/api/v1/admin/usage/stats` 与 `/dashboard/models`。实时信息使用可选的 `/admin/ops/dashboard/overview`，并读取 sub2api 后端计算的 `health_score` 与 `ttft` 分位数；服务器未启用 Ops 监控或版本较旧时，言衡会将对应指标标记为不可用，不影响账号与用量统计。

## 安全

- HTTP 请求只向配置的服务根地址发出，可连接公网或用户局域网中的 sub2api，并使用 `x-api-key` 管理员认证；
- “打开 sub2api”使用言序 1.1.x 的进程 API 调用固定的 macOS `/usr/bin/open`，地址须为 HTTP(S) 且作为单独参数传递，不经过 shell；
- API Key 通过 Keychain generic password 保存，不写入言序清单、日志或 UserDefaults；
- 应用只调用读取类管理 API，不修改 sub2api 账号和设置；
- 原生制品及依赖在 `言序.lock` 与 Bundle 清单中记录 SHA-256。

## 开发

需要言序 1.1.17+、言包 0.5.0+：

```sh
yanbao audit --offline
yanbao check
yanxu 编 . -o build/言衡.app --release --bundle
VERSION=1.0.1 sh scripts/package-release.sh
```

言衡仓库不包含 Swift 或应用专属原生模块。HTTP 与日期时间分别由纯言序 `yanxu-request`、`yanxu-datetime` 提供；Keychain、菜单栏定时器和 SwiftUI 控件由锁定的 `yanxu-macos-ui` 通用宿主提供。

## 致谢

- [Qian](https://qian.io)
- [Yanxu Contributors](https://yanxu.dev)

## 许可

[MIT](LICENSE)
