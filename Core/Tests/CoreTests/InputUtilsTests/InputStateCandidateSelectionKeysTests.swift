import Core
import Foundation
import KanaKanjiConverterModule
import Testing

private func characterEvent(_ character: String, keyCode: UInt16, modifierFlags: KeyEventCore.ModifierFlag = []) -> KeyEventCore {
    KeyEventCore(
        modifierFlags: modifierFlags,
        characters: character,
        charactersIgnoringModifiers: character,
        keyCode: keyCode
    )
}

private func selectingEvent(
    _ event: KeyEventCore,
    userAction: UserAction,
    candidateSelectionKeys: Config.CandidateSelectionKeys.Value
) -> ClientAction {
    InputState.selecting.event(
        eventCore: event,
        userAction: userAction,
        inputLanguage: .japanese,
        liveConversionEnabled: false,
        enableDebugWindow: false,
        enableSuggestion: false,
        candidateSelectionKeys: candidateSelectionKeys
    ).0
}

@Suite("候補選択キーの設定")
struct InputStateCandidateSelectionKeysTests {
    @Test("Dvorakのホーム段で候補を確定する", arguments: zip(["a", "o", "e", "u", "i", "d", "h", "t", "n"], 1...9))
    func dvorakHomeRowSelectsCandidate(key: String, expectedNumber: Int) {
        let action = selectingEvent(
            characterEvent(key, keyCode: 0),
            userAction: .input([.character(Character(key))]),
            candidateSelectionKeys: .dvorakHomeRow
        )
        guard case .selectNumberCandidate(let number) = action else {
            Issue.record("Expected selectNumberCandidate, got \(action)")
            return
        }
        #expect(number == expectedNumber)
    }

    @Test("Dvorakのホーム段以外の文字は確定して入力を続ける")
    func otherCharacterContinuesInput() {
        let action = selectingEvent(
            characterEvent("k", keyCode: 0),
            userAction: .input([.character("k")]),
            candidateSelectionKeys: .dvorakHomeRow
        )
        guard case .commitMarkedTextAndAppendPieceToMarkedText = action else {
            Issue.record("Expected commitMarkedTextAndAppendPieceToMarkedText, got \(action)")
            return
        }
    }

    @Test("Shiftつきのホーム段の文字では候補を確定しない")
    func shiftedCharacterContinuesInput() {
        let action = selectingEvent(
            characterEvent("A", keyCode: 0, modifierFlags: .shift),
            userAction: .input([.character("A")]),
            candidateSelectionKeys: .dvorakHomeRow
        )
        guard case .commitMarkedTextAndAppendPieceToMarkedText = action else {
            Issue.record("Expected commitMarkedTextAndAppendPieceToMarkedText, got \(action)")
            return
        }
    }

    @Test("Dvorakのホーム段を選んだときは数字で候補を確定しない")
    func numberContinuesInputWithDvorakHomeRow() {
        let action = selectingEvent(
            characterEvent("1", keyCode: 18),
            userAction: .number(.one),
            candidateSelectionKeys: .dvorakHomeRow
        )
        guard case .commitMarkedTextAndAppendPieceToMarkedText = action else {
            Issue.record("Expected commitMarkedTextAndAppendPieceToMarkedText, got \(action)")
            return
        }
    }

    @Test("1〜9を選んだときは数字で候補を確定し、文字では確定しない")
    func numbersSetting() {
        let numberAction = selectingEvent(
            characterEvent("2", keyCode: 19),
            userAction: .number(.two),
            candidateSelectionKeys: .numbers
        )
        guard case .selectNumberCandidate(2) = numberAction else {
            Issue.record("Expected selectNumberCandidate(2), got \(numberAction)")
            return
        }

        let characterAction = selectingEvent(
            characterEvent("a", keyCode: 0),
            userAction: .input([.character("a")]),
            candidateSelectionKeys: .numbers
        )
        guard case .commitMarkedTextAndAppendPieceToMarkedText = characterAction else {
            Issue.record("Expected commitMarkedTextAndAppendPieceToMarkedText, got \(characterAction)")
            return
        }
    }
}
