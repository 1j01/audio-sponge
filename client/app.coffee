generate_form = document.querySelector(".generate-form")
keywords_input = document.querySelector(".keywords-input")
generate_button = document.querySelector(".generate-button")
songs_output_ul = document.querySelector(".songs-output")
status_indicator = document.querySelector(".status-indicator")

generate_form.onsubmit = (event)-> event.preventDefault()

state = {}
update = (new_state)->
	status_indicator.classList.remove(state.status)
	state[k] = v for k, v of new_state
	{status, collecting} = state
	status_indicator.classList.add(status)
	status_indicator.innerHTML =
		switch status
			when "loading"
				"Checking..."
			when "offline"
				"Offline"
			when "online"
				"Online"
	generate_button.disabled = collecting
	generate_button.value =
		if collecting
			"Collecting Sounds..."
		else
			"Generate Song"


concatArrayBuffers = (arrayBuffers)->
	offset = 0
	bytes = 0
	arrayBuffers.forEach (buf)->
		bytes += buf.byteLength
	combined = new ArrayBuffer(bytes)
	store = new Uint8Array(combined)
	arrayBuffers.forEach (buf)->
		store.set(new Uint8Array(buf.buffer ? buf, buf.byteOffset), offset)
		offset += buf.byteLength
	return combined

generateId = (len=40)->
	to_hex = (n)-> "0#{n.toString(16)}".substr(-2)
	arr = new Uint8Array(len / 2)
	window.crypto.getRandomValues(arr)
	Array.from(arr, to_hex).join('')


# Taken from https://github.com/parshap/node-sanitize-filename/blob/master/index.js
# but without utf8 truncation, just a slice.
# I haven't looked into the security implications of that because the browser will already do sanitization on this,
# I just want to control the resulting filename.
sanitizeFileName = (input, replacement="")->
	if typeof input isnt "string"
		throw new TypeError("input must be a string")
	illegalRe = /[\/\?<>\\:\*\|"]/g
	controlRe = /[\x00-\x1f\x80-\x9f]/g
	reservedRe = /^\.+$/
	windowsReservedRe = /^(con|prn|aux|nul|com[0-9]|lpt[0-9])(\..*)?$/i
	windowsTrailingRe = /[\. ]+$/
	input
		.replace(illegalRe, replacement)
		.replace(controlRe, replacement)
		.replace(reservedRe, replacement)
		.replace(windowsReservedRe, replacement)
		.replace(windowsTrailingRe, replacement)
		.slice(0, 255)


sound_search = ({query, song_id, midi}, callback)->
	query_id = "#{if midi then "midi" else "sounds"}-for-#{song_id}"

	metadatas_received = []
	socket.emit "sound-search", {query, midi, query_id}
	socket.on "sound-metadata:#{query_id}", (metadata)->
		metadatas_received.push(metadata)
		{sound_id} = metadata
		chunk_array_buffers = []
		socket.on "sound-data:#{sound_id}", (array_buffer)->
			chunk_array_buffers.push(array_buffer)
		socket.once "sound-data-end:#{sound_id}", ->
			socket.off "sound-data:#{sound_id}"
			file_array_buffer = concatArrayBuffers(chunk_array_buffers)
			chunk_array_buffers = null
			callback(file_array_buffer, metadata)
			file_array_buffer = null

	cancel = ->
		socket.off "sound-metadata:#{query_id}"
		for {sound_id} in metadatas_received
			socket.off "sound-data:#{sound_id}"
			socket.off "sound-data-end:#{sound_id}"

	return cancel



generate_button.onclick = ->

	window.audioContext ?= new (window.AudioContext || window.webkitAudioContext)()

	update collecting: true

	audio_buffers = []
	metadatas_used = []

	query = keywords_input.value
	song_id = sanitizeFileName("song-#{generateId(6)}-#{query}").replace(/\s/, "-")

	song_output_li = document.createElement("li")
	song_output_li.className = "song"
	song_search_terms = document.createElement("div")
	song_search_terms.className = "song-search-terms"
	song_search_terms.textContent = "🔎 #{query}"
	song_search_terms.onclick = -> keywords_input.value = query
	song_status = document.createElement("div")
	song_status.className = "song-status"
	song_status.textContent = "Collecting sounds..."
	song_audio_row = document.createElement("div")
	song_audio_row.className = "song-audio-row"
	song_output_audio = document.createElement("audio")
	song_output_audio.controls = true
	song_output_li.appendChild(song_search_terms)
	song_audio_row.appendChild(song_status)
	song_audio_row.appendChild(song_output_audio)
	song_output_li.appendChild(song_audio_row)
	songs_output_ul.prepend(song_output_li)

	audio_buffers = []
	midi_array_buffer = null

	cancel_getting_midi = sound_search {query, song_id, midi: true}, (file_array_buffer, metadata)->
		console.log "found a midi:", {file_array_buffer, metadata}
		midi_array_buffer ?= file_array_buffer
		check_sources_ready()
		metadatas_used.push(metadata) if midi_array_buffer is file_array_buffer
		# actually,
		cancel_getting_midi()
		# and then we don't really need the ?= and if above, but whatever
	
	cancel_getting_audio = sound_search {query, song_id}, (file_array_buffer, metadata)->
		console.log "found a sound:", {file_array_buffer, metadata}
		
		audioContext.decodeAudioData(file_array_buffer).then(
			(audio_buffer)->
				audio_buffers.push(audio_buffer)
				metadatas_used.push(metadata)
				console.log "collected #{audio_buffers.length} audio buffers so far"
				check_sources_ready()
			(error)-> console.warn(error)
		)

	cancel = ->
		cancel_getting_midi()
		cancel_getting_audio()

	check_sources_ready = ->
		if audio_buffers.length >= 5
			if midi_array_buffer
				sources_ready()

	setTimeout ->
		cancel()
		if audio_buffers.length >= 1
			if midi_array_buffer
				sources_ready()
				return
			else
				message = "Didn't find a midi track to base the structure off of."
		else
			if midi_array_buffer
				message = "Didn't find enough tracks to sample from."
			else
				message = "Didn't find enough tracks to sample from, and didn't find a midi track to base the structure off of."
		if socket.disconnected
			message = "Offline. Server access needed to fetch sound sources."
		update collecting: false
		alert message
		song_status.textContent = "Failed"
		song_output_li.classList.add("failed")
	, 1000 * 10

	# target = 5
	# active = 0
	# parallelism = 2

	# get_one = ->
	# 	active += 1
	# 	setTimeout ->
	# 		fetch_audio_buffer((error, audio_buffer)->
	# 			active -= 1
	# 			if error
	# 				console.warn(error)
	# 			else
	# 				audio_buffers.push(audio_buffer)
	# 				console.log("collected #{audio_buffers.length} audio buffers so far")
	# 				if audio_buffers.length is target
	# 					console.log("reached target of #{target} audio buffers")
	# 					sources_ready()
	# 				if audio_buffers.length > target
	# 					console.log("extraneous audio buffer collected (#{audio_buffers.length} / #{target})")
	# 			console.log("collected #{audio_buffers.length} audio buffers so far, plus #{active} active requests; target: #{target}")
	# 			if audio_buffers.length + active < target
	# 				get_one()
	# 		)
	# 	, Math.random() * 500

	# for [0..parallelism]
	# 	get_one()
	
	already_started = false
	sources_ready = ->
		return if already_started
		already_started = true

		update collecting: false
		song_status.textContent = "Generating..."

		song = null
		tid = null
		stop_generating = ->
			console.trace "stop_generating", song_id
			console.log {tid, "cancel_button.parentElement": cancel_button.parentElement, song}
			mediaRecorder.stop()
			song.output.disconnect()
			song = null
			clearTimeout tid
			cancel_button.remove()

		cancel_button = document.createElement("button")
		cancel_button.onclick = stop_generating
		cancel_button.textContent = "Stop"
		song_status.appendChild(cancel_button)

		song_output_li.appendChild(show_attribution(metadatas_used, song_id))

		destination = window.audioContext.createMediaStreamDestination()
		mediaRecorder = new MediaRecorder(destination.stream)
		mediaRecorder.start()

		song = new Song([audio_buffers...], midi_array_buffer)
		song.output.connect(destination)
		end_time = song.schedule()
		tid = setTimeout(stop_generating, end_time * 1000)

		song_output_audio.srcObject = destination.stream
		song_output_audio.play()

		chunks = []
		mediaRecorder.ondataavailable = (event)->
			chunks.push(event.data)

		mediaRecorder.onstop = (event)->
			blob = new Blob(chunks, { 'type' : 'audio/ogg; codecs=opus' })
			chunks = null
			blob_url = URL.createObjectURL(blob)

			currentTime = song_output_audio.currentTime
			song_output_audio.srcObject = null
			song_output_audio.src = blob_url
			song_output_audio.currentTime = currentTime
			# FIXME: there's a case where pressing play will play the tiniest bit because it's at the end
			# maybe only set currentTime if it was playing?
			# or compare with duration to see how near it is to the end

			song_download_link = document.createElement("a")
			song_download_link.className = "download-link"
			song_download_link.textContent = "Download"
			song_download_link.href = blob_url
			song_download_link.download = "#{song_id}.ogg"
			song_status.innerHTML = ""
			song_status.appendChild(song_download_link)

provider_to_icon =
	"filesystem": "icon-folder"
	"soundcloud": "icon-soundcloud"
	"spotify": "icon-spotify"
	"bandcamp": "icon-bandcamp"
	"lastfm": "icon-lastfm"
	"opengameart": "icon-globe" # TODO: specific icon (probably ditch this font icon business, and use favicons)
	"bitmidi": "icon-globe" # TODO: specific icon? but it's not very midi-indicative I feel

provider_to_acquisition_method_description =
	"filesystem": "Via the filesystem"
	"soundcloud": "Via the SoundCloud API"
	# "spotify": "Via the Spotify API"
	# "bandcamp": "Via the Bandcamp API"
	# "lastfm": "Via the Last.fm API"
	# "napster": "Via the Napster API"
	"opengameart": "Scraped from OpenGameArt.org"
	"bitmidi": "Scraped from BitMidi.com"

show_attribution = (metadatas, song_id)->
	attribution_links_details = document.createElement("details")
	attribution_links_summary = document.createElement("summary")
	attribution_links_details.appendChild(attribution_links_summary)
	attribution_links_summary.textContent = "Audio Sources"
	attribution_links_ul = document.createElement("ul")
	attribution_links_ul.className = "attribution-links"
	attribution_links_details.appendChild(attribution_links_ul)
	for metadata in metadatas
		li = document.createElement("li")
		provider_icon = document.createElement("i")
		provider_icon.className = (provider_to_icon[metadata.provider] ? "icon-file-audio") + " provider-icon"
		provider_icon.title = provider_to_acquisition_method_description[metadata.provider] ? "Procured somehow, probably"
		li.appendChild(provider_icon)
		track_link = document.createElement("a")
		track_link.textContent = metadata.name or "something"
		if metadata.link
			track_link.href = metadata.link
			track_link.setAttribute("target", "_blank")
		li.appendChild(track_link)
		if metadata.author?.link or metadata.author?.name
			author_link = document.createElement("a")
			author_link.textContent = metadata.author?.name or "someone"
			if metadata.author?.link
				author_link.href = metadata.author.link
				author_link.setAttribute("target", "_blank")
			li.appendChild(document.createTextNode(" by "))
			li.appendChild(author_link)
		# li.appendChild(document.createTextNode(" (#{source.number_of_samples} samples)"))
		attribution_links_ul.appendChild(li)
	
	attribution_html = """
		<!doctype html>
		<html>
			<head>
				<title>Attribution</title>
			</head>
			<body>
				#{attribution_links_ul.outerHTML}
			</body>
		</html>
	"""
	attribution_blob = new Blob([attribution_html], {type: "text/html"})
	attribution_download_link = document.createElement("a")
	attribution_download_link.download = "#{song_id}-attribution.html"
	attribution_download_link.href = URL.createObjectURL(attribution_blob)
	attribution_download_link.textContent = "Download Attribution as HTML"
	attribution_links_details.appendChild(attribution_download_link)

	return attribution_links_details

socket = io()

# give it a bit to connect (while saying "Checking...") before saying "Offline" if it hasn't
setTimeout ->
	update status: if socket.connected then "online" else "offline"
, 500

socket.on "connect", ->
	update status: "online"

socket.on "disconnect", ->
	update status: "offline"
