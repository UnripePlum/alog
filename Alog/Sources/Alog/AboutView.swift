import SwiftUI
import AppKit
import MonitorKit

/// 버전·개발자·저작권. 값은 identity.json에서만 읽는다.
struct AboutContent: View {
    var identity: AppIdentity = .current
    var versionLabel: String

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
            VStack(spacing: 4) {
                Text(identity.displayName)
                    .font(.title2.weight(.semibold))
                Text("버전 \(versionLabel)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                if !identity.developerName.isEmpty {
                    aboutRow("개발자", identity.developerName)
                }
                if !identity.organization.isEmpty {
                    aboutRow("조직", identity.organization)
                }
                aboutRow("번들 ID", identity.bundleIdentifier)
                if !identity.copyright.isEmpty {
                    aboutRow("저작권", identity.copyright)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                if let url = identity.repositoryURL {
                    Link("GitHub \(identity.repositoryLabel)", destination: url)
                }
                if let home = identity.resolvedHomepageURL,
                   home != identity.repositoryURL {
                    Link("홈페이지", destination: home)
                }
                if let mail = identity.supportMailURL {
                    Link(identity.supportEmail, destination: mail)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func aboutRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .font(.callout)
    }
}

/// 앱 메뉴 정보 창.
struct AboutView: View {
    @EnvironmentObject var updates: UpdateService

    var body: some View {
        AboutContent(versionLabel: updates.currentVersionLabel)
            .padding(28)
            .frame(width: 360)
            .background(PlaceOnAppScreen())
    }
}

/// 설정 > 정보 탭.
struct AboutSettingsPane: View {
    @EnvironmentObject var updates: UpdateService

    var body: some View {
        ScrollView {
            AboutContent(versionLabel: updates.currentVersionLabel)
                .frame(maxWidth: 360)
                .padding(24)
                .frame(maxWidth: .infinity)
        }
    }
}
