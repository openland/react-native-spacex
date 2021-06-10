//
//  SpaceX.swift
//  openland
//
//  Created by Steve Kite on 5/9/19.
//  Copyright © 2019 Openland. All rights reserved.
//

import Foundation

public enum OperationKind {
  case subscription
  case query
  case mutation
}

public class FragmentDefinition {
  let name: String
  let selector: OutputType.Object
  
  init(_ name: String, _ selector: OutputType.Object) {
    self.name = name
    self.selector = selector
  }
}

public class OperationDefinition {
  let name: String
  let kind: OperationKind
  let body: String
  let selector: OutputType.Object
  init(_ name: String, _ kind: OperationKind, _ body: String, _ selector: OutputType.Object) {
    self.name = name
    self.kind = kind
    self.body = body
    self.selector = selector
  }
}

public struct InvalidDataError: Error {
  let message: String
  
  init(_ message: String) {
    self.message = message
  }
  
  public var localizedDescription: String {
    return message
  }
}

open class InputValue {
  public class StringValue: InputValue {
    let value: String
    init(value: String) {
      self.value = value
      super.init()
    }
  }
  
  public class IntValue: InputValue {
    let value: Int
    init(value: Int) {
      self.value = value
      super.init()
    }
  }
  
  public class FloatValue: InputValue {
    let value: Double
    init(value: Double) {
      self.value = value
      super.init()
    }
  }
  
  public class BooleanValue: InputValue {
    let value: Bool
    init(value: Bool) {
      self.value = value
      super.init()
    }
  }
  
  public class NullValue: InputValue {
    override init() {
      super.init()
    }
  }
  
  public class ListValue: InputValue {
    let items: [InputValue]
    init(items: [InputValue]) {
      self.items = items
      super.init()
    }
  }
  
  public class ObjectValue: InputValue {
    let fields: [String: InputValue]
    init(fields: [String: InputValue]) {
      self.fields = fields
      super.init()
    }
  }
  
  public class ReferenceValue: InputValue {
    let value: String
    init(value: String) {
      self.value = value
      super.init()
    }
  }
  
  private init() {
    
  }
}

open class OutputType {

  public class NotNull: OutputType {
    let inner: OutputType
    init(inner: OutputType) {
      self.inner = inner
      super.init()
    }
  }
  
  public class List: OutputType {
    let inner: OutputType
    init(inner: OutputType) {
      self.inner = inner
      super.init()
    }
  }
  
  public class Scalar: OutputType {
    let name: String
    init(name: String) {
      self.name = name
      super.init()
    }
  }
  
  public class Object: OutputType {
    let selectors: [Selector]
    init(selectors: [Selector]) {
      self.selectors = selectors
      super.init()
    }
  }
  
  private init() {
    
  }
}

open class Selector {
  
  public class Field: Selector {
    let name: String
    let alias: String
    let type: OutputType
    let arguments: [String: InputValue]
    init(name: String, alias: String, arguments: [String: InputValue], type: OutputType) {
      self.name = name
      self.alias = alias
      self.type = type
      self.arguments = arguments
      super.init()
    }
  }
  
  public class TypeCondition: Selector {
    let name: String
    let type: OutputType.Object
    init(name: String, type: OutputType.Object) {
      self.name = name
      self.type = type
      super.init()
    }
  }
  
  public class Fragment: Selector {
    let name: String
    let type: OutputType.Object
    init(name: String, type: OutputType.Object) {
      self.name = name
      self.type = type
      super.init()
    }
  }
  
  private init() {
    
  }
}

open class RecordValue: Equatable {
  
  public static func == (lhs: RecordValue, rhs: RecordValue) -> Bool {
    if lhs is RecordValue.NullValue && rhs is RecordValue.NullValue {
      return true
    } else if lhs is RecordValue.StringValue && rhs is RecordValue.StringValue {
      let lhs2 = lhs as! RecordValue.StringValue
      let rhs2 = rhs as! RecordValue.StringValue
      return lhs2.value == rhs2.value
    } else if lhs is RecordValue.NumberValue && rhs is RecordValue.NumberValue {
      let lhs2 = lhs as! RecordValue.NumberValue
      let rhs2 = rhs as! RecordValue.NumberValue
      return lhs2.value == rhs2.value
    } else if lhs is RecordValue.BooleanValue && rhs is RecordValue.BooleanValue {
      let lhs2 = lhs as! RecordValue.BooleanValue
      let rhs2 = rhs as! RecordValue.BooleanValue
      return lhs2.value == rhs2.value
    } else if lhs is RecordValue.ListValue && rhs is RecordValue.ListValue {
      let a = lhs as! RecordValue.ListValue
      let b = rhs as! RecordValue.ListValue
      if a.items.count != b.items.count {
        return false
      }
      for i in 0..<a.items.count {
        if a.items[i] != b.items[i] {
          return false
        }
      }
      return true
    } else if lhs is RecordValue.ReferenceValue && rhs is RecordValue.ReferenceValue {
      let lhs2 = lhs as! RecordValue.ReferenceValue
      let rhs2 = rhs as! RecordValue.ReferenceValue
      return lhs2.key == rhs2.key
    }
    
    return false
  }
  
  public class StringValue: RecordValue {
    let value: String
    init(value: String) {
      self.value = value
      super.init()
    }
  }
  public class NumberValue: RecordValue {
    let value: Double
    init(value: Double) {
      self.value = value
      super.init()
    }
  }
  public class BooleanValue: RecordValue {
    let value: Bool
    init(value: Bool) {
      self.value = value
      super.init()
    }
  }
  
  public class NullValue: RecordValue {
    override init() {
      super.init()
    }
  }
  
  public class ReferenceValue: RecordValue {
    let key: String
    init(key: String) {
      self.key = key
      super.init()
    }
  }
  
  public class ListValue: RecordValue {
    let items: [RecordValue]
    init(items: [RecordValue]) {
      self.items = items
      super.init()
    }
  }
  
  private init() {
    
  }
}

public class Record {
  let key: String
  let fields: [String:RecordValue]
  init(key: String, fields: [String:RecordValue]) {
    self.key = key
    self.fields = fields
  }
}

public typealias RecordSet = [String:Record]

class SharedDictionary<K : Hashable, V> {
  var dict : Dictionary<K, V> = Dictionary()
  subscript(key : K) -> V? {
    get {
      return dict[key]
    }
    set(newValue) {
      dict[key] = newValue
    }
  }
}


//
// Basics
//

public func list(_ inner: OutputType) -> OutputType.List {
  return OutputType.List(inner: inner)
}

public func notNull(_ inner: OutputType) -> OutputType.NotNull {
  return OutputType.NotNull(inner: inner)
}

public func scalar(_ name: String) -> OutputType.Scalar {
  return OutputType.Scalar(name: name)
}

//
// Objects
//

public func obj(_ selectors: Selector...) -> OutputType.Object {
  return OutputType.Object(selectors: selectors)
}

public func obj(_ selectors: [Selector]) -> OutputType.Object {
  return OutputType.Object(selectors: selectors)
}

public func arguments(_ src: (String, InputValue)...) -> [String: InputValue] {
  var res: [String: InputValue] = [:]
  for s in src {
    res[s.0] = s.1
  }
  return res
}

public func fieldValue(_ name: String, _ value: InputValue) -> (String, InputValue) {
  return (name, value)
}

public func refValue(_ key: String) -> InputValue.ReferenceValue {
  return InputValue.ReferenceValue(value: key)
}

public func intValue(_ v: Int) -> InputValue.IntValue {
  return InputValue.IntValue(value: v)
}

public func boolValue(_ v: Bool) -> InputValue.BooleanValue {
  return InputValue.BooleanValue(value: v)
}

public func floatValue(_ v: Double) -> InputValue.FloatValue {
  return InputValue.FloatValue(value: v)
}

public func nullValue() -> InputValue.NullValue {
  return InputValue.NullValue()
}

public func stringValue(_ v: String) -> InputValue.StringValue {
  return InputValue.StringValue(value: v)
}

public func listValue(_ values: InputValue...) -> InputValue.ListValue {
  return InputValue.ListValue(items: values)
}

public func listValue(_ values: [InputValue]) -> InputValue.ListValue {
  return InputValue.ListValue(items: values)
}

public func objectValue(_ src: (String, InputValue)...) -> InputValue.ObjectValue {
  var res: [String: InputValue] = [:]
  for s in src {
    res[s.0] = s.1
  }
  return InputValue.ObjectValue(fields: res)
}

public func objectValue(_ src: [String: InputValue]) -> InputValue.ObjectValue {
  return InputValue.ObjectValue(fields: src)
}


public func field(_ name: String, _ alias: String, _ type: OutputType) -> Selector.Field {
  return Selector.Field(name: name, alias: alias, arguments:[:], type: type)
}

public func field(_ name: String, _ alias: String, _ arguments: [String:InputValue], _ type: OutputType) -> Selector.Field {
  return Selector.Field(name: name, alias: alias, arguments:arguments, type: type)
}

public func inline(_ name:String, _ obj: OutputType.Object) -> Selector.TypeCondition {
  return Selector.TypeCondition(name: name, type: obj)
}

public func fragment(_ name:String, _ src: OutputType.Object) -> Selector.Fragment {
  return Selector.Fragment(name: name, type: src)
}
