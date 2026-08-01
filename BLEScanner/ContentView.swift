import SwiftUI

struct ContentView: View {
    @StateObject private var bluetooth = BluetoothManager()

    var body: some View {
        NavigationView {
            List {
                if !bluetooth.bluetoothOn {
                    Text("Turn on Bluetooth to scan for devices")
                        .foregroundColor(.secondary)
                }

                ForEach(sortedDevices) { device in
                    NavigationLink(destination: DeviceDetailView(device: device, bluetooth: bluetooth)) {
                        DeviceRow(device: device)
                    }
                }
            }
            .navigationTitle("Nearby Devices")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(bluetooth.isScanning ? "Stop" : "Scan") {
                        bluetooth.isScanning ? bluetooth.stopScan() : bluetooth.startScan()
                    }
                    .disabled(!bluetooth.bluetoothOn)
                }
            }
        }
    }

    // Strongest signal (closest device) first.
    private var sortedDevices: [DiscoveredDevice] {
        bluetooth.devices.sorted { $0.rssi > $1.rssi }
    }
}

private struct DeviceRow: View {
    let device: DiscoveredDevice

    var body: some View {
        HStack {
            Image(systemName: "dot.radiowaves.left.and.right")
                .foregroundColor(signalColor)
            VStack(alignment: .leading) {
                Text(device.name).font(.headline)
                Text("RSSI: \(device.rssi) dBm").font(.caption).foregroundColor(.secondary)
            }
        }
    }

    // Rough signal-strength color coding, purely cosmetic.
    private var signalColor: Color {
        switch device.rssi {
        case -50...0: return .green
        case -70..<(-50): return .yellow
        default: return .red
        }
    }
}

#Preview {
    ContentView()
}
