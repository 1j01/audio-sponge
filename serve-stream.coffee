
class StreamWrapper
	constructor: ->
		@maxListeners = 50
		@maxBurstChunks = 1024 # this could use some fine-tuning
		@inputStream = null
		@clients = []
		@chunks = []
	
	setInput: (inputStream)=>
		@inputStream?.removeListener(@onData)
		@inputStream = inputStream
		for response in @clients
			@inputStream?.addListener("data", @onData)
	
	onData: (data)=>
		# console.log "writing #{data.length} bytes to #{@clients.length} clients"
		for client in @clients
			client.write(data)
		@chunks.push(data)
		if @chunks.length > @maxBurstChunks
			@chunks.shift()
	
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
		
		console.log "burst #{@chunks.length} chunks to new client (#{@clients.length})"
		for chunk in @chunks
			response.write(chunk)
		
		request.connection.on "close", =>
			index = @clients.indexOf(response)
			if index > -1
				@inputStream?.unpipe(response)
				@clients.splice(index, 1)

module.exports = -> new StreamWrapper
