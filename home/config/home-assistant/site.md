# Home Assistant — maintained home runbook

Last verified: **2026-10-17**. This is the site companion for Pi's
`home-assistant` skill. Read it at the beginning of HA work; do not search
conversation memory to rediscover these procedures. Verify live configuration
before acting: states, versions, IDs, and device availability can change.

## Ownership and maintenance

- Generic skill, API helper, and helper regression tests:
  `teddyhwang/pi-extensions`, `skills/home-assistant/`.
- This site's nonsecret connection configuration and runbook:
  `teddyhwang/dotfiles`, `home/config/home-assistant/{agent.json,site.md}`,
  linked to `~/.config/home-assistant/` by the normal config linker.
- Live HA configuration is on HA, not duplicated as active YAML in dotfiles.
  Update this runbook and the affected HA README/tests when behavior changes.
- Keep passwords, tokens, PINs, TOTP seeds, HomeKit pairing secrets, and complete
  integration/auth-storage dumps OUT of both repositories and model output.
- Validate, commit, and push each source repository separately. Live-only HA
  edits still require backups/tests/docs; do not invent a git commit for a
  device whose configuration is not git-managed.

## Access — no credentials in this file

| Purpose | Location |
| --- | --- |
| HA API / dashboard | `http://192.168.1.226:8123` |
| Alternate browser URL / OAuth client ID | `http://homeassistant.local:8123/` |
| SSH | `root@192.168.1.226` (Terminal & SSH / `core_ssh` add-on) |
| Configuration root | `/homeassistant` |
| Main YAML | `/homeassistant/configuration.yaml` |
| SSH add-on tools verified | `ha`, `jq`, `curl`; do not assume Python or Docker |
| Local runtime | Node 24; Homebrew Ruby for YAML-based tests |
| Last observed HA version | `2026.10.4` (2026-10-25); inspect `ha core info` before version-dependent changes |

Use the skill's `scripts/ha-api.mjs` with this directory's `agent.json`.
`HA_TOKEN` may supply an existing approved token; otherwise the helper exchanges
an existing matching browser refresh session through SSH, dynamically finding
its ID. No memorized refresh-token ID or new long-lived token is needed.

This site's `agent.json` explicitly selects `transport: system-nc` for the
verified macOS client: Node LAN requests fail while `/usr/bin/nc` succeeds.
The canonical helper creates a bounded ephemeral loopback relay for REST and
WebSocket calls; no resident HA proxy, SSH forwarding, or macOS permission
change is required. It supports this site's approved HTTP origin only, rejects
HTTPS without downgrading, and never retries an ambiguous batch. For clients
with working direct networking (including Linux), use `HA_TRANSPORT=direct`;
`system-nc` requires compatible macOS `/usr/bin/nc` and is not a portable default.

SSH failures now identify host-key/publickey/OAuth stages without printing
credentials. On a new client, authorize its public key and verify the HA host
fingerprint out of band; do not disable host-key checks or copy a private key.
Recorder `history/history_during_period` and `logbook/get_events` are read-only
helper requests: do not add `--write` for them. Specify bounded entity IDs and
explicit timezone-aware `start_time` and `end_time`; the default history end
is only one day after start. Generic regression coverage lives with the helper
in pi-extensions, not as a second copy in dotfiles.

The SSH add-on has `hassio_api`, but **not** `homeassistant_api`. Its
`SUPERVISOR_TOKEN` received 401 from `http://supervisor/core/api/`; this is not a
reason to change add-on security or assume HA is inaccessible. Use HA OAuth.
An SSH add-on shell is not the host shell; do not assume sudo/launchctl/docker.

For live data, batch `lovelace/config`, `get_states`, registry lists, and
`config_entries/get` as needed. Keep raw responses in private files and reduce
to safe fields before displaying. Add-on info and integration storage contain
credentials even when the desired field is only a version or filter.

## Non-negotiable physical-control boundary

Do not send vehicle start/stop/lock/unlock/charging, alarm arm/disarm, or other
physical test commands without specific authorization. Permission to add or
rearrange controls is NOT permission to operate them. This session's dashboard
and estimated-lock changes were verified without actuating the car or alarm.
Do not replay those old approvals as permission for a new physical test.

## Current dashboard

Canonical live configuration: storage-managed **Overview**,
`/homeassistant/.storage/lovelace.lovelace`.

It is now a custom native Sections dashboard, **not auto-generated**:

- **Home** (`/lovelace/home`): 3 responsive desktop sections, stacking on mobile.
  - Home security: alarm, Doors & windows, Motion & alarm status.
  - Lighting & rooms: one control per actual light, Kitchen Night/Away aliases,
    Living room Christmas tree, Living room TV.
  - Garage & LYRIQ: estimated door state, remote start, battery/range/plug/
    charging, Garage plug; nearby weather. Presence/weather badges at the top.
- **Devices** (`/lovelace/devices`): Office printer, automatic backups, and
  Govee maintenance with explicit confirmation.
- Use dashboard-only friendly labels. Do not reintroduce headings such as
  Binary sensor, Switch, Button, Lock, or Sensor.
- Do not show duplicate Govee light + power-switch/gradient/DreamView controls.
  Existing Kitchen names Night/Away are meaningful aliases: do not rename them
  from the misleading backend IDs (`fish_lights`/`kettle`) without asking.
- The two vehicle tiles open More info on tap/icon/hold, avoiding immediate
  start/unlock during ordinary dashboard interaction.
- Use `lovelace/config` / `lovelace/config/save`; do not overwrite live storage.
  Read back the exact saved config and render desktop + phone before finishing.
- Main docs: `/homeassistant/README-DASHBOARD.md`.
- Regression script: `/homeassistant/tests/test-home-dashboard.mjs` (run with
  local Node against an exported JSON configuration).
- Original automatic-layout backup and exports:
  `/homeassistant/backups/dashboard-20261017/`.

Before this custom dashboard, low-level LYRIQ entities were hidden with
`hidden_by: user`, not disabled. Preserve these flags unless intentionally
changing visibility. For future custom-dashboard tidying, omit rows rather
than globally hiding more entities; HomeKit can also filter hidden entities.

## Key entities (verify before editing)

| Purpose | Entity |
| --- | --- |
| DSC alarm | `alarm_control_panel.home` |
| Alarm keypad | `sensor.home_keypad` |
| Entry sensors | `binary_sensor.front_door`, `garage_door`, `side_door`, `kitchen_sliding_door` |
| Window | `binary_sensor.gym_window` |
| Motion | `binary_sensor.kitchen`, `binary_sensor.upstairs` |
| Car remote start | `switch.lyriq_start` (friendly name Car) |
| Car doors | `lock.lyriq_doors` |
| Remembered door estimate, hidden | `input_select.lyriq_door_estimate` |
| Unlocked display window, hidden | `timer.lyriq_unlock_estimate` (5 minutes; display only) |
| Shared door command script, hidden | `script.lyriq_door_command` |
| Command-result history, hidden | `sensor.lyriq_door_command_result` |
| EV percentage/range | `sensor.2024_cadillac_lyriq_charge_state`, `sensor.2024_cadillac_lyriq_ev_range` |
| EV plugged-in/charging | `binary_sensor.2024_cadillac_lyriq_ev_plug_state`, `binary_sensor.2024_cadillac_lyriq_ev_charge_state` |
| Car low-level buttons | `button.2024_cadillac_lyriq_command_lockdoor`, `unlockdoor`, `start`, `cancelstart` (same full prefix) |
| Living room TV | `media_player.living_room` |
| Room switches | `switch.fish_lights` = Night; `switch.kettle` = Away; `switch.christmas_tree`; `switch.garage_plug` |
| Primary lights | `light.floor_lamp`, `light.smart_led_bulb`, `light.tv_backlight`, `light.permanent_lights_pro`, `light.elgato_cw39j1a19465` |

Expand abbreviated entity lists with their full domain/prefix; discover IDs
from live state rather than constructing unverified guesses. Govee devices
mostly have no assigned area; do not invent room assignments from names alone.

## LYRIQ — approved estimated-state design

Live package: `/homeassistant/lyriq_homekit.yaml`, included through
`homeassistant.packages` in `configuration.yaml`.
Docs/tests: `/homeassistant/README-LYRIQ.md`,
`/homeassistant/tests/test-lyriq-config.mjs`.

**Keep this decision:** the user explicitly approved an estimated display
instead of always unknown, then explicitly requested a timed reset analogous
to remote start. After successful unlock, show unlocked for **5 minutes**, then
assume locked for display purposes only. This supersedes the earlier indefinite
last-requested state and the earlier recommendation not to use a timeout.

- `lock.lyriq_doors` mirrors hidden `input_select.lyriq_door_estimate`, whose
  options are unknown/locked/unlocked. No YAML `initial`: it restores across
  restarts, together with restored `timer.lyriq_unlock_estimate` (5 minutes).
  Startup reconciles only an expired/idle unlocked window, not an active one.
- It was seeded to locked **once** from the user's then-current physical-state
  report. That is history, not a current observation. **Never repeat that seed
  from this runbook**; manual reconciliation requires fresh user confirmation.
- Shared script serializes requests (`mode: single`), presses the existing MQTT
  button once, and waits up to 110 seconds for fresh, matching terminal feedback.
- On fresh matching `Completed Successfully`, unlock starts/restarts the
  5-minute window before showing unlocked; lock cancels it and shows locked.
  Sent, stale retained success, wrong-action responses, standalone MQTT
  responses, errors, and timeouts cannot start/cancel the window.
- Timer expiry (or startup recovery with an idle timer and unlocked estimate)
  sets the helper to locked. This is a **display-only assumption**: the expiry
  automation must NEVER call lock/button/MQTT vehicle command services.
  A stale finish event cannot override a renewed active timer.
- Failure retains the previous estimate and shows a persistent notification
  warning it may be wrong. Success dismisses the old failure notification.
  No automatic retries, especially for ambiguous unlocks.
- This is **not live door-lock telemetry**. Fob/handle/Cadillac app changes aren't
  tracked; the display is not proof that the vehicle is secured.
- The owner reports actual automatic re-lock happens **only after a door opens
  then closes**, not a fixed delay. The bridge cannot observe that door cycle.
  The owner nevertheless explicitly requested a timed estimate reset rather
  than an indefinitely unlocked display. The 5-minute reset is NOT detection
  or a real auto-lock: it can display locked while the vehicle is unlocked.
  Do not convert this display rule into an automatic physical lock command.
- Source/fixture review of the pinned bridge/library found no observed door
  position or event subscription; `doorsStatus.supported` / `VEH_SECURE_STATUS`
  are capabilities/permissions, not door readings. Thirty-minute cached health
  polling cannot reliably detect an open→close cycle either. Another verified
  telemetry source would be needed; support through a different GM API is
  unknown. The later timed display reset is an owner-approved workaround,
  not a new telemetry capability.
- Native HomeKit lock/security behavior remains intact; do not replace unlock
  with a generic momentary switch or change accessory identity.
- Remote start's existing 10-minute restored timer is also an estimate, not an
  engine-running callback. Preserve it unless explicitly changing that behavior.
- Pre-change backups: `/homeassistant/backups/lyriq-20261017/` and
  `lyriq-20261017-estimated/`; timed-reset changes use a new
  `lyriq-unlock-window-20261017-084916/` backup. The timed estimate passed
  32 real HA Jinja cases including restored-window/renewal guards. A real
  timer expiry was also observed updating the helper, native lock, and Apple
  Home to locked without invoking the door command script; its configured
  duration remained 5 minutes. Remote start stays 10 minutes.

### OnStar2MQTT facts and auth lessons

- Add-on slug: `020296af_onstar2mqtt_bigthundersr_vehicle1`.
- Broker: `core-mosquitto:1883`; tokens: `/ssl/vehicle1`; 30-minute refresh;
  watchdog off at last verification. Do not lower polling to chase live locks.
- Last investigated code: onstar2mqtt 2.11.0 + onstarjs2 2.16.7; verify on upgrade.
- Command topic `homeassistant/{VIN}/command`; commands are case-sensitive
  `lockDoor` / `unlockDoor`. Discover VIN privately if actually required; don't
  print it or store credentials in this runbook.
- Feedback topics end in `/command/lockDoor/state` or `unlockDoor/state`.
  Payload message is at `command.error.message` **even for success**; timestamp
  is `completionTimestamp`. Sent/success/failure publications are retained.
- Completed Successfully means a resolved library promise; normally command
  status is polled, but it is not an independently observed physical door state.
  There is no true request correlation ID or continuing physical-lock sensor.
- Command requests must never be retained. Do not fabricate responses on the
  live topics for testing.
- GM Access Denied is often anti-bot blocking: avoid login/restart retry loops.
  Archived `.json.old` files do not prove the Microsoft refresh token is dead.
  A previously successful recovery was: back up, restore **only**
  `microsoft_tokens.json` from its `.old` copy with mode 600, start once. Inspect
  current evidence and obtain approval before token recovery; never publish raw
  tokens or broadly overwrite every token file.

## HomeKit identity and verification

| Integration | Port | Entry ID at last verification |
| --- | --- | --- |
| HASS Bridge | 21064 | `fcae08563e212052c571192bdc4bf9e0` |
| Living Room Apple TV (standalone) | 21065 | `01M53DY5CJ9K2EJE43XS0DABQT` |
| LYRIQ Doors (standalone, paired in Garage) | 21066 | `01M54T9W2ZFFVW37S3RR3TH17P` |

HASS Bridge uses an explicit 18-entity allowlist: the existing room controls,
three ordinary lights, DSC alarm/seven zones, and two Govee power-only switches.
New HA entities are **not automatically exposed**; select them deliberately in
its HomeKit options. Its `exclude_accessory_mode` setting means a lock added to
its entity filter alone is ignored. LYRIQ Doors is correctly separate; **no re-pairing is needed
for ordinary dashboard/template/estimate changes**. New standalone accessories
need manual Apple Home pairing from HA's QR notification.

TV YAML customizes `media_player.living_room` as `device_class: tv`. Before
changing TV exposure, inspect any existing Homebridge accessory to avoid a
duplicate. Do not assume an old migration note describes today's plugin state.

Local Itsyhome is available at `http://localhost:8423` on the Mac:

- Read-only `/list/devices` lists Apple Home-visible devices.
- Read-only `/info/Garage/LYRIQ%20Doors` reports the HomeKit-visible estimate,
  e.g. `state.locked`; it is NOT independent vehicle telemetry.
- Other paths can actuate devices via GET. Do not probe control endpoints.
- Itsyhome can't assign rooms; use Apple Home. Do not reset pairing to move or
  rename an accessory. Discover IDs rather than taking the first alarm service.
  Itsyhome `reachable: true` and cached state do NOT prove new HAP
  connections work.

### Apple Home "Updating…" / No Response — check mDNS first

On 2026-10-31, the alarm stayed at "Updating…" in Apple Home while HA and
all three HomeKit entries looked healthy. Cause: Core had started on 10-28
before the LAN was ready (`Network unreachable` and an Envisalink connect
error in startup logs). HA's `network` adapter list then held only the
`hassio`/`docker0` Docker addresses, without `end0` (192.168.1.226). HomeKit
advertised the bridges only there, so Apple devices could not rediscover them.
Existing HAP sessions kept working for about 2.5 days (a Christmas Tree
command still arrived at 06:20), which hid the fault.

1. On the Mac, run `dns-sd -B _hap._tcp local.`. It must list
   `HASS Bridge …`, `Living Room Apple TV …` and `LYRIQ Doors …`.
2. If they are missing, read WS `{ "type": "network" }`. The helper needs
   `--write` for it, though it is a read. The enabled adapters must include
   `end0`.
3. A HomeKit config-entry reload does NOT re-detect adapters. Only a Core
   restart fixes it: `ha core check`, then `ha core restart`. It preserves
   pairing and sends no device commands. Afterwards confirm that `end0` is
   listed, that the bridges are advertised, and that the alarm/keypad report
   live states. Get the owner's approval first; the restart briefly drops the
   DSC TPI link.

The recurring `pair verify without being paired first` errors from a few
Apple devices (for example 192.168.1.251) predate this incident. They are not
this failure mode, and other controllers kept working.

## Govee — Apple Home power only for TV and outdoor patterns

On 2026-10-17, the owner approved replacing just these two Apple Home color
accessories with existing Govee-to-MQTT power switches:

| Original HA light (still enabled in HA) | Apple Home power-only entity |
| --- | --- |
| `light.tv_backlight` | `switch.tv_backlight_power_switch` |
| `light.permanent_lights_pro` | `switch.permanent_lights_pro_power_switch` |

- Apple Home sends only switch on/off, not brightness/color/effect commands.
  Choose TV sync/DreamView and outdoor patterns in Govee. No automation should
  add a color-setting step for these devices. Physical mode restoration has not
  been tested by the agent; a device's own power-cycle behavior is still Govee's.
- Other Govee lights retain their normal color controls. Original HA light
  entities and the HA dashboard remain unchanged; no duplicate dashboard tiles.
- Used the supported HASS Bridge **options flow**, not live storage edits or a
  pairing reset. HA's UI cannot preserve the former mixed domain/exclusion plus
  security-entity filter when changing it, so the equivalent current accessory
  set is now an explicit 18-entity allowlist with only these two replacements.
  Keep DSC/seven zones, Car, Night/Away, Christmas Tree, Garage Plug, and other
  lights when editing this list.
- The replacement accessories appeared as **TV Backlight Power Switch** and
  **Permanent Lights Pro Power Switch**, initially in **Office** (the bridge's
  room). In Apple Home, move them to Living Room/Outside, optionally shorten
  their names, and reselect them in affected scenes/automations. No re-pairing
  is required. This manual room/automation work was not performed by the agent.
- Verified through the Apple Home consumer view that both are reachable switches
  with only on/off state; unrelated accessories, bridge pairing/key identity,
  existing accessory IDs, and standalone TV/LYRIQ entries were preserved.
  **No physical commands were sent**, and no power-cycle/sync test was performed.
- Live docs/test: `/homeassistant/README-GOVEE-HOMEKIT.md` and
  `/homeassistant/tests/test-govee-homekit-power.mjs`. Private before/after
  exports and original bridge identity backup:
  `/homeassistant/backups/govee-homekit-power-20261017/`.
- To reverse the presentation change, use the same supported options flow and
  swap the two switch IDs back to the original light IDs, retaining all other
  included entities. This reintroduces color controls and again requires Apple
  Home scene/room cleanup. Do not restore `.storage` while Core is running;
  restoring the historical mixed filter exactly would require a separately
  approved offline operation. Do not reset the bridge or overwrite pairing.

### TV backlight synchronization — HA-owned (2026-10-25)

Owner approved **Living Room TV - backlight follows power**, automation ID
`living_room_tv_backlight_follow` in `/homeassistant/automations.yaml`.
It follows `media_player.living_room` locally using only
`switch.tv_backlight_power_switch` on/off; Govee modes/colors are untouched.
On/idle/playing/paused/buffering mean on; off/standby mean off. Unknown or
unavailable TV/switch states never cause an off command. Reconciles on mapped
TV power transitions (not playback changes), HA startup (10 seconds), and
backlight reconnection (3 seconds).
Restart mode plus fresh-state guards prevents obsolete retries; maximum two
attempts with 15-second feedback waits, then a persistent failure notification.
No periodic enforcement or idle/paused shutdown timer. Apple TV telemetry can
still be delayed; reported switch state is not observed physical light state.

Owner will remove equivalent Apple Home on/off automations and obsolete
TV duplicates. Do not change HomeKit identity/pairing or disable its TV entry.
Live docs/test: `/homeassistant/README-GOVEE-HOMEKIT.md` and
`/homeassistant/tests/test-tv-backlight-follow.mjs` (358 HA-rendered fixture
cases plus action-scope assertions, no physical test). Backup:
`/homeassistant/backups/tv-backlight-follow-20261025/`. Rollback by disabling
this automation, removing only its ID (or restoring the backup if otherwise
unchanged), checking config, and reloading `automation`; no Core restart.

Access verified from **mac-mini.local** using its authorized SSH key.
Use the site's configured `system-nc` helper transport (see Access above)
instead of reconstructing remote-curl scripts. The SSH add-on refused TCP
forwarding; it is not required. No long-lived token or global proxy was added.

## DSC alarm / Envisalink history and constraints

Migrated from Homebridge's `@brandonarrindell/homebridge-envisalink` to HA's
YAML-only `envisalink` integration on 2026-10-16. EVL4: `192.168.1.142:4025`.
The panel accepts **one TPI client**: the old Homebridge plugin must remain
disabled while HA uses it. Do not re-enable both or restart unrelated services.

YAML is in `configuration.yaml`; credentials/codes are in `secrets.yaml`.
Zone map: 1 Front door, 2 Garage door, 3 Side door, 4 Kitchen sliding door,
5 Upstairs motion, 6 Kitchen motion, 12 Gym window. Partition name Home yields
`alarm_control_panel.home`; this is not a second alarm to discard for its name.

Past logs were quiet despite successful setup; recorder/live entities proved
connectivity. Verify alarm/zone states read-only. No arm/disarm test without
specific permission. A Mac Homebridge service restart may require sudo; do not
assume the SSH add-on or Mac account can run host service-control commands.

Panel clock: HA exposes no panel time. The EVL4 web status page
(`http://192.168.1.142/`, basic auth user `user` + `envisalink_password`)
shows `YYYY-MM-DD HH:MM - System Time`; read it from the SSH add-on with curl
without printing secrets. The only HA way to set the clock is
`envisalink.alarm_keypress` with `*6<master>1HHMMMMDDYY#` (24 h). The SSH
add-on's `SUPERVISOR_TOKEN` returns 401 on `http://supervisor/core/api`, so
send it through the local helper (`--write`) from a private temp file that you
delete afterward. On 2026-10-30 HA accepted one attempt, but it did **not** change the
panel clock, and the owner had to reset it on the keypad. The likely cause is
that HA's stored code isn't the master code, or that TPI keystrokes can't enter
`*6` programming. Treat this path as unproven. Ask the owner to use the keypad
instead of retrying blindly. After the keypad reset, the EVL page matched real
time, so that page **does** show the panel's clock and can be used to check it.

## Deployment and acceptance shortcuts

1. Back up changed resources to a new timestamped private directory. Do not
   overwrite old backups or emit full secret-bearing files in tool output.
2. YAML: precise local edit → upload → `ha core check` → supported domain reloads
   (`input_select`, `script`, `template` used successfully here). Restart only
   when needed; preserve the DSC connection and HomeKit identity.
3. Dashboard: save through WS API, read back, test all entity references, check
   real desktop/phone renders. Native Sections avoids new custom-card installs.
4. HomeKit: verify HA entity/integration, then the read-only Itsyhome consumer
   view after pairing. Clearly distinguish estimate from observed physical state.
5. Confirm no unintended button state or command-script invocation changed.
6. Update this managed source plus the relevant live HA README/tests. Check,
   commit, and push source repos; finish with remaining manual work/limitations.

Use fresh private files for API snapshots. Browser tests use isolated headless
Chrome, not the user's active Chrome. Short-lived browser access tokens may be
kept in-memory/local storage temporarily, without a refresh token; clear that
headless session when done. The Chrome tool's default viewport may reset on
reconnection: use one CDP session for viewport override and screenshot if
checking a specific size (1600px desktop and 390px phone were verified here).
