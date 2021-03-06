// Copyright 2016 The Vanadium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

import Syncbase
import UIKit

let rowKey = "result"

class DiceViewController: UIViewController {
  @IBOutlet weak var numberLabel: UILabel!
  var collection: Collection?
  var currentDieRoll = UInt8(2) // The starting number from the XIB

  override func viewDidLoad() {
    super.viewDidLoad()

    do {
      collection = try Syncbase.database().userdataCollection
    } catch {
      print("Unexpected error: \(error)")
    }
  }

  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)
    do {
      try Syncbase.database().addWatchChangeHandler(
        pattern: CollectionRowPattern(
          collectionName: Syncbase.UserdataSyncgroupName,
          rowKey: rowKey),
        handler: WatchChangeHandler(
          onInitialState: onWatchChanges,
          onChangeBatch: onWatchChanges,
          onError: onWatchError))
    } catch let e {
      print("Unexpected error: \(e)")
    }
  }

  override func viewWillDisappear(animated: Bool) {
    super.viewWillDisappear(animated)
    do {
      try Syncbase.database().removeAllWatchChangeHandlers()
    } catch let e {
      print("Unexpected error: \(e)")
    }
  }

  func onWatchChanges(changes: [WatchChange]) {
    let lastValue = changes
      .filter { $0.entityType == .Row && $0.changeType == .Put }
      .last?
      .value
    if let value = lastValue {
      do {
        currentDieRoll = try UInt8.deserializeFromSyncbase(value)
      } catch {
        print("Unexpected error: \(error)")
      }
      numberLabel.text = currentDieRoll.description
      UIApplication.sharedApplication().networkActivityIndicatorVisible = false
    }
  }

  func onWatchError(err: ErrorType) {
    // Something went wrong. Watch is no longer active.
    print("Unexpected watch error: \(err)")
  }

  @IBAction func didPressRollDie(sender: UIButton) {
    var nextNum: UInt8
    repeat {
      nextNum = UInt8(arc4random_uniform(6) + 1)
    } while (nextNum == currentDieRoll)

    do {
      UIApplication.sharedApplication().networkActivityIndicatorVisible = true
      try collection?.put(rowKey, value: nextNum)
    } catch {
      print("Unexpected error: \(error)")
    }
  }

  @IBAction func didPressLogout(sender: UIBarButtonItem) {
    performSegueWithIdentifier("LogoutSegue", sender: self)
  }

  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if let loginVC = segue.destinationViewController as? LoginViewController {
      loginVC.doLogout = true
    }
  }
}

