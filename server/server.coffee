fs = require "fs"
express = require "express"
get_env_var = require "./get-env-var"
gather_video = require "./gather-video"
gather_midi = require "./gather-midi"
shuffle = require "./shuffle"

server_port = get_env_var "PORT", default: 3901, number: yes
app_hostname = get_env_var "APP_HOSTNAME", default: "localhost"
now_url = get_env_var "NOW_URL"
app_origin = now_url or get_env_var "APP_ORIGIN", default: "http://#{app_hostname}:#{server_port}"

app = express()
http = require("http").createServer(app)
io = require("socket.io")(http)

gather_sources = ({query, midi}, new_source_callback)->
	if midi
		gather_midi query, new_source_callback, ->
	else
		gather_video query, new_source_callback

io.on "connection", (socket)->
	console.log("a user connected")
	socket.on "disconnect", ->
		console.log("user disconnected")

	socket.on "sound-search", ({query, midi, query_id})->
		sources = []
		gather_sources {query, midi}, (new_source)->
			socket.emit("sound-metadata:#{query_id}", new_source.metadata)
			sources.push(new_source)

			if sources.length is (if midi then 1 else 5)
				sources.forEach (source)->
					{sound_id} = source.metadata

					stream = source.createReadStream()
					stream.on "data", on_data = (data)->
						socket.emit("sound-data:#{sound_id}", data)
					stream.on "end", on_end = ->
						console.log "sent file", source.uri
						socket.emit("sound-data-end:#{sound_id}")
						stream.removeListener "data", on_data # not sure this is needed or works how i want it
						stream.removeListener "error", on_error # not sure this is needed or works how i want it
					stream.on "error", on_error = (error)->
						console.log "error", sound_id, error
						stream.removeListener "data", on_data # not sure this is needed or works how i want it
						stream.removeListener "end", on_end # not sure this is needed or works how i want it

setInterval ->
	mem = process.memoryUsage().heapUsed
	mem_limit = 60666000
	# console.log("Memory:", mem)
	if mem > mem_limit
		console.error("Reached memory limit of #{mem_limit}; exiting")
		process.exit(1)
, 1000

app.use(express.static("client"))

app.get "/", (req, res)->
	res.sendFile("client/app.html", root: __dirname + "/..")

http.listen server_port, ->
	console.log """
		.--------------------------------------------------- - - -
		| Listening on #{app_origin}
		'--------------------------------------------------- - - -
	"""
