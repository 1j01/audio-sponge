fs = require "fs"
request = require "request"
lame = require "lame"
# pcmUtils = require "pcm-utils"
pcm = require "pcm-util"
# PCMTransform = require "pcm-transform"
# Meyda = require "meyda"
sliceAudioBuffer = require "./slice-audiobuffer.js"

# pcm_buffer_to_channels = (pcm_buffer, callback)->
# 	channels = []
# 	# unzipper = new pcmUtils.Unzipper channels, pcmUtils.FMT_U16LE
# 	# unzipper.write(pcm_buffer)
# 	# unzipper.on "end", ->
# 	# 	console.log "end"
# 	# unzipper.on "error", (err)->
# 	# 	callback err
# 	# unzipper.on "finish", ->
# 	# 	console.log "finish"
# 	# 	callback null, channels
	
# 	# pcm_transform = new PCMTransform batchSize: 20000
# 	# pcm_transform.write(pcm_buffer)
# 	# pcm_transform.on "end", ->
# 	# 	console.log "end"
# 	# pcm_transform.on "error", (err)->
# 	# 	callback err
# 	# pcm_transform.on "data", (data)->
# 	# 	console.log "data", data # just one argument? no separate channels?
# 	# 	channels[].push/concat(data.slice())??
# 	# pcm_transform.on "finish", ->
# 	# 	console.log "finish"
# 	# 	callback null, channels

max_buffers = parseInt(process.env.MAX_BUFFERS)
if not isFinite(max_buffers) then max_buffers = 50 # TODO: figure out how much this is and if it's reasonable
# actually probably better to define it in terms of samples (uh, you know, sample frames) or seconds
# NOTE: terminology is confusing; we've got samples which are buffers which have many samples
# which are sourced via Source (that's why it's called Source)... and then played via BufferSource nodes
# I should probably call samples slices or beats, and Source could just be a function or functions

take_sample_chance = parseInt(process.env.TAKE_SAMPLE_CHANCE)
if not isFinite(take_sample_chance) then take_sample_chance = 0.05

# TODO: this doesn't need to be a class
# if it is a class, maybe it should be an EventEmitter
module.exports =
class Source
	constructor: (uri, @context, sample_callback, callback)->
		# could use node-get-uri or go the other direction and just accept a stream (and maybe an id for inspection)
		if uri.match(/http[s]:/)
			@uri = uri
			@readStream = request(uri, qs: client_id: process.env.SOUNDCLOUD_CLIENT_ID)
		else
			@uri = "file:///#{uri}"
			@readStream = fs.createReadStream(uri)

		# TODO: wav support and maybe other formats
		decoder = new lame.Decoder
		@readStream.on "error", callback
		@readStream.pipe(decoder)

		pcm_format = null
		buffers = []
		look_at_buffers_and_find_samples = (buffers)=>
			# console.log "       look_at_buffers_and_find_samples start (#{buffers.length} buffers)"
			if not pcm_format
				return console.warn "pcm format not determined yet from mp3 stream after #{buffers.length} data buffers"
			buffer = Buffer.concat(buffers)
			# console.log "looking at #{buffers.length} buffers (#{buffer.byteLength} bytes) for #{@uri} to find samples"
			@findSamplesFromBuffer(buffer, pcm_format, sample_callback)
			# console.log "       look_at_buffers_and_find_samples end"

		decoder.on "format", (format)=>
			pcm_format = format
			# console.log "got format:", format
			# if source.audioBuffer.sampleRate isnt context.sampleRate
			# 	console.log "source.audioBuffer.sampleRate (#{source.audioBuffer.sampleRate}) doesn't match context.sampleRate (#{context.sampleRate}); preemptively rejecting #{source}"

		decoder.on "data", (buffer)=>
			buffers.push(buffer)
			if buffers.length >= max_buffers
				look_at_buffers_and_find_samples(buffers)
				buffers = []
				# console.log "      pause decoder"
				# decoder.pause()
				# setTimeout =>
				# 	console.log "      resume decoder"
				# 	decoder.resume()
				# , Math.random() * 300 + 100
			
			# console.log "      pause decoder"
			decoder.pause()
			setTimeout =>
				# console.log "      resume decoder"
				decoder.resume()
			, 10
		decoder.on "end", =>
			look_at_buffers_and_find_samples(buffers)
			callback(null, @)
		decoder.on "error", callback
	
	toString: -> @uri
	
	# TODO: findInterestingSamplesFromBuffer
	findSamplesFromBuffer: (buffer, pcm_format, sample_callback)->
		# don't need that many samples
		return if Math.random() < take_sample_chance
		# TODO: find beats with Meyda or another module
		
		# pcm_buffer_to_channels buffer, (err, channels)->
		# 	return console.error err if err
		
		# 	{sampleRate, format} = @context
		# 	numberOfChannels = format.numberOfChannels ? format.channels
		# 	max_duration = buffer.length / sampleRate
		# 	slice_duration = Math.random() / 2 + 0.1
		# 	slice_duration = Math.min(slice_duration, max_duration)
		# 	# TODO: start offset
			
		# 	length = sampleRate * slice_duration
		# 	new_audio_buffer = @context.createBuffer numberOfChannels, length, sampleRate
		# 	for channelIndex, channelData in channels
		# 		# buffer.copyFromChannel(tempArray, channel, startOffset)
		# 		# newArrayBuffer.copyToChannel(tempArray, channel, 0)
		# 		newArrayBuffer.copyToChannel(channelData, channelIndex, 0)
			
		# 	sample_callback(null, new_audio_buffer)

		audiojs_audio_buffer = pcm.toAudioBuffer(buffer, pcm_format)
		
		duration = Math.random() / 2 + 0.1
		duration = Math.min(duration, audiojs_audio_buffer.duration)
		start = Math.random() * (audiojs_audio_buffer.duration - duration)
		end = start + Math.max(0, duration - 0.01) # TODO: move duration modifier out to a statement?
		new_audio_buffer = sliceAudioBuffer audiojs_audio_buffer, start, end, @context

		sample_callback(new_audio_buffer)
		

	# findBeats: ->
	# 	rms = Meyda.extract "rms", @buffer
	# 	console.log rms

