import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const MyHomePage(title: 'Flutter Demo Home Page'));
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  String roomName = '1212';

  final _socket = IO.io(
    'http://192.168.3.72:3000',
    IO.OptionBuilder().setTransports(['websocket']).build(),
  );
  @override
  void initState() {
    _initSocket();
    super.initState();
  }

  void _initSocket() {
    _socket.onConnect((_) async {
      print('Socket.IO connected');
      await _makeCall();
      _socket.emit('join_room', roomName);
    });
    _socket.on('welcome', (_) async {
      try {
        if (_pc == null) return;
        RTCSessionDescription offer = await _pc!.createOffer();
        await _pc!.setLocalDescription(offer);

        _socket.emit('offer', {
          'offer': {'sdp': offer.sdp, 'type': offer.type},
          'roomName': roomName,
        });
      } catch (e) {
        print('e.toString() : ${e.toString()}');
      }
    });
    _socket.on("offer", (data) async {
      try {
        if (_pc == null) return;
        if (data['sdp'] == null || data['type'] == null) {
          return;
        }
        await _pc!.setRemoteDescription(
          RTCSessionDescription(data['sdp'], data['type']),
        );
        RTCSessionDescription answer = await _pc!.createAnswer();
        await _pc!.setLocalDescription(answer);

        _socket.emit('answer', {
          'answer': {'sdp': answer.sdp, 'type': answer.type},
          'roomName': roomName,
        });
      } catch (e) {
        print('e.toString() : ${e.toString()}');
      }
    });

    _socket.on("answer", (data) async {
      try {
        if (_pc == null) return;
        if (data['sdp'] == null || data['type'] == null) {
          return;
        }
        await _pc!.setRemoteDescription(
          RTCSessionDescription(data['sdp'], data['type']),
        );
      } catch (e) {
        print('e.toString() : ${e.toString()}');
      }
    });

    _socket.on("ice", (data) async {
      try {
        if (_pc == null) return;
        if (data['candidate'] == null ||
            data['sdpMid'] == null ||
            data['sdpMLineIndex'] == null) {
          return;
        }
        await _pc!.addCandidate(
          RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          ),
        );
      } catch (e) {
        print('e.toString() : ${e.toString()}');
      }
    });
  }

  Future<void> _makeCall() async {
    final config = {
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    };
    _pc = await createPeerConnection(config, {});

    // ICE candidate 전송
    _pc!.onIceCandidate = (candidate) {
      try {
        if (candidate.candidate != null &&
            candidate.sdpMid != null &&
            candidate.sdpMLineIndex != null) {
          _socket.emit('ice', {
            'ice': {
              'candidate': candidate.candidate,
              'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex,
            },
            'roomName': roomName,
          });
        } else {
          print('❌ Invalid ICE candidate: $candidate');
        }
      } catch (e) {
        print('e.toString() : ${e.toString()}');
      }
    };

    // iOS 화면 공유: getDisplayMedia를 지원하는 플러그인 가정
    // _localStream = await navigator.mediaDevices.getDisplayMedia({
    //   'video': true,
    //   'audio': false,
    // });
    // _pc!.addStream(_localStream!);

    _localStream = await navigator.mediaDevices.getDisplayMedia({
      'video': true,
      'audio': false,
    });
    _localStream!.getTracks().forEach((track) {
      _pc!.addTrack(track, _localStream!);
    });
    // _socket.emit('offer', offer.toMap());
  }

  int count = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('iOS画面共有'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              '$count',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 100),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            count++;
          });
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
