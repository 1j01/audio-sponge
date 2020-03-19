function sliceAudioBuffer(buffer, begin, end, audioContext) {

	var duration = buffer.duration;
	var channels = buffer.numberOfChannels;
	var rate = buffer.sampleRate;

	if (begin < 0) {
		throw new RangeError('begin time must be greater than or equal to 0');
	}
	if (end > duration) {
		throw new RangeError('end time must be less than or equal to the duration of the buffer (' + duration + ')');
	}

	var startOffset = Math.floor(rate * begin);
	var endOffset = Math.floor(rate * end);
	var frameCount = endOffset - startOffset;

	var newAudioBuffer = audioContext.createBuffer(channels, frameCount, rate);
	var tempArray = new Float32Array(frameCount);

	var bufferFrameCount = duration * rate;

	for (var channel = 0; channel < channels; channel++) {
		buffer.copyFromChannel(tempArray, channel, startOffset);
		newAudioBuffer.copyToChannel(tempArray, channel, 0);
	}

	return newAudioBuffer;
}

module.exports = sliceAudioBuffer;

/* for web-audio-api instead of web-audio-engine:

sliceAudioBuffer = (audioBuffer, startOffset, endOffset, audioContext)->
	{numberOfChannels, sampleRate} = audioBuffer
	
	if startOffset < 0
		throw new RangeError('start time must be greater than or equal to 0')
	if endOffset > audioBuffer.duration
		throw new RangeError('end time must be less than or equal to the duration of the buffer (' + audioBuffer.duration + ')')

	array =
		for channel in [0...numberOfChannels]
			samples = audioBuffer.getChannelData(channel)
			samples.slice(startOffset * sampleRate, endOffset * sampleRate)
		
	AudioBuffer.fromArray(array, sampleRate)

*/
