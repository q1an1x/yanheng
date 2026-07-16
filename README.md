# 言衡 Yanheng

言衡是面向 [sub2api](https://github.com/Wei-Shaw/sub2api) 管理员的 macOS 菜单栏工具。它把账号供给、上游滚动用量窗口和 token 流量放在一个原生弹层里，首先回答一个运营问题：**现在是否需要补账号？**

界面使用 [yanxu-macos-ui](https://github.com/yanxulang/yanxu-macos-ui) 描述并由 SwiftUI/AppKit 原生渲染；业务入口使用言序编写。当前发布制品支持 macOS 13 或更高版本的 Apple Silicon Mac。

## 功能

- 汇总账号的 `status`、`schedulable`、过期、限流、过载和临时不可调度状态；
- 显示可用账号数、可用率和平台分布；
- 读取每个账号的 passive usage，计算上游 5h/7d 窗口平均剩余比例；
- 按阈值给出“供给充足 / 余量偏紧 / 需要补充”的直接建议；
- 展示今日输入、输出、缓存创建、缓存读取 token，以及请求、成本、RPM、TPM；
- 列出优先处理的异常账号及原因；
- 支持手动刷新和 1–60 分钟自动刷新；
- 管理员 API Key 仅保存在 macOS Keychain。

## 使用

1. 从 [Releases](https://github.com/q1an1x/yanheng/releases) 下载 DMG 或 ZIP。
2. 将“言衡”拖入“应用程序”，首次启动时在 Finder 中右键应用并选择“打开”。
3. 点击菜单栏的天平图标，展开“连接与预警”。
4. 填写 sub2api 服务根地址，例如 `https://sub2api.example.com`，以及系统设置中的管理员 API Key。
5. 调整最少可用账号、最低可用率和 5h/7d 余量阈值，点击“保存并测试连接”。

当前制品没有使用 Apple Developer ID 公证。Release 同时提供 `SHA256SUMS`，请在可信下载来源下核对摘要。

## 指标口径

“可用账号”要求账号为 active、允许调度、未过期，且当前不在限流、过载或临时不可调度窗口。可用率以 sub2api 返回的全部账号为分母。

5h/7d 平均余量按报告对应窗口的账号等权计算：`平均(100 - utilization)`。使用 `source=passive`，日常刷新不会主动探测上游或增加上游请求压力。没有报告某个窗口的账号不进入该窗口平均值，但仍进入账号可用率。

## 安全

- HTTP 请求只向配置的服务根地址发出，并使用 `x-api-key` 管理员认证；
- API Key 通过 Keychain generic password 保存，不写入言序清单、日志或 UserDefaults；
- 应用只调用读取类管理 API，不修改 sub2api 账号和设置；
- 原生制品及依赖在 `言序.lock` 与 Bundle 清单中记录 SHA-256。

## 开发

需要 Xcode 16、Swift 6、言序 1.1.8+、言包 0.5.0+：

```sh
swift test --package-path native
yanbao audit --offline
yanbao check
yanbao build --release --bundle
VERSION=0.1.0 sh scripts/package-release.sh
```

`native/` 是言衡伴生模块源码；`packages/yanheng-native/` 是言包消费的已校验原生包。修改 Swift 后，发布脚本会在摘要未同步时失败，避免发布与锁文件不一致的 dylib。

## 许可

[MIT](LICENSE)
