//
//  AdtalosGromoreBannerAdapter.swift
//  AdtalosAdKitGromoreAdapter
//
//  Created by 赵言 on 2026/4/10.
//

import AdtalosAdKit
import BUAdSDK
import Foundation
import UIKit

@objc(AdtalosGromoreBannerAdapter)
public final class AdtalosGromoreBannerAdapter: NSObject, BUMCustomBannerAdapter {
  public var bridge: (any BUMCustomBannerAdapterBridge)?

  private var bannerAd: BannerAd?
  private let bannerDelegate = AdtalosGromoreBannerDelegate()

  public required override init() {
    super.init()
    bindDelegate()
  }

  public func enablePreloadWhenCurrentIsDisplay() -> Bool {
    false
  }

  public func mediatedAdStatus() -> BUMMediatedAdStatus {
    let loaded = bannerAd?.isLoaded ?? false
    return BUMMediatedAdStatus(
      isReady: loaded ? .sure : .deny,
      unexpired: loaded ? .sure : .deny,
      valid: loaded ? .sure : .deny)
  }

  public func loadBannerAd(
    withSlotID slotID: String, andSize adSize: CGSize, parameter: [AnyHashable: Any]?
  ) {
    let size: CGSize =
      adSize == .zero
      ? CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width * 5 / 32)
      : adSize

    let bannerAd = BannerAd(frame: CGRect(origin: .zero, size: size), unitID: slotID)
    self.bannerAd = bannerAd
    bannerAd.listener = bannerDelegate
    bannerAd.autoRetry = 0
    AdtalosGromoreAdapterUtils.reportGromoreEvent(.gromoreLoad, ad: bannerAd)
    DispatchQueue.main.async { [weak self] in
      guard let self, self.bannerAd != nil else { return }
      bannerAd.load()
    }
  }

  public func didReceive(_ result: BUMMediaBidResult) {
    let winnerPrice = Int64(result.winnerPrice)
    AdtalosGromoreAdapterUtils.applyBidResult(
      win: result.win, winnerPrice: winnerPrice, to: bannerAd)
  }

  deinit {
    let bannerAd = self.bannerAd
    let bannerDelegate = self.bannerDelegate
    DispatchQueue.main.async {
      bannerAd?.view?.removeFromSuperview()
      bannerAd?.listener = nil
      AdtalosGromoreAdapterUtils.reportGromoreEvent(.gromoreDestroy, ad: bannerAd)
      bannerAd?.destroy()
      bannerDelegate.didLoad = nil
      bannerDelegate.didFailToLoad = nil
      bannerDelegate.didShow = nil
      bannerDelegate.didClick = nil
      bannerDelegate.didLeaveApplication = nil
      bannerDelegate.didClose = nil
    }
  }

  private func bindDelegate() {
    bannerDelegate.didLoad = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self, let ad = self.bannerAd, let view = ad.view else { return }
        let ext = AdtalosGromoreAdapterUtils.ecpmExt(fromPrice: ad.price)
        self.bridge?.bannerAd?(self, didLoad: view, ext: ext)
      }
    }

    bannerDelegate.didFailToLoad = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        let error = AdtalosGromoreAdapterUtils.makeError("Banner load failed", code: -4001)
        self.bridge?.bannerAd?(self, didLoadFailWithError: error, ext: [:])
      }
    }

    bannerDelegate.didShow = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self, let view = self.bannerAd?.view else { return }
        AdtalosGromoreAdapterUtils.reportGromoreEvent(.gromoreShow, ad: self.bannerAd)
        self.bridge?.bannerAdDidBecomeVisible?(self, bannerView: view)
      }
    }

    bannerDelegate.didClick = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self, let view = self.bannerAd?.view else { return }
        self.bridge?.bannerAdDidClick?(self, bannerView: view)
      }
    }

    bannerDelegate.didLeaveApplication = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self, let view = self.bannerAd?.view else { return }
        self.bridge?.bannerAdWillPresentFullScreenModal?(self, bannerView: view)
      }
    }

    bannerDelegate.didClose = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self, let view = self.bannerAd?.view else { return }
        self.bridge?.bannerAd?(self, bannerView: view, didClosedWithDislikeWithReason: [])
      }
    }
  }
}
