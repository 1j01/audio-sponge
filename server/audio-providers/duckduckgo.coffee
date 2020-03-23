sec = require("search-engine-client")

module.exports.search = (query, track_callback, done_callback)->
	ddg_query = "#{query} filetype:mp3"
	options = count: 30
	console.log "[DDG] Searching DuckDuckGo for '#{ddg_query}'"
	sec.bing(ddg_query, options).then (result)->
		# TODO: check for result.error?
		mp3_urls = result.links.filter((url)-> url.match(/\.mp3/i))
		console.log "[DDG] Found #{mp3_urls.length} MP3 URLs:", mp3_urls
		for url in mp3_urls
			track_callback null, url, {name: url, link: url, provider: "duckduckgo"}
		
		done_callback()
