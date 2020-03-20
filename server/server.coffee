fs = require "fs"
express = require "express"
get_env_var = require "./get-env-var"
gather_audio = require "./gather-audio"
shuffle = require "./shuffle"

server_port = get_env_var "PORT", default: 3901, number: yes
app_hostname = get_env_var "APP_HOSTNAME", default: "localhost"
now_url = get_env_var "NOW_URL"
app_origin = now_url or get_env_var "APP_ORIGIN", default: "http://#{app_hostname}:#{server_port}"

app = express()
http = require("http").createServer(app)
io = require("socket.io")(http)
ss = require("socket.io-stream")

io.on "connection", (socket)->
	console.log("a user connected")
	socket.on "disconnect", ->
		console.log("user disconnected")

	socket.on "sound-search", ({query, query_id})->
		sources = []
		gather_audio (new_source)->
			sources.push(new_source)
			# socket.emit("attribution", {
			# 	query_id
			# 	sources: (source.metadata for source in sources)
			# })

			# sources_to_use = shuffle(sources).slice(0, 5)
			# console.log("send #{sources_to_use.length} sources to client")
			# for source in shuffle(sources).slice(0, 5)

			if sources.length is 5
				for source in sources
					stream = ss.createStream()
					# Note: path to the file being streamed is leaked
					ss(socket).emit("sound:#{query_id}", stream, source.metadata)
					stream.pipe source.createReadStream()


app.use(express.static("client"))

app.get "/", (req, res)->
	res.sendFile("client/app.html", root: __dirname + "/..")


http.listen server_port, ->
	console.log """
		.--------------------------------------------------- - - -
		| Listening on #{app_origin}
		'--------------------------------------------------- - - -
	"""
