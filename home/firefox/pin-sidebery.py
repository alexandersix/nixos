"""Pin Sidebery in Firefox's saved toolbar layout while Firefox is closed."""

import json
import os
from pathlib import Path
import shutil
import stat
import sys
import tempfile


WIDGET = "_3c078156-979c-498b-8990-85f7987dd929_-browser-action"
LAYOUT_PREFS = {
    "browser.uiCustomization.state",
    "browser.uiCustomization.horizontalTabsBackup",
}


def pin(layout):
    placements = layout.get("placements", {})
    nav = placements.get("nav-bar")
    if not isinstance(nav, list) or WIDGET in nav:
        return False
    for items in placements.values():
        if isinstance(items, list):
            while WIDGET in items:
                items.remove(WIDGET)
    index = nav.index("unified-extensions-button") if "unified-extensions-button" in nav else len(nav)
    nav.insert(index, WIDGET)
    return True


def main(profile):
    prefs = profile / "prefs.js"
    if not prefs.exists():
        return
    # Firefox writes prefs.js at shutdown; do not race an open browser.
    for process in Path("/proc").glob("[0-9]*/comm"):
        try:
            if process.stat().st_uid == os.getuid() and process.read_text().strip() in {"firefox", "firefox-bin"}:
                print("Sidebery toolbar setup deferred: close Firefox before the next activation.")
                return
        except (FileNotFoundError, PermissionError, ProcessLookupError):
            pass

    lines = prefs.read_text().splitlines(keepends=True)
    changed = False
    for index, line in enumerate(lines):
        if not any(line.startswith(f'user_pref("{key}", ') for key in LAYOUT_PREFS):
            continue
        key, value = json.loads("[" + line.removeprefix("user_pref(").strip().removesuffix(");") + "]")
        layout = json.loads(value)
        if pin(layout):
            value = json.dumps(layout, separators=(",", ":"))
            lines[index] = f"user_pref({json.dumps(key)}, {json.dumps(value)});\n"
            changed = True

    if changed:
        backup = profile / "prefs.js.before-sidebery-pin"
        if not backup.exists():
            shutil.copy2(prefs, backup)
        with tempfile.NamedTemporaryFile(mode="w", dir=profile, delete=False) as output:
            output.write("".join(lines))
            temporary = Path(output.name)
        temporary.chmod(stat.S_IMODE(prefs.stat().st_mode))
        temporary.replace(prefs)
        print("Pinned Sidebery in the saved Firefox toolbar layouts.")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
