
namespace Playground {
    // Data for map claim coroutine (see CheckMedals())
    string ClaimingMapUid;

    void LoadMap(int TmxID) {
        startnew(LoadMapCoroutine, CoroutineData(TmxID));
    }

    class CoroutineData {
        int Id;

        CoroutineData(int id) { this.Id = id; }
    }

    // This code is mostly taken from Greep's RMC
    void LoadMapCoroutine(ref@ Data) {
        int TmxID = cast<CoroutineData>(Data).Id;
        ClosePauseMenu();
        auto App = cast<CTrackMania>(GetApp());

        // Go to main menu and wait until map loading is ready
        App.BackToMainMenu();
        while (!App.ManiaTitleControlScriptAPI.IsReady) {
            yield();
        }

        App.ManiaTitleControlScriptAPI.PlayMap("https://trackmania.exchange/maps/download/" + TmxID, "", "");
    }

    void ClosePauseMenu() {
        auto App = cast<CTrackMania>(GetApp());
        bool MenuDisplayed = App.ManiaPlanetScriptAPI.ActiveContext_InGameMenuDisplayed;
        if (MenuDisplayed) {
            CSmArenaClient@ Playground = cast<CSmArenaClient>(App.CurrentPlayground);
            if(Playground !is null) {
                Playground.Interface.ManialinkScriptHandler.CloseInGameMenu(CGameScriptHandlerPlaygroundInterface::EInGameMenuResult::Resume);
            }
        }
    }

    CGameCtnChallenge@ GetCurrentMap() {
        auto App = cast<CTrackMania>(GetApp());
        return App.RootMap;
    }

    // Once again, this is mostly from RMC
    // Only returns a defined value during the finish sequence of a run
    int GetCurrentMedal() {
        // This is GetCurrentMap(), but because App is used in the function,
        // we redefine it here
        auto App = cast<CTrackMania>(GetApp());
        auto Map = App.RootMap;

        auto Playground = cast<CGamePlayground>(App.CurrentPlayground);
        if (Map is null || Playground is null) return -1;

        int AuthorTime = Map.TMObjective_AuthorTime;
        int GoldTime = Map.TMObjective_GoldTime;
        int SilverTime = Map.TMObjective_SilverTime;
        int BronzeTime = Map.TMObjective_BronzeTime;
        int Time = -1;

        auto PlaygroundScript = cast<CSmArenaRulesMode>(App.PlaygroundScript);
        if (PlaygroundScript is null || Playground.GameTerminals.Length == 0) return -1;

        CSmPlayer@ Player = cast<CSmPlayer>(Playground.GameTerminals[0].ControlledPlayer);
        if (Playground.GameTerminals[0].UISequence_Current != SGamePlaygroundUIConfig::EUISequence::Finish || Player is null) return -1;

        CSmScriptPlayer@ PlayerScriptAPI = cast<CSmScriptPlayer>(Player.ScriptAPI);
        auto Ghost = PlaygroundScript.Ghost_RetrieveFromPlayer(PlayerScriptAPI);
        if (Ghost is null) return -1;

        if (Ghost.Result.Time > 0 && Ghost.Result.Time < 4294967295) Time = Ghost.Result.Time;
        PlaygroundScript.DataFileMgr.Ghost_Release(Ghost.Id);

        if (Time != -1) {
            int Medal = -1;
            if (Time <= BronzeTime) Medal = 3;
            if (Time <= SilverTime) Medal = 2;
            if (Time <= GoldTime) Medal = 1;
            if (Time <= AuthorTime) Medal = 0;
            return Medal;
        }
        return -1;
    }

    // Watching task that claims cells when certain medals are achieved
    void CheckMedals() {
        if (ClaimingMapUid != "") return; // Request in progress
        int Medal = GetCurrentMedal();
        if (Medal == -1) return;

        auto MapNod = GetCurrentMap();
        auto GameMap = Room.GetMapWithUid(MapNod.EdChallengeId); // Hi, Ed!
        if (GameMap.TmxID == -1) return;
        if (GameMap.ClaimedTeam != -1) return;

        int TargetMedal = Room.TargetMedal;
        if (Medal <= TargetMedal) {
            // Map should be claimed
            ClaimingMapUid = GameMap.Uid;
            startnew(function() { Network::ClaimCell(ClaimingMapUid); ClaimingMapUid = ""; });
        }
    }
}