# HM-4 实施与验证记录

更新时间：2026-08-21

## 执行边界

- taskId：`HM-4-IMPLEMENT`
- taskState：`READY_RESUME_AFTER_RULE_REFRESH_DIAGNOSIS`
- 分支：`master`
- HEAD / local origin/master：
  `4c06d5bbb6fcbc5900d37d51f713160f993fe071`
- authority 8/8 SHA-256 与 14 号任务卡
  `A23D7E25B70A8EB8852BAB455CA4F2313CC4CAA01C9035AAF36F40B5948EABD7`
  均匹配。
- 续执行前合并 tracked unstaged 和 untracked 的精确路径集合为 17 项，
  staged path set 为空；17 项恢复哈希均与任务卡匹配。

## 本次修正

规则编辑器保存成功后会通过 `router.back()` 返回既有
`TenantRuleListPage` 实例。该页原本仅在 `aboutToAppear` 加载，保留了旧的
规则数组。

- `TenantRuleListPage` 改为在 `onPageShow` 刷新。
- 刷新使用请求版本号和 loading guard，避免并发请求覆盖较新的列表。
- `hm1-device-audit.ps1 -Hm4Only` 在保存后用 UI `pagePath` 区分规则列表、
  编辑器错误和非预期导航；仅确认回到规则列表后等待 `HM4 Audit Rule`。
- 真机服务目录导航使用可见服务项、滚动定位和 `pagePath` 返回，避免滚动后的
  页面标题不可见导致多次返回。

## 测试、构建与验签

- 保留前序完整 Hvigor test 通过证据：75 个 `it()` 声明。本次符合恢复边界，
  未重复运行 ArkTS/Hvigor test。
- 同一 PowerShell 进程：
  - JBR：OpenJDK 21.0.8
  - Node：v18.20.1
  - DevEco SDK：HarmonyOS 6.1.1 / API 24
- signed `assembleHap`：`BUILD SUCCESSFUL in 30 s 140 ms`。
- `verify-app` 通过 Signing Block v3、代码签名、证书链和 SHA-256 摘要。
- `verify-profile`：`verifiedPassed=true`，类型 `debug`。
- bundleName：`com.plagod.WiFiEdgeManager`。
- 最终 HAP：
  - 路径：`entry/build/default/outputs/default/entry-default-signed.hap`
  - 大小：2860372 bytes
  - SHA-256：
    `98703F945CA14F35740F87406E31E3F73137B8F12699452434CF7C38B94FC6DF`

## 真机证据

已确认唯一 USB 设备 `88X9K26526081036`，已使用已验签 HAP 执行
`hdc install -r`，未卸载或清除应用数据。

`tools/hm1-device-audit.ps1 -Hm4Only` 单次完整运行通过 32 项：

- P208 告警列表与确定性 Demo event source online。
- P209 `ALERT_HANDLE` 确认处理；旧事件不会覆盖已处理的新状态。
- P210 告警规则列表，P231 tenant-admin 创建 `HM4 Audit Rule`。
- P212/P232 只读安全审计列表和详情。
- P245 告警分析。
- scenario reset 移除 HM-4 新建规则并恢复固定规则。
- platform delegate 对 rules、audits、analytics 只读。
- 两个受管租户的告警 MAC 数据隔离。
- Demo 网络哨兵保持 0，未发生 HTTP/WebSocket/MQTT 出站。
- 应用 PID `30989` 无 app-authored ERROR/FATAL 或 crash signature。

## 静态与 Git 审查

- `git diff --check` 通过。
- staged diff 为空。
- 七个页面均精确注册一次且对应文件存在：
  P208、P209、P210、P212、P231、P232、P245。
- Alert、规则、审计和服务入口均存在 Router 引用。
- `DemoAlertEventSource` 不引用 `AlertSocketClient`。
- `RepositoryFactory` 仅由 `runtimeModeStore.isDemo()` 选择 Demo HM-4
  adapter；Real adapter 保留 `REAL_API_PENDING`，未回退到 Demo。

## 哈希

恢复边界中未变化的 15 项文件哈希保持任务卡值。续执行新增修正的原始字节
SHA-256：

- `entry/src/main/ets/pages/TenantRuleListPage.ets`
  - pre-change：`C0508DEFED2850116D817371023670A8837C3F0BFB306425893D4CAB60C5FC16`
  - post-change：`6D32A91E8DAC8CC905A255AA809DCE70D47797AC5E0DFFE5B7F4B847AD0AA87F`
- `tools/hm1-device-audit.ps1`
  - pre-change：`B2B94BE0F9BD8403AA01D8CF8400D484A02D0D55B9ADB603369511A7043415B3`
  - post-change：`6F8342C48D158AB73B23C8F684C4ED721B8FF2220E2DC9064A96E33F0954AA1D`

独立 CONTROL 验收、任何暂存、commit、push、冻结声明和 HM-5 均不属于本次任务。

## 2026-08-21 PARTIAL_FAILURE 源码修正

- 定向测试已确认 `PARTIAL_FAILURE` 原先不会使 `analytics()` 失败，导致
  `coversHm4ScenarioMatrixAndDeterministicReset` 得到状态 `0` 而非 `502`。
- `DemoHm4SecurityRepository.analytics()` 现在仅对 `PARTIAL_FAILURE` 抛出
  `ApiError`：HTTP/code `502`，`errorKey=PARTIAL_FAILURE`。该分支位于
  analytics 内部，没有加入全局 guard；alerts、rules 和 audits 在该场景保持可读。
- focused ArkTS 测试同步断言 `502/PARTIAL_FAILURE`、三类局部数据可读以及
  deterministic reset；完整 Hvigor 结果为：
  `Tests run: 79, Failure: 0, Error: 0, Pass: 79, Ignore: 0`。
- 同一 JBR 21.0.8、Node v18.20.1、HarmonyOS 6.1.1/API 24 环境下，
  signed `assembleHap` 通过。新 HAP：
  - 路径：`entry/build/default/outputs/default/entry-default-signed.hap`
  - 大小：2860187 bytes
  - SHA-256：`B50A526F0C800EE2707B271B0BFE8A009E28B08E608AFDFD405654AA406A1CCC`
- `verify-app` 已验证 Signing Block v3、代码签名和 SHA-256 摘要；
  `verify-profile` 返回 `verifiedPassed=true`，类型为 `debug`，
  bundleName 为 `com.plagod.WiFiEdgeManager`。
- 唯一 USB 目标 `88X9K26526081036` 已完成新 HAP 的 `hdc install -r`。
  随后的单次 `-Hm4Only` 审计仅通过设备唯一性检查后停止：设备屏幕锁定，
  `aa start` 返回 `10106102`，开发者模式下无法自动解锁。未清数据、未修改
  系统设置，未进行同条件重试；需要用户解锁设备后由受控续执行重新跑完整旅程。
