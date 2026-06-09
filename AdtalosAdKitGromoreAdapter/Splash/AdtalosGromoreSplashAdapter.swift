//
//  AdtalosGromoreSplashAdapter.swift
//  AdtalosAdKitGromoreAdapter
//
//  Created by 赵言 on 2026/4/10.
//

import AdtalosAdKit
import BUAdSDK
import Foundation
import UIKit

@objc(AdtalosGromoreSplashAdapter)
public final class AdtalosGromoreSplashAdapter: NSObject, BUMCustomSplashAdapter {
  public var bridge: (any BUMCustomSplashAdapterBridge & BUMCustomSplashAdapterCardViewBridge)?

  private let splashDelegate = AdtalosGromoreSplashDelegate()
  private var splashAd: SplashAd?
  private var bottomView: UIView?

  public required override init() {
    super.init()
    bindDelegate()
  }

  public func enablePreloadWhenCurrentIsDisplay() -> Bool {
    false
  }

  public func mediatedAdStatus() -> BUMMediatedAdStatus {
    let loaded = splashAd?.isLoaded ?? false
    return BUMMediatedAdStatus(
      isReady: loaded ? .sure : .deny,
      unexpired: loaded ? .sure : .deny,
      valid: loaded ? .sure : .deny)
  }

  public func loadSplashAd(withSlotID slotID: String, andParameter parameter: [AnyHashable: Any]) {
    bottomView = parameter[BUMAdLoadingParamSPCustomBottomView] as? UIView

    let ad = SplashAd(unitID: slotID)
    ad.listener = self.splashDelegate
    ad.autoRetry = 0
    self.splashAd = ad

    AdtalosGromoreAdapterUtils.reportGromoreEvent(.gromoreLoad, ad: splashAd)

    DispatchQueue.main.async { [weak self] in
      guard let self, self.splashAd != nil else { return }
      ad.load()
    }
  }

  public func showSplashAd(in window: UIWindow, parameter: [AnyHashable: Any]) {
    guard let ad = splashAd, ad.isLoaded else {
      let error = AdtalosGromoreAdapterUtils.makeError("Splash not ready", code: -3001)
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        self.bridge?.splashAdDidShowFailed?(self, error: error)
      }
      return
    }

    DispatchQueue.main.async { [weak self, weak window, weak bottomView] in
      guard let self, let ad = self.splashAd else { return }
      if let bottomView = bottomView, let window = window {
        self.bottomView = bottomView
        window.addSubview(bottomView)
        let size =
          bottomView.bounds.size == .zero
          ? CGSize(width: window.bounds.width, height: 0)
          : bottomView.bounds.size
        bottomView.frame = CGRect(
          x: 0,
          y: window.bounds.height - size.height,
          width: window.bounds.width,
          height: size.height
        )
        _ = ad.show(view: window, frame: CGRect(
          x: 0,
          y: 0,
          width: window.bounds.width,
          height: window.bounds.height - bottomView.frame.height
        ))
        return
      }
      ad.show()
    }
  }

  public func dismissSplashAd() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      let ad = self.splashAd
      AdtalosGromoreAdapterUtils.reportGromoreEvent(.gromoreDestroy, ad: ad)
      ad?.destroy()
      self.bottomView?.removeFromSuperview()
      self.bottomView = nil
    }
  }

  public func didReceive(_ result: BUMMediaBidResult) {
    let winnerPrice = Int64(result.winnerPrice)
    AdtalosGromoreAdapterUtils.applyBidResult(
      win: result.win, winnerPrice: winnerPrice, to: splashAd)
  }

  deinit {
    let splashAd = self.splashAd
    let bottomView = self.bottomView
    let splashDelegate = self.splashDelegate
    DispatchQueue.main.async {
      splashAd?.listener = nil
      AdtalosGromoreAdapterUtils.reportGromoreEvent(.gromoreDestroy, ad: splashAd)
      splashAd?.destroy()
      bottomView?.removeFromSuperview()

      splashDelegate.didLoad = nil
      splashDelegate.didFailToLoad = nil
      splashDelegate.didShow = nil
      splashDelegate.didClick = nil
      splashDelegate.didLeaveApplication = nil
      splashDelegate.didClose = nil
    }
  }

  private func bindDelegate() {
    splashDelegate.didLoad = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self, let ad = self.splashAd else { return }
        let ext = AdtalosGromoreAdapterUtils.ecpmExt(fromPrice: ad.price)
        self.bridge?.splashAd?(self, didLoadWithExt: ext)
      }
    }

    splashDelegate.didFailToLoad = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        let error = AdtalosGromoreAdapterUtils.makeError("Splash load failed", code: -3001)
        self.bridge?.splashAd?(self, didLoadFailWithError: error, ext: [:])
      }
    }

    splashDelegate.didShow = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        AdtalosGromoreAdapterUtils.reportGromoreEvent(.gromoreShow, ad: self.splashAd)
        self.bridge?.splashAdWillVisible?(self)
      }
    }

    splashDelegate.didClick = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.bridge?.splashAdDidClick?(self)
      }
    }

    splashDelegate.didLeaveApplication = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.bridge?.splashAdWillPresentFullScreenModal?(self)
      }
    }

    splashDelegate.didClose = { [weak self] in
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        self.bottomView?.removeFromSuperview()
        self.bottomView = nil
        self.bridge?.splashAdDidClose?(self)
      }
    }
  }
}
