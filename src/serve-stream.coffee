{Writable} = require "stream"

module.exports =
class StreamWrapper extends Writable
	constructor: (options)->
		super(options)
		@maxClients = options?.maxClients ? 100
		@maxBurstChunks = options?.maxBurstChunks ? 1024 # this could probably use some fine-tuning
		@contentType = options?.contentType ? "audio/mpeg"
		@clients = []
		@burstChunks = []
	
	# TODO: kick clients when they pause for too long / when running out of memory
	# right now it probably keeps buffers of audio in memory indefinitely, and separately for each client 

	_write: (chunk, encoding, callback)=>
		for client in @clients
			client.write(chunk)
		@burstChunks.push(chunk)
		if @burstChunks.length > @maxBurstChunks
			@burstChunks.shift()
		callback()
	
	stream: (request, response)=>
		headers =
			"Content-Type": @contentType
			"Connection": "close"
			"Transfer-Encoding": "identity"
		
		if @clients.length > @maxClients
			request.connection.emit "close"
			return
		
		unless response.headers
			response.writeHead(200, headers)
		
		@clients.push(response)
		
		console.log "burst #{@burstChunks.length} chunks to new client (#{@clients.length})"
		for chunk in @burstChunks
			response.write(chunk)
		
		request.connection.on "close", =>
			index = @clients.indexOf(response)
			if index > -1
				@inputStream?.unpipe(response)
				@clients.splice(index, 1)
