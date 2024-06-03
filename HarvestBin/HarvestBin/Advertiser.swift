//
//  Advertiser.swift
//  HarvestBin
//
//  Created by Leo on 5/28/24.
//

import Foundation
import MultipeerConnectivity


class Advertiser : NSObject, MCNearbyServiceAdvertiserDelegate, MCSessionDelegate {

    let session : MCSession
    let advertiser : MCNearbyServiceAdvertiser
    var receiver : GuestServiceReceiver!
    
    override init () {
        let peerID = MCPeerID(displayName: "host")
        session = MCSession(peer: peerID)
        advertiser = .init(peer: peerID, discoveryInfo: nil, serviceType: "bushelgs")
        
        super.init()
        
        advertiser.delegate = self
        session.delegate = self
        
    }
    

    func startWith(receiver: GuestServiceReceiver) {
        assert(self.receiver == nil)
        self.receiver = receiver
        self.advertiser.startAdvertisingPeer()
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        dump(error)
    }
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        
        session.connectPeer(peerID, withNearbyConnectionData: .init())
        invitationHandler(true, session)
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        
            print("session \(session.myPeerID) with \(peerID) did start receive resource \(resourceName)")
    }
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
    }
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
    }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        self.receiver.didReceiveData(data)
    }
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        self.receiver.connectionUpdateTo(.init(state: state, peerID: peerID))
    }
    
}

extension ConnectionStatus {
    init(state: MCSessionState, peerID: MCPeerID) {
        self.init(rawValue: state.rawValue, displayName: peerID.displayName)
    }
    
}
