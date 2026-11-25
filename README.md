# Lenovo Yoga Book (YB1-X91F) — Debian 13 修复合集

让这台 2016 年的 Atom 平板在 Debian 13 (trixie) 上能正常用：**电池有电量、键盘有背光、回车键不串位、不睡死**。

硬件：Lenovo Yoga Book **YB1-X91F** / Intel Atom x5-Z8550 (Cherry Trail) / 4GB RAM / 64GB eMMC /
Goodix 触摸键盘面 / BQ27542 电量计 + BQ25892 充电管理 / Intel 7265 Wi-Fi

系统：Debian 13 trixie，内核 6.12.x，KDE Plasma 6.3（Wayland）

---

## 解决了什么

| 问题 | 现象 | 根因 | 解决 |
|---|---|---|---|
| **电池不显示** | `ls /sys/class/power_supply/` 为空，托盘无电池 | 电池在 I2C 的 BQ27542 上，Debian 内核没编 `bq27xxx`/`bq25890` 模块 | 外部模块，见下 |
| **键盘背光不亮** | 无 `/sys/class/leds/ybwmi::kbd_backlight` | 背光走 ACPI 方法 `GDIX1001.KBLC()`；主线 `lenovo-yogabook` 驱动要求同时有 Wacom 数位板 (`WCOM0019`)，X91F 没有 → probe 失败 | 自写最小模块 `ybkbdbl` |
| **回车 / 反斜杠串位** | 按回车左半边出 `\`，按 `\` 出回车 | halo-keyboard 的 PC-105 布局表把这两块矩形标反了 | 改 `layout.csv` 两行 |
| **休眠后醒不来** | 合盖/闲置后黑屏、SSH 断、只能长按电源 | Cherry Trail 的 S3 恢复在 Linux 上不可用 | 直接禁用睡眠 |

## 安装

```bash
git clone https://github.com/dongyuXu123/lenovo-yogabook-debian.git
cd lenovo-yogabook-debian
sudo ./install.sh
sudo reboot
```

`install.sh` 会：

1. 装 `linux-headers-$(uname -r)`、`build-essential`
2. 按当前内核版本下载主线源码（`bq27xxx_battery*.c`、`bq25890_charger.c`、`drv260x.c`）
3. 编译并安装模块到 `/lib/modules/$(uname -r)/extra/`
4. 配 `/etc/modules-load.d/` 开机自动加载
5. 禁用睡眠（`sleep.target suspend.target hibernate.target`）
6. 启用 `halo-keyboard-backlight.service` 恢复背光到 20%

装完检查：

```bash
cat /sys/class/power_supply/bq27542-0/capacity      # 电量百分比
cat /sys/class/power_supply/bq27542-0/status        # Charging / Discharging
cat /sys/class/leds/ybwmi::kbd_backlight/brightness # 背光 0-255
upower -i $(upower -e | grep battery)               # upower 视角
```

调背光：

```bash
echo 255 | sudo tee /sys/class/leds/ybwmi::kbd_backlight/brightness
```

## 目录结构

```
modules/
  ybkbdbl.c              自写：ACPI KBLC 背光驱动（GPL-2.0）
  Makefile               外部模块构建
  fetch-upstream.sh      按内核版本拉取主线驱动源码
install.sh               一键安装
keymap/
  patch-halo-keymap.sh   修正回车/反斜杠布局
  layout-fix.md          坐标推导过程
docs/
  findings.md            完整排查记录（电池 / 背光 / 笔按钮 / 震动）
```

## 未解决 / 已知限制

- **震动马达**：`drv260x` 模块能编能加载，但 ACPI 给的 i2c 设备名是 `DRV2604`（大写），驱动表是小写，
  加了大写表项仍未绑定。要动的是 i2c client 名字，没继续深挖。
- **笔形按钮**（切换键盘/数位板）：四层都验过（evdev / HID 原始事件 / ACPI / WMI LED 节点），
  **OS 完全收不到事件**。实测切到数位板模式后键盘触摸面直接停止上报，所以不会误触发按键——
  不需要软件处理。想手动关键盘模拟可以用 `systemctl stop halo-keyboard`。
- **内核升级**：模块是外部编译的，升级内核后需要重新跑 `install.sh`。要免维护可以自己套 DKMS。

## 注意

- 自编模块会让内核 taint（`module verification failed`），属于正常现象。
- 改的是系统级配置，装之前自己留个快照/备份。
- 本仓库的 `ybkbdbl.c` 是 GPL-2.0；由 `fetch-upstream.sh` 下载的主线源码版权归各自作者（GPL-2.0）。

## 致谢

- [Yoga-Book/Halo-Keyboard](https://github.com/Yoga-Book/Halo-Keyboard) — Halo 键盘/触摸板 usermode 驱动
- Hans de Goede 的 `drivers/platform/x86/lenovo-yogabook.c`（本仓库背光模块的思路来源）
- 主线 `bq27xxx_battery` / `bq25890_charger` / `drv260x` 驱动作者
