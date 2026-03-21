import os

/// Thread-safe counter for tracking notification delivery in tests.
final class NotificationCounter: Sendable {
    private let _count = OSAllocatedUnfairLock(initialState: 0)
    var count: Int {
        _count.withLock { $0 }
    }

    func increment() {
        _count.withLock { $0 += 1 }
    }
}
