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
    var chapterTwoUnlocked: Bool? = false
    var chapterTwoComplete: Bool? = false
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
    @State private var chapterTwoUnlocked = false
    @State private var chapterTwoComplete = false
    @State private var hintLevel = 0
    @State private var showEvidence = false
    @FocusState private var inputFocused: Bool

    private let fileNames = ["incident_2049.log", "signal_fragment.dat", "personnel.enc", "watcher_trace.log", "blacksite_map.dat", "echo_message.txt"]

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
            Text(isJapanese ? "証拠 \(discovered.count)/6" : "EVIDENCE \(discovered.count)/6").foregroundStyle(Theme.cyan)
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
            add(isJapanese ? "help [command]       詳細ヘルプを表示" : "help [command]       Show detailed command help")
            add(isJapanese ? "hint                 段階的なヒントを表示" : "hint                 Get a progressive puzzle hint")
            add(isJapanese ? "status               ミッション状況" : "status               Mission status")
            add(isJapanese ? "files list           ファイル一覧を表示" : "files list           List available files")
            add(isJapanese ? "files read <name>    証拠ファイルを読む" : "files read <name>    Read an evidence file")
            add(isJapanese ? "logs search <word>   調査済み記録を検索" : "logs search <word>   Search discovered records")
            add(isJapanese ? "evidence             収集した手がかりを確認" : "evidence             Review collected clues")
            add(isJapanese ? "decode <answer>      第01章の答えを送信" : "decode <answer>      Submit the Chapter 01 cipher")
            add(isJapanese ? "clear                端末表示を消去" : "clear                Clear visible terminal")
            add(isJapanese ? "restart              第01章を最初からやり直す" : "restart              Reset Chapter 01 progress")
            add(isJapanese ? "story                ストーリー記録を読む" : "story                Read the expanded story")
            add(isJapanese ? "timeline             事件の時系列を確認" : "timeline             Review the incident timeline")
            if chapterTwoUnlocked { add(isJapanese ? "第02章が解放済み：files list / decode <答え>" : "CHAPTER 02 UNLOCKED: files list / decode <answer>", "success") }
        case "story", "lore", "briefing":
            showStory()
        case "timeline":
            showTimeline()
        case "hint", "hints":
            showHint()
        case "status":
            add("MISSION: UNKNOWN SIGNAL", "system")
            add("SESSION: ACTIVE")
            add("CHAPTER: 01 / UNKNOWN SIGNAL")
            add("EVIDENCE: \(discovered.count)/6")
            add("OBJECTIVE: Identify the origin of the 03:17 signal.")
            if chapterComplete { add("CHAPTER STATUS: COMPLETE", "success") }
        case "files":
            guard parts.count >= 2 else { add("Usage: files list | files read <name>", "warning"); return }
            if parts[1] == "list" {
                add("ARCHIVE DIRECTORY // 6 ENTRIES", "system")
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
                ("personnel.enc", "restricted partial cache staff credential active 03:17 operator identity missing roster"),
                ("watcher_trace.log", "watcher echo surveillance loop no operator outbound packet 03:19"),
                ("blacksite_map.dat", "sector zero lower archive station nine sealed door route below aegis"),
                ("echo_message.txt", "mira vale do not trust the clock it was reset from inside")
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
            let answer = parts.dropFirst().joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if chapterTwoUnlocked {
                let chapterTwoEvidence = discovered.intersection(["station_nine.log", "door_auth.enc", "mira_final.txt"]).count
                if chapterTwoEvidence >= 2 && ["station nine", "station nine is the destination", "nine"].contains(answer) {
                    chapterTwoComplete = true
                    add("ACCESS GRANTED // STATION NINE IDENTIFIED", "success")
                    add("CHAPTER 02 COMPLETE // MIRA VALE LEFT A LIVE CHANNEL.", "system")
                    add("INCOMING: \"If this reached you, the archive is listening. Do not open the third door.\"", "warning")
                } else if chapterTwoEvidence < 2 {
                    add("INSUFFICIENT EVIDENCE. Read at least two Chapter 02 files.", "warning")
                } else { add("DECODE FAILED. Compare the destination and access records.", "error") }
            } else if discovered.count >= 2 && ["internal node", "internal", "node"].contains(answer) {
                chapterComplete = true
                add("CIPHER ACCEPTED.", "success")
                add("CHAPTER 01 COMPLETE // SIGNAL ORIGIN: INTERNAL NODE", "system")
                add("A new message appears: 'You found the door. Now find who opened it.'", "warning")
                chapterTwoUnlocked = true
                add("CHAPTER 02 UNLOCKED // STATION NINE", "success")
                add("New archive entries detected. Type 'files list' to continue.", "system")
            } else if discovered.count < 2 {
                add("INSUFFICIENT EVIDENCE. Read at least two archive files.", "warning")
            } else { add("DECODE FAILED. Re-examine the records and search the logs.", "error") }
        case "clear":
            lines = [TerminalLine(text: "Terminal cleared. Progress remains saved.", kind: "muted")]
            saveGame()
        case "restart":
            discovered.removeAll()
            chapterComplete = false
            chapterTwoUnlocked = false
            chapterTwoComplete = false
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

    private func showStory() {
        add(isJapanese ? "BREACH PROTOCOL // 調査資料" : "BREACH PROTOCOL // INVESTIGATION DOSSIER", "system")
        add(isJapanese ? "背景：2049年、都市インフラを統合管理するAEGISは、あらゆる異常を公式記録から消せると噂されている。" : "BACKGROUND: In 2049, AEGIS manages the city’s critical infrastructure. Rumor says it can make any incident disappear from official records.", "muted")
        add(isJapanese ? "あなたは匿名の調査員。午前03:17、閉鎖済み施設から短い信号が届いた。公式記録では、その施設は12年前に廃止されている。" : "You are an anonymous investigator. At 03:17, a short signal arrived from a sealed facility officially decommissioned twelve years ago.")
        add(isJapanese ? "第一の謎：信号は内部ノードから発信された。誰かが施設の中にいるのか、それともシステム自体が発信しているのか？" : "MYSTERY ONE: The signal came from an internal node. Is someone inside—or is the system itself transmitting?", "warning")
        add(isJapanese ? "人物記録：MIRA VALE。元AEGIS監査員。12年前の閉鎖記録を最後に名簿から消えている。彼女の署名を模したメッセージが復元されたが、本物かは不明。" : "PERSON OF INTEREST: MIRA VALE, a former AEGIS auditor who vanished from the roster after the facility closure. A message bearing her signature was recovered, but its authenticity is unverified.")
        add(isJapanese ? "第二の謎：WATCHER監視系は03:17から同じ映像を再生し続け、03:19に内部コンソールから停止された。" : "MYSTERY TWO: WATCHER replayed the same camera feed from 03:17 until an internal console shut it down at 03:19.")
        add(isJapanese ? "第三の謎：公式図面にない地下区画SECTOR ZERO。その奥にはSTATION NINEという扉がある。" : "MYSTERY THREE: SECTOR ZERO, a lower archive absent from official maps. A door inside is labeled STATION NINE.")
        add(isJapanese ? "調査方針：記録を集め、時刻・署名・経路の矛盾を比較しよう。ひとつの証拠だけで結論を決めないこと。" : "INVESTIGATION: Collect records and compare contradictions in timestamps, signatures, and routes. Do not trust a conclusion based on a single clue.", "muted")
        add(isJapanese ? "次の手がかり：files list で追加ファイルを確認しよう。" : "NEXT LEADS: Use files list to inspect the new records.", "success")
        add(isJapanese ? "仮説：監視映像の停止、職員認証、信号発信は同じ内部操作と関係している可能性がある。ただし、まだ確証はない。" : "WORKING THEORY: The camera shutdown, staff credential, and signal may share an internal operator. This is still only a hypothesis.", "warning")
    }

    private func showTimeline() {
        add(isJapanese ? "事件の時系列 // 未検証記録を含む" : "INCIDENT TIMELINE // INCLUDES UNVERIFIED RECORDS", "system")
        add("03:17:00 — " + (isJapanese ? "閉鎖施設から信号を検出。" : "Signal detected from the sealed facility."))
        add("03:17:04 — " + (isJapanese ? "インシデント削除が予約された。" : "Incident deletion was scheduled."))
        add("03:17 — " + (isJapanese ? "名簿にない職員認証情報が使用された。" : "An unlisted staff credential was active."))
        add("03:17–03:19 — " + (isJapanese ? "WATCHERの映像がループ再生。" : "WATCHER camera footage looped."))
        add("03:19 — " + (isJapanese ? "内部コンソールから監視停止命令。" : "Surveillance shutdown command from an internal console."))
        add(isJapanese ? "注意：記録の時計自体が改ざんされた可能性がある。時刻だけを根拠に結論を出さないこと。" : "CAUTION: The clock may itself have been altered. Do not rely on timestamps alone.", "warning")
    }
    private func showCommandHelp(_ topic: String) {
        switch topic {
        case "files":
            add(isJapanese ? "ファイルコマンド // ヘルプ" : "FILES COMMAND // HELP", "system")
            add(isJapanese ? "files list — アーカイブの一覧を表示" : "files list — show all archive filenames")
            add(isJapanese ? "files read <name> — ファイルを開いて証拠を収集" : "files read <name> — open one file and collect its evidence")
            add(isJapanese ? "例：files read incident_2049.log" : "Example: files read incident_2049.log")
            add(isJapanese ? "ヒント：ファイル名は一覧と完全に一致させてください。" : "Tip: filenames must match the archive list exactly.", "muted")
        case "logs":
            add(isJapanese ? "ログコマンド // ヘルプ" : "LOGS COMMAND // HELP", "system")
            add(isJapanese ? "logs search <word> — 記録された手がかりを検索" : "logs search <word> — search indexed clues")
            add("Try: logs search 03:17")
            add("Try: logs search internal")
            add(isJapanese ? "検索前にアーカイブを1つ以上読んでください。" : "Read at least one archive file before searching.", "muted")
        case "decode":
            add(isJapanese ? "解読コマンド // ヘルプ" : "DECODE COMMAND // HELP", "system")
            add(isJapanese ? "decode <answer> — 第01章の答えを送信" : "decode <answer> — submit your conclusion for Chapter 01")
            add(isJapanese ? "先に証拠ファイルを2つ以上確認してください。" : "You need at least two evidence files first.")
            add("The accepted answer describes the signal's origin.", "muted")
        case "hint", "hints":
            add(isJapanese ? "ヒントコマンド // ヘルプ" : "HINT COMMAND // HELP", "system")
            add(isJapanese ? "hintを入力すると、ヒントが1つずつ表示されます。" : "Type hint to reveal one hint at a time.")
        case "status":
            add(isJapanese ? "ステータスコマンド // ヘルプ" : "STATUS COMMAND // HELP", "system")
            add(isJapanese ? "章、証拠の数、現在の目標を表示します。" : "Shows chapter, evidence count, and current objective.")
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
        let availableNames = chapterTwoUnlocked ? fileNames + ["station_nine.log", "door_auth.enc", "mira_final.txt"] : fileNames
        guard let matchedName = availableNames.first(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else {
            add("FILE NOT FOUND. Use 'files list' to see available records.", "error")
            return
        }
        discovered.insert(name)
        switch name {
        case "station_nine.log":
            add(isJapanese ? "STATION NINE // 到着記録" : "STATION NINE // ARRIVAL LOG", "system")
            add(isJapanese ? "公式地図にない駅。列車の記録はないのに、03:19にプラットフォームの照明が点灯した。" : "A station absent from official maps. No trains are logged, yet the platform lights activated at 03:19.")
            add(isJapanese ? "行先コード：NINE。乗客欄には MIRA VALE とだけ記録されている。" : "Destination code: NINE. The passenger field contains only MIRA VALE.")
        case "door_auth.enc":
            add(isJapanese ? "扉認証 // 復元データ" : "DOOR AUTH // RECOVERED DATA", "system")
            add(isJapanese ? "認証要求は外部からではなく、地下アーカイブの内側から発生した。" : "The access request originated inside the lower archive, not from outside.")
            add(isJapanese ? "対象扉：STATION NINE。認証結果：許可。ただし署名鍵は失効済み。" : "Target: STATION NINE. Result: GRANTED. Signing key: REVOKED.")
        case "mira_final.txt":
            add(isJapanese ? "MIRA VALE // 最終メッセージ" : "MIRA VALE // FINAL MESSAGE", "system")
            add(isJapanese ? "もしこの記録を読めるなら、私はまだシステム内にいる。駅は場所ではない。記録を移送するための経路だ。" : "If you can read this, I am still inside the system. The station is not a place. It is a route used to move records.")
            add(isJapanese ? "行先を問われたら、STATION NINE と答えて。三つ目の扉は開けないで。" : "If asked for the destination, answer STATION NINE. Do not open the third door.", "warning")
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
        case "watcher_trace.log":
            add("OPENING watcher_trace.log", "system")
            add(isJapanese ? "WATCHERは03:17から03:19まで同じ映像をループ再生。" : "WATCHER replayed the same camera feed from 03:17 to 03:19.")
            add(isJapanese ? "外向き映像送信は03:19に停止。" : "Outbound camera transmission stopped at 03:19.")
            add(isJapanese ? "停止命令は外部ではなく内部コンソールから発行。" : "Shutdown command originated from an internal console.")
        case "blacksite_map.dat":
            add("DECODING blacksite_map.dat", "system")
            add(isJapanese ? "区画：SECTOR ZERO / 地下保管庫" : "SECTOR: ZERO / LOWER ARCHIVE")
            add(isJapanese ? "公式図面にない通路が記録されている。" : "A corridor appears here but is absent from official AEGIS maps.")
            add(isJapanese ? "扉の記録：STATION NINE。最後のアクセスは03:17。" : "Door label: STATION NINE. Last access recorded at 03:17.")
        case "echo_message.txt":
            add("RECOVERING echo_message.txt", "system")
            add(isJapanese ? "送信者：MIRA VALE // 署名未検証" : "SENDER: MIRA VALE // SIGNATURE UNVERIFIED")
            add(isJapanese ? "「時計を信じないで。時刻は内側から巻き戻された。」" : "\"Do not trust the clock. It was reset from the inside.\"")
            add(isJapanese ? "追記：この記録を見つけたなら、私はまだここにいるかもしれない。" : "POSTSCRIPT: If you found this record, I may still be here.")
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
        case "watcher_trace.log":
            return isJapanese ? "監視映像は同じ場面を再生し続け、停止命令は内部から出ていた。" : "The camera feed looped; its shutdown command came from inside."
        case "blacksite_map.dat":
            return isJapanese ? "公式図面にない地下区画と、STATION NINEという扉が記録されている。" : "An unlisted lower-level corridor leads to a door marked STATION NINE."
        case "echo_message.txt":
            return isJapanese ? "MIRA VALEを名乗る人物からの警告。時計は内部から改ざんされたという。" : "An unverified warning from MIRA VALE claims the clock was altered from inside."
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
            "CHAPTER STATUS: COMPLETE": "章の状態：クリア", "ARCHIVE DIRECTORY // 6 ENTRIES": "アーカイブ一覧 // 6件",
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
        let data = SaveData(lines: lines, discovered: Array(discovered), chapterComplete: chapterComplete, chapterTwoUnlocked: chapterTwoUnlocked, chapterTwoComplete: chapterTwoComplete)
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
        chapterTwoUnlocked = saved.chapterTwoUnlocked ?? saved.chapterComplete
        chapterTwoComplete = saved.chapterTwoComplete ?? false
    }
}
