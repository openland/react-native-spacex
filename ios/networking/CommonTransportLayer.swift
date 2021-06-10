//
//  ApolloTransport.swift
//  openland
//
//  Created by Steve Kite on 5/13/19.
//  Copyright © 2019 Openland. All rights reserved.
//

import Foundation
import SwiftyJSON
import Starscream

enum TransportSocketState {
  case waiting
  case connecting
  case starting
  case started
  case completed
}

protocol NetworkingDelegate: AnyObject {
  
  // Callbacks
  func onResponse(id: String, data: JSON)
  func onError(id: String, error: JSON)
  func onCompleted(id: String)
  
  // Session state
  func onSessiontRestart()
  func onConnected()
  func onDisconnected()
}

class CommonTransportLayer: WebSocketConnectionDelegate {
  
  private static var nextId: AtomicInteger = AtomicInteger(value: 1)
  private static let PING_INTERVAL = 30
  private static let PING_TIMEOUT = 10
  
  private let queue = DispatchQueue(label: "spacex-networking-transport")
    
  let id: Int
  let url: String
  let params: [String: String?]
  weak var delegate: NetworkingDelegate? = nil
  var callbackQueue: DispatchQueue
  let provider: WebSocketProvider
  private var connection: WebSocketConnection? = nil
  private var pending: [String: JSON] = [:]
  private var state: TransportSocketState = .waiting
  private var failuresCount = 0
  private var started = false
  private var mode: String
  
  private var lastPingId = 0
  
  init(provider: WebSocketProvider, url: String, mode: String, params: [String: String?]) {
    self.callbackQueue = self.queue
    self.provider = provider
    self.id = CommonTransportLayer.nextId.getAndIncrement()
    self.url = url
    self.params = params
    self.mode = mode
  }
  
  func connect() {
    NSLog("[SpaceX-WS]: Starting")
    queue.async {
      self.started = true
      self.doConnect()
    }
  }
  
  func startRequest(id: String, body: JSON) {
    NSLog("[SpaceX-WS]: Start Request " + id + " [" + body["name"].stringValue + "]")
    queue.async {
      if self.state == .waiting || self.state == .connecting {
        // Add to pending buffer if we are not connected already
        self.pending[id] = body
        NSLog("[SpaceX-WS]: Pending " + id)
      } else if self.state == .starting {
        NSLog("[SpaceX-WS]: Starting " + id)
        // If we connected, but not started add to pending buffer (in case of failed start)
        // and send message to socket
        
        self.pending[id] = body
        self.writeToSocket(msg: JSON(["type": "start", "id": id, "payload": body]))
      } else if self.state == .started {
        NSLog("[SpaceX-WS]: Started " + id)
        self.writeToSocket(msg: JSON(["type": "start", "id": id, "payload": body]))
      } else if self.state == .completed {
        NSLog("[SpaceX-WS]: Completed " + id)
        // Silently ignore if connection is completed
      } else {
        fatalError()
      }
    }
  }
  
  func stopRequest(id: String) {
    NSLog("[SpaceX-WS]: Stop Request " + id)
    queue.async {
      if self.state == .waiting || self.state == .connecting {
        // Remove from pending buffer if we are not connected already
        self.pending.removeValue(forKey: id)
      } else if self.state == .starting {
        // If we connected, but not started remove from pending buffer (in case of failed start)
        // and send cancelation message to socket
        self.pending.removeValue(forKey: id)
        self.writeToSocket(msg: JSON(["type": "stop", "id": id]))
      } else if self.state == .started {
        self.writeToSocket(msg: JSON(["type": "stop", "id": id]))
      } else if self.state == .completed {
        // Silently ignore if connection is completed
      } else {
        fatalError()
      }
    }
  }
  
  private func doConnect() {
    NSLog("[SpaceX-WS]: Connecting")
    if self.state != .waiting {
      fatalError("Unexpected state")
    }
    self.state = .connecting
    
    // Create new connection
    var proto: String? = nil
    if (self.mode != "openland") {
        proto = "graphql-ws"
    }
    let ws = self.provider.create(endpoint: WebSocketEndpoint(url: self.url, proto: proto), queue: self.queue)
    ws.delegate = self
    self.connection = ws
  }
    
  func onOpen() {
    NSLog("[SpaceX-WS]: onConnected")
    if self.state != .connecting {
      fatalError("Unexpected state")
    }
    self.state = .starting
    if self.mode == "openland" {
      self.writeToSocket(msg: JSON([
        "protocol_v": 2,"type": "connection_init", "payload": self.params
      ]))
    } else {
      self.writeToSocket(msg: JSON([
        "type": "connection_init", "payload": self.params
      ]))
    }
    for p in self.pending {
      self.writeToSocket(msg: JSON(["type": "start", "id": p.key, "payload": p.value]))
    }
    schedulePing()
  }
    
  func onMessage(message: String) {
    let parsed = JSON(parseJSON: message)
    let type = parsed["type"].stringValue
    NSLog("[SpaceX-WS]: <<" + type)
    if type == "ka" {
      // TODO: Handle
    } else if type == "connection_ack" {
      if self.state == .starting {
        NSLog("[SpaceX-WS]: Started")
        
        // Change state
        self.state = .started
        
        // Remove all pending messages
        self.pending.removeAll()
        
        // Reset failure count
        self.failuresCount = 0
        
        // Notify about state
        self.callbackQueue.async {
          self.delegate?.onConnected()
        }
      }
    } else if type == "data" {
      let id = parsed["id"].stringValue
      let payload = parsed["payload"]
      let errors = payload["errors"]
      let data = payload["data"]
      if errors.exists() {
        self.callbackQueue.async {
            NSLog("[SpaceX-WS]: Error (" + id + ")")
            self.delegate?.onError(id: id, error: errors)
        }
      } else {
        NSLog("[SpaceX-WS]: Data (" + id + ")")
        self.callbackQueue.async {
          self.delegate?.onResponse(id: id, data: data)
        }
      }
    } else if type == "error" {
      let id = parsed["id"].stringValue
      NSLog("[SpaceX-WS]: Critical Error (" + id + "): Retrying")
    } else if type == "ping" {
      self.queue.async {
        if (self.state == .started) {
          if (self.mode == "openland") {
            self.writeToSocket(msg: JSON(["type": "pong"]))
          }
        }
      }
    }else if type == "pong" {
      self.schedulePing()
    } else if type == "complete" {
      let id = parsed["id"].stringValue
      NSLog("[SpaceX-WS]: Complete (" + id + ")")
      self.callbackQueue.async {
        self.delegate?.onCompleted(id: id)
      }
    }
  }
    
  func onClose() {
    NSLog("[SpaceX-WS]: onDisconnected")
    if self.state == .started {
      self.callbackQueue.async {
        self.delegate?.onDisconnected()
        self.delegate?.onSessiontRestart()
      }
    }
    self.stopClient()
    self.state = .waiting
    self.failuresCount += 1
    
    
    self.doConnect()
  }
  
  
  private func schedulePing() {
    if self.mode != "openland" {
      return
    }
    NSLog("[SpaceX-WS]: schedule ping")
    self.lastPingId += 1
    let pingId = self.lastPingId
    self.queue.asyncAfter(deadline: .now() + .seconds(CommonTransportLayer.PING_INTERVAL)) {
      if (self.state == .started) {
        NSLog("[SpaceX-WS]: sending ping")
        self.writeToSocket(msg: JSON(["type": "ping"]))
        self.queue.asyncAfter(deadline: .now() + .seconds(CommonTransportLayer.PING_TIMEOUT)) {
          if(self.state == .started && self.lastPingId == pingId) {
            NSLog("[SpaceX-WS]: ping timeout")
            self.onClose()
          }
        }
      }
    }
  }
  
  func close() {
    queue.async {
      NSLog("[SpaceX-WS]: Stopping")
      if self.state != .completed {
        self.state = .completed
        
        // Remove all pending requests
        self.pending.removeAll()
        
        // Stopping ws connection
        self.stopClient()
        
        // Stopping reachability
        // self.reachability.stopNotifier()
      }
    }
  }
  
  private func stopClient() {
    // Removing client if present
    let ws = self.connection
    self.connection = nil
    
    // Stopping client
    ws?.delegate = nil
    ws?.close()
  }
  
  private func writeToSocket(msg: JSON) {
    let txt = serializeJson(json: msg)
    NSLog("[SpaceX-WS]: >>" + msg["type"].stringValue)
    self.connection!.send(message: txt)
  }
}
