import os

enum Log {
    static let appDelegate = Logger(subsystem: subsystem, category: "AppDelegate")
    static let inputController = Logger(subsystem: subsystem, category: "InputController")
    static let inputSwitcher = Logger(subsystem: subsystem, category: "InputSourceSwitcher")
    static let kenLM = Logger(subsystem: subsystem, category: "KenLMPredictor")
    static let languageManager = Logger(subsystem: subsystem, category: "LanguageManager")
    static let nsManualApp = Logger(subsystem: subsystem, category: "NSManualApplication")
    static let settingsManager = Logger(subsystem: subsystem, category: "SettingsManager")
    static let spellCheck = Logger(subsystem: subsystem, category: "SpellCheckPredictor")
    static let startup = Logger(subsystem: subsystem, category: "startup")

    private static let subsystem = Bundle.main.bundleIdentifier!
}
