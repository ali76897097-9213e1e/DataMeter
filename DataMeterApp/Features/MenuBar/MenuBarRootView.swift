import SwiftUI

struct MenuBarRootView: View {
    @Environment(\.openSettings) private var openSettings
    @EnvironmentObject private var viewModel: UsageViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DataMeter").font(.headline)
                    Text(viewModel.currentNetwork).foregroundStyle(.secondary)
                }
                Spacer()
                Circle().fill(.green).frame(width: 8, height: 8)
            }

            Text(formatBytes(viewModel.totalUsage))
                .font(.title2.bold())
                .monospacedDigit()
            Text("\(viewModel.selectedTimeRange.title) • ↓ \(formatBytes(viewModel.totalDownloaded)) • ↑ \(formatBytes(viewModel.totalUploaded))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Divider()

            ForEach(viewModel.records.prefix(6)) { record in
                HStack {
                    Image(nsImage: AppIconCache.shared.icon(for: record.appName))
                        .resizable()
                        .frame(width: 14, height: 14)
                    Text(record.appName).lineLimit(1)
                    Spacer()
                    Text(formatBytes(record.total)).monospacedDigit()
                }
            }
            if viewModel.records.isEmpty {
                Text("Collecting usage…").foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                Button("Settings") { openSettings() }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(12)
        .onAppear { viewModel.surfaceAppeared() }
        .onDisappear { viewModel.surfaceDisappeared() }
    }
}
