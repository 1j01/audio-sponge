fs = require "fs"
get_env_var = require "./get-env-var"

server_port = get_env_var "PORT", default: 3901, number: yes
app_hostname = get_env_var "APP_HOSTNAME", default: "localhost"
now_url = get_env_var "NOW_URL"
app_origin = now_url or get_env_var "APP_ORIGIN", default: "http://#{app_hostname}:#{server_port}"

express = require "express"
app = express()

app.use(express.static("public"))

app.get "/", (req, res)->
	res.sendFile("public/app.html", root: __dirname + "/..")

lame = require "lame"

Sponge = require "./Sponge"
StreamWrapper = require "./serve-stream"
Throttle = require "throttle"

sponge = new Sponge
stream_wrapper = new StreamWrapper

sponge.start (err, context)->
	if err
		console.error err
		console.log "The server will exit shortly."
		setTimeout ->
			process.exit(1)
		, 200
		# TODO: exit more cleanly? like end the server and such
	
	# Note: inconsistent naming between web-audio-api and web-audio-engine for numberOfChannels/channels
	numberOfChannels = context.format.channels
	bytesPerSample = numberOfChannels * context.format.bitDepth / 8
	throttle =
		new Throttle
			bps: bytesPerSample * context.sampleRate
			chunkSize: bytesPerSample * 1024 # TODO: use blockSize from context?
	encoder =
		new lame.Encoder
			# input options
			channels: numberOfChannels
			bitDepth: context.format.bitDepth
			sampleRate: context.sampleRate
			# output options
			bitRate: 128
			outSampleRate: 22050
			mode: lame.STEREO # STEREO (default), JOINTSTEREO, DUALCHANNEL or MONO
	
	context.pipe(throttle)

	throttle
		.pipe(encoder)
		.pipe(stream_wrapper)
	
	# buffer a bit of audio to burst / to the client that's first / to quench their thirst
	# (having to wait is like the wooorst / it makes you feel.. like... ur cursed... or something)
	# TODO: don't buffer until we have sources? or get sources faster somehow?
	# okay, what I really want is it to buffer enough purge the buffer of the starting blips
	# or, not necessarily automatically based on the max buffer size, but to buffer enough to *be able to*, explicitly, here
	# I'd like it if it gives the illusion of having been running even when it was paused waiting for a first listener
	console.log "Buffering some audio for the first client(s)..."
	context.resume()
	setTimeout =>
		console.log "Buffered some audio for the first client(s)"
		setInterval =>
			if stream_wrapper.clients.length > 0
				unless context._isPlaying
					console.log "Clients: #{stream_wrapper.clients.length}, resuming"
					context.resume()
			else
				if context._isPlaying
					console.log "Clients: 0, pausing"
					context.suspend()
		, 200
	, 12000

app.get "/stream", (req, res)->
	stream_wrapper.stream(req, res)

app.get "/attribution", (req, res)->
	# TODO: are these setHeaders needed?
	res.setHeader "Cache-Control", "no-store, must-revalidate"
	res.setHeader "Expires", "0"
	# TODO: eventually drop sources, so that this list doesn't get ridiculous
	res.json({
		sources:
			for source in sponge.sources
				# {link, name} = source.metadata
				# {link, name}
				source.metadata
	})

app.get "/ping", (req, res)->
	body = "pong"
	res.writeHead 200,
		"Cache-Control": "no-store, must-revalidate"
		"Expires": "0"
		"Content-Type": "text/plain"
		"Content-Length": Buffer.byteLength(body)
	res.end(body)

app.listen server_port, ->
	console.log """
		.--------------------------------------------------- - - -
		| Listening on #{app_origin}
		'--------------------------------------------------- - - -
	"""
