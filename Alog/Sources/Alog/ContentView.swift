import SwiftUI
import MonitorKit

struct ContentView: View {
    @EnvironmentObject var controller: MonitorController
    @EnvironmentObject var updates: UpdateService
    @Environment(\.openWindow) private var openWindow
    @State private var selection: Target.ID?
    @State private var pendingDeleteID: Target.ID?

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 340)
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .toolbar { primaryToolbar }
        .sheet(item: $controller.presentedSheet) { sheet in
            switch sheet {
            case .add:
                AddTargetSheet { id in
                    selection = id
                }
                .environmentObject(controller)
            }
        }
        .onChange(of: updates.isBlocked) { _, blocked in
            if blocked { controller.stopAll() }
        }
        .onAppear {
            controller.runSelfTestIfRequested()
            if selection == nil {
                selection = controller.config.targets.first?.id
            }
        }
        .onChange(of: controller.config.targets.map(\.id)) { _, ids in
            if let selection, ids.contains(selection) { return }
            self.selection = ids.first
        }
        .overlay {
            if updates.isBlocked {
                ForcedUpdateView()
                    .environmentObject(updates)
            }
        }
        .alert(
            updateAlertTitle,
            isPresented: updateAlertPresented
        ) {
            Button("설치") {
                Task { await updates.installAvailable() }
            }
            Button("나중에", role: .cancel) { updates.dismissPrompt() }
        } message: {
            Text(updateAlertMessage)
        }
        .confirmationDialog(
            "\(pendingDeleteName)을(를) 삭제할까요?",
            isPresented: Binding(
                get: { pendingDeleteID != nil },
                set: { if !$0 { pendingDeleteID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                if let id = pendingDeleteID {
                    controller.remove(id)
                }
                pendingDeleteID = nil
            }
            Button("취소", role: .cancel) {
                pendingDeleteID = nil
            }
        }
        .onDeleteCommand {
            pendingDeleteID = selection
        }
    }

    // MARK: - 사이드바 (대상 목록)

    private var sidebar: some View {
        List(selection: $selection) {
            Section("사이트") {
                ForEach(controller.config.targets) { target in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(controller.isRunning(target.id) ? Color.green : Color.secondary.opacity(0.4))
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(target.name.isEmpty ? target.url : target.name)
                                .lineLimit(1)
                            Text(controller.isRunning(target.id) ? "접속 중" : target.url)
                                .font(.caption)
                                .foregroundStyle(controller.isRunning(target.id) ? Color.green : Color.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .tag(Optional(target.id))
                    .contextMenu {
                        Button("삭제", role: .destructive) {
                            pendingDeleteID = target.id
                        }
                    }
                }
                .onDelete { offsets in
                    controller.remove(atOffsets: offsets)
                }
            }
        }
        .navigationTitle(AppIdentity.current.displayName)
        .safeAreaInset(edge: .bottom) {
            Button {
                controller.requestAddTarget()
            } label: {
                Label("사이트 추가", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .padding(12)
        }
    }

    // MARK: - 디테일 (편집기 + 로그)

    private var detail: some View {
        VSplitView {
            Group {
                if let id = selection,
                   let index = controller.config.targets.firstIndex(where: { $0.id == id }) {
                    TargetEditorView(
                        target: $controller.config.targets[index],
                        onDelete: { pendingDeleteID = id }
                    )
                } else if controller.config.targets.isEmpty {
                    EmptyTargetPlaceholder { controller.requestAddTarget() }
                } else {
                    SelectTargetPlaceholder { controller.requestAddTarget() }
                }
            }
            .frame(minHeight: 160)
            LogView(entries: controller.entries, schedule: controller.config.schedule)
                .frame(minHeight: 140)
        }
    }

    // MARK: - 상단 툴바 (추가 + 실행 제어)

    @ToolbarContentBuilder
    private var primaryToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                controller.requestAddTarget()
            } label: {
                Label("사이트 추가", systemImage: "plus")
            }
            .help("사이트 추가 (⌘N)")
        }

        ToolbarItemGroup {
            let selectedRunning = selection.map { controller.isRunning($0) } ?? false
            if selectedRunning {
                Button {
                    if let id = selection { controller.stop(id) }
                } label: {
                    Label("중지", systemImage: "stop.fill")
                }
                .tint(.red)
            } else {
                Button {
                    if let id = selection { controller.start(id) }
                } label: {
                    Label("시작", systemImage: "play.fill")
                }
                .tint(.green)
                .disabled(selection == nil)
            }

            Button {
                if let id = selection { controller.runOnceNow(id) }
            } label: {
                Label("지금 접속", systemImage: "bolt.fill")
            }
            .disabled(selection == nil)

            Button {
                openWindow(id: WindowID.settings)
            } label: {
                Label("설정", systemImage: "gearshape")
            }
            .help("설정 (⌘,)")

            Button {
                pendingDeleteID = selection
            } label: {
                Label("사이트 삭제", systemImage: "trash")
            }
            .help("선택한 사이트 삭제")
            .disabled(selection == nil)
        }
    }

    private var updateAlertPresented: Binding<Bool> {
        Binding(
            get: {
                if case .available = updates.status { return true }
                return false
            },
            set: { show in
                if !show { updates.dismissPrompt() }
            }
        )
    }

    private var updateAlertTitle: String {
        if case .available(let rel) = updates.status {
            return "\(AppIdentity.current.displayName) \(rel.version.string)"
        }
        return "업데이트"
    }

    private var updateAlertMessage: String {
        if case .available(let rel) = updates.status {
            let notes = rel.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if notes.isEmpty { return "새 버전을 받아 설치합니다. 설치 후 앱이 다시 시작됩니다." }
            return notes
        }
        return ""
    }

    private var pendingDeleteName: String {
        guard let id = pendingDeleteID,
              let target = controller.config.targets.first(where: { $0.id == id }) else {
            return "이 사이트"
        }
        return target.name.isEmpty ? target.url : target.name
    }
}
