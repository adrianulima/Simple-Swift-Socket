//
//  Client.swift
//  TvOSConnectivity
//
//  Created by Adriano Lima on 5/12/16.
//
//

import Foundation

@objc protocol ClientDelegate {
    optional func client(client: Client, didReceiveMessage message: [String : AnyObject])
    optional func client(client: Client, didReceiveTextMessage text: String)
    optional func client(client: Client, didReceiveMessageData messageData: NSData)
    optional func client(client: Client, didFoundService service: NSNetService, moreComing: Bool)
    optional func client(client: Client, didResolveAddress service: NSNetService)
    optional func client(client: Client, didConnected socket: GCDAsyncSocket, host: String!, port: UInt16)
    optional func client(client: Client, didDisconnected socket: GCDAsyncSocket, withError err: NSError!)
}

class Client: NSObject, NSNetServiceBrowserDelegate, NSNetServiceDelegate, GCDAsyncSocketDelegate {
    
    var delegate: ClientDelegate?
    private(set) var connectedService: NSNetService?
    private(set) var socket: GCDAsyncSocket?
    
    private var serviceBrowser: NSNetServiceBrowser?
    private var foundServices: [NSNetService]?
    private var autoConnect: Bool = true
    
    func connectToHost(host:String, onPort port:UInt16) {
        socket = GCDAsyncSocket(delegate: self, delegateQueue: dispatch_get_main_queue())
        do {
            try socket?.connectToHost(host, onPort: port)
        } catch let error as NSError{
            print("Failed to connect to \(host):\(port). Error \(error)")
        }
    }
    
    func connectToService(service: NSNetService) -> Bool {
        socket = GCDAsyncSocket(delegate: self, delegateQueue: dispatch_get_main_queue())
        for address in service.addresses! {
            do {
                try socket?.connectToAddress(address)
                connectedService = service
                return true
            } catch let error as NSError{
                print("Failed to connect to address \(address). Error \(error)")
            }
        }
        return false
    }
    
    func sendMessage(userInfo: NSDictionary) {
        let dictData:NSData = NSKeyedArchiver.archivedDataWithRootObject(userInfo)
        socket?.writeData(dictData, withTimeout: -1.0, tag: 0)
    }
    
    func findService(name: String, autoConnectFirst autoConnect: Bool = true, inDomain domain: String = "local.") {
        self.autoConnect = autoConnect
        self.foundServices = []
        self.serviceBrowser = NSNetServiceBrowser()
        self.serviceBrowser?.delegate = self
        self.serviceBrowser?.searchForServicesOfType("_\(name)._tcp.", inDomain: domain)
    }
    
    func disconnect() {
        stopFindingService()
        self.socket?.disconnect()
        self.socket = nil
        self.connectedService = nil
    }
    
    func stopFindingService() {
        self.serviceBrowser?.stop()
        self.serviceBrowser = nil
    }
    
    // NSNetServiceBrowser
    func netServiceBrowser(aNetServiceBrowser: NSNetServiceBrowser, didFindService aNetService: NSNetService, moreComing: Bool) {
        self.delegate?.client?(self, didFoundService: aNetService, moreComing: moreComing)
        foundServices?.append(aNetService)
        aNetService.delegate = self
        aNetService.resolveWithTimeout(-1.0)
    }
    
    func netServiceBrowser(aNetServiceBrowser: NSNetServiceBrowser, didRemoveService aNetService: NSNetService, moreComing: Bool) {
        let idx = foundServices?.indexOf(aNetService)
        if idx >= 0 {
            foundServices?.removeAtIndex(idx!)
        }
    }
    
    //NSNetService
    func netServiceDidResolveAddress(sender: NSNetService) {
        self.delegate?.client?(self, didResolveAddress: sender)
        if autoConnect && connectedService == nil {
            self.connectToService(sender)
        }
    }
    
    func netService(sender: NSNetService, didNotResolve errorDict: [String : NSNumber]) {
        print("Net service did not resolve. errorDict: \(errorDict)")
    }
    
    // GCDAsyncSocket
    func socket(sock: GCDAsyncSocket!, didConnectToHost host: String!, port: UInt16) {
        self.delegate?.client?(self, didConnected: sock, host: host, port: port)
        sock.readDataWithTimeout(-1.0, tag: 0)
    }
    
    func socketDidDisconnect(sock: GCDAsyncSocket!, withError err: NSError!) {
        self.delegate?.client?(self, didDisconnected: sock, withError: err)
    }
    
    func socket(sock: GCDAsyncSocket!, didReadData data: NSData!, withTag tag: Int) {
        delegate?.client?(self, didReceiveMessageData: data)
        if let dict = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? [String : AnyObject] {
            delegate?.client?(self, didReceiveMessage: dict)
        }
        if let text: String = String(data: data, encoding: NSUTF8StringEncoding) {
            delegate?.client?(self, didReceiveTextMessage: text)
        }
    }
    
    func socketDidCloseReadStream(sock: GCDAsyncSocket!) {
        print("socket did close read stream")
    }
}