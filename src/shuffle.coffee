module.exports = (array) ->
	array = Array.from(array)
	i = array.length
	while --i > 0
		j = ~~(Math.random() * (i + 1))
		temp = array[j]
		array[j] = array[i]
		array[i] = temp
	return array
