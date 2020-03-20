keywords_input = document.querySelector(".keywords-input")
generate_button = document.querySelector(".generate-button")
songs_output_ul = document.querySelector(".songs-output")
status_indicator = document.querySelector(".status-indicator")

state = {}
update = (new_state)->
	status_indicator.classList.remove(state.status)
	state[k] = v for k, v of new_state
	{status, generating} = state
	status_indicator.classList.add(status)
	status_indicator.innerHTML =
		switch status
			when "loading"
				"Checking..."
			when "offline"
				"Offline"
			when "online"
				"Online"
	generate_button.disabled = generating
	generate_button.value =
		if generating
			"Generating Song..."
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


generate_button.onclick = ->

	window.audioContext ?= new (window.AudioContext || window.webkitAudioContext)()

	update generating: true

	audio_buffers = []
	metadatas_received = []
	metadatas_used = []

	# TODO: sanitize for filename, and better ID
	query_id = keywords_input.value + Math.random()
	song_id = "song-#{query_id}"

	socket.emit "sound-search", {query: keywords_input.value, query_id}
	socket.on "sound-metadata:#{query_id}", (metadata)->
		metadatas_received.push(metadata)
		{sound_id} = metadata
		array_buffers = []
		socket.on "sound-data:#{sound_id}", (buffer)->
			array_buffers.push(buffer)
		socket.once "sound-data-end:#{sound_id}", ->
			socket.off "sound-data:#{sound_id}"
			array_buffer = concatArrayBuffers(array_buffers)

			audioContext.decodeAudioData(array_buffer).then(
				(audio_buffer)->
					audio_buffers.push(audio_buffer)
					metadatas_used.push(metadata)
					console.log "collected #{audio_buffers.length} audio buffers so far"
					if audio_buffers.length is 5
						got_audio_buffers()
				(error)-> console.warn(error)
			)

	setTimeout ->
		socket.off "sound-metadata:#{query_id}"
		for {sound_id} in metadatas_received
			socket.off "sound-data:#{sound_id}"
			socket.off "sound-data-end:#{sound_id}"
		if audio_buffers.length > 0
			got_audio_buffers()
		else
			update generating: false
			alert "Couldn't find enough tracks to sample from."
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
	# 					got_audio_buffers()
	# 				if audio_buffers.length > target
	# 					console.log("extraneous audio buffer collected (#{audio_buffers.length} / #{target})")
	# 			console.log("collected #{audio_buffers.length} audio buffers so far, plus #{active} active requests; target: #{target}")
	# 			if audio_buffers.length + active < target
	# 				get_one()
	# 		)
	# 	, Math.random() * 500

	# for [0..parallelism]
	# 	get_one()
	
	song_output_li = document.createElement("li")
	song_output_li.className = "song"
	song_audio_row = document.createElement("div")
	song_audio_row.className = "song-audio-row"
	song_output_audio = document.createElement("audio")
	song_download_link = document.createElement("a")
	song_output_audio.controls = true
	song_download_link.textContent = "download"
	song_download_link.className = "download-link"
	song_download_link.download = "#{song_id}.ogg"
	song_audio_row.appendChild(song_download_link)
	song_audio_row.appendChild(song_output_audio)
	song_output_li.appendChild(song_audio_row)
	songs_output_ul.appendChild(song_output_li)

	already_started = false
	got_audio_buffers = ->
		return if already_started
		already_started = true

		update generating: false
		song_output_li.appendChild(show_attribution(metadatas_used, song_id))

		destination = window.audioContext.createMediaStreamDestination()
		mediaRecorder = new MediaRecorder(destination.stream)
		mediaRecorder.start()

		song = new Song([audio_buffers...], ()-> mediaRecorder.stop())

		song.connect(destination)

		song_output_audio.srcObject = destination.stream
		song_output_audio.play()

		chunks = []
		mediaRecorder.ondataavailable = (event)->
			chunks.push(event.data)

		mediaRecorder.onstop = (event)->
			blob = new Blob(chunks, { 'type' : 'audio/ogg; codecs=opus' })
			blob_url = URL.createObjectURL(blob)

			currentTime = song_output_audio.currentTime
			song_output_audio.srcObject = null
			song_output_audio.src = blob_url
			song_output_audio.currentTime = currentTime
			song_download_link.href = blob_url

provider_to_icon =
	"filesystem": "icon-folder"
	"soundcloud": "icon-soundcloud"
	"spotify": "icon-spotify"
	"bandcamp": "icon-bandcamp"
	"lastfm": "icon-lastfm"
	"opengameart": "icon-globe" # TODO: specific icon (probably ditch this font icon business, and use favicons)

provider_to_acquisition_method_description =
	"filesystem": "Via the filesystem"
	"soundcloud": "Via the SoundCloud API"
	# "spotify": "Via the Spotify API"
	# "bandcamp": "Via the Bandcamp API"
	# "lastfm": "Via the Last.fm API"
	# "napster": "Via the Napster API"
	"opengameart": "Scraped from OpenGameArt.org"

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
