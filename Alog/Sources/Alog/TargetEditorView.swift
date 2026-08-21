import SwiftUI
import MonitorKit

/// 대상 하나(이름/URL/동작 목록)를 편집.
struct TargetEditorView: View {
    @Binding var target: Target

    var body: some View {
        Form {
            Section("대상") {
                TextField("이름", text: $target.name)
                TextField("URL", text: $target.url)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
            }

            Section {
                if target.actions.isEmpty {
                    Text("동작을 추가하세요. 매 사이클 순환하며 하나씩 수행합니다.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
                ForEach($target.actions) { $action in
                    ActionRow(action: $action)
                }
                .onDelete { target.actions.remove(atOffsets: $0) }
            } header: {
                HStack {
                    Text("점검 동작 (매 사이클 순환)")
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
                }
            }
        }
        .formStyle(.grouped)
    }
}

/// 동작 한 줄: 종류 선택 + 종류별 파라미터.
struct ActionRow: View {
    @Binding var action: ActionSpec

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("종류", selection: $action.kind) {
                ForEach(ActionKind.allCases, id: \.self) { kind in
                    Text(kind.label).tag(kind)
                }
            }

            switch action.kind {
            case .hasTitle:
                hint("페이지 제목(<title>)이 비어있지 않은지 확인")
            case .bodyHasText:
                hint("실제 본문 텍스트가 렌더링됐는지 확인")
            case .scrollToBottom:
                hint("페이지 맨 아래까지 스크롤 가능한지 확인")
            case .pageLoaded:
                hint("문서 로딩이 완료(readyState=complete)됐는지 확인")
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
        .padding(.vertical, 2)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
