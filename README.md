# Audio Sponge (working title)

soak up some sound, and squeeze some sound out

maybe it music! (...not *good* music, but maybe you can define it as such, as music... that's up to you)

this URL will change: https://station.now.sh/

### What it do tho?

* collects audio by streaming from SoundCloud, OpenGameArt, and/or the filesystem (TODO: more sources; Napster would be good, maybe Spotify)

* takes random slices from the audio it collects (while streaming) (TODO: detect beats for percussion, and perhaps pitch/harmonics for melody)

* plays the sounds in randomly structured rhythms (TODO: rhyme and reason, and effects, and melody!)

* streams to listeners on a [webpage](https://station.now.sh/) (TODO: make this more robust, esp. when clients pause the stream)

------------

## Can I, uh..?

Licensed under the MIT license, see [LICENSE](LICENSE).

### Development Setup

1. [Clone the repo](https://help.github.com/articles/cloning-a-repository/)
2. Install [Node.js]() if you don't have it already
3. `npm i` to install dependencies
4. `npm start`

### Configuration

#### SoundCloud

To enable SoundCloud as a source, add a `SOUNDCLOUD_CLIENT_ID` key the `.env` file.
[You'll need to get a client ID somehow.](https://stackoverflow.com/questions/40992480/getting-a-soundcloud-api-client-id)

#### FileSystem

To enable the filesystem as a source, add an `AUDIO_SOURCE_FILES_GLOB` key the `.env` file, e.g.
```
AUDIO_SOURCE_FILES_GLOB=C:\Users\Isaiah\Music\**\*.mp3
```
It must be a full path; that is, `%` or `$` variables are NOT supported.

The files MUST be **MP3** files.

### Deploy

Deploy to [Now](https://zeit.co/now) with `npm run deploy`

First install Now with `npm i -g now`

------------
<!--
### Are these songs?

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

### What if it doens't work?

* ERROR
* ERROR ABOUT THERE BEING AN ERROR
* MULTIPLE ERROR(S)
* ERROR ABOUT THERE BEING ERRORS
* ERROR ABOUT ERRORS IN GENERAL
* ERROR ABOUT ERRORS BEING ERRORS IN GENERAL
* ERRORS, AM I RIGHT? THEY ARE ALWAYS BEING ERRORS <!-- * AREN'T THEY (ERRN'T THEY?) -->
* HOW ERRONEOUS OF THEM
* INSERT ERROR MESSAGE HERE
* AN ARROR HAS SPELLING-GRAMMAR OCCURD; PLEASE Contact LENSES
* OCCULT ERROR
* WARNING
* [VAGU](https://youtu.be/8d3SMxK40YQ)[**E**](https://www.reddit.com/r/EmboldenTheE/) [FEELING OF UNEASE](https://youtu.be/8d3SMxK40YQ)

### What was that, like some avant-garde poetry?

By the board above the books  
Lies a truth between the crooks  
[cont. ? one possibru -uation](https://www.reddit.com/r/LibraryofBabel/comments/7ophaq/ode_to_being_filthy_rich/?ref=share&ref_source=link)
