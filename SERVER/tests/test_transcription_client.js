const fs = require('fs');
const io = require('socket.io-client');

// Change this to your server's address and port
const socket = io('http://localhost:5000', {
  transports: ['websocket'],
});

const CALL_ID = 'test-call-123';
// Use a stereo, 44100 Hz, LINEAR16 PCM WAV file for testing
// const AUDIO_FILE = 'test_audio.wav'; // Path to your test audio file
const AUDIO_FILE = '680a5614ea3772ef3ae5f16a.wav'; // Path to your test audio file

socket.on('connect', () => {
  console.log('Connected to server');

  // Start transcription with matching language code
  socket.emit('startTranscription', { callId: CALL_ID, languageCode: 'en-AU' });

  // Read and send audio in chunks
  // For 44100 Hz, 2 channels, 16-bit PCM: 44100 samples/sec * 2 channels * 2 bytes/sample = 176400 bytes/sec
  // 100ms chunk = 17640 bytes
  const stream = fs.createReadStream(AUDIO_FILE, { highWaterMark: 17640 }); // ~100ms per chunk

  stream.on('data', (chunk) => {
    socket.emit('audioChunk', { callId: CALL_ID, audioChunk: chunk.toString('base64') });
  });

  stream.on('end', () => {
    console.log('Audio file sent, stopping transcription...');
    socket.emit('stopTranscription', { callId: CALL_ID });
  });
});

// Listen for transcription results
socket.on('transcriptionResult', (data) => {
  console.log('Transcription:', data.transcript, data.isFinal ? '(final)' : '(interim)');
});

socket.on('transcriptionError', (data) => {
  console.error('Transcription error:', data.error);
});
