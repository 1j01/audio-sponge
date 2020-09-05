fs = require "fs"
path = require "path"
glob = require "glob"
async = require "async"
YoutubeDlWrap = require "youtube-dl-wrap"
vtt_to_json = require "vtt-to-json"

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

module.exports = (videoId, callback)->
	youtube_dl_wrap.exec([
		"https://www.youtube.com/watch?v=#{videoId}"

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
		console.log(videoId, "#{progress.percent}%", progress.totalSize, progress.currentSpeed, progress.eta)
	)
	.on("error", (exitCode, processError, stderr) => 
		message = "youtube-dl exited with code #{exitCode}, process error: #{JSON.stringify(processError)}, stderr:\n#{stderr}"
		console.error("[YTDL] #{message}")
		callback(new Error(message))
	)
	.on("close", () =>
		console.log("[YTDL] Downloaded video and subtitles")
		glob("#{videos_folder}/#{videoId}.*.vtt", (error, vtt_files)=>
			if error
				callback(error)
				return
			if vtt_files.length is 0
				# callback(new Error("No vtt subtitles files downloaded for video #{videoId}"))
				callback(null, "#{videos_folder}/#{videoId}.mp4")
				return
			vtt_file = vtt_files[0] # TODO: prefer English (en-GB, en-US, en...), since that's what speech recognition will favor probably (and what I know)? prefer actual language spoken in the video somehow?
			fs.readFile(vtt_file, "utf8", (error, vtt_content)=>
				if error
					callback(error)
					return
				# TODO: this is async for no reason and doesn't allow text from other languages
				# also, escape sequences are not handled
				vtt_to_json(vtt_content)
				.then(
					(subtitles)=>
						# console.log("[YTDL] Subtitles:", JSON.stringify(subtitles))
						# TODO: don't just assume mp4; maybe request transcoding to mp4
						callback(null, "#{videos_folder}/#{videoId}.mp4")
					(error)=>
						console.log("[YTDL] Failed to parse subtitles:", subtitles)
						callback(error)
				)
			)
		)
	)
