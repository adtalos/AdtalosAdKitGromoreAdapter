//
//  AdtalosGromoreInterstitialAdapter.swift
//  AdtalosAdKitGromoreAdapter
//
//  Created by 赵言 on 2026/4/10.
//

import AdtalosAdKit
import BUAdSDK
import Foundation
import UIKit

@objc(AdtalosGromoreInterstitialAdapter)
public final class AdtalosGromoreInterstitialAdapter: NSObject, BUMCustomInterstitialAdapter {
  public var bridge: (any BUMCustomInterstitialAdapterBridge)?

  private var interstitialAd: InterstitialAd?
  private let interstitialDelegate = AdtalosGromoreInterstitialDelegate()

  public required override init() {
    super.init()
    bindDelegate()
  }

  public func enablePreloadWhenCurrentIsDisplay() -> Bool {
    false
  }

  public func mediatedAdStatus() -> BUMMediatedAdStatus {
    let loaded = interstitialAd?.isLoaded ?? false
    return BUMMediatedAdStatus(
      isReady: loaded ? .sure : .deny,
      unexpired: loaded ? .sure : .deny,
      valid: loaded ? .sure : .deny)
  }

  public func loadInterstitialAd(
    withSlotID slotID: String, andSize size: CGSize, parameter: [AnyHashable: Any]
  ) {
    let ad = InterstitialAd(unitID: slotID)
    self.interstitialAd = ad
    ad.listener = interstitialDelegate
    ad.videoListener = interstitialDelegate
    ad.autoRetry = 0
    AdtalosGromoreAdapterUtils.reportGromoreEvent(.gromoreLoad, ad: ad)
    DispatchQueue.main.async { [weak self] in
      guard let self, self.interstitialAd != nil else { return }
      ad.load()
    }
  }

  public func showAd(
    fromRootViewController viewController: UIViewController, parameter: [AnyHashable: Any]
  ) -> Bool {
    guard let ad = interstitialAd, ad.isLoaded else {
      let error = AdtalosGromoreAdapterUtils.makeError("Interstitial not ready", code: -1001)
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.bridge?.interstitialAdDidShowFailed?(self, error: error)
      }
      return false
    }

    DispatchQueue.main.async { [weak self] in
      guard let self, self.interstitialAd != nil else { return }
      _ = ad.show()
    }
    return true
  }

  public func didReceive(_ result: BUMMediaBidResult) {
    let winnerPrice = Int64(result.winnerPrice)
    AdtalosGromoreAdapterUtils.applyBidResult(
      win: result.win, winnerPrice: winnerPrice, to: interstitialAd)
  }

  deinit {
    let interstitialAd = self.interstitialAd
    let interstitialDelegate = self.interstitialDelegate
    DispatchQueue.main.async {
      interstitialAd?.listener = nil
      interstitialAd?.videoListener = nil
      AdtalosGromoreAdapterUtils.reportGromoreEvent(.gromoreDestroy, ad: interstitialAd)
      interstitialAd?.destroy()
      interstitialDelegate.didLoad = nil
      interstitialDelegate.didFailToLoad = nil
      interstitialDelegate.didVisible = nil
      interstitialDelegate.didClick = nil
      interstitialDelegate.didClose = nil
    }
  }

  private func bindDelegate() {
    interstitialDelegate.didLoad = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self, let ad = self.interstitialAd else { return }
        let ext = AdtalosGromoreAdapterUtils.ecpmExt(fromPrice: ad.price)
        self.bridge?.interstitialAd?(self, didLoadWithExt: ext)
      }
    }

    interstitialDelegate.didFailToLoad = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        let error = AdtalosGromoreAdapterUtils.makeError("Interstitial load failed", code: -1001)
        self.bridge?.interstitialAd?(self, didLoadFailWithError: error, ext: [:])
      }
    }

    interstitialDelegate.didVisible = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        AdtalosGromoreAdapterUtils.reportGromoreEvent(.gromoreShow, ad: self.interstitialAd)
        self.bridge?.interstitialAdDidVisible?(self)
      }
    }

    interstitialDelegate.didClick = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.bridge?.interstitialAdDidClick?(self)
      }
    }

    interstitialDelegate.didClose = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.bridge?.interstitialAdDidClose?(self)
      }
    }
  }
}
