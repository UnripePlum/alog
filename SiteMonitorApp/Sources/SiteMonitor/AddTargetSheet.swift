import SwiftUI
import MonitorKit

/// 이름·URL을 받아 사이트를 추가하는 시트. 생성 로직은 `TargetCreating` 계약에 위임.
struct AddTargetSheet: View {
    var factory: any TargetCreating = DefaultTargetFactory()
    var onCreated: (Target) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var url: String = ""
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("사이트 추가")
                .font(.headline)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 8)

            Form {
                Section {
                    TextField("이름 (비우면 주소에서 채움)", text: $name)
                    TextField("https://example.com", text: $url)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                } footer: {
                    Text("본인이 운영하거나 모니터링 권한이 있는 사이트만 추가하세요.")
                }

                if let errorText {
                    Text(errorText)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
            .formStyle(.grouped)
            .onChange(of: url) { _, _ in errorText = nil }

            Divider()
            HStack {
                Spacer()
                Button("취소") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("추가") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(12)
        }
        .frame(width: 460, height: 280)
    }

    private func submit() {
        do {
            let target = try factory.make(name: name, url: url)
            onCreated(target)
            dismiss()
        } catch TargetFactoryError.emptyURL {
            errorText = "사이트 주소를 입력하세요."
        } catch TargetFactoryError.invalidURL {
            errorText = "올바른 http(s) 주소가 아닙니다. 예: example.com"
        } catch {
            errorText = "사이트를 추가하지 못했습니다."
        }
    }
}
