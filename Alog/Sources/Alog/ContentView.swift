import SwiftUI
import MonitorKit

struct ContentView: View {
    @EnvironmentObject var controller: MonitorController
    @EnvironmentObject var updates: UpdateService
    @State private var selection: Target.ID?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .toolbar { primaryToolbar }
        .sheet(item: $controller.presentedSheet) { sheet in
            switch sheet {
            case .settings:
                SettingsView()
                    .environmentObject(controller)
                    .environmentObject(updates)
            case .add:
                AddTargetSheet { id in
                    selection = id
                }
                .environmentObject(controller)
            }
        }
        .onChange(of: controller.config) { _, _ in controller.save() }
        .onAppear { controller.runSelfTestIfRequested() }
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
                            Text(controller.isRunning(target.id) ? "백그라운드 점검 중" : target.url)
                                .font(.caption)
                                .foregroundStyle(controller.isRunning(target.id) ? Color.green : Color.secondary)
                                .lineLimit(1)
                        }
                    }
                    .tag(Optional(target.id))
                }
                .onDelete { offsets in
                    let deleted = Set(offsets.map { controller.config.targets[$0].id })
                    for id in deleted { controller.stop(id) }
                    controller.config.targets.remove(atOffsets: offsets)
                    if let selection, deleted.contains(selection) {
                        self.selection = nil
                    }
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
        VStack(spacing: 0) {
            if let id = selection,
               let index = controller.config.targets.firstIndex(where: { $0.id == id }) {
                TargetEditorView(target: $controller.config.targets[index])
            } else if controller.config.targets.isEmpty {
                EmptyTargetPlaceholder { controller.requestAddTarget() }
            } else {
                SelectTargetPlaceholder { controller.requestAddTarget() }
            }
            Divider()
            LogView(entries: controller.entries)
                .frame(minHeight: 200)
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
                Label("즉시 점검", systemImage: "bolt.fill")
            }
            .disabled(selection == nil)

            Button {
                controller.requestSettings()
            } label: {
                Label("설정", systemImage: "gearshape")
            }
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
}
