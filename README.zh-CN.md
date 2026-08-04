# M5Stack StopWatch 版 Codex Micro

[English](README.md)

把 **M5Stack StopWatch Dev Kit C152** 变成一个实验性的 Codex Micro 控制器和
Codex 额度仪表盘。

![466 x 466 原生仪表盘预览](artifacts/dashboard-preview-v2-round.png)

## 它能做什么

- 显示 Agent 状态。
- 显示本周 Codex 剩余额度和 reset 倒计时。
- Agent 完成时变为绿色并播放柔和提示音。
- 左侧实体键用于按住说话（Push to talk）。
- 右侧实体键用于进入或退出 Voice Chat。
- 点击中央大圆盘发送当前输入。
- 在全屏向上、右、下、左滑动，模拟 Codex Micro 摇杆的四个可自定义方向。
- 实体键和触屏操作提供振动反馈。

控制操作使用 Codex Micro 兼容的 BLE HID 通道。额度数据则由 Mac 上的本地
companion 通过项目自有的 BLE GATT 通道单独发送。手表不会保存 OpenAI token。

## 使用要求

- **M5Stack StopWatch Dev Kit，SKU C152**。本移植不支持其他 M5Stack 设备。
- 一台支持蓝牙的 Mac。
- 首次刷机所需的数据 USB-C 线；日常使用走无线连接。
- 支持 Codex Micro 的 ChatGPT Desktop，以及已经登录的本地 Codex 会话。
- 本地 Codex App、Codex CLI，或其他能够运行终端命令的本地 coding agent。

## 推荐安装方式：直接交给 Codex

这是本项目的主要安装方式。项目不会分发预编译的 macOS App、DMG 或 PKG。
Codex 会直接在用户的 Mac 上从源码构建固件和 companion，并把设备专属的信息
留在本地。

### 第一步：在本机打开仓库

下载本仓库的 ZIP 并解压，或用 Git clone，然后在 Codex Desktop 中打开这个
folder。仓库应该放在准备与 StopWatch 配对的那台 Mac 上。

### 第二步：连接 StopWatch

使用支持数据传输的 USB-C 线连接 C152。如果电脑还连接着其他开发板，不要猜测
哪个串口属于 StopWatch。

### 第三步：把下面这段话粘贴给 Codex

```text
请帮我把这个项目安装到真实的 M5Stack StopWatch Dev Kit C152 上。

开始前完整阅读 AGENTS.md 和 README.zh-CN.md。请自主完成安装流程，但严格遵守：

1. 先做只读检查，确认 macOS、C152 硬件、现有构建工具，以及刚刚接入的准确串口。
2. 不要构建或启用麦克风、USB Audio、BLE Audio、diagnostics 或其他暂缓实验；
   只使用 m5stack-stopwatch 固件环境。
3. 安装任何缺失依赖之前先向我解释。不要向我索要 OpenAI API key、登录 cookie、
   access token 或其他凭据。
4. 先向我展示 M5Stack 官方恢复出厂固件链接，再完成固件编译。
5. 刷机前再次解析并报告准确的 /dev/cu.* 端口，只针对这一次设备写入征求确认。
6. 刷机后验证 CODEX_MICRO_STOPWATCH_READY 串口标记，并引导我完成 macOS 蓝牙配对。
7. 帮我配置 ChatGPT Desktop：左键 = Push to talk，Command Key 4 = Toggle voice
   chat，中间 = Send；四个滑动方向的动作由我选择。
8. 从源码编译 Swift 额度 companion。先用 demo discovery 找出这台 Mac 看到的
   CoreBluetooth UUID，再把真实额度写入绑定到这一台设备。
9. 如果我同意开机自动运行，只在本机生成 app wrapper 和 LaunchAgent。路径、UUID、
   日志和生成的 app 都不能进入 Git。
10. 分别验证两个实体键、中央 Send、四向滑动、Agent 颜色、完成提示音、振动、
    真实额度和 reset 更新。没有在真机观察到的结果必须明确标成未验证。
```

仓库中的 [AGENTS.md](AGENTS.md) 为 Codex 提供持续生效的安装和隐私边界，因此
用户不需要在提示词里解释所有实现细节。Claude Code 等其他本地 coding agent
也可以按照同一套说明工作，但本项目默认并主要面向 Codex。

### 第四步：完成可见的系统授权

Codex 会完成终端工作，但 macOS 仍可能要求用户亲自：

1. 同意安装缺失的构建工具。
2. 在刷机前确认准确的设备端口。
3. 在 **系统设置 > 蓝牙** 中配对 **Codex Micro**。
4. 允许本机生成的 companion 使用蓝牙。
5. 在 **ChatGPT Desktop > Settings > Codex Micro** 中配置按键动作。

## 控制方式

| StopWatch 输入 | 上报的控制 | 推荐的 Codex 动作 |
| --- | --- | --- |
| 按住左侧实体键 | Mic key `ACT10` | Push to talk |
| 按一下右侧实体键 | Command Key 4 `ACT09` | Toggle voice chat |
| 点击中央额度圆盘 | Send key `ACT12` | 发送输入框消息 |
| 向上滑动 | 摇杆上 | 用户自定义 |
| 向右滑动 | 摇杆右 | 用户自定义 |
| 向下滑动 | 摇杆下 | 用户自定义 |
| 向左滑动 | 摇杆左 | 用户自定义 |

开发时使用的 ChatGPT Desktop 版本只显示一个 Mic key 设置，没有独立的
`ACT10`/`ACT11` 配置。因此右侧实体键有意映射为可配置的 Command Key 4，
而不是第二个 Mic switch。

## 额度 companion 与隐私

Codex Micro HID 接口本身不包含账户额度。Swift companion 会使用用户已有的
本地登录状态启动 Codex App Server，读取 `account/rateLimits/read`，并且只向
明确绑定的手表发送以下小型快照：

- 剩余百分比；
- reset 倒计时；

它不会向手表发送 API key、access token、账户标识、prompt、任务文本或音频。
设备 MAC、CoreBluetooth UUID、用户名、home 路径和日志都属于本机安装数据，
绝不能提交到仓库。更多内容见 [companion 文档](companion/README.md)和
[GATT 协议](docs/COMPANION_PROTOCOL.md)。

BLE 配对采用平台的 Just Works 流程，没有 passkey 身份验证。请只在可信环境中
使用；Mac 或手表更换所有者时，应删除旧配对。

## 手动编译与刷机

推荐使用前面的 Codex 安装流程。维护者也可以使用
[PlatformIO Core](https://docs.platformio.org/en/latest/core/index.html) 手动构建：

```sh
pio run -e m5stack-stopwatch
pio device list
```

找出连接 C152 后新出现的准确串口。先完成构建并阅读 M5Stack 的
[StopWatch 官方恢复出厂说明](https://docs.m5stack.com/en/guide/restore_factory/stopwatch)，
然后才向已经确认的端口刷写：

```sh
pio run -e m5stack-stopwatch --target upload --upload-port /dev/cu.YOUR_C152_PORT
```

不要复制其他用户文档中的串口。启动成功时串口会输出：

```text
CODEX_MICRO_STOPWATCH_READY
```

随后在 macOS 中配对 **Codex Micro**，打开 ChatGPT Desktop，并按照上表配置。
如果 macOS 缓存了旧 HID descriptor，请在 Mac 上忽略该设备、重启手表，再重新
配对。

### 手动运行额度 companion

```sh
cd companion
swift build -c release

# 只写入演示数据，并打印这台 Mac 看到的 UUID。
.build/release/codex-watch-companion --demo --verbose

# 只在本机替换占位符，绝不能提交生成的 UUID。
.build/release/codex-watch-companion \
  --device-id YOUR_COREBLUETOOTH_UUID --watch --interval 60
```

如需登录后自动运行，让 Codex 在本机创建可选的 app wrapper 和当前用户的
LaunchAgent。仓库只提供通用模板，不包含任何用户生成的配置或预编译 companion。

## 常见问题

### 找不到 C152 串口

- 更换确认支持数据传输的 USB-C 线和接口。
- 断开其他开发板，重新列出端口，再只连接 C152。
- 如果现有固件无法启动，按照 M5Stack 官方 download mode 和恢复出厂流程操作。

### 蓝牙设置中看不到 Codex Micro

- 重启手表后重新扫描。
- 先删除 Mac 上已有的旧 **Codex Micro** 配对。
- 通过串口确认固件已经输出 `CODEX_MICRO_STOPWATCH_READY`。

### 右键界面有反应，但没有进入 Voice Chat

在 ChatGPT Desktop 中把 **Command Key 4** 设置为 **Toggle voice chat**。
本移植的右键发送 `ACT09`，不是 `ACT11`。

### 屏幕显示 `SYNCING MAC`，或者额度已经 stale

- 确认 companion 正在已经配对的 Mac 上运行。
- 重新运行 demo discovery，并绑定那台 Mac 当次打印的准确 UUID。
- 不要复制其他电脑上的 UUID；CoreBluetooth 标识属于本地主机。

## 致谢、许可证与商标

本项目在实现 Codex Micro 兼容层时参考了
[`imliubo/codex-micro-4-core2`](https://github.com/imliubo/codex-micro-4-core2)。
感谢原作者的工作；相关 MIT attribution 保留在 [LICENSE](LICENSE) 和
[NOTICE.md](NOTICE.md) 中。Space Mono 继续使用 `assets/fonts/OFL.txt` 中的 SIL
Open Font License 1.1。

OpenAI 关于原始设备的说明见
[Codex Micro](https://learn.chatgpt.com/docs/features/codex-micro)，companion 所用的
本地客户端接口见 [Codex App Server](https://learn.chatgpt.com/docs/app-server)。

所有名称和标识只用于说明兼容性。版权归属、协议风险、安全、免责声明和商标说明
见 [NOTICE.md](NOTICE.md)。
