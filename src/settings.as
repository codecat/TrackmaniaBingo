namespace Settings {
    [Setting name="Backend Server URL" category="Debug"]
    string BackendAddress = "38.242.214.20";

    [Setting name="Backend TCP Port" category="Debug"]
    uint16 BackendPort = 6900;
    
    [Setting name="Connection Timeout" category="Debug"]
    uint NetworkTimeout = 10000;

    [Setting name="Server Ping Interval" category="Debug"]
    uint PingInterval = 30000;

    [Setting name="Developer Mode" category="Debug"]
    bool DevMode = false;
}