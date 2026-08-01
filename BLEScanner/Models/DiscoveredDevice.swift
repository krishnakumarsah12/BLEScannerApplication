import CoreBluetooth

// Wraps a CBPeripheral with extra scan info (RSSI, last seen) for the UI.
struct DiscoveredDevice: Identifiable, Equatable {
    let id: UUID                 // peripheral.identifier
    let peripheral: CBPeripheral
    var name: String
    var rssi: Int
    var lastSeen: Date

    static func == (lhs: DiscoveredDevice, rhs: DiscoveredDevice) -> Bool {
        lhs.id == rhs.id
    }
}
