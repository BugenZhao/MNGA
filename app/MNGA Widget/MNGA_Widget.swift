//
//  MNGA_Widget.swift
//  MNGA Widget
//
//  Created by Bugen Zhao on 2021/10/6.
//

import Intents
import SDWebImageSwiftUI
import SwiftUI
import WidgetKit

struct Provider: IntentTimelineProvider {
  func placeholder(in _: Context) -> HotTopicsEntry {
    .placeholder
  }

  func getSnapshot(for configuration: ConfigurationIntent, in context: Context, completion: @escaping (HotTopicsEntry) -> Void) {
    getTimeline(for: configuration, in: context) { timeline in
      let entry = timeline.entries.first ?? .placeholder
      completion(entry)
    }
  }

  func getTimeline(for configuration: ConfigurationIntent, in _: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    logicInitialConfigure()

    let forum = configuration.forum ?? HotTopicsEntry.placeholder.forum.widgetForum
    let request = HotTopicListRequest.with {
      if let id = forum.fid, !id.isEmpty { $0.id.fid = id }
      if let id = forum.stid, !id.isEmpty { $0.id.stid = id }
      $0.range = .day
    }

    basicLogicCallAsync(.hotTopicList(request)) { (response: HotTopicListResponse) in
      SDWebImageManager.shared.loadImage(with: URL(string: response.forum.iconURL), options: .init(), progress: nil) { image, _, _, _, _, _ in
        let entry = HotTopicsEntry(date: Date(), forum: response.forum, topics: response.topics, error: nil, image: image)
        completion(.init(entries: [entry], policy: .after(Date() + 3600)))
      }
    } onError: { e in
      let entry = HotTopicsEntry(date: Date(), forum: .init(), topics: [], error: e.errorDescription, image: nil)
      completion(.init(entries: [entry], policy: .after(Date() + 900)))
    }
  }
}

struct HotTopicsEntry: TimelineEntry {
  let date: Date
  let forum: Forum
  let topics: [Topic]
  let error: String?
  let image: PlatformImage?

  static var placeholder: HotTopicsEntry {
    let topic = Topic.with {
      $0.subject.content = "感觉女友家庭有一个封建习惯。感觉女友家庭有一个封建习惯。感觉女友家庭有一个封建习惯。"
      $0.repliesNum = 2333
    }
    let forum = Forum.with {
      $0.name = "晴风村"
      $0.id.fid = "-7955747"
      $0.iconURL = "https://img4.ngacn.cc/ngabbs/nga_classic/f/app/-7955747.png"
    }
    return .init(date: Date(), forum: forum, topics: .init(repeating: topic, count: 5), error: nil, image: nil)
  }
}

struct MNGA_WidgetEntryView: View {
  let entry: Provider.Entry

  var body: some View {
    if let error = entry.error {
      Text(error)
    } else {
      HotTopicsView(
        time: entry.date,
        forum: entry.forum,
        topics: entry.topics,
        image: entry.image
      )
    }
  }
}

@main
struct MNGA_Widget: Widget {
  let kind: String = "MNGA_Widget"

  var body: some WidgetConfiguration {
    IntentConfiguration(kind: kind, intent: ConfigurationIntent.self, provider: Provider()) { entry in
      MNGA_WidgetEntryView(entry: entry)
    }
    .configurationDisplayName("My Widget")
    .description("This is an example widget.")
  }
}

struct MNGA_Widget_Previews: PreviewProvider {
  static var previews: some View {
    MNGA_WidgetEntryView(entry: .placeholder)
      .previewContext(WidgetPreviewContext(family: .systemMedium))
    MNGA_WidgetEntryView(entry: .placeholder)
      .preferredColorScheme(.dark)
      .previewContext(WidgetPreviewContext(family: .systemMedium))
  }
}

extension Forum {
  var widgetForum: WidgetForum {
    let wf = WidgetForum(
      identifier: idDescription,
      display: name,
      subtitle: info,
      image: nil
    )
    wf.fid = id.fid
    wf.stid = id.stid
    wf.iconURL = iconURL
    return wf
  }
}
