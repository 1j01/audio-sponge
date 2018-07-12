async = require "async"
SC = require "node-soundcloud"
shuffle = require "../shuffle"

# TODO: maybe have init method that just wraps SC.init?
# which is better, having an extra wrapper, or sharing global state thru node-soundcloud?
# or are we sharing state either way? this would still use the global state..
# but you'd be able to consider it this module's global state, as an abstraction
# yeah, I think that's why having a wrapper would be better

module.exports = (query, track_callback, done_callback)->
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
				attribution = {
					link: track.permalink_url
					name: track.title
					author: {
						name: track.user.username
						link: track.user.permalink_url
					}
				}
				# FIXME: callback within (implicitly) try-caught block (by `async`)
				track_callback(track.stream_url, attribution)
				setTimeout =>
					callback null
				, 500 # TODO: does this actually help?
			(err)=>
				# FIXME: catches errors within track_callback
				console.error "[SC] Error:", err if err
				done_callback() # regardless of error
