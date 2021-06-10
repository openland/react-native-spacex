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

//class MMKVPersistenceProvider: PersistenceProvier {
//  private let db: MMKV
//  init(name: String) {
//    self.db = MMKV(mmapID: name, mode: MMKVMode.singleProcess)!
//  }
//
//  func close() {
//    self.db.close()
//  }
//
//  func saveRecords(records: [String: String]) {
//    for k in records {
//      self.db.setValue(k.value, forKey: k.key)
//    }
//  }
//
//  func loadRecords(keys: Set<String>) -> [String: String] {
//    var res: [String: String] = [:]
//    for k in keys {
//      let ex = self.db.string(forKey: k)
//      if ex != nil {
//        res[k] = ex
//      }
//    }
//    return res
//  }
//}

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
//    if name != nil {
//      self.provider = MMKVPersistenceProvider(name: name!)
//    } else {
//      self.provider = EmptyPersistenceProvier()
//    }
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
