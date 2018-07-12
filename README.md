# Audio Sponge (working title)

Soak up some sound, and squeeze some sound out

maybe it music!™ (...it's not *GOOD* music, but maybe you can define it as such, as music... that's up to you. That's up to you - that's your mission, if you choose to accept it: a quest to categorize a cacophony as candidly as you can as.. music..)

Currently deployed here: https://station.now.sh/

The stream itself is here: https://station.now.sh/stream

TODO: Better name! Any suggestions? [Please share!](mailto:isaiahodhner@gmail.com)

## What it does

* Collects audio by streaming from SoundCloud, OpenGameArt, and/or the filesystem (TODO: more sources; Napster would be good, maybe Spotify. Also, gather sources as a continuous process!)

* Takes random samples from the audio it collects (as it streams) (TODO: Detect beats for percussion, detect pitch/harmonics for melody)

* Plays the samples in randomly structured rhythms (TODO: melody, song structure, effects)

* Streams to listeners on a [webpage](https://station.now.sh/), along with live attribution of the sources its using

## Project Structure

Written in [CoffeeScript](https://coffeescript.org/). (Could change to TypeScript later.)

[`server.coffee`](src/server.coffee) is the main entry point for the server.

The most interesting stuff is in [`Sponge.coffee`](src/Sponge.coffee); this handles generating the audio (using [web-audio-engine](https://www.npmjs.com/package/web-audio-engine)), as well as collecting audio at the top level. (At the lower level, it uses several audio providers located in [`src/audio-providers/`](src/audio-providers))

The client code is in [`public/`](public/).

[Fontello](http://fontello.com/) is currently used for some icons representing the audio providers but this could change to using favicons and be simpler.
Workflow: drag [`config.json`](public/fontello/config.json) to Fontello, update font, download zip and replace [`fontello/`](public/fontello/)

## License

MIT licensed, see [LICENSE](LICENSE).

## Development Setup

1. [Clone the repository](https://help.github.com/articles/cloning-a-repository/)
2. Install [Node.js]() if you don't have it already
3. Run `npm i` in a terminal/command-prompt to install dependencies
4. `npm start` to start the server
5. Wait for it to say "Listening on http://localhost:3901" and open that URL

## Configuration

Copy `template.env` to a new file called simply `.env`

### SoundCloud

To enable the SoundCloud audio provider, add a `SOUNDCLOUD_CLIENT_ID` key the `.env` file.
[You'll need to get a client ID somehow.](https://stackoverflow.com/questions/40992480/getting-a-soundcloud-api-client-id)

### FileSystem

To enable the filesystem audio provider, add an `AUDIO_SOURCE_FILES_GLOB` key the `.env` file, e.g.
```
AUDIO_SOURCE_FILES_GLOB=C:\Users\Isaiah\Music\**\*.mp3
```
It must be a full path. `%` or `$` variables are NOT supported.
Uses [glob syntax](https://www.npmjs.com/package/glob#glob-primer).

The files MUST be MP3s. Only MP3 files are supported, currently.

## Deployment

You can deploy to [△ Now](https://zeit.co/now) with `npm run deploy`

(First install Now with `npm i -g now`)

For configuration, copy `template.env` or `.env` to a new file called `production.env`

<!--
## Are these songs?

no they just names:

* The Sponge of Truth and Lies
* In equal and opposite measure
* Cathartic cacophony
* Retched reverbertations
* Spontanious sound shenanigans
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
-->

## What if it doesn't work?

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

### What was that, like some avant-garde poetry?

By the board above the books  
Lies a truth between the crooks  
[cont. ? one possibru -uation](https://www.reddit.com/r/LibraryofBabel/comments/7ophaq/ode_to_being_filthy_rich/?ref=share&ref_source=link)

## Problems and Suggestions

[Open an issue!](https://github.com/1j01/audio-sponge/issues)
