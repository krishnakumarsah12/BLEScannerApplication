# BLE Scanner — Notes

## What it does
Scans for nearby Bluetooth LE devices, lists them (name + signal strength),
lets you tap one to connect and see its GATT services.

## Files
| File | Role |
|---|---|
| `BluetoothManager.swift` | All CoreBluetooth logic (scan, connect, discover). Single source of truth. |
| `DiscoveredDevice.swift` | UI-friendly wrapper around `CBPeripheral` (adds RSSI, name fallback). |
| `ContentView.swift` | Device list screen. |
| `DeviceDetailView.swift` | Connect/disconnect + shows discovered services. |
| `Info.plist` | Required `NSBluetoothAlwaysUsageDescription` — app crashes without it. |

## Core flow (how BLE works here)
1. `CBCentralManager` is created → waits for `centralManagerDidUpdateState`.
2. Only when state == `.poweredOn` can you call `scanForPeripherals`.
3. Each advertisement → `didDiscover peripheral` fires (repeatedly, since devices
   broadcast every few hundred ms). We update RSSI live instead of duplicating rows.
4. `connect(peripheral)` → `didConnect` → set `peripheral.delegate = self` →
   `discoverServices(nil)` → `didDiscoverServices` → `discoverCharacteristics`.
5. `MARK: ⭐ INTERVIEW` — this Central → Peripheral → Service → Characteristic
   hierarchy is the #1 thing interviewers check you understand.

## Key design choices
- **ObservableObject + @Published**: SwiftUI view auto-updates on scan/connect
  events with zero manual wiring.
- **queue: nil** in `CBCentralManager(delegate:queue:)`: delivers callbacks on
  main thread, so `@Published` mutation is safe (no `DispatchQueue.main.async` needed).
- **withServices: nil** scans everything (good for a demo/utility app). In production
  you'd pass specific service UUIDs — much better battery life, and it's the only
  way iOS lets you scan while your app is backgrounded.
- **allowDuplicatesKey: true** so RSSI updates live instead of only firing once per device.

---

## ⭐ Interview Questions (marked, with 1-line answers)

**Q1. Why can't you scan for BLE devices immediately at app launch?**
> Central manager starts in `.unknown` state; you must wait for
> `centralManagerDidUpdateState` to report `.poweredOn` first.

**Q2. What's the CoreBluetooth object hierarchy?**
> `CBCentralManager` (your phone) discovers `CBPeripheral`s (devices), each peripheral
> exposes `CBService`s, each service exposes `CBCharacteristic`s (the actual readable/
> writable data points).

**Q3. Central vs Peripheral role — what's the difference?**
> Central = the device that scans and initiates connections (your iPhone here).
> Peripheral = the device being discovered and connected to (e.g. a heart-rate strap).
> iOS can act as either.

**Q4. Why pass specific service UUIDs to `scanForPeripherals` in production instead of nil?**
> Filters at the OS/radio level (saves battery, less noise), and it's required for
> background scanning — iOS ignores `nil` service scans in the background.

**Q5. How do you keep BLE scanning alive in the background?**
> Add the `bluetooth-central` background mode in capabilities, use
> `CBCentralManagerOptionRestoreIdentifierKey`, and implement
> `centralManager(_:willRestoreState:)`.

**Q6. What happens if you don't add `NSBluetoothAlwaysUsageDescription` to Info.plist?**
> App crashes immediately when `CBCentralManager` is instantiated — iOS requires the
> usage-description string before any Bluetooth API can be touched.

**Q7. Why store peripherals in an array instead of a Set, given `didDiscover` fires repeatedly?**
> To control ordering (e.g. sort by RSSI) and update rows in place; dedup is handled
> manually via `peripheral.identifier` rather than relying on `Hashable`.

**Q8. How would you read/write a characteristic's value?**
> `peripheral.readValue(for:)` triggers `didUpdateValueFor`; `peripheral.writeValue(_:for:type:)`
> writes, with `.withResponse` (acked) or `.withoutResponse` (fire-and-forget) types.

**Q9. How do you get notified when a characteristic's value changes (e.g. live heart rate)?**
> `peripheral.setNotifyValue(true, for: characteristic)`, then handle updates in
> `didUpdateValueFor` — the same callback used for a manual `readValue`.

**Q10. RSSI-based "distance" — is it reliable?**
> No — RSSI is signal strength, heavily affected by obstacles/orientation, only a rough
> proxy for distance, not a precise measurement.

## Possible extensions to mention in an interview
- Persist bonded/paired devices with `CBCentralManager.retrievePeripherals(withIdentifiers:)`
- Add MVVM: move `BluetoothManager` logic behind a protocol for testability/mocking
- Add characteristic read/write UI in `DeviceDetailView`
