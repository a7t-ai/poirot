import SwiftUI

struct SubAgentFormView: View {
    let existingAgent: SubAgent?
    let onSave: (SubAgent) -> Void

    @State
    private var name: String
    @State
    private var descriptionText: String
    @State
    private var model: String
    @State
    private var selectedColor: AgentColor
    @State
    private var selectedTools: Set<String>
    @State
    private var selectedMemory: AgentMemory
    @State
    private var prompt: String
    @State
    private var showIndividualTools = false

    @Environment(\.dismiss)
    private var dismiss

    init(
        existingAgent: SubAgent? = nil,
        onSave: @escaping (SubAgent) -> Void
    ) {
        self.existingAgent = existingAgent
        self.onSave = onSave
        _name = State(initialValue: existingAgent?.name ?? "")
        _descriptionText = State(initialValue: existingAgent?.description ?? "")
        _model = State(initialValue: existingAgent?.model ?? "sonnet")
        _selectedColor = State(initialValue: existingAgent?.color ?? .orange)
        _selectedTools = State(initialValue: Set(existingAgent?.tools ?? ["Glob", "Grep", "Read", "Bash"]))
        _selectedMemory = State(initialValue: existingAgent?.memory ?? .user)
        _prompt = State(initialValue: existingAgent?.prompt ?? "")
    }

    private var isEditing: Bool { existingAgent != nil }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !descriptionText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text(isEditing ? "Edit Agent" : "New Agent")
                .font(PoirotTheme.Typography.headingSmall)
                .foregroundStyle(PoirotTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(PoirotTheme.Spacing.lg)

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xl) {
                    nameSection
                    filePathSection
                    descriptionSection
                    modelSection
                    colorSection
                    toolsSection
                    memorySection
                    promptSection
                }
                .padding(PoirotTheme.Spacing.lg)
            }

            Divider()

            // Actions
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .help("Cancel")
                Button(isEditing ? "Save" : "Create") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
                    .help(isEditing ? "Save agent" : "Create agent")
            }
            .padding(PoirotTheme.Spacing.lg)
        }
        .frame(width: 520, height: 700)
        .background(PoirotTheme.Colors.bgApp)
    }

    private var derivedFilename: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "" }
        return trimmed
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }

    // MARK: - Sections

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
            Text("Name")
                .font(PoirotTheme.Typography.captionMedium)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)
            TextField("Agent name", text: $name)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var filePathSection: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
            Text("File")
                .font(PoirotTheme.Typography.captionMedium)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)
            Text(derivedFilename.isEmpty ? "\u{2014}" : "~/.claude/agents/\(derivedFilename).md")
                .font(PoirotTheme.Typography.codeSmall)
                .foregroundStyle(PoirotTheme.Colors.textTertiary)
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
            Text("Description")
                .font(PoirotTheme.Typography.captionMedium)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)
            TextField("What does this agent do?", text: $descriptionText)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
            Text("Model")
                .font(PoirotTheme.Typography.captionMedium)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)
            Picker("Model", selection: $model) {
                Text("Opus").tag("opus")
                Text("Sonnet").tag("sonnet")
                Text("Haiku").tag("haiku")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
            Text("Color")
                .font(PoirotTheme.Typography.captionMedium)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)
            HStack(spacing: PoirotTheme.Spacing.sm) {
                ForEach(AgentColor.allCases, id: \.self) { color in
                    Button {
                        selectedColor = color
                    } label: {
                        Circle()
                            .fill(themeColor(for: color))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .strokeBorder(
                                        PoirotTheme.Colors.textPrimary,
                                        lineWidth: selectedColor == color ? 2 : 0
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .help(color.label)
                }
            }
        }
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.sm) {
            HStack {
                Text("Tools")
                    .font(PoirotTheme.Typography.captionMedium)
                    .foregroundStyle(PoirotTheme.Colors.textSecondary)
                Spacer()
                Text("\(selectedTools.count) of \(SubAgent.knownTools.count)")
                    .font(PoirotTheme.Typography.micro)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }

            Toggle(isOn: allToolsBinding) {
                Text("All tools")
                    .font(PoirotTheme.Typography.bodyMedium)
            }
            .toggleStyle(.checkbox)

            ForEach(SubAgent.toolCategories) { category in
                Toggle(isOn: categoryBinding(for: category)) {
                    Text(category.name)
                        .font(PoirotTheme.Typography.body)
                }
                .toggleStyle(.checkbox)
                .padding(.leading, PoirotTheme.Spacing.md)
            }

            DisclosureGroup(isExpanded: $showIndividualTools) {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), alignment: .leading),
                        GridItem(.flexible(), alignment: .leading),
                        GridItem(.flexible(), alignment: .leading),
                    ],
                    spacing: PoirotTheme.Spacing.xs
                ) {
                    ForEach(SubAgent.knownTools, id: \.self) { tool in
                        Toggle(isOn: Binding(
                            get: { selectedTools.contains(tool) },
                            set: { isOn in
                                if isOn {
                                    selectedTools.insert(tool)
                                } else {
                                    selectedTools.remove(tool)
                                }
                            }
                        )) {
                            Text(tool)
                                .font(PoirotTheme.Typography.codeSmall)
                        }
                        .toggleStyle(.checkbox)
                    }
                }
                .padding(.top, PoirotTheme.Spacing.xs)
            } label: {
                Text("Show individual tools")
                    .font(PoirotTheme.Typography.caption)
                    .foregroundStyle(PoirotTheme.Colors.textTertiary)
            }
        }
    }

    private var allToolsBinding: Binding<Bool> {
        Binding(
            get: { selectedTools.count == SubAgent.knownTools.count },
            set: { isOn in
                if isOn {
                    selectedTools = Set(SubAgent.knownTools)
                } else {
                    selectedTools.removeAll()
                }
            }
        )
    }

    private func categoryBinding(for category: ToolCategory) -> Binding<Bool> {
        Binding(
            get: { category.tools.allSatisfy { selectedTools.contains($0) } },
            set: { isOn in
                if isOn {
                    category.tools.forEach { selectedTools.insert($0) }
                } else {
                    category.tools.forEach { selectedTools.remove($0) }
                }
            }
        )
    }

    private var memorySection: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
            Text("Memory")
                .font(PoirotTheme.Typography.captionMedium)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)
            Picker("Memory", selection: $selectedMemory) {
                ForEach(AgentMemory.allCases, id: \.self) { memory in
                    Text(memory.label).tag(memory)
                }
            }
            .labelsHidden()
        }
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: PoirotTheme.Spacing.xs) {
            Text("System Prompt")
                .font(PoirotTheme.Typography.captionMedium)
                .foregroundStyle(PoirotTheme.Colors.textSecondary)
            TextEditor(text: $prompt)
                .font(PoirotTheme.Typography.code)
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .padding(PoirotTheme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                        .fill(PoirotTheme.Colors.bgCode)
                        .overlay(
                            RoundedRectangle(cornerRadius: PoirotTheme.Radius.sm)
                                .strokeBorder(PoirotTheme.Colors.border)
                        )
                )
        }
    }

    // MARK: - Actions

    private func save() {
        let agent = SubAgent(
            id: existingAgent?.id ?? UUID().uuidString,
            name: name.trimmingCharacters(in: .whitespaces),
            icon: "person.crop.circle.badge.plus",
            description: descriptionText.trimmingCharacters(in: .whitespaces),
            tools: SubAgent.knownTools.filter { selectedTools.contains($0) },
            model: model,
            color: selectedColor,
            prompt: prompt.isEmpty ? nil : prompt,
            filePath: existingAgent?.filePath,
            memory: selectedMemory,
            scope: .global
        )
        onSave(agent)
        dismiss()
    }

    private func themeColor(for color: AgentColor) -> Color {
        switch color {
        case .orange: PoirotTheme.Colors.orange
        case .red: PoirotTheme.Colors.red
        case .blue: PoirotTheme.Colors.blue
        case .green: PoirotTheme.Colors.green
        case .purple: PoirotTheme.Colors.purple
        case .teal: PoirotTheme.Colors.teal
        }
    }
}
