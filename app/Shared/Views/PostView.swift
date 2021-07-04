//
//  PostView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI

struct PostVoteView: View {
  enum VoteState {
    case up, none, down
  }

  let post: Post

  @State var delta: Int32 = 0
  @State var state = VoteState.none

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: state == .up ? "hand.thumbsup.fill" : "hand.thumbsup")
        .foregroundColor(state == .up ? .accentColor : .secondary)
        .frame(height: 24)
        .onTapGesture { vote(.upvote) }

      Text("\(max(Int32(post.score) + delta, 0))")
        .foregroundColor(state != .none ? .accentColor : .secondary)
        .font(.subheadline.monospacedDigit())

      Image(systemName: state == .down ? "hand.thumbsdown.fill" : "hand.thumbsdown")
        .foregroundColor(state == .down ? .accentColor : .secondary)
        .frame(height: 24)
        .onTapGesture { vote(.downvote) }
    }
  }

  func vote(_ operation: PostVoteRequest.Operation) {
    logicCallAsync(.postVote(.with {
      $0.postID = post.id
      $0.operation = operation
    })) { (response: PostVoteResponse) in
      withAnimation {
        if operation == .upvote {
          self.state = response.delta > 0 ? .up : .none
        } else {
          self.state = response.delta < 0 ? .down : .none
        }
        self.delta += response.delta
      }
    }
  }
}

struct PostView: View {
  let post: Post
  let user: User?

  @State var liked: Int32 = 0

  init(post: Post) {
    self.post = post
    self.user = try! (logicCall(.localUser(.with { $0.userID = post.authorID })) as LocalUserResponse).user
  }

  @ViewBuilder
  var header: some View {
    HStack {
      avatar
        .foregroundColor(.accentColor)
        .frame(width: 36, height: 36)
        .clipShape(Circle())

      VStack(alignment: .leading, spacing: 2) {
        Text(user?.name ?? post.authorID)
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

      (Text("#").font(.footnote) + Text("\(post.floor)").font(.callout))
        .fontWeight(.medium)
        .foregroundColor(.accentColor)
    }
  }

  @ViewBuilder
  var footer: some View {
    HStack {
      PostVoteView(post: post)

      Spacer()

      Text(timeago(post.postDate))
        .foregroundColor(.secondary)
        .font(.footnote)
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      header
      PostContentView(spans: post.content.spans)
      footer
    } .padding(.vertical, 4)
      .contextMenu {
      Button(action: { copyContent(post.content.raw) }) {
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
