import AppKit
import InputMethodKit

@MainActor @objc(AppDelegate)
class AppDelegate: NSObject, NSApplicationDelegate {
    private var server: IMKServer!
    private var statusBarController: StatusBarController!
    private var inputSourceSwitcher: InputSourceSwitcher?
    func applicationDidFinishLaunching(_: Notification) {
        Log.appDelegate.info("applicationDidFinishLaunching called")

        guard let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String else {
            Log.appDelegate.error("Failed to read InputMethodConnectionName from Info.plist")
            return
        }

        // Verify InputController is discoverable by IMKServer
        if let controllerClass = Bundle.main.infoDictionary?["InputMethodServerControllerClass"] as? String {
            let resolved: AnyClass? = NSClassFromString(controllerClass)
            Log.appDelegate.info("InputMethodServerControllerClass = '\(controllerClass, privacy: .public)' → NSClassFromString → \(resolved.map { String(describing: $0) } ?? "nil (class not found!)", privacy: .public)")
        }

        Log.appDelegate.info("Starting IMKServer with connection name: \(connectionName, privacy: .public)")

        server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)

        Log.appDelegate.info("IMKServer created successfully")

        statusBarController = StatusBarController()

        inputSourceSwitcher = InputSourceSwitcher()
    }

    func applicationWillTerminate(_: Notification) {
        Log.appDelegate.info("Application terminating")
    }
}
