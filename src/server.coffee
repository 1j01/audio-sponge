fs = require "fs"
get_env_var = require "./get-env-var"
express = require "express"
Sponge = require "./Sponge"

server_port = get_env_var "PORT", default: 3901, number: yes
app_hostname = get_env_var "APP_HOSTNAME", default: "localhost"
now_url = get_env_var "NOW_URL"
app_origin = now_url or get_env_var "APP_ORIGIN", default: "http://#{app_hostname}:#{server_port}"

app = express()

app.use(express.static("public"))

app.get "/", (req, res)->
	res.sendFile("public/app.html", root: __dirname + "/..")


sponge = new Sponge
sponge.gatherSources()

app.get "/some-sound", (req, res)->
	index = ~~(Math.random() * sponge.sources.length)
	source = sponge.sources[index]
	console.log("from #{sponge.sources.length} sources, picked:", source.uri)

	res.setHeader "Cache-Control", "no-store, must-revalidate"
	res.setHeader "Expires", "0"
	res.setHeader "Content-Type", "application/octet-stream"
	# res.setHeader "Content-Length", byteLength

	# TODO: don't try to pipe twice from the same stream
	source.readStream.pipe(res)

app.get "/attribution", (req, res)->
	res.setHeader "Cache-Control", "no-store, must-revalidate"
	res.setHeader "Expires", "0"
	# TODO: eventually drop sources, so that this list doesn't get ridiculous
	res.json({
		sources: (source.metadata for source in sponge.sources)
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
