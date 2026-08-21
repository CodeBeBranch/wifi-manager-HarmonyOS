# HM-2 实施审计

## 状态

- 记录日期：2026-08-19。
- HM-1：`DEMO_FROZEN`。
- HM-2：`DEMO_FROZEN`。
- 真实 Gateway、JWT、权限和租户切换继续标记为 `REAL_PENDING`。
- 本轮未读取、修改或运行后端与 Vue 工程。
- 本轮未提交、未推送，也未进入 HM-3。
- 本轮先撤销旧冻结进行独立复审，发现并修复 2 个中风险问题后重新冻结。

## 实施范围

HM-2 按冻结注册表完成 12 项平台超级管理员能力：

- `P100` 平台首页。
- `P101` 组织列表、搜索、筛选和分页。
- `P102` 组织创建、必填校验和重复标识冲突。
- `P103` 组织代管详情、资料保存、启停和返回平台。
- `P104` 代管组织成员只读列表和筛选。
- `P105` 平台账号列表。
- `P106` 账号详情、启停和提交删除审核。
- `P107` 删除审核列表。
- `P132` 删除审核详情、批准和驳回。
- `P121` 平台服务目录。
- `P109` SaaS 套餐只读列表、搜索和筛选。
- `P110` SaaS 套餐只读详情。

平台底栏保持：首页、组织、账号、服务、我的。超级管理员进入组织代管后使用
`PLATFORM_TENANT`，返回平台时清理代管页面栈和缓存。Demo 代管上下文只在当前
进程有效，冷启动恢复登录态但归一化到 `PLATFORM`；真实上下文恢复继续以后端
JWT 和上下文契约为准。

## 实现边界

- 新增独立的 HM-2 model、Demo Repository、页面和工作区 transition。
- Demo Repository 延迟创建，Demo 模式不会实例化 Real Repository。
- Demo 场景覆盖正常、空数据、筛选为空、延迟、局部失败、403、409、429 和 503。
- 延迟场景使用 2500 ms，仅在用户主动选择本地 Demo 延迟场景时生效。
- 账号删除审批的批准和驳回均为本地 Demo 状态转换；批准后账号进入
  `DELETED`，重置 Demo 后可独立验证驳回路径。
- SaaS 套餐在 HM-2 中保持只读；创建、编辑和发布不提供入口。
- 成员邀请、移除、角色调整和 Owner 转让不在 HM-2 范围。
- Demo HTTP、WebSocket 和 MQTT 哨兵保持为零；Mock 不替代真实后端验收。

## 本地验证

- ArkTS：`Tests run: 65, Failure: 0, Error: 0, Pass: 65, Ignore: 0`。
- Hvigor `test`：`BUILD SUCCESSFUL`。
- Hvigor `assembleHap`：`BUILD SUCCESSFUL`。
- `hap-sign-tool verify-app`：Signing Block v3、代码签名和 SHA-256 摘要通过。
- `hap-sign-tool verify-profile`：`verifiedPassed=true`，Profile 类型为 `debug`，
  bundleName 为 `com.plagod.WiFiEdgeManager`。
- 最终签名 HAP：
  - 路径：`entry/build/default/outputs/default/entry-default-signed.hap`
  - 大小：2347001 bytes
  - SHA-256：`201E86241306BAAA7698C4403A2C9227668FA3F91B6D63922F20814D7738F238`
- `git diff --check` 和 `tools/hm1-device-audit.ps1` PowerShell 语法检查通过；
  仅保留工作区已有的 LF/CRLF 提示。
- 构建仍报告既有异常处理建议和 `@ohos.router` 弃用提示，未产生编译错误。

## 真机验证

- 唯一 USB 目标：`88X9K26526081036`。
- 使用 `hdc install -r` 覆盖安装最终签名 HAP 成功，没有删除签名配置。
- `tools/hm1-device-audit.ps1` 最终单轮完成 64 项检查并输出
  `HM-2 DEVICE AUDIT PASSED: 64 checks`。
- 真机闭环覆盖：
  - 超管登录及“账号 -> 服务 -> 账号”连续切换。
  - 12 项 HM-2 页面能力及组织分页、筛选、创建和 409 冲突。
  - 进入 `PLATFORM_TENANT`、成员只读、返回平台、重新代管和强停恢复。
  - 账号启停、删除申请、批准删除、重置后驳回；批准和驳回后返回待审核列表，
    已处理记录均立即消失。
  - SaaS 搜索、状态筛选、详情和无写入口。
  - 空数据、筛选为空、延迟、局部失败、403、429、503 和恢复正常。
  - 超管、租管和成员三角色底栏、强停会话恢复、退出登录。
  - 浅色 -> 深色 -> 浅色：
    `#FFF7F8FA -> #FF0F1415 -> #FFF7F8FA`。
  - 三类 Demo 出站 HTTP、WebSocket、MQTT 请求计数均为零。
- 最终应用进程 PID 为 `56473`。只读 ERROR/FATAL 查询观察到 26 行系统框架日志，
  未发现 `wifi-manager/testTag` 应用错误或 crash 特征。

## 独立复审

- 本轮复审发现两个中风险阻断：
  1. 账号详情启停或提交删除申请后，账号根列表驻留旧状态；
  2. Preferences `put` 已改变内存、`flush` 失败时，HM-2 Repository 缺少旧快照补偿。
- 账号列表改为由 MainPage `onPageShow()` 读取 HM-2 单调变更版本，并用版本键重建
  账号内容；新增“详情返回后显示删除待审核”的真机门。
- HM-2 持久化写失败时补偿写入前快照；新增“写入后 flush 失败”的单元测试。
- 修复后 ArkTS `65/65`、签名 HAP 校验和完整真机 `64/64` 均通过，未发现新的高、
  中严重度问题，恢复 HM-2 `DEMO_FROZEN`。

## 真机安全边界

- 未刷机、未解锁 bootloader、未恢复出厂、未修改系统分区。
- 未卸载应用、未清除应用数据、未修改系统息屏或其他系统设置。
- 只对明确的 USB serial 覆盖安装本应用签名 HAP、启动或强停本应用，并读取
  本应用 UI 树和进程日志。
- 测试期间两次遇到锁屏或 USB Offline，均停止操作并等待用户手动恢复。

## 验收限制

- 后端升级期间没有执行真实 Gateway 联调。
- 新旧 JWT、Cookie/Token、真实权限、真实租户隔离和状态转换仍为
  `REAL_PENDING`，本地 Demo 结果不替代后端验收。
- HM-2 冻结只解锁后续 HarmonyOS Demo 阶段，不证明后端、Vue、固件或跨端阶段。
- 当前工作区保留全部 HM-2 未提交修改；等待明确授权后再执行 Git 收口。
