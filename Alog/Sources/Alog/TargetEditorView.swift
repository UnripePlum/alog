import SwiftUI
import MonitorKit

/// 대상 하나(이름/URL/동작 목록)를 편집.
struct TargetEditorView: View {
    @Binding var target: Target
    var onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("대상").font(.headline)
                    TextField("이름", text: $target.name)
                    TextField("URL", text: $target.url)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                }

                Divider()

                HStack {
                    Text("점검 동작").font(.headline)
                    Spacer()
                    Menu {
                        ForEach(ActionKind.allCases, id: \.self) { kind in
                            Button(kind.label) {
                                target.actions.append(ActionSpec(kind: kind))
                            }
                        }
                    } label: {
                        Label("동작 추가", systemImage: "plus")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                if target.actions.isEmpty {
                    Text("동작을 추가하세요. 매 사이클 순환하며 하나씩 수행합니다.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }

                ForEach($target.actions) { $action in
                    ActionRow(action: $action) {
                        target.actions.removeAll { $0.id == action.id }
                    }
                }

                Button("사이트 삭제", role: .destructive, action: onDelete)
            }
            .textFieldStyle(.roundedBorder)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// 동작 한 줄: 종류 선택 + 종류별 파라미터.
struct ActionRow: View {
    @Binding var action: ActionSpec
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Picker("종류", selection: $action.kind) {
                    ForEach(ActionKind.allCases, id: \.self) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                }
                .buttonStyle(.plain)
                .help("동작 삭제")
            }

            switch action.kind {
            case .hasTitle:
                hint("페이지 제목(<title>)이 비어있지 않은지 확인")
            case .bodyHasText:
                hint("실제 본문 텍스트가 렌더링됐는지 확인")
            case .scrollToBottom:
                hint("페이지 맨 아래까지 스크롤 가능한지 확인")
            case .pageLoaded:
                hint("문서가 interactive 또는 complete인지 확인")
            case .checkSelector, .click:
                TextField("CSS 선택자 (예: #main, .title)", text: $action.selector)
                    .autocorrectionDisabled()
            case .checkText:
                TextField("확인할 텍스트", text: $action.text)
            case .scroll:
                Stepper("스크롤 \(action.pixels)px", value: $action.pixels, in: 0...100_000, step: 100)
            case .wait:
                Stepper("대기 \(action.ms)ms", value: $action.ms, in: 0...60_000, step: 100)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
