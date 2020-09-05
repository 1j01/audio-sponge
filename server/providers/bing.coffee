rp = require('request-promise')
cheerio = require('cheerio')
querystring = require('querystring')

module.exports = (query)->

	filters = [
		"+filterui:msite-youtube.com"
		"+filterui:duration-short"
		"+filterui:videoage-lt10080"
		"+filterui:price-free"
	]

	query_params =
		q: query
		qft: filters.join('')
	
	url = "http://www.bing.com/videos/search?#{querystring.encode(query_params)}"

	results = []

	return rp(url)
		.then (body)->
			$ = cheerio.load(body)
			items = $('td.resultCell')	

			$(items).each (i, item)->
				result = {}
				if $(item).find('div.title span').attr('title')
					result.title = $(item).find('div.title span').attr('title')
				else
					result.title = $(item).find('div.title').text()

				link = $(item).find('a').attr('href')
				video_id = new URL(link).searchParams.get("v")

				result.link = "https://www.youtube.com/watch?v=#{video_id}"
				result.video_id = video_id
				result.thumbnail = "https://i.ytimg.com/vi/#{video_id}/default.jpg"
				result.thumbnail_mq = "https://i.ytimg.com/vi/#{video_id}/mqdefault.jpg"
				result.thumbnail_hq = "https://i.ytimg.com/vi/#{video_id}/hqdefault.jpg"

				results.push(result)

			return results
