sec = require("search-engine-client")

module.exports.search = (query, track_callback, done_callback)->
	ddg_query = "#{query} filetype:mp3"
	sec.bing(ddg_query).then (result)->
		# TODO: check for result.error?
		for url in result.links
			track_callback null, url, {name: url, link: url, provider: "bing"}
		
		done_callback()
