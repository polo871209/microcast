import Foundation

enum BackupCategory: String, CaseIterable, Identifiable, Sendable {
    case configuration
    case clipboard
    case notes
    case learning

    var id: Self { self }

    struct Descriptor: Sendable {
        let label: String
        let symbol: String
        let subpath: String
        let countNoun: String?
    }

    var descriptor: Descriptor {
        switch self {
        case .configuration:
            return .init(
                label: "Settings & Shortcuts", symbol: "slider.horizontal.3", subpath: "",
                countNoun: nil)
        case .clipboard:
            return .init(
                label: "Clipboard History", symbol: "doc.on.clipboard", subpath: "clipboard",
                countNoun: "clips")
        case .notes:
            return .init(label: "Notes", symbol: "note.text", subpath: "notes", countNoun: "notes")
        case .learning:
            return .init(
                label: "Launcher Learning", symbol: "chart.line.uptrend.xyaxis",
                subpath: "learning", countNoun: "records")
        }
    }

    static let all = Set(BackupCategory.allCases)

    static func ordered(_ selection: Set<BackupCategory>) -> [BackupCategory] {
        allCases.filter(selection.contains)
    }
}
