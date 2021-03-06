// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Foundation

/// The singleton instance of Syncbase that represents the local store.
public enum Syncbase {
  /// The dispatch queue to run callbacks on. Defaults to main.
  public static var queue: dispatch_queue_t = dispatch_get_main_queue()
  // Internal variables
  static var didInit = false
  static var isUnitTest = false

  public static func configure(
    // Default to Application Support/Syncbase.
    rootDir rootDir: String = NSFileManager.defaultManager()
      .URLsForDirectory(.ApplicationSupportDirectory, inDomains: .UserDomainMask)[0]
      .URLByAppendingPathComponent("Syncbase")
      .path!,
    queue: dispatch_queue_t = dispatch_get_main_queue()) throws {
      if didInit {
        throw SyncbaseError.AlreadyConfigured
      }
      if rootDir == "" {
        throw SyncbaseError.IllegalArgument(detail: "Missing rootDir")
      }
      if !NSFileManager.defaultManager().fileExistsAtPath(rootDir) {
        try NSFileManager.defaultManager().createDirectoryAtPath(
          rootDir,
          withIntermediateDirectories: true,
          attributes: [NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication])
      }
      let opts = v23_syncbase_InitOpts(
        clientUnderstandsVOM: false,
        rootDir: try rootDir.toCgoString(),
        testLogin: isUnitTest,
        verboseLevel: 0)
      v23_syncbase_Init(opts)
      if isLoggedIn {
        try serve()
      }
      Syncbase.queue = queue
      Syncbase.didInit = true
  }

  /// Starts serving Syncbase post-initialization and login. Internal use only.
  static func serve() throws {
    try VError.maybeThrow { errPtr in
      v23_syncbase_Serve(errPtr)
    }
  }

  /// Shuts down the Syncbase service. You must call configure again before any calls will work.
  public static func shutdown() {
    v23_syncbase_Shutdown()
    Syncbase.didInit = false
  }

  /// Create a database using the relative name and user's blessings.
  public static func database(name: String) throws -> Database {
    if !Syncbase.didInit {
      throw SyncbaseError.NotConfigured
    }
    return try database(Identifier(name: name, blessing: try Principal.appBlessing()))
  }

  /// DatabaseForId returns the Database with the given app blessing and name (from the Id struct).
  public static func database(databaseId: Identifier) throws -> Database {
    if !Syncbase.didInit {
      throw SyncbaseError.NotConfigured
    }
    return try Database(databaseId: databaseId, batchHandle: nil)
  }

  /// ListDatabases returns a list of all Database ids that the caller is allowed to see.
  /// The list is sorted by blessing, then by name.
  public static func listDatabases() throws -> [Identifier] {
    if !Syncbase.didInit {
      throw SyncbaseError.NotConfigured
    }
    var ids = v23_syncbase_Ids()
    return try VError.maybeThrow { err in
      v23_syncbase_ServiceListDatabases(&ids, err)
      return ids.extract()
    }
  }

  /// Must return true before any Syncbase operation can work. Authorize using GoogleCredentials
  /// created from a Google OAuth token (you should use the Google Sign In SDK to get this).
  public static var isLoggedIn: Bool {
    var ret = false
    v23_syncbase_IsLoggedIn(&ret)
    return ret
  }

  /// For debugging the current Syncbase user blessings.
  public static var loggedInBlessingDebugDescription: String {
    return Principal.blessingsDebugDescription
  }

  public typealias LoginCallback = (err: SyncbaseError?) -> Void

  /// Authorize using an oauth token. Right now only Google OAuth token is supported
  /// (you should use the Google Sign In SDK to get this), and you should use the
  /// GoogleOAuthCredentials struct to pass the token.
  ///
  /// You must login and have valid credentials before any Syncbase operation will work.
  ///
  /// Calls `callback` on `Syncbase.queue` with any error that occured, or nil on success.
  ///
  /// TODO(zinman): Make sure the blessings cache works so we don't actually have to login
  /// every single time.
  public static func login(credentials: OAuthCredentials, callback: LoginCallback) {
    if !Syncbase.didInit {
      callback(err: SyncbaseError.NotConfigured)
    }
    // Go's login is blocking, so call on a background concurrent queue.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)) {
      var err: SyncbaseError? = nil
      do {
        try VError.maybeThrow { errPtr in
          v23_syncbase_Login(
            try credentials.provider.rawValue.toCgoString(),
            try credentials.token.toCgoString(),
            errPtr)
        }
      } catch let e as SyncbaseError {
        err = e
      } catch {
        preconditionFailure("Invalid ErrorType: \(error)")
      }
      dispatch_async(Syncbase.queue) {
        callback(err: err)
      }
    }
  }

  public static func getPermissions() throws -> (Permissions, PermissionsVersion) {
    if !Syncbase.didInit {
      throw SyncbaseError.NotConfigured
    }
    var cPermissions = v23_syncbase_Permissions()
    var cVersion = v23_syncbase_String()
    try VError.maybeThrow { errPtr in
      v23_syncbase_ServiceGetPermissions(
        &cPermissions,
        &cVersion,
        errPtr)
    }
    // TODO(zinman): Verify that permissions defaulting to zero-value is correct for Permissions.
    // We force cast of cVersion because we know it can be UTF-8 converted.
    return (try cPermissions.extract() ?? Permissions(), cVersion.extract()!)
  }

  public static func setPermissions(permissions: Permissions, version: PermissionsVersion) throws {
    if !Syncbase.didInit {
      throw SyncbaseError.NotConfigured
    }
    try VError.maybeThrow { errPtr in
      v23_syncbase_ServiceSetPermissions(
        try v23_syncbase_Permissions(permissions),
        try version.toCgoString(),
        errPtr)
    }
  }
}
