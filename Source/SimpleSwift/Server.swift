//
//  Created by Adriano Lima in 2016.
//

import Foundation

@objc protocol ServerDelegate {
    optional func server(server: Server, didReceiveMessage dict: [String : AnyObject])
    optional func server(server: Server, didReceiveText string: String)
    optional func server(server: Server, didReceiveMessageData data: NSData)
    optional func server(server: Server, didStartListenning port: UInt16)
    optional func server(server: Server, didPublishService service: NSNetService)
    optional func server(server: Server, didAcceptNewUser socket: GCDAsyncSocket)
    optional func server(server: Server, didDisconnectedUser socket: GCDAsyncSocket, withError err: NSError!)
}

class Server: NSObject, NSNetServiceDelegate, NSNetServiceBrowserDelegate, GCDAsyncSocketDelegate {
    
    //TODO: check if we can use timeout different of -1.0
    //TODO: implement header messages
    
    var delegate: ServerDelegate?
    private(set) var service: NSNetService?
    private(set) var socket: GCDAsyncSocket?
    private(set) var connectedSockets : [GCDAsyncSocket]?
    
    func listen(onPort port: UInt16) {
        createSocketAndListen(onPort: port)
    }
    
    func startService(name: String, onPort port: UInt16, inDomain domain: String = "local.") {
        createSocketAndListen(onPort: port, name: name, inDomain: domain)
    }
    
    private func createSocketAndListen(onPort port: UInt16, name: String? = nil, inDomain domain: String? = nil) {
        self.socket = GCDAsyncSocket(delegate: self, delegateQueue: dispatch_get_main_queue())
        do {
            try self.socket?.acceptOnPort(port)
            self.delegate?.server?(self, didStartListenning: port)
            self.connectedSockets = []
            if name != nil && domain != nil {
                self.service = NSNetService(domain: domain!, type: "_\(name)._tcp.", name: name!, port: Int32(port))
                self.service?.delegate = self
                self.service?.publish()
                self.delegate?.server?(self, didPublishService: self.service!)
            }
        } catch let error as NSError {
            print("Failed to create server socket. Error \(error)")
        }
    }
    
    func stopService() {
        self.service?.stop()
        self.socket?.disconnect()
        self.connectedSockets?.removeAll()
        
        self.service = nil
        self.socket = nil
        self.connectedSockets = nil
    }
    
    func send(clientSocket: GCDAsyncSocket, messageData: NSData, withTimeout timeout: NSTimeInterval = -1.0) {
        clientSocket.writeData(messageData, withTimeout: timeout, tag: 0)
    }
    
    func send(clientSocket: GCDAsyncSocket, message: [String : AnyObject], withTimeout timeout: NSTimeInterval = -1.0) {
        if let data:NSData = NSKeyedArchiver.archivedDataWithRootObject(message) {
            send(clientSocket, messageData: data, withTimeout: timeout)
        }
    }
    
    func send(clientSocket: GCDAsyncSocket, text: String, withTimeout timeout: NSTimeInterval = -1.0) {
        if let data = text.dataUsingEncoding(NSUTF8StringEncoding) {
            send(clientSocket, messageData: data, withTimeout: timeout)
        }
    }
    
    func broadcast(messageData data: NSData, withTimeout timeout: NSTimeInterval = -1.0) {
        for client in connectedSockets! {
            send(client, messageData: data, withTimeout: timeout)
        }
    }
    
    func broadcast(message dict: [String : AnyObject], withTimeout timeout: NSTimeInterval = -1.0) {
        if let data:NSData = NSKeyedArchiver.archivedDataWithRootObject(dict) {
            broadcast(messageData: data, withTimeout: timeout)
        }
    }
    
    func broadcast(text string: String, withTimeout timeout: NSTimeInterval = -1.0) {
        if let data = string.dataUsingEncoding(NSUTF8StringEncoding) {
            broadcast(messageData: data, withTimeout: timeout)
        }
    }
    
    func netServiceDidPublish(sender: NSNetService) {
        print("Service published: domain: \(sender.domain) type: \(sender.type) name: \(sender.name) hostName: \(sender.hostName)  port: \(sender.port)")
    }
    
    func netService(sender: NSNetService, didNotPublish errorDict: [String : NSNumber]) {
        print("Failed to publish service: domain: \(sender.domain) type: \(sender.type) name: \(sender.name) - \(errorDict)")
    }
    
    func socket(sock: GCDAsyncSocket!, didAcceptNewSocket newSocket: GCDAsyncSocket!) {
        newSocket.readDataWithTimeout(-1.0, tag: 0)
        
        connectedSockets?.append(newSocket)
        delegate?.server?(self, didAcceptNewUser: newSocket)
    }
    
    func socketDidDisconnect(sock: GCDAsyncSocket!, withError err: NSError!) {
        let idx = connectedSockets?.indexOf(sock)
        if idx >= 0 {
            connectedSockets?.removeAtIndex(idx!)
            delegate?.server?(self, didDisconnectedUser: sock, withError: err)
        }
    }
    
    func socket(sock: GCDAsyncSocket!, didWriteDataWithTag tag: Int) {
        //print("Write data is done")
    }
    
    func socket(sock: GCDAsyncSocket!, didReadData data: NSData!, withTag tag: Int) {
        delegate?.server?(self, didReceiveMessageData: data)
        if let dict = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? [String : AnyObject] {
            delegate?.server?(self, didReceiveMessage: dict)
        }
        if let text = String(data: data, encoding: NSUTF8StringEncoding) {
            delegate?.server?(self, didReceiveText: text)
        }
        sock.readDataWithTimeout(-1.0, tag: 0)
    }
}