//
//  WebSocketProvider.swift
//  react-native-spacex
//
//  Created by Steve Korshakov on 6/10/21.
//

import Foundation
import Starscream

struct WebSocketEndpoint {
    let url: String
    let proto: String?
}

protocol WebSocketConnectionDelegate: AnyObject {
    func onOpen()
    func onMessage(message: String)
    func onClose()
}

protocol WebSocketConnection: AnyObject {
    var delegate: WebSocketConnectionDelegate? { get set }
    func send(message: String)
    func close()
}

protocol WebSocketProvider: AnyObject {
    func create(endpoint: WebSocketEndpoint, queue: DispatchQueue) -> WebSocketConnection
}

//
// Raw Provider
//

class WebSocketConnectionRaw: WebSocketConnection, WebSocketDelegate {
    weak var delegate: WebSocketConnectionDelegate?
    
    private var ws: WebSocket?
    private let queue: DispatchQueue
    
    init(endpoint: WebSocketEndpoint, queue: DispatchQueue) {
        self.queue = queue
        
        // Create Connection
        var request = URLRequest(url: URL(string: endpoint.url)!)
        if (endpoint.proto != nil) {
          request.setValue(endpoint.proto, forHTTPHeaderField: "Sec-WebSocket-Protocol")
        }
        self.ws = WebSocket(request: request)
        self.ws!.callbackQueue = queue
        self.ws!.delegate = self
        self.ws!.connect()
    }
    
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
            case .connected(_):
                self.delegate?.onOpen()
                break
            case .disconnected(_, _):
                if (self.ws == nil) {
                    return
                }
                self.ws = nil
                self.delegate?.onClose()
                break
            case .text(let string):
                self.delegate?.onMessage(message: string)
                break
            case .binary(_):
                break
            case .pong(_):
                break
            case .ping(_):
                break
            case .error(_):
                break
            case .viabilityChanged(_):
                break
            case .reconnectSuggested(_):
                break
            case .cancelled:
                break
        }
    }
    
    func send(message: String) {
        if self.ws == nil {
            return
        }
        self.ws!.write(string: message)
    }
    
    func close() {
        if self.ws == nil {
            return
        }
        self.ws!.disconnect()
        self.ws = nil
    }    
}

class WebSocketProviderRaw: WebSocketProvider {
    func create(endpoint: WebSocketEndpoint, queue: DispatchQueue) -> WebSocketConnection {
        return WebSocketConnectionRaw(endpoint: endpoint, queue: queue)
    }
}

//
// WatchDog provider
//

class WebSocketConnectionWatchDog: WebSocketConnection, WebSocketConnectionDelegate {
    weak var delegate: WebSocketConnectionDelegate?
    private var inner: WebSocketConnection?
    private var watchDog: WatchDogTimer?
    private var timeout: Int
    private var queue: DispatchQueue
    
    init(inner: WebSocketConnection, timeout: Int, queue: DispatchQueue) {
        self.inner = inner
        self.timeout = timeout
        self.queue = queue
        inner.delegate = self
    }
    
    func send(message: String) {
        self.inner?.send(message: message)
    }
    
    func close() {
        self.doClose()
    }
    
    //
    // Events
    //
    
    func onOpen() {
        if (self.inner == nil) {
            return
        }
        self.watchDog = WatchDogTimer(timeout: self.timeout, queue: self.queue, onRestart: {
            self.delegate?.onClose()
            self.delegate = nil
            self.doClose()
        });
        self.delegate?.onOpen()
    }
    
    func onMessage(message: String) {
        if (self.inner == nil) {
            return
        }
        self.watchDog?.kick()
        self.delegate?.onMessage(message: message)
    }
    
    func onClose() {
        self.delegate?.onClose()
        self.delegate = nil
        self.doClose()
    }
    
    private func doClose() {
        self.inner?.delegate = nil
        self.inner = nil
        self.watchDog?.kill()
        self.watchDog = nil
    }
}

class WebSocketProviderWatchDog: WebSocketProvider {
    private let inner: WebSocketProvider
    private let timeout: Int
    
    init(inner: WebSocketProvider, timeout: Int) {
        self.inner = inner
        self.timeout = timeout
    }
    
    func create(endpoint: WebSocketEndpoint, queue: DispatchQueue) -> WebSocketConnection {
        return WebSocketConnectionWatchDog(
            inner: self.inner.create(endpoint: endpoint, queue: queue),
            timeout: self.timeout,
            queue: queue
        )
    }
}
