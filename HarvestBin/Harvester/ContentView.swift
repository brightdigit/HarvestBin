//
//  ContentView.swift
//  Harvester
//
//  Created by Leo Dion on 5/28/24.
//

import SwiftUI
import MultipeerConnectivity

class BrowserListener : NSObject, MCNearbyServiceBrowserDelegate, MCSessionDelegate {
  internal init(displayName : String) {
    let id = MCPeerID(displayName: displayName)
    session = MCSession(peer: id)
    browser = .init(peer: id, serviceType: "bushelgs")
    
    super.init()
    
    session.delegate = self
    browser.delegate = self
  }
  
  var receiver : BrowserReceiver!
  
  let session : MCSession
  let browser : MCNearbyServiceBrowser
  
  func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
    self.receiver.stateChangedTo(state, for: peerID)
  }
  
  func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
    
  }
  
  func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
    
  }
  
  func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
    
  }
  
  func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: (any Error)?) {
    
  }
  
  func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
    self.receiver.foundPeer(peerID)
    browser.invitePeer(peerID, to: session, withContext: nil, timeout: 5.0)
  }
  
  func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    self.receiver.lostPeer(peerID)
  }
  
  func startWith(receiver: BrowserReceiver) {
    self.receiver = receiver
    self.browser.startBrowsingForPeers()
  }
  
  func sendData(_ data: Data, to peers: [MCPeerID]) throws {
    try self.session.send(data, toPeers: peers, with: .reliable)
  }
}

protocol BrowserReceiver {
  func foundPeer(_ peerID: MCPeerID)
  func lostPeer(_ peerID: MCPeerID)
  func stateChangedTo(_ state: MCSessionState, for peerID: MCPeerID)
}

enum PeerState {
  case initialized
  case found
  case connectingTo
  case notConnected
  case connected
  case unknown
}

extension PeerState {
  init(state: MCSessionState) {
    switch state {
    case .connected:
      self = .connected
    case .connecting:
      self = .connectingTo
    case .notConnected:
      self = .notConnected
    @unknown default:
      assertionFailure("Unknown state: \(state)")
      self = .unknown
    }
  }
}
struct Peer : Identifiable, Hashable {
  internal init(id: MCPeerID, state: PeerState = .found) {
    self.id = id
    self.state = state
  }
  
  static func == (lhs: Peer, rhs: Peer) -> Bool {
    lhs.id == rhs.id
  }
  
  let id : MCPeerID
  var state : PeerState
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

@Observable
class MachineListObject: BrowserReceiver {
  func foundPeer(_ peerID: MCPeerID) {
    assert(peerDictionary[peerID] == nil)
    peerDictionary[peerID] = .found
  }
  
  func lostPeer(_ peerID: MCPeerID) {
    assert(peerDictionary.removeValue(forKey: peerID) != nil)
  }
  
  func stateChangedTo(_ state: MCSessionState, for peerID: MCPeerID) {
    //assert(peerDictionary[peerID] != nil)
    peerDictionary[peerID] = .init(state: state)
  }
  
  public convenience init (displayName : String) {
    self.init(listener: .init(displayName: displayName))
  }
  private init(listener: BrowserListener) {
    
    self.listener = listener
  }
  
  var peerIDs = [MCPeerID]()
  var peerDictionary = [MCPeerID : PeerState]() {
    didSet {
      peerIDs = .init(peerDictionary.keys)
    }
  }
  
  @ObservationIgnored
  let listener : BrowserListener
  
  var error : (any Error)?
  
  func send (_ message: String, to peerIDs: [MCPeerID]) {
    assert(!peerIDs.isEmpty)
    guard let data = message.data(using: .utf8) else {
      assertionFailure("Can't make data.")
      return
    }
    
    do {
      try listener.sendData(data, to: peerIDs)
    } catch {
      assert(error == nil)
      dump(error)
      return
    }
  }
  
  func start () {
    self.listener.startWith(receiver: self)
  }
}

extension MCPeerID : Identifiable {
  public var id: String {
    return self.displayName
  }
}

struct ContentView: View {
  @State var text = "Hello World"
  var object : MachineListObject
  @State var selectedPeerIDs = [MCPeerID]()
    var body: some View {
        VStack {
          List(selection: self.$selectedPeerIDs){
            ForEach(self.object.peerIDs) { key in
              Text(key.displayName)
            }
          }
          HStack{
            TextField("Message", text: self.$text)
            Button {
              self.object.send(self.text, to: selectedPeerIDs)
            } label: {
              Text("Send")
            }.disabled(self.selectedPeerIDs.isEmpty)
          }
        }
        .padding()
        .onAppear{
          self.object.start()
        }
    }
}

#Preview {
  ContentView(object: .init(displayName: "preview"))
}
