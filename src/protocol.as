// Implementation of a full TCP custom protocol, similar to websockets
class HandshakeData {
    string ClientVersion;
    string AuthToken;

    Json::Value ToJSON() {
        auto object = Json::Object();
        object["version"] = ClientVersion;
        object["token"] = AuthToken;
        return object;
    }
}

class Protocol {
    Net::Socket@ Socket;
    ConnectionState State;
    int MsgSize;

    Protocol() {
        @Socket = null;
        State = ConnectionState::Closed;
        MsgSize = 0;
    }

    void Connect(const string&in host, uint16 port, HandshakeData handshake, uint timeout = 5000) {
        State = ConnectionState::Connecting;
        @Socket = Net::Socket();
        MsgSize = 0;
        
        // Socket Creation
        if (!Socket.Connect(host, port)) {
            trace("Protocol: Could not create socket to connect to " + host + ":" + port + ".");
            Fail();
            return;
        }
        trace("Protocol: Socket bound and ready to connect to " + host + ":" + port + ".");

        // Connection
        uint64 TimeoutDate = Time::Now + timeout;
        uint64 InitialDate = Time::Now;
        while (!Socket.CanWrite() && Time::Now < TimeoutDate) { yield(); }
        if (!Socket.CanWrite()) {
            trace("Protocol: Connection timed out after " + timeout + "ms.");
            Fail();
            return;
        }
        trace("Protocol: Connected to server after " + (Time::Now - InitialDate) + "ms.");

        // Opening Handshake
        if (!InnerSend(Json::Write(handshake.ToJSON()))) {
            trace("Protocol: Failed sending opening handshake.");
            Fail();
            return;
        }
        trace("Protocol: Opening handshake sent.");

        string HandshakeReply = BlockRecv(timeout);
        if (HandshakeReply == "") {
            trace("Protocol: Handshake reply reception timed out after " + timeout + "ms.");
            Fail();
            return;
        }

        // Handshake Check
        int StatusCode;
        try {
            Json::Value@ Reply = Json::Parse(HandshakeReply);
            StatusCode = Reply["code"];
        } catch {
            trace("Protocol: Handshake reply parse failed. Got: " + HandshakeReply);
            Fail();
            return;
        }

        if (StatusCode == 0) {
            trace("Protocol: Handshake reply validated. Connection has been established!");
            State = ConnectionState::Connected;
        } else {
            trace("Protocol: Received non-zero code " + StatusCode + " in handshake.");
            Fail();
            return;
        }
    }

    private bool InnerSend(const string&in data) {
        MemoryBuffer@ buf = MemoryBuffer(4);
        buf.Write(data.Length);
        buf.Seek(0);
        return Socket.WriteRaw(buf.ReadString(4) + data);
    }

    string BlockRecv(uint timeout) {
        uint TimeoutDate = Time::Now + timeout;
        string Message = "";
        while (Message == "" && Time::Now < TimeoutDate) { yield(); Message = Recv(); }
        return Message;
    }

    string Recv() {
        if (MsgSize == 0) {
            if (Socket.Available() >= 4) {
                MemoryBuffer@ buf = MemoryBuffer(4);
                buf.Write(Socket.ReadRaw(4));
                buf.Seek(0);
                int Size = buf.ReadInt32();
                if (Size <= 0) {
                    // TODO: fail
                    trace("Protocol: buffer size violation (got " + Size + ").");
                }
                MsgSize = Size;
            }
        }

        if (MsgSize != 0) {
            if (Socket.Available() >= MsgSize) {
                string Message = Socket.ReadRaw(MsgSize);
                MsgSize = 0;
                return Message;
            }
        }

        return "";
    }

    void Fail() {
        trace("Protocol: Connection fault. Closing.");
        State = ConnectionState::Closed;
        @Socket = null;
        MsgSize = 0;
    }
}

enum ProtocolFailure {
    SocketCreation,
    Timeout
}

enum ConnectionState {
    Closed,
    Connecting,
    Connected,
    Closing
}