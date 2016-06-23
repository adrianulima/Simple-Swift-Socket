# Simple-Swift-Socket
This is a simple socket library in Swift, very easy to understand and use.

Server
=====================
~~~~~ swift
let server = Server()
server.delegate = self
server.startService("Teste", onPort: 8000, inDomain: "local.")
//or
let server = Server()
server.delegate = self
server.listen(onPort: 8000)
~~~~~

ServerDelegate
~~~~~ swift
func server(server: Server, didPublishService service: NSNetService) {
  print("\(NSProcessInfo.processInfo().hostName):\(service.port)")
}
func server(server: Server, didConnectedUser socket: GCDAsyncSocket) {
  print("connected user")
}
func server(server: Server, didReceiveMessageData messageData: NSData) {
  print(String(data: messageData, encoding: NSUTF8StringEncoding))
}
~~~~~
~~~~~ swift
optional func server(server: Server, didReceiveMessage message: [String : AnyObject])
optional func server(server: Server, didReceiveTextMessage text: String)
optional func server(server: Server, didReceiveMessageData messageData: NSData)
optional func server(server: Server, didStartListenning port: UInt16)
optional func server(server: Server, didPublishService service: NSNetService)
optional func server(server: Server, didAcceptNewUser socket: GCDAsyncSocket)
optional func server(server: Server, didDisconnectedUser socket: GCDAsyncSocket, withError err: NSError!)
~~~~~
