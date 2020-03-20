qs = require "qs"
{URL} = require "url"
cheerio = require "cheerio"
request = require "request"
async = require "async"
shuffle = require "./shuffle"

# TODO: fallback to https://bitmidi.com/random
# and other ways of getting midi
# like some local static set of them if nothing else

module.exports = (query, track_callback, done_callback)->

	url = "https://bitmidi.com/search?" + qs.stringify({
		q: query,
	})
	console.log "[BM] Searching BitMidi for \"#{query}\", search URL:", url

	request(url, (error, response, body)->
		if error
			console.error "[BM] Error searching BitMidi:", error
			done_callback()
			return
		
		$ = cheerio.load(body)

		links_to_track_pages = $("a[href$='-mid']")

		console.log "[BM] Found #{links_to_track_pages.length} tracks"

		async.eachLimit(
			shuffle(links_to_track_pages)
			2 # at a time
			(element, onwards)->
				# NOTE: MUST not call callback herein syncronously!
				# An error in the callback would be caught by `async` and lead to confusion.
				track_page_link_href = $(element).attr("href")
				track_page_url = new URL(track_page_link_href, url).href
				track_name = $(element).find("h2").text()
				track_attribution =
					name: track_name
					link: track_page_url
					provider: "BitMidi"
				request(track_page_url, (error, response, body)->
					if error
						track_callback(error)
						onwards()
						return
					track_page_$ = cheerio.load(body)
					stream_url = track_page_$("a[href$='.mid'], a[download]").attr("href")

					track_callback(null, stream_url, track_attribution)
					onwards()
				)
			(err)->
				console.error "[BM] Error:", err if err
				done_callback() # regardless of error
		)
	)
