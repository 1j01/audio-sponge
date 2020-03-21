async = require "async"
SC = require "node-soundcloud"
shuffle = require "../shuffle"

module.exports.init = (options)-> SC.init(options)

module.exports.search = (query, track_callback, done_callback)->
	console.log "[SC] Searching SoundCloud for \"#{query}\""
	SC.get "/tracks", {q: query}, (err, tracks)=>
		if err
			console.error "[SC] Error searching for tracks:", err if err
			done_callback()
			return
		tracks = tracks.filter((track)-> track.streamable)

		console.log "[SC] Found #{tracks.length} tracks"

		async.eachLimit shuffle(tracks), 2,
			(track, callback)=>
				# NOTE: MUST not call callback herein syncronously!
				# An error in the callback would be caught by `async` and lead to confusion.
				attribution = {
					link: track.permalink_url
					name: track.title
					author: {
						name: track.user.username
						link: track.user.permalink_url
					}
					provider: "soundcloud"
				}
				console.log "[SC] process.nextTick then track_callback"
				process.nextTick => # avoid synchronous callback!
					console.log "[SC] track_callback"
					track_callback(track.stream_url, attribution)
					setTimeout =>
						callback null
					, 500 # TODO: does this actually help?
			(err)=>
				# FIXME: catches errors within track_callback
				console.error "[SC] Error:", err if err
				done_callback() # regardless of error
