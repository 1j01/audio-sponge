
fs = require "fs"
SC = require "node-soundcloud"

accessToken = try fs.readFileSync("soundcloud-access-token", "utf8")

# Initialize client 
console.log "init node-soundcloud"
SC.init
	id: "99859bbbc016945344ec5ba5731400b4"
	secret: fs.readFileSync("soundcloud-api.secret", "utf8")
	uri: "http://localhost:3901/okay"
	accessToken: accessToken

# Connect user to authorize application 
initOAuth = (req, res)->
	res.redirect(SC.getConnectUrl())

auth = (code, callback)->
	if accessToken
		console.log "reusing access token: #{accessToken}"
		process.nextTick ->
			callback(null, accessToken)
	else
		console.log "getting new access token for #{code}"
		SC.authorize code, (err, newAccessToken)->
			accessToken = newAccessToken
			callback(err, accessToken)

redirectHandler = (req, res)->
	auth req.query.code, (err, accessToken)->
		return console.error err if err
		console.log "got access token:", accessToken
		return console.error "accessToken should not be #{accessToken}" unless accessToken
		
		fs.writeFile "soundcloud-access-token", accessToken, "utf8",
		
		res.redirect("/")

express = require "express"
app = express()

app.get "/", (req, res)->
	if accessToken
		
		# SC.get "/tracks/164497989", (err, track)->
		# 	throw err if err
		# 	console.log track
		
		console.log "get /me"
		SC.get "/me", (err, me)->
			return console.error err if err
			SC.get "/tracks/13158665", (err, track)->
				return console.error err if err
				res.send("""
					<!doctype html>
					<html>
						<head>
							<title>SoundClowning Around</title>
							<style>
								body {
									font-family: sans-serif;
								}
								code.block {
									display: block;
									white-space: pre-wrap;
									background: black;
									color: white;
									padding: 1em;
								}
							</style>
						</head>
						<body>
							<h1>SoundClowning Around</h1>
							<p>Authenticated as #{me.username}</p>
							<h2>Track Data</h2>
							<code class="block">#{JSON.stringify(track, null, "\t")}</code>
							<h2>Empty Audio Element</h2>
							<audio controls <!--src="#{track.stream_url}"-->></audio>
						</body>
					</html>
				""")
		
		# http://api.soundcloud.com/tracks/275207096/stream
	else
		initOAuth(req, res)

app.get "/okay", (req, res)->
	if accessToken
		res.redirect("/")
	else
		redirectHandler(req, res)

app.listen 3901, ->
	console.log "listening on http://localhost:3901"
