//
//  SpaceXPersistence.swift
//  openland
//
//  Created by Steve Kite on 5/13/19.
//  Copyright © 2019 Openland. All rights reserved.
//

import Foundation

protocol PersistenceProvier: class {
  func saveRecords(records: [String: String])
  func loadRecords(keys: Set<String>) -> [String: String]
  func close()
}

class EmptyPersistenceProvier: PersistenceProvier {
  func close() {
    
  }
  
  func saveRecords(records: [String: String]) {
    //
  }
  func loadRecords(keys: Set<String>) -> [String: String] {
    return [:]
  }
}

class SpaceXPersistence {
  private let provider: PersistenceProvier
  private let writerQueue = ManagedDispatchQueue(label: "spacex-persistence-write")
  private let readerQueue = ManagedDispatchQueue(label: "spacex-persistence-read", concurrent: true)
  
  init(name: String?) {
    self.provider = EmptyPersistenceProvier()
  }
  
  func close() {
    self.writerQueue.stop()
    self.readerQueue.stop()
    self.provider.close()
  }
  
  func saveRecords(records: RecordSet, queue: ManagedDispatchQueue, callback: @escaping () -> Void) {
    writerQueue.async {
      var serialized: [String: String] = [:]
      for k in records {
        serialized[k.key] = serializeRecord(record: k.value)
      }
      self.provider.saveRecords(records: serialized)
      queue.async {
        callback()
      }
    }
  }
  
  func loadRecors(keys: Set<String>, queue: ManagedDispatchQueue, callback: @escaping (RecordSet) -> Void) {
    readerQueue.async {
      
      let loaded = self.provider.loadRecords(keys: keys)
      var res: RecordSet = [:]
      for l in loaded {
        res[l.key] = parseRecord(key: l.key, src: l.value)
      }
      
      // Fill empty for missing records
      for k in keys {
        if res[k] == nil {
          res[k] = Record(key: k, fields: [:])
        }
      }
      
      queue.async {
        callback(res)
      }
    }
  }
}