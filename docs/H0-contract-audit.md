# Wifi Manager HarmonyOS H0 审计与首闭环验收记录

日期：2026-08-17

## 1. 本轮边界

HarmonyOS 客户端复用现有 Wifi Manager Gateway、认证、租户和设备契约，
未新增后端、数据库或业务模型，未修改 Vue 和后端源码。本轮实现范围固定为：

```text
冷启动会话门禁
  -> 登录
  -> 租户工作区
  -> 设备分页列表
  -> 只读设备详情
```

Session 页面、告警、WebSocket、设备命令和平台租户选择器不在首闭环内。
本轮不 commit、不 push。

## 2. 仓库状态

- HarmonyOS：`D:\HarmonyOS\WiFiEdgeManager`。
- Git 已初始化，分支为 `master`，尚无首个提交。
- 工程文件当前均为未跟踪文件，不存在可作为 Qoder 基线的已提交 diff。
- Vue 工作区保留原有 9 个修改文件，本轮未写入。
- 后端工作区保留原有 `AuthController.java` 修改，本轮未写入。
- `origin` 已配置为
  `https://github.com/PL-Basic/wifi-manager-HarmonyOS.git`，未执行 fetch、
  commit 或 push。

## 3. 真实契约映射

### 登录

- HarmonyOS：`pages/LoginPage`。
- Vue：`src/views/LoginView.vue`、`src/api/auth.js`。
- 后端：`POST /auth/login`。
- 请求：`loginType`、`account`、`password`。
- 响应：`AuthResultDTO`；`TENANT_MEMBERSHIP_PENDING` 且无 Token 时保持受限，
  不进入工作区。

### 工作区

- HarmonyOS：`pages/WorkspacePage`。
- Vue：应用壳、租户上下文门禁和 `OverviewView`。
- 当前租户只读取 `AuthResultDTO.context`，不自行发送租户 Header。
- role `1` 且上下文为 `TENANT` 是首闭环主路径。
- role `0` 只有进入 `PLATFORM_TENANT` 后才能进入设备列表；纯 `PLATFORM`
  状态在页面阻断。
- role `2` 在页面阻断管理员设备入口，后端 403 仍是最终判定。

### 设备

- HarmonyOS：`pages/DeviceListPage`、`pages/DeviceDetail`。
- Vue：`DevicesView.vue`、`DeviceDetailView.vue`、`src/api/devices.js`。
- API：
  - `GET /admin/devices?current={n}&size={n}&keyword={value}`
  - `GET /admin/devices/{nodeId}`
- 模型直接对应 `DevicePageResult` 和 `DeviceNodeVO`。
- 已删除页面 Mock 与本地“断开连接/重新上线”伪操作，详情保持只读。

## 4. HTTP 与会话实现

- Gateway 是客户端唯一后端入口，不是用户账号字段。普通登录页和工作区均不
  展示或修改地址；HTTP 客户端只读取 `RuntimeConfig.ets` 的部署配置。
- 原登录页遗留的 Gateway Preferences 覆盖已停用，避免应用升级后旧地址覆盖
  新云环境。部署到云服务时只修改部署配置并重新构建，不向普通用户暴露服务拓扑。
- 每次请求生成 `X-Request-Id`，安装实例持久化
  `X-Client-Instance-Id`。
- 受保护请求只发送 `Authorization: Bearer {token}`。
- Refresh Cookie 只发送到 `/auth/refresh` 和 `/auth/logout`。
- 不发送 `X-Tenant-*`、`X-User-*`、`X-Context-Type` 或内部 Token。
- Access JWT 与 `wifi_refresh` 组成的会话 JSON 使用 HUKS
  AES-256-GCM 加密后存入 Preferences；页面只读取脱敏 `SessionSnapshot`。
- 应用备份恢复已关闭，HUKS 会话密文不会进入设备备份或跨设备迁移。
- 冷启动使用 Refresh Cookie 恢复会话。
- 受保护请求遇到有效 401 时只刷新一次并重放一次；并发请求检测旧 Token，
  避免重复刷新。
- Refresh 成功必须同时返回旋转后的 `wifi_refresh`；缺失 Cookie 或 Access Token
  按 `DEPENDENCY_PROTOCOL_INVALID` 处理，不继续使用已被服务端轮换的旧 Cookie。
- 刷新结果只允许覆盖发起刷新时的同一份会话；退出会先清本地状态，迟到的刷新
  结果不能恢复已退出会话。重放请求再次返回 401 时清除本地会话。
- Refresh 401 清空本地会话；Refresh 403 且
  `errorKey=REFRESH_STEP_UP_REQUIRED` 保留加密 Cookie并进入复核状态。
- 退出无论服务端是否可达都会清空本地会话并返回登录页。

## 5. 错误契约

客户端统一解析：

```json
{
  "code": 200,
  "message": "操作成功",
  "data": {},
  "errorKey": null,
  "requestId": null
}
```

- HTTP 2xx 但业务 `code != 200` 仍按失败处理。
- JSON 合法但缺少 `code/message/data`，或字段类型不符合 `ApiResponse` 时，
  统一归一为 `502 / DEPENDENCY_PROTOCOL_INVALID`。
- 错误保留有效状态、`errorKey`、`requestId`、`Retry-After` 和可重试标记。
- `X-Request-Id` 响应头优先于 envelope `requestId`。
- 非 JSON 响应归一为 `502 / DEPENDENCY_PROTOCOL_INVALID`。
- UI 不显示 Token、Cookie、完整 Header、堆栈或不安全响应正文。

## 6. 构建与测试证据

构建环境：

- SDK：`D:\devEcoStudio\DevEcoStudio\sdk`
- Node：`D:\devEcoStudio\DevEcoStudio\tools\node`
- Hvigor：
  `D:\devEcoStudio\DevEcoStudio\tools\hvigor\bin\hvigorw.bat`

完整 debug HAP 构建：

```powershell
$env:DEVECO_SDK_HOME='D:\devEcoStudio\DevEcoStudio\sdk'
$env:NODE_HOME='D:\devEcoStudio\DevEcoStudio\tools\node'
$env:JAVA_HOME='D:\devEcoStudio\DevEcoStudio\jbr'
$env:PATH="$env:JAVA_HOME\bin;$env:PATH"
& 'D:\devEcoStudio\DevEcoStudio\tools\hvigor\bin\hvigorw.bat' `
  --mode module -p product=default -p module=entry@default `
  -p buildMode=debug assembleHap --no-daemon
```

未配置 `DEVECO_SDK_HOME` 时 Hvigor 会报 `00303217`；使用系统 PATH 中
JDK 8 进行签名时会报 `11014003 / parseAlgParameters failed`。将 `java`
固定为 DevEco Studio 自带 JBR 21 后，签名构建结果为
`BUILD SUCCESSFUL in 4 s 186 ms`。

产物：
`entry\build\default\outputs\default\entry-default-signed.hap`。

HAP SHA-256：
`F57BD2DB4234FF7F2F6E4077EEDF12963027FDCA995930729A43C4D0B25CF53A`。

`hap-sign-tool verify-app` 已确认 HAP Signing Block、代码签名摘要和证书链
均验证成功；内嵌 Profile 类型为 `debug`，bundleName、appIdentifier 和
授权设备均与目标真机匹配。

本地单元测试使用同一参数执行 Hvigor `test`，覆盖成功 envelope、
响应头 requestId 优先级、429/Retry-After、Refresh Cookie、业务 401、
非 JSON 响应、JSON 合法但结构无效的 envelope、数组形式响应头、Gateway
规范化、主题偏好非法值回退，以及登录、设备分页和设备详情三组真实 DTO
形状的 Mock envelope。
Mock 仅位于 `entry/src/test`，未进入生产 Repository、页面或运行配置。

2026-08-17 18:24 复验：测试源共 12 项，Hvigor
`UnitTestArkTS`、`GenerateUnitTestResult` 和 `entry:test` 全部完成，
`BUILD SUCCESSFUL in 14 s 429 ms`。

## 7. 视觉与主题

- 移除原生星空背景，不在移动工具中复制 Vue 的动态展示层。
- 采用 Flat Design / Minimalism：纯色背景、单一青绿色主强调、清晰边框、
  无渐变、无装饰动画和最多 8vp 圆角。
- 提供浅色/深色分段控件，登录页和工作区均可切换；主题通过 Preferences
  持久化，并使用 HarmonyOS light/dark 资源统一更新页面和系统窗口配色。
- 浅色为默认模式；非法或旧主题值回退到浅色。关键操作与主题选项的触控高度
  不低于 44vp，正文和弱化文字在两种模式下保持明确对比。

## 8. 签名安全

仓库发布版 `build-profile.json5` 不包含本机签名路径、证书或口令，也不绑定
某一台开发机的签名配置。本机工作文件继续保留 `nova16` 调试签名，并由
`default` 产品显式绑定；该本地差异受 Git `skip-worktree` 保护，不进入提交。

- 当前电脑后续真机构建继续使用本地 `nova16`，不得删除该本地签名配置。
- 新环境克隆仓库后必须在 DevEco Studio 中配置自己的调试签名，不能复用其他
  开发者的证书、Profile、路径或口令。
- 签名构建必须使用 DevEco Studio 自带 JBR 21，不能回退到当前系统 JDK 8。
- `.gitignore` 拒绝常见证书、Profile、私钥和密钥库文件；提交前仍需执行
  敏感信息扫描，不能只依赖扩展名。

真机安全边界固定为：仅允许覆盖安装 signed HAP、启动本应用和按本应用 PID
读取有限日志；禁止卸载、清应用数据、重启设备、修改系统设置或删除手机文件。

## 9. 验收门

已完成源码实现、ArkTS 编译、signed HAP 打包、离线验签和本地逻辑测试。
Hvigor `test` 复验通过当前 15 项测试。

HDC 只发现一台 HarmonyOS API 24 目标真机。使用 `hdc install -r` 覆盖安装
当前 signed HAP 成功，安装后 bundle 仍为 `com.plagod.WiFiEdgeManager`，
证书指纹与本次签名证书一致。未卸载应用、未清数据，也未修改设备设置。

首次启动 `EntryAbility` 时设备处于锁屏状态，系统返回 `10106102`。用户手动
解锁后再次启动成功；未通过 HDC 解锁或修改开发者设置。按本应用 PID 读取的
有限日志确认 `Ability onCreate`、`onWindowStageCreate`、`onForeground` 和
页面内容加载成功，且没有 `wifi-manager` 本地初始化错误。当前页面进入登录页。

Preferences、运行配置和空会话初始化已经通过真机启动冒烟。由于设备上当前
没有可恢复的 Refresh Session，本次启动没有触发 HUKS 会话加解密，不能据此
宣告 HUKS 真机闭环通过。

当前 Gateway `8080`、Nacos `8848` 和业务服务 `8381-8386` 均未监听，仓库及
Vue 测试中也未发现可用于真实登录的管理员凭据。因此以下运行证据尚未完成：

1. 真实 role `1` 租户管理员登录成功。
2. Refresh Cookie 在 HUKS 中的真机加解密和冷启动恢复。
3. 当前租户设备分页与详情的真实网络返回。
4. 401 刷新重放、role `2` 的 403、404、429 和 503 的端到端界面状态。

用户已确认真实后端正在升级，本轮冻结上述端到端运行门。冻结期间只允许在
`entry/src/test` 使用 Mock envelope 验证客户端解析、字段映射和页面依赖的
数据形状；Mock 不进入生产源码，也不替代真实权限、租户隔离、状态转换或
Gateway Cookie 行为的验收证据。

恢复条件：后端升级完成，Gateway 和依赖服务达到可用状态，并具备一个可登录的
role `1` 租户管理员测试账号。恢复后完成登录、HUKS 会话写入与冷启动恢复、
工作区、设备分页和详情闭环。
后端升级期间，真实联调债务继续冻结；客户端侧通过源码、契约 Mock、构建、
签名和真机安装门后，可以继续实现 role `0` 平台租户选择。之后按 Session、
告警与 WebSocket、设备命令的顺序逐批交付，但每批的真实后端验收仍必须回补。

2026-08-17 18:24 再次完成简约浅色/深色主题 signed HAP 构建，
`BUILD SUCCESSFUL in 16 s 563 ms`。最新 HAP SHA-256 为
`F57BD2DB4234FF7F2F6E4077EEDF12963027FDCA995930729A43C4D0B25CF53A`，
`hap-sign-tool verify-app` 再次确认签名块、代码摘要、证书链和 debug Profile
有效。随后仅对目标 USB 真机执行 `hdc install -r` 并成功启动本应用；
未卸载、未清数据、未改系统设置。

真机日志确认页面加载成功并可接收滚动输入。日志仍包含 debug HAP 的系统
theme pattern 缺项告警，但未出现 `wifi-manager` 初始化失败或 JS 崩溃；
该系统告警不作为客户端功能通过证据，也不阻塞当前本地验收。

当前 H0 验收结论：源码审计、真实契约映射、构建、签名、离线验签、覆盖安装、
启动冒烟和简约双主题实现通过；真实业务闭环运行门因后端升级冻结，尚未通过。
Mock 结果只证明客户端解析与 DTO 适配，不替代真实认证、Cookie 轮换、租户隔离
和设备查询证据。用户已授权冻结该外部依赖门并继续客户端实现，因此后续阶段
只能取得“客户端侧通过”，不能宣告真实端到端通过。

## 10. 登录移动端纠偏验收

2026-08-17 19:03 完成登录页纠偏：

- 删除 Gateway 输入框和工作区底部地址展示，Gateway 改为纯部署配置。
- 页面改为无卡片嵌套的手机单列布局，保留浅色/深色切换。
- 账号类型改为 48vp 高的高对比分段控件；浅色选中态使用深青绿色底和白字，
  未选中态使用白色底、深色文字和明确边框。
- 复用真实 `POST /auth/login`，支持用户名密码和手机号/邮箱密码登录。
- 新增真实 `POST /auth/code-login` 与 `POST /auth/codes` 适配，支持联系方式
  验证码登录、发送状态和 60 秒倒计时。
- 新增密码显示/隐藏；“记住账号”只持久化账号类型和账号文本，不保存密码、
  验证码、Token 或 Cookie。
- `ApiResponse<Void>` 的 `data:null` 按后端三字段契约解析；缺少 `data` 字段仍按
  `DEPENDENCY_PROTOCOL_INVALID` 拒绝。

Vue 登录页已有但 HarmonyOS 尚未实现的能力继续作为真实闭环排队：注册、忘记
密码、OAuth Provider 查询与回调。OAuth 在应用链接/浏览器回跳方案确认前不展示
空入口。

本次 Hvigor `test` 共 15 项，`BUILD SUCCESSFUL in 15 s 592 ms`；最终
`assembleHap` 为 `BUILD SUCCESSFUL in 17 s 79 ms`。独立 `verify-app` 确认
Signing Block v3、代码摘要、证书链和 debug Profile 有效。最终 HAP：

```text
entry/build/default/outputs/default/entry-default-signed.hap
SHA-256 36140B3C25840B9FA4082FC087C01BFED6F7C74537A39CCD27E393842EE8F438
```

最终 HAP 已通过 `hdc install -r` 覆盖安装到唯一 USB 真机
`88X9K26526081036`。首次启动时手机再次自动锁屏，系统返回 `10106102`；
未通过 HDC 解锁或修改系统设置。手机恢复解锁后，只重试本应用启动并成功。
限定应用 PID `27998` 的日志确认 `Ability onCreate`、`onWindowStageCreate`、
`onForeground`、内容加载和登录页路由加载成功，未发现 `wifi-manager` 初始化
错误、未捕获异常或 JS 崩溃。系统 theme pattern 告警仍按既有非阻塞项记录。

## 11. 移动端视觉与平台组织阶段

2026-08-17 19:28 完成移动端视觉纠偏和平台组织客户端阶段：

- Gateway 不作为账号字段或普通用户设置项。当前唯一地址由
  `RuntimeConfig.ets` 提供；云部署时替换部署配置并重新构建。
- 登录账号类型改为高对比的原生分段控件；联系方式下的密码/验证码为二级模式，
  不再使用两排同权重大按钮。
- 浅色主题改为中性灰白背景、深色正文和克制的绿色操作色；深色主题继续使用
  独立资源。主题切换收为单个“日间/夜间”按钮并保留 Preferences 持久化。
- 工作区按“当前身份 -> 常用功能 -> 账号与工作区 -> 退出”排序，不优先展示
  `contextType` 等内部字段。平台管理员先选择组织，租户管理员进入设备和
  Session，成员只进入本人 Session。
- `GET /admin/platform/tenants` 改为 20 条分页和“加载更多”，不再把前 100 条
  当作全集；搜索从第一页重置，最终 401 返回登录页。
- 进入组织仍使用 `POST /auth/platform-context/tenants/{tenantId}` 和不超过
  255 字符的原因；返回平台仍使用 `POST /auth/platform-context`。客户端校验
  新 Token、上下文类型和 tenantId，一切权限和状态转换以后端结果为准。

本阶段 15 项 ArkTS 契约测试通过，完整 signed HAP 构建成功并通过独立验签；
随后只对唯一真机执行覆盖安装和启动。未卸载、未清数据、未改系统设置、未读写
手机业务文件。

## 12. Session 客户端阶段

2026-08-17 19:40 完成 Session 客户端最小闭环：

- 新增 `SessionModels.ets`、`SessionRepository.ets`、
  `SessionListPage.ets` 和 `SessionDetailPage.ets`。
- 管理员在 TENANT 或 PLATFORM_TENANT 上下文使用
  `GET /admin/sessions` 和
  `POST /admin/sessions/{sessionId}/revoke`。
- 成员使用 `GET /sessions` 和
  `POST /sessions/{sessionId}/logout`，请求不携带客户端伪造的 userId 或
  tenantId。
- 列表支持状态、MAC、设备编号和管理员用户编号筛选及分页；详情展示
  `SessionRecordVO` 的连接、设备、流量和时间字段。
- 注销/撤销使用二次确认。详情页从当前加密会话快照重新派生管理员身份，不信任
  路由参数；操作响应必须返回相同 sessionId，否则按
  `DEPENDENCY_PROTOCOL_INVALID` 拒绝。
- 设备命令执行记录和轮询未塞入本批次。管理员撤销后的最终设备执行状态仍必须
  在后续命令批次按真实后端结果实现。

测试源共 19 项，Hvigor `test` 为 `BUILD SUCCESSFUL in 9 s 235 ms`；最终
`assembleHap` 为 `BUILD SUCCESSFUL in 17 s 850 ms`。独立 `verify-app`
确认 Signing Block v3、代码摘要、证书链和 debug Profile 有效。最终 HAP：

```text
entry/build/default/outputs/default/entry-default-signed.hap
SHA-256 01344C38768EE94CDD27CA2384BFFB568151D73C72B2C11F68DD36D03E770B97
```

最终 HAP 已通过 `hdc install -r` 覆盖安装到唯一 USB 真机并成功启动。
限定 PID `49138` 的日志确认 `onWindowStageCreate`、`onForeground`、页面加载
和 ArkUI 首帧完成，未匹配到未捕获异常或 JS 错误。真机没有可用真实后端会话，
因此 Session 列表、详情、成员注销、管理员撤销、租户隔离和设备命令终态的真实
运行证据继续冻结；Mock 只证明客户端 envelope 与 DTO 适配，不替代端到端验收。

本轮未修改 Vue 或后端源码，未 commit、未暂存、未 push。鸿蒙仓库仍处于首提交
前的全量未跟踪状态；本机签名路径和口令仍不得直接发布到远端，首次提交前必须
单独完成本地签名配置的仓库边界处理。

## 13. 告警 REST 客户端阶段

2026-08-17 20:06 完成告警 REST 客户端最小闭环：

- 管理员在 `TENANT` 或 `PLATFORM_TENANT` 上下文使用
  `GET /admin/alerts`、`GET /admin/alerts/{id}` 和
  `PATCH /admin/alerts/{id}/handle`。
- 列表支持级别、处理状态和 MAC 筛选及分页；详情展示规则、设备、用户、
  时间和处理状态，并在处理前二次确认。
- API 24 的 `http.RequestMethod` 未声明 `PATCH`，但
  `HttpRequestOptions.customMethod` 自 API 23 起支持自定义 HTTP 方法。
  客户端通过统一 HTTP 与 Session 层透传 `customMethod: 'PATCH'`，首次请求和
  401 刷新后的重放保持相同方法，不使用 Method Override，也不修改后端契约。
- 详情页告警编号由路由参数校验后保存为 `alertId`，避免与 ArkUI 组件 `id()`
  冲突。页面权限继续从当前加密会话快照派生，不信任路由参数。

测试源共 21 项，Hvigor `test` 为 `BUILD SUCCESSFUL in 12 s 402 ms`；
完整 `assembleHap` 为 `BUILD SUCCESSFUL in 12 s 140 ms`。独立
`verify-app` 确认 Signing Block v3、代码摘要、证书链和 debug Profile 有效。
最终 HAP：

```text
entry/build/default/outputs/default/entry-default-signed.hap
SHA-256 7434B6506AEC8D102B3DD82FC49B950FC4190D3AD902F4E229B81595FC7904DA
```

最终 HAP 已通过 `hdc install -r` 覆盖安装到唯一 USB 真机
`88X9K26526081036` 并成功启动。限定 PID `64581` 的日志确认
`Ability onCreate`、`onWindowStageCreate`、`onForeground` 和页面内容加载
成功，未发现未捕获异常或 JS 错误。未卸载、未清数据、未重启设备、未修改系统
设置，也未删除手机文件。

真实后端仍在升级，告警查询、详情、处理权限、租户隔离和状态转换的真实运行
证据继续冻结。Mock 仅验证客户端 envelope 与 DTO 形状，不替代真实联调。

## 14. 告警 WebSocket 客户端阶段

2026-08-17 20:33 完成 `/ws/alerts` 原生客户端适配：

- 只允许管理员在 `TENANT` 或 `PLATFORM_TENANT` 上下文打开连接；Access JWT
  通过 `Sec-WebSocket-Protocol: access_token, {JWT}` 发送，不放入 URL、
  UI、日志或额外缓存。
- WebSocket URL 从隐藏 Gateway 配置派生，`http/https` 分别转换为 `ws/wss`。
  本地 Origin 也位于 `RuntimeConfig.ets`，不提供普通用户输入。
- 当前本地 Origin 与后端默认 `http://portal.test:5173` 一致。云部署时必须同时
  修改客户端 Origin 配置以及 Gateway、monitor-service 的 Origin 白名单；
  这属于部署配置条件，不修改后端公共 API 或业务模型。
- 客户端响应服务端 JSON `PING` 并发送 `{"type":"PONG"}`。告警消息要求
  `type=alert`、正整数 `alertId`，并再次核对 payload `tenantId` 与当前加密
  Session 上下文相同；不匹配或格式无效的消息被忽略。
- 连接仅在管理员告警列表页和应用前台保持。页面离开、Ability 进入后台或销毁
  时关闭连接；回到前台后按需恢复，不实现后台常驻或系统推送。
- 普通断开按 1 秒、2 秒、4 秒逐步退避，最大 30 秒；服务端心跳超时关闭码
  `4000` 进入退避重连。明确 `401/403` 错误文本或策略关闭码 `1008` 停止自动
  重连并显示“连接被拒绝”，用户可显式重试。
- HarmonyOS API 24 不保证在握手失败回调中稳定暴露 HTTP 状态。因此无法从所有
  原生错误中严格区分 401、Origin 403 和网络失败；未明确识别的错误按普通断开
  退避处理。该限制必须在真实 Gateway 联调时回补验证。
- 告警页使用紧凑状态行显示连接状态；收到新告警时显示内联提示和“刷新”操作，
  不复制 Vue 的全局网页 Toast，也不使用星空或装饰动画。

测试源共 24 项，新增覆盖 WebSocket URL 转换、PING/告警解析、跨租户消息拒绝
和退避上限。最终 Hvigor `test` 为 `BUILD SUCCESSFUL in 16 s 729 ms`；
完整 `assembleHap` 为 `BUILD SUCCESSFUL in 18 s 425 ms`。独立
`verify-app` 确认 Signing Block v3、代码摘要、证书链和 debug Profile 有效。
最终 HAP：

```text
entry/build/default/outputs/default/entry-default-signed.hap
SHA-256 7B5E80272237E8C78190BD97B455B0ED068280065009AAB1C20FE4B7A02F3A64
```

最终 HAP 已通过 `hdc install -r` 覆盖安装到唯一 USB 真机
`88X9K26526081036`，`aa start` 返回成功。应用 PID `17918` 在启动 3 秒后仍
存在，限定该 PID 的 ERROR/FATAL 查询无输出。本次日志缓冲区没有返回生命周期
行，因此不把 ArkUI 首帧记为新增证据；此前告警 REST 批次的首帧证据仍有效。
未卸载、未清数据、未重启设备、未修改系统设置，也未删除手机文件。

由于后端升级且真机没有可用管理员会话，本阶段未产生真实 WebSocket 握手、
Gateway JWT 终止、Origin 校验、租户广播、PING/PONG 或断线重连运行证据。
该端到端门继续冻结，24 项测试不替代真实 Gateway 与 monitor-service 验收。

## 15. 设备命令与执行记录客户端阶段

2026-08-17 完成设备详情中的手动命令最小闭环：

- 设备详情新增“设备控制与执行记录”入口，独立移动页面提供重启设备、断开
  MAC 和阻断 IPv4/SNI 三类现有管理操作，不复制 Vue 的桌面表格布局。
- 命令提交分别复用：
  - `POST /admin/devices/{deviceCode}/kick`
  - `POST /admin/devices/{deviceCode}/disconnect-mac`
  - `POST /admin/devices/{deviceCode}/block-traffic`
- 执行记录复用
  `GET /admin/device-commands?deviceCode={deviceCode}`；提交成功后使用后端返回的
  命令 `requestId` 增加精确筛选并查询终态。
- 当前三个提交 DTO 不接受 `clientRequestId`，命令 `requestId` 由后端落库时
  生成。客户端不把 HTTP `X-Request-Id` 当作设备命令编号，也不自行生成命令
  幂等键。
- 客户端对网络超时不自动重新提交命令；用户再次提交仍需重新确认。由于当前
  后端提交契约没有调用方幂等键，响应丢失后的人工重试无法由客户端证明不会
  重复入队，这是后端公共契约边界，本阶段未修改后端。
- 统一会话层仅在收到明确 HTTP 401 后刷新 Token 并重放一次；按现有 Gateway
  约束，认证失败在请求路由到命令 Controller 前完成。该顺序需要真实 Gateway
  联调确认，客户端不能把它替代为本地成功或幂等结论。
- 后端命令状态 `0/1` 为非终态，`2/3/4/5` 分别为成功、设备执行失败、发布失败
  和结果超时。客户端最多查询 20 次、每次完成后间隔 3 秒，不发起并发轮询；
  本地次数耗尽只显示“本轮查询已停止”，不伪造设备失败终态。
- 页面离开、Ability 进入后台或销毁时停止后续轮询；回到前台只恢复同一命令的
  剩余次数。非终态历史记录支持用户显式继续查询。
- 页面只展示命令类型、后端状态、命令编号、结果时间和结果消息，不展示
  `DeviceCommandResult` 或 `DeviceCommandVO` 中的 MQTT `topic/payload`。
- 当前上下文必须是 `TENANT` 或 `PLATFORM_TENANT` 且角色为 `0/1`；只读上下文
  禁用提交。客户端门禁不替代后端角色、租户、设备归属和状态检查。
- WiFi 候选凭据下发属于独立敏感配置流程，本批次没有把它并入普通命令表单。

交付前审计定向修复了历史加载与命令提交共用请求版本导致的加载状态竞争，并
将 `3/4/5` 失败终态从成功提示改为错误提示。执行记录响应还会校验分页对象、
记录数组、关键字符串和 `0..5` 整数状态，畸形响应按
`DEPENDENCY_PROTOCOL_INVALID` 拒绝。

测试源码新增 4 项 Mock/纯函数用例，覆盖命令提交 envelope、执行记录 DTO、
真实终态集合以及 MAC、IPv4 和命令编号格式。测试总数为 28 项，Mock 仍只位于
`entry/src/test`。最终 Hvigor `test`：

```text
BUILD SUCCESSFUL in 10 s 919 ms
```

最终 `assembleHap` 使用保留的 `nova16` 调试签名：

```text
BUILD SUCCESSFUL in 19 s 590 ms
entry/build/default/outputs/default/entry-default-signed.hap
SHA-256 FBA5B8B23B667A66DA43063B0ECA75C1B3DF0F36B557D8AF2197F8826303C918
```

独立 `hap-sign-tool verify-app` 和 `verify-profile` 确认 Signing Block v3、
代码摘要、证书链和 debug Profile 有效；Profile 的 bundleName 为
`com.plagod.WiFiEdgeManager`。

最终 HAP 已通过 `hdc install -r` 覆盖安装到唯一 USB 真机
`88X9K26526081036` 并成功启动。应用 PID `5538` 在等待后保持不变；限定该
PID 的日志确认 `Ability onCreate`、`onWindowStageCreate`、`onForeground`
和内容加载成功，未匹配到本应用 ERROR/FATAL。未卸载、未清数据、未重启设备、
未修改系统设置，也未删除手机文件。

后端升级和真机无管理员 Session 的条件未变化，因此本阶段没有产生真实命令
入队、MQTT 发布、ESP32 回执、终态轮询、租户隔离、401 重放或 429
`Retry-After` 运行证据。这些端到端门继续冻结；28 项测试、构建、验签和启动
冒烟只证明客户端实现通过，不替代真实后端与设备执行验收。

## 16. 首次仓库发布复验

2026-08-18 首次提交前完成仓库发布边界复验：

- 候选源码、配置、文档和资源共 72 个文件、约 479 KB；构建目录、依赖目录和
  IDE 本地状态均未进入候选集。
- 敏感扫描只命中本机 `build-profile.json5` 中的签名路径与口令，没有发现
  硬编码 Access Token、Refresh Token、Bearer 凭据或私钥正文。
- 仓库版 `build-profile.json5` 已移除本机 `signingConfigs` 和产品签名绑定；
  本机工作文件仍保留 `nova16`，用于后续真机覆盖安装。
- 使用仓库版无签名配置执行 28 项 ArkTS 测试成功：

```text
BUILD SUCCESSFUL in 30 s 685 ms
```

- 同一仓库配置执行 `assembleHap` 成功：

```text
BUILD SUCCESSFUL in 14 s 624 ms
```

- 恢复本机 `nova16` 后再次执行 signed `assembleHap` 成功：

```text
BUILD SUCCESSFUL in 16 s 206 ms
entry/build/default/outputs/default/entry-default-signed.hap
SHA-256 B1818A71029EF61E33E34624175D690DECA5904A52604D86398D9BCC7FE9AD21
```

独立 `hap-sign-tool verify-app` 和 `verify-profile` 再次通过，确认 Signing
Block v3、代码摘要、证书链和 debug Profile 有效。本发布门没有重新安装、
启动或读取真机；第 15 节的受限真机证据仍对应当时已安装的
`FBA5B8B23B667A66DA43063B0ECA75C1B3DF0F36B557D8AF2197F8826303C918`
构建。

后端升级期间的真实登录、命令入队、MQTT/ESP32 回执、租户隔离、401 重放和
429 行为仍保持冻结。首次发布只冻结已通过的 HarmonyOS 客户端实现和审计证据，
不把 Mock 或本地构建提升为真实端到端结论。

## 17. 上游 WiFi 候选配置客户端阶段

2026-08-18 完成设备上游 WiFi 候选配置的客户端最小闭环：

- 设备详情新增“上游 WiFi 配置”入口，独立页面重新使用 nodeId 查询设备详情，
  不信任路由携带的设备状态。
- 提交复用
  `POST /admin/devices/{deviceCode}/wifi-config/candidate`，请求体只包含当前
  `ssid` 和 `password`。
- 最近任务和精确任务分别复用
  `GET /admin/devices/{deviceCode}/wifi-config/latest` 与
  `GET /admin/devices/{deviceCode}/wifi-config/{requestId}`。
- 新设备尚未配置时，`latest` 的 `ApiResponse.data=null` 是有效空状态；其他
  任务响应必须校验设备编号、操作编号、配置版本、SSID、密码配置标记、状态和
  时间字段，畸形响应按 `DEPENDENCY_PROTOCOL_INVALID` 拒绝。
- 状态 `0/1/4` 分别为正在下发、已保存等待连接和结果未知，均不是终态；
  `2/3/5` 分别为已生效、失败和被新配置替代，属于后端真实终态。
- 客户端最多查询 20 次，每次请求完成后间隔 3 秒，不并发查询。页面离开、
  Ability 后台和销毁会停止或暂停后续查询；本地次数耗尽不伪造设备失败。
- 只读工作区和当前离线设备禁用提交，提交前使用内联二次确认。客户端门禁只
  用于交互，最终角色、租户、设备归属、心跳和任务状态以后端结果为准。
- SSID 和密码按 UTF-8 字节验证：SSID 为 1 到 32 字节；密码为空表示开放网络，
  否则为 8 到 63 字节；两者均拒绝空字符。
- 密码只保存在当前页面状态和当次 HTTP 请求体中。提交开始、提交失败、页面
  隐藏或离开时立即清除，不写 Preferences、HUKS、日志或任务展示；响应只展示
  后端 `passwordConfigured` 布尔值。
- 提交契约不接受调用方幂等键，`requestId` 和 `configVersion` 均由后端生成。
  客户端不会因网络超时自动重新提交；响应丢失后的人工重试无法由客户端证明
  不会创建新版本。
- 统一会话层仍只在明确 HTTP 401 后刷新并重放一次。其安全性依赖 Gateway 在
  请求进入命令 Controller 前完成认证拒绝，必须在后端恢复后真实联调确认。

测试新增 4 项，覆盖提交 DTO 不回传密码、最近任务空状态、真实终态集合和
SSID/密码 UTF-8 边界，总计 32 项。首轮测试有一个测试期望错误，把 5 个汉字
误写为 18 字节；实现实际返回正确的 15 字节，修正测试后显式检查 Hypium 输出
中没有 `ERROR`。最终测试结果：

```text
BUILD SUCCESSFUL in 24 s 519 ms
```

完整 signed HAP 构建和独立验签通过：

```text
BUILD SUCCESSFUL in 25 s 680 ms
entry/build/default/outputs/default/entry-default-signed.hap
SHA-256 330DAA69E90A0CC29E81A3BBE288CE1EA26DCB330719F54B1BCC148142479740
```

`hap-sign-tool verify-app` 和 `verify-profile` 确认 Signing Block v3、代码
摘要、证书链和 debug Profile 有效。最终 HAP 仅通过 `hdc install -r` 覆盖
安装到唯一 USB 真机 `88X9K26526081036`，随后启动本应用；PID `55095` 的有限
日志确认 `Ability onCreate`、`onWindowStageCreate`、`onForeground` 和内容
加载成功，未匹配本应用 ERROR/FATAL。未卸载、未清数据、未重启设备、未修改
系统设置，也未删除手机文件。

后端升级和真机无管理员 Session 的条件没有变化，因此本阶段没有产生真实候选
配置入库、加密 Outbox、MQTT 发布、ESP32 保存/切换、状态 `1/2/3/4/5`、
跨租户拒绝、401 重放或 429 `Retry-After` 运行证据。新页面也无法在真实登录
后进入，当前真机证据只证明安装和启动无回归；这些端到端门继续冻结。
