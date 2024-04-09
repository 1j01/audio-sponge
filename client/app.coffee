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
			"Collecting Videos..."
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


sound_search = ({query, song_id, midi}, on_progress, callback)->
	query_id = "#{if midi then "midi" else "sounds"}-for-#{song_id}"

	metadatas_received = []
	console.log "Searching for", {query, midi, query_id}
	socket.emit "sound-search", {query, midi, query_id}
	socket.on "sound-metadata:#{query_id}", (metadata)->
		metadatas_received.push(metadata)
		{sound_id} = metadata
		chunk_array_buffers = []
		socket.on "sound-data:#{sound_id}", (array_buffer)->
			chunk_array_buffers.push(array_buffer)
			on_progress()
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
	song_id = sanitizeFileName("song-#{generateId(6)}-#{query}").replace(/\s/g, "-")

	song_output_li = document.createElement("li")
	song_output_li.className = "song"
	song_search_terms = document.createElement("div")
	song_search_terms.className = "song-search-terms"
	song_search_terms.textContent = "🔎 #{query}"
	song_search_terms.onclick = -> keywords_input.value = query
	song_status = document.createElement("div")
	song_status.className = "song-status"
	song_status.textContent = "Collecting Videos..."
	song_audio_row = document.createElement("div")
	song_audio_row.className = "song-audio-row"
	song_output_audio = document.createElement("audio")
	song_output_audio.controls = true
	song_output_li.appendChild(song_search_terms)
	song_audio_row.appendChild(song_status)
	song_audio_row.appendChild(song_output_audio)
	song_output_li.appendChild(song_audio_row)
	songs_output_ul.prepend(song_output_li)

	song_output_canvas = document.createElement("canvas")
	song_output_canvas.width = 640
	song_output_canvas.height = 480
	song_output_ctx = song_output_canvas.getContext("2d")
	song_audio_row.appendChild(song_output_canvas)

	source_videos = []
	audio_buffers = []
	# midi_array_buffer = null
	collection_tid = null

	on_progress = ->
		clearTimeout(collection_tid)
		collection_tid = setTimeout collection_timed_out, 1000 * 60

	# cancel_getting_midi = sound_search {query, song_id, midi: true}, on_progress, (file_array_buffer, metadata)->
	# 	console.log "Got a midi file", metadata

	# 	midi_array_buffer ?= file_array_buffer
	# 	metadatas_used.push(metadata) if midi_array_buffer is file_array_buffer

	# 	check_sources_ready()
		
	# 	# actually,
	# 	cancel_getting_midi()
	# 	# and then we don't really need the ?= and if above, but whatever
	
	canceled = false
	cancel_getting_audio = sound_search {query, song_id}, on_progress, (file_array_buffer, metadata)->
		return if canceled
		console.log "Got a sound file (decoding...)", metadata
		
		# TODO: is new Uint8Array necessary?
		video_blob = new Blob([new Uint8Array(file_array_buffer)])
		video_blob_uri = URL.createObjectURL(video_blob)
		video = document.createElement("video")
		# song_audio_row.appendChild(video)
		video.src = video_blob_uri
		source_videos.push(video)

		audioContext.decodeAudioData(file_array_buffer).then(
			(audio_buffer)->
				return if canceled
				audio_buffer.video = video # HACK
				audio_buffers.push(audio_buffer)
				metadatas_used.push(metadata)
				console.log "Collected #{audio_buffers.length} audio buffers so far"
				check_sources_ready()
			(error)-> console.warn(error)
		)

	cancel = ->
		# cancel_getting_midi()
		cancel_getting_audio()
		canceled = true
		clearTimeout(collection_tid)

	check_sources_ready = ->
		if audio_buffers.length >= 5
			# if midi_array_buffer
				sources_ready()

	collection_timed_out = ->
		cancel()
		if audio_buffers.length >= 1
			# if midi_array_buffer
				sources_ready()
				return
			# else
			# 	message = "Didn't find a midi track to base the structure off of."
		else
			# if midi_array_buffer
				message = "Didn't find enough tracks to sample from."
			# else
			# 	message = "Didn't find enough tracks to sample from, and didn't find a midi track to base the structure off of."
		if socket.disconnected
			message = "Offline. Server access needed to fetch sound sources."
		update collecting: false
		alert message
		song_status.textContent = "Failed"
		song_output_li.classList.add("failed")
	
	clearTimeout collection_tid
	collection_tid = setTimeout collection_timed_out, 1000 * 60

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
			# console.trace "stop_generating", song_id
			# console.log {tid, "cancel_button.parentElement": cancel_button.parentElement, song}
			mediaRecorder?.stop()
			song?.output.disconnect()
			song = null
			clearTimeout tid
			cancel_button.remove()

		cancel_button = document.createElement("button")
		cancel_button.onclick = stop_generating
		cancel_button.textContent = "Stop"
		song_status.appendChild(cancel_button)

		song_output_li.appendChild(show_attribution(metadatas_used, song_id))

		try 
			# song = new Song([audio_buffers...], midi_array_buffer)
			song = new Song([audio_buffers...])
		catch error
			console.error error
			stop_generating()
			song_status.textContent = "Failed"
			song_output_li.classList.add("failed")
			return

		destination = window.audioContext.createMediaStreamDestination()
		video_stream = song_output_canvas.captureStream(30)
		video_stream.addTrack(destination.stream.getAudioTracks()[0])
		mediaRecorder = new MediaRecorder(video_stream)
		mediaRecorder.start()

		song.output.connect(destination)
		end_time = song.schedule()

		song_output_audio_time_at_last_raf = song_output_audio.currentTime
		# memory and CPU usage leak (keep looping since the audio could be played again)
		_song = song
		animate = ->
			requestAnimationFrame(animate)
			if not song_output_audio.paused and not song_output_audio.ended and song_output_audio.currentTime > 0
				song_output_ctx.clearRect(0, 0, song_output_canvas.width, song_output_canvas.height)
				for video_event in _song.video_events
					if song_output_audio_time_at_last_raf <= video_event.timeInAudioOutput < song_output_audio.currentTime
						if video_event.type is "play"
							video_event.video.currentTime = video_event.startTimeInVideo
							video_event.video.muted = true
							video_event.video.play()
						if video_event.type is "pause"
							video_event.video.pause()
				for video, index in source_videos
					if not video.paused and not video.ended and video.currentTime > 0
						song_output_ctx.drawImage(video, index * 50, 0)
				song_output_audio_time_at_last_raf = song_output_audio.currentTime
		animate()
		stop_video = ->
			for video in source_videos
				video.pause()

		song_output_audio.addEventListener("pause", stop_video)
		song_output_audio.addEventListener("ended", stop_video)
		song_output_audio.addEventListener("error", stop_video)

		tid = setTimeout(stop_generating, end_time * 1000)

		song_output_audio.srcObject = destination.stream
		song_output_audio.play()

		chunks = []
		mediaRecorder.ondataavailable = (event)->
			chunks.push(event.data)

		mediaRecorder.onstop = (event)->
			blob = new Blob(chunks, { 'type' : 'video/webm' })
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
			song_download_link.download = "#{song_id}.webm"
			song_status.innerHTML = ""
			song_status.appendChild(song_download_link)


provider_to_acquisition_method_description =
	"filesystem": "Via the filesystem"
	"soundcloud": "Via the SoundCloud API"
	"youtube": "Via YouTube"
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
	attribution_links_summary.textContent = "Sources"
	attribution_links_ul = document.createElement("ul")
	attribution_links_ul.className = "attribution-links"
	attribution_links_details.appendChild(attribution_links_ul)
	for metadata in metadatas
		li = document.createElement("li")
		provider_icon = document.createElement("img")
		provider_icon.width = 16
		provider_icon.height = 16
		provider_icon.src = new URL(metadata.link).origin + "/favicon.ico"
		provider_icon.className = "provider-icon"
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
				<meta charset="utf-8">
				<title>Attribution</title>
				<style>
					.attribution-links {
						text-align: left;
						list-style-type: none;
					}
					.attribution-links li {
						padding: 0.2em;
					}
					.provider-icon {
						margin-right: 0.3em;
						vertical-align: middle;
					}
				</style>
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
