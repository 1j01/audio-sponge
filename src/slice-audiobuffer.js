function sliceAudioBuffer(buffer, begin, end, audioContext) {
	var duration = buffer.duration;
	var channels = buffer.numberOfChannels;
	var rate = buffer.sampleRate;

	if (begin < 0) {
		throw new RangeError('begin time must be greater than 0');
	}
	if (end > duration) {
		throw new RangeError('end time must be less than or equal to the duration of the buffer (' + duration + ')');
	}

	var startOffset = rate * begin;
	var endOffset = rate * end;
	var frameCount = endOffset - startOffset;
	var newArrayBuffer;

	newArrayBuffer = audioContext.createBuffer(channels, endOffset - startOffset, rate);
	var tempArray = new Float32Array(frameCount);

	for (var channel = 0; channel < channels; channel++) {
		buffer.copyFromChannel(tempArray, channel, startOffset);
		newArrayBuffer.copyToChannel(tempArray, channel, 0);
	}

	return newArrayBuffer;
}

module.exports = sliceAudioBuffer;

/* for web-audio-api instead of web-audio-engine:

sliceAudioBuffer = (audioBuffer, startOffset, endOffset, audioContext)->
	{numberOfChannels, sampleRate} = audioBuffer
	
	array =
		for channel in [0...numberOfChannels]
			samples = audioBuffer.getChannelData(channel)
			samples.slice(startOffset * sampleRate, endOffset * sampleRate)
		
	AudioBuffer.fromArray(array, sampleRate)
*/
