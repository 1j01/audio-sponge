
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
	url = SC.getConnectUrl()
	
	res.writeHead(301, Location: url)
	res.end()

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
	{code} = req.query
	
	auth code, (err, accessToken)->
		return console.error err if err
		# Client is now authorized and able to make API calls 
		console.log "got access token:", accessToken
		return console.error "accessToken should not be #{accessToken}" unless accessToken
		
		fs.writeFileSync("soundcloud-access-token", accessToken, "utf8")
		
		# SC.get "/tracks/164497989", (err, track)->
		# 	throw err if err
		# 	console.log track
		
		res.write("access token: #{accessToken}<br><br>")
		
		console.log "get /me"
		SC.get "/me", (err, data)->
			return console.error err if err
			console.log data
			res.end(JSON.stringify(data))
		
		# http://api.soundcloud.com/tracks/275207096/stream

express = require "express"
app = express()

app.get "/", initOAuth
app.get "/okay", redirectHandler

app.listen 3901, ->
	console.log "listening on http://localhost:3901"
