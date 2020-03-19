fs = require "fs"
express = require "express"
get_env_var = require "./get-env-var"
gather_audio = require "./gather-audio"

server_port = get_env_var "PORT", default: 3901, number: yes
app_hostname = get_env_var "APP_HOSTNAME", default: "localhost"
now_url = get_env_var "NOW_URL"
app_origin = now_url or get_env_var "APP_ORIGIN", default: "http://#{app_hostname}:#{server_port}"

app = express()

app.use(express.static("client"))

app.get "/", (req, res)->
	res.sendFile("client/app.html", root: __dirname + "/..")


sources = []
gather_audio((new_source)-> sources.push(new_source))

app.get "/some-sound", (req, res)->
	if sources.length is 0
		res.status(404).send("Not enough sources collected yet!") # 425 isn't really relevant

	index = ~~(Math.random() * sources.length)
	source = sources[index]
	console.log("from #{sources.length} sources, picked:", source.uri)

	res.setHeader "Cache-Control", "no-store, must-revalidate"
	res.setHeader "Expires", "0"
	res.setHeader "Content-Type", "application/octet-stream"
	# res.setHeader "Content-Length", byteLength

	source.createReadStream().pipe(res)

app.get "/attribution", (req, res)->
	res.setHeader "Cache-Control", "no-store, must-revalidate"
	res.setHeader "Expires", "0"
	# TODO: eventually drop sources, so that this list doesn't get ridiculous
	res.json({
		sources: (source.metadata for source in sources)
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
