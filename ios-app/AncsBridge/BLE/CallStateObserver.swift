import CallKit
import os.log

/// Observes phone call state via CallKit's CXCallObserver and notifies
/// a delegate when the state changes. Used for live call status sync to watch.
///
/// Only active when "Live Call Status" is enabled in settings.
class CallStateObserver: NSObject {

    private let logger = Logger(subsystem: "com.wearos.ancsbridge", category: "CallStateObserver")
    private let callObserver = CXCallObserver()

    /// Called whenever call state changes. Values match BLEConstants.callState* constants.
    var onCallStateChanged: ((UInt8) -> Void)?

    /// Current call state (for reads)
    private(set) var currentState: UInt8 = BLEConstants.callStateIdle

    private var isObserving = false
    private var idleReset: DispatchWorkItem?

    /// What the watch needs to know about one call.
    struct CallInfo: Equatable {
        let isOutgoing: Bool
        let hasConnected: Bool
        let hasEnded: Bool
    }

    func startObserving() {
        guard !isObserving else { return }
        callObserver.setDelegate(self, queue: nil)
        isObserving = true
        currentState = Self.state(of: callObserver.calls.map(Self.info), previous: BLEConstants.callStateIdle)
        logger.info("Started observing call state")
    }

    func stopObserving() {
        callObserver.setDelegate(nil, queue: nil)
        isObserving = false
        idleReset?.cancel()
        idleReset = nil
        currentState = BLEConstants.callStateIdle
        logger.info("Stopped observing call state")
    }

    /// The state to show on the watch, from every call iOS knows about. An incoming call still
    /// ringing wins (call waiting), then an answered incoming call. Outgoing calls are ignored:
    /// the watch only shows incoming ones. When the last incoming call goes away the watch gets
    /// "ended", which `callChanged` turns back into idle 2 s later.
    static func state(of calls: [CallInfo], previous: UInt8) -> UInt8 {
        let incoming = calls.filter { !$0.isOutgoing && !$0.hasEnded }
        if incoming.contains(where: { !$0.hasConnected }) { return BLEConstants.callStateRinging }
        if !incoming.isEmpty { return BLEConstants.callStateActive }
        switch previous {
        case BLEConstants.callStateRinging, BLEConstants.callStateActive, BLEConstants.callStateEnded:
            return BLEConstants.callStateEnded
        default:
            return BLEConstants.callStateIdle
        }
    }

    private static func info(_ call: CXCall) -> CallInfo {
        CallInfo(isOutgoing: call.isOutgoing, hasConnected: call.hasConnected, hasEnded: call.hasEnded)
    }

    private func publish(_ newState: UInt8) {
        guard newState != currentState else { return }
        currentState = newState

        let stateStr: String
        switch newState {
        case BLEConstants.callStateRinging: stateStr = "ringing"
        case BLEConstants.callStateActive: stateStr = "active"
        case BLEConstants.callStateEnded: stateStr = "ended"
        default: stateStr = "idle"
        }
        logger.info("Call state changed: \(stateStr)")
        onCallStateChanged?(newState)
    }
}

extension CallStateObserver: CXCallObserverDelegate {

    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        guard isObserving else { return }

        // `calls` plus the call that just changed, in case the list lags behind the callback.
        var calls = Dictionary(callObserver.calls.map { ($0.uuid, Self.info($0)) }, uniquingKeysWith: { _, last in last })
        calls[call.uuid] = Self.info(call)

        idleReset?.cancel()
        idleReset = nil
        publish(Self.state(of: Array(calls.values), previous: currentState))

        // Back to idle shortly after "ended", unless another call changed things meanwhile.
        if currentState == BLEConstants.callStateEnded {
            let reset = DispatchWorkItem { [weak self] in
                guard let self, self.isObserving, self.currentState == BLEConstants.callStateEnded else { return }
                self.publish(BLEConstants.callStateIdle)
            }
            idleReset = reset
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: reset)
        }
    }
}
