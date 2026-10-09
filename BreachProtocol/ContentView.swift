import SwiftUI

private enum Theme {
    static let bg = Color(red: 0.025, green: 0.04, blue: 0.055)
    static let panel = Color(red: 0.045, green: 0.075, blue: 0.09)
    static let cyan = Color(red: 0.12, green: 0.88, blue: 0.98)
    static let muted = Color(red: 0.42, green: 0.58, blue: 0.64)
    static let amber = Color(red: 1, green: 0.72, blue: 0.28)
    static let red = Color(red: 1, green: 0.32, blue: 0.34)
}

private struct TerminalLine: Identifiable, Codable {
    var id = UUID()
    var text: String
    var kind: String = "normal"
}

private struct SaveData: Codable {
    var lines: [TerminalLine]
    var discovered: [String]
    var chapterComplete: Bool
}

struct ContentView: View {
    @AppStorage("bp_hasSave") private var hasSave = false
    @State private var input = ""
    @State private var lines: [TerminalLine] = [
        TerminalLine(text: "BREACH PROTOCOL // FIELD TERMINAL v1.0", kind: "system"),
        TerminalLine(text: "Secure session established.", kind: "muted"),
        TerminalLine(text: "INCOMING MESSAGE: IF YOU CAN READ THIS, THEY ALREADY KNOW.", kind: "warning"),
        TerminalLine(text: "Type 'help' to view available commands.", kind: "muted")
    ]
    @State private var discovered: Set<String> = []
    @State private var chapterComplete = false
    @State private var showEvidence = false
    @FocusState private var inputFocused: Bool

    private let fileNames = ["incident_2049.log", "signal_fragment.dat", "personnel.enc"]

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                statusStrip
                terminal
                commandBar
            }
        }
        .preferredColorScheme(.dark)
        .onAppear(perform: loadGame)
        .sheet(isPresented: $showEvidence) {
            evidenceSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Theme.cyan.opacity(0.75), lineWidth: 1)
                    .frame(width: 38, height: 38)
                Image(systemName: "terminal.fill").foregroundStyle(Theme.cyan)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("BREACH PROTOCOL")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .tracking(1.2).foregroundStyle(.white)
                Text("NARRATIVE TERMINAL // CH.01")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1).foregroundStyle(Theme.muted)
            }
            Spacer()
            Circle().fill(chapterComplete ? Theme.amber : Theme.cyan).frame(width: 7, height: 7)
            Text(chapterComplete ? "CLEARED" : "ONLINE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(chapterComplete ? Theme.amber : Theme.cyan)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .background(Theme.panel)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.cyan.opacity(0.25)).frame(height: 1) }
    }

    private var statusStrip: some View {
        HStack {
            Label("AEGIS / RESTRICTED", systemImage: "lock.fill")
            Spacer()
            Text("EVIDENCE \(discovered.count)/3").foregroundStyle(Theme.cyan)
            Button { showEvidence = true } label: {
                Image(systemName: "folder.badge.questionmark").foregroundStyle(Theme.cyan)
            }
            .accessibilityLabel("Open evidence")
        }
        .font(.system(size: 9, weight: .medium, design: .monospaced))
        .tracking(0.5).foregroundStyle(Theme.muted)
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var terminal: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 9) {
                    ForEach(lines) { line in
                        Text(line.text)
                            .font(.system(size: 12, weight: line.kind == "system" ? .bold : .regular, design: .monospaced))
                            .foregroundStyle(color(for: line.kind))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                    Color.clear.frame(height: 1).id("BOTTOM")
                }.padding(15)
            }
            .onChange(of: lines.count) { _, _ in
                withAnimation(.easeOut(duration: 0.18)) { proxy.scrollTo("BOTTOM", anchor: .bottom) }
            }
        }
        .background(Theme.bg)
    }

    private var commandBar: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    quickCommand("help")
                    quickCommand("status")
                    quickCommand("files list")
                    quickCommand("evidence")
                }
            }
            HStack(spacing: 9) {
                Text(">").font(.system(size: 17, weight: .bold, design: .monospaced)).foregroundStyle(Theme.cyan)
                TextField("Enter command…", text: $input)
                    .font(.system(size: 14, design: .monospaced)).foregroundStyle(.white)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .submitLabel(.send).focused($inputFocused).onSubmit(submitCommand)
                    .accessibilityLabel("Game command")
                Button(action: submitCommand) {
                    Image(systemName: "arrow.up").font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.bg).frame(width: 37, height: 37)
                        .background(Theme.cyan).clipShape(RoundedRectangle(cornerRadius: 9))
                }.accessibilityLabel("Run command")
            }
            .padding(.leading, 13).padding(.trailing, 6).padding(.vertical, 6)
            .background(Theme.panel).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cyan.opacity(0.3), lineWidth: 1))
        }
        .padding(.horizontal, 13).padding(.top, 10).padding(.bottom, 12)
        .background(Theme.panel.opacity(0.8))
        .overlay(alignment: .top) { Rectangle().fill(Theme.cyan.opacity(0.2)).frame(height: 1) }
    }

    private var evidenceSheet: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                List {
                    if discovered.isEmpty {
                        Text("No evidence collected yet. Explore files from the terminal.")
                            .foregroundStyle(Theme.muted).listRowBackground(Theme.panel)
                    }
                    ForEach(discovered.sorted(), id: \.self) { item in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.uppercased())
                                .font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(Theme.cyan)
                            Text(evidenceDescription(item))
                                .font(.system(size: 12, design: .monospaced)).foregroundStyle(.white.opacity(0.8))
                        }.listRowBackground(Theme.panel)
                    }
                }.scrollContentBackground(.hidden)
            }
            .navigationTitle("EVIDENCE FILE").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showEvidence = false }.foregroundStyle(Theme.cyan)
                }
            }
        }.preferredColorScheme(.dark)
    }

    private func quickCommand(_ command: String) -> some View {
        Button(command) { input = command; submitCommand() }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(Theme.cyan).padding(.horizontal, 10).padding(.vertical, 7)
            .background(Theme.cyan.opacity(0.08)).clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.cyan.opacity(0.25), lineWidth: 1))
    }

    private func color(for kind: String) -> Color {
        switch kind {
        case "system", "success": return Theme.cyan
        case "muted": return Theme.muted
        case "warning": return Theme.amber
        case "error": return Theme.red
        default: return Color(red: 0.78, green: 0.86, blue: 0.88)
        }
    }

    private func add(_ text: String, _ kind: String = "normal") {
        lines.append(TerminalLine(text: text, kind: kind))
        if lines.count > 300 { lines.removeFirst(lines.count - 300) }
        saveGame()
    }

    private func submitCommand() {
        let command = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }
        input = ""
        add("operator@bp:~$ \(command)", "muted")
        run(command.lowercased())
    }

    private func run(_ raw: String) {
        let parts = raw.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let first = parts.first else { return }
        switch first {
        case "help":
            add("AVAILABLE COMMANDS", "system")
            add("help                 Show this command list")
            add("status               Mission status")
            add("files list           List available files")
            add("files read <name>    Read an evidence file")
            add("logs search <word>   Search discovered records")
            add("evidence             Review collected clues")
            add("decode <answer>      Submit the Chapter 01 cipher")
            add("clear                Clear visible terminal")
            add("restart              Reset Chapter 01 progress")
        case "status":
            add("MISSION: UNKNOWN SIGNAL", "system")
            add("SESSION: ACTIVE")
            add("CHAPTER: 01 / UNKNOWN SIGNAL")
            add("EVIDENCE: \(discovered.count)/3")
            add("OBJECTIVE: Identify the origin of the 03:17 signal.")
            if chapterComplete { add("CHAPTER STATUS: COMPLETE", "success") }
        case "files":
            guard parts.count >= 2 else { add("Usage: files list | files read <name>", "warning"); return }
            if parts[1] == "list" {
                add("ARCHIVE DIRECTORY // 3 ENTRIES", "system")
                fileNames.forEach { add("[FILE] \($0)", discovered.contains($0) ? "success" : "normal") }
            } else if parts[1] == "read" {
                guard parts.count >= 3 else { add("Usage: files read <name>", "warning"); return }
                readFile(parts.dropFirst(2).joined(separator: " "))
            } else { add("Unknown files operation. Try 'files list'.", "error") }
        case "logs":
            guard parts.count >= 3, parts[1] == "search" else { add("Usage: logs search <word>", "warning"); return }
            let term = parts.dropFirst(2).joined(separator: " ")
            let hasRecords = !discovered.isEmpty
            guard hasRecords else { add("No indexed records. Read a file first.", "warning"); return }
            if ["03:17", "internal", "node", "signal", "*", "aegis"].contains(term) {
                add("MATCH: signal detected at 03:17", "success")
                add("MATCH: origin classified as INTERNAL NODE", "success")
                add("MATCH: operator ID withheld", "success")
            } else { add("No matches for '\(term)'.", "warning") }
        case "evidence":
            if discovered.isEmpty { add("No evidence collected. Try 'files list'.", "warning") }
            else {
                add("EVIDENCE REGISTER // \(discovered.count) ITEM(S)", "system")
                discovered.sorted().forEach { add("[CONFIRMED] \($0)", "success") }
                showEvidence = true
            }
        case "decode":
            let answer = parts.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if discovered.count >= 2 && ["internal node", "internal", "node"].contains(answer) {
                chapterComplete = true
                add("CIPHER ACCEPTED.", "success")
                add("CHAPTER 01 COMPLETE // SIGNAL ORIGIN: INTERNAL NODE", "system")
                add("A new message appears: 'You found the door. Now find who opened it.'", "warning")
                add("CHAPTER 02 is locked in this build. Your progress has been saved.", "muted")
            } else if discovered.count < 2 {
                add("INSUFFICIENT EVIDENCE. Read at least two archive files.", "warning")
            } else { add("DECODE FAILED. Re-examine the records and search the logs.", "error") }
        case "clear":
            lines = [TerminalLine(text: "Terminal cleared. Progress remains saved.", kind: "muted")]
            saveGame()
        case "restart":
            discovered.removeAll()
            chapterComplete = false
            lines = [
                TerminalLine(text: "BREACH PROTOCOL // FIELD TERMINAL v1.0", kind: "system"),
                TerminalLine(text: "New investigation initialized.", kind: "muted"),
                TerminalLine(text: "INCOMING MESSAGE: IF YOU CAN READ THIS, THEY ALREADY KNOW.", kind: "warning")
            ]
            saveGame()
        default: add("Command not found: \(first). Type 'help' for available commands.", "error")
        }
    }

    private func readFile(_ name: String) {
        guard fileNames.contains(name) else {
            add("FILE NOT FOUND. Use 'files list' to see available records.", "error")
            return
        }
        discovered.insert(name)
        switch name {
        case "incident_2049.log":
            add("OPENING incident_2049.log", "system")
            add("03:17 // SIGNAL DETECTED")
            add("Origin field: INTERNAL NODE")
            add("Incident marked for deletion 00:04 after detection.")
        case "signal_fragment.dat":
            add("DECODING signal_fragment.dat", "system")
            add("FRAGMENT: 03-17 / IN-TERNAL / NODE")
            add("Metadata: source route begins inside the AEGIS network.")
        case "personnel.enc":
            add("READING personnel.enc", "system")
            add("ACCESS RESTRICTED // PARTIAL CACHE RECOVERED")
            add("A staff credential was active at 03:17.")
            add("The operator's identity is missing from the official roster.")
        default: break
        }
        add("EVIDENCE ADDED: \(name)", "success")
        saveGame()
    }

    private func evidenceDescription(_ item: String) -> String {
        switch item {
        case "incident_2049.log": return "Incident log: signal detected at 03:17; origin field says INTERNAL NODE."
        case "signal_fragment.dat": return "Signal fragment: route begins inside the AEGIS network."
        case "personnel.enc": return "Personnel cache: an unlisted credential was active at 03:17."
        default: return "Recovered record."
        }
    }

    private func saveGame() {
        let data = SaveData(lines: lines, discovered: Array(discovered), chapterComplete: chapterComplete)
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "bp_save_data")
            hasSave = true
        }
    }

    private func loadGame() {
        guard hasSave,
              let data = UserDefaults.standard.data(forKey: "bp_save_data"),
              let saved = try? JSONDecoder().decode(SaveData.self, from: data) else { return }
        lines = saved.lines
        discovered = Set(saved.discovered)
        chapterComplete = saved.chapterComplete
    }
}
