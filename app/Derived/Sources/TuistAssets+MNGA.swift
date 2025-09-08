// swiftlint:disable:this file_name
// swiftlint:disable all
// swift-format-ignore-file
// swiftformat:disable all
// Generated using tuist — https://github.com/tuist/tuist

#if os(macOS)
  import AppKit
#elseif os(iOS)
  import UIKit
#elseif os(tvOS) || os(watchOS)
  import UIKit
#endif
#if canImport(SwiftUI)
  import SwiftUI
#endif

// MARK: - Asset Catalogs

public enum MNGAAsset: Sendable {
  public static let accentColor = MNGAColors(name: "AccentColor")
  public static let github = MNGAImages(name: "github")
  public static let lightAccentColor = MNGAColors(name: "LightAccentColor")
  public static let roundedIcon = MNGAImages(name: "RoundedIcon")
  public static let a2Doge = MNGAImages(name: "a2|doge")
  public static let a2Goodjob = MNGAImages(name: "a2|goodjob")
  public static let a2Jojo立 = MNGAImages(name: "a2|jojo立")
  public static let a2Jojo立2 = MNGAImages(name: "a2|jojo立2")
  public static let a2Jojo立3 = MNGAImages(name: "a2|jojo立3")
  public static let a2Jojo立4 = MNGAImages(name: "a2|jojo立4")
  public static let a2Jojo立5 = MNGAImages(name: "a2|jojo立5")
  public static let a2Lucky = MNGAImages(name: "a2|lucky")
  public static let a2Poi = MNGAImages(name: "a2|poi")
  public static let a2Yes = MNGAImages(name: "a2|yes")
  public static let a2不明觉厉 = MNGAImages(name: "a2|不明觉厉")
  public static let a2不活了 = MNGAImages(name: "a2|不活了")
  public static let a2中枪 = MNGAImages(name: "a2|中枪")
  public static let a2你为猴这么 = MNGAImages(name: "a2|你为猴这么")
  public static let a2你已经死了 = MNGAImages(name: "a2|你已经死了")
  public static let a2你看看你 = MNGAImages(name: "a2|你看看你")
  public static let a2你这种人 = MNGAImages(name: "a2|你这种人…")
  public static let a2偷吃 = MNGAImages(name: "a2|偷吃")
  public static let a2偷笑 = MNGAImages(name: "a2|偷笑")
  public static let a2冷 = MNGAImages(name: "a2|冷")
  public static let a2冷笑 = MNGAImages(name: "a2|冷笑")
  public static let a2哦嗬嗬嗬 = MNGAImages(name: "a2|哦嗬嗬嗬")
  public static let a2哭 = MNGAImages(name: "a2|哭")
  public static let a2囧 = MNGAImages(name: "a2|囧")
  public static let a2囧2 = MNGAImages(name: "a2|囧2")
  public static let a2壁咚 = MNGAImages(name: "a2|壁咚")
  public static let a2大哭 = MNGAImages(name: "a2|大哭")
  public static let a2妮可妮可妮 = MNGAImages(name: "a2|妮可妮可妮")
  public static let a2威吓 = MNGAImages(name: "a2|威吓")
  public static let a2干杯 = MNGAImages(name: "a2|干杯")
  public static let a2干杯2 = MNGAImages(name: "a2|干杯2")
  public static let a2异议 = MNGAImages(name: "a2|异议")
  public static let a2怒 = MNGAImages(name: "a2|怒")
  public static let a2恨 = MNGAImages(name: "a2|恨")
  public static let a2惊 = MNGAImages(name: "a2|惊")
  public static let a2抢镜头 = MNGAImages(name: "a2|抢镜头")
  public static let a2是在下输了 = MNGAImages(name: "a2|是在下输了")
  public static let a2有何贵干 = MNGAImages(name: "a2|有何贵干")
  public static let a2病娇 = MNGAImages(name: "a2|病娇")
  public static let a2笑 = MNGAImages(name: "a2|笑")
  public static let a2自戳双目 = MNGAImages(name: "a2|自戳双目")
  public static let a2舔 = MNGAImages(name: "a2|舔")
  public static let a2认真 = MNGAImages(name: "a2|认真")
  public static let a2诶嘿 = MNGAImages(name: "a2|诶嘿")
  public static let a2那个 = MNGAImages(name: "a2|那个…")
  public static let a2鬼脸 = MNGAImages(name: "a2|鬼脸")
  public static let acBlink = MNGAImages(name: "ac|blink")
  public static let acGoodjob = MNGAImages(name: "ac|goodjob")
  public static let ac上 = MNGAImages(name: "ac|上")
  public static let ac中枪 = MNGAImages(name: "ac|中枪")
  public static let ac偷笑 = MNGAImages(name: "ac|偷笑")
  public static let ac冷 = MNGAImages(name: "ac|冷")
  public static let ac凌乱 = MNGAImages(name: "ac|凌乱")
  public static let ac反对 = MNGAImages(name: "ac|反对")
  public static let ac吓 = MNGAImages(name: "ac|吓")
  public static let ac吻 = MNGAImages(name: "ac|吻")
  public static let ac呆 = MNGAImages(name: "ac|呆")
  public static let ac咦 = MNGAImages(name: "ac|咦")
  public static let ac哦 = MNGAImages(name: "ac|哦")
  public static let ac哭 = MNGAImages(name: "ac|哭")
  public static let ac哭1 = MNGAImages(name: "ac|哭1")
  public static let ac哭笑 = MNGAImages(name: "ac|哭笑")
  public static let ac哼 = MNGAImages(name: "ac|哼")
  public static let ac喘 = MNGAImages(name: "ac|喘")
  public static let ac喷 = MNGAImages(name: "ac|喷")
  public static let ac嘲笑 = MNGAImages(name: "ac|嘲笑")
  public static let ac嘲笑1 = MNGAImages(name: "ac|嘲笑1")
  public static let ac囧 = MNGAImages(name: "ac|囧")
  public static let ac委屈 = MNGAImages(name: "ac|委屈")
  public static let ac心 = MNGAImages(name: "ac|心")
  public static let ac忧伤 = MNGAImages(name: "ac|忧伤")
  public static let ac怒 = MNGAImages(name: "ac|怒")
  public static let ac怕 = MNGAImages(name: "ac|怕")
  public static let ac惊 = MNGAImages(name: "ac|惊")
  public static let ac愁 = MNGAImages(name: "ac|愁")
  public static let ac抓狂 = MNGAImages(name: "ac|抓狂")
  public static let ac抠鼻 = MNGAImages(name: "ac|抠鼻")
  public static let ac擦汗 = MNGAImages(name: "ac|擦汗")
  public static let ac无语 = MNGAImages(name: "ac|无语")
  public static let ac晕 = MNGAImages(name: "ac|晕")
  public static let ac汗 = MNGAImages(name: "ac|汗")
  public static let ac瞎 = MNGAImages(name: "ac|瞎")
  public static let ac羞 = MNGAImages(name: "ac|羞")
  public static let ac羡慕 = MNGAImages(name: "ac|羡慕")
  public static let ac花痴 = MNGAImages(name: "ac|花痴")
  public static let ac茶 = MNGAImages(name: "ac|茶")
  public static let ac衰 = MNGAImages(name: "ac|衰")
  public static let ac计划通 = MNGAImages(name: "ac|计划通")
  public static let ac赞同 = MNGAImages(name: "ac|赞同")
  public static let ac闪光 = MNGAImages(name: "ac|闪光")
  public static let ac黑枪 = MNGAImages(name: "ac|黑枪")
  public static let dtROLL = MNGAImages(name: "dt|ROLL")
  public static let dt上 = MNGAImages(name: "dt|上")
  public static let dt傲娇 = MNGAImages(name: "dt|傲娇")
  public static let dt叉出去 = MNGAImages(name: "dt|叉出去")
  public static let dt发光 = MNGAImages(name: "dt|发光")
  public static let dt呵欠 = MNGAImages(name: "dt|呵欠")
  public static let dt哭 = MNGAImages(name: "dt|哭")
  public static let dt啃古头 = MNGAImages(name: "dt|啃古头")
  public static let dt嘲笑 = MNGAImages(name: "dt|嘲笑")
  public static let dt心 = MNGAImages(name: "dt|心")
  public static let dt怒 = MNGAImages(name: "dt|怒")
  public static let dt怒2 = MNGAImages(name: "dt|怒2")
  public static let dt怨 = MNGAImages(name: "dt|怨")
  public static let dt惊 = MNGAImages(name: "dt|惊")
  public static let dt惊2 = MNGAImages(name: "dt|惊2")
  public static let dt无语 = MNGAImages(name: "dt|无语")
  public static let dt星星眼 = MNGAImages(name: "dt|星星眼")
  public static let dt星星眼2 = MNGAImages(name: "dt|星星眼2")
  public static let dt晕 = MNGAImages(name: "dt|晕")
  public static let dt注意 = MNGAImages(name: "dt|注意")
  public static let dt注意2 = MNGAImages(name: "dt|注意2")
  public static let dt泪 = MNGAImages(name: "dt|泪")
  public static let dt泪2 = MNGAImages(name: "dt|泪2")
  public static let dt烧 = MNGAImages(name: "dt|烧")
  public static let dt笑 = MNGAImages(name: "dt|笑")
  public static let dt笑2 = MNGAImages(name: "dt|笑2")
  public static let dt笑3 = MNGAImages(name: "dt|笑3")
  public static let dt脸红 = MNGAImages(name: "dt|脸红")
  public static let dt药 = MNGAImages(name: "dt|药")
  public static let dt衰 = MNGAImages(name: "dt|衰")
  public static let dt鄙视 = MNGAImages(name: "dt|鄙视")
  public static let dt闲 = MNGAImages(name: "dt|闲")
  public static let dt黑脸 = MNGAImages(name: "dt|黑脸")
  public static let pg严肃 = MNGAImages(name: "pg|严肃")
  public static let pg冻 = MNGAImages(name: "pg|冻")
  public static let pg吃瓜 = MNGAImages(name: "pg|吃瓜")
  public static let pg哈啤 = MNGAImages(name: "pg|哈啤")
  public static let pg响指 = MNGAImages(name: "pg|响指")
  public static let pg哭 = MNGAImages(name: "pg|哭")
  public static let pg嘣 = MNGAImages(name: "pg|嘣")
  public static let pg嘣2 = MNGAImages(name: "pg|嘣2")
  public static let pg心 = MNGAImages(name: "pg|心")
  public static let pg战斗力 = MNGAImages(name: "pg|战斗力")
  public static let pg拒绝 = MNGAImages(name: "pg|拒绝")
  public static let pg满分 = MNGAImages(name: "pg|满分")
  public static let pg衰 = MNGAImages(name: "pg|衰")
  public static let pg谢 = MNGAImages(name: "pg|谢")
  public static let pg转身 = MNGAImages(name: "pg|转身")
  public static let pst举手 = MNGAImages(name: "pst|举手")
  public static let pst亲 = MNGAImages(name: "pst|亲")
  public static let pst偷笑 = MNGAImages(name: "pst|偷笑")
  public static let pst偷笑2 = MNGAImages(name: "pst|偷笑2")
  public static let pst偷笑3 = MNGAImages(name: "pst|偷笑3")
  public static let pst傻眼 = MNGAImages(name: "pst|傻眼")
  public static let pst傻眼2 = MNGAImages(name: "pst|傻眼2")
  public static let pst兔子 = MNGAImages(name: "pst|兔子")
  public static let pst发光 = MNGAImages(name: "pst|发光")
  public static let pst呆 = MNGAImages(name: "pst|呆")
  public static let pst呆2 = MNGAImages(name: "pst|呆2")
  public static let pst呆3 = MNGAImages(name: "pst|呆3")
  public static let pst呕 = MNGAImages(name: "pst|呕")
  public static let pst呵欠 = MNGAImages(name: "pst|呵欠")
  public static let pst哭 = MNGAImages(name: "pst|哭")
  public static let pst哭2 = MNGAImages(name: "pst|哭2")
  public static let pst哭3 = MNGAImages(name: "pst|哭3")
  public static let pst嘲笑 = MNGAImages(name: "pst|嘲笑")
  public static let pst基 = MNGAImages(name: "pst|基")
  public static let pst宅 = MNGAImages(name: "pst|宅")
  public static let pst安慰 = MNGAImages(name: "pst|安慰")
  public static let pst幸福 = MNGAImages(name: "pst|幸福")
  public static let pst开心 = MNGAImages(name: "pst|开心")
  public static let pst开心2 = MNGAImages(name: "pst|开心2")
  public static let pst开心3 = MNGAImages(name: "pst|开心3")
  public static let pst怀疑 = MNGAImages(name: "pst|怀疑")
  public static let pst怒 = MNGAImages(name: "pst|怒")
  public static let pst怒2 = MNGAImages(name: "pst|怒2")
  public static let pst怨 = MNGAImages(name: "pst|怨")
  public static let pst惊吓 = MNGAImages(name: "pst|惊吓")
  public static let pst惊吓2 = MNGAImages(name: "pst|惊吓2")
  public static let pst惊呆 = MNGAImages(name: "pst|惊呆")
  public static let pst惊呆2 = MNGAImages(name: "pst|惊呆2")
  public static let pst惊呆3 = MNGAImages(name: "pst|惊呆3")
  public static let pst惨 = MNGAImages(name: "pst|惨")
  public static let pst斜眼 = MNGAImages(name: "pst|斜眼")
  public static let pst星星眼 = MNGAImages(name: "pst|星星眼")
  public static let pst晕 = MNGAImages(name: "pst|晕")
  public static let pst汗 = MNGAImages(name: "pst|汗")
  public static let pst泪 = MNGAImages(name: "pst|泪")
  public static let pst泪2 = MNGAImages(name: "pst|泪2")
  public static let pst泪3 = MNGAImages(name: "pst|泪3")
  public static let pst泪4 = MNGAImages(name: "pst|泪4")
  public static let pst满足 = MNGAImages(name: "pst|满足")
  public static let pst满足2 = MNGAImages(name: "pst|满足2")
  public static let pst火星 = MNGAImages(name: "pst|火星")
  public static let pst牙疼 = MNGAImages(name: "pst|牙疼")
  public static let pst电击 = MNGAImages(name: "pst|电击")
  public static let pst看戏 = MNGAImages(name: "pst|看戏")
  public static let pst眼袋 = MNGAImages(name: "pst|眼袋")
  public static let pst眼镜 = MNGAImages(name: "pst|眼镜")
  public static let pst笑而不语 = MNGAImages(name: "pst|笑而不语")
  public static let pst紧张 = MNGAImages(name: "pst|紧张")
  public static let pst美味 = MNGAImages(name: "pst|美味")
  public static let pst背 = MNGAImages(name: "pst|背")
  public static let pst脸红 = MNGAImages(name: "pst|脸红")
  public static let pst脸红2 = MNGAImages(name: "pst|脸红2")
  public static let pst腐 = MNGAImages(name: "pst|腐")
  public static let pst谢 = MNGAImages(name: "pst|谢")
  public static let pst醉 = MNGAImages(name: "pst|醉")
  public static let pst闷 = MNGAImages(name: "pst|闷")
  public static let pst闷2 = MNGAImages(name: "pst|闷2")
  public static let pst音乐 = MNGAImages(name: "pst|音乐")
  public static let pst黑脸 = MNGAImages(name: "pst|黑脸")
  public static let pst鼻血 = MNGAImages(name: "pst|鼻血")
  public static let defaultForumIcon = MNGAImages(name: "default_forum_icon")
}

// MARK: - Implementation Details

public final class MNGAColors: Sendable {
  public let name: String

  #if os(macOS)
  public typealias Color = NSColor
  #elseif os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
  public typealias Color = UIColor
  #endif

  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, visionOS 1.0, *)
  public var color: Color {
    guard let color = Color(asset: self) else {
      fatalError("Unable to load color asset named \(name).")
    }
    return color
  }

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, visionOS 1.0, *)
  public var swiftUIColor: SwiftUI.Color {
      return SwiftUI.Color(asset: self)
  }
  #endif

  fileprivate init(name: String) {
    self.name = name
  }
}

public extension MNGAColors.Color {
  @available(iOS 11.0, tvOS 11.0, watchOS 4.0, macOS 10.13, visionOS 1.0, *)
  convenience init?(asset: MNGAColors) {
    let bundle = Bundle.module
    #if os(iOS) || os(tvOS) || os(visionOS)
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    self.init(named: NSColor.Name(asset.name), bundle: bundle)
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, visionOS 1.0, *)
public extension SwiftUI.Color {
  init(asset: MNGAColors) {
    let bundle = Bundle.module
    self.init(asset.name, bundle: bundle)
  }
}
#endif

public struct MNGAImages: Sendable {
  public let name: String

  #if os(macOS)
  public typealias Image = NSImage
  #elseif os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
  public typealias Image = UIImage
  #endif

  public var image: Image {
    let bundle = Bundle.module
    #if os(iOS) || os(tvOS) || os(visionOS)
    let image = Image(named: name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    let image = bundle.image(forResource: NSImage.Name(name))
    #elseif os(watchOS)
    let image = Image(named: name)
    #endif
    guard let result = image else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, visionOS 1.0, *)
  public var swiftUIImage: SwiftUI.Image {
    SwiftUI.Image(asset: self)
  }
  #endif
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, visionOS 1.0, *)
public extension SwiftUI.Image {
  init(asset: MNGAImages) {
    let bundle = Bundle.module
    self.init(asset.name, bundle: bundle)
  }

  init(asset: MNGAImages, label: Text) {
    let bundle = Bundle.module
    self.init(asset.name, bundle: bundle, label: label)
  }

  init(decorative asset: MNGAImages) {
    let bundle = Bundle.module
    self.init(decorative: asset.name, bundle: bundle)
  }
}
#endif

// swiftformat:enable all
// swiftlint:enable all
