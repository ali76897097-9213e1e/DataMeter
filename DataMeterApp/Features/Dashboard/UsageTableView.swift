import DataMeterCore
import SwiftUI

struct UsageTableView: View {
    let records: [UsageRecord]
    @Binding var sortOrder: [KeyPathComparator<UsageRecord>]

    var body: some View {
        Table(records, sortOrder: $sortOrder) {
            TableColumn("App", value: \UsageRecord.appName) { record in
                HStack(spacing: 8) {
                    Image(nsImage: AppIconCache.shared.icon(for: record.appName))
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text(record.appName)
                }
            }
            TableColumn("Downloaded") { Text(formatBytes($0.downloaded)) }
                .width(120)
            TableColumn("Uploaded") { Text(formatBytes($0.uploaded)) }
                .width(120)
            TableColumn("Total") { Text(formatBytes($0.total)).bold() }
                .width(120)
        }
    }
}
