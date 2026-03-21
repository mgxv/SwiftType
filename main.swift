import AppKit

// Create the application instance.
// In Release builds, NSPrincipalClass creates NSManualApplication which sets the delegate.
// In Debug builds, Xcode's preview dylib may pre-create a plain NSApplication,
// so we fall back to setting the delegate explicitly.
_ = NSApplication.shared

let appDelegate: NSApplicationDelegate
if let existing = NSApp.delegate {
    appDelegate = existing
} else {
    Log.startup.info("NSManualApplication was not used (NSApp.delegate is nil) — setting delegate manually")
    let delegate = AppDelegate()
    NSApp.delegate = delegate
    appDelegate = delegate
}

Log.startup.info("NSApplication.shared type = \(String(describing: type(of: NSApp!)), privacy: .public), delegate = \(String(describing: type(of: appDelegate)), privacy: .public)")

// appDelegate strong reference keeps delegate alive for the app's lifetime
NSApp.run()
