listen_button = document.querySelector(".listen-button")
button_label = listen_button.querySelector(".button-label")
status_indicator = listen_button.querySelector(".status-indicator")
attribution_links_ul = document.querySelector(".attribution-links")

state = {}
update = (new_state)->
	status_indicator.classList.remove(state.status)
	state[k] = v for k, v of new_state
	{status, listening} = state
	status_indicator.classList.add(status)
	status_indicator.innerHTML =
		switch status
			when "loading"
				"Loading..."
			# when "connecting"
			# 	"Connecting..."
			when "offline"
				"&#9679;&#xFE0E; Offline"
			when "live"
				"&#9679;&#xFE0E; Live"
	button_label.innerHTML =
		if listening
			"&#11035;&#xFE0E; Stop" # You can't pause yet, sorry
		else
			"&#9654;&#xFE0E; Listen"

toggle_listen = ->
	if state.listening
		audio.pause()
		update listening: no
	else
		# TODO: maybe allow pausing again, but implement other server error handling and reconnecting logic
		audio.src = null
		audio.src = "stream"
		audio.play()
		# update status: "connecting"
		check_status()

update status: "loading"
audio = document.createElement("audio")
audio.preload = "none"
audio.src = "stream"
audio.addEventListener "error", ->
	update status: "offline"
audio.addEventListener "stalled", ->
	# FIXME: this is annoying
	# I want it to only end the stream if the server is offline
	# but it generally only realizes its offline (when the ping fails) *after* the stalled event
	# so I'd need to wait for it to go offline and then, I guess if there's been a stalled with no
	# play/resume/unstalled/timeupdate or whatever after it, then end the stream (like the following:)
	audio.src = null
audio.addEventListener "play", ->
	update listening: yes
audio.addEventListener "pause", ->
	update listening: no
audio.addEventListener "emptied", ->
	update listening: no


update_attribution = (attribution)->
	# TODO: diff-based updates
	attribution_links_ul.innerHTML = ""
	for source in attribution.sources
		li = document.createElement("li")
		track_link = document.createElement("a")
		track_link.href = source.link
		track_link.textContent = source.name or "track"
		track_link.setAttribute("target", "_blank")
		author_link = document.createElement("a")
		author_link.href = source.author.link
		author_link.textContent = source.author.name or "someone"
		author_link.setAttribute("target", "_blank")
		li.appendChild(track_link)
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
				update_attribution(JSON.parse(req.responseText))
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

listen_button.addEventListener "click", toggle_listen
trigger_keys = [32, 13, 80] # Space, Enter, P
window.addEventListener "keydown", (e)->
	if e.keyCode in trigger_keys
		listen_button.classList.add("pressed")
window.addEventListener "keyup", (e)->
	return if e.target isnt listen_button and e.target.tagName in ["input", "textarea", "select", "button"]
	if e.keyCode in trigger_keys
		listen_button.classList.remove("pressed")
		toggle_listen()
