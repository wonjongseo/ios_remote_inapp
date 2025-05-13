import http from "http";
import { Server } from "socket.io";
import express from "express";
import path from "path";
const __dirname = path.resolve();
const app = express();

app.set("view engine", "pug");
app.set("views", __dirname + "/views");

app.use("/public", express.static(__dirname + "/public"));
app.get("/", (_, res) => res.render("home"));
// app.get("/*", (req, res) => res.redirect("/"));

const handleListen = () => console.log(`Listening on http://localhost:3000`);
// app.listen(3000, handleListen);
const httpServer = http.createServer(app);
const wsServer = new Server(httpServer, {});

wsServer.on("connection", (socket) => {
  console.log("connection");

  socket.on("join_room", (roomName) => {
    console.log("JOIN ");
    console.log("roomName: ", roomName);
    socket.join(roomName);
    socket.to(roomName).emit("welcome");
  });

  socket.on("offer", (data) => {
    socket.to(data.roomName).emit("offer", data.offer);
  });
  socket.on("answer", (data, roomName) => {
    console.log("data: ", data);
    socket.to(data.roomName).emit("answer", { sdp: data.answer.sdp, type: data.answer.type });
  });
  socket.on("ice", (data) => {
    console.log("ice: ", data);

    socket.to(data.roomName).emit("ice", {
      candidate: data.ice?.candidate,
      sdpMid: data.ice?.sdpMid,
      sdpMLineIndex: data.ice?.sdpMLineIndex,
    });
  });
});
httpServer.listen(3000, handleListen);
