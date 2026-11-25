# 排查记录：电池 / 背光 / 笔按钮 / 震动

设备：Lenovo Yoga Book **YB1-X91F**，Atom x5-Z8550，Debian 13 trixie，kernel 6.12.117。

---

## 1. 电池

### 症状
`ls /sys/class/power_supply/` 为空；托盘无电池；upower 看不到。

### 排查
```
ACPI: found native INT34D3 PMIC, skipping ACPI AC and battery devices
platform cht_wcove_pwrsrc: deferred probe pending: getting Vbus regulator
```

ACPI 里没有 `PNP0C0A` 电池设备，DSDT 里也没有 `_BST/_BIF`，更没有 EmbeddedControl 区域
（反编译：`acpidump -b` + `iasl -d`）。

但 I2C 总线上明明挂着：

```
/sys/bus/i2c/devices/i2c-bq27542   ← TI BQ27542 电量计
/sys/bus/i2c/devices/i2c-bq25892   ← TI BQ25892 充电管理
```

### 根因
Debian 内核没编 `CONFIG_BATTERY_BQ27XXX` / `CONFIG_CHARGER_BQ25890`，设备在但驱动不在。

### 解决
主线源码编成外部模块（`modules/Makefile` + `fetch-upstream.sh`）：

```
bq27xxx_battery.ko + bq27xxx_battery_i2c.ko + bq25890_charger.ko
→ /lib/modules/$(uname -r)/extra/
→ /etc/modules-load.d/yogabook-battery.conf
```

验证：

```
/sys/class/power_supply/bq27542-0/{capacity,status,voltage_now,temp,health,cycle_count}
/sys/class/power_supply/bq25890-charger-0/   (BQ25892 Fast charging)
upower -i ...
```

---

## 2. 键盘背光

### 症状
键盘背光不亮；`/sys/class/leds/` 为空；
`halo-keyboard-backlight.service` 因为
`ConditionPathExists=/sys/class/leds/ybwmi::kbd_backlight/brightness` 不满足而不执行。

### 排查
主线里有 `drivers/platform/x86/lenovo-yogabook.c`（Hans de Goede, 2023），
它同时支持 YB1-X90（platform）和 **YB1-X91（WMI）**，注册 `ybwmi::kbd_backlight`。

编出来加载后发现它**没有 probe**：WMI 部分要求同时找到

```
GDIX1001  触摸键盘   ✓ 存在
WCOM0019  Wacom 数位板 ✗ 这台 X91F 没有
```

找不到 `WCOM0019` → `-ENODEV` → 整个驱动放弃，LED 也就不存在。

### 背光的真实控制方式
不是 PWM（PWM 那套是 X90 安卓版的 `pwm_soc_lpss_2` + GPIO 52），而是调 ACPI 方法：

```
GDIX1001.KBLC(255 - level)     # level 越大越亮（值反着传）
```

### 解决
自写最小模块 `modules/ybkbdbl.c`：只找 `GDIX1001`，注册 `ybwmi::kbd_backlight` LED，
写 brightness 时调 `KBLC(max - value)`。

```bash
echo 255 | sudo tee /sys/class/leds/ybwmi::kbd_backlight/brightness
```

重启后由 `halo-keyboard-backlight.service` 恢复到 20%（51/255）。

---

## 3. 笔形按钮（切换键盘 / 数位板）

### 现象
右上角有个笔形按钮，按下键盘背光灭、再按亮。

### 验证（四层全部为零）

| 层面 | 方法 | 结果 |
|---|---|---|
| 输入设备（16 个） | 自写 evdev 读取器 | 无事件 |
| Goodix HID 原始事件 | 抓 ABS/KEY 全类型，含 `PRESSURE`、`BTN_TOOL_PEN` | 两种模式数据**完全一致** |
| ACPI | `acpi_listen` 90 秒 | 无事件 |
| WMI | `/sys/class/leds/ybwmi::kbd_backlight` | 驱动缺失时不存在 |

### 结论
按键由 EC/面板硬件处理，OS 不可见。

而且实测：切到数位板模式后，**键盘触摸面直接停止上报**（GIMP 里画布无反应、指针不动），
所以不会出现"数位板模式下乱触发按键"的问题——这一点不需要软件处理。

（Wacom 数位板层只有 YB1-**X91L** 有，`056A:0169`；X91F 没有。）

---

## 4. 震动马达（未完成）

I2C 上有两个马达：

```
/sys/bus/i2c/devices/i2c-DRV2604:00
/sys/bus/i2c/devices/i2c-DRV2604:01
```

`drv260x` 模块（依赖 `ff-memless`）能编能加载，但：

- 驱动 id_table 是小写 `drv2604`，ACPI 给的名字是大写 `DRV2604`
- 手工加 `{ "DRV2604", 0 }` 表项重新编译后**仍未绑定**
- `halo-keyboard-handler` 日志仍报 `Cannot find left/right motor`

下一步要看 `/sys/bus/i2c/devices/i2c-DRV2604:00/name`、`modalias`，
或用 `new_device` 重建客户端。

---

## 5. 休眠

Cherry Trail 的 S3 恢复在 Linux 上不可用：唤醒后无桌面、网络掉线、SSH 断。

```
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

配套 logind 配置（`/etc/systemd/logind.conf.d/99-nosleep.conf`）：

```ini
[Login]
IdleAction=ignore
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
```
