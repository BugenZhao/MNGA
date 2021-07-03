//
//  ReplyView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI

struct ReplyView: View {
  let reply: Reply
  let user: User?

  @State var liked = false

  init(reply: Reply) {
    self.reply = reply
    self.user = try! (logicCall(.localUser(.with { $0.userID = reply.authorID })) as LocalUserResponse).user
  }

  @ViewBuilder
  var header: some View {
    HStack {
      avatar
        .foregroundColor(.accentColor)
        .frame(width: 36, height: 36)
        .clipShape(Circle())

      VStack(alignment: .leading, spacing: 2) {
        Text(user?.name ?? reply.authorID)
          .font(.subheadline)

        if let user = self.user {
          HStack(spacing: 2) {
            Image(systemName: "text.bubble")
            Text("\(user.postNum)")

            Spacer().frame(width: 4)
            
            Image(systemName: "calendar")
            Text(Date(timeIntervalSince1970: TimeInterval(user.regDate)), style: .date)
          } .font(.footnote)
            .foregroundColor(.secondary)
        }
      }

      Spacer()

      (Text("#").font(.footnote) + Text("\(reply.floor)").font(.callout))
        .fontWeight(.medium)
        .foregroundColor(.accentColor)
    }
  }

  @ViewBuilder
  var footer: some View {
    HStack(spacing: 4) {
      Group {
        Image(systemName: liked ? "hand.thumbsup.fill" : "hand.thumbsup")
          .foregroundColor(liked ? .accentColor : .secondary)
          .frame(height: 24)


        Text("\(reply.score + (liked ? 1 : 0))")
          .foregroundColor(liked ? .accentColor : .secondary)
          .font(.subheadline)
      } .onTapGesture { withAnimation { self.liked.toggle() } }
      
      Spacer()
      
      Text(timeago(reply.postDate))
        .foregroundColor(.secondary)
        .font(.footnote)
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      header
      ReplyContentView(spans: reply.content.spans)
      footer
    } .padding(.vertical, 4)
      .contextMenu {
      Button(action: { copyContent(reply.content.raw) }) {
        Label("Copy Raw Content", systemImage: "doc.on.doc")
      }
    }
  }

  @ViewBuilder
  var avatar: some View {
    let placeholder = Image(systemName: "person.circle.fill")
      .resizable()

    if let url = URL(string: user?.avatarURL ?? "") {
      WebImage(url: url)
        .resizable()
        .placeholder(placeholder)
    } else {
      placeholder
    }
  }

  func copyContent(_ content: String) {
    #if os(iOS)
      UIPasteboard.general.string = content
    #elseif os(macOS)
      let pb = NSPasteboard.general
      pb.clearContents()
      pb.writeObjects([content as NSString])
    #endif
  }
}
