# Wifi Manager HarmonyOS

Wifi Manager 的原生 HarmonyOS 移动客户端。客户端复用现有 Gateway、账号、
租户、设备、Session、告警和统一错误契约，不包含独立后端或业务模型。

## 当前能力

- 登录、会话刷新和安全本地缓存
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

仓库中的 `build-profile.json5` 不发布本机证书路径、Profile、密钥库或口令。
本机签名只能保存在开发者自己的工作文件中，禁止提交到远端。

## 联调边界

Gateway 地址和 WebSocket Origin 是隐藏部署配置，不提供普通用户输入。部署环境
变化时应修改客户端运行配置并同步服务端白名单。权限、租户隔离、幂等和状态
转换始终以后端响应为准。

后端升级期间，真实登录、命令入队、MQTT/ESP32 回执和跨租户行为验收保持冻结；
测试目录中的 Mock 只验证客户端适配，不替代真实联调。
