generate_button = document.querySelector(".generate-button")
# listen_button = document.querySelector(".listen-button")
# button_label = listen_button.querySelector(".button-label")
# status_indicator = document.querySelector(".status-indicator")
# attribution_links_ul = document.querySelector(".attribution-links")


fetch_audio_buffer = (callback)->

	url = "/some-sound"

	xhr = new XMLHttpRequest()
	xhr.open("GET", url)
	xhr.responseType = "arraybuffer"
	xhr.onerror = (error)-> callback(error)
	xhr.onload = ->
		if xhr.status is 200
			arraybuffer = xhr.response
			if arraybuffer.byteLength is 0
				callback(new Error("arraybuffer.byteLength is 0"))
				return

			audioContext.decodeAudioData(arraybuffer, (audio_buffer)-> callback(null, audio_buffer))
		else
			callback(new Error("HTTP #{xhr.status}: #{xhr.statusText}"))

	xhr.send()

generate_button.onclick = ->

	window.audioContext ?= new (window.AudioContext || window.webkitAudioContext)()

	audio_buffers = []

	target = 5
	active = 0
	parallelism = 2

	get_one = ->
		active += 1
		fetch_audio_buffer((error, audio_buffer)->
			active -= 1
			if error
				console.error(error)
			else
				audio_buffers.push(audio_buffer)
				console.log("collected #{audio_buffers.length} so far")
				if audio_buffers.length is target
					got_audio_buffers()
			console.log("collected #{audio_buffers.length} so far, plus #{active} active requests; target: #{target}")
			if audio_buffers.length + active < target
				get_one()
		)

	for [0..parallelism]
		get_one()
	
	got_audio_buffers = ->
		song = new Song()
		song.source_samples = [audio_buffers...]
		# findSamplesFromAudioBuffer

# state = {}
# update = (new_state)->
# 	status_indicator.classList.remove(state.status)
# 	state[k] = v for k, v of new_state
# 	{status, listening} = state
# 	status_indicator.classList.add(status)
# 	status_indicator.innerHTML =
# 		switch status
# 			when "loading"
# 				"Checking..."
# 			# when "connecting"
# 			# 	"Connecting..."
# 			when "offline"
# 				"&#9679;&#xFE0E; Offline"
# 			when "live"
# 				"&#9679;&#xFE0E; Live"
# 	button_label.innerHTML =
# 		if listening
# 			"&#11035;&#xFE0E; Stop" # You can't pause yet, sorry
# 		else
# 			"&#9654;&#xFE0E; Listen"

# toggle_listen = ->
# 	if state.listening
# 		audio.pause()
# 		update listening: no
# 	else
# 		# TODO: maybe allow pausing again, but implement other server error handling and reconnecting logic
# 		audio.src = null
# 		audio.src = "stream"
# 		audio.play()
# 		# update status: "connecting"
# 		check_status()

# update status: "loading"
# audio = document.createElement("audio")
# audio.preload = "none"
# audio.src = "stream"
# audio.addEventListener "error", ->
# 	update status: "offline"
# audio.addEventListener "stalled", ->
# 	# FIXME: this is annoying
# 	# I want it to only end the stream if the server is offline
# 	# but it generally only realizes its offline (when the ping fails) *after* the stalled event
# 	# so I'd need to wait for it to go offline and then, I guess if there's been a stalled with no
# 	# play/resume/unstalled/timeupdate or whatever after it, then end the stream (like the following:)
# 	audio.src = null
# audio.addEventListener "play", ->
# 	update listening: yes
# audio.addEventListener "pause", ->
# 	update listening: no
# audio.addEventListener "emptied", ->
# 	update listening: no

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

# check_attribution = ->
# 	req = new XMLHttpRequest()
# 	req.addEventListener "readystatechange", ->
# 		# console?.log "readystatechange", req.readyState, req.status
# 		if req.readyState is 4
# 			if req.status in [0, 200]
# 				# update status: "live"
# 				try
# 					attribution = JSON.parse(req.responseText)
# 				catch error
# 					console.error "Invalid JSON response", {responseText: req.responseText, error}
# 				if attribution
# 					update_attribution(attribution)
# 			else
# 				# update status: "offline"
# 	req.addEventListener "error", ->
# 		# console?.log "error", arguments
# 		# update status: "offline"
# 	req.open("GET", "attribution")
# 	req.send()

# check_status = ->
# 	# TODO: check status via attribution checking?
# 	req = new XMLHttpRequest()
# 	req.addEventListener "readystatechange", ->
# 		# console?.log "readystatechange", req.readyState, req.status
# 		if req.readyState is 4
# 			if req.status in [0, 200]
# 				update status: "live"
# 			else
# 				update status: "offline"
# 	req.addEventListener "error", ->
# 		# console?.log "error", arguments
# 		update status: "offline"
# 	req.open("GET", "ping")
# 	req.send()

# do periodically_check_status_and_attribution = ->
# 	unless document.hidden
# 		check_status()
# 		check_attribution()
# 	setTimeout periodically_check_status_and_attribution, 5000

# listen_button.addEventListener "click", toggle_listen
# trigger_keys = [32, 13, 80] # Space, Enter, P
# window.addEventListener "keydown", (e)->
# 	if e.keyCode in trigger_keys
# 		listen_button.classList.add("pressed")
# window.addEventListener "keyup", (e)->
# 	return if e.target isnt listen_button and e.target.tagName in ["input", "textarea", "select", "button"]
# 	if e.keyCode in trigger_keys
# 		listen_button.classList.remove("pressed")
# 		toggle_listen()
