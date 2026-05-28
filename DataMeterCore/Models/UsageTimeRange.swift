import Foundation

public enum UsageTimeRange: String, CaseIterable, Identifiable, Sendable {
    case session
    case today
    case week
    case month
    case allTime

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .session: "Session"
        case .today: "Today"
        case .week: "This Week"
        case .month: "This Month"
        case .allTime: "All Time"
        }
    }

    public func startDate(sessionStartedAt: Date, now: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch self {
        case .session:
            sessionStartedAt
        case .today:
            calendar.startOfDay(for: now)
        case .week:
            calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        case .month:
            calendar.dateInterval(of: .month, for: now)?.start ?? calendar.startOfDay(for: now)
        case .allTime:
            nil
        }
    }
}
