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
| Last observed HA version | `2026.10.2`; inspect `ha core info` before version-dependent changes |

Use the skill's `scripts/ha-api.mjs` with this directory's `agent.json`.
`HA_TOKEN` may supply an existing approved token; otherwise the helper exchanges
an existing matching browser refresh session through SSH, dynamically finding
its ID. No memorized refresh-token ID or new long-lived token is needed.

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

**Keep this decision:** the user explicitly approved displaying the last
successfully requested door state instead of always unknown. Apple Home made
unknown look like unlocked even though the car was physically locked.

- `lock.lyriq_doors` mirrors hidden `input_select.lyriq_door_estimate`, whose
  options are unknown/locked/unlocked. No YAML `initial`: it restores across
  restarts. Do not reset it on startup/redeploy.
- It was seeded to locked **once** from the user's then-current physical-state
  report. That is history, not a current observation. **Never repeat that seed
  from this runbook**; manual reconciliation requires fresh user confirmation.
- Shared script serializes requests (`mode: single`), presses the existing MQTT
  button once, and waits up to 110 seconds for fresh, matching terminal feedback.
- Update estimate ONLY for the current wrapper request after
  `Completed Successfully`. Sent, stale retained success, wrong-action responses,
  standalone MQTT responses, errors, and timeouts cannot change it.
- Failure retains the previous estimate and shows a persistent notification
  warning it may be wrong. Success dismisses the old failure notification.
  No automatic retries, especially for ambiguous unlocks.
- This is **not live door-lock telemetry**. Fob/handle/Cadillac app changes aren't
  tracked; the display is not proof that the vehicle is secured.
- Native HomeKit lock/security behavior remains intact; do not replace unlock
  with a generic momentary switch or change accessory identity.
- Remote start's existing 10-minute restored timer is also an estimate, not an
  engine-running callback. Preserve it unless explicitly changing that behavior.
- Pre-change backups: `/homeassistant/backups/lyriq-20261017/` and
  `lyriq-20261017-estimated/`. The estimate update passed 23 real HA Jinja tests.

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

HASS Bridge includes switch/light domains plus the DSC alarm and seven zones.
Its `exclude_accessory_mode` setting means a lock added to its entity filter
alone is ignored. LYRIQ Doors is correctly separate; **no re-pairing is needed
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
