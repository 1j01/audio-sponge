fs = require "fs"
path = require "path"
glob = require "glob"
async = require "async"
YTDlpWrap = require("yt-dlp-wrap-plus").default
vtt_to_json = require "vtt-to-json"

videos_folder = path.join(__dirname, "../../videos")
bin_folder = path.join(__dirname, "../../bin")
yt_dlp_file_name = if require("os").platform() is "win32" then "yt-dlp.exe" else "yt-dlp"
yt_dlp_path = path.join(bin_folder, yt_dlp_file_name)

fs.mkdirSync(videos_folder, {recursive: true})
fs.mkdirSync(bin_folder, {recursive: true})
# TODO: delay init until downloaded? or just make sure it always exists in the published version of this project
if (not fs.existsSync(yt_dlp_path)) or process.env.REDOWNLOAD_yt_dlp is "1"
	YTDlpWrap.downloadFromGithub(yt_dlp_path)
	.then(
		->
			fs.chmodSync(yt_dlp_path, "755")
			console.log("Downloaded yt-dlp")
		(error)->
			console.error("Failed to download yt-dlp:", error)
	)

yt_dlp_wrap = new YTDlpWrap(yt_dlp_path)

module.exports = (videoId, callback)->
	yt_dlp_wrap.exec([
		"https://www.youtube.com/watch?v=#{videoId}"

		"--format", "worst" # worst quality please! :)

		"--output", "#{videos_folder}/%(id)s.%(ext)s"
		"--restrict-filenames"
		"--no-overwrites"

		# TODO: which of these options are needed vs implied?
		"--write-subs"
		# "--write-auto-subs"
		# "--all-subs"
		# "--sub-format", "vtt" # hunch: this might limit to only downloading IF the format is provided directly
		"--convert-subs", "vtt"

		# "--extract-audio"

		"--write-info-json"
	])
	.on("progress", (progress) => 
		console.log(videoId, "#{progress.percent}%", progress.totalSize, progress.currentSpeed, progress.eta)
	)
	.on("error", (error) => 
		message = "yt-dlp failed to download #{videoId} - got error: #{error}"
		console.error("[YT-DLP] #{message}")
		callback(new Error(message))
	)
	.on("close", () =>
		console.log("[YT-DLP] Downloaded video and subtitles")
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
						# console.log("[YT-DLP] Subtitles:", JSON.stringify(subtitles))
						# TODO: don't just assume mp4; maybe request transcoding to mp4
						callback(null, "#{videos_folder}/#{videoId}.mp4")
					(error)=>
						console.log("[YT-DLP] Failed to parse subtitles:", subtitles)
						callback(error)
				)
			)
		)
	)
