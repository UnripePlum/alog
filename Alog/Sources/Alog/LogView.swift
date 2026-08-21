import SwiftUI
import MonitorKit

/// 점검 로그 (최신순). 한 행 = 테스트 1회.
struct LogView: View {
    let entries: [CheckRun]
    var schedule: ScheduleConfig = ScheduleConfig(
        minSeconds: Defaults.minSeconds, maxSeconds: Defaults.maxSeconds)
    @State private var expanded: Set<UUID> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("점검 로그").font(.headline)
                Spacer()
                Text("\(Int(min(schedule.minSeconds, schedule.maxSeconds)))~\(Int(max(schedule.minSeconds, schedule.maxSeconds)))초마다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(entries.count)회").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if entries.isEmpty {
                Text("백그라운드에서 실제 페이지를 연 결과가 여기 쌓입니다.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 12)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(entries) { run in
                            LogRunRow(
                                run: run,
                                expanded: expanded.contains(run.id),
                                onToggle: { toggle(run.id) }
                            )
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private func toggle(_ id: UUID) {
        if expanded.contains(id) { expanded.remove(id) }
        else { expanded.insert(id) }
    }
}
