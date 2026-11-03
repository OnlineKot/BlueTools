<div align="center">
  <img src="BlueTools/Assets.xcassets/AppIcon.appiconset/icon.png" width="128" height="128" alt="BlueTools icon">
  <h1>BlueTools</h1>
  <p><i>Bluetooth scanner for iPhone</i></p>
</div>

<h3 align="center">
  <a href="https://altdirect.app/?url=https://github.com/OnlineKot/BlueTools/releases/latest/download/source.json" target="_blank"><img src="https://altdirect.app/assets/png/AltSource_Blue.png" alt="Add source" width="200"></a>
  &nbsp;
  <a href="https://github.com/OnlineKot/BlueTools/releases/latest/download/BlueTools.ipa" target="_blank"><img src="https://altdirect.app/assets/png/Download_Blue.png" alt="Download IPA" width="200"></a>
</h3>

<p align="center">
  <img src="docs/screenshots/list.png" width="200" alt="Nearby devices">
  <img src="docs/screenshots/finder.png" width="200" alt="Finding a device">
  <img src="docs/screenshots/list-dark.png" width="200" alt="Nearby devices in dark mode">
  <img src="docs/screenshots/settings.png" width="200" alt="Settings">
</p>

BlueTools is free and open source. No ads, no accounts, no analytics. The only thing it ever asks the internet is the latest version number on GitHub.

## What it does

**Tells you what things are.** It knows all 4000+ Bluetooth manufacturer IDs and reads the extra bits devices put in their broadcasts. That's enough to tell an AirPods Pro 2 from a pair of Beats (with battery levels), spot an AirTag or another Find My accessory, a Galaxy SmartTag, a Tile, a Windows PC, Swift Pair and Fast Pair accessories, iBeacons and Eddystone beacons, heart rate straps, scales and sensors.

**Helps you find a device.** Open Find and BlueTools does a few things at once:

- It ticks like a Geiger counter (sound and haptics) and ticks faster as you get closer.
- If the device accepts connections, it connects quietly and reads the signal four times a second instead of waiting for broadcasts.
- It smooths the signal with a Kalman filter, so the number moves when you move and not on every random spike, and it draws the last minute as a graph.
- Hold the phone in front of you and turn around once. Your body blocks the signal behind you, so BlueTools remembers how strong it was in every compass direction and shows an arrow. Walk that way, turn again. Don't expect a laser pointer, but it's usually enough to tell which way to go.
- If it's a tag or key finder that can beep, there's a Play sound button right there.

**Checks for trackers.** AirTags and other Find My accessories, Galaxy SmartTags and Tiles get flagged. If one stays near you for more than 10 minutes, BlueTools tells you and you can go find it.

**Comes with commands.** Connect to a device and BlueTools shows the commands it supports:

| | |
|---|---|
| Ring loudly, ring softly, stop | tags and key finders (Immediate Alert) |
| Alert when out of range | Link Loss |
| Battery level, watch battery | any device with a battery service |
| Device info | maker, model, serial, firmware |
| Sync clock | watches, scales, anything with Current Time |
| Live heart rate, reset energy | chest straps and watches |
| Live temperature, humidity, pressure | environmental sensors |
| Live cycling, running and weight data | bike sensors, foot pods, scales |
| Send text, listen | Nordic UART and HM-10 serial modules |
| Rename device | devices that allow it |
| Read everything, listen to everything | anything |

You can also open any characteristic, send your own bytes and save them as a command. It then shows up on every device that has that characteristic.

**And the basics:** signal and distance for everything nearby, filtering by type, pinning and nicknames, raw advertisement data, a log of everything you sent and received, value decoding so you see `87%` and `72 bpm` instead of hex, and CSV export of a scan.

**Updates itself.** Every time you open BlueTools it asks GitHub for the latest release. If there's a newer one, it counts down from 3, hands the new IPA to the installer you picked (SideStore, LiveContainer, AltStore, TrollStore, Feather, or just Safari) and closes itself so the installer can swap it out. That works inside LiveContainer too. You can turn the automatic part off and get a list to pick from instead, or cancel the countdown.

## Install

You need iOS 16 or newer. On iOS 26 the icon, the tab bar, the scan status bar and all the floating controls use Liquid Glass. Content stays in plain lists, the way Apple's own apps do it.

### <img src="docs/installers/sidestore.png" width="22" align="center"> SideStore or <img src="docs/installers/livecontainer.png" width="22" align="center"> LiveContainer

Tap **Add AltSource** above on your iPhone and pick your app. Or add the source by hand: in SideStore go to **Sources**, in LiveContainer open the sources settings, and paste:

```
https://github.com/OnlineKot/BlueTools/releases/latest/download/source.json
```

New versions show up there by themselves.

### Manually

Grab `BlueTools.ipa` from the [latest release](https://github.com/OnlineKot/BlueTools/releases/latest) and install it with Sideloadly, AltStore or TrollStore. The IPA isn't signed, so with a free Apple ID it has to be refreshed every 7 days.

## Building

You'll need a Mac with Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
xcodegen generate
open BlueTools.xcodeproj
```

Pick your team under *Signing & Capabilities* and run it on your phone. The simulator has no Bluetooth, but if you launch with `-demo` it shows sample devices. That's how the screenshots above are made: a GitHub Actions job runs the app in the simulator on every push and commits fresh screenshots.

A few other things worth knowing:

- `.xcodeproj` isn't in the repo. XcodeGen builds it from `project.yml`.
- The icon lives in `BlueTools/AppIcon.icon` as layers for Icon Composer, plus a PNG for older iOS. `python3 scripts/make_icon.py` redraws both.
- Manufacturer and UUID names come from the [Bluetooth SIG assigned numbers](https://bitbucket.org/bluetooth-SIG/public). `python3 scripts/import_sig.py <folder>` refreshes them.

## Releases

Bump `MARKETING_VERSION` in `project.yml`, update `.github/release-notes.md`, and push a commit whose message starts with `[release]` (or push a `v*` tag). CI builds the IPA and publishes it together with `source.json` and the icon.

## Limits

- Distance is a guess from signal strength. Walls, pockets and hands can throw it off by meters.
- The direction arrow needs a full turn and gets better with each lap. Metal, mirrors and crowded rooms make it noisier.
- iOS hides real MAC addresses. The identifier you see is made up by iOS and differs on every phone.
- Apple devices change their address every so often for privacy, so they can disappear and come back as "new".
- Classic Bluetooth (old speakers, car kits) is invisible to iOS apps. This is BLE only.

## Contributing

Bug reports and pull requests are welcome. The most useful additions are new device fingerprints in `BlueTools/Identification/DeviceIdentifier.swift` and new commands in `BlueTools/Commands/CommandLibrary.swift`.

## License

[GPL-3.0](LICENSE). The "Add AltSource" and "Download" buttons come from [AltDirect](https://github.com/StikDebug/altdirect). The SideStore, AltStore, LiveContainer, TrollStore and Feather icons belong to those projects and are only used to point to them.
