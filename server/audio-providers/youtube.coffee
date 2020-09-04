async = require "async"
search_youtube = require "youtube-api-v3-search"
youtube_dl_path = require("youtube-dl-ffmpeg-ffprobe-static").path
YoutubeDlWrap = require("youtube-dl-wrap")
youtube_dl_wrap = new YoutubeDlWrap(youtube_dl_path)
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
	search_youtube(youtube_api_key, params)
	.then(
		(data)=>
			console.log data
			items = data.items.filter((searchResult)-> searchResult.snippet.liveBroadcastContent is "none")
			{items} = data

			console.log "[YT] Found #{items.length} videos"

			async.eachLimit shuffle(items), 2,
				(item, callback)=>
					console.log "[YT] Video:", item
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
					
					youtube_dl_wrap.exec(["https://www.youtube.com/watch?v=#{item.id.videoId}",
						"-f", "worst", "-o", "%(title)s.%(ext)s", "--restrict-filenames"])
					.on("progress", (progress) => 
						console.log(item.id.videoId, progress.percent, progress.totalSize, progress.currentSpeed, progress.eta)
					)
					.on("error", (exitCode, processError, stderr) => 
						message = "youtube-dl exited with code #{exitCode}, process error: #{JSON.stringify(processError)}, stderr:\n#{stderr}"
						console.error("[YT] #{message}")
						callback(new Error(message))
					)
					.on("close", () =>
						console.log("[YT] Got video")
						track_callback("https://stream-youtube-video/#{item.id.videoId}", attribution)
						setTimeout =>
							callback null
						, 500 # TODO: does this actually help?
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