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
  static let adapterSDKVersion: String = "1.0.0"

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
