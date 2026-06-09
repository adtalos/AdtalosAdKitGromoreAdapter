//
//  AdtalosGromoreNativeAdManager.swift
//  AdtalosAdKitGromoreAdapter
//
//  Created by 赵言 on 2026/4/23.
//

import AdtalosAdKit
import BUAdSDK
import Foundation

final class AdtalosGromoreNativeAdManager: NSObject {
  weak var bridge: (any BUMCustomNativeAdapterBridge)?
  weak var adapter: AdtalosGromoreNativeAdapter?

  private var slots: [Slot] = []
  private var expectedCount = 0
  private var deliveredToBridge = false
  private var failed = false

  init(
    bridge: (any BUMCustomNativeAdapterBridge)?,
    adapter: AdtalosGromoreNativeAdapter?
  ) {
    self.bridge = bridge
    self.adapter = adapter
    super.init()
  }

  @MainActor
  func load(placementId: String, loadCount: Int) {
    expectedCount = max(1, loadCount)
    deliveredToBridge = false
    failed = false
    disposeSlotsWithoutRemovingManager()
    slots = (0..<expectedCount).map { _ in Slot(owner: self, placementId: placementId) }
    for slot in slots {
      slot.beginLoad()
    }
  }

  /// 使用 `BUMMediaBidResult.originNativeAdData` 与下发的 `originMediatedNativeAd`（`NativeAd`）对齐；为空时退化为对当前批次全部生效。
  func handleBidResult(_ result: BUMMediaBidResult) {
    let winnerPrice = Int64(result.winnerPrice)
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      let origin = result.originNativeAdData
      if let mediatedNativeAd = origin as? BUMMediatedNativeAd {
        let originMediatedNativeAd = mediatedNativeAd.originMediatedNativeAd
        if let nativeAd = originMediatedNativeAd as? NativeAd {
          if let slot = self.slots.first(where: { $0.nativeAd === nativeAd }) {
            AdtalosGromoreAdapterUtils.applyBidResult(
              win: result.win, winnerPrice: winnerPrice, to: slot.nativeAd)
          }
          return
        }
      }
      if let nativeAd = origin as? NativeAd {
        if let slot = self.slots.first(where: { $0.nativeAd === nativeAd }) {
          AdtalosGromoreAdapterUtils.applyBidResult(
            win: result.win, winnerPrice: winnerPrice, to: slot.nativeAd)
        }
        return
      }
      for slot in self.slots {
        AdtalosGromoreAdapterUtils.applyBidResult(
          win: result.win, winnerPrice: winnerPrice, to: slot.nativeAd)
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
      self.adapter?.clearSelfRenderManagerIfCurrent(self)
    }
  }

  @MainActor
  private func tryDeliverBatchIfNeeded() {
    guard !failed, !deliveredToBridge else { return }
    guard slots.count == expectedCount, !slots.isEmpty else { return }
    guard slots.allSatisfy({ $0.mediationReady }) else { return }
    guard
      let bridge = self.bridge,
      let adapter = self.adapter
    else {
      return
    }

    var mediatedList: [BUMMediatedNativeAd] = []
    var extList: [[String: Any]] = []

    for slot in slots {
      let ad = slot.nativeAd
      guard ad.isLoaded, let response = ad.nativeResponse else { return }

      let mediated = BUMMediatedNativeAd()
      mediated.originMediatedNativeAd = ad
      mediated.data = AdtalosGromoreNativeMaterialData(response: response)
      mediated.viewCreator = AdtalosGromoreNativeSelfRenderViewCreator(nativeAd: ad)
      mediatedList.append(mediated)
      extList.append(AdtalosGromoreAdapterUtils.ecpmExt(fromPrice: ad.price))
    }

    deliveredToBridge = true
    bridge.nativeAd?(adapter, didLoadWith: mediatedList, exts: extList)
  }

  @MainActor
  private func disposeSlotsWithoutRemovingManager() {
    for slot in slots {
      slot.dispose()
    }
    slots = []
  }

  private final class Slot: NSObject, Listener, VideoListener {
    weak var owner: AdtalosGromoreNativeAdManager?
    let nativeAd: NativeAd
    private var videoMetadataReady = false

    init(owner: AdtalosGromoreNativeAdManager, placementId: String) {
      self.owner = owner
      self.nativeAd = NativeAd(unitID: placementId)
      super.init()
    }

    @MainActor
    var mediationReady: Bool {
      guard nativeAd.isLoaded, let response = nativeAd.nativeResponse else { return false }
      if response.hasVideo {
        return videoMetadataReady
      }
      return true
    }

    func beginLoad() {
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.nativeAd.listener = self
        self.nativeAd.videoListener = self
        self.nativeAd.autoRetry = 0
        AdtalosGromoreAdapterUtils.reportGromoreEvent(.gromoreLoad, ad: self.nativeAd)
        self.nativeAd.load()
      }
    }

    @MainActor
    func dispose() {
      nativeAd.nativeResponse?.unregisterViews()
      nativeAd.listener = nil
      nativeAd.videoListener = nil
      AdtalosGromoreAdapterUtils.reportGromoreEvent(.gromoreDestroy, ad: nativeAd)
      nativeAd.destroy()
    }

    func onLoaded() {
      owner?.slotReadyMayHaveChanged()
    }

    func onFailedToLoad(_ error: Error) {
      owner?.slotFailed(error)
    }

    func onRendered() {}

    func onShown() {
      AdtalosGromoreAdapterUtils.reportGromoreEvent(.gromoreShow, ad: nativeAd)
      guard let owner, let adapter = owner.adapter, let bridge = owner.bridge else { return }
      bridge.nativeAd?(adapter, didVisibleWithMediatedNativeAd: nativeAd)
    }

    func onClicked() {
      guard let owner, let adapter = owner.adapter, let bridge = owner.bridge else { return }
      bridge.nativeAd?(adapter, didClickWithMediatedNativeAd: nativeAd)
    }

    func onLeftApplication() {
      guard let owner, let adapter = owner.adapter, let bridge = owner.bridge else { return }
      bridge.nativeAd?(adapter, willPresentFullScreenModalWithMediatedNativeAd: nativeAd)
    }

    func onClosed() {}

    @MainActor
    func onVideoLoad(_ metadata: VideoMetadata) {
      videoMetadataReady = true
      owner?.slotReadyMayHaveChanged()

      if let nativeResponse = nativeAd.nativeResponse {
        DispatchQueue.main.async { [weak nativeResponse] in
          nativeResponse?.refreshMotionHintViewPosition()
        }
      }
    }

    func onVideoStart() {
      reportVideoState(.statePlaying)
    }

    func onVideoPlay() {
      reportVideoState(.statePlaying)
    }

    func onVideoPause() {
      reportVideoState(.statePause)
    }

    func onVideoEnd() {
      reportVideoState(.stateStopped)
      reportVideoPlayFinish()
    }

    func onVideoVolumeChange(_ volume: Double, muted: Bool) {}
    func onVideoTimeUpdate(_ currentTime: Double, duration: Double) {}

    func onVideoError() {
      reportVideoState(.stateFailed)
    }

    func onVideoBreak() {
      reportVideoState(.stateStopped)
    }

    private func reportVideoState(_ state: BUPlayerPlayState) {
      guard let owner, let adapter = owner.adapter, let bridge = owner.bridge else { return }
      bridge.nativeAd?(adapter, videoStateDidChangedWith: state, andNativeAd: nativeAd)
    }

    private func reportVideoPlayFinish() {
      guard let owner, let adapter = owner.adapter, let bridge = owner.bridge else {
        return
      }
      bridge.nativeAd?(adapter, videoDidPlayFinish: nativeAd)
    }
  }
}
