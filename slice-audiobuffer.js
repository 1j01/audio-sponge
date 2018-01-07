
module.exports = sliceAudioBuffer;

function sliceAudioBuffer(buffer, begin, end, audioContext) {
	var duration = buffer.duration;
	var channels = buffer.numberOfChannels;
	var rate = buffer.sampleRate;
	// console.log({duration, channels, rate});

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
	var anotherArray = new Float32Array(frameCount);
	var offset = 0;

	for (var channel = 0; channel < channels; channel++) {
		buffer.copyFromChannel(anotherArray, channel, startOffset);
		newArrayBuffer.copyToChannel(anotherArray, channel, offset);
	}

	return newArrayBuffer;
}

/*
# sliceAudioBuffer = (audioBuffer, startOffset, endOffset, audioContext)->
# 	{numberOfChannels, duration, sampleRate, frameCount} = audioBuffer
# 	console.log audioBuffer

# 	newAudioBuffer = audioContext.createBuffer(numberOfChannels, endOffset - startOffset, sampleRate)
# 	tempArray = new Float32Array(frameCount)
	
# 	for channel in [0...numberOfChannels]
# 		audioBuffer.copyFromChannel(tempArray, channel, startOffset)
# 		newAudioBuffer.copyToChannel(tempArray, channel, 0)
	
# 	newAudioBuffer
	
# 	# {numberOfChannels, sampleRate} = audioBuffer
	
# 	# array =
# 	# 	for channel in [0...numberOfChannels]
# 	# 		samples = audioBuffer.getChannelData(channel)
# 	# 		samples.slice(startOffset * sampleRate, endOffset * sampleRate)
		
# 	# AudioBuffer.fromArray(array, sampleRate)
*/
