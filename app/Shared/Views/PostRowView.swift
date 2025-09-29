//
//  PostRowView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI
import SwiftUIX

struct PostRowView: View {
  let post: Post
  let isAuthor: Bool

  @Binding var vote: VotesModel.Vote

  @EnvironmentObject<TopicDetailsActionModel>.Optional var action
  @EnvironmentObject<PostReplyModel>.Optional var postReply
  @EnvironmentObject var textSelection: TextSelectionModel
  @Environment(\.enableAuthorOnly) var enableAuthorOnly

  @StateObject var authStorage = AuthStorage.shared
  @StateObject var pref = PreferencesStorage.shared
  @StateObject var users = UsersModel.shared
  @StateObject var attachments: AttachmentsModel

  @State var showAttachments = false

  static func build(post: Post, isAuthor: Bool = false, vote: Binding<VotesModel.Vote>) -> Self {
    let attachments = AttachmentsModel(post.attachments)
    return .init(post: post, isAuthor: isAuthor, vote: vote, attachments: attachments)
  }

  private var user: User? {
    users.localUser(id: post.authorID)
  }

  var mock: Bool {
    post.id.tid.isMNGAMockID
  }

  var dummy: Bool {
    post.id == .dummy
  }

  @ViewBuilder
  var floor: some View {
    if post.floor != 0 {
      (Text("#").font(.footnote) + Text("\(post.floor)").font(.callout))
        .fontWeight(.medium)
        .foregroundColor(.accentColor)
    }
  }

  @ViewBuilder
  var menuButton: some View {
    #if os(iOS)
      Menu(content: { menu }) {
        Image(systemName: "ellipsis.circle.fill")
          .symbolRenderingMode(.hierarchical)
          .imageScale(.large)
          .glassEffect()
      }
    #endif
  }

  @ViewBuilder
  var header: some View {
    HStack {
      PostRowUserView(post: post, compact: false, isAuthor: isAuthor)
      Spacer()
      floor
      if !dummy { menuButton }
    }
  }

  @ViewBuilder
  var footer: some View {
    HStack {
      voter
      Spacer()
      Group {
        if !post.alterInfo.isEmpty {
          Image(systemName: "pencil")
        }
        DateTimeTextView.build(timestamp: post.postDate)
          .id(pref.postRowDateTimeStrategy)
        Image(systemName: post.device.icon)
          .frame(width: 10)
      }.foregroundColor(.secondary)
        .font(.footnote)
    }
  }

  @ViewBuilder
  var comments: some View {
    if !post.comments.isEmpty {
      Divider()
      HStack {
        Spacer().frame(width: 6, height: 1)
        VStack {
          ForEach(post.comments, id: \.hashValue) { comment in
            PostCommentRowView(comment: comment)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
  }

  @ViewBuilder
  var voter: some View {
    HStack(spacing: 4) {
      Button(action: { doVote(.upvote) }) {
        Image(systemName: vote.state == .up ? "hand.thumbsup.fill" : "hand.thumbsup")
          .foregroundColor(vote.state == .up ? .accentColor : .secondary)
          .frame(height: 24)
      }.buttonStyle(PlainButtonStyle())

      let font = Font.subheadline.monospacedDigit()
      Text("\(max(Int32(post.score) + vote.delta, 0))")
        .foregroundColor(vote.state == .up ? .accentColor : .secondary)
        .font(vote.state == .up ? font.bold() : font)

      Button(action: { doVote(.downvote) }) {
        Image(systemName: vote.state == .down ? "hand.thumbsdown.fill" : "hand.thumbsdown")
          .foregroundColor(vote.state == .down ? .accentColor : .secondary)
          .frame(height: 24)
      }.buttonStyle(PlainButtonStyle())
    }
  }

  @ViewBuilder
  var signature: some View {
    if pref.showSignature, let sig = user?.signature, !sig.spans.isEmpty {
      Divider()
      UserSignatureView(content: sig, font: .subheadline, color: .secondary)
    }
  }

  @ViewBuilder
  var content: some View {
    BlockedView(content: BlockWordsStorage.content(user: user?.name ?? .init(), content: post.content.raw), revealOnTap: true) {
      PostContentView(content: post.content, id: post.id, postDate: post.postDate)
    }
  }

  @ViewBuilder
  var menu: some View {
    if let model = postReply, !mock, !dummy {
      ControlGroup {
        Button(action: { doQuote(model: model) }) {
          Label("Quote", systemImage: "quote.bubble")
        }
        Button(action: { doComment(model: model) }) {
          Label("Comment", systemImage: "tag")
        }
        if authStorage.authInfo.uid == post.authorID {
          Button(action: { doEdit(model: model) }) {
            Label("Edit", systemImage: "pencil")
          }
        } else {
          // Why reporting myself?
          Button(role: .destructive, action: { doReport(model: model) }) {
            Label("Report", systemImage: "exclamationmark.bubble")
          }
        }
      }
    }
    Section {
      Button(action: { textSelection.text = post.content.raw.replacingOccurrences(of: "<br/>", with: "\n") }) {
        Label("Select Text", systemImage: "selection.pin.in.out")
      }
      if !attachments.items.isEmpty {
        Button(action: { showAttachments = true }) {
          Label("Attachments (\(attachments.items.count))", systemImage: "paperclip")
        }
      }
    }
    if let action {
      Section {
        if enableAuthorOnly, !(user?.isAnonymous ?? false) {
          Button(action: { withPlusCheck(.authorOnly) { action.navigateToAuthorOnly = post.authorID } }) {
            Label("This Author Only", systemImage: "person")
          }
        }
      }
    }
  }

  var body: some View {
    let body = VStack(alignment: .leading, spacing: 10) {
      header
      content
      footer
      comments
      signature
    }.padding(.vertical, 2)
      .fixedSize(horizontal: false, vertical: true)
      .contextMenu { menu }
    #if os(iOS)
      .listRowBackground(action?.scrollToPid == post.id.pid ? Color.tertiarySystemBackground : nil)
    #endif
      .sheet(isPresented: $showAttachments) { NavigationView { AttachmentsView(model: attachments, isPresented: $showAttachments) }.presentationDetents([.medium, .large]) }
      .environmentObject(attachments)

    if let model = postReply, !mock {
      body
        .swipeActions(edge: pref.postRowSwipeActionLeading ? .leading : .trailing) {
          Button(action: { doQuote(model: model) }) {
            Label("Quote", systemImage: "quote.bubble")
          }.tint(.accentColor)
        }
    } else {
      body
    }
  }

  func doVote(_ operation: PostVoteRequest.Operation) {
    if mock || dummy {
      #if os(iOS)
        HapticUtils.play(type: .warning)
      #endif
      return
    }

    logicCallAsync(.postVote(.with {
      $0.postID = post.id
      $0.operation = operation
    })) { (response: PostVoteResponse) in
      if !response.hasError {
        withAnimation {
          vote.state = response.state
          vote.delta += response.delta
          #if os(iOS)
            if vote.state != .none {
              HapticUtils.play(style: .light)
            }
          #endif
        }
      } else {
        // not used
      }
    }
  }

  func doQuote(model: PostReplyModel) {
    if dummy { return }

    model.show(action: .with {
      $0.postID = post.id
      $0.forumID = .with { f in
        f.fid = post.fid
      }
      $0.operation = .quote
    }, pageToReload: .last)
  }

  func doComment(model: PostReplyModel) {
    model.show(action: .with {
      $0.postID = post.id
      $0.forumID = .with { f in
        f.fid = post.fid
      }
      $0.operation = .comment
    }, pageToReload: .exact(Int(post.atPage)))
  }

  func doEdit(model: PostReplyModel) {
    model.show(action: .with {
      $0.postID = post.id
      $0.forumID = .with { f in
        f.fid = post.fid
      }
      $0.operation = .modify
    }, pageToReload: .exact(Int(post.atPage)))
  }

  func doReport(model: PostReplyModel) {
    model.show(action: .with {
      $0.postID = post.id
      $0.operation = .report
    })
  }
}
