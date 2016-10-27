
class StreamWrapper
	constructor: ->
		@maxListeners = 50
		@inputStream = null
		@responses = []
	
	setInput: (inputStream)->
		@inputStream?.unpipe()
		@inputStream = inputStream
		for response in @responses
			@inputStream?.pipe(response)
	
	stream: (request, response)->
		headers =
			"Content-Type": "audio/mpeg"
			"Connection": "close"
			"Transfer-Encoding": "identity"
		
		if @responses.length > @maxListeners
			request.connection.emit "close"
			return
		
		unless response.headers
			response.writeHead(200, headers)
		
		@inputStream?.pipe(response)
		@responses.push(response)
		
		request.connection.on "close", =>
			index = @responses.indexOf(response)
			if index > -1
				@inputStream?.unpipe(response)
				@responses.splice(index, 1)

module.exports = -> new StreamWrapper
