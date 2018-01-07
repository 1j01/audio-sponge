fs = require "fs"
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
	constructor: (@path)->
		@buffer = fs.readFileSync(@path)
	
	toString: -> "file:#{@path}"
	
	prepareAudioBuffer: (context, callback)->
		# this works
		context.decodeAudioData @buffer,
			(@audioBuffer)=>
				callback(null)
			(err)=>
				callback(err)
		
		# as does this
		# streamToBufferArray @readStream, (err, buffers)=>
		# 	return callback err if err
		# 	buffer = Buffer.concat(buffers)
		# 	context.decodeAudioData buffer,
		# 		(@audioBuffer)=>
		# 			callback(null)
		# 		(err)=>
		# 			callback(err)
		
		# this doesn't really work, though:
		# streamToBufferArray @headerStream, (err, buffers)=>
		# 	return callback err if err
		# 	streamToBufferArray @readStream, (err, more_buffers)=>
		# 		return callback err if err
		# 		# console.log buffers.concat(more_buffers)
		# 		buffer = Buffer.concat(buffers.concat(more_buffers))
		# 		context.decodeAudioData buffer,
		# 			(@audioBuffer)=>
		# 				callback(null)
		# 			(err)=>
		# 				callback(err)
		# it'd need to align with the frame boundaries
		# offset by the header which may not always be a multiple of the frame size
		# I could get this information with node-wav,
		# but I don't really want to create a dependency on a specific file type
	
	# findBeats: ->
	# 	rms = Meyda.extract "rms", @buffer
	# 	console.log rms

