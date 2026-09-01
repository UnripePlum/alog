import AppKit
import SwiftUI
import MonitorKit

/// 보조 창(설정·정보)을 메인 앱 창과 같은 디스플레이 가운데에 둔다.
enum WindowPlacement {
    static func appScreen() -> NSScreen? {
        let mains = NSApp.windows.filter(isMainAppWindow)
        if let screen = mains.first(where: { $0.isVisible })?.screen { return screen }
        if let screen = mains.first?.screen { return screen }
        let mouse = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) {
            return screen
        }
        return NSScreen.main
    }

    static func isMainAppWindow(_ window: NSWindow) -> Bool {
        if let id = window.identifier?.rawValue {
            if id == WindowID.main || id.hasSuffix(".\(WindowID.main)") { return true }
        }
        return window.title == AppIdentity.current.displayName
            && window.styleMask.contains(.resizable)
            && window.frame.width >= 700
    }

    static func center(_ window: NSWindow, on screen: NSScreen) {
        window.isRestorable = false
        let vis = screen.visibleFrame
        var frame = window.frame
        if frame.width > vis.width { frame.size.width = vis.width - 40 }
        if frame.height > vis.height { frame.size.height = vis.height - 40 }
        frame.origin.x = vis.midX - frame.width / 2
        frame.origin.y = vis.midY - frame.height / 2
        if frame.maxX > vis.maxX { frame.origin.x = vis.maxX - frame.width }
        if frame.minX < vis.minX { frame.origin.x = vis.minX }
        if frame.maxY > vis.maxY { frame.origin.y = vis.maxY - frame.height }
        if frame.minY < vis.minY { frame.origin.y = vis.minY }
        window.setFrame(frame, display: true)
    }
}

/// 창이 생기면 메인 앱이 있는 화면으로 한 번만 옮긴다.
struct PlaceOnAppScreen: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var placed = false
    }

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        func attempt(_ remaining: Int) {
            guard !context.coordinator.placed else { return }
            guard remaining > 0 else { return }
            guard let window = view.window, let screen = WindowPlacement.appScreen() else {
                DispatchQueue.main.async { attempt(remaining - 1) }
                return
            }
            WindowPlacement.center(window, on: screen)
            window.makeKeyAndOrderFront(nil)
            context.coordinator.placed = true
        }
        DispatchQueue.main.async { attempt(12) }
    }
}
