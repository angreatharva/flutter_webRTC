const fs = require('fs');
const path = require('path');
const { Readable } = require('stream');
const { spawn } = require('child_process');

// Debug flag - set to true for verbose logging
const DEBUG = true;

// Map to track active audio sessions
const activeAudioSessions = new Map();

// Storage path for WAV files
const AUDIO_STORAGE_PATH = path.join(__dirname, '../uploads/audio');

function getAudioFilePath(callId) {
    return path.join(AUDIO_STORAGE_PATH, `${callId}.wav`);
}

// Ensure the audio storage directory exists
if (!fs.existsSync(AUDIO_STORAGE_PATH)) {
    fs.mkdirSync(AUDIO_STORAGE_PATH, { recursive: true });
}

// Minimum recording duration in seconds
const MIN_RECORDING_DURATION = 20;

// Helper to log messages when debug is enabled
function debug(message, data) {
    if (!DEBUG) return;
    console.log(`[WebRTC Audio] ${message}`);
    if (data) console.log(data);
}

/**
 * Initialize a new audio session for a call
 * @param {string} callId - Unique ID for the call
 * @param {boolean} saveToWav - Whether to save audio to WAV file
 * @param {object} options - Audio options (sampleRate, channels, etc)
 * @returns {object} Session info including file path if applicable
 */
function initAudioSession(callId, saveToWav = true, options = {}) {
    if (activeAudioSessions.has(callId)) {
        // End previous session and clean up
        stopTranscriptionSession(callId);
    }
    const filePath = getAudioFilePath(callId);
    // Remove old file if exists
    if (fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
    }
    console.log(`[AudioService] initAudioSession: callId=${callId}, filePath=${filePath}, options=`, options);
    // Default options
    const sessionOptions = {
        languageCode: options.languageCode || 'en-US',
        saveToWav: saveToWav,
        sampleRate: options.sampleRate || 44100,
        channels: options.channels || 2,
        encoding: options.encoding || 'LINEAR16'
    };

    const sessionId = callId;
    debug(`Starting audio session for ${sessionId}`, sessionOptions);

    // Create session object
    const session = {
        id: sessionId,
        startTime: new Date(),
        config: sessionOptions,
        chunks: [],
        writeStream: null,
        wavFile: filePath,
        transcript: [],
        totalBytesWritten: 0,
        lastChunkTime: Date.now()
    };

    // Create WAV file if saveToWav is enabled
    if (sessionOptions.saveToWav) {
        try {
            // Create write stream for WAV file
            const writeStream = fs.createWriteStream(filePath);

            // Write WAV header - start with a placeholder (we'll update it at the end)
            const header = createWavHeader(0, sessionOptions.sampleRate, sessionOptions.channels);
            writeStream.write(header);

            // Track the header size so we can rewrite it later
            session.headerSize = header.length;
            session.writeStream = writeStream;

            debug(`Created WAV file: ${filePath}`);

            // Add periodic heartbeat to ensure file stays open
            session.heartbeatInterval = setInterval(() => {
                // If no chunks received in the last 5 seconds, send a heartbeat
                if (Date.now() - session.lastChunkTime > 5000) {
                    debug(`Sending heartbeat to keep file open for ${sessionId}`);
                    // Write a tiny bit of silence (2 bytes of 0)
                    const silence = Buffer.from([0, 0]);
                    if (writeStream && !writeStream.destroyed) {
                        writeStream.write(silence);
                        session.totalBytesWritten += silence.length;
                    }
                }
            }, 5000);
        } catch (err) {
            console.error(`Error creating WAV file for ${sessionId}:`, err);
        }
    }

    // Add session to active sessions
    activeAudioSessions.set(sessionId, session);

    return {
        sessionId: session.id,
        wavFilePath: session.wavFile,
        audioParams: session.config
    };
}

/**
 * Process an audio chunk for a session
 * @param {string} sessionId - The session ID (call ID)
 * @param {Buffer|string} chunk - Audio chunk data (Buffer or base64 string)
 * @param {object} socket - Socket.io socket for transcription events
 * @param {boolean} transcribe - Whether to transcribe this chunk
 * @param {boolean} isHeartbeat - Whether this is a heartbeat packet
 */
function processAudioChunk(sessionId, chunk, socket, transcribe = true, isHeartbeat = false) {
    if (!chunk || (!Buffer.isBuffer(chunk) && typeof chunk !== 'string')) {
        console.error(`[AudioService] processAudioChunk: Invalid chunk for callId=${sessionId}`);
        return;
    }
    console.log(`[AudioService] processAudioChunk: callId=${sessionId}, chunkSize=${chunk.length}, type=${typeof chunk}`);
    if (Buffer.isBuffer(chunk)) {
        console.log(`[AudioService] First 10 bytes:`, chunk.slice(0, 10));
    }
    const session = activeAudioSessions.get(sessionId);
    if (!session) {
        console.error(`No active audio session found for ${sessionId}`);
        return;
    }

    // Update last chunk time
    session.lastChunkTime = Date.now();

    try {
        // Convert base64 to buffer if needed
        const audioBuffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk, 'base64');

        // Skip empty buffers
        if (audioBuffer.length === 0) {
            debug(`Received empty audio buffer for ${sessionId}`);
            return;
        }

        // Check if buffer contains any non-zero values (actual audio)
        let hasAudioData = false;
        for (let i = 0; i < Math.min(audioBuffer.length, 100); i++) {
            if (audioBuffer[i] !== 0) {
                hasAudioData = true;
                break;
            }
        }

        if (!hasAudioData && !isHeartbeat) {
            debug(`Warning: Audio buffer contains only zeros (silence) for ${sessionId}`);
        }

        // Store the chunk
        session.chunks.push(audioBuffer);

        // Write to WAV file if stream exists
        if (session.writeStream && !session.writeStream.destroyed) {
            try {
                const success = session.writeStream.write(audioBuffer);
                session.totalBytesWritten += audioBuffer.length;

                if (!success) {
                    debug(`Write stream backpressure detected for ${sessionId}`);
                }

                debug(`Processed ${audioBuffer.length} bytes of audio for ${sessionId}, total: ${session.totalBytesWritten} bytes`);
            } catch (err) {
                console.error(`Error writing to WAV file for ${sessionId}:`, err);
            }
        }

        // Log processing info
        if (isHeartbeat) {
            debug(`Received heartbeat for ${sessionId}`);
        } else {
            debug(`Processed ${audioBuffer.length} bytes of audio for ${sessionId}`);
        }
    } catch (err) {
        console.error(`Error processing audio chunk for ${sessionId}:`, err);
    }
}

/**
 * Finalize an audio session
 * @param {string} sessionId - The session ID (call ID)
 * @param {object} socket - Socket.io socket for transcription events
 * @returns {object} Session info including file path and duration
 */
function finalizeAudioSession(sessionId, socket) {
    return stopTranscriptionSession(sessionId);
}

/**
 * Stop an active transcription session
 * @param {string} sessionId - The session ID (call ID)
 * @returns {object} Session info including file path and duration
 */
function stopTranscriptionSession(sessionId) {
    const session = activeAudioSessions.get(sessionId);
    if (!session) {
        console.error(`No active audio session found for ${sessionId}`);
        return null;
    }

    console.log(`[WebRTC Audio] Stopping transcription session for ${sessionId}`);

    // Calculate duration
    session.endTime = new Date();
    session.duration = (session.endTime - session.startTime) / 1000; // in seconds

    // Check if we have enough audio data (minimum duration)
    try {
        // Add padding silence if recording is shorter than minimum duration
        if (session.duration < MIN_RECORDING_DURATION && session.writeStream && !session.writeStream.destroyed) {
            const paddingDuration = MIN_RECORDING_DURATION - session.duration;
            debug(`Adding ${paddingDuration.toFixed(2)}s of silence padding to ${sessionId}`);

            // Calculate padding size in bytes
            const bytesPerSecond = session.config.sampleRate * session.config.channels * 2; // 2 bytes per sample
            const paddingSizeBytes = Math.floor(paddingDuration * bytesPerSecond);

            // Create silence buffer (all zeros)
            const silenceBuffer = Buffer.alloc(paddingSizeBytes);
            session.writeStream.write(silenceBuffer);
            session.totalBytesWritten += silenceBuffer.length;

            debug(`Added ${paddingSizeBytes} bytes of silence padding to ${sessionId}`);
        }
    } catch (err) {
        console.error(`Error adding silence padding for ${sessionId}:`, err);
    }

    // Clear heartbeat interval
    if (session.heartbeatInterval) {
        clearInterval(session.heartbeatInterval);
        session.heartbeatInterval = null;
    }

    // Finalize WAV file if it exists
    if (session.writeStream && session.wavFile) {
        try {
            // Get current position in file (total bytes written)
            const dataSize = session.totalBytesWritten;
            debug(`Finalizing WAV file for ${sessionId} with ${dataSize} bytes of audio data`);

            // Close the write stream first
            session.writeStream.end(() => {
                try {
                    // Rewrite the header with the correct file size
                    const fd = fs.openSync(session.wavFile, 'r+');
                    const header = createWavHeader(dataSize, session.config.sampleRate, session.config.channels);
                    fs.writeSync(fd, header, 0, header.length, 0);
                    fs.closeSync(fd);

                    debug(`Updated WAV header for ${sessionId} with correct file size`);

                    // Verify file size
                    const stats = fs.statSync(session.wavFile);
                    debug(`Final WAV file size: ${stats.size} bytes`);

                    // Quick sanity check
                    if (stats.size <= 44) { // WAV header is 44 bytes
                        console.error(`WARNING: WAV file for ${sessionId} contains no audio data!`);
                    }
                } catch (err) {
                    console.error(`Error finalizing WAV header for ${sessionId}:`, err);
                }
            });
        } catch (err) {
            console.error(`Error closing WAV file for ${sessionId}:`, err);
        }
    }

    // Remove session from active sessions
    activeAudioSessions.delete(sessionId);

    // Do NOT delete the file; keep it for audit/download
    // if (session.wavFile && fs.existsSync(session.wavFile)) {
    //     fs.unlinkSync(session.wavFile);
    // }

    debug(`Transcription session ended for ${sessionId}, duration: ${session.duration}s`);

    console.log(`[WebRTC Audio] Finalizing WAV file for ${sessionId} with ${session.totalBytesWritten} bytes of audio data`);

    return {
        sessionId: session.id,
        wavFilePath: session.wavFile,
        duration: session.duration,
        totalBytes: session.totalBytesWritten
    };
}

/**
 * Create a basic WAV header for the given parameters
 * @param {number} dataLength - Length of the audio data in bytes
 * @param {number} sampleRate - Audio sample rate (e.g., 16000)
 * @param {number} numChannels - Number of audio channels (1 for mono, 2 for stereo)
 * @returns {Buffer} WAV header buffer
 */
function createWavHeader(dataLength, sampleRate, numChannels) {
    const buffer = Buffer.alloc(44);

    // RIFF identifier
    buffer.write('RIFF', 0);

    // File length
    buffer.writeUInt32LE(dataLength + 36, 4);

    // WAVE identifier
    buffer.write('WAVE', 8);

    // Format chunk identifier
    buffer.write('fmt ', 12);

    // Format chunk length
    buffer.writeUInt32LE(16, 16);

    // Sample format (PCM)
    buffer.writeUInt16LE(1, 20);

    // Channel count
    buffer.writeUInt16LE(numChannels, 22);

    // Sample rate
    buffer.writeUInt32LE(sampleRate, 24);

    // Byte rate (sample rate * block align)
    buffer.writeUInt32LE(sampleRate * numChannels * 2, 28);

    // Block align (channel count * bytes per sample)
    buffer.writeUInt16LE(numChannels * 2, 32);

    // Bits per sample
    buffer.writeUInt16LE(16, 34);

    // Data chunk identifier
    buffer.write('data', 36);

    // Data chunk length
    buffer.writeUInt32LE(dataLength, 40);

    debug(`Created WAV header: ${buffer.length} bytes, data length: ${dataLength} bytes`);

    return buffer;
}

/**
 * Convert PCM audio chunks to a WAV file using ffmpeg
 * @param {string} sessionId - The session ID (call ID)
 * @param {Array<Buffer>} chunks - Array of audio chunks
 * @param {object} audioParams - Audio parameters (sampleRate, channels)
 * @returns {Promise<string>} Path to the WAV file
 */
function convertPcmToWavUsingFfmpeg(sessionId, chunks, audioParams) {
    return new Promise((resolve, reject) => {
        const timestamp = new Date().toISOString().replace(/:/g, '-');
        const outputPath = path.join(AUDIO_STORAGE_PATH, `${sessionId}_${timestamp}.wav`);

        try {
            // Create a readable stream from the chunks
            const chunksStream = new Readable({
                read() {
                    if (this.chunkIndex >= chunks.length) {
                        this.push(null);
                        return;
                    }
                    this.push(chunks[this.chunkIndex++]);
                }
            });
            chunksStream.chunkIndex = 0;
            
            // Use ffmpeg to convert PCM to WAV
            const ffmpeg = spawn('ffmpeg', [
                '-f', 's16le',              // Format: signed 16-bit little-endian
                '-ar', audioParams.sampleRate,    // Sample rate
                '-ac', audioParams.channels,      // Channels
                '-i', 'pipe:0',             // Input from stdin
                outputPath                  // Output file
            ]);

            chunksStream.pipe(ffmpeg.stdin);

            ffmpeg.on('close', (code) => {
                if (code === 0) {
                    resolve(outputPath);
                } else {
                    reject(new Error(`ffmpeg exited with code ${code}`));
                }
            });

            ffmpeg.stderr.on('data', (data) => {
                console.log(`ffmpeg: ${data}`);
            });
        } catch (err) {
            console.error('Error in ffmpeg conversion:', err);
            reject(err);
        }
    });
}

function closeAudioSession(callId, socket) {
    const session = activeAudioSessions.get(callId);
    if (!session) {
        console.error(`[AudioService] closeAudioSession: No session for callId=${callId}`);
        return;
    }
    session.writeStream.end(() => {
        try {
            const stats = fs.statSync(session.wavFile);
            console.log(`[AudioService] closeAudioSession: callId=${callId}, filePath=${session.wavFile}, finalSize=${stats.size} bytes`);
        } catch (err) {
            console.error(`[AudioService] closeAudioSession: Error getting file size for callId=${callId}, filePath=${session.wavFile}:`, err.message);
        }
    });
}

/**
 * Utility to clean up old/unused WAV files in the audio storage directory.
 * @param {number} maxAgeHours - Files older than this (in hours) will be deleted.
 */
function cleanupOldWavFiles(maxAgeHours = 24) {
    const now = Date.now();
    const files = fs.readdirSync(AUDIO_STORAGE_PATH);
    files.forEach(file => {
        if (file.endsWith('.wav')) {
            const filePath = path.join(AUDIO_STORAGE_PATH, file);
            const stats = fs.statSync(filePath);
            const ageHours = (now - stats.mtimeMs) / (1000 * 60 * 60);
            if (ageHours > maxAgeHours) {
                fs.unlinkSync(filePath);
                debug(`Deleted old WAV file: ${filePath}`);
            }
        }
    });
}

module.exports = {
    initAudioSession,
    processAudioChunk,
    finalizeAudioSession,
    convertPcmToWavUsingFfmpeg,
    closeAudioSession,
    cleanupOldWavFiles
};
