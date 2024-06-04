//
//  GuestServicesObject.swift
//  HarvestBin
//
//  Created by Leo on 5/28/24.
//

import Foundation

protocol GuestServiceReceiver {
    func didReceiveData(_ data: Data)
    func connectionUpdateTo(_ status: ConnectionStatus)
    
}
enum ConnectionStatus {
    case initialized
    case connectingTo(String)
    case notConnected
    case connected(String)
    case unknown(String)
}
class GuestServicesObject : ObservableObject, GuestServiceReceiver {
    func didReceiveData(_ data: Data) {
        guard let newMessage = String(bytes: data, encoding: .utf8) else {
            assertionFailure("Unable to interpert data")
            return
        }
        DispatchQueue.main.async {
            self.lastMessage = newMessage
        }
    }
    
    func connectionUpdateTo(_ status: ConnectionStatus) {
        
        DispatchQueue.main.async {
            self.connectedState = status
        }
    }
    
    @Published var lastMessage = ""
    @Published var connectedState = ConnectionStatus.initialized
    let advertiser : Advertiser
    
    init () {
        self.advertiser = .init()
    }
    
    func start () {
        self.advertiser.startWith(receiver: self)
    }
}

extension ConnectionStatus {
    
    init(rawValue: Int, displayName: String) {
        assert(rawValue >= 0 && rawValue <= 2)
        switch rawValue {
        case 0:
            self = .notConnected
        case 1:
            self = .connectingTo(displayName)
        case 2:
            self = .connected(displayName)
        default:
            
            self = .unknown(displayName)
        }
    }
}
