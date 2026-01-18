from __future__ import annotations

import argparse
import sys
import time

from rich.console import Console

try:
    from .connect import _adb, _describe_adb_env, _run, _trim_one_line, _wait_for_boot_completed, _wait_for_device
except ImportError:  # 支持 `python src/u2runner/story11_floating_tool_dock.py` 直接运行
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


def _center(bounds: dict) -> tuple[int, int]:
    # uiautomator2: {"left":..,"top":..,"right":..,"bottom":..}
    return int((bounds["left"] + bounds["right"]) / 2), int((bounds["top"] + bounds["bottom"]) / 2)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Story 11：验证悬浮工具（可拖动+持久化）（UIAutomator2）")
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
        help="可选：重启 App 校验坐标持久化（可能需要你手动重新进入远控会话页）",
    )
    parser.add_argument("--tolerance", type=int, default=8, help="坐标允许误差像素（默认 8）")
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

    console.print("5) 等待远控会话页的悬浮按钮出现…")
    if not d(**_SEL_KEYBOARD_BTN).wait(timeout=20.0):
        raise SystemExit("未找到 u2_remote_keyboard_button：请进入 Android 远控会话页，并确保悬浮工具按钮已显示。")

    b0 = d(**_SEL_KEYBOARD_BTN).bounds()
    x0, y0 = _center(b0)
    console.print(f"当前中心坐标: ({x0}, {y0})")

    console.print("6) 拖动悬浮工具到新位置…")
    w, h = d.window_size()
    x1 = int(min(w - 20, x0 + w * 0.22))
    y1 = int(min(h - 20, y0 + h * 0.22))
    d.drag(x0, y0, x1, y1, duration=0.2)
    time.sleep(0.8)

    b1 = d(**_SEL_KEYBOARD_BTN).bounds()
    x_new, y_new = _center(b1)
    console.print(f"拖动后中心坐标: ({x_new}, {y_new})")
    if abs(x_new - x0) < 4 and abs(y_new - y0) < 4:
        raise AssertionError("拖动后坐标变化过小，疑似未生效（请确认悬浮工具可拖动）")

    if args.restart:
        console.print("7) 重启 App 校验坐标持久化（可能需要你手动重新进入远控会话页）…")
        d.app_stop(_PKG)
        time.sleep(0.8)
        d.app_start(_PKG)
        time.sleep(args.launch_wait)

        if not d(**_SEL_KEYBOARD_BTN).wait(timeout=30.0):
            raise SystemExit("重启后未找到 u2_remote_keyboard_button：请手动进入远控会话页后重试。")

        b2 = d(**_SEL_KEYBOARD_BTN).bounds()
        x2, y2 = _center(b2)
        console.print(f"重启后中心坐标: ({x2}, {y2})")
        if abs(x2 - x_new) > args.tolerance or abs(y2 - y_new) > args.tolerance:
            raise AssertionError(f"坐标未持久化：期望接近 ({x_new}, {y_new})，实际 ({x2}, {y2})，tolerance={args.tolerance}")

    console.print("[green]OK[/green]：悬浮工具拖动（及可选持久化）通过")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

