import SwiftUI

struct DeviceDetailView: View {
    let device: DiscoveredDevice
    @ObservedObject var bluetooth: BluetoothManager

    var body: some View {
        VStack(spacing: 20) {
            Text(device.name).font(.title2).bold()
            Text("RSSI: \(device.rssi) dBm").foregroundColor(.secondary)

            statusView

            Button(connectButtonTitle) {
                switch bluetooth.connectionState {
                case .connected: bluetooth.disconnect()
                default: bluetooth.connect(to: device)
                }
            }
            .buttonStyle(.borderedProminent)

            if bluetooth.connectionState == .connected {
                List(bluetooth.discoveredServices, id: \.uuid) { service in
                    Text(service.uuid.uuidString).font(.system(.body, design: .monospaced))
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Device")
    }

    private var connectButtonTitle: String {
        bluetooth.connectionState == .connected ? "Disconnect" : "Connect"
    }

    @ViewBuilder
    private var statusView: some View {
        switch bluetooth.connectionState {
        case .disconnected: Text("Not connected").foregroundColor(.secondary)
        case .connecting: ProgressView("Connecting…")
        case .connected: Text("Connected ✅").foregroundColor(.green)
        case .failed(let message): Text("Failed: \(message)").foregroundColor(.red)
        }
    }
}
