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
                Text("↓ \(formatBytes(viewModel.totalDownloaded))   ↑ \(formatBytes(viewModel.totalUploaded))")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Label("Tracking", systemImage: "circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                Text("Since \(viewModel.trackingStartedAt, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var filters: some View {
        HStack(spacing: 10) {
            TextField("Filter apps", text: $viewModel.filterText)
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
