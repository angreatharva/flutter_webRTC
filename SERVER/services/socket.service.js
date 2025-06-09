const socketAuth = require('../middleware/socket.middleware');
const { startTranscriptionStream, sendAudioChunk, stopTranscriptionStream } = require('./transcription.services');
const webrtcAudioService = require('./webrtc-audio.service');

// Create a variable to hold the io instance for use across the application
let io;

// Keep track of connected users
const connectedUsers = new Map();

const setupSocketServer = (ioInstance) => {
  // Store the io instance for use in other functions
  io = ioInstance;
  
  // Apply socket authentication middleware
  io.use(socketAuth);

  io.on("connection", (socket) => {
    console.log(`User ${socket.user} connected to socket server`);
    
    // Add user to connected users map
    connectedUsers.set(socket.user, socket);
    console.log(`Total connected users: ${connectedUsers.size}`);
    
    socket.join(socket.user);

    // Handle callerId verification
    socket.on("verifyCallerId", (data) => {
      const verifiedCallerId = data.callerId;
      
      // Check if the callerId matches what's in the socket
      if (socket.user !== verifiedCallerId) {
        console.log(`Updating caller ID from ${socket.user} to ${verifiedCallerId}`);
        
        // Remove from connected users map with old ID
        connectedUsers.delete(socket.user);
        
        // Have the socket leave the old room
        socket.leave(socket.user);
        
        // Update the socket.user value
        socket.user = verifiedCallerId;
        
        // Add to connected users map with new ID
        connectedUsers.set(socket.user, socket);
        
        // Join the new room
        socket.join(verifiedCallerId);
        
        // Acknowledge the change
        socket.emit("callerIdVerified", { success: true, callerId: verifiedCallerId });
      } else {
        console.log(`Caller ID verified: ${verifiedCallerId}`);
        socket.emit("callerIdVerified", { success: true, callerId: verifiedCallerId });
      }
    });

    socket.on("makeCall", (data) => {
      let calleeId = data.calleeId;
      let sdpOffer = data.sdpOffer;
      let callerName = data.callerName || null;
      
      console.log(`User ${socket.user} is calling ${calleeId}`);

      socket.to(calleeId).emit("newCall", {
        callerId: socket.user,
        sdpOffer: sdpOffer,
        callerName: callerName
      });
    });

    socket.on("answerCall", (data) => {
      let callerId = data.callerId;
      let sdpAnswer = data.sdpAnswer;
      
      console.log(`User ${socket.user} is answering call from ${callerId}`);

      socket.to(callerId).emit("callAnswered", {
        callee: socket.user,
        sdpAnswer: sdpAnswer,
      });
    });

    socket.on("IceCandidate", (data) => {
      let calleeId = data.calleeId;
      let iceCandidate = data.iceCandidate;

      socket.to(calleeId).emit("IceCandidate", {
        sender: socket.user,
        iceCandidate: iceCandidate,
      });
    });
    
    // Handle call request acceptance
    socket.on("callRequestAccepted", (data) => {
      console.log(`Call request accepted by ${socket.user} for patient ${data.patientCallerId}`);
      const patientCallerId = data.patientCallerId;
      
      // Notify the patient that their call request was accepted
      socket.to(patientCallerId).emit("callRequestAccepted", {
        requestId: data.requestId,
        doctorCallerId: data.doctorCallerId,
        doctorName: data.doctorName,
      });
    });
    
    // Handle transcription events
    socket.on("transcription", (data) => {
      // Broadcast to the room for real-time updates
      socket.to(data.callId).emit("transcriptionUpdate", data);
    });
    
    // When client starts sending audio for transcription
    socket.on('startTranscription', (data) => {
      console.log(`[Socket] startTranscription received:`, data);
      // data: { callId, languageCode, saveToWav, sampleRate, channels, encoding }
      const saveToWav = data.saveToWav !== undefined ? data.saveToWav : true;
      const options = {
        languageCode: data.languageCode || 'en-US',
        sampleRate: data.sampleRate || 44100,
        channels: data.channels || 2,
        encoding: data.encoding || 'LINEAR16'
      };
      console.log(`[Socket] Starting transcription for callId=${data.callId}, saveToWav=${saveToWav}, options=`, options);
      // Initialize an audio session (for saving)
      const sessionInfo = webrtcAudioService.initAudioSession(
        data.callId,
        saveToWav,
        options
      );
      // Start the real-time transcription stream (for Google STT)
      startTranscriptionStream(socket, data.callId, options.languageCode);
      // Let the client know the session was created successfully
      socket.emit('transcriptionSessionCreated', {
        callId: data.callId,
        sessionId: sessionInfo.sessionId,
        wavFilePath: sessionInfo.wavFilePath ? true : false
      });
      console.log(`Audio transcription session started for call: ${data.callId}`);
    });

    socket.on('audioChunk', (data) => {
      if (!data || !data.callId || !data.audioChunk) {
        console.error('[Socket] Invalid audioChunk data:', data);
        return;
      }
      console.log(`[Socket] audioChunk received: callId=${data.callId}, chunkSize=${data.audioChunk.length}, type=${typeof data.audioChunk}`);
      // data: { callId, chunk (Buffer or base64), transcribe }
      const transcribe = data.transcribe !== undefined ? data.transcribe : true;
      // Process the audio chunk (for saving)
      webrtcAudioService.processAudioChunk(
        data.callId,
        data.audioChunk,
        socket,
        transcribe
      );
      // Forward the audio chunk to the transcription stream (for Google STT)
      sendAudioChunk(socket, data.callId, data.audioChunk);
    });

    socket.on('stopTranscription', (data) => {
      console.log(`[Socket] stopTranscription received:`, data);
      // data: { callId }
      const sessionInfo = webrtcAudioService.finalizeAudioSession(data.callId, socket);
      // Stop the real-time transcription stream (for Google STT)
      stopTranscriptionStream(socket, data.callId);
      if (sessionInfo) {
        socket.emit('transcriptionSessionFinalized', {
          callId: data.callId,
          wavFilePath: sessionInfo.wavFilePath ? true : false,
          duration: sessionInfo.duration,
          chunks: sessionInfo.chunks
        });
        console.log(`Audio transcription session finalized for call: ${data.callId}`);
      }
    });
    
    // Process an existing WAV file for transcription
    socket.on('transcribeWavFile', (data) => {
      // data: { wavFilePath, callId }
      if (!data.wavFilePath) {
        socket.emit('transcriptionError', { 
          callId: data.callId, 
          error: 'No WAV file path provided' 
        });
        return;
      }
      
      const sessionId = webrtcAudioService.transcribeWavFile(
        data.wavFilePath, 
        socket, 
        data.callId
      );
      
      socket.emit('transcriptionSessionCreated', {
        callId: data.callId || sessionId,
        sessionId: sessionId,
        wavFilePath: true
      });
      
      console.log(`Transcription started for WAV file: ${data.wavFilePath}`);
    });
    
    // Handle disconnection
    socket.on("disconnect", () => {
      console.log(`User ${socket.user} disconnected from socket server`);
      
      // Remove from connected users map
      connectedUsers.delete(socket.user);
      console.log(`Remaining connected users: ${connectedUsers.size}`);
    });
  });
};

// Function to emit a doctor status change event to all connected clients
const emitDoctorStatusChange = (doctorId, isActive) => {
  if (!io) {
    console.log('Socket.io not initialized, cannot emit doctor status change');
    return;
  }
  
  console.log(`Broadcasting doctor status change: ${doctorId} is now ${isActive ? 'active' : 'inactive'}`);
  
  // Broadcast to all connected clients
  io.emit('doctorStatusChanged', { 
    doctorId,
    isActive,
    timestamp: new Date()
  });
};

// Function to emit a new call request event to the doctor
const emitNewCallRequest = (doctorId, patientId, requestId) => {
  if (!io) {
    console.log('Socket.io not initialized, cannot emit new call request');
    return;
  }
  
  console.log(`Emitting new call request notification to doctor ${doctorId}`);
  
  // Check if doctor is connected
  const doctorSocket = connectedUsers.get(doctorId);
  if (doctorSocket) {
    console.log(`Doctor ${doctorId} is connected, sending direct notification`);
  } else {
    console.log(`Doctor ${doctorId} is not connected, broadcasting to room`);
  }
  
  // Emit to the specific doctor's room
  io.to(doctorId).emit('newCallRequest', {
    doctorId,
    patientId,
    requestId,
    timestamp: new Date()
  });
  
  // Also broadcast to everyone (not just the specific doctor)
  io.emit('newCallRequest', { 
    doctorId,
    patientId,
    requestId,
    broadcast: true,
    timestamp: new Date()
  });
};

// Function to emit a call request status update event
const emitCallRequestStatusUpdate = (doctorId, patientId, requestId, status) => {
  if (!io) {
    console.log('Socket.io not initialized, cannot emit call request status update');
    return;
  }
  
  console.log(`Emitting call request status update: ${requestId} is now ${status}`);
  
  // Create the update data
  const updateData = {
    doctorId,
    patientId,
    requestId,
    status,
    timestamp: new Date()
  };
  
  // Emit to both patient and doctor
  if (doctorId) {
    console.log(`Sending status update to doctor: ${doctorId}`);
    io.to(doctorId).emit('callRequestStatusUpdated', updateData);
  }
  
  if (patientId) {
    console.log(`Sending status update to patient: ${patientId}`);
    io.to(patientId).emit('callRequestStatusUpdated', updateData);
  }
  
  // Also broadcast to everyone
  console.log('Broadcasting status update to all clients');
  io.emit('callRequestStatusUpdated', {
    ...updateData,
    broadcast: true
  });
};

module.exports = setupSocketServer;
module.exports.emitDoctorStatusChange = emitDoctorStatusChange;
module.exports.emitNewCallRequest = emitNewCallRequest;
module.exports.emitCallRequestStatusUpdate = emitCallRequestStatusUpdate; 