import CoreBluetooth
import SwiftUI

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case failed(String)
}

// Central point for all BLE work. SwiftUI views only read @Published state
// and call the public methods (startScan, connect, disconnect).
final class BluetoothManager: NSObject, ObservableObject {

    @Published var devices: [DiscoveredDevice] = []
    @Published var isScanning = false
    @Published var connectionState: ConnectionState = .disconnected
    @Published var connectedPeripheral: CBPeripheral?
    @Published var discoveredServices: [CBService] = []
    @Published var bluetoothOn = false

    private var centralManager: CBCentralManager!

    override init() {
        super.init()
        // Queue = nil -> delegate callbacks land on main queue, safe for @Published updates.
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Scanning

    func startScan() {
        guard centralManager.state == .poweredOn else { return }
        devices.removeAll()
        isScanning = true
        // withServices: nil scans for ALL nearby peripherals (drains battery faster,
        // interview point: pass service UUIDs in production to filter at the OS level).
        centralManager.scanForPeripherals(withServices: nil,
                                           options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }

    func stopScan() {
        centralManager.stopScan()
        isScanning = false
    }

    // MARK: - Connect / Disconnect

    func connect(to device: DiscoveredDevice) {
        connectionState = .connecting
        centralManager.connect(device.peripheral, options: nil)
    }

    func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {

    // Called once at launch and whenever Bluetooth power state changes.
    // Interview point: NEVER call scanForPeripherals before this reports .poweredOn.
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothOn = central.state == .poweredOn
        if central.state != .poweredOn {
            isScanning = false
            devices.removeAll()
        }
    }

    // Fired repeatedly for every advertising packet a peripheral broadcasts.
    func centralManager(_ central: CBCentralManager,
                         didDiscover peripheral: CBPeripheral,
                         advertisementData: [String: Any],
                         rssi RSSI: NSNumber) {
        let name = peripheral.name
            ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? "Unknown Device"

        if let index = devices.firstIndex(where: { $0.id == peripheral.identifier }) {
            devices[index].rssi = RSSI.intValue
            devices[index].lastSeen = Date()
        } else {
            devices.append(DiscoveredDevice(id: peripheral.identifier,
                                             peripheral: peripheral,
                                             name: name,
                                             rssi: RSSI.intValue,
                                             lastSeen: Date()))
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionState = .connected
        connectedPeripheral = peripheral
        peripheral.delegate = self
        peripheral.discoverServices(nil) // nil = discover ALL services
    }

    func centralManager(_ central: CBCentralManager,
                         didFailToConnect peripheral: CBPeripheral,
                         error: Error?) {
        connectionState = .failed(error?.localizedDescription ?? "Failed to connect")
    }

    func centralManager(_ central: CBCentralManager,
                         didDisconnectPeripheral peripheral: CBPeripheral,
                         error: Error?) {
        connectionState = .disconnected
        connectedPeripheral = nil
        discoveredServices = []
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        discoveredServices = peripheral.services ?? []
        // Discover characteristics for each service so they can be read/written later.
        discoveredServices.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
    }

    func peripheral(_ peripheral: CBPeripheral,
                     didDiscoverCharacteristicsFor service: CBService,
                     error: Error?) {
        // Extend here: read values, subscribe to notifications, etc.
    }
}
