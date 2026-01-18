from __future__ import annotations

import argparse
import re
import sys
import time

from rich.console import Console

try:
    from .connect import _adb, _describe_adb_env, _run, _trim_one_line, _wait_for_boot_completed, _wait_for_device
except ImportError:  # 支持 `python src/u2runner/story7_shortcuts_panel.py` 直接运行
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

_SEL_TOGGLE = {"description": "u2_remote_shortcuts_toggle"}
_SEL_PANEL = {"description": "u2_remote_shortcuts_panel"}
_SEL_BTN = {"description": "u2_remote_shortcut_button"}


def _has_semantics(d, label: str) -> bool:
    xml = d.dump_hierarchy(compressed=False)
    return f'content-desc="{label}"' in xml or f'content-desc="{label}\\n' in xml


def _tap_ok_in_dialog(d) -> None:
    candidates = [
        {"text": "OK"},
        {"text": "确定"},
        {"text": "好"},
        {"description": "OK"},
        {"description": "确定"},
    ]
    for sel in candidates:
        obj = d(**sel)
        if obj.exists:
            obj.click()
            return
    raise AssertionError("未找到 OK/确定 按钮（快捷键新增对话框）")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Story 7：验证远控会话页组合快捷键面板（UIAutomator2）")
    parser.add_argument("--serial", required=True, help="adb 设备序列号（如 emulator-5554）")
    parser.add_argument("--timeout", type=int, default=240, help="等待设备/开机完成超时秒数")
    parser.add_argument("-v", "--verbose", action="count", default=0, help="输出更详细的过程（可重复 -vv）")
    parser.add_argument("--poll-interval", type=float, default=1.0, help="轮询间隔秒数（默认 1.0）")
    parser.add_argument("--adb-timeout", type=int, default=10, help="单次 adb 命令超时秒数（默认 10）")
    parser.add_argument(
        "--launch",
        action="store_true",
        help="可选：自动启动 App（注意：脚本无法自动建立远控连接，需你手动进入远控会话页）",
    )
    parser.add_argument("--launch-wait", type=float, default=3.0, help="启动后等待秒数（默认 3.0）")
    parser.add_argument(
        "--restart",
        action="store_true",
        help="可选：尝试重启 App 校验“新增快捷键”持久化（可能需要你手动重新进入远控会话页）",
    )
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

    console.print("3) uiautomator2 连接…")
    import uiautomator2 as u2

    d = u2.connect(args.serial)
    if args.launch:
        console.print("4) 启动 App…")
        d.app_stop(_PKG)
        d.app_start(_PKG)
        time.sleep(args.launch_wait)

    console.print("5) 等待快捷键面板按钮出现（需远控会话页）…")
    if not d(**_SEL_TOGGLE).wait(timeout=20.0):
        raise SystemExit("未找到 u2_remote_shortcuts_toggle：请进入 Android 远控会话页，并确保悬浮工具按钮已显示。")

    console.print("6) 点击切换快捷键面板：应出现 u2_remote_shortcuts_panel…")
    d(**_SEL_TOGGLE).click()
    time.sleep(0.6)
    if not d(**_SEL_PANEL).exists and not _has_semantics(d, "u2_remote_shortcuts_panel"):
        raise AssertionError("未找到快捷键面板（u2_remote_shortcuts_panel）")

    console.print("7) 长按快捷键按钮：新增一个快捷键（打开对话框 -> OK）…")
    d(**_SEL_TOGGLE).long_click(duration=0.7)
    time.sleep(0.8)
    if not d(description="u2_remote_add_shortcut_name").wait(timeout=6.0):
        raise AssertionError("未出现新增快捷键对话框（u2_remote_add_shortcut_name）")
    d(description="u2_remote_add_shortcut_name").set_text("U2 Shortcut")
    _tap_ok_in_dialog(d)
    time.sleep(0.8)

    console.print("8) 面板中应出现至少一个 u2_remote_shortcut_button…")
    if not d(**_SEL_BTN).exists:
        # 兜底：从 XML 中判断
        if not _has_semantics(d, "u2_remote_shortcut_button"):
            raise AssertionError("未找到快捷键按钮（u2_remote_shortcut_button）")

    if args.restart:
        console.print("9) 重启 App（可能需要你手动再次进入远控会话页）…")
        d.app_stop(_PKG)
        time.sleep(0.8)
        d.app_start(_PKG)
        time.sleep(args.launch_wait)

        console.print("10) 等待 u2_remote_shortcuts_toggle 重新出现…")
        if not d(**_SEL_TOGGLE).wait(timeout=30.0):
            raise SystemExit("重启后未找到 u2_remote_shortcuts_toggle：请手动进入远控会话页后重试。")

        d(**_SEL_TOGGLE).click()
        time.sleep(0.8)
        if not d(**_SEL_BTN).exists and not _has_semantics(d, "u2_remote_shortcut_button"):
            raise AssertionError("重启后未找到快捷键按钮，疑似持久化失败")

    console.print("[green]OK[/green]：快捷键面板显示/隐藏 + 新增（及可选持久化）通过")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

