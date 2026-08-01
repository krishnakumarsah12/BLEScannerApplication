# BLEScanner

A SwiftUI + CoreBluetooth iOS app that scans for nearby Bluetooth LE devices, displays them sorted by signal strength, and lets you connect to inspect their GATT services.

## Features

- Scan for nearby BLE peripherals (name + live RSSI)
- Auto-sort device list by signal strength (strongest first)
- Tap a device to connect / disconnect
- View discovered GATT services after connecting
- Reactive UI via `ObservableObject` / `@Published` — no manual view refresh code

## Tech Stack

- **SwiftUI** — declarative UI
- **CoreBluetooth** — BLE scanning, connecting, service/characteristic discovery
- **MVVM-ish pattern** — `BluetoothManager` as the single source of truth, views only read `@Published` state

## Project Structure

| File | Role |
|---|---|
| `BluetoothManager.swift` | All CoreBluetooth logic (scan, connect, discover). Single source of truth. |
| `Models/DiscoveredDevice.swift` | UI-friendly wrapper around `CBPeripheral` (adds RSSI, name fallback). |
| `ContentView.swift` | Device list screen. |
| `DeviceDetailView.swift` | Connect/disconnect + shows discovered services. |
| `Info.plist` | Required `NSBluetoothAlwaysUsageDescription` — app crashes without it. |
| `BLEScannerApp.swift` | App entry point. |

## How It Works

1. `CBCentralManager` is created and waits for `centralManagerDidUpdateState`.
2. Scanning only starts once state == `.poweredOn`.
3. Each advertisement triggers `didDiscover peripheral` (fires repeatedly, since devices broadcast every few hundred ms) — RSSI is updated in place instead of duplicating rows.
4. `connect(peripheral)` → `didConnect` → set `peripheral.delegate = self` → `discoverServices(nil)` → `didDiscoverServices` → `discoverCharacteristics`.
5. This **Central → Peripheral → Service → Characteristic** hierarchy is the core mental model for CoreBluetooth.

## Key Design Choices

- **`ObservableObject` + `@Published`**: SwiftUI view auto-updates on scan/connect events with zero manual wiring.
- **`queue: nil`** in `CBCentralManager(delegate:queue:)`: delivers callbacks on the main thread, so `@Published` mutation is safe (no `DispatchQueue.main.async` needed).
- **`withServices: nil`**: scans everything (fine for a demo/utility app). In production you'd pass specific service UUIDs — much better battery life, and it's the only way iOS lets you scan while backgrounded.
- **`allowDuplicatesKey: true`**: so RSSI updates live instead of only firing once per device.

## Requirements

- Xcode 15+
- iOS 16+
- A physical device (CoreBluetooth scanning does not work in the Simulator)

## Getting Started

```bash
git clone [https://github.com/krishnakumarsah12/BLEScannerApplication.git]
cd BLEScanner
open BLEScanner.xcodeproj
```

Run on a physical device (not the Simulator) with Bluetooth enabled, and grant the Bluetooth permission prompt.

## Possible Extensions

- Persist bonded/paired devices with `CBCentralManager.retrievePeripherals(withIdentifiers:)`
- Introduce a protocol around `BluetoothManager` for testability/mocking
- Add characteristic read/write UI in `DeviceDetailView`
- Support background scanning with restore identifiers

---

## Interview Notes 📝

This project is a solid talking point for iOS interviews touching Bluetooth/CoreBluetooth. Below are the questions most likely to come up, with short, ready-to-say answers.

**Q1. Why can't you scan for BLE devices immediately at app launch?**
> The central manager starts in `.unknown` state; you must wait for `centralManagerDidUpdateState` to report `.poweredOn` before scanning.

**Q2. What's the CoreBluetooth object hierarchy?**
> `CBCentralManager` (your phone) discovers `CBPeripheral`s (devices), each peripheral exposes `CBService`s, and each service exposes `CBCharacteristic`s (the actual readable/writable data points).

**Q3. Central vs Peripheral role — what's the difference?**
> Central = the device that scans and initiates connections (the iPhone here). Peripheral = the device being discovered and connected to (e.g. a heart-rate strap). iOS can act as either.

**Q4. Why pass specific service UUIDs to `scanForPeripherals` in production instead of `nil`?**
> It filters at the OS/radio level (saves battery, less noise), and it's required for background scanning — iOS ignores `nil` service scans in the background.

**Q5. How do you keep BLE scanning alive in the background?**
> Add the `bluetooth-central` background mode capability, use `CBCentralManagerOptionRestoreIdentifierKey`, and implement `centralManager(_:willRestoreState:)`.

**Q6. What happens if you don't add `NSBluetoothAlwaysUsageDescription` to Info.plist?**
> The app crashes immediately when `CBCentralManager` is instantiated — iOS requires the usage-description string before any Bluetooth API can be touched.

**Q7. Why store peripherals in an array instead of a Set, given `didDiscover` fires repeatedly?**
> To control ordering (e.g. sort by RSSI) and update rows in place; deduplication is handled manually via `peripheral.identifier` rather than relying on `Hashable`.

**Q8. How would you read/write a characteristic's value?**
> `peripheral.readValue(for:)` triggers `didUpdateValueFor`; `peripheral.writeValue(_:for:type:)` writes, with `.withResponse` (acknowledged) or `.withoutResponse` (fire-and-forget) types.

**Q9. How do you get notified when a characteristic's value changes (e.g. live heart rate)?**
> `peripheral.setNotifyValue(true, for: characteristic)`, then handle updates in `didUpdateValueFor` — the same callback used for a manual `readValue`.

**Q10. Is RSSI-based "distance" reliable?**
> No — RSSI is signal strength, heavily affected by obstacles and orientation. It's only a rough proxy for distance, not a precise measurement.

## License

MIT
