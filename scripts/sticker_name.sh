ls app/Shared/Assets.xcassets/Stickers | grep imageset | sed -E 's/^(.*)\.imageset$/"\1",/g'
