"""draw kitty tab"""
# pyright: reportMissingImports=false
# pylint: disable=E0401,C0116,C0103,W0603,R0913

import datetime
import re
import subprocess
import sys
import time
from pathlib import Path

from kitty.fast_data_types import Screen, get_options
from kitty.tab_bar import (
    DrawData,
    ExtraData,
    TabBarData,
    as_rgb,
    draw_tab_with_powerline,
    draw_title,
)
from kitty.utils import color_as_int

opts = get_options()

ICON: str = " LEI "
ICON_LENGTH: int = len(ICON)
ICON_FG: int = as_rgb(color_as_int(opts.color16))
ICON_BG: int = as_rgb(color_as_int(opts.color8))

CLOCK_FG = 1
CLOCK_BG = as_rgb(color_as_int(opts.color11))
BATTERY_FG = 1
BATTERY_BG = as_rgb(color_as_int(opts.color12))
DATE_FG = 3
DATE_BG = as_rgb(color_as_int(opts.color16))

BATTERY_CACHE_TTL = 30.0
BATTERY_SYSFS = Path("/sys/class/power_supply")
BATTERY_REGEX = re.compile(r"(\d+)%")
_battery_cache_text: str | None = None
_battery_cache_at = 0.0


def _read_linux_battery_text() -> str | None:
    if not BATTERY_SYSFS.exists():
        return None

    levels: list[int] = []
    for power_supply in BATTERY_SYSFS.iterdir():
        try:
            power_type = (power_supply / "type").read_text(encoding="utf-8").strip()
        except OSError:
            continue
        if power_type != "Battery":
            continue
        try:
            capacity = int(
                (power_supply / "capacity").read_text(encoding="utf-8").strip()
            )
        except (OSError, ValueError):
            continue
        levels.append(capacity)

    if not levels:
        return None

    return f" {round(sum(levels) / len(levels))}% "


def _read_macos_battery_text() -> str | None:
    try:
        result = subprocess.run(
            ["pmset", "-g", "batt"],
            check=False,
            capture_output=True,
            text=True,
            timeout=1,
        )
    except (OSError, subprocess.SubprocessError):
        return None

    if result.returncode != 0:
        return None

    match = BATTERY_REGEX.search(result.stdout)
    if not match:
        return None

    return f" {match.group(1)}% "


def _get_battery_text() -> str | None:
    global _battery_cache_at, _battery_cache_text

    now = time.monotonic()
    if now - _battery_cache_at < BATTERY_CACHE_TTL:
        return _battery_cache_text

    if sys.platform == "darwin":
        _battery_cache_text = _read_macos_battery_text()
    else:
        _battery_cache_text = _read_linux_battery_text()
    _battery_cache_at = now
    return _battery_cache_text


def _draw_icon(screen: Screen, index: int) -> int:
    if index != 1:
        return screen.cursor.x

    fg, bg, bold, italic = (
        screen.cursor.fg,
        screen.cursor.bg,
        screen.cursor.bold,
        screen.cursor.italic,
    )
    # restore color style
    screen.cursor.fg, screen.cursor.bg, screen.cursor.bold, screen.cursor.italic = (
        fg,
        bg,
        bold,
        italic,
    )
    return screen.cursor.x


def _draw_left_status(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_title_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
    use_kitty_render_function: bool = False,
) -> int:
    if use_kitty_render_function:
        # Use `kitty` function render tab
        end = draw_tab_with_powerline(
            draw_data, screen, tab, before, max_title_length, index, is_last, extra_data
        )
        return end

    if draw_data.leading_spaces:
        screen.draw(" " * draw_data.leading_spaces)

    # draw tab title
    draw_title(draw_data, screen, tab, index)

    trailing_spaces = min(max_title_length - 1, draw_data.trailing_spaces)
    max_title_length -= trailing_spaces
    extra = screen.cursor.x - before - max_title_length
    if extra > 0:
        screen.cursor.x -= extra + 1
        # Don't change `ICON`
        screen.cursor.x = max(screen.cursor.x, ICON_LENGTH)
        screen.draw("…")
    if trailing_spaces:
        screen.draw(" " * trailing_spaces)

    screen.cursor.bold = screen.cursor.italic = False
    screen.cursor.fg = 0
    if not is_last:
        screen.cursor.bg = as_rgb(color_as_int(draw_data.inactive_bg))
        screen.draw(draw_data.sep)
    screen.cursor.bg = 0
    return screen.cursor.x


def _draw_right_status(screen: Screen, is_last: bool) -> int:
    if not is_last:
        return screen.cursor.x

    cells = [
        (CLOCK_FG, CLOCK_BG, datetime.datetime.now().strftime(" %H:%M ")),
    ]
    battery_text = _get_battery_text()
    if battery_text is not None:
        cells.append((BATTERY_FG, BATTERY_BG, battery_text))
    cells.append((DATE_FG, DATE_BG, datetime.datetime.now().strftime(" %Y/%m/%d ")))

    right_status_length = 0
    for _, _, cell in cells:
        right_status_length += len(cell)

    draw_spaces = screen.columns - screen.cursor.x - right_status_length
    if draw_spaces > 0:
        screen.draw(" " * draw_spaces)

    for fg, bg, cell in cells:
        screen.cursor.fg = fg
        screen.cursor.bg = bg
        screen.draw(cell)
    screen.cursor.fg = 0
    screen.cursor.bg = 0

    screen.cursor.x = max(screen.cursor.x, screen.columns - right_status_length)
    return screen.cursor.x


def draw_tab(
    draw_data: DrawData,
    screen: Screen,
    tab: TabBarData,
    before: int,
    max_title_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    _draw_icon(screen, index)
    # Set cursor to where `left_status` ends, instead `right_status`,
    # to enable `open new tab` feature
    end = _draw_left_status(
        draw_data,
        screen,
        tab,
        before,
        max_title_length,
        index,
        is_last,
        extra_data,
        use_kitty_render_function=False,
    )
    _draw_right_status(
        screen,
        is_last,
    )
    return end
