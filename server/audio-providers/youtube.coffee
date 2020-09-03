async = require "async"
YoutubeSearch = require "youtube-api-search-reloaded"
shuffle = require "../shuffle"

# {
# 	part,
# 	key,
# 	term,
# 	type,
# 	forContentOwner,
# 	forDeveloper,
# 	forMine,
# 	relatedToVideoId,
# 	channelId,
# 	channelType,
# 	eventType,
# 	location,
# 	locationRadius,
# 	maxResults,
# 	onBehalfOfContentOwner,
# 	order,
# 	pageToken,
# 	publishedAfter,
# 	regionCode,
# 	relevanceLanguage,
# 	safeSearch,
# 	topicId,
# 	videoCaption,
# 	videoCategoryId,
# 	videoDefinition,
# 	videoDimension,
# 	videoDuration,
# 	videoEmbeddable,
# 	videoLicense,
# 	videoSyndicated,
# 	videoType
# }

module.exports.init = (options)->

module.exports.search = (query, track_callback, done_callback)->
	console.log "[YT] Searching YouTube for \"#{query}\""
	params = {
		part: "snippet"
		type: "video"
		order: "date"
		# publishedAfter: ""
		videoCaption: "closedCaption"
		safeSearch: "moderate"
		videoDuration: "short"
		# videoLicense: "creativeCommon"
		videoSyndicated: "true"
		q: query
	}
	YoutubeSearch(params)
	.then(
		(tracks)=>
			tracks = tracks.filter((track)-> track.streamable)

			console.log "[YT] Found #{tracks.length} tracks"

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
						provider: "youtube"
					}
					console.log "[YT] process.nextTick then track_callback"
					process.nextTick => # avoid synchronous callback!
						console.log "[YT] track_callback"
						track_callback(track.stream_url, attribution)
						setTimeout =>
							callback null
						, 500 # TODO: does this actually help?
				(err)=>
					# FIXME: catches errors within track_callback
					console.error "[YT] Error:", err if err
					done_callback() # regardless of error
		(err)=>
			if err
				console.error "[YT] Error searching for tracks:", err if err
				done_callback()
				return
	)