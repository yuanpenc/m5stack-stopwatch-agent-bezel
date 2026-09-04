# Hermes Desktop 与三桌面循环设计

## 状态与范围

- 状态：Approved。用户确认开始代码实现；按本规格串行实施，硬件验收另行进行。
- 基线：`3c955f3`，开发分支 `feature/hermes-desktop-workspace`。
- 目标：USB 麦克风版 M5Stack StopWatch C152；保留现有 Codex Micro 面板与 SUPER 功能，增加 Hermes Desktop。
- 方式：当前会话串行实施，不使用子 Agent。设计审阅后编写逐任务 TDD 实施计划。
- 原型与嵌入式 framebuffer 不等同；字体、接缝、滑动与应用行为均需 native preview 和物理 C152 验收。

## 1. 已批准交互

左滑循环：`Codex / ChatGPT → super.engineering → Hermes Desktop → Codex / ChatGPT`。

这是三个应用入口，不是四个。设计阶段本机应用清单显示名称为 ChatGPT 的应用使用 `com.openai.codex`；不把它与 Codex 再拆成两个循环目标。

| 手表模式 | 左滑 | 上滑 | 下滑 | 右滑 |
| --- | --- | --- | --- | --- |
| Codex | 进入 SUPER | 原有映射 | 原有映射 | 原有映射 |
| SUPER | 进入 HERMES | 上一个项目 | 下一个项目 | 下一个会话 Tab |
| HERMES | 回到 Codex | 上一个会话 Tab | 下一个会话 Tab | 新建会话 Tab |

- 取消原型中的四格按钮与选择菜单；不新增第四模式。
- 左滑替代原先的 SUPER 进入/返回策略，不再记录或返回任意旧应用。
- 上/下/右不承担反向桌面切换，不引入可编辑宏。
- macOS 前台变化决定手表模式；左滑只请求激活，不乐观修改手表模式。
- 手表屏幕切换与 macOS 应用激活存在传输延迟，不承诺原子同步或零延迟。
- 对三个目标以外的前台应用，手表维持 Codex 面板；左滑先激活 Codex，作为重新进入循环的确定入口。这是本规格明确的边界规则，须随书面规格审阅。

## 2. 前台身份与固定按键

| 模式 | exact bundle ID | Companion 上/下/右 |
| --- | --- | --- |
| Codex | `com.openai.codex` | 不注入；沿用应用已有控制器映射 |
| SUPER | `com.zarifpour.superconductor` | `Control-Option-Up` / `Control-Option-Down` / `Control-Option-Right` |
| HERMES | `com.nousresearch.hermes` | `Control-Shift-Tab` / `Control-Tab` / `Command-T` |

Hermes 映射来源：[Hermes Desktop 官方文档，Windows, tabs & panes](https://hermes-agent.nousresearch.com/docs/user-guide/desktop#windows-tabs--panes)。官方快捷键可被用户重新绑定；本机是否仍为默认值必须通过实际按键验收，不读取配置文件来推断。

三个 bundle ID 在设计阶段已从本机运行应用清单观察到；实现安装前再核对应用元数据，不依据显示名称模糊匹配，也不匹配 `.setup` 安装器。

进程投递同时校验：命令允许的 bundle ID、当前前台 PID/bundle ID、PID 当前对应的存活应用。使用成对 key-down/key-up，固定修饰键。只调用进程定向投递，不产生全局键盘事件，不用 UI 抓取、菜单点击或脚本执行替代。

投递返回值只表明事件已提交，不证明目标应用执行了操作。新建 Tab 不做自动重试，避免重复创建。

## 3. 共享方向界面

SUPER 与 HERMES 共用一套几何与绘制逻辑，仅固定标题及右侧文案不同。

- 画布 `466 × 466`，沿用现有四个向外三角形及 5px 轮廓构造。
- 删除独立绿色中心方框。中心由四个三角形的底边围合；填充中心内部时不得覆盖三角形底边，也不得出现延伸出角的方框笔画。
- 中央保留 `SUPER` / `HERMES`、连接状态、电量、充电状态与现有电源确认覆盖层。
- 左侧 `BACK` 改成 `CYCLE`；上下为 `PREV` / `NEXT`；右侧 SUPER 为 `TAB`，HERMES 为 `NEW`。
- HERMES 字号必须适配中心区域；不得通过改动全局字体而影响 Codex。现有嵌入字体不足时，仅为共享工作区增加必要字号并附原字体许可，先核对 native preview 再定实现。
- 固定文字颜色，不跟随随机边框；滑动方向通过内部短暂提亮提示，不用白色覆盖随机边框。
- `CONNECTED` 表示现有设备连接状态，不表示 Hermes Agent 健康、会话运行状态或操作成功。
- 模型不得新增项目名、会话名、窗口标题、任务内容、配额或账号字段。

### 3.1 随机色池

按原型批准的以下 12 个 RGB888 常量转换为 RGB565，颜色转换后仍须互不相同：

```text
#25D8FA #FFA735 #EC50FF #65B9FC
#FFE36A #7DED93 #FF8397 #B8A0FF
#5EE3C4 #C7EF72 #FFAE86 #F0F4FF
```

每次本地有效四向滑动，从色池中抽取四种不同颜色，按上、右、下、左储存。每个方向不得与自己上一次颜色相同；允许某种颜色在下一次转移到另一方向，不要求四种颜色全部从上一组之外抽取。

- 使用可注入随机数源的有限步骤抽样；不能用“反复抽到符合为止”的无界循环。
- 每次事件抽样一次，颜色存储在独立视觉状态中，不在 renderer 中抽样。
- 全部四向滑动均可更新色组；不是只有切换应用的左滑才换色。
- 视觉状态使用基于单调时间、无符号差值的 800ms 冷却；一个接触手势至多触发一次，释放不换色。此视觉门控不改变已有 HID 发送、释放和震动语义。
- 在 Codex 上产生的有效滑动可以更新隐藏色组，但 Codex 原面板不改变；随后进入 SUPER/HERMES 使用该色组，不再额外抽一次。
- 心跳、应用前台通知、普通重绘、电量更新、配额同步、滑动反馈结束均不换色。外部 Dock/Command-Tab 切换沿用当前色组。
- 800ms 内忽略的视觉重复输入不换色。Companion 保留自身现有按设备 decoder 防抖；两者不共享时钟或操作确认，不把颜色当成 Companion 接受命令的证据。
- 应用激活失败时，手表保持真实前台对应模式；本地滑动已发生的配色反馈不回滚。
- 不持久化色组、不写 flash、不通过 RPC 传颜色。重启恢复初始四种颜色；重绘和模式间切换不得重置随机状态。

## 4. 组件与职责

| 组件 | 责任 | 不负责 |
| --- | --- | --- |
| 固件 workspace lease | 严格解析固定模式、连接所有权、过期回退 | 应用激活、随机颜色 |
| 固件方向视觉状态 | 色池抽样、800ms 视觉门控、保存当前四种颜色 | HID 按键成功确认 |
| 固件共享 renderer | 纯绘制标题、方向、连接与电量 | 抽随机数、发 RPC、读 Agent 内容 |
| Companion app profile | 固定应用标识、方向命令、循环次序 | 动态配置或任意宏 |
| Companion cycle controller | 根据真实前台请求下一应用、协调激活中的状态 | 决定已成功显示的手表模式 |
| Companion command router/emitter | 中立方向事件分派、权限检查、定向按键 | 全局按键、读取应用数据 |
| Companion mode coordinator | 真实前台到 mode、设备附着/移除、5 秒续租 | 创建 Spaces、改变输入映射 |

已有 decoder 中以 SUPER 命名的事件应变为中立方向事件，保持 `v.oai.rad` 线协议与角度语义不变。应用策略不应留在解码器内。

改动集中于 `include/WorkspaceMode.h`、`include/WorkspaceInputPolicy.h`、`include/SuperWorkspaceUi.h` 或其共享替代文件、`src/main.cpp`、`src/CodexMicroBle.cpp`，以及 Companion 现有 decoder/router/emitter/toggler/coordinator/writer 与对应测试。新增 profile、cycle controller、palette 模块须保持小而独立，不做无关重构。

## 5. 应用激活生命周期

1. 每次接受左滑时重新读取前台身份，不按累计滑动计数推断当前桌面。
2. 已运行目标调用公开 `activate(options: [])`；未运行目标通过 NSWorkspace 查找并启动。
3. 同一时间只允许一个激活请求；等待期间的左滑不排队、不叠加目标。上/下/右仍按当时真实前台路由。
4. 公开激活请求成功不等于前台已改变。观察到 exact target 前台才完成请求；模式协调器独立跟随真实前台。
5. 请求最长等待 3 秒。启动失败、拒绝或超时后结束请求，不跳过目标、不重试按键；下一次用户左滑可重新请求。
6. 使用请求 generation 和 started 状态使 stop/重启后的延迟回调成为 no-op。延迟启动成功若确实改变前台，只由前台观察重新同步，不把旧回调写入新的循环状态。
7. 请求中用户通过 Dock/Command-Tab 切到另一个应用时取消该请求的跟踪并服从真实前台；已交给 macOS 的启动不可强制撤销，不伪称能阻止系统迟到的激活。
8. 移除“返回上一应用”的存储与行为，不对旧应用 PID 做恢复或唤起。

## 6. 固定 RPC、所有权与心跳

仍使用 Report ID 6 Output RPC，仅增加固定的 `hermes` 枚举：

```json
{"method":"host.workspace_mode","params":{"mode":"super","ttl_ms":15000},"id":1}
{"method":"host.workspace_mode","params":{"mode":"hermes","ttl_ms":15000},"id":2}
{"method":"host.workspace_mode","params":{"mode":"codex"},"id":3}
```

- `codex` 仅允许 mode；`super` 和 `hermes` 必须恰好有 mode 与整数 `ttl_ms:15000`。
- 缺字段、多字段、类型错误、布尔 TTL、负值、浮点、溢出及其他 TTL 均拒绝，返回 `-32602`，不改变模式、所有者或刷新时间。
- SUPER/HERMES 共用一份租约。所有者可以在二者间切换并续租；其他连接不能夺取、切换或刷新现有租约。
- 任意合法 `codex` 可安全退出；所有者断开或无符号 elapsed 达到 15000ms 回到 Codex。非所有者断开不清理租约。
- 只在模式实际改变时置 dirty；单纯续租不重绘、不改变颜色、不设置 hostRpcObserved、不伪造 CODEX LIVE。
- workspace RPC 保持 `ControlOnly`；仅 `HostActivity` 调用原有活动记录。
- Report ID、64 字节完整报告、61 字节分片上限、UTF-8 字节分片、末尾换行、UInt32 请求序号回绕与任一分片失败即停止保持不变。
- writer 只构造固定字符串，不接受显示文本、颜色或应用内容；不记录 payload、设备标识或 UUID。

协调器在 SUPER/HERMES 前台每 5 秒发送当前模式；二者切换时立即发送新模式，timer 保持单实例并在回调时读取最新模式，不能捕获旧 SUPER 常量。

进入 Codex 或其他应用时停止租约心跳并发送一次 codex。若此次写失败，仅做有界安全重试（5 秒后一次，再过 5 秒一次）；新的前台模式覆盖并取消旧重试。仍失败依靠固件自上一次成功续租起 15 秒回退。不能在离开 SUPER/HERMES 后继续重发旧模式。

每个 device key 独立保存 output handle/decoder；设备 attach 立即同步真实前台，detach 不影响其他设备。写失败日志全局每 60 秒最多一次，正常心跳不写常规日志。

全部观察、timer、writer、router 和激活回调在 MainActor/主 RunLoop 串行执行。仅真实 `--watch` 创建这些对象；demo、json-only、单次额度与 bootloader 不创建观察器、timer 或 writer。停止时尽力发送 codex，再取消观察和所有 timer，使延迟回调无效，最后停止 listener。

## 7. 输入隔离、睡眠与兼容性

- SUPER/HERMES 共用现有隔离策略：仅四向滑动、红色电源键、中心长按电源确认与旅行关机有效。
- Agent、Send、中心短按及左右 ChatGPT 实体键不发送、不成功震动、不为这些禁用操作唤醒设备。
- 每轮 `codex.poll()` 后、输入处理前读取模式；任何模式切换释放已有麦克风/语音/方向按压，清理 Send、Agent、语音提示、完成提示和触控候选，防止残留按键。
- SUPER/HERMES 持续静默同步 Agent 基线；返回 Codex 不补发旧完成提醒。
- 熄屏时前台/RPC 变化只保存状态；不主动唤醒。下一次合法唤醒显示真实模式及保存配色。
- Codex 原上/下/右映射保持，左方向保持未绑定，避免与新循环重复。Companion 在 Codex/其他应用不补发上/下/右。
- 缺 Input Monitoring 只警告一次，额度继续；缺 Accessibility 只警告一次、停用 SUPER/HERMES 定向导航，不影响左滑、租约、额度与 USB 音频。
- 独立 macOS Space 继续由用户人工设置 Dock 的“分配给此桌面”。应用激活不保证具体窗口或 Space；不新增私有 Space API。
- 保留 Report ID 6、VID `0x303A`、PID `0x8360`、usage page `0xFF00`、usage `1`，按设备释放门控与 800ms Companion 防抖。
- USB 麦克风保持 input-only，不添加 USB 输出端点、不改变采样/音频回调、BLE 配额通道与默认无线固件运行行为。
- 已安装 Companion、LaunchAgent、设备绑定、Codex 路径和日志配置不因设计或本地构建而改变。

## 8. 验证矩阵与发布门槛

### 自动化验证

1. 固件严格参数、三模式租约、所有者切换与拒绝抢占、15 秒边界及 millis 回绕。
2. palette 使用确定性随机源覆盖 12 色池、RGB565 唯一性、四边不重复、各边不沿用旧色、有界抽样、800ms 边界、回绕、重绘与心跳不抽样。
3. renderer 以 native framebuffer 检查 SUPER/HERMES、四向反馈、offline、充电、低电量、未知电量与电源覆盖层；中心无独立边框，三角形底边完整，HERMES 不越界。
4. 输入策略覆盖全部三模式、模式跨越释放、静默 Agent 基线、禁用按钮与睡眠。
5. Swift XCTest 源码覆盖中立 decoder、三目标循环、未知前台入口、激活失败/超时/迟到/stop、exact PID 和 bundle 验证、权限降级、固定按键、重连多设备与无重复 timer。
6. writer 验证新增 hermes 固定消息、完整分片、序号回绕与分片失败；coordinator 验证 SUPER→HERMES 心跳内容改变、Codex 有界失败重试与新模式取消旧重试。
7. 完整原有 native 测试、USB-mic 构建、native preview、HID/USB 工具自测、json-only、模式门控、RunLoop、回调生命周期与额度失败重试。
8. 构建前检查实际 Swift/SDK 状态；若默认 SDK 仍不匹配，使用现有固定 macOS 15.4 SDK 和私有临时 cache/scratch 路径。XCTest 不可执行时保留失败原因，以临时 harness 辅证，绝不称完整 XCTest 通过。

### 本机安装与实机验收

- 先构建并保存可恢复基线固件和原签名 Companion 备份、SHA-256；确认官方 C152 恢复路径。
- 固件安装单独进行：重新枚举下载模式端口并取得当次精确 `/dev/cu.*` 刷写确认，不复用历史端口许可。
- Companion 只替换 bundle 内可执行文件并重新签名；保留原 LaunchAgent 配置并重启原 label，不创建第二个 watch。
- 验证三应用完整循环、未运行目标启动、失败不跳过、Command-Tab/Dock 跟随、Space、800ms、按方向随机换色、无边框接缝、熄屏不唤醒、四向与输入隔离。
- 验证 HERMES 中三个官方快捷键实际生效；新建 Tab 只创建一次；SUPER/ChatGPT 不发生后台误动作。
- 验证 15 秒租约回退、断开重连、无过期 Agent 提示、USB 麦克风枚举与短采集、额度与自动启动。
- 未由用户在物理 C152 上观察的行为均标为“未验证”。关键回归停止验收；回滚固件同样需重新解析端口并确认。
- GitHub push、合并 main、删除开发 worktree 均不属于本次设计或实现的自动授权步骤。

## 9. 文档与隐私

同步更新中英文 README、Companion README、Companion 协议文档和固定模式诊断工具；最终加入 Codex、SUPER、HERMES 三张 native 设计图。不能将浏览器示例当实机截图。

保留 Stopwatch AgentBezel C152 公共品牌、受保护运行标识、上游 MIT 和 NOTICE 引用。所有公开文案继续说明独立、非官方、实验性和未文档化的兼容性。

不读取或传输 Hermes/SUPER/Codex 项目、会话、工作区、窗口标题、内存、提示词、配置或凭据；不把个人路径、用户名、设备标识、录音及本地浏览器会话 URL 写入受版本控制文件。Companion 的工作区控制通道不运行 `sc`、shell、AppleScript、CLI 或任意宏；既有 Codex App Server 额度子进程保持不变。开发阶段编译/测试命令与运行时行为分开。

## 10. 当前证据与下一步

- 已确认：用户批准三桌面循环、去除中央独立边框、12 色池随机抽四色的浏览器交互原型。
- 浏览器层已观察：完整循环、失败保留模式、800ms 忽略重复、外部前台模拟衔接、随机四色及每边变化。
- 配色抽样逻辑曾运行 10000 次检查；这仅是原型算法验证，不是固件验证。
- 基线 `3c955f3` 在新 worktree 重新运行 9 项 native 测试通过；UI 测试使用最小 M5GFX 类型头，未声称完成实际 framebuffer 验证。
- 代码实现已完成；10 项 native 测试、USB-mic 构建、固定 SDK release、53 项临时 Swift harness 与 JSON smoke 通过，完整 XCTest 因 CLT 缺少模块不可执行。
- 已生成并检查 native framebuffer；Companion 安装、刷写与新增功能的物理验收未执行。
- 详细分层证据见 [implementation validation](../plans/2026-09-04-hermes-desktop-workspace-validation.md)。
