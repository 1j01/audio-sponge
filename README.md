# Procedural Song Generator

Maybe it music!™ (...It's not *GOOD* music, but maybe you can define it as such, as music - that's up to you. That's up to you - that's your mission, if you choose to accept it: a quest to categorize a cacophony as candidly as you can as: music.)

## What it does

* Collects audio by searching SoundCloud, OpenGameArt, and/or the filesystem (TODO: more sources; Napster would be good, maybe Spotify.)

* Takes random samples from the audio it collects (TODO: Detect beats for percussion, detect pitch/harmonics for melody)

* Plays the samples in randomly structured rhythms (TODO: melody, song structure, effects)

## Project Structure

Written in [CoffeeScript](https://coffeescript.org/).

[`server/server.coffee`](server/server.coffee) is the main entry point for the server.

[`server/gather-audio.coffee`](server/gather-audio.coffee) collects audio sources, using several audio providers located in [`server/audio-providers/`](server/audio-providers))

The client code is in [`client/`](client/).

[`client/song.coffee`](client/song.coffee) generates the songs.

[Fontello](http://fontello.com/) is currently used for some icons representing the audio providers but this could change to using favicons and be simpler.
Workflow: drag [`config.json`](client/fontello/config.json) to Fontello, update font, download zip and replace [`fontello/`](client/fontello/)

## License

MIT licensed, see [LICENSE](LICENSE).

## Development Setup

1. [Clone the repository](https://help.github.com/articles/cloning-a-repository/)
2. Install [Node.js](https://nodejs.org) if you don't have it already
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

## Problems and Suggestions

[Open an issue!](https://github.com/1j01/audio-sponge/issues)
