# HM-3 实施与验收记录

更新时间：2026-08-21

## 当前结论

HM-3“租户设备与网络运维”当前状态为：

```text
NOT_ACCEPTED / NOT_FROZEN
```

联合收口执行已完成授权范围内的实现和验证，但 HM-3 尚未通过独立 CONTROL
验收，不得标记 `DEMO_FROZEN`，不得进入 HM-4。

后端升级期间的真实联调仍冻结为 `REAL_PENDING`。Demo 数据仅用于本地展示和
测试，真实运行入口仍保留真实 Repository、Gateway、会话和统一错误契约边界。

## 已实施能力

- 租户设备列表、详情、创建、编辑、删除、恢复和重复编码 409。
- 租户 Session 列表、详情、撤销和重复撤销 409。
- 设备信号列表、信号详情和流量趋势。
- 设备命令提交、requestId、终态轮询、执行记录和命令详情。
- 上游 WiFi 候选配置、终态轮询、任务详情和密码不缓存/不展示边界。
- 租户服务目录和黑名单新增、重复 409、移除。
- 两个租户的独立设备、Session、命令、WiFi 和黑名单数据集。
- 超级管理员进入代管组织工作台、返回平台工作区和只读权限边界。
- NORMAL、EMPTY、FILTER_EMPTY、PARTIAL_FAILURE、403、409、429、503
  Demo 场景。
- Demo HTTP、WebSocket、MQTT 出站计数哨兵；真实模式保持
  `REAL_API_PENDING`。

## 本轮修复

1. 修复设备命令页真机崩溃。

   `DeviceCommandPage` 原先调用单参数 `TextEncoder.encodeInto()` 后读取
   `.length`。目标真机返回 `undefined`，触发 `TypeError` 和系统自动恢复。
   当前改用工程已有且有测试覆盖的 `utf8ByteLength()`。

2. 加固真机审计脚本。

   - 增加 `-Hm3Only` 专项入口。
   - 跟踪测试期间所有应用 PID，避免进程崩溃并自动恢复后漏报。
   - 输入框先显式聚焦，再发送文本。
   - WiFi 表单逐字段输入并逐次收起软键盘。
   - 消除“新增黑名单”和“移除”等同名节点的点击歧义。
   - 按真实状态机覆盖黑名单重复 409 后的重试、重载和移除。
   - 设备写冲突详情后先返回列表，再恢复 NORMAL 场景。

## 构建与测试证据

- ArkTS 测试源码声明 71 项。
- Hvigor `test`：`BUILD SUCCESSFUL in 11 s 611 ms`。
- Hvigor signed `assembleHap`：
  `BUILD SUCCESSFUL in 11 s 337 ms`。
- 保留现有 `nova16` 调试签名配置，`build-profile.json5` 无工作区差异。
- 签名 HAP 已通过 `hdc install -r` 覆盖安装到唯一 USB 真机
  `88X9K26526081036`，未卸载、未清数据、未修改系统设置。
- 当前 HAP SHA-256：
  `A64647FE71EEFE16A2C15D0AA412D93F29DBC903B207A941F90650C7EEC10BE9`。

该 SHA 仅表示当前暂停点产物，不是 HM-3 冻结产物。最终验收前仍需重新执行
`verify-app`、`verify-profile` 并记录最终 SHA-256。

## 真机验收进度

最近一次完整执行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\tools\hm1-device-audit.ps1 -Hm3Only
```

已连续通过 34 项检查：

- 租户管理员登录和五栏底部导航。
- Demo 状态重置。
- 设备 CRUD、恢复和重复编码 409。
- Session 详情与撤销。
- 信号列表/详情和流量趋势。
- 命令提交、终态、记录和详情。
- WiFi 提交、终态、详情和密码边界。
- 黑名单新增、重复 409 和移除。
- EMPTY、FILTER_EMPTY、403、429、503、PARTIAL_FAILURE、写冲突 409。
- NORMAL 场景恢复和 Demo 网络出站为 0。
- 超级管理员登录。
- 进入租户 01 代管工作台。
- 租户 01 数据可见、租户 02 设备不泄漏。
- 代管态黑名单保持只读。
- 返回平台工作区后恢复平台底栏。

## 已解决的第 35 项

第 35 项的根因不是视口、滚动、分页、筛选或刷新状态。平台
`DemoPlatformAdminRepository` 中 `preview-tenant-02` 的元数据原为
`north-campus / 北区校园网络`，与既有租户运维数据集不一致。

现已仅将该 Demo 平台租户元数据对齐为
`branch-office / 分部办公网络`，并更新既有租户分页/过滤 ArkTS 断言以同时验证
`tenantCode` 和 `name`。修复后的签名 HAP 覆盖安装后，`-Hm3Only` 完整旅程通过
第 35 项租户 02 代管进入和第 36 项隔离验证。

## 2026-08-21 联合收口执行证据

- 受控文件变更仅为：
  - `entry/src/main/ets/repository/PlatformAdminRepository.ets`
  - `entry/src/test/LocalUnit.test.ets`
  - 本文档。
- ArkTS 完整结果保持为：
  `Tests run: 71, Failure: 0, Error: 0, Pass: 71, Ignore: 0`。
- 首次 `assembleHap` 的 `11014003 Init keystore failed` 已确认是默认 Java 8
  环境导致；在同一 PowerShell 进程设置 DevEco SDK、Node 和 JBR 21，并将
  `JBR/bin` 前置到 `PATH` 后，`java -version` 为
  `OpenJDK Runtime Environment JBR-21.0.8`，changed-condition retry 的 signed
  `assembleHap` 成功。
- 最终签名 HAP：
  - 路径：`entry/build/default/outputs/default/entry-default-signed.hap`
  - 大小：2674201 bytes
  - SHA-256：`C8966A3D651DEB68D3E1F45BC0E93DAD332C90DD87C4EE28DEB70878AFDE8170`
- `hap-sign-tool verify-app` 通过 Signing Block v3、代码签名和 SHA-256 摘要；
  `verify-profile` 返回 `verifiedPassed=true`，Profile 类型为 `debug`，
  bundleName 为 `com.plagod.WiFiEdgeManager`。
- 验签 HAP 覆盖安装至唯一 USB 目标 `88X9K26526081036` 后，单次
  `-Hm3Only` changed-condition 重跑通过 41 项检查，包括租户 02 选择、租户
  隔离、返回平台、Demo 网络 sentinel 为 0，以及应用 PID 无 app-authored
  ERROR/FATAL 或 crash signature。
- `git diff --check` 通过；页面注册表含 39 个唯一页面，全部存在，Router 引用的
  页面均已注册。
- RepositoryFactory 仅在 Demo 模式选择 Demo Repository；非 Demo 分支保留真实
  Repository、`httpClient`、session 和 `ApiError` 架构，未以 Mock 替代真实入口。

独立 CONTROL 验收、任何 commit、push 或冻结声明均不属于本次执行。

## Git 与边界

- 分支：`master`。
- 基线 HEAD：`011b6811b120b8a5f7d0257933643f9a4c4c0e4c`。
- `origin/master` 与基线 HEAD 一致。
- HM-2、HM-3 仍为未提交工作区改动。
- 本轮未修改后端、Vue、计划原文或签名配置。
- 本轮未 commit、未 push。
