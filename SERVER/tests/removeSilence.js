const fs = require('fs');
const wav = require('wav-decoder');
const wavEncoder = require('wav-encoder');

// Config
const inputFile = '680a5614ea3772ef3ae5f16a.wav';
const outputFile = 'output_no_silence.wav';
const silenceThreshold = 0.005; // Amplitude threshold (0 to 1)
const minSilenceDuration = 0.05; // seconds

async function removeSilenceFromWav() {
  const buffer = fs.readFileSync(inputFile);
  const audioData = await wav.decode(buffer);

  const { sampleRate, channelData } = audioData;
  const mono = channelData[0]; // Use the first channel for silence detection
  const silenceSamples = Math.floor(minSilenceDuration * sampleRate);

  const output = [];

  let i = 0;
  while (i < mono.length) {
    const chunk = mono.slice(i, i + silenceSamples);
    const maxAmp = Math.max(...chunk.map(Math.abs));

    if (maxAmp > silenceThreshold) {
      output.push(...chunk);
    }
    i += silenceSamples;
  }

  const cleanedChannel = new Float32Array(output);

  // Output as mono file
  const outputAudio = {
    sampleRate: sampleRate,
    channelData: [cleanedChannel]
  };

  const encodedWav = await wavEncoder.encode(outputAudio);
  fs.writeFileSync(outputFile, Buffer.from(encodedWav));
  console.log(`✅ Saved silence-trimmed audio to: ${outputFile}`);
}

removeSilenceFromWav().catch(console.error);
