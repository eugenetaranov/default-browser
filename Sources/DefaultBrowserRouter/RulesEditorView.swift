import SwiftUI
import RouterCore

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - Editable model

/// The condition kinds exposed in the editor, mapped to/from `RouterCore.Condition`.
enum ConditionType: String, CaseIterable, Identifiable {
    case domain, prefix, contains, equals, regex, sourceApp
    var id: String { rawValue }

    var label: String {
        switch self {
        case .domain: return "Domain is"
        case .prefix: return "URL starts with"
        case .contains: return "URL contains"
        case .equals: return "URL equals"
        case .regex: return "URL matches regex"
        case .sourceApp: return "Source app is"
        }
    }

    var placeholder: String {
        switch self {
        case .domain: return "amazon.com"
        case .prefix: return "https://meet.google.com/"
        case .contains: return "facebook"
        case .equals: return "https://example.com/"
        case .regex: return #"^https://.*\.slack\.com/"#
        case .sourceApp: return "Mail"
        }
    }

    func condition(_ value: String) -> Condition {
        switch self {
        case .domain: return .domain(value)
        case .prefix: return .urlPrefix(value)
        case .contains: return .urlContains(value)
        case .equals: return .urlEquals(value)
        case .regex: return .urlRegex(value)
        case .sourceApp: return .sourceApp(value)
        }
    }

    init(from condition: Condition) {
        switch condition {
        case .domain: self = .domain
        case .urlPrefix: self = .prefix
        case .urlContains: self = .contains
        case .urlEquals: self = .equals
        case .urlRegex: self = .regex
        case .sourceApp: self = .sourceApp
        }
    }
}

final class EditableCondition: Identifiable, ObservableObject {
    let id = UUID()
    @Published var type: ConditionType
    @Published var value: String
    init(type: ConditionType = .domain, value: String = "") {
        self.type = type
        self.value = value
    }
}

final class EditableRule: Identifiable, ObservableObject {
    let id = UUID()
    @Published var match: MatchMode
    @Published var conditions: [EditableCondition]
    @Published var browser: String
    init(match: MatchMode = .all, conditions: [EditableCondition] = [EditableCondition()], browser: String = "") {
        self.match = match
        self.conditions = conditions
        self.browser = browser
    }
}

/// Transient result of the last save, driving the footer confirmation.
enum SaveState: Equatable {
    case idle
    case saved
    case failed(String)
}

/// View model bridging the editor to the on-disk YAML config.
final class RulesViewModel: ObservableObject {
    @Published var defaultBrowser: String = "Brave"
    @Published var rules: [EditableRule] = []
    @Published var saveState: SaveState = .idle

    let browsers: [String]
    private let store: ConfigStore

    init(store: ConfigStore = ConfigStore()) {
        self.store = store
        self.browsers = InstalledBrowsers.names()
    }

    func load() {
        guard let config = try? store.load() else { return }
        defaultBrowser = config.defaultBrowser
        rules = config.rules.map { rule in
            EditableRule(
                match: rule.match,
                conditions: rule.conditions.map { EditableCondition(type: ConditionType(from: $0), value: $0.value) },
                browser: rule.browser
            )
        }
        saveState = .idle
    }

    func addRule() {
        rules.append(EditableRule(browser: defaultBrowser))
    }

    func save() {
        let config = Config(
            defaultBrowser: defaultBrowser.trimmed,
            rules: rules.compactMap { r in
                let conds = r.conditions
                    .filter { !$0.value.trimmed.isEmpty }
                    .map { $0.type.condition($0.value.trimmed) }
                guard !conds.isEmpty, !r.browser.trimmed.isEmpty else { return nil }
                return Rule(match: r.match, conditions: conds, browser: r.browser.trimmed)
            }
        )
        do {
            try store.save(config)
            saveState = .saved
        } catch {
            saveState = .failed("\(error)")
        }
    }

    /// Options for a browser picker, always including the current value.
    func browserOptions(including current: String) -> [String] {
        var opts = browsers
        let c = current.trimmed
        if !c.isEmpty && !opts.contains(c) { opts.insert(c, at: 0) }
        return opts
    }
}

// MARK: - Views

struct RulesEditorView: View {
    @ObservedObject var model: RulesViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Default browser").font(.headline)
                        BrowserPicker(selection: $model.defaultBrowser,
                                      options: model.browserOptions(including: model.defaultBrowser))
                        Spacer()
                    }
                    Divider()
                    ForEach(model.rules) { rule in
                        RuleCardView(rule: rule, model: model) {
                            model.rules.removeAll { $0.id == rule.id }
                        }
                    }
                    Button {
                        model.addRule()
                    } label: {
                        Label("Add Rule", systemImage: "plus.circle")
                    }
                    .buttonStyle(.link)
                }
                .padding(20)
            }
            Divider()
            HStack {
                saveConfirmation
                Spacer()
                Button("Save") { model.save() }
                    .keyboardShortcut("s", modifiers: .command)
            }
            .padding(12)
            .animation(.spring(response: 0.35, dampingFraction: 0.6), value: model.saveState)
            .onChange(of: model.saveState) { state in
                guard state == .saved else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                    if model.saveState == .saved {
                        withAnimation(.easeInOut(duration: 0.35)) { model.saveState = .idle }
                    }
                }
            }
        }
        .frame(minWidth: 560, minHeight: 420)
    }

    @ViewBuilder private var saveConfirmation: some View {
        switch model.saveState {
        case .saved:
            Label("Saved", systemImage: "checkmark.circle.fill")
                .font(.callout.weight(.medium))
                .foregroundColor(.green)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(.red)
                .lineLimit(1)
                .truncationMode(.middle)
        case .idle:
            EmptyView()
        }
    }
}

private struct RuleCardView: View {
    @ObservedObject var rule: EditableRule
    let model: RulesViewModel
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("", selection: $rule.match) {
                    Text("All").tag(MatchMode.all)
                    Text("Any").tag(MatchMode.any)
                }
                .frame(width: 90)
                .labelsHidden()
                Text("of the following are true:").foregroundColor(.secondary)
                Spacer()
                Button(action: onDelete) { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
            }
            ForEach(rule.conditions) { cond in
                ConditionRowView(condition: cond) {
                    rule.conditions.removeAll { $0.id == cond.id }
                }
            }
            HStack {
                Button {
                    rule.conditions.append(EditableCondition())
                } label: {
                    Label("Add condition", systemImage: "plus")
                }
                .buttonStyle(.link)
                Spacer()
                Text("→ open in").foregroundColor(.secondary)
                BrowserPicker(selection: $rule.browser,
                              options: model.browserOptions(including: rule.browser))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
    }
}

private struct ConditionRowView: View {
    @ObservedObject var condition: EditableCondition
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Picker("", selection: $condition.type) {
                ForEach(ConditionType.allCases) { t in
                    Text(t.label).tag(t)
                }
            }
            .frame(width: 170)
            .labelsHidden()
            TextField(condition.type.placeholder, text: $condition.value)
                .textFieldStyle(.roundedBorder)
            Button(action: onDelete) { Image(systemName: "minus.circle") }
                .buttonStyle(.borderless)
        }
    }
}

private struct BrowserPicker: View {
    @Binding var selection: String
    let options: [String]

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options, id: \.self) { Text($0).tag($0) }
        }
        .frame(width: 160)
        .labelsHidden()
    }
}
