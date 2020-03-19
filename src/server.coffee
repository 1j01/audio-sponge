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

Sponge = require "./Sponge"

sponge = new Sponge

sponge.start (err, context)->
	if err
		console.error err
		console.log "The server will exit shortly."
		setTimeout ->
			process.exit(1)
		, 200
		# TODO: exit more cleanly? like end the server and such

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
