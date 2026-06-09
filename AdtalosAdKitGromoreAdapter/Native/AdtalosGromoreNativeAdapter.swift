//
//  AdtalosGromoreNativeAdapter.swift
//  AdtalosAdKitGromoreAdapter
//
//  Created by 赵言 on 2026/4/23.
//

import AdtalosAdKit
import BUAdSDK
import Foundation
import UIKit

@objc(AdtalosGromoreNativeAdapter)
public final class AdtalosGromoreNativeAdapter: NSObject, BUMCustomNativeAdapter {

  @MainActor
  public func unregisterClickableViews(forNativeAd nativeAd: Any) {
    guard let ad = nativeAd as? NativeAd else { return }
    ad.nativeResponse?.unregisterViews()
  }

  public var bridge: (any BUMCustomNativeAdapterBridge)?

  /// 当前自渲染批次
  private var selfRenderManager: AdtalosGromoreNativeAdManager?
  /// 当前模板信息流批次。
  private var feedTemplateManager: AdtalosGromoreNativeFeedAdManager?
  /// 监听模板广告视图高度变化，用于同步父容器高度。
  private var expressFrameObservers: [ObjectIdentifier: NSKeyValueObservation] = [:]

  @MainActor
  public func mediatedAdStatus(with ad: BUMMediatedNativeAd) -> BUMMediatedAdStatus {
    var ready = false
    if let originAd = ad.originMediatedNativeAd as? NativeAd {
      ready = originAd.isLoaded
    } else {
      ready = false
    }
    return status(ready: ready)
  }

  @MainActor
  public func mediatedAdStatus(withExpressView view: UIView) -> BUMMediatedAdStatus {
    let ready = feedTemplateManager?.isExpressViewReady(view) ?? false
    return status(ready: ready)
  }

  public func enablePreloadWhenCurrentIsDisplay() -> Bool {
    false
  }

  public required override init() {
    super.init()
  }

  @MainActor
  public func loadNativeAd(
    withSlotID slotID: String,
    andSize size: CGSize,
    imageSize: CGSize,
    parameter: [AnyHashable: Any]
  ) {
    resetCurrentLoadsForNewRequest()

    let loadAdCount = Self.nativeLoadAdCount(from: parameter)
    let expressType = (parameter[BUMAdLoadingParamExpressAdType] as? NSNumber)?.intValue ?? 0
    let isTemplate = expressType == 1

    if isTemplate {
      let manager = AdtalosGromoreNativeFeedAdManager(bridge: bridge, adapter: self)
      feedTemplateManager = manager
      manager.load(placementId: slotID, adSize: size, loadCount: loadAdCount)
    } else {
      let manager = AdtalosGromoreNativeAdManager(bridge: bridge, adapter: self)
      selfRenderManager = manager
      manager.load(placementId: slotID, loadCount: loadAdCount)
    }
  }

  public func render(forExpressAdView expressAdView: UIView) {
    bridge?.nativeAd?(self, renderSuccessWithExpressView: expressAdView)
  }

  public func setRootViewController(
    _ viewController: UIViewController,
    forExpressAdView expressAdView: UIView
  ) {
    DispatchQueue.main.async { [weak self, weak expressAdView] in
      guard
        let self,
        let expressAdView,
        let container = expressAdView.superview
      else {
        return
      }

      let key = ObjectIdentifier(expressAdView)
      self.expressFrameObservers[key]?.invalidate()
      self.expressFrameObservers[key] = nil

      let currentHeight = expressAdView.frame.height
      if currentHeight > 0, abs(container.frame.height - currentHeight) > 0.1 {
        var containerFrame = container.frame
        containerFrame.size.height = currentHeight
        container.frame = containerFrame
      }

      let observer = expressAdView.observe(\.frame, options: [.new, .initial]) {
        [weak container] _, change in
        guard let container, let newFrame = change.newValue else { return }
        let newHeight = newFrame.height
        guard newHeight > 0 else { return }
        DispatchQueue.main.async {
          var containerFrame = container.frame
          if abs(containerFrame.height - newHeight) > 0.1 {
            containerFrame.size.height = newHeight
            container.frame = containerFrame
          }
        }
      }
      self.expressFrameObservers[key] = observer
    }
  }

  @MainActor
  public func setRootViewController(
    _ viewController: UIViewController,
    forNativeAd nativeAd: Any
  ) {
    (nativeAd as? NativeAd)?.nativeResponse?.refreshMotionHintViewPosition()
  }

  @MainActor
  public func registerContainerView(
    _ containerView: UIView,
    andClickableViews views: [UIView],
    forNativeAd nativeAd: Any
  ) {
    guard let ad = nativeAd as? NativeAd else { return }
    ad.nativeResponse?.registerViews(
      (containerView.subviews.first != nil) ? containerView.subviews.first : containerView,
      clickViews: views, closeViews: [])
  }

  public func didReceive(_ result: BUMMediaBidResult) {
    selfRenderManager?.handleBidResult(result)
    feedTemplateManager?.handleBidResult(result)
  }

  public func reportVideoEvent(
    _ event: BUMVideoAdEvent,
    for ad: BUMMediatedNativeAd,
    withParameters parameters: [AnyHashable: Any]
  ) {
  }

  deinit {
    let sr = selfRenderManager
    let ft = feedTemplateManager
    selfRenderManager = nil
    feedTemplateManager = nil
    for (_, observer) in expressFrameObservers {
      observer.invalidate()
    }
    expressFrameObservers.removeAll()
    DispatchQueue.main.async {
      sr?.tearDown()
      ft?.tearDown()
    }
  }
}

extension AdtalosGromoreNativeAdapter {
  /// 自渲染最后一条被卸载后，释放对 Manager 的强引用。
  func clearSelfRenderManagerIfCurrent(_ manager: AdtalosGromoreNativeAdManager) {
    if selfRenderManager === manager {
      selfRenderManager = nil
    }
  }

  /// 模板加载失败等场景下释放 Manager。
  func clearFeedTemplateManagerIfCurrent(_ manager: AdtalosGromoreNativeFeedAdManager) {
    if feedTemplateManager === manager {
      feedTemplateManager = nil
    }
  }

  @MainActor
  private func resetCurrentLoadsForNewRequest() {
    selfRenderManager?.tearDown()
    selfRenderManager = nil
    feedTemplateManager?.tearDown()
    feedTemplateManager = nil
    for (_, observer) in expressFrameObservers {
      observer.invalidate()
    }
    expressFrameObservers.removeAll()
  }

  private static func nativeLoadAdCount(from parameter: [AnyHashable: Any]) -> Int {
    let raw: Int
    if let num = parameter[BUMAdLoadingParamNALoadAdCount] as? NSNumber {
      raw = num.intValue
    } else if let i = parameter[BUMAdLoadingParamNALoadAdCount] as? Int {
      raw = i
    } else {
      raw = 0
    }
    return max(1, raw)
  }

  private func status(ready: Bool) -> BUMMediatedAdStatus {
    BUMMediatedAdStatus(
      isReady: ready ? .sure : .deny,
      unexpired: ready ? .sure : .deny,
      valid: ready ? .sure : .deny
    )
  }
}
