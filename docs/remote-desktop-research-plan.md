# Remote Mango Desktop Research Plan

- Status: **researching**
- Created: 2026-08-21
- Implementation readiness: **not ready**
- Intended host: `desktop` (NixOS, Mango/Wayland)
- Intended client: MacBook (macOS)
- Private network: Tailscale

## Purpose

Research a secure, low-latency way to use the existing Mango graphical session
on `desktop` from a MacBook, both within the house and potentially from other
networks. Preserve the findings gathered so far without treating the candidate
design or configuration below as approved for implementation.

No changes described in this document should be applied until the open
questions and research checklist are resolved and this status is deliberately
changed from `researching`.

## Current system context

- Mango is enabled as the Wayland compositor through `programs.mango` in
  `modules/system.nix`.
- Tailscale is already enabled with `openFirewall = true` in
  `modules/system.nix`. Joining the tailnet remains a one-time interactive step.
- `hardware.uinput.enable = true` is already set.
- The desktop user is already in the `input` and `uinput` groups.
- The configuration appears to target AMD graphics: ROCm/OpenCL support and
  `nvtopPackages.amd` are installed. The exact GPU and supported hardware video
  encoders still need to be verified on the running system.
- Mango currently configures the physical output `HDMI-A-1` with scale
  `1.333333`.
- Mango's autostart script imports the Wayland environment into the systemd user
  manager and restarts `xdg-desktop-portal-wlr`, which may help a graphical user
  service find the active session. Whether Mango reliably activates
  `graphical-session.target` still needs to be tested.

## Desired outcome

- View and control the real Mango session from the MacBook.
- Forward keyboard and pointer input reliably, including Mango shortcuts.
- Use a responsive hardware-encoded stream suitable for normal work.
- Carry the connection over Tailscale with no public port forwarding.
- Prefer access that is restricted to the Tailscale interface and, if useful,
  further restricted by tailnet policy.
- Support a sensible monitor-off workflow, ideally through a Mango virtual
  output sized for the MacBook.
- Keep SSH as a recovery and administrative path.

## Candidate design

The leading candidate is:

```text
MacBook: Moonlight
        |
        | Sunshine streaming protocol over the private tailnet
        v
NixOS desktop: Tailscale -> Sunshine -> existing Mango session
                                      -> physical or virtual Mango output
```

This is the strongest current fit because:

- Sunshine supports Linux capture through wlroots, KMS/DRM, and the XDG Desktop
  Portal, with hardware encoding support.
- Moonlight provides a mature macOS client with hardware decoding, direct mouse
  control, and keyboard-shortcut capture.
- Mango is wlroots-based and explicitly documents virtual outputs for VNC and
  Sunshine/Moonlight.
- Tailscale already provides authenticated, encrypted connectivity and avoids
  router port forwarding.

Relevant upstream references:

- [Sunshine project and capture compatibility](https://github.com/LizardByte/Sunshine)
- [Sunshine configuration reference](https://docs.lizardbyte.dev/projects/sunshine/latest/md_docs_2configuration.html)
- [Sunshine getting started](https://docs.lizardbyte.dev/projects/sunshine/master/md_docs_2getting__started.html)
- [Moonlight setup guide](https://github.com/moonlight-stream/moonlight-docs/wiki/Setup-Guide)
- [Moonlight desktop client features](https://github.com/moonlight-stream/moonlight-qt/blob/master/README.md)
- [Mango virtual-monitor documentation](https://github.com/mangowm/mango/blob/main/docs/configuration/monitors.md)
- [Mango virtual-output commands](https://github.com/mangowm/mango/blob/main/docs/bindings/keys.md)
- [Tailscale connection types](https://tailscale.com/docs/reference/connection-types)
- [Tailscale performance guidance](https://tailscale.com/docs/reference/best-practices/performance)

## Provisional NixOS configuration

This is a research sketch, not an implementation-ready change:

```nix
services.sunshine = {
  enable = true;
  autoStart = true;
  openFirewall = false;
  capSysAdmin = false;
};

networking.firewall.interfaces."tailscale0" = {
  allowedTCPPorts = [ 47984 47989 48010 ];
  allowedUDPPorts = [ 47998 47999 48000 48002 ];
};
```

Current reasoning:

- `openFirewall = false` avoids exposing Sunshine on every network interface.
- Interface-specific rules would expose the streaming ports only through
  `tailscale0`.
- UDP 5353 is omitted because Moonlight can add the host manually and multicast
  discovery is not expected to cross Tailscale.
- TCP 47990, the Sunshine web UI, is intentionally omitted from the firewall
  sketch. It can be reached through an SSH tunnel instead.
- `capSysAdmin = false` is the preferred starting point. Mango should support
  Sunshine's unprivileged wlroots capture path. KMS capture is a fallback only;
  it requires the broad `CAP_SYS_ADMIN` capability and should not be enabled
  without a demonstrated need.
- The exact ports opened by the pinned NixOS Sunshine module and current
  Sunshine release must be confirmed before implementation.

## Proposed pairing workflow

1. Install Moonlight on the MacBook and ensure Tailscale is connected on both
   machines.
2. Start Sunshine inside the active Mango session.
3. Forward the administrative UI over the existing SSH path:

   ```sh
   ssh -L 47990:127.0.0.1:47990 desktop
   ```

4. Open `https://localhost:47990` on the MacBook.
5. Create strong Sunshine administrative credentials.
6. Keep Sunshine UPnP disabled; Tailscale replaces public port forwarding.
7. Add `desktop` manually in Moonlight using MagicDNS, or use the desktop's
   Tailscale `100.x.y.z` address.
8. Enter Moonlight's pairing PIN through the tunneled Sunshine UI.
9. Launch Sunshine's built-in Desktop application and test the physical output.

The web UI's certificate warning is expected for Sunshine's locally generated
certificate, but the exact certificate and trust behavior should be reviewed
during testing rather than dismissed automatically.

## Display approaches to investigate

### 1. Capture the physical output

Start by capturing the existing `HDMI-A-1` output. This is the shortest path to
proving that video, keyboard, pointer, and audio work with the current Mango
session.

Expected properties:

- The MacBook sees the same output as the physical monitor.
- Local observers can see remote activity.
- The physical display may need to remain logically connected and awake.
- Its aspect ratio and scaling may not match the MacBook well.

### 2. Create a dedicated Mango virtual output

Mango supports creating a headless output at runtime:

```sh
mmsg dispatch create_virtual_output

wlr-randr \
  --output HEADLESS-1 \
  --pos 1921,0 \
  --scale 1 \
  --custom-mode 1920x1200@60Hz
```

The output can later be removed with:

```sh
mmsg dispatch destroy_all_virtual_output
```

Potential advantages:

- Provides a MacBook-shaped remote monitor.
- Avoids exposing activity on the physical monitor.
- May remain available when the physical monitor is powered off.
- Can behave as an extended Mango monitor rather than disturbing the physical
  workspace.

Questions to resolve:

- Does the pinned Mango revision create `HEADLESS-1` consistently?
- Does Sunshine's wlroots backend enumerate and capture it reliably?
- Can Sunshine select the output by stable name, or only by an index that may
  change?
- Should the virtual output be persistent, created on demand, or tied to a
  Sunshine stream lifecycle?
- What position keeps Mango tag and focus behavior intuitive?
- Is 1920x1200 at 60 Hz the best initial mode, or should the MacBook use another
  resolution and scaling combination?
- What happens to windows placed on the virtual output when it is destroyed?

## Security design under consideration

- Do not enable Sunshine UPnP or configure router port forwarding.
- Permit streaming only on the Tailscale interface.
- Keep the Sunshine web UI bound to or firewalled for localhost and administer
  it through SSH forwarding.
- Retain Sunshine pairing and credentials even though Tailscale authenticates
  and encrypts the network path. A paired Moonlight client effectively has
  screen and keyboard access.
- Consider a Tailscale grant/ACL permitting only the MacBook or the owning user
  to reach Sunshine's ports on `desktop`.
- Confirm whether services are listening on all addresses even when the NixOS
  firewall restricts access, and document the resulting defense-in-depth model.
- Review whether remote input works at the current Noctalia lock screen and
  whether allowing it is desirable.

## Session lifecycle limitations

Sunshine and wayvnc attach to an existing user graphical session. They do not
replace a display manager and should not be assumed to provide remote login from
the Noctalia greeter.

Expected initial operating model:

- The desktop is powered on and awake.
- The user is already logged into Mango, possibly with the session locked.
- Sunshine runs only in that user's graphical session.
- SSH remains available if Sunshine needs to be restarted or diagnosed.

Before calling the design ready, determine:

- Whether `services.sunshine.autoStart` reliably starts after Mango login.
- Whether the NixOS user unit receives `WAYLAND_DISPLAY`, `XDG_RUNTIME_DIR`,
  audio, and portal environment variables.
- Whether Mango activates `graphical-session.target` in this configuration.
- Whether Sunshine survives lock/unlock, output sleep/wake, Mango config reload,
  and disconnect/reconnect cycles.
- What behavior is desired after a reboot. Autologin would make unattended
  graphical access easier but is a separate security decision and is not
  currently proposed.
- What sleep policy is required. Tailscale does not itself wake a suspended or
  powered-off desktop, so wake-on-LAN or a no-suspend policy would be separate
  work.

## Performance research

- Verify the precise AMD GPU and its H.264, HEVC, and possibly AV1 VA-API encode
  capabilities with `vainfo`.
- Start conservatively at 1920x1200, 60 FPS, H.264 or HEVC, and a moderate
  bitrate. Optimize only after measuring latency and frame loss.
- Test Moonlight's direct mouse mode and keyboard-capture behavior.
- Determine how macOS Command and Option map to Mango Super and Alt. Document
  any remapping required for existing Mango keybindings.
- Test audio output and whether the active PipeWire sink changes or mutes local
  audio unexpectedly.
- Run `tailscale ping desktop` from the MacBook and confirm the connection
  transitions to a direct path. DERP remains encrypted but adds latency and
  constrains throughput.
- Compare same-LAN performance with performance from an external network before
  deciding whether additional Tailscale connectivity work is necessary.

## Alternatives retained for comparison

### wayvnc

`wayvnc` is the leading fallback and a useful diagnostic control. It is designed
for wlroots compositors, attaches to an existing Wayland session, creates
virtual input devices, and can capture a physical or headless output.

Advantages:

- Small and Wayland-native.
- Directly aligned with Mango/wlroots.
- Traditional VNC clients are widely available.
- Reasonable option if Sunshine proves unreliable for office work.

Disadvantages and concerns:

- Default frame limit is 30 FPS and the experience is generally less fluid than
  Sunshine/Moonlight.
- Only one output is captured by default, though it can be selected or changed.
- Apple's built-in Screen Sharing client requires wayvnc's legacy DES
  compatibility mode. That authentication is obsolete and does not encrypt the
  session.
- If tested with macOS Screen Sharing, wayvnc should listen only on localhost
  and be reached through an SSH tunnel, or be protected by strict Tailscale
  policy. A modern VNC client supporting VeNCrypt or RSA-AES is preferable.

Reference: [wayvnc README](https://github.com/any1/wayvnc/blob/master/README.md)

### RustDesk

RustDesk plus Tailscale direct-IP access is convenient on conventional desktop
environments, and Tailscale documents this combination. It is not the current
favorite because RustDesk still describes Linux Wayland support as experimental
and has had recent wlroots keyboard-input problems.

References:

- [RustDesk Linux documentation](https://rustdesk.com/docs/en/client/linux/)
- [Tailscale and RustDesk guide](https://tailscale.com/blog/tailscale-rustdesk-remote-desktop-access)

### xrdp/RDP

Not a strong fit. It generally creates a separate Xorg desktop rather than
attaching to the existing Mango session, defeating the main goal.

### Commercial remote-support tools

Not currently favored. They tend to have weaker integration with custom
Wayland compositors and duplicate the remote-connectivity role already handled
by Tailscale.

## Research checklist

- [ ] Confirm the installed/pinned Sunshine version and the exact options in the
      NixOS 26.05 module.
- [ ] Confirm current Sunshine TCP and UDP port requirements from the installed
      package or current upstream documentation.
- [ ] Verify that `services.sunshine` can start in this Mango session and gets
      the correct graphical environment.
- [ ] Verify Mango exposes the protocols required by Sunshine's wlroots capture
      backend.
- [ ] Verify wlroots capture works without `CAP_SYS_ADMIN`.
- [ ] Verify keyboard and pointer injection through existing `uinput` access.
- [ ] Identify the AMD GPU and supported hardware encoders.
- [ ] Test physical `HDMI-A-1` capture.
- [ ] Test audio capture and playback.
- [ ] Test Moonlight modifier-key behavior on macOS.
- [ ] Test full-screen and windowed remote-desktop mouse behavior.
- [ ] Test Tailscale MagicDNS and direct connection establishment.
- [ ] Confirm firewall rules expose the service only through `tailscale0`.
- [ ] Decide whether to add a tailnet grant/ACL for the Sunshine ports.
- [ ] Test Mango virtual-output creation, configuration, capture, and teardown.
- [ ] Test physical-monitor power-off behavior.
- [ ] Test lock/unlock behavior and decide whether remote unlock is acceptable.
- [ ] Test reconnect behavior after Sunshine, Mango, and Tailscale restarts.
- [ ] Decide desired behavior after reboot and suspend.
- [ ] Compare Sunshine/Moonlight with wayvnc for text clarity and interactive
      latency before making a final selection.

## Eventual implementation outline

These steps remain blocked on the research checklist:

1. Add the selected host package/service declaratively.
2. Add Tailscale-interface-only firewall rules.
3. Add any required user-service environment or Mango autostart integration.
4. Configure Sunshine credentials and pair Moonlight without committing secrets.
5. Validate physical-output streaming.
6. Add an on-demand virtual-output helper only if the basic path is stable.
7. Document client settings, modifier mappings, recovery commands, and normal
   operating procedure in the repository README.
8. Run Nix evaluation/formatting checks and an actual rebuild.
9. Exercise the validation matrix below.
10. Change this document's status only after the chosen setup has passed the
    agreed tests.

## Validation matrix for a future implementation

| Scenario | Required result |
| --- | --- |
| MacBook on home Wi-Fi | Direct Tailscale path and usable 60 FPS session |
| MacBook on external network | Secure connection with acceptable latency |
| Physical monitor on | Correct output, input, and audio |
| Physical monitor asleep/off | Defined behavior; virtual output works if selected |
| Mango session locked | Behavior understood and deliberately accepted |
| Moonlight disconnect/reconnect | No stale input devices or dead Sunshine process |
| Mango config reload | Stream remains usable or recovers predictably |
| Tailscale reconnect | Sunshine becomes reachable without public exposure |
| Desktop reboot | Documented behavior; no assumption of remote graphical login |
| SSH recovery | Sunshine can be inspected/restarted without local access |

## Rollback expectations

Any future implementation should remain easy to remove:

- Disable and remove `services.sunshine` configuration.
- Remove Sunshine-specific Tailscale interface firewall rules.
- Remove any Mango virtual-output helper or autostart entry.
- Remove paired client state and Sunshine configuration if desired.
- Preserve the existing Tailscale SSH configuration and unrelated `uinput`
  support, since both already serve other purposes.

## Current conclusion

Sunshine/Moonlight over Tailscale is the leading candidate, with wayvnc as the
fallback. The design is promising and unusually well aligned with Mango's
virtual-output support, but it remains in **researching** status pending
hands-on validation of wlroots capture, remote input, service startup, monitor
power behavior, macOS key mapping, and Tailscale-only exposure.
