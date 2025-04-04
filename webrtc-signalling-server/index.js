const IO = require("socket.io");
const ngrok = require("ngrok");

let port = process.env.PORT || 5000;

const io = IO(port, {
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
