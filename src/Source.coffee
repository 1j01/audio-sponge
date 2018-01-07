fs = require "fs"
lame = require "lame"
# Meyda = require "meyda"

###
streamToBufferArray = (stream, callback)->
	buffers = []
	stream.on "data", (buffer)->
		buffers.push(buffer)
	stream.on "end", ->
		# buffer = Buffer.concat(buffers)
		callback(null, buffers)
	stream.on "error", callback
###

module.exports =
class Source
	constructor: (uri)->
		# const stream = require('youtube-audio-stream')
		# const url = 'http://youtube.com/watch?v=34aQNMvGEZQ'
		# const decoder = require('lame').Decoder()
		# const speaker = require('speaker')
		
		# stream(url)
		# .pipe(decoder)
		# .pipe(...)

		# if uri.match(/http[s]:/
		# 	request(uri)
		# else
		# 	fs.createReadStream(uri)

		decoder = new lame.Decoder

	
	toString: -> "file:#{@path}"
	
	prepareAudioBuffer: (context, callback)->
		context.decodeAudioData @buffer,
			(@audioBuffer)=>
				callback(null)
			(err)=>
				callback(err)
	
	# findBeats: ->
	# 	rms = Meyda.extract "rms", @buffer
	# 	console.log rms

