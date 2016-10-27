
class StreamWrapper
	constructor: ->
		@maxListeners = 50
		@inputStream = null
		@clients = []
	
	setInput: (inputStream)=>
		@inputStream?.removeListener(@onData)
		@inputStream = inputStream
		for response in @clients
			@inputStream?.addListener("data", @onData)
	
	onData: (data)=>
		for client in @clients
			client.write(data)
	
	stream: (request, response)=>
		headers =
			"Content-Type": "audio/mpeg"
			"Connection": "close"
			"Transfer-Encoding": "identity"
		
		if @clients.length > @maxListeners
			request.connection.emit "close"
			return
		
		unless response.headers
			response.writeHead(200, headers)
		
		@clients.push(response)
		
		request.connection.on "close", =>
			index = @clients.indexOf(response)
			if index > -1
				@inputStream?.unpipe(response)
				@clients.splice(index, 1)

module.exports = -> new StreamWrapper
