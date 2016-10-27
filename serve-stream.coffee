
class StreamWrapper
	constructor: ->
		@max_listeners = 50
		@encoder = new lame.Encoder
			# input
			channels: 2        # 2 channels (left and right)
			bitDepth: 16       # 16-bit samples
			sampleRate: 44100  # 44,100 Hz sample rate

			# output
			bitRate: 128
			outSampleRate: 22050
			mode: lame.STEREO  # STEREO (default), JOINTSTEREO, DUALCHANNEL or MONO

	stream: (request, response)->
		headers =
			"Content-Type": "audio/mpeg"
			"Connection": "close"
			"Transfer-Encoding": "identity"
		
		# if @radio_listeners.length > @max_listeners
		# 	request.connection.emit "close"
		# 	return
		
		unless response.headers
			response.writeHead(200, headers)
		
		@encoder.pipe(response)
		
		# self.decoder.addClient(request, response);
		# 
		# request.connection.on "close", ->
		# 	self.decoder.removeClient(ip)

module.exports = -> new StreamWrapper
