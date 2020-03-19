fs = require "fs"
request = require "request"

# TODO: this doesn't need to be a class
# if it is a class, maybe it should be an EventEmitter
module.exports =
class Source
	constructor: (uri, @metadata)->
	# constructor: (@metadata, @stream)->
		@metadata.number_of_samples = 0
		# should just accept a stream (pcm and format?)
		if uri.match(/^http[s]:/)
			@uri = uri
			@readStream = request(uri, qs: client_id: process.env.SOUNDCLOUD_CLIENT_ID)
		else
			file_path = uri
			@uri = "file:///#{file_path}"
			@readStream = fs.createReadStream(file_path)

	toString: -> @uri
