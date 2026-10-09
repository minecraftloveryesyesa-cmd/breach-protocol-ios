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
    @AppStorage("bp_language") private var language = "ja"
    private var isJapanese: Bool { language == "ja" }
    @State private var input = ""
    @State private var lines: [TerminalLine] = [
        TerminalLine(text: "BREACH PROTOCOL // FIELD TERMINAL v1.0", kind: "system"),
        TerminalLine(text: "Secure session established.", kind: "muted"),
        TerminalLine(text: "INCOMING MESSAGE: IF YOU CAN READ THIS, THEY ALREADY KNOW.", kind: "warning"),
        TerminalLine(text: "Type 'help' to view available commands.", kind: "muted")
    ]
    @State private var discovered: Set<String> = []
    @State private var chapterComplete = false
    @State private var hintLevel = 0
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
                Text(isJapanese ? "ストーリー端末 // 第01章" : "NARRATIVE TERMINAL // CH.01")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1).foregroundStyle(Theme.muted)
            }
            Button { language = isJapanese ? "en" : "ja" } label: {
                Text(isJapanese ? "日本語 / EN" : "EN / 日本語")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.cyan)
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .overlay(Capsule().stroke(Theme.cyan.opacity(0.45), lineWidth: 1))
            }
            Spacer()
            Circle().fill(chapterComplete ? Theme.amber : Theme.cyan).frame(width: 7, height: 7)
            Text(chapterComplete ? (isJapanese ? "攻略完了" : "CLEARED") : (isJapanese ? "接続中" : "ONLINE"))
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(chapterComplete ? Theme.amber : Theme.cyan)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
        .background(Theme.panel)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.cyan.opacity(0.25)).frame(height: 1) }
    }

    private var statusStrip: some View {
        HStack {
            Label(isJapanese ? "AEGIS / 機密区分" : "AEGIS / RESTRICTED", systemImage: "lock.fill")
            Spacer()
            Text("EVIDENCE \(discovered.count)/3").foregroundStyle(Theme.cyan)
            Button { showEvidence = true } label: {
                Image(systemName: "folder.badge.questionmark").foregroundStyle(Theme.cyan)
            }
            .accessibilityLabel(isJapanese ? "証拠を開く" : "Open evidence")
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
                TextField(isJapanese ? "コマンドを入力…" : "Enter command…", text: $input)
                    .font(.system(size: 14, design: .monospaced)).foregroundStyle(.white)
                    .autocorrectionDisabled().textInputAutocapitalization(.never)
                    .submitLabel(.send).focused($inputFocused).onSubmit(submitCommand)
                    .accessibilityLabel(isJapanese ? "ゲームコマンド" : "Game command")
                Button(action: submitCommand) {
                    Image(systemName: "arrow.up").font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.bg).frame(width: 37, height: 37)
                        .background(Theme.cyan).clipShape(RoundedRectangle(cornerRadius: 9))
                }.accessibilityLabel(isJapanese ? "コマンドを実行" : "Run command")
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
                        Text(isJapanese ? "証拠はまだありません。端末からファイルを調査してください。" : "No evidence collected yet. Explore files from the terminal.")
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
            .navigationTitle(isJapanese ? "証拠ファイル" : "EVIDENCE FILE").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isJapanese ? "閉じる" : "Done") { showEvidence = false }.foregroundStyle(Theme.cyan)
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
        lines.append(TerminalLine(text: localized(text), kind: kind))
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
            if parts.count > 1 {
                showCommandHelp(parts.dropFirst().joined(separator: " "))
                return
            }
            add("AVAILABLE COMMANDS", "system")
            add("help [command]       Show detailed command help")
            add("hint                 Get a progressive puzzle hint")
            add("status               Mission status")
            add("files list           List available files")
            add("files read <name>    Read an evidence file")
            add("logs search <word>   Search discovered records")
            add("evidence             Review collected clues")
            add("decode <answer>      Submit the Chapter 01 cipher")
            add("clear                Clear visible terminal")
            add("restart              Reset Chapter 01 progress")
        case "hint", "hints":
            showHint()
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
            let term = parts.dropFirst(2).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !discovered.isEmpty else { add("No indexed records. Read a file first.", "warning"); return }
            let records: [(String, String)] = [
                ("incident_2049.log", "03:17 signal detected origin internal node incident deletion"),
                ("signal_fragment.dat", "03-17 in-ternal node source route aegis network"),
                ("personnel.enc", "restricted partial cache staff credential active 03:17 operator identity missing roster")
            ].filter { discovered.contains($0.0) }
            let matches = records.filter { term == "*" || $0.0.localizedCaseInsensitiveContains(term) || $0.1.localizedCaseInsensitiveContains(term) }
            if matches.isEmpty {
                add("No matches for '\(term)'.", "warning")
            } else {
                add("SEARCH RESULTS // \(matches.count)", "system")
                for record in matches {
                    add("MATCH IN \(record.0)", "success")
                    add(record.1, "muted")
                }
            }
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
            hintLevel = 0
            lines = [
                TerminalLine(text: localized("BREACH PROTOCOL // FIELD TERMINAL v1.0"), kind: "system"),
                TerminalLine(text: localized("New investigation initialized."), kind: "muted"),
                TerminalLine(text: localized("INCOMING MESSAGE: IF YOU CAN READ THIS, THEY ALREADY KNOW."), kind: "warning")
            ]
            saveGame()
        default: add("Command not found: \(first). Type 'help' for available commands.", "error")
        }
    }

    private func showCommandHelp(_ topic: String) {
        switch topic {
        case "files":
            add("FILES COMMAND // HELP", "system")
            add("files list — show all archive filenames")
            add("files read <name> — open one file and collect its evidence")
            add("Example: files read incident_2049.log")
            add("Tip: filenames must match the archive list exactly.", "muted")
        case "logs":
            add("LOGS COMMAND // HELP", "system")
            add("logs search <word> — search indexed clues")
            add("Try: logs search 03:17")
            add("Try: logs search internal")
            add("Read at least one archive file before searching.", "muted")
        case "decode":
            add("DECODE COMMAND // HELP", "system")
            add("decode <answer> — submit your conclusion for Chapter 01")
            add("You need at least two evidence files first.")
            add("The accepted answer describes the signal's origin.", "muted")
        case "hint", "hints":
            add("HINT COMMAND // HELP", "system")
            add("Type hint to reveal one hint at a time.")
        case "status":
            add("STATUS COMMAND // HELP", "system")
            add("Shows chapter, evidence count, and current objective.")
        default:
            add("No detailed help for '\(topic)'. Try: help files, help logs, help decode, help hint", "warning")
        }
    }

    private func showHint() {
        hintLevel = min(hintLevel + 1, 3)
        switch hintLevel {
        case 1:
            add(isJapanese ? "ヒント 1/3：まずアーカイブの一覧を確認しよう。" : "HINT 1/3: Start with the archive inventory.", "warning")
            add("Try: files list", "muted")
        case 2:
            add(isJapanese ? "ヒント 2/3：2つ目のファイルを開き、時刻と経路の情報を比べよう。" : "HINT 2/3: Open a second file and compare its timestamp and route metadata.", "warning")
            add("Try: files read signal_fragment.dat", "muted")
        default:
            add(isJapanese ? "ヒント 3/3：03:17やinternalで検索しよう。発信源は内部ノードと記録されている。" : "HINT 3/3: Search the records for 03:17 or internal. The source is described as an internal node.", "warning")
            add("Try: logs search 03:17", "muted")
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
            add(isJapanese ? "03:17 // 信号を検出" : "03:17 // SIGNAL DETECTED")
            add(isJapanese ? "発信源：内部ノード (INTERNAL NODE)" : "Origin field: INTERNAL NODE")
            add(isJapanese ? "検出から4秒後にインシデント削除が予約された。" : "Incident marked for deletion 00:04 after detection.")
        case "signal_fragment.dat":
            add("DECODING signal_fragment.dat", "system")
            add(isJapanese ? "断片：03-17 / IN-TERNAL / NODE" : "FRAGMENT: 03-17 / IN-TERNAL / NODE")
            add(isJapanese ? "メタデータ：信号経路はAEGISネットワーク内部から始まっている。" : "Metadata: source route begins inside the AEGIS network.")
        case "personnel.enc":
            add("READING personnel.enc", "system")
            add(isJapanese ? "アクセス制限 // キャッシュの一部を復元" : "ACCESS RESTRICTED // PARTIAL CACHE RECOVERED")
            add(isJapanese ? "03:17に職員の認証情報が使用されていた。" : "A staff credential was active at 03:17.")
            add(isJapanese ? "オペレーターの身元は公式名簿に存在しない。" : "The operator's identity is missing from the official roster.")
        default: break
        }
        add("EVIDENCE ADDED: \(name)", "success")
        saveGame()
    }

    private func evidenceDescription(_ item: String) -> String {
        switch item {
        case "incident_2049.log":
            return isJapanese ? "インシデント記録：03:17に信号を検出。発信源欄は「内部ノード」。" : "Incident log: signal detected at 03:17; origin field says INTERNAL NODE."
        case "signal_fragment.dat":
            return isJapanese ? "信号の断片：経路はAEGISネットワーク内部から始まっている。" : "Signal fragment: route begins inside the AEGIS network."
        case "personnel.enc":
            return isJapanese ? "職員キャッシュ：名簿にない認証情報が03:17に使用されていた。" : "Personnel cache: an unlisted credential was active at 03:17."
        default:
            return isJapanese ? "復元された記録。" : "Recovered record."
        }
    }

    private func localized(_ text: String) -> String {
        guard isJapanese else { return text }
        let exact: [String: String] = [
            "BREACH PROTOCOL // FIELD TERMINAL v1.0": "BREACH PROTOCOL // フィールド端末 v1.0",
            "Secure session established.": "セキュアセッションを確立しました。",
            "INCOMING MESSAGE: IF YOU CAN READ THIS, THEY ALREADY KNOW.": "受信メッセージ：これが読めるなら、相手はすでに気づいている。",
            "Type 'help' to view available commands.": "利用可能なコマンドは 'help' で確認できます。",
            "AVAILABLE COMMANDS": "利用可能なコマンド",
            "Show this command list": "コマンド一覧を表示", "Mission status": "ミッション状況",
            "List available files": "ファイル一覧を表示", "Read an evidence file": "証拠ファイルを読む",
            "Search discovered records": "調査済み記録を検索", "Review collected clues": "収集した手がかりを確認",
            "Submit the Chapter 01 cipher": "第01章の暗号を解読", "Clear visible terminal": "端末表示を消去",
            "Reset Chapter 01 progress": "第01章の進行状況をリセット",
            "MISSION: UNKNOWN SIGNAL": "ミッション：未知の信号", "SESSION: ACTIVE": "セッション：稼働中",
            "CHAPTER: 01 / UNKNOWN SIGNAL": "章：01 / 未知の信号", "OBJECTIVE: Identify the origin of the 03:17 signal.": "目標：03:17に検出された信号の発信源を特定する。",
            "CHAPTER STATUS: COMPLETE": "章の状態：クリア", "ARCHIVE DIRECTORY // 3 ENTRIES": "アーカイブ一覧 // 3件",
            "Usage: files list | files read <name>": "使い方：files list または files read <ファイル名>",
            "Usage: files read <name>": "使い方：files read <ファイル名>",
            "Unknown files operation. Try 'files list'.": "不明な操作です。'files list' を試してください。",
            "No indexed records. Read a file first.": "検索対象の記録がありません。先にファイルを読んでください。",
            "MATCH: signal detected at 03:17": "一致：03:17に信号を検出", "MATCH: origin classified as INTERNAL NODE": "一致：発信源は内部ノードに分類", "MATCH: operator ID withheld": "一致：オペレーターIDは秘匿",
            "No evidence collected. Try 'files list'.": "証拠はまだありません。'files list' を試してください。",
            "CIPHER ACCEPTED.": "暗号を確認しました。", "INSUFFICIENT EVIDENCE. Read at least two archive files.": "証拠が不足しています。アーカイブを2つ以上読んでください。",
            "DECODE FAILED. Re-examine the records and search the logs.": "解読失敗。記録を再確認し、ログを検索してください。",
            "Terminal cleared. Progress remains saved.": "端末表示を消去しました。進行状況は保存されています。",
            "New investigation initialized.": "新しい調査を開始しました。",
            "FILE NOT FOUND. Use 'files list' to see available records.": "ファイルが見つかりません。'files list' で一覧を確認してください。",
            "EVIDENCE ADDED: incident_2049.log": "証拠を追加：incident_2049.log",
            "EVIDENCE ADDED: signal_fragment.dat": "証拠を追加：signal_fragment.dat",
            "EVIDENCE ADDED: personnel.enc": "証拠を追加：personnel.enc",
            "ACCESS RESTRICTED // PARTIAL CACHE RECOVERED": "アクセス制限 // キャッシュの一部を復元",
            "A staff credential was active at 03:17.": "03:17に職員の認証情報が使用されていた。",
            "The operator's identity is missing from the official roster.": "オペレーターの身元は公式名簿に存在しない。",
            "Chapter 02 is locked in this build. Your progress has been saved.": "第02章は今後のアップデートで追加予定です。進行状況は保存されました。"
        ]
        if let translated = exact[text] { return translated }
        if text.hasPrefix("[FILE] ") { return "[ファイル] " + text.replacingOccurrences(of: "[FILE] ", with: "") }
        if text.hasPrefix("[CONFIRMED] ") { return "[確認済み] " + text.replacingOccurrences(of: "[CONFIRMED] ", with: "") }
        if text.hasPrefix("EVIDENCE ADDED: ") { return "証拠を追加：" + text.replacingOccurrences(of: "EVIDENCE ADDED: ", with: "") }
        if text.hasPrefix("Command not found: ") { return "コマンドが見つかりません：" + text.replacingOccurrences(of: "Command not found: ", with: "") + "。'help' で一覧を確認してください。" }
        if text.hasPrefix("No matches for '") { return "一致する記録はありません：" + text.replacingOccurrences(of: "No matches for '", with: "").replacingOccurrences(of: "'.", with: "") }
        if text.hasPrefix("operator@bp:~$ ") { return "操作者@bp:~$ " + text.replacingOccurrences(of: "operator@bp:~$ ", with: "") }
        if text.hasPrefix("EVIDENCE REGISTER // ") { return "証拠一覧 // " + text.replacingOccurrences(of: "EVIDENCE REGISTER // ", with: "") + "件" }
        if text.hasPrefix("CHAPTER 01 COMPLETE") { return "第01章クリア // 信号の発信源：内部ノード" }
        if text.hasPrefix("A new message appears:") { return "新しいメッセージ：「扉は見つけた。次は、誰が開けたのかを探せ。」" }
        if text.hasPrefix("EVIDENCE: ") { return "証拠：" + text.replacingOccurrences(of: "EVIDENCE: ", with: "") }
        if text.hasPrefix("OPENING incident_2049.log") { return "incident_2049.log を開いています" }
        if text.hasPrefix("DECODING signal_fragment.dat") { return "signal_fragment.dat を解析しています" }
        if text.hasPrefix("READING personnel.enc") { return "personnel.enc を読み込んでいます" }
        if text.hasPrefix("Origin field:") { return "発信源：" + text.replacingOccurrences(of: "Origin field: ", with: "") }
        if text.hasPrefix("Incident marked for deletion") { return "検出から4秒後にインシデント削除が予約された。" }
        if text.hasPrefix("FRAGMENT:") { return "断片：" + text.replacingOccurrences(of: "FRAGMENT: ", with: "") }
        if text.hasPrefix("Metadata:") { return "メタデータ：" + text.replacingOccurrences(of: "Metadata: ", with: "") }
        if text.hasPrefix("MATCH:") { return "一致：" + text.replacingOccurrences(of: "MATCH: ", with: "") }
        if text.hasPrefix("EVIDENCE: ") { return "証拠：" + text.replacingOccurrences(of: "EVIDENCE: ", with: "") }
        return text
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
