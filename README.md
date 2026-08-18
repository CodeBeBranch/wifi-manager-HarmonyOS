# Wifi Manager HarmonyOS

Wifi Manager 的原生 HarmonyOS 移动客户端。客户端复用现有 Gateway、账号、
租户、设备、Session、告警和统一错误契约，不包含独立后端或业务模型。

## 当前能力

- 登录、会话刷新和安全本地缓存
- 账号注册、验证码发送和密码找回
- 平台/租户工作区切换
- 设备列表、设备详情
- Session 列表、详情、注销和管理员撤销
- 告警 REST 查询、处理和 WebSocket 实时通知
- 设备命令提交、执行记录和有界终态轮询
- 上游 WiFi 候选配置、最新任务和有界终态轮询
- 浅色/深色简约移动端主题

契约映射、验收证据和冻结项见
[`docs/H0-contract-audit.md`](docs/H0-contract-audit.md)。

## 本地构建

1. 使用 DevEco Studio 和 HarmonyOS API 24 SDK 打开工程。
2. 使用 DevEco Studio 自带的 JBR 21。
3. 首次安装依赖后执行 ArkTS 测试和 `assembleHap`。
4. 真机安装前，在 DevEco Studio 中配置当前开发者自己的调试签名。
