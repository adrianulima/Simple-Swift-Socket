//
//  Server.swift
//  TvOSConnectivity
//
//  Created by Adriano Lima on 5/12/16.
//
//

import Foundation

@objc protocol ServerDelegate {
    optional func server(server: Server, didReceiveMessage message: [String : AnyObject])
    optional func server(server: Server, didReceiveTextMessage text: String)
    optional func server(server: Server, didReceiveMessageData messageData: NSData)
    optional func server(server: Server, didPublishService service: NSNetService)
    optional func server(server: Server, didAcceptNewUser socket: GCDAsyncSocket)
    optional func server(server: Server, didDisconnectedUser socket: GCDAsyncSocket, withError err: NSError!)
}

class Server: NSObject, NSNetServiceDelegate, NSNetServiceBrowserDelegate, GCDAsyncSocketDelegate {
    
    //TODO: check if we can use timeout different of -1.0
    //TODO: implement header
    //TODO: test p2p btw sockets
    
    var delegate: ServerDelegate?
    private(set) var service: NSNetService?
    private(set) var socket: GCDAsyncSocket?
    private(set) var connectedSockets : [GCDAsyncSocket]?
    
    func startService(name: String, onPort port: UInt16, inDomain domain: String = "local.") {
        self.socket = GCDAsyncSocket(delegate: self, delegateQueue: dispatch_get_main_queue())
        do {
            try self.socket?.acceptOnPort(port)
            self.service = NSNetService(domain: domain, type: "_\(name)._tcp.", name: name, port: Int32(port))
            self.service?.delegate = self
            self.service?.publish()
            self.connectedSockets = []
            self.delegate?.server?(self, didPublishService: self.service!)
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
    
    func send(clientSocket: GCDAsyncSocket, messageData: NSData) {
        clientSocket.writeData(messageData, withTimeout: -1.0, tag: 0)
    }
    func send(clientSocket: GCDAsyncSocket, message: [String : AnyObject]) {
        if let data:NSData = NSKeyedArchiver.archivedDataWithRootObject(message) {
            send(clientSocket, messageData: data)
        }
    }
    func send(clientSocket: GCDAsyncSocket, textMessage: String) {
        if let data = textMessage.dataUsingEncoding(NSUTF8StringEncoding) {
            send(clientSocket, messageData: data)
        }
    }
    
    func broadcastData(messageData: NSData) {
        for client in connectedSockets! {
            send(client, messageData: messageData)
        }
    }
    func broadcast(message: [String : AnyObject]) {
        if let data:NSData = NSKeyedArchiver.archivedDataWithRootObject(message) {
            broadcastData(data)
        }
    }
    func broadcastText(textMessage: String) {
        if let data = textMessage.dataUsingEncoding(NSUTF8StringEncoding) {
            broadcastData(data)
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
            delegate?.server?(self, didReceiveTextMessage: text)
        }
        sock.readDataWithTimeout(-1.0, tag: 0)
    }
}