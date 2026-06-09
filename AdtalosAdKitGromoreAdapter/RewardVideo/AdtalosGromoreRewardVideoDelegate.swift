//
//  AdtalosGromoreRewardVideoDelegate.swift
//  AdtalosAdKitGromoreAdapter
//
//  Created by 赵言 on 2026/4/10.
//

import AdtalosAdKit
import Foundation

final class AdtalosGromoreRewardVideoDelegate: NSObject, Listener, RewardVideoListener,
  VideoListener
{
  var didLoad: (() -> Void)?
  var didFailToLoad: (() -> Void)?
  var didVisible: (() -> Void)?
  var didClick: (() -> Void)?
  var didClose: (() -> Void)?
  var didRewarded: ((String) -> Void)?
  var didPlayFinish: (() -> Void)?
  var didVideoError: (() -> Void)?

  func onBeforeRequest() {}

  func onLoaded() {
    didLoad?()
  }

  func onFailedToLoad(_ error: any Error) {
    didFailToLoad?()
  }

  func onRendered() {}

  func onShown() {
    didVisible?()
  }

  func onClicked() {
    didClick?()
  }

  func onLeftApplication() {}

  func onClosed() {
    didClose?()
  }

  func onRewarded(_ data: String) {
    didRewarded?(data)
  }

  func onVideoLoad(_ metadata: VideoMetadata) {}
  func onVideoStart() {}
  func onVideoPlay() {}
  func onVideoPause() {}

  func onVideoEnd() {
    didPlayFinish?()
  }

  func onVideoVolumeChange(_ volume: Double, muted: Bool) {}
  func onVideoTimeUpdate(_ currentTime: Double, duration: Double) {}

  func onVideoError() {
    didVideoError?()
  }

  func onVideoBreak() {}
}
