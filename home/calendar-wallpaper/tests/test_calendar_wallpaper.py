from __future__ import annotations

import argparse
import datetime as dt
import importlib.util
import json
import os
from pathlib import Path
import struct
import tempfile
import unittest
from unittest import mock


MODULE_PATH = Path(__file__).parents[1] / "calendar_wallpaper.py"
SPEC = importlib.util.spec_from_file_location("calendar_wallpaper", MODULE_PATH)
assert SPEC and SPEC.loader
wallpaper = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(wallpaper)


def config() -> dict:
    palette = {
        "background_dim": "#232A2E",
        "background_0": "#2D353B",
        "background_1": "#343F44",
        "background_2": "#3D484D",
        "background_3": "#475258",
        "foreground": "#D3C6AA",
        "red": "#E67E80",
        "orange": "#E69875",
        "yellow": "#DBBC7F",
        "green": "#A7C080",
        "aqua": "#83C092",
        "blue": "#7FBBB3",
        "purple": "#D699B6",
    }
    months = {
        str(month): {"primary": "green", "secondary": "yellow", "marker": "red"}
        for month in range(1, 13)
    }
    return {
        "palette": palette,
        "months": months,
        "fonts": {"primary": "Inter", "calendar": "Iosevka Fixed"},
        "rsvg_convert": "rsvg-convert",
        "mmsg": "mmsg",
        "noctalia": "noctalia",
        "authoritative": True,
        "stale_output_days": 30,
        "texture_opacity": 0.035,
        "top_safe_area_ratio": 0.055,
    }


def valid_png_header(width: int, height: int) -> bytes:
    return wallpaper.PNG_SIGNATURE + b"\x00\x00\x00\x0dIHDR" + struct.pack(">II", width, height) + b"x"


class CalendarTests(unittest.TestCase):
    def test_approved_date_is_friday_in_correct_column(self):
        day = dt.date(2026, 8, 21)
        grid = wallpaper.calendar_grid(day)
        self.assertEqual(day.strftime("%A"), "Friday")
        self.assertEqual(grid[3][4], 21)
        self.assertEqual(grid[0], [0, 0, 0, 0, 0, 1, 2])
        self.assertEqual(grid[5][0], 31)

    def test_grid_is_always_six_weeks(self):
        for year in (2026, 2027, 2028):
            for month in range(1, 13):
                self.assertEqual(len(wallpaper.calendar_grid(dt.date(year, month, 1))), 6)

    def test_leap_year(self):
        self.assertIn(29, sum(wallpaper.calendar_grid(dt.date(2028, 2, 29)), []))
        self.assertNotIn(29, sum(wallpaper.calendar_grid(dt.date(2027, 2, 28)), []))


class RenderingTests(unittest.TestCase):
    def test_svg_contains_required_content_once(self):
        svg = wallpaper.render_svg(dt.date(2026, 8, 21), 3840, 2160, config())
        self.assertIn(">2026</text>", svg)
        self.assertIn(">AUGUST</text>", svg)
        self.assertNotIn(">FRIDAY</text>", svg)
        self.assertIn(">21</text>", svg)
        self.assertIn('width="3840" height="2160"', svg)
        self.assertIn('&quot;layout&quot;: &quot;wide&quot;', svg)
        self.assertIn('x2="3705.60"', svg)
        self.assertIn('filter id="paper-noise"', svg)
        self.assertIn('filter id="dither-noise"', svg)
        self.assertIn('radialGradient id="glow"', svg)
        self.assertEqual(svg.count('fill="#DBBC7F"'), 1)
        self.assertEqual(svg, wallpaper.render_svg(dt.date(2026, 8, 21), 3840, 2160, config()))

    def test_responsive_modes(self):
        self.assertEqual(wallpaper.layout_mode(1920, 1080), "wide")
        self.assertEqual(wallpaper.layout_mode(1920, 1200), "wide")
        self.assertEqual(wallpaper.layout_mode(1350, 1000), "medium")
        self.assertEqual(wallpaper.layout_mode(1200, 1000), "tall")

    def test_rejects_impossible_dimensions(self):
        with self.assertRaises(wallpaper.WallpaperError):
            wallpaper.render_svg(dt.date(2026, 8, 21), 320, 200, config())

    def test_png_validation_checks_dimensions(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "test.png"
            path.write_bytes(valid_png_header(1920, 1080))
            wallpaper.validate_png(path, 1920, 1080)
            with self.assertRaises(wallpaper.WallpaperError):
                wallpaper.validate_png(path, 3840, 2160)


class OutputTests(unittest.TestCase):
    def test_mango_logical_geometry_becomes_physical_geometry(self):
        outputs = wallpaper.parse_outputs({
            "monitors": [{
                "name": "HDMI-A-1",
                "active": True,
                "width": 2880,
                "height": 1620,
                "scale": 1.3333330154418945,
            }]
        })
        self.assertEqual(outputs[0]["width"], 3840)
        self.assertEqual(outputs[0]["height"], 2160)

    def test_connector_filename_cannot_escape_cache(self):
        stem = wallpaper.output_stem("../../strange/output")
        self.assertNotIn("/", stem)
        self.assertNotIn("..", stem)


class CoordinatorTests(unittest.TestCase):
    def test_changed_refresh_alternates_slots_and_bounds_files(self):
        output = {
            "name": "HDMI-A-1",
            "width": 1920,
            "height": 1080,
            "logical_width": 1920,
            "logical_height": 1080,
            "scale": 1.0,
        }
        args_one = argparse.Namespace(date="2026-08-21", force=False)
        args_two = argparse.Namespace(date="2026-08-22", force=False)

        def fake_render(_svg, path, width, height, _config):
            path.write_bytes(valid_png_header(width, height))

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            environment = {
                "XDG_CACHE_HOME": str(root / "cache"),
                "XDG_STATE_HOME": str(root / "state"),
            }
            with (
                mock.patch.dict(os.environ, environment),
                mock.patch.object(wallpaper, "discover_outputs", return_value=[output]),
                mock.patch.object(wallpaper, "render_png", side_effect=fake_render),
                mock.patch.object(wallpaper, "apply_wallpaper"),
            ):
                self.assertEqual(wallpaper.command_refresh(args_one, config()), 0)
                state_path = root / "state/calendar-wallpaper/state.json"
                first = json.loads(state_path.read_text())
                self.assertEqual(first["outputs"]["HDMI-A-1"]["active_slot"], "a")

                self.assertEqual(wallpaper.command_refresh(args_two, config()), 0)
                second = json.loads(state_path.read_text())
                self.assertEqual(second["outputs"]["HDMI-A-1"]["active_slot"], "b")
                slots = list((root / "cache/calendar-wallpaper").glob("*.png"))
                self.assertEqual(len(slots), 2)


if __name__ == "__main__":
    unittest.main()
