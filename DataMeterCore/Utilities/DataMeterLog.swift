import OSLog

public enum DataMeterLog {
    public static let sampling = Logger(subsystem: "com.emmanuelchucks.DataMeter", category: "sampling")
    public static let storage = Logger(subsystem: "com.emmanuelchucks.DataMeter", category: "storage")
    public static let shell = Logger(subsystem: "com.emmanuelchucks.DataMeter", category: "shell")
    public static let network = Logger(subsystem: "com.emmanuelchucks.DataMeter", category: "network")
}
