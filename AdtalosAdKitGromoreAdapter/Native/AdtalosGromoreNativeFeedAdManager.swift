//
//  AdtalosGromoreNativeFeedAdManager.swift
//  AdtalosAdKitGromoreAdapter
//
//  Created by 赵言 on 2026/4/23.
//

import AdtalosAdKit
import BUAdSDK
import Foundation
import UIKit

final class AdtalosGromoreNativeFeedAdManager: NSObject {
  weak var bridge: (any BUMCustomNativeAdapterBridge)?
  weak var adapter: AdtalosGromoreNativeAdapter?

  private var slots: [Slot] = []
  private var expectedCount = 0
  private var deliveredToBridge = false
  private var failed = false

  var feedAd: FeedAd? {
    slots.first?.feedAd
  }

  init(
    bridge: (any BUMCustomNativeAdapterBridge)?,
    adapter: AdtalosGromoreNativeAdapter?
  ) {
    self.bridge = bridge
    self.adapter = adapter
    super.init()
  }

  @MainActor
  func load(placementId: String, adSize: CGSize, loadCount: Int) {
    expectedCount = max(1, loadCount)
    deliveredToBridge = false
    failed = false
    disposeSlotsWithoutRemovingManager()
    slots = (0..<expectedCount).map { _ in
      Slot(owner: self, placementId: placementId, adSize: adSize)
    }
    for slot in slots {
      slot.beginLoad()
    }
  }

  @MainActor
  func isExpressViewReady(_ view: UIView) -> Bool {
    slots.contains { slot in
      guard let v = slot.feedAd.view else { return false }
      return v === view && slot.feedAd.isLoaded
    }
  }

  /// 使用 `BUMMediaBidResult.originNativeAdData`：模板侧一般为对应 `UIView`，也可能为 `FeedAd`；为空时对当前批次全部生效。
  func handleBidResult(_ result: BUMMediaBidResult) {
    let winnerPrice = Int64(result.winnerPrice)
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      let origin = result.originNativeAdData
      // `FeedAd` 继承自 `UIView`，必须先按 `FeedAd` 再按裸 `view` 匹配。
      if let feed = origin as? FeedAd {
        if let slot = self.slots.first(where: { $0.feedAd === feed }) {
          AdtalosGromoreAdapterUtils.applyBidResult(
            win: result.win, winnerPrice: winnerPrice, to: slot.feedAd)
        }
        return
      }
      if let view = origin as? UIView {
        if let slot = self.slots.first(where: { $0.feedAd.view === view }) {
          AdtalosGromoreAdapterUtils.applyBidResult(
            win: result.win, winnerPrice: winnerPrice, to: slot.feedAd)
        }
        return
      }
      for slot in self.slots {
        AdtalosGromoreAdapterUtils.applyBidResult(
          win: result.win, winnerPrice: winnerPrice, to: slot.feedAd)
      }
    }
  }

  @MainActor
  func tearDown() {
    disposeSlotsWithoutRemovingManager()
    slots = []
  }

  private func slotReadyMayHaveChanged() {
    DispatchQueue.main.async { [weak self] in
      self?.tryDeliverBatchIfNeeded()
    }
  }

  private func slotFailed(_ error: Error) {
    DispatchQueue.main.async { [weak self] in
      guard let self, !self.failed else { return }
      self.failed = true
      if let adapter = self.adapter, let bridge = self.bridge {
        bridge.nativeAd?(adapter, didLoadFailWithError: error as NSError)
      }
      self.disposeSlotsWithoutRemovingManager()
      self.slots = []
      self.adapter?.clearFeedTemplateManagerIfCurrent(self)
    }
  }

  @MainActor
  private func tryDeliverBatchIfNeeded() {
    guard !failed, !deliveredToBridge else { return }
    guard slots.count == expectedCount, !slots.isEmpty else { return }
    guard slots.allSatisfy({ $0.feedAd.isLoaded && $0.feedAd.view != nil }) else { return }
    guard let bridge = self.bridge, let adapter = self.adapter else { return }

    let views = slots.compactMap(\.feedAd.view)
    let exts = slots.map { AdtalosGromoreAdapterUtils.ecpmExt(fromPrice: $0.feedAd.price) }
    guard views.count == slots.count else { return }

    deliveredToBridge = true
    bridge.nativeAd?(adapter, didLoadWithExpressViews: views, exts: exts)
  }

  @MainActor
  private func disposeSlotsWithoutRemovingManager() {
    for slot in slots {
      slot.dispose()
    }
    slots = []
  }

  private final class Slot: NSObject, @preconcurrency Listener, @preconcurrency VideoListener {
    weak var owner: AdtalosGromoreNativeFeedAdManager?
    let feedAd: FeedAd

    @MainActor
    init(owner: AdtalosGromoreNativeFeedAdManager, placementId: String, adSize: CGSize) {
      self.owner = owner
      let width = adSize.width > 0 ? adSize.width : UIScreen.main.bounds.width
      let height = adSize.height > 0 ? adSize.height : 0.0
      self.feedAd = {
        guard width > 0, height > 0 else {
          return FeedAd(unitID: placementId)
        }
        return FeedAd(
          frame: CGRect(x: 0, y: 0, width: Double(width), height: Double(height)),
          unitID: placementId)
      }()
      super.init()
    }

    func beginLoad() {
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.feedAd.listener = self
        self.feedAd.videoListener = self
        self.feedAd.autoRetry = 0
        AdtalosGromoreAdapterUtils.reportGromoreEvent(.gromoreLoad, ad: self.feedAd)
        self.feedAd.load()
      }
    }

    @MainActor
    func dispose() {
      feedAd.listener = nil
      feedAd.videoListener = nil
      AdtalosGromoreAdapterUtils.reportGromoreEvent(.gromoreDestroy, ad: feedAd)
      feedAd.destroy()
    }

    deinit {
    }

    func onBeforeRequest() {}

    func onLoaded() {
      owner?.slotReadyMayHaveChanged()
    }

    func onFailedToLoad(_ error: Error) {
      owner?.slotFailed(error)
    }

    func onRendered() {
      DispatchQueue.main.async { [weak self] in
        guard
          let self,
          let view = self.feedAd.view,
          let adapter = self.owner?.adapter,
          let bridge = self.owner?.bridge
        else {
          return
        }
        bridge.nativeAd?(adapter, renderSuccessWithExpressView: view)
      }
    }

    @MainActor
    func onShown() {
      AdtalosGromoreAdapterUtils.reportGromoreEvent(.gromoreShow, ad: feedAd)
      guard let owner, let view = feedAd.view, let adapter = owner.adapter,
        let bridge = owner.bridge
      else {
        return
      }
      bridge.nativeAd?(adapter, didVisibleWithMediatedNativeAd: view)
    }

    @MainActor
    func onClicked() {
      guard let owner, let view = feedAd.view, let adapter = owner.adapter,
        let bridge = owner.bridge
      else {
        return
      }
      bridge.nativeAd?(adapter, didClickWithMediatedNativeAd: view)
    }

    @MainActor
    func onLeftApplication() {
      guard let owner, let view = feedAd.view, let adapter = owner.adapter,
        let bridge = owner.bridge
      else {
        return
      }
      bridge.nativeAd?(adapter, willPresentFullScreenModalWithMediatedNativeAd: view)
    }

    @MainActor
    func onClosed() {
      guard let owner, let view = feedAd.view, let adapter = owner.adapter,
        let bridge = owner.bridge
      else {
        return
      }
      bridge.nativeAd?(adapter, didCloseWithExpressView: view, closeReasons: [])
    }

    func onVideoLoad(_ metadata: VideoMetadata) {}

    @MainActor
    func onVideoStart() {
      reportVideoState(.statePlaying)
    }

    @MainActor
    func onVideoPlay() {
      reportVideoState(.statePlaying)
    }

    @MainActor
    func onVideoPause() {
      reportVideoState(.statePause)
    }

    @MainActor
    func onVideoEnd() {
      reportVideoState(.stateStopped)
      reportVideoPlayFinish()
    }

    func onVideoVolumeChange(_ volume: Double, muted: Bool) {}

    func onVideoTimeUpdate(_ currentTime: Double, duration: Double) {}

    @MainActor
    func onVideoError() {
      reportVideoState(.stateFailed)
    }

    @MainActor
    func onVideoBreak() {
      reportVideoState(.stateStopped)
    }

    @MainActor
    private func reportVideoState(_ state: BUPlayerPlayState) {
      guard let owner, let view = feedAd.view, let adapter = owner.adapter,
        let bridge = owner.bridge
      else {
        return
      }
      bridge.nativeAd?(adapter, videoStateDidChangedWith: state, andNativeAd: view)
    }

    @MainActor
    private func reportVideoPlayFinish() {
      guard let owner, let view = feedAd.view, let adapter = owner.adapter,
        let bridge = owner.bridge
      else {
        return
      }
      bridge.nativeAd?(adapter, videoDidPlayFinish: view)
    }
  }
}
