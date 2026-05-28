import SwiftUI

struct EmptyUsageView: View {
    let isRunning: Bool

    var body: some View {
        ContentUnavailableView {
            Label(isRunning ? "Collecting usage" : "Tracking paused", systemImage: "antenna.radiowaves.left.and.right")
        } description: {
            Text(isRunning ? "Data appears after the second network sample. Try using the internet for a few seconds." : "Start tracking to collect network usage.")
        }
    }
}
