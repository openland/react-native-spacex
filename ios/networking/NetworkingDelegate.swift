//
//  NetworkingDelegate.swift
//

import Foundation
import SwiftyJSON

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
