qs = require "qs"
{URL} = require "url"
cheerio = require "cheerio"
request = require "request"
async = require "async"

module.exports = (query, callback, track_callback)->

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

		async.eachLimit(
			$("[data-mp3-url]")
			2 # at a time
			(element, callback)->
				track_page_link_href = $(element).closest(".node").find(".art-preview-title a, div[property='dc:title'] a, a").first().attr("href")
				track_page_url = new URL(track_page_link_href, url).href
				track =
					stream_url: $(element).attr("data-mp3-url")
					title: $(element).closest(".node").find(".art-preview-title, div[property='dc:title']").first().text()
					permalink_url: track_page_url
				request(track.permalink_url, (error, response, body)->
					if error
						track_callback(error)
						return
					track_page_$ = cheerio.load(body)
					user_page_link_href = track_page_$(".field-name-author-submitter a").attr("href")
					user_page_url = new URL(user_page_link_href, url).href

					request(user_page_url, (error, response, body)->
						if error
							track_callback(error)
							return
						user_page_$ = cheerio.load(body)
					
						track.user =
							username: user_page_$(".field-name-field-real-name, div[property='foaf:name']").first().text()
							permalink_url: user_page_url
						
						track_callback(null, track)
					)
				)
		)
	)
