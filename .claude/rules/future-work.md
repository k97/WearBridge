# Future Work

## App Icon Support
- Currently 24dp white Material Design vector drawables with 25% padding
- Upgrade to Play Store PNGs as `largeIcon` for full-color icons

## Multi-Device Pairing
- Support pairing with multiple Wear OS watches
- Persist bonded device list and per-watch notification category preferences
- Only one watch active at a time (BLE limitation with ANCS)

## Health Data Bridge
- Transfer Wear OS health/fitness data to iPhone via BLE + HealthKit
- Requires custom BLE service on both sides + HealthKit entitlement

## Quick Reply List Sync
- The iOS app's editable reply list stays on the iPhone; the watch uses its hard-coded `QUICK_REPLIES`
- Sync it over a companion characteristic (read on connect, notify on change)

## iOS Shortcut Template
- Provide a pre-built "WearBridge Reply" shortcut for download
- Currently users must create the iOS Shortcut manually to handle quick reply text
