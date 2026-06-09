//
//  AdtalosGromoreNativeMediatedAd.swift
//  AdtalosAdKitGromoreAdapter
//
//  Created by 赵言 on 2026/4/23.
//

import AdtalosAdKit
import BUAdSDK
import Foundation
import UIKit

final class AdtalosGromoreNativeMaterialData: NSObject, BUMMediatedNativeAdData {
  private weak var response: NativeResponse?

  init(response: NativeResponse?) {
    self.response = response
    super.init()
  }

  var callToType: BUMMediatedNativeAdCallToType { .others }

  var imageList: [BUMImage]? {
    guard let response else { return nil }
    var images: [BUMImage] = []
    for imageURL in response.imageURLList {
      let image = BUMImage()
      if let url = URL(string: imageURL) {
        image.imageURL = url
      }
      images.append(image)
    }
    if !response.imageURL.isEmpty {
      let item = BUMImage()
      if let url = URL(string: response.imageURL) {
        item.imageURL = url
      }
      if let image = response.image {
        item.image = image
      }
      images.append(item)
    }
    return images
  }

  var icon: BUMImage? {
    guard let response else { return nil }
    let icon = BUMImage()
    icon.image = response.icon ?? UIImage()
    if !response.iconURL.isEmpty, let url = URL(string: response.iconURL) {
      icon.imageURL = url
    }
    return icon
  }

  var adLogo: BUMImage? {
    guard let response else { return nil }
    let logo = BUMImage()
    logo.image = response.logo ?? UIImage()
    if !response.logoURL.isEmpty, let url = URL(string: response.logoURL) {
      logo.imageURL = url
    }
    return logo
  }

  var adTextLogo: BUMImage? { nil }
  var adTitle: String? { response?.title }
  var adDescription: String? { response?.desc }
  var source: String? { response?.developer }
  var buttonText: String? { response?.buttonText }
  var appPrice: String? { nil }
  var advertiser: String? { response?.developer }
  var brandName: String? {
    guard let response else { return nil }
    return response.appName.isEmpty ? response.developer : response.appName
  }
  var dislikeReasons: [BUMDislikeReason]? { nil }
  var videoUrl: String? { response?.videoURL }

  var imageMode: BUFeedADMode {
    return response?.hasVideo ?? false ? .videoAdModeImage : .adModeMediationUnknown
  }

  var score: Int { -1 }
  var commentNum: Int { -1 }
  var appSize: Int { 0 }
  var videoDuration: Int {
    guard let duration = response?.videoMetadata?.duration else { return 0 }
    return Int(duration)
  }
  var videoAspectRatio: CGFloat {
    guard let metadata = response?.videoMetadata, metadata.videoHeight > 0 else { return 0 }
    return CGFloat(metadata.videoWidth / metadata.videoHeight)
  }
  var mediaExt: [AnyHashable: Any]? { nil }
}

final class AdtalosGromoreNativeSelfRenderViewCreator: NSObject, BUMMediatedNativeAdViewCreator {
  var hasSupportActionBtn: Bool = true
  @MainActor var titleLabel: UILabel? {
    syncPrimaryViewsIfNeeded()
    return fallbackTitleLabel
  }
  @MainActor var descLabel: UILabel? {
    syncPrimaryViewsIfNeeded()
    return fallbackDescLabel
  }
  @MainActor var iconImageView: UIImageView? {
    syncPrimaryViewsIfNeeded()
    return fallbackIconImageView
  }
  @MainActor var callToActionBtn: UIButton? {
    syncPrimaryViewsIfNeeded()
    return fallbackCallToActionBtn
  }
  var advertiserView: UIView?
  var ecMallView: UIView?

  private weak var nativeAd: NativeAd?
  private weak var rootViewController: UIViewController?
  private lazy var fallbackView = UIView(frame: .zero)
  private lazy var fallbackMediaView = UIView(frame: .zero)
  private lazy var fallbackImageView = UIImageView(frame: .zero)
  private lazy var fallbackDislikeButton = UIButton(type: .custom)
  private lazy var fallbackTitleLabel = UILabel(frame: .zero)
  private lazy var fallbackDescLabel = UILabel(frame: .zero)
  private lazy var fallbackIconImageView = UIImageView(frame: .zero)
  private lazy var fallbackCallToActionBtn = UIButton(type: .custom)
  @MainActor private var cachedAdLogoView: UIView?

  init(nativeAd: NativeAd) {
    self.nativeAd = nativeAd
    super.init()
  }

  @MainActor
  var mediaView: UIView? {
    nativeAd?.nativeResponse?.videoView ?? fallbackMediaView
  }

  @MainActor
  var adLogoView: UIView? {
    if let cached = cachedAdLogoView {
      return cached
    }
    guard let logo = nativeAd?.nativeResponse?.logo else {
      return fallbackView
    }

    let view = UIView(frame: CGRect(origin: .zero, size: logo.size))
    let imageView = UIImageView(frame: view.bounds)
    imageView.image = logo
    view.addSubview(imageView)
    cachedAdLogoView = view
    return view
  }

  var dislikeBtn: UIButton? {
    fallbackDislikeButton
  }

  @MainActor
  var imageView: UIImageView? {
    if let image = nativeAd?.nativeResponse?.image ?? nativeAd?.nativeResponse?.imageList.first {
      fallbackImageView.image = image
    }
    return fallbackImageView
  }

  @MainActor
  private func syncPrimaryViewsIfNeeded() {
    guard let response = nativeAd?.nativeResponse else { return }
    fallbackTitleLabel.text = response.title
    fallbackDescLabel.text = response.desc
    fallbackIconImageView.image = response.icon
    fallbackCallToActionBtn.setTitle(response.callToAction, for: .normal)
    fallbackCallToActionBtn.setTitle(response.callToAction, for: .highlighted)
  }
}

extension NativeResponse {
  fileprivate var callToAction: String { buttonText }
}
