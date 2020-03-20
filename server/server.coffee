fs = require "fs"
express = require "express"
get_env_var = require "./get-env-var"
gather_audio = require "./gather-audio"

server_port = get_env_var "PORT", default: 3901, number: yes
app_hostname = get_env_var "APP_HOSTNAME", default: "localhost"
now_url = get_env_var "NOW_URL"
app_origin = now_url or get_env_var "APP_ORIGIN", default: "http://#{app_hostname}:#{server_port}"

app = express()
http = require("http").createServer(app)
io = require("socket.io")(http)


io.on "connection", (socket)->
	console.log("a user connected")
	socket.on "disconnect", ->
		console.log("user disconnected")

app.use(express.static("client"))

app.get "/", (req, res)->
	res.sendFile("client/app.html", root: __dirname + "/..")


sources = []
gather_audio (new_source)->
	sources.push(new_source)
	io.emit("attribution", {
		sources: (source.metadata for source in sources)
	})

app.get "/some-sound", (req, res)->
	if sources.length is 0
		res.status(404).send("Not enough sources collected yet!") # 425 isn't really relevant
		return

	index = ~~(Math.random() * sources.length)
	source = sources[index]
	console.log("from #{sources.length} sources, picked:", source.uri)

	res.setHeader "Cache-Control", "no-store, must-revalidate"
	res.setHeader "Expires", "0"
	res.setHeader "Content-Type", "application/octet-stream"
	# res.setHeader "Content-Length", byteLength

	source.createReadStream().pipe(res)


http.listen server_port, ->
	console.log """
		.--------------------------------------------------- - - -
		| Listening on #{app_origin}
		'--------------------------------------------------- - - -
	"""
