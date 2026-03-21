import AppKit
import os

@MainActor @objc(NSManualApplication)
class NSManualApplication: NSApplication {
    private let appDelegate = AppDelegate()

    override init() {
        super.init()
        delegate = appDelegate
        Log.nsManualApp.info("NSManualApplication.init() called — delegate set to \(String(describing: type(of: self.appDelegate)), privacy: .public)")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
