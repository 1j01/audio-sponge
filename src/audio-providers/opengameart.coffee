qs = require "qs"
{URL} = require "url"
cheerio = require "cheerio"
request = require "request"
async = require "async"
shuffle = require "../shuffle"

module.exports.search = (query, track_callback, done_callback)->

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
	console.log "[OGA] Searching OpenGameArt for \"#{query}\", search URL:", url

	request(url, (error, response, body)->
		if error
			console.error "[OGA] Error searching OpenGameArt:", error
			done_callback()
			return
		
		$ = cheerio.load(body)

		elements_with_data_mp3_url = $("[data-mp3-url]")

		console.log "[OGA] Found #{elements_with_data_mp3_url.length} tracks"

		async.eachLimit(
			shuffle(elements_with_data_mp3_url) # sort of weird that shuffling is part of this otherwise somewhat generic scraper
			2 # at a time
			(element, onwards)->
				# FIXME: callbacks within (implicitly) try-caught block (by `async`)? maybe not a problem since it uses request which is async
				track_page_link_href = $(element).closest(".node").find(".art-preview-title a, div[property='dc:title'] a, a").first().attr("href")
				track_page_url = new URL(track_page_link_href, url).href
				stream_url = $(element).attr("data-mp3-url")
				track_name = $(element).closest(".node").find(".art-preview-title, div[property='dc:title']").first().text()
				track_attribution =
					name: track_name
					link: track_page_url
					provider: "opengameart"
				request(track_page_url, (error, response, body)->
					if error
						track_callback(error)
						onwards()
						return
					track_page_$ = cheerio.load(body)
					user_page_link_href = track_page_$(".field-name-author-submitter a").attr("href")
					user_page_url = new URL(user_page_link_href, url).href

					# TODO: detect external user links and use link track_page_$(".field-name-author-submitter a").text() as the name
					# for e.g. https://opengameart.org/content/knife-sharpening-slice-2
					# which links to https://archive.org/details/Berklee44v13
					# track_attribution.author =
					# 	name: track_page_$(".field-name-author-submitter a").text()
					# 	link: user_page_url

					request(user_page_url, (error, response, body)->
						if error
							track_callback(error)
							onwards()
							return
						user_page_$ = cheerio.load(body)

						track_attribution.author =
							name: user_page_$(".field-name-field-real-name, div[property='foaf:name']").first().text()
							link: user_page_url
						
						track_callback(null, stream_url, track_attribution)
						onwards()
					)
				)
			(err)->
				console.error "[OGA] Error:", err if err
				done_callback() # regardless of error
		)
	)
