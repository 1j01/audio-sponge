class @Rhythm
	constructor: ->
		@generate()
	
	generate: ->
		# TODO: we want multiple beats on top of each other
		# this could be achieved here or outside by layering things on the same Rhythms (or both)
		# but TODO: maybe a parameter for how complex the rhythm should be
		# TODO: make it so the set of beat types returned is contiguous from zero,
		# i.e. 0..N and not 1,2,5 (Monty Python reference there)
		gen = (depth)->
			if depth > 1 + Math.random() * 2
				# NOTE: an arbitrary number of beat types is assumed here!
				~~(Math.random() * 20)
			else if Math.random() < 0.1
				a = gen(depth + 1)
				[a, a, a]
			else if Math.random() < 0.5
				a = gen(depth + 1)
				b = gen(depth + 1)
				[a, b]
			else
				a = gen(depth + 1)
				b = gen(depth + 1)
				c = gen(depth + 1)
				if Math.random() < 0.3
					[a, b, a, [c, c, c, c]]
				else
					[a, b, a, c]
		
		@root = gen(0)
	
	getBeats: (arr = @root, outer_offset = 0, scale = 1)->
		beats = []
		for def, i in arr
			def_offset = outer_offset + (i / arr.length) * scale
			# console.log {outer_offset, def_offset, arr, i, scale}
			if Array.isArray(def)
				beats = beats.concat(@getBeats(def, def_offset, scale / arr.length))
			else
				beats.push({time: def_offset, type: def})
		beats
	
	toString: (arr)->
		str = if arr? then "" else "Rhythm "
		arr ?= @root
		str += "["
		for def, i in arr
			if Array.isArray(def)
				str += @toString(def)
			else
				str += (def+10).toString(36)
		str += "]"

test_getBeats = (input_root, expected_beats)->
	r = new Rhythm
	beats = r.getBeats(input_root)
	# TODO or whatever
	# require("assert").deepEqual(beats, expected_beats)

test_getBeats([0, 1], [
	{time: 0, type: 0}
	{time: 1/2, type: 1}
])

test_getBeats([[2, 3]], [
	{time: 0, type: 2}
	{time: 1/2, type: 3}
])

test_getBeats([
	[5, 6]
	[1, 2, 3]
], [
	{time: 0, type: 5}
	{time: 1/4, type: 6}
	{time: 1/2+0/6, type: 1}
	{time: 1/2+1/6, type: 2}
	{time: 1/2+2/6, type: 3}
])
