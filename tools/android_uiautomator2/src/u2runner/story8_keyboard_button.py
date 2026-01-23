from __future__ import annotations

import argparse
import re
import sys
import time

from rich.console import Console

try:
    from .connect import _adb, _describe_adb_env, _run, _trim_one_line, _wait_for_boot_completed, _wait_for_device
except ImportError:  # 支持 `python src/u2runner/story8_keyboard_button.py` 直接运行
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

_SEL_KEYBOARD_BTN = {"description": "u2_remote_keyboard_button"}


def _get_semantics_value(d, label: str) -> str:
    xml = d.dump_hierarchy(compressed=False)
    m = re.search(rf'content-desc="{re.escape(label)}(?:\\n([^"]+))?"', xml)
    if not m:
        return ""
    return (m.group(1) or "").strip()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Story 8：验证远控会话页“呼出安卓输入法”按钮（UIAutomator2）")
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

    console.print("5) 等待远控会话页的键盘按钮出现…")
    if not d(**_SEL_KEYBOARD_BTN).wait(timeout=20.0):
        raise SystemExit("未找到 u2_remote_keyboard_button：请进入 Android 远控会话页，并确保悬浮工具按钮已显示。")

    console.print("6) 点击键盘按钮，等待 u2_remote_keyboard_state=visible…")
    d(**_SEL_KEYBOARD_BTN).click()
    deadline = time.time() + 12.0
    while time.time() < deadline:
        if _get_semantics_value(d, "u2_remote_keyboard_state") == "visible":
            break
        time.sleep(0.2)
    else:
        raise AssertionError("键盘状态未变为 visible（请确认开启 Android E2E Mode，且键盘按钮可用）")

    console.print("7) 再次点击键盘按钮，等待 u2_remote_keyboard_state=hidden…")
    d(**_SEL_KEYBOARD_BTN).click()
    deadline = time.time() + 12.0
    while time.time() < deadline:
        if _get_semantics_value(d, "u2_remote_keyboard_state") == "hidden":
            break
        time.sleep(0.2)
    else:
        raise AssertionError("键盘状态未变为 hidden")

    console.print("[green]OK[/green]：键盘按钮开关与状态标识通过")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

