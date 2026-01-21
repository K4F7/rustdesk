from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time

from rich.console import Console

try:
    from .connect import (
        _adb,
        _adb_logcat_clear,
        _adb_logcat_dump_u2e2e_lines,
        _describe_adb_env,
        _run,
        _trim_one_line,
        _wait_for_boot_completed,
        _wait_for_device,
    )
except ImportError:  # 支持 `python src/u2runner/story234_gesture_state_machine.py` 直接运行
    import pathlib

    _SRC = pathlib.Path(__file__).resolve().parents[1]
    if str(_SRC) not in sys.path:
        sys.path.insert(0, str(_SRC))
    from u2runner.connect import (  # type: ignore[no-redef]
        _adb,
        _adb_logcat_clear,
        _adb_logcat_dump_u2e2e_lines,
        _describe_adb_env,
        _run,
        _trim_one_line,
        _wait_for_boot_completed,
        _wait_for_device,
    )


_PKG = "com.carriez.flutter_hbb"


def _get_log_lines(serial: str, *, adb_timeout_s: int) -> list[str]:
    return _adb_logcat_dump_u2e2e_lines(serial, timeout_s=adb_timeout_s)


def _find_events(lines: list[str], event_type: str) -> list[tuple[int, str, dict]]:
    out: list[tuple[int, str, dict]] = []
    for ln in lines:
        # <ts_ms> <type> <json?>
        m = re.match(r"^(\d+)\s+(\S+)(?:\s+(.+))?$", ln)
        if not m:
            continue
        ts = int(m.group(1))
        typ = m.group(2)
        if typ != event_type:
            continue
        data_s = (m.group(3) or "").strip()
        data = {}
        if data_s:
            try:
                data = json.loads(data_s)
            except Exception:  # noqa: BLE001
                data = {"_raw": data_s}
        out.append((ts, typ, data))
    return out


def _assert_contains_drag_phases(lines: list[str], drag_type: str) -> None:
    events = _find_events(lines, drag_type)
    phases = {str(e[2].get("phase", "")) for e in events}
    missing = [p for p in ("down", "move", "up") if p not in phases]
    if missing:
        raise AssertionError(
            f"未满足 {drag_type} 的 phase 序列（缺少 {missing}）。当前事件: {events[-8:]}"
        )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Story 2/3/4：验证单指手势互斥（左拖动/右键长按/右键拖动，UIAutomator2）"
    )
    parser.add_argument("--serial", required=True, help="adb 设备序列号（如 emulator-5554）")
    parser.add_argument("--timeout", type=int, default=240, help="等待设备/开机完成超时秒数")
    parser.add_argument("-v", "--verbose", action="count", default=0, help="输出更详细的过程（可重复 -vv）")
    parser.add_argument("--poll-interval", type=float, default=1.0, help="轮询间隔秒数（默认 1.0）")
    parser.add_argument("--adb-timeout", type=int, default=10, help="单次 adb 命令超时秒数（默认 10）")
    parser.add_argument("--overlay-wait", type=float, default=15.0, help="等待日志刷入秒数（默认 15）")
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

    console.print("5) 清空 logcat（只抓取本次事件）…")
    _adb_logcat_clear(args.serial, timeout_s=args.adb_timeout)
    time.sleep(0.2)

    w, h = d.window_size()
    cx, cy = int(w * 0.5), int(h * 0.45)

    console.print("6) Story 3：左键拖动（pan）…")
    # 用 swipe 触发一段明确位移
    d.swipe(cx, cy, cx + int(w * 0.15), cy + int(h * 0.05), duration=0.12)
    time.sleep(0.5)
    lines = _get_log_lines(args.serial, adb_timeout_s=args.adb_timeout)
    _assert_contains_drag_phases(lines, "left_drag")

    _adb_logcat_clear(args.serial, timeout_s=args.adb_timeout)
    time.sleep(0.2)

    console.print("7) Story 2：右键长按（long press）…")
    d.long_click(cx, cy, duration=0.8)
    time.sleep(0.5)
    lines = _get_log_lines(args.serial, adb_timeout_s=args.adb_timeout)
    if not _find_events(lines, "right_click"):
        raise AssertionError(
            "未找到 right_click 事件：请确认已在 Debug 构建打开 Settings -> Android E2E Mode，并进入远控会话页。"
            f" 当前日志: {lines[-12:]}"
        )

    _adb_logcat_clear(args.serial, timeout_s=args.adb_timeout)
    time.sleep(0.2)

    console.print("8) Story 4：右键拖动（long press -> move）…")
    # uiautomator2 touch 链式：按下 -> 等待长按判定 -> 移动 -> 抬起
    d.touch.down(cx, cy)
    time.sleep(0.7)
    d.touch.move(cx + int(w * 0.12), cy + int(h * 0.03))
    time.sleep(0.12)
    d.touch.move(cx + int(w * 0.18), cy + int(h * 0.05))
    time.sleep(0.12)
    d.touch.up(cx + int(w * 0.18), cy + int(h * 0.05))
    time.sleep(0.6)
    lines = _get_log_lines(args.serial, adb_timeout_s=args.adb_timeout)
    _assert_contains_drag_phases(lines, "right_drag")

    console.print("[green]OK[/green]：Story 2/3/4 手势日志断言通过（如远端行为异常，请重点回归阈值与互斥逻辑）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
