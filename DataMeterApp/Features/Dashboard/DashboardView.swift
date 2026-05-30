import DataMeterCore
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var viewModel: UsageViewModel
    @State private var sortOrder = [KeyPathComparator(\UsageRecord.total, order: .reverse)]

    var body: some View {
        VStack(spacing: 14) {
            header
            filters
            if viewModel.records.isEmpty {
                EmptyUsageView(isRunning: viewModel.isRunning)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                UsageTableView(records: viewModel.records, sortOrder: $sortOrder)
                    .onChange(of: sortOrder) { _, newOrder in viewModel.records.sort(using: newOrder) }
            }
        }
        .padding(20)
        .onAppear { viewModel.surfaceAppeared() }
        .onDisappear { viewModel.surfaceDisappeared() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("DataMeter")
                    .font(.largeTitle.bold())
                Text(viewModel.currentNetwork)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(formatBytes(viewModel.totalUsage))
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .accessibilityLabel("Total usage")
                    .accessibilityValue(formatBytes(viewModel.totalUsage))
                Text("↓ \(formatBytes(viewModel.totalDownloaded))   ↑ \(formatBytes(viewModel.totalUploaded))")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .accessibilityLabel("Downloaded \(formatBytes(viewModel.totalDownloaded)), uploaded \(formatBytes(viewModel.totalUploaded))")
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Label(statusTitle, systemImage: "circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(statusColor)
                    .accessibilityLabel("Tracking status")
                    .accessibilityValue(viewModel.status)
                Text("Since \(viewModel.trackingStartedAt, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusTitle: String {
        if viewModel.status.localizedCaseInsensitiveContains("failed") || viewModel.status.localizedCaseInsensitiveContains("unavailable") {
            return "Needs attention"
        }
        return viewModel.isRunning ? "Tracking" : "Paused"
    }

    private var statusColor: Color {
        if viewModel.status.localizedCaseInsensitiveContains("failed") || viewModel.status.localizedCaseInsensitiveContains("unavailable") {
            return .red
        }
        return viewModel.isRunning ? .green : .secondary
    }

    private var filters: some View {
        HStack(spacing: 10) {
            TextField("Filter apps", text: $viewModel.filterText)
                .accessibilityLabel("Filter apps")
                .textFieldStyle(.roundedBorder)
                .onChange(of: viewModel.filterText) { _, _ in viewModel.filtersChanged() }
            Picker("Range", selection: $viewModel.selectedTimeRange) {
                ForEach(UsageTimeRange.allCases) { range in Text(range.title).tag(range) }
            }
            .frame(width: 180)
            .onChange(of: viewModel.selectedTimeRange) { _, _ in viewModel.filtersChanged() }
            Picker("Network", selection: $viewModel.selectedNetwork) {
                ForEach(viewModel.networks, id: \.self) { Text($0).tag($0) }
            }
            .frame(width: 220)
            .onChange(of: viewModel.selectedNetwork) { _, _ in viewModel.filtersChanged() }
        }
    }
}
