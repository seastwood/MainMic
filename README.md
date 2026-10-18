# MainMic

A small menu bar app for macOS (built for the MacBook Air M4) that picks your microphone for you, so AirPods
or any other headset can't take over the input when they connect.

- **Priority list.** The highest-ranked mic that's connected becomes the system input. The MacBook's built-in
  microphone starts at the top. Any new device (AirPods, USB mic, webcam…) goes in at the **bottom** the first
  time it's seen, so it can't take over unless you move it up.
- **Remembers devices.** Devices are stored by their Core Audio UID, so unplugging and replugging, Bluetooth
  reconnects and reboots all keep the order you set.
- **Holds the setting.** MainMic reacts to every device and default-input change, checks again several times over
  the next 6 seconds (AirPods often grab the input again a second or two after connecting), re-checks after
  wake, and runs a check every 3 seconds as a fallback.
- **Better AirPods audio.** With the built-in mic as input, AirPods stay in high-quality stereo for output
  instead of dropping to the low-quality "headset" call profile.

## Menu

Click the 🎙 icon in the menu bar:

| Item | What it does |
| --- | --- |
| Input: … | The current system input |
| Last fix: … | The last time MainMic switched the input back, and from which device |
| 1. MacBook Air Microphone ✓ | The priority list. The check mark is the active device. Hover over a device for **Make Top Priority / Move Up / Move Down / Move to Bottom / Never Use This Mic / Forget Device** |
| Pause Auto-Switching | Stops enforcing the list for now (the icon changes to a crossed-out mic) |
| Launch at Login | Turned on automatically at first launch |

To use your AirPods mic for a call, choose **AirPods → Make Top Priority**. When you're done, move the MacBook mic
back to the top, or just pause auto-switching. If you change the input in System Settings or Control Center while
MainMic is running, it will switch it straight back. That's on purpose.

## Install

You need the Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/seastwood/mainmic.git
cd mainmic
./build.sh --install     # builds, copies to /Applications, launches
```

Or download `MainMic.zip` from the latest **Build** run under the repo's Actions tab, unzip it, move it to
/Applications, then run:

```bash
xattr -dr com.apple.quarantine /Applications/MainMic.app
```

macOS blocks unsigned downloads by default, and that command clears the block.

MainMic doesn't need microphone permission. It only changes which device is the default input and never records
audio.

## Logs

```bash
log stream --predicate 'subsystem == "com.seastwood.mainmic"' --level info
```
