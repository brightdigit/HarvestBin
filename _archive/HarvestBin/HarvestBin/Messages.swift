import Foundation
struct BaseMessage : Codable {
  let id : UUID
}

protocol Message : Codable {
  var id : UUID { get }
    associatedtype Reply : Message
}

struct SystemProfileReply : Message {
  let id : UUID
  let profile : SystemProfiler
  
  typealias Reply = SystemProfileMessage
}

struct SystemProfileMessage: Message {
    let id : UUID
    typealias Reply = SystemProfileReply
}
