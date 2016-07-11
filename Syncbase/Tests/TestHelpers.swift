// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import XCTest
@testable import Syncbase
import enum Syncbase.Syncbase
import enum Syncbase.SyncbaseError
import class Syncbase.Database
@testable import SyncbaseCore

let unitTestRootDir = NSFileManager.defaultManager()
  .URLsForDirectory(.ApplicationSupportDirectory, inDomains: .UserDomainMask)[0]
  .URLByAppendingPathComponent("SyncbaseUnitTest")
  .path!

/// Convert integer seconds into Grand Central Dispatch (GCD)'s dispatch_time_t format.
func secondsGCD(seconds: Int64) -> dispatch_time_t {
  return dispatch_time(DISPATCH_TIME_NOW, seconds * Int64(NSEC_PER_SEC))
}

func failOnNonContextError(err: ErrorType) {
  if err is SyncbaseCore.SyncbaseError {
    XCTFail("No core error should make it to the high-level API")
    return
  }
  switch err {
  case SyncbaseError.UnknownVError(let verr):
    if verr.id == "v.io/v23/verror.Unknown" && verr.msg == "context canceled" {
      return
    }
  default: break
  }
  XCTFail("Unexpected error: \(err)")
}

extension XCTestCase {
  class func configureDb(disableUserdataSyncgroup disableUserdataSyncgroup: Bool, disableSyncgroupPublishing: Bool) {
    SyncbaseCore.Syncbase.isUnitTest = true

    try! NSFileManager.defaultManager().removeItemAtPath(unitTestRootDir)

    // TODO(zinman): Once we have create-and-join implemented don't always set
    // disableUserdataSyncgroup to true.
    try! Syncbase.configure(
      adminUserId: "unittest@google.com",
      rootDir: unitTestRootDir,
      disableUserdataSyncgroup: disableUserdataSyncgroup,
      disableSyncgroupPublishing: disableSyncgroupPublishing,
      queue: testQueue)
    let semaphore = dispatch_semaphore_create(0)
    Syncbase.login(GoogleOAuthCredentials(token: ""), callback: { err in
      XCTAssertNil(err)
      dispatch_semaphore_signal(semaphore)
    })
    let val = dispatch_semaphore_wait(semaphore, secondsGCD(5))
    if val != 0 {
      XCTFail("Timed out performing login")
    }
  }

  func withDb(runBlock: Database throws -> Void) {
    do {
      let db = try Syncbase.database()
      try runBlock(db)
      try db.collections().forEach { try $0.destroy() }
      // TODO(zinman): Re-enable when supported in Syncbase
//      try db.syncgroups().forEach { try $0.coreSyncgroup.destroy() }
    } catch let e {
      XCTFail("Unexpected error: \(e)")
    }
  }
}
