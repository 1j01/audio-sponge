
listen_button = document.querySelector(".listen-button")
button_label = listen_button.querySelector(".button-label")
status_indicator = listen_button.querySelector(".status-indicator")

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
			when "connecting"
				"Connecting..."
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
		update listening: no
		audio.pause()
	else
		update status: "connecting"
		audio.play()

update status: "loading"
audio = document.createElement("audio")
# audio.preload = "none"
# TODO: actually indicate whether the stream is live
audio.src = "stream"
audio.addEventListener "canplay", ->
	update status: "live"
audio.addEventListener "error", ->
	update status: "offline", listening: no
audio.addEventListener "playing", ->
	update status: "live", listening: yes

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
