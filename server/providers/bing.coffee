async = require "async"
request_promise = require "request-promise"
cheerio = require "cheerio"
querystring = require "querystring"
youtube_dl = require "./youtube-dl"
shuffle = require "../shuffle"

module.exports.search = (query)->

	filters = [
		"+filterui:msite-youtube.com"
		"+filterui:duration-short"
		# "+filterui:videoage-lt10080"
		"+filterui:price-free"
	]

	query_params =
		q: query
		qft: filters.join("")
	
	url = "http://www.bing.com/videos/search?#{querystring.encode(query_params)}"

	console.log "[bing] Search URL:", url

	results = []

	return request_promise(url)
		.then (body)->
			$ = cheerio.load(body)
			items = $("td.resultCell")	

			$(items).each (i, item)->
				result = {}
				if $(item).find("div.title span").attr("title")
					result.title = $(item).find("div.title span").attr("title")
				else
					result.title = $(item).find("div.title").text()

				link = $(item).find("a").attr("href")
				video_id = new URL(link).searchParams.get("v")

				result.link = "https://www.youtube.com/watch?v=#{video_id}"
				result.video_id = video_id
				result.thumbnail = "https://i.ytimg.com/vi/#{video_id}/default.jpg"
				result.thumbnail_mq = "https://i.ytimg.com/vi/#{video_id}/mqdefault.jpg"
				result.thumbnail_hq = "https://i.ytimg.com/vi/#{video_id}/hqdefault.jpg"

				results.push(result)

			console.log "[bing] Found #{results.length} results"

			return results

module.exports.searchAndDownload = (query, track_callback, done_callback)->
	module.exports.search(query).then(
		(items)->
			async.eachLimit shuffle(items), 2,
				(item, callback)=>
					# console.log "[bing] Video:", item
					console.log "[bing] Video: #{item.video_id} (#{item.link})"
					# NOTE: MUST not call callback herein synchronously!
					# An error in the callback would be caught by `async` and lead to confusion.
					attribution = {
						link: "https://www.youtube.com/watch?v=#{item.video_id}"
						name: item.title
						author: {
							# TODO: can use *.info.json, and share / move to youtube-dl.coffee
							name: "TODO" # item.channelTitle
							link: "TODO" # "https://www.youtube.com/channel/#{item.channelId}"
						}
						provider: "youtube" # TODO
					}
					youtube_dl(item.video_id, (error, file_path)->
						if file_path
							track_callback(file_path, attribution)
						setTimeout =>
							callback(error)
						, 500 # TODO: does this actually help? (rate limiting)
					)
				(err)=>
					# FIXME: catches errors within track_callback
					console.error "[bing] Error:", err if err
					done_callback() # regardless of error

		(error)->
			done_callback()
	)
