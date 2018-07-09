qs = require "qs"
{URL} = require "url"
cheerio = require "cheerio"
request = require "request"
async = require "async"

module.exports = (query, callback)->

	url = "https://opengameart.org/art-search-advanced?" + qs.stringify({
		keys: query,
		title: '',
		field_art_tags_tid_op: 'or',
		field_art_tags_tid: '',
		name: '',
		field_art_type_tid: [ '12', '13' ], # Music, SFX
		sort_by: 'count',
		sort_order: 'DESC',
		items_per_page: '24',
		Collection: ''
	})
	console.log "OGA search URL:", url

	request(url, (error, response, body)->
		if error
			callback(error)
			return
		$ = cheerio.load(body)

		# tracks =
		# 	for element in $("[data-mp3-url]")
		# 		stream_url: $(element).attr("data-mp3-url")
		# 		title: $(element).closest(".node").find("[property='dc:title']").text()
		# 		permalink_url: $(element).closest(".node").find("[property='dc:title'] a, a").first().attr("href")
		# 
		# callback(null, tracks)

		# TODO: handle errors gracefully and basically ignore (but report) errors for individual track metadata-fetching
		# TODO: limit fetching to a max number of tracks (possibly 1) and space out requests over time, stream / call back with individual track metadatas
		async.map(
			$("[data-mp3-url]")
			(element, callback)->
				track_page_link_href = $(element).closest(".node").find(".art-preview-title a, div[property='dc:title'] a, a").first().attr("href")
				track_page_url = new URL(track_page_link_href, url).href
				track =
					stream_url: $(element).attr("data-mp3-url")
					title: $(element).closest(".node").find(".art-preview-title, div[property='dc:title']").first().text()
					permalink_url: track_page_url
				request(track.permalink_url, (error, response, body)->
					if error
						callback(error)
						return
					track_page_$ = cheerio.load(body)
					user_page_link_href = track_page_$(".field-name-author-submitter a").attr("href")
					user_page_url = new URL(user_page_link_href, url).href

					# track.user =
					# 	username: track_page_$(".field-name-author-submitter").text()
					# 	permalink_url: user_page_url
					
					# callback(null, track)
					
					request(user_page_url, (error, response, body)->
						if error
							callback(error)
							return
						user_page_$ = cheerio.load(body)
					
						track.user =
							username: user_page_$(".field-name-field-real-name, div[property='foaf:name']").first().text()
							permalink_url: user_page_url
						
						callback(null, track)
					)
				)
			callback
		)
	)
