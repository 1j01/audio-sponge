qs = require "qs"
{URL} = require "url"
cheerio = require "cheerio"
request = require "request"
async = require "async"
shuffle = require "./shuffle"
Source = require "./Source"

# TODO: other ways of getting midi
# like a local folder of midi files

scrape_bitmidi_track_page = (track_page_url, callback)->
	console.log("[BM] scrape track page:", track_page_url)
	request track_page_url, (error, response, body)->
		return callback(error) if error

		$ = cheerio.load(body)

		track_name = $("main h1").first().text()
		track_attribution =
			name: track_name
			link: track_page_url
			provider: "BitMidi"
		download_link_href = $("a[href$='.mid'], a[download]").attr("href")
		stream_url = new URL(download_link_href, track_page_url).href
		console.log("[BM] scraped track page, got", stream_url, track_attribution)

		callback(null, new Source(stream_url, track_attribution))


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

		if links_to_track_pages.length is 0
			console.log "[BM] Didn't find any MIDIs for \"#{query}\", using random MIDI"
			request({url: "https://bitmidi.com/random", followRedirect: no}, (error, response, body)->
				if error
					console.error "[BM] Error getting random MIDI from BitMidi:", error
					done_callback()
					return
				
				track_page_url = new URL(response.headers.location, "https://bitmidi.com/").href
				console.log "[BM] /random redirected to:", track_page_url

				scrape_bitmidi_track_page(track_page_url, (error, source)->
					if error
						console.error "[BM] Error scraping random MIDI from BitMidi:", error
						done_callback()
						return
					track_callback(source)
					done_callback()
				)
			)
			return

		console.log "[BM] Found #{links_to_track_pages.length} tracks"

		async.eachLimit(
			shuffle(links_to_track_pages)
			2 # at a time
			(element, onwards)->
				# NOTE: MUST not call callback herein syncronously!
				# An error in the callback would be caught by `async` and lead to confusion.

				track_page_link_href = $(element).attr("href")
				track_page_url = new URL(track_page_link_href, url).href

				request(track_page_url, (error, response, body)->
					if error
						console.error(error)
						onwards()
						return
					track_page_link_href = $(element).attr("href")
					track_page_url = new URL(track_page_link_href, url).href
					scrape_bitmidi_track_page(track_page_url, (error, source)->
						if error
							console.error "[BM] Error scraping BitMidi track page:", error
							onwards()
							return
						track_callback(source)
						onwards()
					)
				)
			(err)->
				console.error "[BM] Error:", err if err
				done_callback() # regardless of error
		)
	)
