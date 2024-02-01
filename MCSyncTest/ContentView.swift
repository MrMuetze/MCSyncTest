//
//  ContentView.swift
//  MCSyncTest
//
//  Created by Björn Wieczoreck on 31.01.24.
//

import MultipeerConnectivity
import SwiftUI

struct ContentView: View {
    @ObservedObject var sessionHelper = SessionHelper()

    var body: some View {
        VStack {
            ForEach(sessionHelper.foundPeers) { peer in
                Text("\(peer)").onTapGesture {
                    sessionHelper.joinSession(peerID: peer)
                }
            }
            Text("\(sessionHelper.sliderValue)")
            Slider(value: $sessionHelper.sliderValue)
            Button(action: { sessionHelper.startAdvertising() }, label: {
                Text("Advertise")
            })
        }
        .padding().onAppear {
            sessionHelper.startBrowsing()
        }
    }
}

extension MCPeerID: Identifiable {}

class SessionHelper: NSObject, ObservableObject {
    static let shared: SessionHelper = .init()

    static let serviceType = "mctest"
    let myPeerID = MCPeerID(displayName: UIDevice.current.name)

    @Published var foundPeers = [MCPeerID]()
    var session: MCSession?
    var advertiser: MCNearbyServiceAdvertiser?
    var browser: MCNearbyServiceBrowser?

    var internalSliderValue = 0.0

    @Published var sliderValue = 0.0 {
        didSet {
            if internalSliderValue != sliderValue {
                internalSliderValue = sliderValue
                do {
                    try sendUpdate(newVal: sliderValue)
                } catch {
                    print(error)
                }
            }
        }
    }

    func startAdvertising() {
        session = MCSession(
            peer: myPeerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )

        session?.delegate = self

        advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: nil,
            serviceType: SessionHelper.serviceType
        )
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        print("started advertising")
    }

    func startBrowsing() {
        foundPeers = [MCPeerID]()
        if browser == nil {
            browser = MCNearbyServiceBrowser(
                peer: myPeerID,
                serviceType: SessionHelper.serviceType
            )
        }
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        print("started browsing")
    }

    func joinSession(peerID: MCPeerID) {
        session = MCSession(
            peer: myPeerID,
            securityIdentity: nil,
            encryptionPreference: .required
        )
        session?.delegate = self
        if let session = session {
            browser?.invitePeer(peerID, to: session, withContext: nil, timeout: 0)
        }
    }

    func sendUpdate(newVal: Double) throws {
        guard let session = session else {
            return
        }
        print("sending value to \(session.connectedPeers.count) peers(s)")
        try session.send(Data(from: newVal), toPeers: session.connectedPeers, with: .unreliable)
    }
}

extension SessionHelper: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("issue advertising connection: \(error.localizedDescription)")
    }

    func advertiser(
        _: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer _: MCPeerID,
        withContext _: Data?,
        invitationHandler handler: @escaping (Bool, MCSession?) -> Void
    ) {
        handler(true, session)
    }
}

extension SessionHelper: MCNearbyServiceBrowserDelegate {
    func browser(_: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("issue browsing for peers: \(error.localizedDescription)")
    }

    func browser(
        _: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo _: [String: String]?
    ) {
        // we don't find ourselves here
        if !foundPeers.contains(peerID) {
            foundPeers.append(peerID)
        }
    }

    func browser(_: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        foundPeers.removeAll { $0 == peerID }
    }
}

extension SessionHelper: MCSessionDelegate {
    func session(_: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connected: print("\(peerID.displayName) connected")
        case .connecting: print("connecting ...")
        case .notConnected: print("disconnected")
        @unknown default:
            fatalError("unknown MCSession connection state occurred")
        }
    }

    func session(_: MCSession, didReceive data: Data, fromPeer _: MCPeerID) {
        print("received data")
        DispatchQueue.main.async {
            print("doing stuff")
            let doubleVal = data.to(type: Double.self) ?? 0.0
            self.internalSliderValue = doubleVal
            self.sliderValue = doubleVal
        }
    }

    func session(_: MCSession, didReceive _: InputStream, withName _: String,
                 fromPeer _: MCPeerID) {}

    func session(
        _: MCSession,
        didStartReceivingResourceWithName _: String,
        fromPeer _: MCPeerID,
        with _: Progress
    ) {}

    func session(
        _: MCSession,
        didFinishReceivingResourceWithName _: String,
        fromPeer _: MCPeerID,
        at _: URL?,
        withError _: Error?
    ) {}
}

extension Data {
    init<T>(from value: T) {
        self = Swift.withUnsafeBytes(of: value) { Data($0) }
    }

    func to<T>(type _: T.Type) -> T? where T: ExpressibleByIntegerLiteral {
        var value: T = 0
        guard count >= MemoryLayout.size(ofValue: value) else { return nil }
        _ = Swift.withUnsafeMutableBytes(of: &value) { copyBytes(to: $0) }
        return value
    }
}

#Preview {
    ContentView()
}
