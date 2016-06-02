// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Note: Imported C structs have a default initializer in Swift that zero-initializes all fields.
// https://developer.apple.com/library/ios/releasenotes/DeveloperTools/RN-Xcode/Chapters/xc6_release_notes.html

import Foundation

extension v23_syncbase_BatchOptions {
  init (_ opts: BatchOptions?) throws {
    guard let o = opts else {
      self.hint = v23_syncbase_String()
      self.readOnly = false
      return
    }
    self.hint = try o.hint?.toCgoString() ?? v23_syncbase_String()
    self.readOnly = o.readOnly
  }
}

extension v23_syncbase_Bool {
  init(_ bool: Bool) {
    switch bool {
    case true: self = 1
    case false: self = 0
    }
  }

  func toBool() -> Bool {
    switch self {
    case 0: return false
    default: return true
    }
  }
}

extension v23_syncbase_Bytes {
  init(_ data: NSData?) {
    guard let data = data else {
      self.n = 0
      self.p = nil
      return
    }
    let p = malloc(data.length)
    if p == nil {
      fatalError("Couldn't allocate \(data.length) bytes")
    }
    let n = data.length
    data.getBytes(p, length: n)
    self.p = UnsafeMutablePointer<UInt8>(p)
    self.n = Int32(n)
  }

  // Return value takes ownership of the memory associated with this object.
  func toNSData() -> NSData? {
    if p == nil {
      return nil
    }
    return NSData(bytesNoCopy: UnsafeMutablePointer<Void>(p), length: Int(n), freeWhenDone: true)
  }
}

extension v23_syncbase_ChangeType {
  func toChangeType() -> WatchChange.ChangeType? {
    return WatchChange.ChangeType(rawValue: Int(self.rawValue))
  }
}

extension v23_syncbase_CollectionRowPattern {
  init(_ pattern: CollectionRowPattern) throws {
    self.collectionBlessing = try pattern.collectionBlessing.toCgoString()
    self.collectionName = try pattern.collectionName.toCgoString()
    self.rowKey = try (pattern.rowKey ?? "").toCgoString()
  }
}

extension v23_syncbase_CollectionRowPatterns {
  init(_ patterns: [CollectionRowPattern]) throws {
    if (patterns.isEmpty) {
      self.n = 0
      self.p = nil
      return
    }
    let numBytes = patterns.count * sizeof(v23_syncbase_CollectionRowPattern)
    self.p = unsafeBitCast(malloc(numBytes), UnsafeMutablePointer<v23_syncbase_CollectionRowPattern>.self)
    if self.p == nil {
      fatalError("Couldn't allocate \(numBytes) bytes")
    }
    self.n = Int32(patterns.count)
    var i = 0
    do {
      for pattern in patterns {
        self.p.advancedBy(i).memory = try v23_syncbase_CollectionRowPattern(pattern)
        i += 1
      }
    } catch let e {
      free(self.p)
      self.p = nil
      self.n = 0
      throw e
    }
  }
}

extension v23_syncbase_Id {
  init(_ id: Identifier) throws {
    self.name = try id.name.toCgoString()
    self.blessing = try id.blessing.toCgoString()
  }

  func toIdentifier() -> Identifier? {
    guard let name = name.toString(),
      blessing = blessing.toString() else {
        return nil
    }
    return Identifier(name: name, blessing: blessing)
  }
}

extension v23_syncbase_Ids {
  init(_ ids: [Identifier]) throws {
    let arrayBytes = ids.count * sizeof(v23_syncbase_Id)
    let p = unsafeBitCast(malloc(arrayBytes), UnsafeMutablePointer<v23_syncbase_Id>.self)
    if p == nil {
      fatalError("Couldn't allocate \(arrayBytes) bytes")
    }
    for i in 0 ..< ids.count {
      do {
        p.advancedBy(i).memory = try v23_syncbase_Id(ids[i])
      } catch (let e) {
        for j in 0 ..< i {
          free(p.advancedBy(j).memory.blessing.p)
          free(p.advancedBy(j).memory.name.p)
        }
        free(p)
        throw e
      }
    }
    self.p = p
    self.n = Int32(ids.count)
  }

  func toIdentifiers() -> [Identifier] {
    var ids: [Identifier] = []
    for i in 0 ..< n {
      let idStruct = p.advancedBy(Int(i)).memory
      if let id = idStruct.toIdentifier() {
        ids.append(id)
      }
    }
    if p != nil {
      free(p)
    }
    return ids
  }
}

extension v23_syncbase_Permissions {
  init(_ permissions: Permissions?) throws {
    guard let p = permissions where !p.isEmpty else {
      // Zero-value constructor.
      self.json = v23_syncbase_Bytes()
      return
    }
    var m = [String: AnyObject]()
    for (key, value) in p {
      m[key as String] = (value as AccessList).toJsonable()
    }
    let serialized = try NSJSONSerialization.serialize(m)
    let bytes = v23_syncbase_Bytes(serialized)
    self.json = bytes
  }

  func toPermissions() throws -> Permissions? {
    guard let data = self.json.toNSData(),
      map = try NSJSONSerialization.deserialize(data) as? NSDictionary else {
        return nil
    }
    var p = Permissions()
    for (k, v) in map {
      guard let key = k as? String,
        jsonAcessList = v as? [String: AnyObject],
        accessList = AccessList.fromJsonable(jsonAcessList) else {
          throw SyncbaseError.CastError(obj: v)
      }
      p[key] = accessList
    }
    return p
  }
}

extension v23_syncbase_String {
  init(_ string: String) throws {
    // TODO: If possible, make one copy instead of two, e.g. using s.getCString.
    guard let data = string.dataUsingEncoding(NSUTF8StringEncoding) else {
      throw SyncbaseError.InvalidUTF8(invalidUtf8: string)
    }
    let p = malloc(data.length)
    if p == nil {
      fatalError("Unable to allocate \(data.length) bytes")
    }
    let n = data.length
    data.getBytes(p, length: n)
    self.p = UnsafeMutablePointer<Int8>(p)
    self.n = Int32(n)
  }

  // Return value takes ownership of the memory associated with this object.
  func toString() -> String? {
    if p == nil {
      return nil
    }
    return String(bytesNoCopy: UnsafeMutablePointer<Void>(p),
      length: Int(n),
      encoding: NSUTF8StringEncoding,
      freeWhenDone: true)
  }
}

extension v23_syncbase_Strings {
  init(_ strings: [String]) throws {
    let arrayBytes = strings.count * sizeof(v23_syncbase_String)
    let p = unsafeBitCast(malloc(arrayBytes), UnsafeMutablePointer<v23_syncbase_String>.self)
    if p == nil {
      fatalError("Couldn't allocate \(arrayBytes) bytes")
    }
    for i in 0 ..< strings.count {
      do {
        p.advancedBy(i).memory = try v23_syncbase_String(strings[i])
      } catch (let e) {
        for j in 0 ..< i {
          free(p.advancedBy(j).memory.p)
        }
        free(p)
        throw e
      }
    }
    self.p = p
    self.n = Int32(strings.count)
  }

  init(_ strings: [v23_syncbase_String]) {
    let arrayBytes = strings.count * sizeof(v23_syncbase_String)
    let p = unsafeBitCast(malloc(arrayBytes), UnsafeMutablePointer<v23_syncbase_String>.self)
    if p == nil {
      fatalError("Couldn't allocate \(arrayBytes) bytes")
    }
    var i = 0
    for string in strings {
      p.advancedBy(i).memory = string
      i += 1
    }
    self.p = p
    self.n = Int32(strings.count)
  }

  // Return value takes ownership of the memory associated with this object.
  func toStrings() -> [String] {
    if p == nil {
      return []
    }
    var ret = [String]()
    for i in 0 ..< n {
      ret.append(p.advancedBy(Int(i)).memory.toString() ?? "")
    }
    return ret
  }
}

extension String {
  /// Create a Cgo-passable string struct forceably (will crash if the string cannot be created).
  func toCgoString() throws -> v23_syncbase_String {
    return try v23_syncbase_String(self)
  }
}

extension v23_syncbase_WatchChange {
  func toWatchChange() -> WatchChange {
    let resumeMarkerData = v23_syncbase_Bytes(
      p: unsafeBitCast(self.resumeMarker.p, UnsafeMutablePointer<UInt8>.self),
      n: self.resumeMarker.n).toNSData()!
    return WatchChange(
      collectionId: self.collection.toIdentifier()!,
      row: self.row.toString()!,
      changeType: self.changeType.toChangeType()!,
      value: self.value.toNSData(),
      resumeMarker: ResumeMarker(data: resumeMarkerData),
      isFromSync: self.fromSync,
      isContinued: self.continued)
  }
}

// Note, we don't define init(VError) since we never pass Swift VError objects to Go.
extension v23_syncbase_VError {
  // Return value takes ownership of the memory associated with this object.
  func toVError() -> VError? {
    if id.p == nil {
      return nil
    }
    // Take ownership of all memory before checking optionals.
    let vId = id.toString(), vMsg = msg.toString(), vStack = stack.toString()
    // TODO: Stop requiring id, msg, and stack to be valid UTF8?
    return VError(id: vId!, actionCode: actionCode, msg: vMsg ?? "", stack: vStack!)
  }
}

public struct VError: ErrorType {
  public let id: String
  public let actionCode: UInt32
  public let msg: String
  public let stack: String

  static func maybeThrow<T>(@noescape f: UnsafeMutablePointer<v23_syncbase_VError> throws -> T) throws -> T {
    var e = v23_syncbase_VError()
    let res = try f(&e)
    if let err = e.toVError() {
      // We might be able to convert this VError into a SyncbaseError depending on the ID.
      if let syncbaseError = SyncbaseError(err) {
        throw syncbaseError
      }
      throw err
    }
    return res
  }
}

