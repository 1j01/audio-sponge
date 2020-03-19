generate_button = document.querySelector(".generate-button")
songs_output_ul = document.querySelector(".songs-output")

button_label = generate_button.querySelector(".button-label")
status_indicator = document.querySelector(".status-indicator")
attribution_links_ul = document.querySelector(".attribution-links")

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
			# when "connecting"
			# 	"Connecting..."
			when "offline"
				"Offline"
			when "live"
				"Online"
	button_label.innerHTML =
		if generating
			"Generating Song..."
		else
			"Generate Song"

fetch_audio_buffer = (callback)->
	fetch("/some-sound")
		.then (response)->
			if response.status isnt 200
				throw new Error("HTTP #{response.status} #{response.statusText}")
			response.arrayBuffer()
		.then (array_buffer)->
			if array_buffer.byteLength is 0
				throw new Error("array_buffer.byteLength is 0")
			audioContext.decodeAudioData(array_buffer)
		.then(
			(audio_buffer)-> callback(null, audio_buffer)
			(error)-> callback(error)
		)


generate_button.onclick = ->

	window.audioContext ?= new (window.AudioContext || window.webkitAudioContext)()

	update generating: true

	audio_buffers = []

	target = 5
	active = 0
	parallelism = 2

	get_one = ->
		active += 1
		setTimeout ->
			fetch_audio_buffer((error, audio_buffer)->
				active -= 1
				if error
					console.warn(error)
				else
					audio_buffers.push(audio_buffer)
					console.log("collected #{audio_buffers.length} audio buffers so far")
					if audio_buffers.length is target
						console.log("reached target of #{target} audio buffers")
						got_audio_buffers()
					if audio_buffers.length > target
						console.log("extraneous audio buffer collected (#{audio_buffers.length} / #{target})")
				console.log("collected #{audio_buffers.length} audio buffers so far, plus #{active} active requests; target: #{target}")
				if audio_buffers.length + active < target
					get_one()
			)
		, Math.random() * 500

	for [0..parallelism]
		get_one()
	
	song_output_li = document.createElement("li")
	song_output_audio = document.createElement("audio")
	song_download_link = document.createElement("a")
	song_output_audio.controls = true
	song_download_link.textContent = "download"
	song_download_link.download = "generated-song.ogg"
	song_output_li.appendChild(song_download_link)
	song_output_li.appendChild(song_output_audio)
	songs_output_ul.appendChild(song_output_li)

	got_audio_buffers = ->

		update generating: false

		destination = window.audioContext.createMediaStreamDestination()
		mediaRecorder = new MediaRecorder(destination.stream)
		mediaRecorder.start()

		song = new Song([audio_buffers...], ()-> mediaRecorder.stop())

		song.connect(destination)

		# song.connect(window.audioContext.destination)
		song_output_audio.srcObject = destination.stream
		song_output_audio.play()

		chunks = []
		mediaRecorder.ondataavailable = (event)->
			chunks.push(event.data)

		mediaRecorder.onstop = (event)->
			# Make blob out of our blobs, and open it.
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

update_attribution = (attribution)->
	# TODO: diff-based updates
	# not for performance, just so selection can work better; currently the selection gets cleared unnecessarily
	# and so inspecting the DOM is easier
	attribution_links_ul.innerHTML = ""
	for source in attribution.sources
		li = document.createElement("li")
		provider_icon = document.createElement("i")
		provider_icon.className = (provider_to_icon[source.provider] ? "icon-file-audio") + " provider-icon"
		provider_icon.title = provider_to_acquisition_method_description[source.provider] ? "Procured somehow, probably"
		li.appendChild(provider_icon)
		track_link = document.createElement("a")
		track_link.textContent = source.name or "something"
		if source.link
			track_link.href = source.link
			track_link.setAttribute("target", "_blank")
		li.appendChild(track_link)
		if source.author?.link or source.author?.name
			author_link = document.createElement("a")
			author_link.textContent = source.author?.name or "someone"
			if source.author?.link
				author_link.href = source.author.link
				author_link.setAttribute("target", "_blank")
			li.appendChild(document.createTextNode(" by "))
			li.appendChild(author_link)
		li.appendChild(document.createTextNode(" (#{source.number_of_samples} samples)"))
		attribution_links_ul.appendChild(li)

check_attribution = ->
	req = new XMLHttpRequest()
	req.addEventListener "readystatechange", ->
		# console?.log "readystatechange", req.readyState, req.status
		if req.readyState is 4
			if req.status in [0, 200]
				# update status: "live"
				try
					attribution = JSON.parse(req.responseText)
				catch error
					console.error "Invalid JSON response", {responseText: req.responseText, error}
				if attribution
					update_attribution(attribution)
			else
				# update status: "offline"
	req.addEventListener "error", ->
		# console?.log "error", arguments
		# update status: "offline"
	req.open("GET", "attribution")
	req.send()

check_status = ->
	# TODO: check status via attribution checking?
	req = new XMLHttpRequest()
	req.addEventListener "readystatechange", ->
		# console?.log "readystatechange", req.readyState, req.status
		if req.readyState is 4
			if req.status in [0, 200]
				update status: "live"
			else
				update status: "offline"
	req.addEventListener "error", ->
		# console?.log "error", arguments
		update status: "offline"
	req.open("GET", "ping")
	req.send()

do periodically_check_status_and_attribution = ->
	unless document.hidden
		check_status()
		check_attribution()
	setTimeout periodically_check_status_and_attribution, 5000
