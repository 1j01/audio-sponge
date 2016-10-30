
# based on https://github.com/AlekseyMartynov/cafe-content/blob/5f0e410959c412d60be79917a65eb824908a6ff6/server-node/throttle.js

through2 = require "through2"
{TokenBucket} = require "limiter"

module.exports = (rate, chunkSize, initialBurst)->
	bucket = new TokenBucket(rate, rate, "second")
	
	step = (stream, chunk, pos, callback)->
		nextPos = pos + chunkSize
		slice = chunk.slice(pos, nextPos)
		len = slice.length
		
		nextStep = ->
			step(stream, chunk, nextPos, callback)
		
		return callback() unless len
		
		if initialBurst > 0
			initialBurst -= len
			console.log "burst #{len}"
			stream.push(slice)
			process.nextTick(nextStep)
		
		bucket.removeTokens len, (err)->
			return callback err if err
			console.log "rated #{len}"
			stream.push(slice)
			nextStep()
	
	through2 (chunk, encoding, callback)->
		step(@, chunk, 0, callback)
