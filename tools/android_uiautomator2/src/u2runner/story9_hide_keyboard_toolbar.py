from __future__ import annotations

import argparse
import sys
import time

from rich.console import Console

try:
    from .connect import _adb, _describe_adb_env, _run, _trim_one_line, _wait_for_boot_completed, _wait_for_device
except ImportError:  # 支持 `python src/u2runner/story9_hide_keyboard_toolbar.py` 直接运行
    import pathlib

    _SRC = pathlib.Path(__file__).resolve().parents[1]
    if str(_SRC) not in sys.path:
        sys.path.insert(0, str(_SRC))
    from u2runner.connect import (  # type: ignore[no-redef]
        _adb,
        _describe_adb_env,
        _run,
        _trim_one_line,
        _wait_for_boot_completed,
        _wait_for_device,
    )


_PKG = "com.carriez.flutter_hbb"

_SEL_SETTINGS_TAB = {"descriptionContains": "Settings"}
_SEL_SETTING = {"description": "u2_settings_hide_keyboard_tools_on_ime"}

_SEL_KEYBOARD_BTN = {"description": "u2_remote_keyboard_button"}


def _has_semantics(d, label: str) -> bool:
    xml = d.dump_hierarchy(compressed=False)
    return f'content-desc="{label}"' in xml or f'content-desc="{label}\\n' in xml


def _tap_settings_tab(console: Console, d) -> None:
    if d(**_SEL_SETTINGS_TAB).exists:
        d(**_SEL_SETTINGS_TAB).click()
        time.sleep(0.8)
        return
    # 兜底：右下角点击
    w, h = d.window_size()
    console.print("[yellow]未能直接定位 Settings 标签，尝试坐标点击（右下角）[/yellow]")
    d.click(int(w * 0.88), int(h * 0.88))
    time.sleep(0.8)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Story 9：验证“隐藏键盘工具条黑色区域”设置（UIAutomator2）")
    parser.add_argument("--serial", required=True, help="adb 设备序列号（如 emulator-5554）")
    parser.add_argument("--timeout", type=int, default=240, help="等待设备/开机完成超时秒数")
    parser.add_argument("-v", "--verbose", action="count", default=0, help="输出更详细的过程（可重复 -vv）")
    parser.add_argument("--poll-interval", type=float, default=1.0, help="轮询间隔秒数（默认 1.0）")
    parser.add_argument("--adb-timeout", type=int, default=10, help="单次 adb 命令超时秒数（默认 10）")
    parser.add_argument("--launch-wait", type=float, default=3.0, help="启动后等待秒数（默认 3.0）")
    args = parser.parse_args(argv)

    console = Console()
    if args.verbose:
        console.print(f"[dim]{_describe_adb_env()}[/dim]")

    console.print("0) 检查 adb 可用性…")
    ver = _run([_adb(), "version"], timeout_s=args.adb_timeout)
    if ver.returncode != 0:
        console.print(f"[red]adb 不可用[/red]: {_trim_one_line(ver.stdout) or f'returncode={ver.returncode}'}")
        return 2

    console.print("1) 等待设备上线…")
    _wait_for_device(
        console,
        args.serial,
        args.timeout,
        poll_interval_s=args.poll_interval,
        cmd_timeout_s=args.adb_timeout,
        verbose=args.verbose,
    )

    console.print("2) 等待系统开机完成…")
    _wait_for_boot_completed(
        console,
        args.serial,
        args.timeout,
        poll_interval_s=args.poll_interval,
        cmd_timeout_s=args.adb_timeout,
        verbose=args.verbose,
    )

    console.print("3) uiautomator2 连接并启动 App…")
    import uiautomator2 as u2

    d = u2.connect(args.serial)
    d.app_stop(_PKG)
    d.app_start(_PKG)
    time.sleep(args.launch_wait)

    console.print("4) 进入 Settings 并开启隐藏黑条设置…")
    _tap_settings_tab(console, d)
    time.sleep(0.8)

    found = False
    for _ in range(10):
        if d(**_SEL_SETTING).exists or _has_semantics(d, "u2_settings_hide_keyboard_tools_on_ime"):
            found = True
            break
        d.swipe_ext("up", scale=0.65)
        time.sleep(0.5)
    if not found:
        raise AssertionError("未找到设置项语义标识：u2_settings_hide_keyboard_tools_on_ime")

    # 点击 tile（会切换开关）
    d(**_SEL_SETTING).click()
    time.sleep(0.8)

    console.print("5) 进入远控会话页，打开软键盘，并断言黑色工具条不存在…")
    console.print("[yellow]提示[/yellow]: 脚本无法自动建立远控连接。请你现在手动进入 Android 远控会话页（RemotePage）。")
    if not d(**_SEL_KEYBOARD_BTN).wait(timeout=60.0):
        raise SystemExit("未找到 u2_remote_keyboard_button：请进入远控会话页后重试。")

    d(**_SEL_KEYBOARD_BTN).click()
    time.sleep(1.2)

    if d(description="u2_remote_key_help_tools").exists or _has_semantics(d, "u2_remote_key_help_tools"):
        raise AssertionError("发现黑色键盘工具条（u2_remote_key_help_tools），与设置“隐藏”不符")

    console.print("[green]OK[/green]：设置开启后，呼出输入法不显示黑色工具条")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

