import XCTest
@testable import AncsBridge

final class AncsBridgeTests: XCTestCase {

    // MARK: - Quick reply URL

    func testQuickReplyURLEncodesQuerySeparators() throws {
        let url = try XCTUnwrap(QuickReplyLauncher.shortcutURL(for: "Mom & Dad|On my way = 5 min + traffic?"))
        XCTAssertEqual(url.absoluteString,
                       "shortcuts://run-shortcut?name=WearBridge%20Reply&input=text&text=Mom%20%26%20Dad%7COn%20my%20way%20%3D%205%20min%20%2B%20traffic%3F")
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.map(\.name), ["name", "input", "text"])
        XCTAssertEqual(items.last?.value, "Mom & Dad|On my way = 5 min + traffic?")
    }

    func testQuickReplyURLKeepsUnicode() throws {
        let url = try XCTUnwrap(QuickReplyLauncher.shortcutURL(for: "Léa|J'arrive 🚗"))
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.last?.value, "Léa|J'arrive 🚗")
    }

    // MARK: - Call state

    private let ringing = CallStateObserver.CallInfo(isOutgoing: false, hasConnected: false, hasEnded: false)
    private let answered = CallStateObserver.CallInfo(isOutgoing: false, hasConnected: true, hasEnded: false)
    private let ended = CallStateObserver.CallInfo(isOutgoing: false, hasConnected: true, hasEnded: true)
    private let outgoing = CallStateObserver.CallInfo(isOutgoing: true, hasConnected: true, hasEnded: false)

    func testIncomingCallLifecycle() {
        let idle = BLEConstants.callStateIdle
        XCTAssertEqual(CallStateObserver.state(of: [ringing], previous: idle), BLEConstants.callStateRinging)
        XCTAssertEqual(CallStateObserver.state(of: [answered], previous: BLEConstants.callStateRinging), BLEConstants.callStateActive)
        XCTAssertEqual(CallStateObserver.state(of: [ended], previous: BLEConstants.callStateActive), BLEConstants.callStateEnded)
        XCTAssertEqual(CallStateObserver.state(of: [], previous: BLEConstants.callStateEnded), BLEConstants.callStateEnded)
    }

    func testCallWaitingKeepsTheRingingCall() {
        // Ending the active call while a second one rings must not dismiss the ringing one.
        XCTAssertEqual(CallStateObserver.state(of: [ended, ringing], previous: BLEConstants.callStateRinging),
                       BLEConstants.callStateRinging)
        XCTAssertEqual(CallStateObserver.state(of: [answered, ringing], previous: BLEConstants.callStateActive),
                       BLEConstants.callStateRinging)
        // Declining the waiting call goes back to the active one.
        XCTAssertEqual(CallStateObserver.state(of: [answered, ended], previous: BLEConstants.callStateRinging),
                       BLEConstants.callStateActive)
    }

    func testOutgoingCallsAreIgnored() {
        XCTAssertEqual(CallStateObserver.state(of: [outgoing], previous: BLEConstants.callStateIdle), BLEConstants.callStateIdle)
        XCTAssertEqual(CallStateObserver.state(of: [outgoing, ringing], previous: BLEConstants.callStateIdle),
                       BLEConstants.callStateRinging)
        XCTAssertEqual(CallStateObserver.state(of: [outgoing, ended], previous: BLEConstants.callStateRinging),
                       BLEConstants.callStateEnded)
    }
}
