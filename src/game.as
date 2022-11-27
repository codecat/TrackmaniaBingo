// Global active room
GameRoom Room;
// Milliseconds time until game starts (displayed while loading maps)
int StartCountdown;

class GameRoom {
    bool Active;
    bool InGame;
    string JoinCode;
    array<Player>@ Players = {};
    int MaxPlayers;
    MapMode MapSelection;
    int MappackId;
    Medal TargetMedal;
    array<Map>@ MapList = {};
    LoadStatus MapsLoadingStatus = LoadStatus::Loading;
    string HostName;
    bool LocalPlayerIsHost;
    EndState EndState;

    Map GetMapWithUid(string&in uid) {
        for (uint i = 0; i < MapList.Length; i++) {
            Map SelectedMap = MapList[i];
            if (SelectedMap.Uid == uid) return SelectedMap;
        }

        return Map();
    }

    int GetMapCellId(string&in uid) {
        for (uint i = 0; i < MapList.Length; i++) {
            Map SelectedMap = MapList[i];
            if (SelectedMap.Uid == uid) return i;
        }

        return -1;
    }

    Player@ GetSelf(){
        for (uint i = 0; i < Room.Players.Length; i++){
            auto player = Room.Players[i];
            if (player.IsSelf)
                return player;
        }
        return null;
    }
}

class Player {
    string Name;
    int Team;
    bool IsSelf;

    Player() { }

    Player(string&in name, int team, bool self) {
        this.Name = name;
        this.Team = team;
        this.IsSelf = self;
    }
}

class Map {
    string Name;
    string Author;
    int TmxID = -1; // Used to compare whether a map is valid
    string Uid;
    int ClaimedTeam = -1;
    RunResult ClaimedRun;
    CachedImage@ Thumbnail;
    CachedImage@ MapImage;

    Map() { }

    Map(string&in name, string&in author, int tmxid, string&in uid) {
        this.Name = name;
        this.Author = author;
        this.TmxID = tmxid;
        this.Uid = uid;
        @this.Thumbnail = Images::CachedFromURL("https://trackmania.exchange/maps/screenshot_normal/" + tmxid);
        @this.MapImage = Images::CachedFromURL("https://trackmania.exchange/maps/" + tmxid + "/image/1"); // Do not use /imagethumb route, Openplanet can't understand WEBP
    }
}

class EndState {
    BingoDirection BingoDirection;
    int Offset; // Horizontal: Row ID, Vertical: Column ID, Diagonal: 0 -> TL to BR & 1 -> BL to TR
    uint64 EndTime;

    bool HasEnded() {
        return this.BingoDirection != BingoDirection::None;
    }
}

class RunResult {
    int Time = -1;
    Medal Medal = Medal::None;

    RunResult() { }
    RunResult(int time, Medal medal) {
        this.Time = time;
        this.Medal = medal;
    }

    string Display() {
        return symbolOf(this.Medal) + "\\$z " + Time::Format(this.Time);
    }
}

enum MapMode {
    TOTD,
    MXRandom,
    Mappack
}

string stringof(MapMode mode) {
    if (mode == MapMode::TOTD) {
        return "Track of the Day";
    }
    if (mode == MapMode::MXRandom) {
        return "Random Map (TMX)";
    }
    return "Selected Mappack";
}

enum BingoDirection {
    None,
    Horizontal,
    Vertical,
    Diagonal
}

enum LoadStatus {
    Loading,
    LoadSuccess,
    LoadFail
}

// Game tick function
void Tick(int dt) {
    if (Room.InGame && !Room.EndState.HasEnded()) {
        Playground::CheckMedals();
    }

    // Update countdown
    if (StartCountdown > 0) {
        StartCountdown -= dt;
        if (dt >= StartCountdown) {
            Room.InGame = true;
            Window::Visible = false;
            MapList::Visible = true;
            InfoBar::StartTime = Time::Now;
        }
    }
}
