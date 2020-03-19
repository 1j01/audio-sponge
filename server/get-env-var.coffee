module.exports = (var_name, options={})->
	if options.required and options.default?
		throw new TypeError "options.required and options.default can't both be specified, silly"
	value = process.env[var_name]
	if options.required and not value?
		throw new Error("environment variable #{var_name} required#{
			if options.number then " (should be a number)" else ""
		}")
	if options.number and value?
		value = parseFloat(value)
		if isNaN(value)
			throw new Error("environment variable #{var_name} #{
				if options.required then "must" else "should"
			} be a number#{
				if options.required then "" else " if present"
			} (got #{
				JSON.stringify(process.env[var_name])
			})")
	# could (easily) have a validation function
	# options.validate?(value)
	# but would that even be easier than checking the value after get_env_var?
	# I don't think so, unless it's a helper for giving useless error messages
	# could also have helpers for like min and max and stuff, but that can get infinitely complex
	return value ? options.default
