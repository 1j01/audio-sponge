async = require "async"
search_youtube = require "youtube-api-v3-search"
youtube_dl = require "./youtube-dl"
shuffle = require "../shuffle"

youtube_api_key = null
module.exports.init = (options)->
	youtube_api_key = options.key

module.exports.searchAndDownload = (query, track_callback, done_callback)->
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
			if data.error
				console.error "[YT] YouTube API returned error: #{JSON.stringify(data.error)}"
				done_callback() # regardless of error
				return
			# console.log "[YT] Search results data:", data
			items = data.items.filter((searchResult)-> searchResult.snippet.liveBroadcastContent is "none")
			{items} = data

			console.log "[YT] Found #{items.length} videos"

			async.eachLimit shuffle(items), 2,
				(item, callback)=>
					# console.log "[YT] Video:", item
					console.log "[YT] Video: #{item.id.videoId} (#{item.snippet.title})"
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
					youtube_dl(item.id.videoId, (error, file_path)->
						if file_path
							track_callback(file_path, attribution)
						setTimeout =>
							callback(error)
						, 500 # TODO: does this actually help? (rate limiting)
					)
				(err)=>
					# FIXME: catches errors within track_callback
					console.error "[YT] Error:", err if err
					done_callback() # regardless of error
		(err)=>
			if err
				console.error "[YT] Error searching for videos:", err if err
				done_callback()
				return
	)
