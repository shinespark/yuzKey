import Foundation

/// InputMethodKit の同期 `handle` が返すイベント所有権だけを判断する。
///
/// 変換状態の本体は ConverterServer が所有する。Client は Server が最後に返した
/// 読み取り専用の状態を使い、明らかな application shortcut を同期的に通す。
/// Server の応答待ちがある間は状態が進んでいる可能性があるため、Command shortcut
/// 以外を保守的に consume し、生のキー入力が application へ漏れることを防ぐ。
public enum ConverterClientEventDisposition: Sendable, Equatable {
    case sendToServer
    case fallthroughToApplication
}

public struct ConverterClientEventRoutingContext: Sendable, Equatable {
    public var acknowledgedInputState: ConverterInputState
    public var acknowledgedInputLanguage: InputLanguage
    public var hasPendingKeyEvents: Bool
    public var liveConversionEnabled: Bool
    public var enableDebugWindow: Bool
    public var enableSuggestion: Bool
    public var typeBackSlash: Bool
    public var candidateSelectionKeys: Config.CandidateSelectionKeys.Value

    public init(
        acknowledgedInputState: ConverterInputState = .none,
        acknowledgedInputLanguage: InputLanguage = .japanese,
        hasPendingKeyEvents: Bool = false,
        liveConversionEnabled: Bool = true,
        enableDebugWindow: Bool = false,
        enableSuggestion: Bool = false,
        typeBackSlash: Bool = false,
        candidateSelectionKeys: Config.CandidateSelectionKeys.Value = .numbers
    ) {
        self.acknowledgedInputState = acknowledgedInputState
        self.acknowledgedInputLanguage = acknowledgedInputLanguage
        self.hasPendingKeyEvents = hasPendingKeyEvents
        self.liveConversionEnabled = liveConversionEnabled
        self.enableDebugWindow = enableDebugWindow
        self.enableSuggestion = enableSuggestion
        self.typeBackSlash = typeBackSlash
        self.candidateSelectionKeys = candidateSelectionKeys
    }
}

public enum ConverterClientEventRouter {
    public static func disposition(
        event: KeyEventCore,
        context: ConverterClientEventRoutingContext
    ) -> ConverterClientEventDisposition {
        // Command shortcut は composition の有無にかかわらず application が所有する。
        if event.modifierFlags.contains(.command) {
            return .fallthroughToApplication
        }

        // 未応答イベントがある場合、acknowledgedInputState は古い可能性がある。
        // ここで fallthrough するとタイムアウトした文字が英字として漏れるため、
        // Server が順番に処理できるようイベントを consume する。
        if context.hasPendingKeyEvents {
            return .sendToServer
        }

        if case .fallthrough = action(event: event, context: context) {
            return .fallthroughToApplication
        }
        return .sendToServer
    }

    /// Server の応答は非同期のため、`handle` が返る時点では marked text が空のままになる。
    /// その間に生のキーを application へ送る client（Ghostty など）があるので、
    /// composition を始めるキーは入力文字を仮の marked text として同期的に表示する。
    public static func provisionalMarkedText(
        event: KeyEventCore,
        context: ConverterClientEventRoutingContext
    ) -> String? {
        guard !context.hasPendingKeyEvents,
              context.acknowledgedInputState.inputState == .none else {
            return nil
        }
        guard case .appendPieceToMarkedText(let pieces) = action(event: event, context: context) else {
            return nil
        }
        let text = pieces.inputString(preferIntention: true)
        return text.isEmpty ? nil : text
    }

    private static func action(
        event: KeyEventCore,
        context: ConverterClientEventRoutingContext
    ) -> ClientAction {
        let inputState = context.acknowledgedInputState.inputState
        let userAction = UserAction.getUserAction(
            eventCore: event,
            inputLanguage: context.acknowledgedInputLanguage,
            typeBackSlash: context.typeBackSlash
        )
        return inputState.event(
            eventCore: event,
            userAction: userAction,
            inputLanguage: context.acknowledgedInputLanguage,
            liveConversionEnabled: context.liveConversionEnabled,
            enableDebugWindow: context.enableDebugWindow,
            enableSuggestion: context.enableSuggestion,
            candidateSelectionKeys: context.candidateSelectionKeys
        ).0
    }
}
