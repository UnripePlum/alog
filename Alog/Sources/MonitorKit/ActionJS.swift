import Foundation

/// 동작 명세가 유효하지 않을 때.
public enum ActionError: Error, Equatable, Sendable {
    case missingSelector
    case missingText
}

/// 한 동작을 실제 실행하기 위한 계획 (순수 값 — 테스트 가능).
/// preDelayMs: 스크립트 실행 전 대기(대기 동작 등).
/// script: WebPage.callJavaScript 에 넘길 함수 본문. nil이면 JS 없이 성공 처리(대기).
public struct ActionPlan: Equatable, Sendable {
    public var preDelayMs: Int
    public var script: String?

    public init(preDelayMs: Int, script: String?) {
        self.preDelayMs = preDelayMs
        self.script = script
    }
}

public enum ActionJS {

    /// ActionSpec → 실행 계획. 성공/실패는 script가 boolean을 return 하도록 구성.
    public static func plan(for spec: ActionSpec) -> Result<ActionPlan, ActionError> {
        switch spec.kind {
        case .hasTitle:
            return .success(ActionPlan(
                preDelayMs: 0,
                script: "return !!(document.title && document.title.trim().length > 0);"
            ))

        case .bodyHasText:
            // 본문 텍스트 확인. 외부 문서가 비어있으면 같은 출처 iframe(예: 네이버 #mainFrame)도 확인.
            return .success(ActionPlan(
                preDelayMs: 0,
                script: """
                function textLen(doc) {
                  try { return (((doc && doc.body && doc.body.innerText) || '').trim().length); }
                  catch (e) { return 0; }
                }
                let n = textLen(document);
                for (const f of document.querySelectorAll('iframe')) {
                  try { n = Math.max(n, textLen(f.contentDocument)); } catch (e) {}
                }
                return n > 20;
                """
            ))

        case .scrollToBottom:
            // 맨 아래까지 스크롤. 짧아서 스크롤 불필요한 문서는 정상으로 간주.
            // 같은 출처 iframe(네이버 등)이 있으면 프레임 안도 스크롤 시도.
            return .success(ActionPlan(
                preDelayMs: 0,
                script: """
                function scrollDoc(win, doc) {
                  try {
                    const el = doc.documentElement;
                    const h = Math.max(el.scrollHeight, doc.body ? doc.body.scrollHeight : 0);
                    const vh = win.innerHeight;
                    if (h <= vh + 1) { return true; }
                    win.scrollTo(0, h);
                    return (win.scrollY + vh) >= (h - 4);
                  } catch (e) { return false; }
                }
                let ok = scrollDoc(window, document);
                for (const f of document.querySelectorAll('iframe')) {
                  try { if (scrollDoc(f.contentWindow, f.contentDocument) === true) { ok = true; } }
                  catch (e) {}
                }
                return ok === true;
                """
            ))

        case .pageLoaded:
            return .success(ActionPlan(
                preDelayMs: 0,
                script: "return document.readyState === 'complete';"
            ))

        case .checkSelector:
            guard !spec.selector.isEmpty else { return .failure(.missingSelector) }
            let sel = jsString(spec.selector)
            return .success(ActionPlan(
                preDelayMs: 0,
                script: "return document.querySelector(\(sel)) !== null;"
            ))

        case .checkText:
            guard !spec.text.isEmpty else { return .failure(.missingText) }
            let txt = jsString(spec.text)
            return .success(ActionPlan(
                preDelayMs: 0,
                script: "return ((document.body && document.body.innerText) || '').includes(\(txt));"
            ))

        case .click:
            guard !spec.selector.isEmpty else { return .failure(.missingSelector) }
            let sel = jsString(spec.selector)
            return .success(ActionPlan(
                preDelayMs: 0,
                script: "const e = document.querySelector(\(sel)); if (!e) { return false; } e.click(); return true;"
            ))

        case .scroll:
            return .success(ActionPlan(
                preDelayMs: 0,
                script: "window.scrollBy(0, \(spec.pixels)); return true;"
            ))

        case .wait:
            // JS 없이 preDelay만 주고 성공.
            return .success(ActionPlan(preDelayMs: max(0, spec.ms), script: nil))
        }
    }

    /// 문자열을 안전한 JS 문자열 리터럴로 인코딩 (JSON 인코딩 사용).
    static func jsString(_ s: String) -> String {
        if let data = try? JSONEncoder().encode(s),
           let lit = String(data: data, encoding: .utf8) {
            return lit
        }
        // 폴백: 매우 방어적 (도달하기 어려움)
        return "\"\""
    }
}
