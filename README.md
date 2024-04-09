# Video Sponge

This is an experiment in creating video collages and procedurally generating music videos.

## Ideas

* Generate or accept lyrics in UI, then search for videos online that contain the words and phrases of the lyrics and string them together in a video collage (using closed captions / subtitles and/or speech recognition)

* Accept search terms for non-lyrical parts, or just sample other parts of the videos used (probably more economical, and more cohesive results, but sometimes you might want more variety or control)

* Use MIDI files for easily getting song structure information to work with. I've implemented this using BitMidi, and made it use search terms from the user, and fall back to a random MIDI if it doesn't find anything.

* When finding samples, detect beats for percussion, detect pitch/harmonics for melody.

* Crazy random effects like randomly changing knobs on [this](https://googlechromelabs.github.io/web-audio-samples/archive/demos/wavetable-synth.html)

* Experiment with generating or modifying melody / rhythm, phasing in and out parts, automating effects rhythmically and long term

* Video effects that correspond to audio effects (audio-visual analogies)
  - See below

* Download output videos and attribution `.html` files (with related filenames so you can keep them together easily). Embed attribution information in video file metadata. Track number of samples per source and don't show sources where no samples were used.

* Export to a known video editor's project file format. This would probably be very limiting in the effects department, as I want to do a lot of custom effects. And it wouldn't be very portable.

## Project Story

I started this project with the goal of making an infinite everchanging generative audio station, inspired by [versificator](https://github.com/sebpiq/versificator). (I didn't find the repo for it then and may have just worked on / messed around with that if I had found it.)

I managed to make something, but before getting to making it sound good, I ran into some problems:
1. I couldn't deploy to heroku (or many other free services) and just have it stream an audio file like a radio station - heroku would cut off the response at [30s](https://devcenter.heroku.com/articles/request-timeout). I would have to use websockets or something to stream, or rearchitect it so it does the audio generation on the client.
2. Streaming audio is not too difficult to get working, but harder to get scalable. The way I implemented it it could stream to multiple clients (cool), but if a client paused the stream, the server would indefinitely buffer audio for that client. You could literally DOS it by pausing the stream and waiting. ShoutCast/IceCast would be better (but they would work better with discrete songs...)
3. Installing native dependencies is hard. I had gone with Node.js so I could use the somewhat familiar-to-me Web Audio API (also so I could possibly transition to doing it on the client). I tried at least two implementations of the Web Audio API for Node.js but they came with problems installing native dependencies and/or lacked features I wanted (to make fun audio effects in the future).
4. While listening to the stream, if I heard something I liked, I couldn't easily save it. I had to already have been recording the system audio and then pause and cut that (somewhat arbitrarily) and save it.
5. I wanted to do visualization on the client, but this would mean meticulously marshalling data between the server and client, and keeping it SYNCED with the audio stream. This would be a RIDICULOUSLY complicated way to approach this problem.
6. I wanted to accept search terms on the client, but if it just fed into a public audio stream, moderation would be a concern. Also, as a user you want to be able to try things out freely and only share them if they're interesting, and even try things you know you wouldn't want to share. That works better as a social system. You might want to regenerate several times from a prompt because you have a hunch it might generate something really cool, but if everyone was listening to that, they would get bored and frustrated with you (or the system in general). There's something to be said for a stream that everyone's listening to, but that could be a separate addition, a station playing community songs that were shared explicitly (and this allows for "now playing" / "coming up" features).

So I decided to rewrite it to generate individual songs.  

I did that, and I made a reasonably nice looking UI, and I made it so you can enter search terms for creative control over the output, and I made it show attribution per song, instead of the long list of attribution for a pool of sounds that it *might* be using which didn't correspond much to what you were hearing.  
I made it use MIDI files as a basis for song structure - perhaps it will only create "covers" of songs, but I'm fine with that.

But just as I thought I had a good basis to work from and was ready to start doing the creative work of trying to make it sound good/interesting (reasonably often, rather than very occasionally), I ran into performance problems.  
With more complex MIDI files, it would lag and stutter the audio, which made it very unpleasant to listen to.  
You could pause it and wait for it to finish, and playing it back it would sound fine, but if you downloaded and played it in VLC, it would actually include the stuttering. (This behavior depends on the browser.)  
So not only is it painful to listen to, it's inconsistent, and can give you a false sense of sonic security.
You might save something and then come back to it months later and be like, "I thought this one sounded really cool! This sounds like shit...",
or going thru a collection, maybe just "this is a bad one, *delete*."  

There are several potential solutions to this:
- Limit the number of MIDI tracks; I've tried this and it kinda helps but not always, because there could be a lot of notes in one track
- Use Firefox? Firefox seemed better, but I forget how much
- Order the notes before scheduling them? I don't know if this matters
- Use a scheduler loop instead of scheduling all the BufferSourceNodes at once; this is the most likely useful solution
- Use OfflineAudioContext and just ditch the playback-while-generating feature
  - Maybe could render a short preview with normal or offline AudioContext, but for the full song and download use OfflineAudioContext
- Rewrite in some other language that has a decent audio processing ecosystem, where I would have more control over the performance

It's a bummer tho, and since this is a project for fun, well, I might just not work on this again. Who knows.

I do have ideas for a further rewrite tho.

I think it would be a lot cooler to use **video** for the sources.
- Don't need as many audio providers. All the major search engines have Video as a search category.
  - So just crawl the web for videos right? Might actually need lots of code for scraping videos from various websites, idk.
    - Well, there's [youtube-dl](https://github.com/ytdl-org/youtube-dl/) which works with various sites actually; that would probably be a *huge* boon!
- I've had this idea of pairing audio effects with corresponding video effects, like:
  - a muffling sound with a blur
  - volume = opacity
    - fading in = fading in
    - fading out = fading out
  - a grunge effect = increased contrast maybe
  - pitch could be indicated with Y position, or with scaling (lower = larger, higher = smaller)
  - delay = delay
  - merging audio sources = simply averaging pixels, or perhaps something more additive
    - so you might have a "dry" (original) signal and a "wet" (e.g. reverb'd) signal, mixed together in the audio graph based on an oscillator so the reverb (or whatever) fades in an out, and it would just by mixed together in the video graph and correspondingly fade in and out
  - reverb convolution is applied to pixels over time, to produce a visual echo
  - bit crush = reduce bitrate of video
  - other things could shift color channels, skew the video, or use novel shaders from shadertoy
- Use closed caption data and speech recognition to find where words are uttered, and combine them together into sentences/lyrics
  - This way you could search for a famous line in a movie, and get it to sample that actual line (and not just that scene)
  - If there aren't (good) results for the whole phrase the user enters, search for sub-phrases and words and try to find where those are uttered in videos, to splice them together in a video collage
  - Just generally sampling from whole words probably makes things more interesting/pleasant, if we can do at least word boundary detection (i.e. non-semantic speech recognition/detection) 

Also, it would be good to make song generation reproducible, and maybe export to a known DAW / video editor format for human editing.

Externalities for reproducibility:
- Search is completely unreliable - new content appears, search algorithms change etc. - but the results can be simply cached
- Fetching URLs is unreliable, but audio/video content is *usually* static
  - Internet access can be unavailable
  - Videos can be taken down
  - Sites can go down
  - Videos can be edited, which is likely to ruin timecodes
  - [Content-addressable storage](https://en.wikipedia.org/wiki/Content-addressable_storage) would be better, but might not be practical
  - Caching media can work but it's a lot heavier than a list of search results; video can take up a lot of space
- Random decisions can be made pseudorandom easily (with a seeded PRNG)
  - That said, it will be specific to a version of the generation code, and so caching the output (song structure) may be helpful too

## Project Structure

Written in [CoffeeScript](https://coffeescript.org/) with [Socket.IO](https://socket.io/).

The code is split into [`server/`](server/) and [`client/`](client/).

[`server/server.coffee`](server/server.coffee) is the main entry point for the server.

[`server/gather-video.coffee`](server/gather-video.coffee) collects video sources, using several video providers located in [`server/video-providers/`](server/video-providers))

[`client/app.coffee`](client/app.coffee) is the main entry point for the client app.

[`client/song.coffee`](client/song.coffee) generates the songs.

## License

MIT licensed, see [LICENSE](LICENSE).

## Development Setup

Requirements:
- [Git](https://git-scm.com/)
- [Git LFS](https://git-lfs.github.com/)
- [Node.js](https://nodejs.org) - best installed with [nvm](https://github.com/nvm-sh/nvm) or [nvm-windows](https://github.com/coreybutler/nvm-windows)
- [Python](https://www.python.org/) available as `python` - can be installed with `sudo apt install python-is-python3` on Ubuntu

1. [Clone the repository](https://help.github.com/articles/cloning-a-repository/)
2. Open a terminal/command-prompt in the project directory
3. Run `npm i` to install dependencies
4. Run `npm start` to start the server
5. Wait for it to say "Listening on http://localhost:3901" and open that URL

## Configuration

Copy `template.env` to a new file called simply `.env`

### YouTube

To enable the YouTube provider, add a `YOUTUBE_API_KEY` key the `.env` file.
[You'll need to get an API ID.](https://console.developers.google.com/apis/credentials)

### FileSystem

To enable the filesystem provider, set `FS_enabled` to `true` in `gather-video.coffee`, and add an `FILESYSTEM_GLOB` key the `.env` file, e.g.
```
FILESYSTEM_GLOB=C:\Users\Whomst\Videos\**\*.mp4
```
It must be a full path. `%` or `$` variables are NOT supported.
Uses [glob syntax](https://www.npmjs.com/package/glob#glob-primer).

<!--
## Are these songs?

no they just names:

* The Sponge of Truth and Lies
* In equal and opposite measure
* Cathartic cacophony
* Retched reverberations
* Spontaneous sound shenanigans
* Automatic chaotic euphony
* Synthetic symphonic hodgepodge
* Percussive pandemonium & rambunctious rhythm
* Wayward librettist
* Select the server other is file not play
* Large birds, soft cheese, green fruit
* A gathering of empty places
* I would understand a colorless green idea
* Cozy paranoia
* Primary reality beta

## What if it doesn't work?

spell-checker: disable

* ERROR
* ERROR ABOUT THERE BEING AN ERROR
* MULTIPLE ERROR(S)
* ERROR ABOUT THERE BEING ERRORS
* ERROR ABOUT ERRORS IN GENERAL
* ERROR ABOUT ERRORS BEING ERRORS IN GENERAL
* ERRORS, AM I RIGHT? THEY ARE ALWAYS BEING ERRORS
* ERRN'T THEY?
* HOW ERRONEOUS OF THEM
* ERRMAHGERD
* INSERT ERROR MESSAGE HERE
* AN ERRER HAS SPELLING-GRAMMAR OCCURD; PLEASE Contact LENSES (0x2C)
* OCCULT ERROR
* WARNING
* [VAGU](https://youtu.be/8d3SMxK40YQ)[**E**](https://www.reddit.com/r/EmboldenTheE/) [FEELING OF UNEASE](https://youtu.be/8d3SMxK40YQ)

spell-checker: enable

### What was that, like some avant-garde poetry?

By the board above the books  
Lies a truth between the crooks  

-->

## Problems and Suggestions

[Open an issue!](https://github.com/1j01/audio-sponge/issues)
