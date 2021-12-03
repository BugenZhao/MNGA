//
//  IntentHandler.swift
//  Widget Intents
//
//  Created by Bugen Zhao on 2021/10/6.
//

import Intents

class IntentHandler: INExtension, ConfigurationIntentHandling {
  var groupStore: UserDefaults {
    UserDefaults(suiteName: Constants.Key.groupStore)!
  }

  func provideForumOptionsCollection(for _: ConfigurationIntent, with completion: @escaping (INObjectCollection<WidgetForum>?, Error?) -> Void) {
    let forums = [Forum](readFrom: groupStore, forKey: Constants.Key.favoriteForums) ?? []
    let items = forums.map(\.widgetForum)
    completion(INObjectCollection(items: items), nil)
  }

  override func handler(for _: INIntent) -> Any {
    self
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
