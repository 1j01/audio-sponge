async = require "async"
searchYoutube = require "youtube-api-v3-search"
getYoutubeSubtitles = require "@joegesualdo/get-youtube-subtitles-node"
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

youtube_api_key = null
module.exports.init = (options)->
	youtube_api_key = options.key

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
	searchYoutube(youtube_api_key, params)
	.then(
		(data)=>
			console.log data
			items = data.items.filter((searchResult)-> searchResult.snippet.liveBroadcastContent is "none")
			{items} = data

			console.log "[YT] Found #{items.length} videos"

			async.eachLimit shuffle(items), 2,
				(item, callback)=>
					console.log item
					# NOTE: MUST not call callback herein syncronously!
					# An error in the callback would be caught by `async` and lead to confusion.
					attribution = {
						link: "https://www.youtube.com/watch?v=#{item.id.videoId}"
						name: item.snippet.title
						author: {
							name: item.snippet.channelTitle
							link: "https://www.youtube.com/channel/#{item.snippet.channelId}"
						}
						provider: "youtube"
					}
					console.log "getYoutubeSubtitles"
					# TODO: type: "either" (not implemented by this module)
					getYoutubeSubtitles(item.id.videoId, {type: 'nonauto'})
					.then(
						(subtitles)=>
							console.log("[YT] Got subtitles:", subtitles)
							track_callback("https://stream-youtube-video/#{item.id.videoId}", attribution)
							setTimeout =>
								callback null
							, 500 # TODO: does this actually help?
						(err)=>
							console.log "[YT] Failed to get subtitles:", err
							callback(err)
					)
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