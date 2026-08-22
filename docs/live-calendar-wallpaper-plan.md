# Live Everforest Calendar Wallpaper Implementation Plan

- Status: **approved direction; not implemented**
- Created: 2026-08-21
- Target environment: NixOS, Home Manager, Mango/Wayland, Noctalia 5.x
- Primary host today: desktop output HDMI-A-1 at scale 1.333333
- Future targets: 13-inch and 14-inch laptops, including 16:10 and 3:2 displays
- Approved concept: [calendar-wallpaper-concept.png](assets/calendar-wallpaper-concept.png)

## Purpose of this document

This is the implementation handoff for a standalone, automatically updating
calendar wallpaper. It deliberately records the product decisions, visual
direction, runtime behavior, repository integration points, failure handling,
and validation work discussed before implementation.

An implementing agent should treat the decisions in this document as the
default requirements. If a repository or upstream API detail makes one of them
impractical, preserve the user-visible behavior and document the deviation
rather than silently choosing a materially different design.

No runtime implementation has been made yet. The only associated asset is the
approved visual concept under docs/assets.

## Executive summary

Build a small Python application that computes the local date, discovers active
Mango outputs, produces a responsive SVG for each output, and renders each SVG
to a monitor-sized PNG through librsvg. Noctalia remains the wallpaper presenter
and receives each finished image through its wallpaper-set IPC command.

The wallpaper updates:

- synchronously during Mango session startup, before Noctalia is launched;
- shortly after local midnight through a systemd user timer;
- after a missed midnight when the computer resumes or is next powered on;
- after a monitor, timezone, or date change is discovered by a cheap,
  idempotent periodic check.

Use two fixed wallpaper slots per output. Render into the inactive slot,
validate it, atomically publish it, ask Noctalia to switch paths, and then record
the new active slot. This guarantees a path change for Noctalia/Qt cache
invalidation while permanently bounding storage use.

The production wallpaper must be deterministic SVG/PNG generated from code. AI
image generation was used only to establish the approved art direction and
must not be used at runtime.

## Decisions already made

| Topic | Decision |
|---|---|
| Wallpaper type | A generated still image, not a video wallpaper and not an always-running widget |
| Presentation | Standalone generator with Noctalia used only to display/apply the image |
| Date behavior | Use the machine's current local date and timezone |
| Startup behavior | Generate today's image before Noctalia starts so a powered-off laptop never remains on yesterday's image |
| Midnight behavior | Refresh automatically just after midnight while the user is logged in |
| Storage | Two alternating, reusable PNG slots per monitor; no dated archive |
| Calendar | Complete current-month grid with the actual current date highlighted |
| Week start | Monday by default |
| Appearance | Dark-mode-only Everforest backgrounds with seasonal/monthly accents |
| Responsiveness | Compute layout from the output's physical pixel dimensions; do not store hand-positioned widget coordinates |
| Technology | Python standard library plus SVG and librsvg; Nix/Home Manager for packaging and lifecycle |
| Source design | Preserve the broad editorial qualities, but do not copy the original wallpaper pack's composition |
| Excluded reference elements | No left-side icons; no color name, hex value, or color description |
| Approved visual direction | Oversized cropped day numeral, vertical month, compact calendar, weekday label, fine rule, month-progress arc, subtle grain, generous negative space |

## Current repository context

The implementation should begin from these observed facts:

- Home Manager configuration lives primarily in home/default.nix.
- The Noctalia Home Manager module is imported there.
- Noctalia is enabled, but its systemd integration is disabled in both the
  system and Home Manager configuration.
- Mango starts Noctalia from home/mango/autostart.sh.
- That autostart script already imports Wayland-related variables into the
  systemd user manager, then starts Noctalia in the background.
- The script does not currently import MANGO_INSTANCE_SIGNATURE. Add it so a
  later systemd user service can call mmsg against the active compositor.
- Noctalia desktop widgets are disabled. Keep them disabled; this feature does
  not require them.
- Noctalia 5.0.0 exposes:

  ~~~text
  noctalia msg wallpaper-set [connector] <path>
  noctalia msg wallpaper-get [connector]
  ~~~

- Mango exposes monitor queries through mmsg, including get all-monitors and
  get monitor.
- The current Mango rule names HDMI-A-1 and applies scale 1.333333.
- Noctalia's current saved wallpaper configuration contains absolute paths and
  a hard-coded HDMI-A-1 monitor entry. The live wallpaper integration should
  not assume that connector exists on every host.
- The active Noctalia snapshot uses the Everforest community theme in dark
  mode. Preserve a non-wallpaper-derived theme source so changing the generated
  wallpaper does not unexpectedly recolor the entire shell every day.
- The system already installs Inter and Iosevka Fixed. Both are valid renderer
  dependencies and should be referenced explicitly through fontconfig.
- sync-noctalia-config exports Noctalia's merged, writable state back into
  home/noctalia/config.toml. Alternating persisted wallpaper paths may appear in
  that export, so the implementation must test and document the interaction.
- Noctalia greeter auto-sync is currently enabled. Daily CLI wallpaper changes
  must not cause an authentication prompt at midnight. Test this explicitly;
  if it does, disable automatic greeter wallpaper synchronization or otherwise
  keep the dynamic wallpaper desktop-only.

## Product requirements

### Required date content

Every generated wallpaper must contain:

- the four-digit year;
- the full month name;
- the full weekday name;
- the day of month without a leading zero;
- a complete grid for the current month;
- weekday headings;
- an unmistakable highlight around the correct current day.

Use Python's calendar and datetime facilities instead of custom weekday
arithmetic. The default grid begins on Monday. Render a stable six-week grid so
the composition does not jump between short and long months; unused cells stay
empty.

The local timezone is authoritative. Do not call a network time or location
service. Use a timezone-aware local datetime at the start of each refresh and
derive every date field from that single captured value so a render cannot mix
two days if it begins during midnight.

### Required runtime scenarios

The system must behave correctly in all of these situations:

1. The user remains logged in from 11:59 PM through midnight.
2. The computer sleeps before midnight and resumes after midnight.
3. A laptop is powered off for one or many days and then started.
4. The date crosses into a new month or year.
5. February occurs in a leap year and a non-leap year.
6. The system timezone is changed while the graphical session is running.
7. A monitor is connected, disconnected, or replaced during a session.
8. Rendering fails, Noctalia is temporarily unavailable, or the machine shuts
   down during a refresh.
9. Two refresh triggers arrive at nearly the same time.
10. The wallpaper cache was manually deleted.

### Non-functional requirements

- No continuously running Python process.
- No browser engine, QML desktop widget, JavaScript runtime, ImageMagick, video
  renderer, or network request is required.
- A normal no-change check should finish quickly and should not render a PNG.
- A changed 4K wallpaper should normally be ready within two seconds; measure
  rather than optimize speculatively.
- All writes must be confined to the feature's own XDG cache/state directories.
- Publishing a file and updating state must be atomic.
- User-visible output must never be an incomplete PNG.
- Rendering failure must retain the active last-known-good image or a packaged
  dark Everforest fallback; it must not intentionally switch to a missing file.
- Cache cleanup must be narrowly scoped and must never delete arbitrary user
  wallpapers.
- The implementation must be declarative and reproducible through this flake.

### Explicit non-goals

- Do not recreate the original wallpaper pack pixel-for-pixel.
- Do not include the original reference pack in this repository.
- Do not use AI image generation for daily wallpapers.
- Do not implement animated or video wallpaper behavior.
- Do not enable Noctalia desktop widgets for this feature.
- Do not add weather, appointments, tasks, clocks, icons, color names, hex
  values, or marketing descriptions in the first version.
- Do not pre-generate a week or year of wallpapers.
- Do not rewrite the generator in Rust unless profiling identifies a real
  bottleneck or the project later becomes a separately distributed binary.

## Approved visual direction

![Approved live calendar wallpaper concept](assets/calendar-wallpaper-concept.png)

The user explicitly approved this concept as the intended direction. The
production renderer should reproduce its visual language, not trace its pixels.

### Composition

For a wide display, use this hierarchy:

1. An enormous day-of-month numeral dominates the right half and is allowed to
   crop at the right and bottom edges.
2. The month name runs vertically near the left edge.
3. The year sits near the upper-left corner.
4. A thin horizontal rule establishes the upper baseline.
5. The weekday appears in widely tracked uppercase near the visual center.
6. A compact monthly calendar occupies the lower-left region.
7. A thin partial arc near the calendar indicates progress through the month,
   with a small contrasting endpoint.
8. Negative space remains a first-class element; do not fill every region.

This intentionally differs from the original reference's evenly divided
vertical columns. Do not introduce the reference's icon rail or color metadata.

### Typography

- Use Inter as the primary editorial sans-serif unless font rendering tests
  show a stronger installed alternative.
- Iosevka Fixed is appropriate for the small calendar grid if its monospaced
  rhythm improves alignment, but do not force it onto the oversized numeral if
  it weakens the concept.
- The day numeral should use a light or regular weight, not a heavy black
  weight.
- Use the Everforest foreground color rather than pure white.
- Track the year, weekday, headings, and vertical month deliberately.
- Convert no text to paths in source code unless librsvg/fontconfig produces
  inconsistent results. Keeping text as text makes layout iteration easier.
- Record the exact font family and weight in generated metadata/state so a font
  change invalidates the render fingerprint.

### Calendar details

- Weekday headings use MON through SUN by default.
- Day numbers should be two digits inside the compact grid if that produces the
  best alignment; the giant day numeral has no leading zero.
- Highlight today with a small rounded rectangle or pill using the active
  monthly accent and a high-contrast foreground.
- The calendar must remain legible at the laptop's physical resolution without
  competing with application windows.
- Derive the arc's completion from the day within the month. A reasonable
  definition is zero progress on day 1 and full progress on the last day.
- Avoid displaying adjacent-month dates in the empty grid cells for version 1.

### Background and texture

- Start with an Everforest Dark gradient based on bg0 through bg3.
- Never use pure black as the main background and never allow a bright or
  near-white region.
- Add extremely subtle deterministic paper grain or noise. It must not shimmer
  between otherwise identical renders and must not inflate PNG size
  excessively.
- If SVG filter noise is inconsistent in librsvg, use a small deterministic
  tile/pattern or omit texture in the first implementation. Correctness and
  clean rendering outrank texture.

### Safe areas and responsiveness

Render at each output's physical pixel dimensions so Noctalia does not have to
crop a mismatched aspect ratio. Scale all measurements from the shorter canvas
dimension rather than from fixed desktop pixels.

Reserve a top visual safe area for Noctalia's 40-logical-pixel bar and the Mango
frame. The wallpaper still covers the full output; important text simply must
not sit behind shell chrome.

Implement at least three composition modes:

| Aspect ratio | Intended layout |
|---|---|
| Wide, at least about 1.55 | Approved concept: calendar left, giant numeral right |
| Medium, about 1.25 to 1.55 | Reduce numeral size/cropping and tighten horizontal separation |
| Tall/narrow, below about 1.25 | Stack calendar and labels more vertically while retaining the giant numeral and negative space |

Test representative canvases including 3840x2160, 2560x1440, 1920x1080,
1920x1200, 2880x1800, and a 3:2 laptop resolution. Breakpoints and measurements
should be tuned visually from rendered samples rather than treated as immutable
numbers from this plan.

## Everforest palette system

The wallpaper is dark-mode-only. Define a base palette and separate monthly
accent selections. Initial base values can follow the established Everforest
Dark palette:

| Role | Initial value |
|---|---|
| Background dim | #232A2E |
| Background 0 | #2D353B |
| Background 1 | #343F44 |
| Background 2 | #3D484D |
| Background 3 | #475258 |
| Foreground | #D3C6AA |
| Red | #E67E80 |
| Orange | #E69875 |
| Yellow | #DBBC7F |
| Green | #A7C080 |
| Aqua | #83C092 |
| Blue | #7FBBB3 |
| Purple | #D699B6 |

Provide a declarative month-to-accent mapping. A good first pass is:

| Months | Seasonal character | Primary accents |
|---|---|---|
| December, January, February | Winter | blue, aqua, cool foreground |
| March, April, May | Spring | green, aqua, restrained yellow |
| June, July, August | Summer | green, yellow, restrained orange/coral |
| September, October, November | Autumn | yellow, orange, red, restrained purple |

August should remain close to the approved concept: warm foreground, green
current-day highlight/arc, yellow weekday emphasis, and a very small red/coral
progress marker.

The Nix configuration should permit a user to replace any base color or monthly
accent without changing Python source. Validate colors as six-digit hexadecimal
RGB values before rendering.

## Proposed architecture

~~~text
Mango session / systemd timer
            |
            v
calendar-wallpaper coordinator
  - capture local date once
  - acquire process lock
  - discover outputs
  - calculate render fingerprint
  - choose inactive slot
            |
            v
deterministic Python SVG renderer
            |
            v
rsvg-convert -> temporary PNG -> validate -> atomic rename
            |
            v
noctalia msg wallpaper-set <connector> <inactive-slot>
            |
            v
atomic state update and bounded stale-output cleanup
~~~

### Component 1: Python renderer

The renderer owns only deterministic visual generation. Inputs should include:

- date;
- canvas width and height;
- output name for optional metadata only;
- week-start policy;
- palette and month accents;
- font family/weight choices;
- texture and safe-area settings;
- renderer/schema version.

It should produce SVG without depending on a templating framework unless a
clear maintainability benefit appears. Python's standard library is sufficient
for calendar calculations, XML/text escaping, JSON, hashing, filesystem work,
locking, and subprocess execution.

Provide a direct render command with an injectable date. This is essential for
testing arbitrary months without changing the system clock.

Suggested CLI surface:

~~~text
calendar-wallpaper render --date 2026-08-21 --width 3840 --height 2160 --output preview.png
calendar-wallpaper prepare [--date YYYY-MM-DD]
calendar-wallpaper refresh [--date YYYY-MM-DD] [--force]
calendar-wallpaper apply [--wait-seconds 10]
calendar-wallpaper status
~~~

The exact command names may change, but preserve separate testable operations
for pure rendering, pre-Noctalia preparation, and live application.

### Component 2: output discovery

Use Mango's IPC rather than hard-coded connectors. Inspect the actual JSON from
mmsg get all-monitors on the running compositor before finalizing the parser.
Determine whether its reported width and height are physical or logical. If
they are logical, multiply by the output scale and round carefully to obtain the
physical render size.

Requirements:

- ignore inactive outputs;
- support more than one active output;
- preserve connector names for Noctalia commands;
- sanitize or hash connector names before using them in filenames;
- sort outputs deterministically;
- include connector, dimensions, scale, date, palette, font, layout version,
  and renderer version in the render fingerprint;
- treat an output size/scale change as requiring a new render.

If monitor discovery is unavailable during a transient compositor event, do
not delete valid files or publish a guessed replacement. Exit with a useful log
message and allow the next periodic check to retry.

### Component 3: SVG-to-PNG rendering

Use librsvg's rsvg-convert from the Nix store. Invoke it with an argument array,
not through a shell string. Render to a temporary file in the destination
directory so os.replace remains atomic on the same filesystem.

Before publishing, validate at minimum:

- subprocess success;
- nonzero file size;
- PNG signature;
- PNG IHDR width and height equal the requested canvas;
- file is readable by the current user.

Avoid a runtime ImageMagick dependency. If rsvg-convert cannot implement a
specific texture effect, simplify the effect rather than adding a large image
processing pipeline.

### Component 4: Noctalia application

Use the installed command:

~~~text
noctalia msg wallpaper-set <connector> <absolute-path>
~~~

Only update the recorded active slot after this command succeeds. Capture and
log stderr on failure. Do not delete the newly rendered inactive slot after an
apply failure; it can be retried safely.

Use wallpaper-get when available to reconcile Noctalia's effective path with
the local state file, especially after manual wallpaper changes. Define and
document the policy for manual changes. The recommended policy is that enabling
this module makes the calendar authoritative and the next refresh restores it.

Noctalia may animate the path change using its normal wallpaper transition.
Do not implement a separate animation layer.

## Cache and state design

### Runtime paths

Use dedicated XDG locations, approximately:

~~~text
~/.cache/calendar-wallpaper/
  HDMI-A-1-a.png
  HDMI-A-1-b.png
  eDP-1-a.png
  eDP-1-b.png
  temporary files only while rendering

~/.local/state/calendar-wallpaper/
  state.json
  refresh.lock
~~~

The state file should be small and atomic. One possible schema is:

~~~json
{
  "schema_version": 1,
  "renderer_version": 1,
  "outputs": {
    "HDMI-A-1": {
      "active_slot": "a",
      "date": "2026-08-21",
      "width": 3840,
      "height": 2160,
      "scale": 1.333333,
      "fingerprint": "sha256-value",
      "path": "/home/alexandersix/.cache/calendar-wallpaper/HDMI-A-1-a.png"
    }
  }
}
~~~

Do not rely on state.json as the only truth about whether a file is valid.
Verify files before reuse. Treat unknown schema versions conservatively and
regenerate rather than crashing.

### Alternating-slot refresh algorithm

For each changed output during a live refresh:

1. Read the recorded active slot; reconcile with wallpaper-get if practical.
2. Select the opposite slot.
3. Render once to a temporary PNG.
4. Validate it completely.
5. Atomically replace the inactive slot with the validated PNG.
6. Ask Noctalia to switch that connector to the inactive slot's absolute path.
7. If the switch succeeds, atomically record the new active slot and
   fingerprint.
8. Leave the old active file in place as the last-known-good alternative.

Do not use date-bearing filenames. A path change between a and b is sufficient
to defeat image caching without creating an archive.

### Startup preparation algorithm

Startup differs slightly because Noctalia has not launched yet:

1. Import the Mango/Wayland environment into the systemd user manager.
2. Discover active outputs while Mango is available.
3. Generate today's validated image for each output.
4. Atomically copy/publish that same result into both of the output's slots.
   This ensures whichever slot Noctalia persisted from the previous session
   already contains today's image before Noctalia paints it.
5. Update state without claiming Noctalia applied a path that has not yet been
   confirmed.
6. Start Noctalia.
7. Run a short bounded apply/reconciliation helper in the background once
   Noctalia IPC is ready.

On a normal powered-off laptop startup this produces the current wallpaper on
demand; there is no need for future pre-generated images.

### Cache cleanup

At the end of a successful refresh:

- retain exactly slots a and b for each current or recently known connector;
- remove abandoned temporary files created by this application;
- remove slots for connectors absent longer than a conservative grace period,
  such as 30 days;
- never follow symlinks during cleanup;
- only remove filenames matching the application's strict slot/temp naming
  scheme inside its resolved cache directory;
- keep state entries consistent with any removal.

The normal steady-state upper bound is two PNGs per output, a tiny JSON state
file, and no temporary file. The approved 1672x941 concept is about 1.9 MB; an
actual textured 4K PNG may be several megabytes, but bounded slot count matters
more than the exact compression result.

### Locking and atomicity

Acquire an exclusive advisory lock before reading state or starting a refresh.
A second invocation should either wait briefly or exit successfully with a
clear already-running result. Do not permit the midnight timer and periodic
check to race.

Write JSON and PNG files as temporary siblings, fsync where reasonable, and
publish with os.replace. Preserve the old file until the new file passes every
validation step.

## Lifecycle integration

### Mango startup

Modify home/mango/autostart.sh carefully. Preserve the existing portal restart,
Solaar startup, and conditional Mouseless startup.

The intended order is:

1. Import WAYLAND_DISPLAY, XDG_CURRENT_DESKTOP, XDG_SESSION_TYPE, DISPLAY, and
   MANGO_INSTANCE_SIGNATURE into the systemd user manager.
2. Restart the portal exactly as the current configuration does.
3. Run calendar-wallpaper prepare synchronously.
4. Start Noctalia in the background.
5. Start a bounded calendar-wallpaper apply/reconcile operation in the
   background; it should wait only a small configured number of seconds for
   Noctalia IPC.
6. Continue the remaining current autostart commands.

Preparation must fail soft: log the problem and allow Noctalia to start with a
last-known-good or packaged fallback rather than preventing the desktop shell
from launching.

### Midnight and resilience timer

Create a Home Manager systemd user oneshot service and timer. The timer should
combine an exact local-midnight trigger with a low-frequency idempotent safety
check. A starting design is:

~~~ini
[Timer]
OnCalendar=*-*-* 00:00:02
OnStartupSec=5m
OnUnitActiveSec=5m
Persistent=true
AccuracySec=1s
~~~

The five-minute trigger does not render every five minutes. The command first
compares the date/output/config fingerprint and normally exits without calling
rsvg-convert. It exists to catch monitor hotplug, timezone changes, resume edge
cases, or a failed midnight application without maintaining a daemon.

Verify that the Mango session exposes the imported environment to the service.
The service should be Type=oneshot, should not restart indefinitely, and should
write useful messages to the user journal.

### Suspend, power-off, and clock changes

- If the system is awake at midnight, OnCalendar performs the switch within a
  few seconds.
- If it is asleep, Persistent and/or the next periodic trigger refreshes after
  resume.
- If it was powered off, synchronous Mango startup preparation renders the
  current date before Noctalia starts.
- If the timezone or system date moves forward or backward, the periodic
  fingerprint check notices the new local date within five minutes.
- Date injection used by tests must never modify the system clock.

## Home Manager and Nix structure

Prefer separating this feature from the already large home/default.nix. A
reasonable proposed layout is:

~~~text
home/
  calendar-wallpaper.nix
  calendar-wallpaper/
    calendar_wallpaper.py
    palettes.json or generated Nix JSON
    tests/
      test_calendar_wallpaper.py
  default.nix
  mango/
    autostart.sh
docs/
  assets/
    calendar-wallpaper-concept.png
  live-calendar-wallpaper-plan.md
~~~

The local Home Manager module should expose an option namespace such as
alexandersix.calendarWallpaper with at least:

- enable;
- weekStartsOn, default monday;
- base palette colors;
- month accent overrides;
- primary and calendar font family/weight;
- texture opacity or enable flag;
- top safe-area ratio;
- periodic check interval;
- stale-output retention period;
- whether the calendar is authoritative after manual wallpaper changes.

Serialize the resolved Nix settings to a JSON file in the Nix store and pass
that immutable config path to the Python executable. Do not teach Python to
parse Nix or TOML.

Package the Python entry point with explicit runtime dependencies, including
Python, librsvg, fontconfig/fonts as needed, and any core utilities used by a
small wrapper. The Python application should use no third-party Python package
for version 1.

Add the module to home/default.nix imports and enable it there with the chosen
Everforest defaults. Ensure the module works for a username/home directory
provided by Home Manager rather than embedding /home/alexandersix in Python.

### Noctalia configuration changes

- Keep desktop_widgets.enabled false.
- Replace the current hard-coded default wallpaper with a guaranteed existing
  dark fallback or managed initial path.
- Avoid a declarative connector-only entry for HDMI-A-1; runtime output
  discovery owns per-connector application.
- Ensure the final Nix override wins over values loaded from
  home/noctalia/config.toml where required.
- Test what wallpaper-set persists and what sync-noctalia-config exports.
- Avoid daily repository diffs. If manual export flips only the managed a/b
  wallpaper path, normalize or exclude that runtime-managed field during the
  sync workflow, or document a stable final override that makes the snapshot
  value irrelevant.
- Confirm the community Everforest theme remains active and is not regenerated
  from the wallpaper.
- Confirm greeter auto-sync does not produce daily privilege prompts. The
  dynamic calendar is desktop-only unless greeter support is deliberately
  designed later.

### Fallback asset behavior

Package a static, date-free dark Everforest gradient in the Nix store. It must
not display a potentially wrong calendar date. Use it as Noctalia's safe default
and as the recovery source if the cache is missing and a runtime render cannot
be completed.

The approved concept is a design reference, not the fallback, because it
contains the fixed date August 21, 2026.

Test a manually deleted cache followed by login. The observed result must be a
current generated wallpaper or the date-free fallback, never a blank desktop.

## Implementation milestones

### Milestone 0: verify integration APIs

- Capture representative mmsg monitor JSON on the live Mango session.
- Establish physical versus logical geometry and scaling semantics.
- Confirm wallpaper-set and wallpaper-get behavior for a specific connector.
- Confirm whether setting an a/b path triggers a Noctalia transition.
- Confirm whether a CLI wallpaper change triggers theme extraction or greeter
  auto-sync.
- Confirm user services receive MANGO_INSTANCE_SIGNATURE after import.

Do not build the state parser around guessed monitor fields.

### Milestone 1: build the pure renderer

- Implement date/calendar modeling.
- Implement wide, medium, and tall responsive layouts.
- Implement the Everforest base palette and August concept styling.
- Generate SVG and render it through librsvg.
- Add direct date/dimension preview commands.
- Render August 21, 2026 and compare it visually with the approved concept.
- Tune typography, crop, calendar scale, safe area, arc, and grain.

This milestone is successful when the deterministic 16:9 render clearly feels
like the approved concept while being structurally original and calendar-correct.

### Milestone 2: add seasonal palettes

- Implement monthly accent resolution.
- Add Nix-configurable overrides.
- Produce a contact sheet or individual previews for at least January, April,
  August, and October.
- Verify every wallpaper remains dark and foreground contrast remains usable.

### Milestone 3: add coordinator and bounded storage

- Implement output discovery.
- Implement fingerprints and idempotent no-change exits.
- Implement the state schema, lock, temp files, PNG validation, and atomic
  replacement.
- Implement a/b slot selection and Noctalia application.
- Implement narrowly scoped stale-output cleanup.
- Add useful status and error messages.

### Milestone 4: package declaratively

- Add the Home Manager module and options.
- Package Python, librsvg, and the date-free fallback.
- Add the package and settings to home/default.nix.
- Adjust Noctalia's declarative wallpaper defaults.
- Run Nix formatting and evaluation checks.

### Milestone 5: integrate session lifecycle

- Update Mango autostart environment import and ordering.
- Add prepare-before-Noctalia and bounded post-start apply.
- Add the systemd user oneshot service and timer.
- Verify journal output and session environment.
- Verify a failed prepare cannot block Noctalia startup.

### Milestone 6: end-to-end validation

- Test startup, manual refresh, simulated midnight, sleep/resume, cache deletion,
  render failure, Noctalia failure, monitor hotplug, and concurrent invocations.
- Test the current 4K desktop output and representative laptop aspect ratios.
- Confirm bounded storage after many forced date changes.
- Confirm sync-noctalia-config and greeter behavior.
- Update README with user-facing controls and troubleshooting.

## Test plan

### Automated Python tests

Use the standard-library unittest framework unless the repository adopts
another test runner before implementation.

Calendar tests:

- August 21, 2026 is Friday and appears in the Friday column.
- August 2026 begins on Saturday and ends on Monday the 31st.
- February 2028 includes the 29th.
- February 2027 does not include the 29th.
- Months beginning on Monday and Sunday align correctly.
- December-to-January and year changes update all labels.
- Six-week grid output is stable.

Rendering/model tests:

- SVG width/viewBox and rendered PNG dimensions match requested pixels.
- The giant date, year, month, weekday, calendar header, and current-day
  highlight exist exactly once where intended.
- XML-special text/config values are escaped.
- Invalid palette colors and impossible dimensions are rejected.
- Identical inputs produce identical SVG and fingerprint.
- Each aspect-ratio class selects the intended layout.

Coordinator tests with temporary directories and fake subprocess commands:

- First refresh creates a valid slot.
- A successful second changed refresh flips a to b or b to a.
- An unchanged fingerprint does not invoke rsvg-convert or Noctalia.
- Render failure preserves the old slot and state.
- PNG validation failure preserves the old slot and state.
- Noctalia failure does not mark the new slot active.
- A later retry can apply an already rendered inactive slot.
- Two concurrent refreshes cannot corrupt state.
- Cleanup removes only recognized stale files inside the owned directory.
- Unsafe connector strings cannot escape the cache directory.
- Unknown/corrupt state regenerates safely.

### Nix checks

At minimum run:

~~~console
alejandra home/calendar-wallpaper.nix home/default.nix
nix flake check
nix build .#nixosConfigurations.desktop.config.system.build.toplevel
~~~

Use the repository's normal dry-build/switch workflow only after evaluation
succeeds. Do not overwrite unrelated user changes in a dirty worktree.

### Manual visual matrix

Generate controlled previews rather than changing the system clock:

| Date | Purpose |
|---|---|
| 2026-08-21 | Match the approved concept and Friday highlight |
| 2026-08-01 | First day, near-zero arc |
| 2026-08-31 | Last day, full arc |
| 2028-02-29 | Leap-day layout |
| 2026-12-31 | Year-end labels and winter palette |
| 2027-01-01 | New-year labels and winter palette |
| Representative April date | Spring palette |
| Representative October date | Autumn palette |

Inspect each at 16:9 desktop, 16:10 laptop, and 3:2 laptop dimensions. Check
that the giant numeral is intentionally cropped rather than accidentally
clipped, small text remains legible, and the bar safe area works.

### Manual lifecycle tests

1. Start Mango from a cold login and verify today's image is already present
   when Noctalia appears.
2. Use the date-injection/manual command to simulate the next day and observe a
   normal Noctalia transition to the other slot.
3. Force month and year boundaries.
4. Stop Noctalia, run refresh, restart it, and verify reconciliation.
5. Make rsvg-convert fail and confirm the old image remains.
6. Delete the cache and log in; confirm current output or the date-free fallback,
   never blank.
7. Suspend across a scheduled test timer and resume.
8. Connect another output and verify it receives an appropriately sized image
   within the periodic-check window.
9. Disconnect/reconnect an output and verify state remains safe.
10. Run many forced refreshes and verify there are still only two slots per
    retained connector.
11. Run sync-noctalia-config and inspect the diff for unwanted slot churn.
12. Observe whether greeter sync or polkit prompts occur during CLI changes.

## Logging and diagnostics

Every refresh should log a concise reason and result, for example:

~~~text
calendar-wallpaper: trigger=midnight local_date=2026-08-22
calendar-wallpaper: output=HDMI-A-1 size=3840x2160 slot=b rendered=412ms applied=yes
calendar-wallpaper: unchanged output=eDP-1 fingerprint=...
~~~

Never log large SVG content or private environment dumps. Include enough
information to diagnose output discovery, rendering, and Noctalia IPC failures.

The status command should report current local date, discovered outputs,
recorded active slots, file existence/dimensions, fingerprints, and the next
timer run if this can be obtained cheaply.

README troubleshooting should include:

- viewing the user service/timer status;
- viewing recent journal messages;
- manually forcing a refresh;
- rendering a preview for an arbitrary date and size;
- recovering to the packaged fallback;
- explaining that cache contents are disposable and bounded.

## Performance rationale

Python is the deliberate choice. Calendar computation and SVG construction take
milliseconds; 4K rasterization through librsvg is expected to dominate. A Rust
rewrite might reduce interpreter startup by a few tens of milliseconds but
would not materially improve a once-daily operation.

Measure separate timings for discovery, SVG generation, rasterization,
validation, and Noctalia application. Optimize only if the complete changed
refresh exceeds the two-second target on the laptop. A later Rust/resvg version
can preserve the same JSON configuration, state schema, CLI behavior, and SVG
contract if distribution as a standalone binary ever becomes a goal.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Noctalia caches an overwritten image | Alternate between two distinct paths |
| Laptop was off at midnight | Generate synchronously at Mango login |
| Laptop slept through midnight | Persistent timer plus periodic idempotent check |
| Hundreds of dated 4K files accumulate | Fixed a/b slots and scoped stale-output cleanup |
| Render dies halfway through | Temporary sibling, validation, atomic rename |
| Noctalia is not ready | Preserve inactive render and use bounded post-start retry |
| Two triggers race | Exclusive state/refresh lock |
| Wrong calendar math | Python calendar library plus injected-date unit tests |
| Desktop coordinates fail on laptop | Responsive normalized layout from physical dimensions |
| Scale causes blur/cropping | Render at exact physical output size and verify Mango geometry semantics |
| Daily wallpaper unexpectedly rethemes shell | Keep Noctalia theme source on community Everforest, not wallpaper-derived |
| Daily greeter sync prompts for privilege | Test and disable/decouple greeter auto-sync if needed |
| Noctalia config export churns a/b paths | Normalize runtime-managed fields or enforce/document stable overrides |
| Cache deletion leaves stale Noctalia path | Guaranteed packaged fallback and explicit cache-deletion login test |
| Texture creates huge PNGs | Deterministic low-opacity pattern, measure size, omit if necessary |
| Font differs across hosts | Declare fonts in Nix and include font identity in fingerprint |

## Acceptance criteria

The feature is complete only when all of the following are true:

- The deterministic wallpaper visibly matches the approved concept's design
  direction without copying the original commercial design.
- It shows the correct local year, month, weekday, day, month grid, and current
  day highlight.
- It updates automatically within a few seconds of midnight while the machine
  is awake.
- It updates after resume if midnight was missed.
- It starts with today's wallpaper after the computer was powered off.
- A cold login never intentionally presents a blank wallpaper; a date-free dark
  fallback covers failures.
- Month, year, leap-year, and timezone changes work.
- The current desktop and representative 13/14-inch laptop aspect ratios look
  intentional without manual widget positioning.
- Dark Everforest styling is maintained across all twelve months.
- August remains recognizably close to the approved concept's accent treatment.
- Storage remains bounded to two PNG slots per retained output plus tiny state.
- There is no resident Python wallpaper daemon and no video playback.
- Rendering/apply failures preserve the last-known-good wallpaper.
- The Noctalia shell theme does not change unexpectedly with each wallpaper.
- Midnight updates do not cause greeter authentication prompts.
- Nix evaluation/build checks and automated tests pass.
- README documents configuration, manual refresh/preview, cache location, and
  troubleshooting.

## Handoff checklist for the implementing agent

Before editing:

- Read this entire document.
- Inspect git status and preserve unrelated user changes.
- Re-check the relevant portions of home/default.nix,
  home/mango/autostart.sh, home/noctalia/config.toml, and
  home/scripts/sync-noctalia-config.sh because the repository may have evolved.
- Inspect the live mmsg schema instead of assuming fields.
- Inspect current Noctalia CLI help from the installed version.

During implementation:

- Keep pure renderer logic separable from Mango/Noctalia orchestration.
- Use apply_patch for text edits and preserve existing formatting conventions.
- Render previews early and compare them with the approved concept.
- Make startup failure soft and all file publication atomic.
- Add automated tests alongside behavior, not after all integration work.
- Send short progress updates before long builds or visual inspection cycles.

Before handing back:

- Run the automated and Nix checks appropriate to the changed files.
- Report any manual tests the user still needs to perform in the graphical
  session.
- List changed files and explain any deviation from this plan.
- Do not claim midnight, suspend/resume, greeter, or multi-monitor behavior was
  verified unless it was actually exercised.

## Appendix A: concept-generation brief

The approved concept was generated from the following design brief. Preserve it
as art-direction context; do not use image generation in the production path.

~~~text
Use case: UI mockup
Asset type: 16:9 desktop wallpaper concept, dark-mode calendar wallpaper

Create an original, highly polished editorial calendar wallpaper for Friday,
August 21, 2026. Use the supplied commercial wallpaper screenshot only as a
high-level reference for the appeal of oversized date typography, fine rules,
generous negative space, and modernist editorial restraint. Do not reproduce
its column layout or element placement.

Build a distinctly original asymmetric composition: place an enormous partially
cropped 21 across the right half as the dominant form; anchor a compact complete
monthly calendar in the lower-left quadrant; place AUGUST vertically near the
far left edge; place FRIDAY horizontally in restrained uppercase near the
center; place 2026 in the upper-left. Use one thin horizontal rule and a subtle
curved month-progress arc, not four vertical columns. Keep ample breathing room
and account for a slim desktop bar at the top.

Use a dark Everforest-inspired gradient: deep charcoal blue-green #2D353B
through #343F44 and #475258, warm foreground #D3C6AA, with restrained #A7C080,
#DBBC7F, and #E67E80 accents. The result must remain comfortable behind a dark
desktop theme and must never become bright or white.

The calendar starts Monday. August 2026 begins with 01 under Saturday and 02
under Sunday, continues through 31 under Monday, and highlights 21 under Friday
with a small rounded Everforest-green field.

No icons, color metadata, clocks, logos, watermarks, monitor frames, UI chrome,
or replica composition.
~~~

## Appendix B: open implementation-time questions

These are deliberately unresolved until the live APIs are exercised:

1. Which exact mmsg fields represent active state, logical dimensions, physical
   dimensions, and scale in the pinned Mango version?
2. Does Noctalia notice/reload the same path, and does alternating paths produce
   its expected transition? The architecture assumes distinct paths regardless.
3. How quickly is Noctalia IPC ready after process launch, and what bounded wait
   is appropriate?
4. Does wallpaper-set trigger greeter auto-sync or a polkit prompt with the
   current settings?
5. Does wallpaper-get report a canonicalized absolute path suitable for slot
   reconciliation?
6. What per-monitor entries are emitted by sync-noctalia-config after runtime
   a/b changes, and should the sync script normalize them?
7. Does librsvg render Inter/Iosevka weights identically on desktop and laptop
   closures, or should the package set FONTCONFIG_FILE explicitly?
8. How subtle can grain remain while retaining good 4K PNG compression?
9. Which responsive breakpoint values look best after actual preview renders?
10. Does a new hotplugged output receive Noctalia's default fallback until the
    next periodic refresh, and is that transition acceptable?

Resolve these through inspection and tests; none requires changing the core
product direction.
