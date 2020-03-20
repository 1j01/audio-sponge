fs = require "fs"
request = require "request"

# TODO: this doesn't need to be a class
# if it is a class, maybe it should be an EventEmitter
module.exports =
class Source
	constructor: (uri, @metadata)->
	# constructor: (@metadata, @stream)->
		# should just accept a stream (pcm and format?)
		if uri.match(/^http[s]:/)
			@uri = uri
			# TODO: cache?
			@createReadStream = -> request(uri, qs: client_id: process.env.SOUNDCLOUD_CLIENT_ID)
		else
			file_path = uri
			@uri = "file:///#{file_path}"
			@createReadStream = -> fs.createReadStream(file_path)

	toString: -> @uri
