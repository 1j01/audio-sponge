keywords_input = document.querySelector(".keywords-input")
generate_button = document.querySelector(".generate-button")
button_label = generate_button.querySelector(".button-label")
songs_output_ul = document.querySelector(".songs-output")
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
			when "offline"
				"Offline"
			when "online"
				"Online"
	generate_button.disabled = generating
	button_label.innerHTML =
		if generating
			"Generating Song..."
		else
			"Generate Song"

# fetch_audio_buffer = (callback)->
# 	fetch("/some-sound")
# 		.then (response)->
# 			if response.status isnt 200
# 				throw new Error("HTTP #{response.status} #{response.statusText}")
# 			response.arrayBuffer()
# 		.then (array_buffer)->
# 			if array_buffer.byteLength is 0
# 				throw new Error("array_buffer.byteLength is 0")
# 			audioContext.decodeAudioData(array_buffer)
# 		.then(
# 			(audio_buffer)-> callback(null, audio_buffer)
# 			(error)-> callback(error)
# 		)


generate_button.onclick = ->

	window.audioContext ?= new (window.AudioContext || window.webkitAudioContext)()

	update generating: true

	audio_buffers = []

	query_id = keywords_input.value + Math.random()
	socket.emit "sound-search", {query: keywords_input.value, query_id}
	ss(socket).on "sound:#{query_id}", (stream, metadata)->
		console.log {metadata, stream}
		buffers = []
		stream.on "data", (buffer)->
			buffers.push(buffer)
			console.log("buffers received:", buffers.length)
		stream.on "end", ->
			console.log("stream end")
			buffer = ss.Buffer.concat(buffers)

			audioContext.decodeAudioData(buffer).then(
				(audio_buffer)-> audio_buffers.push(audio_buffer)
				(error)-> console.warn(error)
			)
		stream.on "error", (error)->
			console.log("stream error", error)
		stream.on "close", ->
			console.log("stream close")
		stream.resume()



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
	song_output_audio = document.createElement("audio")
	song_download_link = document.createElement("a")
	song_output_audio.controls = true
	song_download_link.textContent = "download"
	song_download_link.className = "download-link"
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
		# li.appendChild(document.createTextNode(" (#{source.number_of_samples} samples)"))
		attribution_links_ul.appendChild(li)

socket = io()

socket.on "attribution", update_attribution

# give it a bit to connect (while saying "Checking...") before saying "Offline" if it hasn't
setTimeout ->
	update status: if socket.connected then "online" else "offline"
, 500

socket.on "connect", ->
	update status: "online"

socket.on "disconnect", ->
	update status: "offline"
