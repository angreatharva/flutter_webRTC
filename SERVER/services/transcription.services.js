const speech = require('@google-cloud/speech');
const client = new speech.SpeechClient();

const activeStreams = new Map(); // callId -> { recognizeStream, socket }

function startTranscriptionStream(socket, callId, languageCode = 'en-IN') {
  // Set up Google streaming config
  const request = {
    config: {
      encoding: 'LINEAR16',
      sampleRateHertz: 44100,
      audioChannelCount: 2,
      languageCode,
      model: 'latest_long',
      enableWordTimeOffsets: true,
      enableWordConfidence: true,
      diarizationConfig: {
        enableSpeakerDiarization: true,
        minSpeakerCount: 2,
        maxSpeakerCount: 2
      }
    },
    interimResults: true,
  };

  const recognizeStream = client
    .streamingRecognize(request)
    .on('data', (data) => {
      // Emit transcription result to client
      socket.emit('transcriptionResult', {
        callId,
        transcript: data.results[0]?.alternatives[0]?.transcript || '',
        isFinal: data.results[0]?.isFinal || false,
      });
    })
    .on('error', (err) => {
      socket.emit('transcriptionError', { callId, error: err.message });
    });

  activeStreams.set(callId, { recognizeStream, socket });
}

function sendAudioChunk(socket, callId, chunk) {
  const streamObj = activeStreams.get(callId);
  if (streamObj) {
    // If chunk is base64, decode it
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk, 'base64');
    streamObj.recognizeStream.write(buffer);
  }
}

function stopTranscriptionStream(socket, callId) {
  const streamObj = activeStreams.get(callId);
  if (streamObj) {
    streamObj.recognizeStream.end();
    activeStreams.delete(callId);
  }
}

module.exports = { startTranscriptionStream, sendAudioChunk, stopTranscriptionStream };
