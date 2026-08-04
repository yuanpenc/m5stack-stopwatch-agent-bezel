# 技术说明

当前中文总览、协议边界和实机验证顺序分别见：

- [项目中文说明](../README.zh-CN.md)
- [底层协议](TECHNICAL.md)
- [Companion 数据协议](COMPANION_PROTOCOL.md)
- [移植验证清单](PORTING.md)

本项目使用未公开的兼容协议，任何 ChatGPT Desktop 更新都可能导致失效。当前
MVP 已经在真实 C152 上完成验证；修改 HID descriptor、按键映射或 BLE 服务后，
必须重新完成 `device.status` 往返和实体控制验证，不能仅凭编译通过声称兼容。
