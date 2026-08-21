import SwiftUI
import MonitorKit

/// 점검 로그 (최신순). 한 행 = 테스트 1회, 펼치면 그 안의 각 항목 결과.
struct LogView: View {
    let entries: [CheckRun]

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("점검 로그").font(.headline)
                Spacer()
                Text("\(entries.count)회").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if entries.isEmpty {
                Text("아직 점검 기록이 없습니다. 대상의 ▶ 버튼이나 ‘즉시 점검’을 눌러보세요.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(entries) { run in
                    DisclosureGroup {
                        ForEach(run.items) { item in
                            HStack(spacing: 8) {
                                Image(systemName: item.ok ? "checkmark.circle" : "xmark.circle")
                                    .foregroundStyle(item.ok ? Color.green : Color.red)
                                    .font(.caption)
                                Text(item.actionKind.label)
                                    .font(.caption)
                                Spacer()
                                Text(item.detail)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Text("\(item.durationMs)ms")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading, 4)
                        }
                    } label: {
                        runHeader(run)
                    }
                }
            }
        }
    }

    private func runHeader(_ run: CheckRun) -> some View {
        let okCount = run.items.filter { $0.ok }.count
        return HStack(spacing: 10) {
            Image(systemName: run.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(run.ok ? Color.green : Color.red)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(run.targetName) · \(run.vantageName)").font(.callout)
                Text("\(okCount)/\(run.items.count) 항목 정상")
                    .font(.caption)
                    .foregroundStyle(run.ok ? Color.secondary : Color.red)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Self.timeFormatter.string(from: run.timestamp)).font(.caption)
                Text("\(run.durationMs)ms").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
