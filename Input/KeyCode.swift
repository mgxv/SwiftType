/// Hardware key codes (keyboard-layout-independent)
enum KeyCode: UInt16, Sendable {
    case key1 = 18
    case key2 = 19
    case key3 = 20
    case key4 = 21
    case key5 = 23
    case key6 = 22
    case key7 = 26
    case backspace = 51
    case escape = 53
    case returnKey = 36
    case space = 49
    case tab = 48
    case leftArrow = 123
    case rightArrow = 124
    case downArrow = 125
    case upArrow = 126

    static let candidateKeys: [KeyCode] = [.key1, .key2, .key3, .key4, .key5, .key6, .key7]
    static let navigationKeys: Set<KeyCode> = [.tab, .leftArrow, .rightArrow, .upArrow, .downArrow]
    /// Keys that advance the active column to the right within the current row.
    /// `.downArrow` is intentionally excluded — it navigates rows in the grid, not columns.
    static let selectNextKeys: Set<KeyCode> = [.tab, .rightArrow]
    /// Keys that move the active column to the left within the current row.
    /// `.upArrow` is intentionally excluded — it navigates rows in the grid, not columns.
    static let selectPreviousKeys: Set<KeyCode> = [.leftArrow]

    private static let digitMap: [KeyCode: Int] =
        Dictionary(uniqueKeysWithValues: candidateKeys.enumerated().map { ($0.element, $0.offset + 1) })

    /// The 1-based digit for candidate keys (e.g. .key1 → 1), nil for non-candidate keys.
    var digit: Int? {
        KeyCode.digitMap[self]
    }
}
