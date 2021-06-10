//
//  WrappedWebSocket.swift
//  openland
//
//  Created by Steve Korshakov on 2/13/20.
//  Copyright © 2020 Openland. All rights reserved.
//

import Foundation
import Starscream

/**
  Wrapper for WebSocket class that provides correct (like JS) callback invoking guaranteees unlike original Starscream one
 */
class WrappedWebSocket: WebSocketDelegate {
    let ws: WebSocket
    let queue: DispatchQueue
  
    var onConnect: (() -> Void)?
    var onDisconnect: ((Error?) -> Void)?
    var onText: ((String) -> Void)?
  
    init(ws: WebSocket, queue: DispatchQueue) {
        self.ws = ws
        self.queue = queue
        ws.delegate = self
//
//    ws.onConnect = {
//      self.queue.async {
//        let t = self.onConnect
//        if t != nil {
//          t!()
//        }
//      }
//    }
//    ws.onDisconnect = { err in
//      self.queue.async {
//        let t = self.onDisconnect
//        if t != nil {
//          t!(err)
//        }
//      }
//    }
//    ws.onText = { str in
//      self.queue.async {
//        let t = self.onText
//        if t != nil {
//          t!(str)
//        }
//      }
//    }
        ws.connect()
    }
    
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
            case .connected(_):
                self.queue.async {
                    let t = self.onConnect
                    if t != nil {
                        t!()
                    }
                }
                break
            case .disconnected(_, _):
                self.queue.async {
                    let t = self.onDisconnect
                    if t != nil {
                        t!(nil)
                    }
                }
                break
            case .text(let string):
                self.queue.async {
                    let t = self.onText
                    if t != nil {
                        t!(string)
                    }
                }
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
    
  
    func write(string: String) {
        self.ws.write(string: string)
    }
  
    func disconnect() {
        self.ws.disconnect()
    }
}
