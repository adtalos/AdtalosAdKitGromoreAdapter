//
//  AdtalosGromoreAdapterUtils.swift
//  AdtalosAdKitGromoreAdapter
//
//  Created by 赵言 on 2026/4/10.
//

import AdtalosAdKit
import BUAdSDK
import Foundation

/// Gromore 适配器事件码，避免直接依赖 AdtalosAdKit.EventType 中的 gromore 段。
enum GromoreAdapterEvent: Int32 {
  case gromoreInit = 430
  case gromoreLoad = 431
  case gromoreShow = 432
  case gromoreDestroy = 433
}

enum AdtalosGromoreAdapterUtils {
  static let adapterSDKVersion: String = "1.0.3"

  // Adtalos 自定义配置字段，非 GroMore SDK 官方常量。
  private static let shakeEnabledKey = "adtalos_shake_enabled"

  static func shakeEnabled(from parameter: [AnyHashable: Any]?) -> Bool {
    // true 仅允许 Adtalos 广告素材配置的摇一摇生效，不会强制开启未下发的交互。
    return boolValue(from: parameter?[shakeEnabledKey])
      ?? boolValue(from: BUAdSDKConfiguration.configuration().mediation.extraData?[shakeEnabledKey])
      ?? backendBoolValue(
        from: parameter?[BUMAdLoadingParamCustomJson] as? String, key: shakeEnabledKey)
      ?? true
  }

  static func backendBoolValue(from customJSON: String?, key: String) -> Bool? {
    guard let customJSON, !customJSON.isEmpty else { return nil }
    do {
      let config = try JSONSerialization.jsonObject(with: Data(customJSON.utf8)) as? [String: Any]
      return boolValue(from: config?[key])
    } catch {
      return nil
    }
  }

  private static func boolValue(from value: Any?) -> Bool? {
    guard let value else { return nil }
    if let number = value as? NSNumber {
      return number.compare(0) != .orderedSame
    }
    if let string = value as? String {
      return string != "false" && string != "0"
    }
    return true
  }

  static func ecpmExt(fromPrice price: Int64) -> [String: Any] {
    [
      BUMMediaAdLoadingExtECPM: String(max(0, price))
    ]
  }

  static func makeError(_ message: String, code: Int) -> NSError {
    NSError(
      domain: "com.adtalos.gromoreAdapter",
      code: code,
      userInfo: [NSLocalizedDescriptionKey: message]
    )
  }

  static func applyBidResult(win: Bool, winnerPrice: Int64, to ad: BaseAd?) {
    guard let ad, ad.isLoaded else { return }
    if win {
      if winnerPrice > 0 {
        ad.sendWinNotice(winnerPrice)
      } else {
        ad.sendWinNotice()
      }
    } else {
      ad.sendLossNotice(.priceLowFilter)
      DispatchQueue.main.async {
        ad.destroy()
      }
    }
  }

  // MARK: - Gromore mediation event reporting

  static func reportGromoreEvent(_ eventType: GromoreAdapterEvent, ad: BaseAd?) {
    DispatchQueue.main.async {
      EventReporter.apply(
        eventType: eventType.rawValue,
        adToken: ad?.unitID ?? "",
        eventID: ad?.adResponseEventID ?? "",
        requestID: ad?.adResponseRequestID ?? ""
      )
    }
  }
}
