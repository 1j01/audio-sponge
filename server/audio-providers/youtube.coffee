fs = require "fs"
path = require "path"
glob = require "glob"
async = require "async"
search_youtube = require "youtube-api-v3-search"
YoutubeDlWrap = require "youtube-dl-wrap"
webvtt = require "node-webvtt"
shuffle = require "../shuffle"

videos_folder = path.join(__dirname, "../../videos")
bin_folder = path.join(__dirname, "../../bin")
youtube_dl_file_name = if require("os").platform() is "win32" then "youtube-dl.exe" else "youtube-dl"
youtube_dl_path = path.join(bin_folder, youtube_dl_file_name)
# TODO: delay init until downloaded? or just make sure it always exists in the published version of this project
if (not fs.existsSync(youtube_dl_path)) or process.env.REDOWNLOAD_YOUTUBE_DL is "1"
	YoutubeDlWrap.downloadYoutubeDl(youtube_dl_path, "2020.07.28")
	.then(
		->
			fs.chmodSync(youtube_dl_path, "755")
			console.log("Downloaded youtube-dl")
		(error)->
			console.error("Failed to download youtube-dl:", error)
	)

youtube_dl_wrap = new YoutubeDlWrap(youtube_dl_path)


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
					
					youtube_dl_wrap.exec([
						"https://www.youtube.com/watch?v=#{item.id.videoId}"

						"--format", "worst" # worst quality please! :)

						"--output", "#{videos_folder}/%(id)s.%(ext)s"
						"--restrict-filenames"
						"--no-overwrites"

						# TODO: which of these options are needed vs implied?
						"--write-sub"
						# "--write-auto-sub"
						# "--all-subs"
						# "--sub-format", "vtt" # hunch: this might limit to only downloading IF the format is provided directly
						"--convert-subs", "vtt"

						# "--extract-audio"

						"--write-info-json"
					])
					.on("progress", (progress) => 
						console.log(item.id.videoId, progress.percent, progress.totalSize, progress.currentSpeed, progress.eta)
					)
					.on("error", (exitCode, processError, stderr) => 
						message = "youtube-dl exited with code #{exitCode}, process error: #{JSON.stringify(processError)}, stderr:\n#{stderr}"
						console.error("[YT] #{message}")
						callback(new Error(message))
					)
					.on("close", () =>
						console.log("[YT] Downloaded video and subtitles")
						glob("#{videos_folder}/#{item.id.videoId}.*.vtt", (error, vtt_files)=>
							if error
								callback(error)
								return
							if vtt_files.length is 0
								callback(new Error("No vtt subtitles files downloaded for video #{item.id.videoId}"))
								return
							vtt_file = vtt_files[0] # TODO: prefer English (en-GB, en-US, en...), since that's what speech recognition will favor probably (and what I know)? prefer actual language spoken in the video somehow?
							fs.readFile(vtt_file, "utf8", (error, vtt_content)=>
								if error
									callback(error)
									return
								errored = false
								try
									# TODO: escape sequences are not handled
									subtitles = webvtt.parse(vtt_content)
								catch error
									errored = true
									console.log("[YT] Failed to parse subtitles file '#{vtt_file}'")
									callback(new Error("Failed to parse subtitles file '#{vtt_file}': #{error}"))
								if not errored
									console.log("[YT] Subtitles:", JSON.stringify(subtitles))
									# TODO: don't just assume mp4; maybe request transcoding to mp4
									track_callback("#{videos_folder}/#{item.id.videoId}.mp4", attribution)
									setTimeout =>
										callback null
									, 500 # TODO: does this actually help?
							)
						)
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
