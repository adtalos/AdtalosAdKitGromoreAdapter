//
//  AdtalosGromoreCustomConfigAdapter.swift
//  AdtalosAdKitGromoreAdapter
//
//  Created by 赵言 on 2026/4/10.
//

import AdtalosAdKit
import BUAdSDK
import Foundation

@objc(AdtalosGromoreCustomConfigAdapter)
public final class AdtalosGromoreCustomConfigAdapter: NSObject, BUMCustomConfigAdapter {
  /// 采集相关配置，默认全部开启，外部可通过静态方法修改
  private static var presetIdfa: String = ""
  private static var acquireIDFA: Bool = true
  private static var acquireIDFV: Bool = true
  private static var acquireUserAgent: Bool = true
  private static var acquireGeoInfo: Bool = true
  private static var acquireInstalledApps: Bool = true
  private static var enableLocalLog: Bool = true
  private static var presetJoinKey: JoinKey? = nil
  private static var presetJoinKey2: JoinKey? = nil

  @objc public static func setIdfa(_ idfa: String) {
    presetIdfa = idfa
  }

  @objc public static func setAcquireIDFA(_ enabled: Bool) {
    acquireIDFA = enabled
  }

  @objc public static func setAcquireIDFV(_ enabled: Bool) {
    acquireIDFV = enabled
  }

  @objc public static func setAcquireUserAgent(_ enabled: Bool) {
    acquireUserAgent = enabled
  }

  @objc public static func setAcquireGeoInfo(_ enabled: Bool) {
    acquireGeoInfo = enabled
  }

  @objc public static func setAcquireInstalledApps(_ enabled: Bool) {
    acquireInstalledApps = enabled
  }

  @objc public static func setEnableLocalLog(_ enabled: Bool) {
    enableLocalLog = enabled
  }

  @objc public static func setJoinKey(_ joinKey: JoinKey?) {
    presetJoinKey = joinKey
  }

  @objc public static func getJoinKey() -> JoinKey? {
    return presetJoinKey
  }

  @objc public static func setJoinKey2(_ joinKey2: JoinKey?) {
    presetJoinKey2 = joinKey2
  }

  @objc public static func getJoinKey2() -> JoinKey? {
    return presetJoinKey2
  }

  public func adnInitInfo() -> NSMutableDictionary {
    return ["status": true, "duration": 0]
  }

  public override init() {
    super.init()
  }

  /// 该自定义 adapter 基于哪个版本实现
  public func basedOnCustomAdapterVersion() -> BUMCustomAdapterVersion {
    return BUMCustomAdapterVersion1_1
  }

  public func adapterVersion() -> String {
    AdtalosGromoreAdapterUtils.adapterSDKVersion
  }

  public func networkSdkVersion() -> String {
    SDK.sdkVersion
  }

  public func initializeAdapter(withConfiguration initConfig: BUMSdkInitConfig?) {
    let token = (initConfig?.appID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let appToken = (initConfig?.appKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let config = Self.makeConfiguration(token: token, appToken: appToken)

    AdtalosGromoreAdapterUtils.reportGromoreEvent(.gromoreInit, ad: nil)

    DispatchQueue.main.async {
      SDK.initialize(config)
    }
  }

  public func didRequestAdPrivacyConfigUpdate(_ config: [AnyHashable: Any]) {
  }

  public func didReceiveConfigUpdateRequest(_ config: BUMUserConfig) {
  }

  private static func makeConfiguration(token: String, appToken: String) -> Configuration {
    let joinKey = presetJoinKey ?? JoinKey()
    let joinKey2 = presetJoinKey2 ?? JoinKey()
    return Configuration(
      token: token,
      appToken: appToken,
      idfa: presetIdfa,
      acquireIDFA: acquireIDFA,
      acquireIDFV: acquireIDFV,
      acquireUserAgent: acquireUserAgent,
      acquireGeoInfo: acquireGeoInfo,
      acquireInstalledApps: acquireInstalledApps,
      enableLocalLog: enableLocalLog,
      joinKey: joinKey,
      joinKey2: joinKey2
    )
  }
}
