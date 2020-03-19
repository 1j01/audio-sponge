function sliceAudioBuffer(audioBuffer, begin, end, audioContext) {
	var {duration, numberOfChannels} = audioBuffer;
	var rate = audioBuffer.sampleRate;

	if (end == null) {
		end = duration;
	}

	if (begin < 0) {
		throw new RangeError('begin time must be greater than 0');
	}

	if (end > duration) {
		throw new RangeError('end time must be less than or equal to ' + duration);
	}

	var startOffset = rate * begin;
	var endOffset = rate * end;
	var frameCount = endOffset - startOffset;

	var newAudioBuffer = audioContext.createBuffer(numberOfChannels, endOffset - startOffset, rate);
	var anotherArray = new Float32Array(frameCount);
	var offset = 0;

	for (var channel = 0; channel < numberOfChannels; channel++) {
		audioBuffer.copyFromChannel(anotherArray, channel, startOffset);
		newAudioBuffer.copyToChannel(anotherArray, channel, offset);
	}

	return newAudioBuffer;
}
