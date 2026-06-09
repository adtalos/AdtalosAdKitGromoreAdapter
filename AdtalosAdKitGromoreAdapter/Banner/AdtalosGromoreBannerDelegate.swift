//
//  AdtalosGromoreBannerDelegate.swift
//  AdtalosAdKitGromoreAdapter
//
//  Created by 赵言 on 2026/4/10.
//

import AdtalosAdKit
import Foundation

final class AdtalosGromoreBannerDelegate: NSObject, Listener {
  var didLoad: (() -> Void)?
  var didFailToLoad: (() -> Void)?
  var didShow: (() -> Void)?
  var didClick: (() -> Void)?
  var didLeaveApplication: (() -> Void)?
  var didClose: (() -> Void)?

  func onBeforeRequest() {}

  func onLoaded() {
    didLoad?()
  }

  func onFailedToLoad(_ error: any Error) {
    didFailToLoad?()
  }

  func onRendered() {}

  func onShown() {
    didShow?()
  }

  func onClicked() {
    didClick?()
  }

  func onLeftApplication() {
    didLeaveApplication?()
  }

  func onClosed() {
    didClose?()
  }
}
