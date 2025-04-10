// index.js (updated with MongoDB and API routes)
const IO = require("socket.io");
const ngrok = require("ngrok");
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');

// Create Express app
const app = express();
let port = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// MongoDB Connection
mongoose.connect(process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/call-transcription', {
  useNewUrlParser: true,
  useUnifiedTopology: true
})
.then(() => console.log('MongoDB Connected'))
.catch(err => console.log('MongoDB Connection Error:', err));

// Routes
app.use('/api/transcriptions', require('./routes/transcription.routes'));

// Create HTTP server and attach socket.io
const server = app.listen(port, () => console.log(`Server running on port ${port}`));
const io = IO(server, {
  cors: {
    origin: true,
    methods: ["GET", "POST"],
  },
});

io.use((socket, next) => {
  if (socket.handshake.query) {
    let callerId = socket.handshake.query.callerId;
    socket.user = callerId;
    next();
  }
});

io.on("connection", (socket) => {
  console.log(socket.user, "Connected");
  socket.join(socket.user);

  socket.on("makeCall", (data) => {
    let calleeId = data.calleeId;
    let sdpOffer = data.sdpOffer;

    socket.to(calleeId).emit("newCall", {
      callerId: socket.user,
      sdpOffer: sdpOffer,
    });
  });

  socket.on("answerCall", (data) => {
    let callerId = data.callerId;
    let sdpAnswer = data.sdpAnswer;

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
  
  // Handle transcription events
  socket.on("transcription", (data) => {
    // Broadcast to the room for real-time updates
    socket.to(data.callId).emit("transcriptionUpdate", data);
  });
});

// 🚀 Start ngrok after server is up
(async function () {
  try {
    const url = await ngrok.connect({
      proto: "http",
      addr: port,
      authtoken: process.env.NGROK_TOKEN,
    });
    console.log(`\n🎉 Public URL (share this!): ${url}\n`);
  } catch (err) {
    console.error("Failed to start ngrok:", err);
  }
})();