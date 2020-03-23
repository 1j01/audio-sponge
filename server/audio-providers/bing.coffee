sec = require("search-engine-client")

module.exports.search = (query, track_callback, done_callback)->
	bing_query = "#{query} filetype:mp3"
	options = count: 30
	console.log "[bing] Searching Bing for '#{bing_query}'"
	sec.bing(bing_query, options).then (result)->
		# TODO: check for result.error?
		mp3_urls = result.links.filter((url)-> url.match(/\.mp3/i))
		console.log "[bing] Found #{mp3_urls.length} MP3 URLs:", mp3_urls
		for url in mp3_urls
			track_callback null, url, {name: url, link: url, provider: "bing"}
		
		done_callback()
