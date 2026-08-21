import SwiftUI
import MonitorKit

/// 점검 1회 행. List/DisclosureGroup을 쓰지 않는다 (macOS에서 라벨 너비가 무너짐).
struct LogRunRow: View {
    let run: CheckRun
    let expanded: Bool
    var onToggle: () -> Void

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                header
            }
            .buttonStyle(.plain)
            if expanded {
                itemList
            }
        }
    }

    private var header: some View {
        let okCount = run.items.filter(\.ok).count
        return HStack(alignment: .center, spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(expanded ? 90 : 0))
                .frame(width: 12)

            Image(systemName: run.ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(run.ok ? Color.green : Color.red)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(run.targetName) · \(run.vantageName)")
                    .font(.callout)
                    .lineLimit(1)
                Text("\(okCount)/\(run.items.count) 항목 정상")
                    .font(.caption)
                    .foregroundStyle(run.ok ? Color.secondary : Color.red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                Text(Self.timeFormatter.string(from: run.timestamp))
                    .font(.caption)
                    .monospacedDigit()
                Text("\(run.durationMs)ms")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var itemList: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(run.items) { item in
                HStack(spacing: 8) {
                    Image(systemName: item.ok ? "checkmark.circle" : "xmark.circle")
                        .foregroundStyle(item.ok ? Color.green : Color.red)
                        .font(.caption)
                    Text(item.actionKind.label)
                        .font(.caption)
                    Spacer(minLength: 8)
                    Text(item.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("\(item.durationMs)ms")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.leading, 36)
        .padding(.trailing, 12)
        .padding(.bottom, 8)
    }
}
