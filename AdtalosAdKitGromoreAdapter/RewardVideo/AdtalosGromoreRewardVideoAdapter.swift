//
//  AdtalosGromoreRewardVideoAdapter.swift
//  AdtalosAdKitGromoreAdapter
//
//  Created by 赵言 on 2026/4/10.
//

import AdtalosAdKit
import BUAdSDK
import Foundation
import UIKit

@objc(AdtalosGromoreRewardVideoAdapter)
public final class AdtalosGromoreRewardVideoAdapter: NSObject, BUMCustomRewardedVideoAdapter {
  public var bridge: (any BUMCustomRewardedVideoAdapterBridge)?

  private var rewardVideoAd: RewardVideoAd?
  private let rewardVideoDelegate = AdtalosGromoreRewardVideoDelegate()

  public required override init() {
    super.init()
    bindDelegate()
  }

  public func enablePreloadWhenCurrentIsDisplay() -> Bool {
    false
  }

  public func mediatedAdStatus() -> BUMMediatedAdStatus {
    let loaded = rewardVideoAd?.isLoaded ?? false
    return BUMMediatedAdStatus(
      isReady: loaded ? .sure : .deny,
      unexpired: loaded ? .sure : .deny,
      valid: loaded ? .sure : .deny)
  }

  public func loadRewardedVideoAd(
    withSlotID slotID: String, andParameter parameter: [AnyHashable: Any]
  ) {
    let ad = RewardVideoAd(unitID: slotID)
    self.rewardVideoAd = ad
    ad.listener = rewardVideoDelegate
    ad.videoListener = rewardVideoDelegate
    ad.autoRetry = 0
    AdtalosGromoreAdapterUtils.reportGromoreEvent(.gromoreLoad, ad: ad)
    DispatchQueue.main.async { [weak self] in
      guard let self, self.rewardVideoAd != nil else { return }
      ad.load()
    }
  }

  public func showAd(
    fromRootViewController viewController: UIViewController, parameter: [AnyHashable: Any]
  ) -> Bool {
    guard let ad = rewardVideoAd, ad.isLoaded else {
      let error = AdtalosGromoreAdapterUtils.makeError("Reward video not ready", code: -2001)
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.bridge?.rewardedVideoAdDidShowFailed?(self, error: error)
      }
      return false
    }

    DispatchQueue.main.async { [weak self] in
      guard let self, self.rewardVideoAd != nil else { return }
      _ = ad.show()
    }
    return true
  }

  public func didReceive(_ result: BUMMediaBidResult) {
    let winnerPrice = Int64(result.winnerPrice)
    AdtalosGromoreAdapterUtils.applyBidResult(
      win: result.win, winnerPrice: winnerPrice, to: rewardVideoAd)
  }

  deinit {
    let rewardVideoAd = self.rewardVideoAd
    let rewardVideoDelegate = self.rewardVideoDelegate
    DispatchQueue.main.async {
      rewardVideoAd?.listener = nil
      rewardVideoAd?.videoListener = nil
      AdtalosGromoreAdapterUtils.reportGromoreEvent(.gromoreDestroy, ad: rewardVideoAd)
      rewardVideoAd?.destroy()
      rewardVideoDelegate.didLoad = nil
      rewardVideoDelegate.didFailToLoad = nil
      rewardVideoDelegate.didVisible = nil
      rewardVideoDelegate.didClick = nil
      rewardVideoDelegate.didClose = nil
      rewardVideoDelegate.didRewarded = nil
      rewardVideoDelegate.didPlayFinish = nil
      rewardVideoDelegate.didVideoError = nil
    }
  }

  private func bindDelegate() {
    rewardVideoDelegate.didLoad = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self, let ad = self.rewardVideoAd else { return }
        let ext = AdtalosGromoreAdapterUtils.ecpmExt(fromPrice: ad.price)
        self.bridge?.rewardedVideoAd?(self, didLoadWithExt: ext)
      }
    }

    rewardVideoDelegate.didFailToLoad = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        let error = AdtalosGromoreAdapterUtils.makeError("Reward video load failed", code: -2001)
        self.bridge?.rewardedVideoAd?(self, didLoadFailWithError: error, ext: [:])
      }
    }

    rewardVideoDelegate.didVisible = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        AdtalosGromoreAdapterUtils.reportGromoreEvent(.gromoreShow, ad: self.rewardVideoAd)
        self.bridge?.rewardedVideoAdDidVisible?(self)
      }
    }

    rewardVideoDelegate.didClick = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.bridge?.rewardedVideoAdDidClick?(self)
      }
    }

    rewardVideoDelegate.didClose = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.bridge?.rewardedVideoAdDidClose?(self)
      }
    }

    rewardVideoDelegate.didRewarded = { [weak self] data in
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.bridge?.rewardedVideoAd?(
          self,
          didServerRewardSuccessWithInfo: { info in
            if !data.isEmpty {
              info.rewardName = data
            }
            info.verify = true
          })
      }
    }

    rewardVideoDelegate.didPlayFinish = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.bridge?.rewardedVideoAd?(self, didPlayFinishWithError: nil)
      }
    }

    rewardVideoDelegate.didVideoError = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        let error = AdtalosGromoreAdapterUtils.makeError(
          "Reward video playback failed", code: -2002)
        self.bridge?.rewardedVideoAd?(self, didPlayFinishWithError: error)
      }
    }
  }
}
