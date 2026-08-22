#!/usr/bin/env python3
"""Deterministic Everforest calendar wallpaper renderer and coordinator."""

from __future__ import annotations

import argparse
import calendar
import datetime as dt
import fcntl
import hashlib
import html
import json
import math
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time
from typing import Any


SCHEMA_VERSION = 1
RENDERER_VERSION = 1
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
HEX_COLOR = re.compile(r"^#[0-9A-Fa-f]{6}$")
SLOT_FILE = re.compile(r"^[a-zA-Z0-9_.-]+--[0-9a-f]{8}-[ab]\.png$")
TEMP_FILE = re.compile(r"^\.(?:render|state|slot)-[a-zA-Z0-9_.-]+\.tmp$")


class WallpaperError(RuntimeError):
    """A recoverable wallpaper operation failure."""


def log(message: str) -> None:
    print(f"calendar-wallpaper: {message}", file=sys.stderr)


def local_date(value: str | None = None) -> dt.date:
    if value:
        try:
            return dt.date.fromisoformat(value)
        except ValueError as error:
            raise WallpaperError(f"invalid ISO date: {value}") from error
    return dt.datetime.now().astimezone().date()


def load_config(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise WallpaperError(f"cannot load config {path}: {error}") from error

    required = {"palette", "months", "fonts", "rsvg_convert", "mmsg", "noctalia"}
    missing = required.difference(data)
    if missing:
        raise WallpaperError(f"config is missing: {', '.join(sorted(missing))}")
    for name, color in data["palette"].items():
        if not isinstance(color, str) or not HEX_COLOR.fullmatch(color):
            raise WallpaperError(f"palette.{name} is not a six-digit RGB color")
    for month in range(1, 13):
        accents = data["months"].get(str(month))
        if not isinstance(accents, dict):
            raise WallpaperError(f"months.{month} is missing")
        for role in ("primary", "secondary", "marker"):
            color_name = accents.get(role)
            if color_name not in data["palette"]:
                raise WallpaperError(f"months.{month}.{role} references an unknown color")
    return data


def calendar_grid(day: dt.date, first_weekday: int = calendar.MONDAY) -> list[list[int]]:
    weeks = calendar.Calendar(firstweekday=first_weekday).monthdayscalendar(day.year, day.month)
    return weeks + [[0] * 7 for _ in range(6 - len(weeks))]


def layout_mode(width: int, height: int) -> str:
    ratio = width / height
    if ratio >= 1.55:
        return "wide"
    if ratio >= 1.25:
        return "medium"
    return "tall"


def _svg_text(
    value: str,
    x: float,
    y: float,
    size: float,
    *,
    fill: str,
    family: str,
    weight: int | str = 400,
    anchor: str = "start",
    spacing: float = 0,
    opacity: float = 1,
    transform: str | None = None,
    extra: str = "",
) -> str:
    attrs = (
        f'x="{x:.2f}" y="{y:.2f}" font-size="{size:.2f}" fill="{fill}" '
        f'font-family="{html.escape(family, quote=True)}" font-weight="{weight}" '
        f'text-anchor="{anchor}" letter-spacing="{spacing:.2f}" opacity="{opacity:.3f}"'
    )
    if transform:
        attrs += f' transform="{html.escape(transform, quote=True)}"'
    return f"<text {attrs} {extra}>{html.escape(value)}</text>"


def render_svg(day: dt.date, width: int, height: int, config: dict[str, Any]) -> str:
    if width < 640 or height < 480 or width > 16384 or height > 16384:
        raise WallpaperError("dimensions must be between 640x480 and 16384x16384")

    palette = config["palette"]
    accents = config["months"][str(day.month)]
    primary = palette[accents["primary"]]
    secondary = palette[accents["secondary"]]
    marker = palette[accents["marker"]]
    foreground = palette["foreground"]
    primary_font = config["fonts"]["primary"]
    calendar_font = config["fonts"]["calendar"]
    mode = layout_mode(width, height)
    short = min(width, height)
    safe = max(height * float(config.get("top_safe_area_ratio", 0.055)), 52)
    month_name = day.strftime("%B").upper()
    if config.get("week_starts_on", "monday") == "sunday":
        first_weekday = calendar.SUNDAY
        headings = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    else:
        first_weekday = calendar.MONDAY
        headings = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    grid = calendar_grid(day, first_weekday)

    if mode == "wide":
        numeral_x, numeral_y, numeral_size = width * 0.535, height * 0.940, height * 0.82
        calendar_x, calendar_y, calendar_w = width * 0.038, height * 0.615, width * 0.285
        month_x, month_y = width * 0.057, height * 0.430
    elif mode == "medium":
        numeral_x, numeral_y, numeral_size = width * 0.445, height * 0.930, height * 0.66
        calendar_x, calendar_y, calendar_w = width * 0.045, height * 0.615, width * 0.345
        month_x, month_y = width * 0.066, height * 0.450
    else:
        numeral_x, numeral_y, numeral_size = width * 0.285, height * 0.955, width * 0.63
        calendar_x, calendar_y, calendar_w = width * 0.105, height * 0.390, width * 0.790
        month_x, month_y = width * 0.075, height * 0.310

    cell_w = calendar_w / 7
    cell_h = short * (0.050 if mode != "tall" else 0.044)
    cal_size = short * (0.018 if mode != "tall" else 0.025)
    heading_size = cal_size * 0.62
    year_x = width * (0.038 if mode == "wide" else 0.045 if mode == "medium" else 0.105)
    year_y = safe + short * 0.045
    rule_y = safe + short * 0.082
    rule_end = width * (0.965 if mode != "tall" else 0.90)

    arc_radius = short * (0.205 if mode != "tall" else 0.245)
    arc_cx = calendar_x + calendar_w * (0.92 if mode != "tall" else 0.82)
    arc_cy = calendar_y + cell_h * 3.10
    arc_start = math.radians(-60)
    arc_total = math.radians(155)
    arc_end = arc_start + arc_total

    def point(angle: float) -> tuple[float, float]:
        return arc_cx + arc_radius * math.cos(angle), arc_cy + arc_radius * math.sin(angle)

    start_x, start_y = point(arc_start)
    end_x, end_y = point(arc_end)
    large_arc = 1 if arc_total > math.pi else 0
    arc_path = (
        f"M {start_x:.2f} {start_y:.2f} "
        f"A {arc_radius:.2f} {arc_radius:.2f} 0 {large_arc} 1 {end_x:.2f} {end_y:.2f}"
    )

    metadata = html.escape(
        json.dumps(
            {
                "date": day.isoformat(),
                "layout": mode,
                "renderer_version": RENDERER_VERSION,
                "primary_font": primary_font,
                "calendar_font": calendar_font,
            },
            sort_keys=True,
        )
    )
    texture_opacity = float(config.get("texture_opacity", 0.035))
    parts = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        f"<metadata>{metadata}</metadata>",
        "<defs>",
        '<linearGradient id="background" x1="0" y1="0" x2="1" y2="1">',
        f'<stop offset="0" stop-color="{palette["background_dim"]}"/>',
        f'<stop offset="0.48" stop-color="{palette["background_0"]}"/>',
        f'<stop offset="1" stop-color="{palette["background_2"]}"/>',
        "</linearGradient>",
        '<radialGradient id="glow" cx="76%" cy="72%" r="82%">',
        f'<stop offset="0" stop-color="{palette["background_3"]}" stop-opacity="0.18"/>',
        f'<stop offset="1" stop-color="{palette["background_3"]}" stop-opacity="0"/>',
        "</radialGradient>",
        '<pattern id="grain" width="47" height="47" patternUnits="userSpaceOnUse">',
        f'<circle cx="4" cy="8" r="0.8" fill="{foreground}" opacity="0.35"/>',
        f'<circle cx="29" cy="19" r="0.55" fill="{foreground}" opacity="0.24"/>',
        f'<circle cx="14" cy="39" r="0.65" fill="{palette["background_dim"]}" opacity="0.55"/>',
        f'<circle cx="43" cy="34" r="0.45" fill="{foreground}" opacity="0.20"/>',
        "</pattern>",
        '<filter id="paper-noise" x="0" y="0" width="100%" height="100%">',
        '<feTurbulence type="fractalNoise" baseFrequency="0.10" numOctaves="4" seed="21" stitchTiles="stitch"/>',
        '<feColorMatrix type="saturate" values="0"/>',
        '<feComponentTransfer><feFuncA type="table" tableValues="0 0.48"/></feComponentTransfer>',
        "</filter>",
        '<filter id="dither-noise" x="0" y="0" width="100%" height="100%">',
        '<feTurbulence type="fractalNoise" baseFrequency="0.24" numOctaves="3" seed="73" stitchTiles="stitch"/>',
        '<feColorMatrix type="saturate" values="0"/>',
        '<feComponentTransfer><feFuncA type="table" tableValues="0 0.55"/></feComponentTransfer>',
        "</filter>",
        "</defs>",
        f'<rect width="{width}" height="{height}" fill="url(#background)"/>',
        f'<rect width="{width}" height="{height}" fill="url(#glow)"/>',
        f'<rect width="{width}" height="{height}" fill="url(#grain)" opacity="{texture_opacity:.3f}"/>',
        f'<rect width="{width}" height="{height}" fill="{foreground}" filter="url(#paper-noise)" opacity="{min(0.30, texture_opacity * 2.4):.3f}" style="mix-blend-mode:soft-light"/>',
        f'<rect width="{width}" height="{height}" fill="{foreground}" filter="url(#dither-noise)" opacity="{min(0.20, texture_opacity * 1.6):.3f}"/>',
        f'<line x1="{year_x:.2f}" y1="{rule_y:.2f}" x2="{rule_end:.2f}" y2="{rule_y:.2f}" stroke="{foreground}" stroke-opacity="0.30" stroke-width="{max(1, short * 0.001):.2f}"/>',
        _svg_text(str(day.year), year_x, year_y, short * 0.022, fill=foreground, family=primary_font, weight=500, spacing=short * 0.004),
        _svg_text(
            str(day.day), numeral_x, numeral_y, numeral_size,
            fill=foreground, family=primary_font, weight=300, opacity=0.94,
            spacing=short * (-0.034 if mode != "tall" else -0.012),
            extra='style="font-variant-numeric: lining-nums"',
        ),
        _svg_text(
            month_name, month_x, month_y, short * (0.044 if mode != "tall" else 0.027),
            fill=foreground, family=primary_font, weight=400, spacing=short * 0.010,
            transform=f"rotate(-90 {month_x:.2f} {month_y:.2f})",
        ),
        f'<path d="{arc_path}" fill="none" stroke="{primary}" stroke-width="{max(2, short * 0.0022):.2f}" stroke-linecap="round" opacity="0.75"/>',
        f'<circle cx="{start_x:.2f}" cy="{start_y:.2f}" r="{max(3, short * 0.004):.2f}" fill="{marker}"/>',
    ]

    for column, heading in enumerate(headings):
        x = calendar_x + (column + 0.5) * cell_w
        is_today = column == day.weekday() if first_weekday == calendar.MONDAY else column == (day.weekday() + 1) % 7
        parts.append(_svg_text(
            heading, x, calendar_y, heading_size,
            fill=secondary if is_today else foreground, family=calendar_font,
            weight=650 if is_today else 500, anchor="middle",
            spacing=heading_size * 0.12, opacity=0.92 if is_today else 0.62,
        ))

    for row, week in enumerate(grid):
        for column, number in enumerate(week):
            if not number:
                continue
            x = calendar_x + (column + 0.5) * cell_w
            y = calendar_y + (row + 1.15) * cell_h
            if number == day.day:
                pill_w, pill_h = cell_w * 0.68, cell_h * 0.70
                parts.append(
                    f'<rect x="{x - pill_w / 2:.2f}" y="{y - pill_h * 0.72:.2f}" '
                    f'width="{pill_w:.2f}" height="{pill_h:.2f}" rx="{pill_h * 0.28:.2f}" '
                    f'fill="{primary}" opacity="0.96"/>'
                )
                fill, weight = palette["background_dim"], 700
            else:
                fill, weight = foreground, 450
            parts.append(_svg_text(
                f"{number:02d}", x, y, cal_size,
                fill=fill, family=calendar_font, weight=weight,
                anchor="middle", opacity=0.94,
                extra='style="font-variant-numeric: tabular-nums"',
            ))

    parts.append("</svg>")
    return "\n".join(parts) + "\n"


def fingerprint(day: dt.date, output: dict[str, Any], config: dict[str, Any]) -> str:
    payload = {
        "date": day.isoformat(),
        "output": output,
        "palette": config["palette"],
        "months": config["months"],
        "fonts": config["fonts"],
        "texture_opacity": config.get("texture_opacity"),
        "top_safe_area_ratio": config.get("top_safe_area_ratio"),
        "week_starts_on": config.get("week_starts_on"),
        "renderer_version": RENDERER_VERSION,
    }
    return hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def physical_size(logical: int | float, scale: int | float) -> int:
    return max(1, int(round(float(logical) * float(scale))))


def parse_outputs(payload: dict[str, Any]) -> list[dict[str, Any]]:
    raw_outputs = payload.get("monitors", payload.get("outputs", []))
    if not isinstance(raw_outputs, list):
        raise WallpaperError("mmsg response has no monitor list")
    outputs = []
    for raw in raw_outputs:
        if not isinstance(raw, dict) or raw.get("active", True) is False:
            continue
        name = raw.get("name") or raw.get("connector")
        width, height = raw.get("width"), raw.get("height")
        scale = float(raw.get("scale", 1.0))
        if not name or not width or not height or scale <= 0:
            continue
        outputs.append({
            "name": str(name),
            "width": physical_size(width, scale),
            "height": physical_size(height, scale),
            "logical_width": int(width),
            "logical_height": int(height),
            "scale": scale,
        })
    if not outputs:
        raise WallpaperError("Mango reported no active outputs")
    return sorted(outputs, key=lambda output: output["name"])


def discover_outputs(config: dict[str, Any]) -> list[dict[str, Any]]:
    try:
        result = subprocess.run(
            [config["mmsg"], "get", "all-monitors"],
            check=True, capture_output=True, text=True, timeout=5,
        )
        return parse_outputs(json.loads(result.stdout))
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError) as error:
        raise WallpaperError(f"cannot discover Mango outputs: {error}") from error


def validate_png(path: Path, width: int, height: int) -> None:
    try:
        with path.open("rb") as handle:
            header = handle.read(24)
    except OSError as error:
        raise WallpaperError(f"cannot read rendered PNG: {error}") from error
    if len(header) != 24 or header[:8] != PNG_SIGNATURE or header[12:16] != b"IHDR":
        raise WallpaperError("renderer did not produce a valid PNG header")
    actual_width, actual_height = struct.unpack(">II", header[16:24])
    if (actual_width, actual_height) != (width, height):
        raise WallpaperError(
            f"PNG dimensions are {actual_width}x{actual_height}, expected {width}x{height}"
        )
    if path.stat().st_size <= 24:
        raise WallpaperError("rendered PNG is empty")


def atomic_text(path: Path, contents: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.stem}-", suffix=".tmp", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as handle:
            handle.write(contents)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def render_png(svg: str, output: Path, width: int, height: int, config: dict[str, Any]) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    svg_fd, svg_name = tempfile.mkstemp(prefix=".render-", suffix=".svg", dir=output.parent)
    png_fd, png_name = tempfile.mkstemp(prefix=".render-", suffix=".png", dir=output.parent)
    os.close(png_fd)
    try:
        with os.fdopen(svg_fd, "w", encoding="utf-8") as handle:
            handle.write(svg)
            handle.flush()
            os.fsync(handle.fileno())
        subprocess.run(
            [config["rsvg_convert"], "--width", str(width), "--height", str(height), "--output", png_name, svg_name],
            check=True, capture_output=True, timeout=30,
        )
        temporary_png = Path(png_name)
        validate_png(temporary_png, width, height)
        os.replace(temporary_png, output)
    except (OSError, subprocess.SubprocessError) as error:
        raise WallpaperError(f"PNG rendering failed: {error}") from error
    finally:
        for temporary in (svg_name, png_name):
            try:
                os.unlink(temporary)
            except FileNotFoundError:
                pass


def runtime_paths() -> tuple[Path, Path]:
    cache = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "calendar-wallpaper"
    state = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "calendar-wallpaper"
    return cache, state


def output_stem(name: str) -> str:
    slug = re.sub(r"[^a-zA-Z0-9_.-]+", "-", name).strip("-.") or "output"
    digest = hashlib.sha256(name.encode()).hexdigest()[:8]
    return f"{slug[:64]}--{digest}"


def slot_path(cache: Path, name: str, slot: str) -> Path:
    if slot not in ("a", "b"):
        raise WallpaperError(f"invalid slot: {slot}")
    return cache / f"{output_stem(name)}-{slot}.png"


def read_state(path: Path) -> dict[str, Any]:
    try:
        state = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {"schema_version": SCHEMA_VERSION, "renderer_version": RENDERER_VERSION, "outputs": {}}
    except (OSError, json.JSONDecodeError) as error:
        log(f"ignoring corrupt state: {error}")
        return {"schema_version": SCHEMA_VERSION, "renderer_version": RENDERER_VERSION, "outputs": {}}
    if state.get("schema_version") != SCHEMA_VERSION or not isinstance(state.get("outputs"), dict):
        log("ignoring state with unsupported schema")
        return {"schema_version": SCHEMA_VERSION, "renderer_version": RENDERER_VERSION, "outputs": {}}
    return state


def write_state(path: Path, state: dict[str, Any]) -> None:
    state["schema_version"] = SCHEMA_VERSION
    state["renderer_version"] = RENDERER_VERSION
    atomic_text(path, json.dumps(state, indent=2, sort_keys=True) + "\n")


def apply_wallpaper(name: str, path: Path, config: dict[str, Any]) -> None:
    try:
        subprocess.run(
            [config["noctalia"], "msg", "wallpaper-set", name, str(path.resolve())],
            check=True, capture_output=True, text=True, timeout=8,
        )
    except (OSError, subprocess.SubprocessError) as error:
        raise WallpaperError(f"Noctalia could not apply {name}: {error}") from error


def effective_wallpaper(name: str, config: dict[str, Any]) -> Path | None:
    try:
        result = subprocess.run(
            [config["noctalia"], "msg", "wallpaper-get", name],
            check=True, capture_output=True, text=True, timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    value = result.stdout.strip().splitlines()
    return Path(value[-1]).resolve() if value else None


def state_entry(day: dt.date, output: dict[str, Any], slot: str, path: Path, digest: str, applied: bool) -> dict[str, Any]:
    return {
        "active_slot": slot,
        "applied": applied,
        "date": day.isoformat(),
        "fingerprint": digest,
        "height": output["height"],
        "last_seen": int(time.time()),
        "logical_height": output["logical_height"],
        "logical_width": output["logical_width"],
        "path": str(path.resolve()),
        "scale": output["scale"],
        "width": output["width"],
    }


def copy_atomic(source: Path, destination: Path, width: int, height: int) -> None:
    fd, temporary = tempfile.mkstemp(prefix=".slot-", suffix=".tmp", dir=destination.parent)
    os.close(fd)
    try:
        shutil.copyfile(source, temporary)
        validate_png(Path(temporary), width, height)
        os.replace(temporary, destination)
    finally:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass


def cleanup(cache: Path, state: dict[str, Any], active_names: set[str], retention_days: int) -> None:
    cutoff = int(time.time()) - retention_days * 86400
    retained_stems = set()
    for name, entry in list(state["outputs"].items()):
        if name not in active_names and int(entry.get("last_seen", 0)) < cutoff:
            state["outputs"].pop(name, None)
            continue
        retained_stems.add(output_stem(name))
    try:
        children = list(cache.iterdir())
    except FileNotFoundError:
        return
    for child in children:
        if child.is_symlink() or not child.is_file():
            continue
        if TEMP_FILE.fullmatch(child.name):
            try:
                child.unlink()
            except OSError:
                pass
            continue
        if SLOT_FILE.fullmatch(child.name) and not any(child.name.startswith(f"{stem}-") for stem in retained_stems):
            try:
                child.unlink()
            except OSError:
                pass


def acquire_lock(state_dir: Path):
    state_dir.mkdir(parents=True, exist_ok=True)
    handle = (state_dir / "refresh.lock").open("a+")
    try:
        fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError as error:
        handle.close()
        raise WallpaperError("another refresh is already running") from error
    return handle


def command_prepare(args: argparse.Namespace, config: dict[str, Any]) -> int:
    day = local_date(args.date)
    cache, state_dir = runtime_paths()
    with acquire_lock(state_dir):
        state_path = state_dir / "state.json"
        state = read_state(state_path)
        outputs = discover_outputs(config)
        cache.mkdir(parents=True, exist_ok=True)
        for output in outputs:
            started = time.monotonic()
            name = output["name"]
            digest = fingerprint(day, output, config)
            previous = state["outputs"].get(name, {})
            active = previous.get("active_slot") if previous.get("active_slot") in ("a", "b") else "a"
            active_path = slot_path(cache, name, active)
            svg = render_svg(day, output["width"], output["height"], config)
            render_png(svg, active_path, output["width"], output["height"], config)
            other_path = slot_path(cache, name, "b" if active == "a" else "a")
            copy_atomic(active_path, other_path, output["width"], output["height"])
            state["outputs"][name] = state_entry(day, output, active, active_path, digest, False)
            log(f"trigger=startup output={name} size={output['width']}x{output['height']} slots=a,b rendered={int((time.monotonic() - started) * 1000)}ms")
        cleanup(cache, state, {output["name"] for output in outputs}, int(config.get("stale_output_days", 30)))
        write_state(state_path, state)
    return 0


def command_refresh(args: argparse.Namespace, config: dict[str, Any]) -> int:
    day = local_date(args.date)
    cache, state_dir = runtime_paths()
    with acquire_lock(state_dir):
        state_path = state_dir / "state.json"
        state = read_state(state_path)
        outputs = discover_outputs(config)
        cache.mkdir(parents=True, exist_ok=True)
        for output in outputs:
            started = time.monotonic()
            name = output["name"]
            digest = fingerprint(day, output, config)
            previous = state["outputs"].get(name, {})
            old_slot = previous.get("active_slot") if previous.get("active_slot") in ("a", "b") else "b"
            old_path = slot_path(cache, name, old_slot)
            unchanged = previous.get("fingerprint") == digest
            if unchanged:
                try:
                    validate_png(old_path, output["width"], output["height"])
                except WallpaperError:
                    unchanged = False
            if unchanged and not args.force:
                previous["last_seen"] = int(time.time())
                current = effective_wallpaper(name, config) if config.get("authoritative", True) else old_path.resolve()
                if not previous.get("applied", False) or (current is not None and current != old_path.resolve()):
                    apply_wallpaper(name, old_path, config)
                    previous["applied"] = True
                    previous["path"] = str(old_path.resolve())
                    log(f"output={name} rendered=no applied=yes reason=reconcile")
                else:
                    log(f"output={name} unchanged fingerprint={digest[:12]}")
                continue

            new_slot = "b" if old_slot == "a" else "a"
            new_path = slot_path(cache, name, new_slot)
            svg = render_svg(day, output["width"], output["height"], config)
            render_png(svg, new_path, output["width"], output["height"], config)
            apply_wallpaper(name, new_path, config)
            state["outputs"][name] = state_entry(day, output, new_slot, new_path, digest, True)
            log(f"output={name} size={output['width']}x{output['height']} slot={new_slot} rendered={int((time.monotonic() - started) * 1000)}ms applied=yes")
        cleanup(cache, state, {output["name"] for output in outputs}, int(config.get("stale_output_days", 30)))
        write_state(state_path, state)
    return 0


def command_apply(args: argparse.Namespace, config: dict[str, Any]) -> int:
    cache, state_dir = runtime_paths()
    deadline = time.monotonic() + args.wait_seconds
    last_error: Exception | None = None
    while True:
        try:
            with acquire_lock(state_dir):
                state_path = state_dir / "state.json"
                state = read_state(state_path)
                outputs = discover_outputs(config)
                for output in outputs:
                    entry = state["outputs"].get(output["name"])
                    if not entry:
                        raise WallpaperError(f"no prepared wallpaper for {output['name']}")
                    path = slot_path(cache, output["name"], entry["active_slot"])
                    validate_png(path, output["width"], output["height"])
                    apply_wallpaper(output["name"], path, config)
                    entry["applied"] = True
                    entry["path"] = str(path.resolve())
                    entry["last_seen"] = int(time.time())
                    log(f"output={output['name']} applied=yes reason=startup")
                write_state(state_path, state)
            return 0
        except WallpaperError as error:
            last_error = error
            if time.monotonic() >= deadline:
                raise WallpaperError(f"Noctalia did not become ready: {last_error}") from error
            time.sleep(0.5)


def command_render(args: argparse.Namespace, config: dict[str, Any]) -> int:
    day = local_date(args.date)
    svg = render_svg(day, args.width, args.height, config)
    output = args.output.resolve()
    if output.suffix.lower() == ".svg":
        atomic_text(output, svg)
    elif output.suffix.lower() == ".png":
        render_png(svg, output, args.width, args.height, config)
    else:
        raise WallpaperError("render output must end in .svg or .png")
    log(f"preview={output} date={day.isoformat()} size={args.width}x{args.height} layout={layout_mode(args.width, args.height)}")
    return 0


def command_status(_args: argparse.Namespace, config: dict[str, Any]) -> int:
    cache, state_dir = runtime_paths()
    state = read_state(state_dir / "state.json")
    try:
        outputs: Any = discover_outputs(config)
        discovery_error = None
    except WallpaperError as error:
        outputs = []
        discovery_error = str(error)
    report = {
        "cache_directory": str(cache),
        "discovered_outputs": outputs,
        "discovery_error": discovery_error,
        "local_date": local_date().isoformat(),
        "state": state,
    }
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--config", type=Path, default=os.environ.get("CALENDAR_WALLPAPER_CONFIG"), required=os.environ.get("CALENDAR_WALLPAPER_CONFIG") is None)
    subparsers = result.add_subparsers(dest="command", required=True)

    render = subparsers.add_parser("render", help="render a deterministic preview")
    render.add_argument("--date")
    render.add_argument("--width", type=int, required=True)
    render.add_argument("--height", type=int, required=True)
    render.add_argument("--output", type=Path, required=True)
    render.set_defaults(function=command_render)

    for name, function in (("prepare", command_prepare), ("refresh", command_refresh)):
        command = subparsers.add_parser(name)
        command.add_argument("--date")
        if name == "refresh":
            command.add_argument("--force", action="store_true")
        command.set_defaults(function=function)

    apply = subparsers.add_parser("apply")
    apply.add_argument("--wait-seconds", type=float, default=10)
    apply.set_defaults(function=command_apply)

    status = subparsers.add_parser("status")
    status.set_defaults(function=command_status)
    return result


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        config = load_config(args.config)
        return args.function(args, config)
    except WallpaperError as error:
        log(f"error: {error}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
