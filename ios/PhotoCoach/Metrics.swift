import os

/// Phase 1 baseline instrumentation (TRD §9). Read in Console/Xcode logs (category "metrics")
/// or as Points of Interest in Instruments.
enum Metrics {
    static let launch = ContinuousClock.now
    static let log = Logger(subsystem: "com.travischeung.photocoach", category: "metrics")
    static let signposter = OSSignposter(subsystem: "com.travischeung.photocoach", category: .pointsOfInterest)
}

extension Duration {
    var ms: Int { Int(self / .milliseconds(1)) }
}
