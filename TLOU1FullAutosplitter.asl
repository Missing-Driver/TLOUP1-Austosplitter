// Base address signatures:
    // task base: 48 8B 0D ?? ?? ?? ?? 48 8B 01 FF 50 ?? E8 ?? ?? ?? ?? 48 8B C8
    // timeListBase: 48 8B 0D ?? ?? ?? ?? 41 8D 55 30 48 81 C1
    // segmentTime/isSpeedrun base: 48 8D 0D ?? ?? ?? ?? E8 ?? ?? ?? ?? 8B 48 18 E8
    // isMainMenu: C6 05 ?? ?? ?? ?? 01 C3 CC CC CC CC CC CC CC CC C6 05 ?? ?? ?? ?? 00

state("tlou-i", "v1.1.4.0-Steam"){
    string52 task : 0x6427ED0, 0x80; // Task ID string
    ulong timeListBase : 0x5F27188; // Segment time list supercontainer
    double segmentTime : 0x34E2FE0, 0x4960; // Running segment time
    byte isSpeedrun : 0x34E2FE0, 0x477C; // Speedrun mode flag
    byte isMainMenu : 0x35D8CE8; // Menu boolean flag
}
state("tlou-i", "v1.1.5.0-Steam"){
    string52 task : 0x6433150, 0x80; // Task ID string
    ulong timeListBase : 0x5F31438; // Segment time list supercontainer
    double segmentTime : 0x34ECFE0, 0x4960; // Running segment time
    byte isSpeedrun : 0x34ECFE0, 0x477C; // Speedrun mode flag
    byte isMainMenu : 0x35E2CE8; // Menu boolean flag
}

startup{
    // Object containing useful functions:
    vars.Funcs = new ExpandoObject();

    // Stores the memory addresses containing the completed segment times.
    // Used to calculate the accurate IGT:
    vars.timeListPointers = new List<ulong>();
    vars.timeListOffset = 0xDA640; // Segment time list offset
    vars.nSegments = 30; // Amount of segments (chapters)

    // Keeps track of which checkpoints already caused a split:
    vars.splitted = new HashSet<string>();

    // Calculates the hash of a given module.
    // Based on ISO2768mK's Horizon Forbidden West load remover
    // (Used to determine the running game version):
    vars.Funcs.hashModule = (Func<ProcessModuleWow64Safe, string>)((module) => {
        byte[]  hashBytes = new byte[0];
        using (var MD5Object = System.Security.Cryptography.MD5.Create())
        {
            using (var binary = File.Open(module.FileName, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
            {
                hashBytes = MD5Object.ComputeHash(binary);
            }
        }
        var hexHashString = hashBytes.Select(x => x.ToString("X2")).Aggregate((a, b) => a + b);
        return hexHashString;
    });

    // Initialize the segment time list.
    // The segment list on memory is an array of 4 byte slots where the completed segment
    // times are stored (in milliseconds). The game uses this list to calculate the in-game speedrun time:
    vars.Funcs.initTimePointerList = (Action<ulong>)((timeListContainer) => {
        vars.timeListPointers = new List<ulong>();
        // Adds a new pointer address for every segment time slot:
        for(int i = 0; i <= vars.nSegments; i++){
            vars.timeListPointers.Add(
                // Time list super container + time list start address + time slot (4 bytes)
                timeListContainer + (ulong)(vars.timeListOffset + (i * 4))
            );
        }
    });

    //Calculates undeniably, perfectly accurate IGT (exactly as the game does):
    vars.Funcs.getAccurateIGT = (Func<System.Diagnostics.Process, double, bool, TimeSpan>)((gameInstance, currentSegmentTime, speedrunMode) => {
        int IGT = 0;
        double adjustedSegmentTime = currentSegmentTime;
        if(speedrunMode){ // Only if speedrun mode is on:
            for(int i = 0; i <= vars.nSegments; i++){ // Sum of all the segment times:
                IGT += gameInstance.ReadValue<int>((IntPtr)(vars.timeListPointers[i]));
            }
        }
        // The game multiplies by 1000 the double segment time value to get the milliseconds,
        // then truncates the result to keep it as an integer, and adds it to the sum of saved times:
        IGT += (int)(adjustedSegmentTime * 1000);
        // Since the in game timer only displays hundreds of milliseconds, the game rounds the time:
        IGT = (int)(Math.Round(IGT / 100.0) * 100.0); // round to nearest 100 ms
        // Don't ask me why it does all of this, I didn't developed the game...
        // Returns IGT from calculated milliseconds:
        return new TimeSpan(0, 0, 0, 0, IGT);
    });

    // CONTAINS THE AUTOSPLITTER SETTINGS AND SPLITS:
    dynamic[,] _settings = {
        // ID, Label, Tool tip, Parent ID, Default setting?
        // MAIN GAME
        {"main_game", "Main game", "Main game splits", null, true},
            // STARTING POINTS
            {"mg_starting_points", "Starting points", "Select when livesplit will start the timer", "main_game", true},
                // This accounts for the RTA timer start, although the IGT will be paused:
                {"hom-intro-start", "Any% / NG+", "When the 1st cutscene starts playing (this is when the game actually starts)", "mg_starting_points", true},
            // CHAPTERS:
            {"mg_chapters", "Chapters", null, "main_game", true},
                // HOMETOWN
                {"mg_hometown", "Hometown", null, "mg_chapters", true},
                    // Prologue
                    {"mil-street-start", "Prologue completion", "After skipping Sarah's death cutscene", "mg_hometown", true},
                // QUARANTINE ZONE
                {"mg_quarantine", "Quarantine Zone", null, "mg_chapters", true},
                    // 20 years later
                    {"mil-checkpoint-truck-explode", "FEDRA checkpoint", "When reaching the checkpoint checkpoint :P", "mg_quarantine", true},
                    {"mil-exterior-in-the-tunnel", "20 years later completion", "After entering the secret passage behind the bookshelf", "mg_quarantine", true},
                    // Beyond the Wall
                    {"mil-exterior-first-ladder-end", "Ladder checkpoint", "After getting on the ladder", "mg_quarantine", true},
                    {"mil-exterior-warehouse", "Pallet secret entrance unlocked", "Right when the pallet 'door' becomes active", "mg_quarantine", true},
                    {"mil-city-back-to-city", "Beyond the Wall completion", "After talking to the kid and getting out the room", "mg_quarantine", true},
                    // The slums
                    {"mil-tess-market-b", "Brive cutscene", "When the brive cutscene starts playing", "mg_quarantine", true},
                    {"mil-city-melee-tutorial-igc", "The slums 1st encounter start", "When the unskipable cutscene starts playing", "mg_quarantine", true},
                    {"mil-city-over-the-fence", "The slums 1st encounter end", "After killing the first smugglers", "mg_quarantine", true},
                    {"mil-city-dock-warehouse-exit", "The slums 3rd encounter end", "After killing the smugglers inside the warehouse, before the lift gate", "mg_quarantine", true},
                    {"mil-escape-alley", "The slums completion", "After skipping Robert's final cutscene", "mg_quarantine", true},
                    // The cargo
                    {"out-wasteland-elevator", "The cargo  completion", "After reaching the meeting point, after skipping the cutscene", "mg_quarantine", true},
                // THE OUTSKIRTS
                {"mg_outskirts", "The Outskirts", null, "mg_chapters", true},
                    // Outside
                    {"out-wasteland-broken-bridge", "Outside completion", "After skipping the tunnel gate cutscene", "mg_outskirts", true},
                    // Downtown
                    {"out-downtown-tilted-building-cafeteria-puzzle-end", "Tilted building cafeteria puzzle", "After entering the new room", "mg_outskirts", true},
                    {"out-downtown-tilted-building-subway", "Subway section cleared", "After leaving the subway area", "mg_outskirts", true},
                    {"out-downtown-state-house-loading-dock", "Downtown completion", "After skipping the lift gate cutscene", "mg_outskirts", true},
                    // The museum
                    {"out-park-alley", "The museum completion", "After skipping the plank cutscene", "mg_outskirts", true},
                    // The Capitol
                    {"bil-intro-fx", "The Capitol building completion", "After skipping the subway exit cutscene", "mg_outskirts", true},
                // BILL'S TOWN
                {"mg_bill", "Bill's Town", null, "mg_chapters", true},
                    // The woods
                    {"bil-bar-explore", "The woods completion", "After skipping the safehouse cutscene at the bar", "mg_bill", true},
                    // Safehouse
                    {"bil-church-training", "Safehouse completion", "After skipping the entering church basement cutscene", "mg_bill", true},
                    // Graveyard
                    {"bil-residential-backyards-start", "Graveyard exit", "After exiting the graveyard area", "mg_bill", true},
                    {"bil-residential-house", "House backyard", "After jumping from the plank into the house backyard, pre-highschool encounter", "mg_bill", true},
                    {"bil-highschool-shop", "Graveyard completion", "After skipping the Highschool window cutscene", "mg_bill", true},
                    // High school escape
                    {"bill-find-truck", "Ladder cutscene", "When the ladder cutscene starts playing", "mg_bill", true},
                    {"bil-escape-outro", "Truck scape", "After getting on the truck, when the cutscene starts", "mg_bill", true},
                    {"hun-underpass-slam-intro", "High school escape completion", "After skipping the last truck cutscene", "mg_bill", true},
                // PITTSBURGH
                {"mg_pittsburgh", "Pittsburgh", null, "mg_chapters", true},
                    // Alone and forsaken
                    {"hun-underpass-hunter-camp", "Pittsburgh lift gate", "After the 1st encounter, after the lift gate", "mg_pittsburgh", true},
                    {"hun-checkpoint-maze", "Turnstile", "When reaching the turnstile", "mg_pittsburgh", true},
                    {"hun-hotel-lobby-traverse", "Alone and forsaken completion", "Right after jumping into the hotel", "mg_pittsburgh", true},
                    // Hotel Lobby
                    {"hun-hotel-basement-maze", "Swimming segment", "After reaching the swimming segment at the basement", "mg_pittsburgh", true},
                    {"hun-hotel-kitchen-restaurant-fight", "Restaurant kitchen", "Entering the kitchen", "mg_pittsburgh", true},
                    {"hun-ellie-gun", "Ellie saves Joel", "After Ellie shoots the bad guy and the cutscene starts", "mg_pittsburgh", true},
                    {"hun-financial-plaza-fight", "Hotel Lobby completion", "After exiting the hotel and skipping the financial discrict cutscene", "mg_pittsburgh", true},
                    // Financial district
                    {"hun-financial-plaza-seek-exit", "Financial district 1st enconter end", "After skipping Ellie's cutscene", "mg_pittsburgh", true},
                    {"hun-financial-libertyave-fireescape", "Financial district 2nd encounter end", "After killing all the enemies", "mg_pittsburgh", true},
                    {"hun-financial-chase-approach", "Financial district Bus jump", "After climbing the fire ladder and jumping over the bus", "mg_pittsburgh", true},
                    {"hun-camp-apartment-start", "Financial district completion", "After meeting Henry and Sam for the first time and skipping the cutscene", "mg_pittsburgh", true},
                    // Escape the city
                    {"hun-camp-alley-post-fight", "Toy store fight end", "After killing the enemies at the back of the Toy store", "mg_pittsburgh", true},
                    {"hun-overlook-camp", "Henry's office", "'Welcome to my office' cutscene", "mg_pittsburgh", true},
                    {"hun-bridge-henry-and-sam-separated", "Separate ways", "When the cutscene where Henry and Sam go, starts playing", "mg_pittsburgh", true},
                    {"sub-riverbank-start", "Escape the city completion", "After skipping the bridge cutscene", "mg_pittsburgh", true},
                // THE SUBURBS
                {"mg_suburbs", "The Suburbs", null, "mg_chapters", true},
                    // The sewers
                    {"sub-sewer-alarm", "Alarm door", "When openning the alarm door at the sewers", "mg_suburbs", true},
                    {"sub-joel-trips-door-trap", "Door trap", "When triggering the door trap at the sewers", "mg_suburbs", true},
                    {"sub-sewer-old-camp-sprint-to-sam-crawl", "Reunion", "When all our heroes reunite... again", "mg_suburbs", true},
                    {"sub-exploration-start", "The sewers completion", "After the sewers exit animation finishes", "mg_suburbs", true},
                    // Suburbs
                    {"sub-sniper-chase-start", "Sniper death", "After killing that annoying sniper", "mg_suburbs", true},
                    {"tom-path-intro-igc", "Suburbs completion", "After skipping the final cutscene, after the snipper sequence", "mg_suburbs", true},
                // TOMMY'S DAM
                {"mg_dam", "Tommy's Dam", null, "mg_chapters", true},
                    // Hydroelectric dam
                    {"tom-reunited-with-tommy", "Gate cutscene", "When the cutscene starts", "mg_dam", true},
                    {"tom-what-to-do-with-ellie", "Tommy's dialog skip", "After the dialog skip, when Joel enters the room and the cutscene starts playing", "mg_dam", true},
                    {"tom-road-find-ellie-follow-road", "Hydroelectric dam completion", "After skipping Maria's cutscene, after the pump room fight", "mg_dam", true},
                    // Ranch house
                    {"tom-road-find-ellie-post-ambush", "Ambush fight end", "After killing those annoying MFs", "mg_dam", true},
                    {"tom-ranch-find-ellie-ranch-vista", "Ranch road skip", "On the way to the ranch, when you RC to skip part of the road", "mg_dam", true},
                    {"uni-1-depo-start", "Ranch house completion", "After leaving the ranch house and skipping the cutscene", "mg_dam", true},
                // THE UNIVERSITY
                {"mg_university", "The University", null, "mg_chapters", true},
                    // Go big horns
                    {"uni-1-library-generator", "Library encounter", "After killing the Z's ant the library", "mg_university", true},
                    {"uni-2-dorms-nest-end", "Dorms stealth section end", "After the door scripted animation", "mg_university", true},
                    {"uni-4-lab-start", "Go big horns completion", "After entering the lab", "mg_university", true},
                    // Science building
                    {"uni-ambush", "Ambush cutscene at the lab", "After forcing the door, when the cutscene starts", "mg_university", true},
                    {"lak-forest-deer-hunt-start-igc", "Science building completion", "After skipping the two cutscenes following the science building exit", "mg_university", true},
                // LAKESIDE RESORT
                {"mg_lakeside", "Lakeside Resort", null, "mg_chapters", true},
                    // The hunt
                    {"lak-mining-camp", "Deer cutscene", "When the dead deer cutscene starts playing", "mg_lakeside", true},
                    {"lak-mine-flee-down-hall", "Coal mine 1st encounter end", "After David breaks the door, while walking throug the hall way", "mg_lakeside", true},
                    {"lak-mine-close-door-igc", "Coal mine ladder", "After climbing the ladder", "mg_lakeside", true},
                    {"lak-ellie-leaves-hideout-on-horse-igc", "The hunt completion", "After skipping David's cutscene at the coal mines", "mg_lakeside", true},
                    // Cabin resort
                    {"lak-resort-beach-fight", "Horse segment end", "Afther the scripted horse death animation", "mg_lakeside", true},
                    {"lak-resort-trail-start", "First stealth section cleared", "After jumping down towards the pipe", "mg_lakeside", true},
                    {"lak-kitchen-awake", "Cannibal kitchet cutscene", "When the cutscene starts playing", "mg_lakeside", true},
                    {"lak-town-ellie-lands-in-alleyway-igc", "Ellie's stealth section start", "More like a running section actually...", "mg_lakeside", true},
                    {"lak-town-approach-joel", "Joel's running section start", "When Joels arrive to Silver Lake", "mg_lakeside", true},
                    {"lak-town-approach-joel-exits-meatshop-igc", "Joel reaches the steakhouse", "After the scripted animation starts, when Joel opens the door", "mg_lakeside", true},
                    {"wild-1-intro", "Cabin resort completion", "After skipping the final cutscene at the steakhouse", "mg_lakeside", true},
                // BUS DEPOT
                {"mg_bus", "Bus Depot", null, "mg_chapters", true},
                    // Highway exit
                    {"wild-2-tunnel-entrance", "Highway exit completion", "After crossing the bus", "mg_bus", true},
                    // Underground tunnel
                    {"wild-3-underground-combat-start", "Stealth section start", "Again, more like a running section...", "mg_bus", true},
                    {"wild-3-flooded-tunnel", "Stealth section cleared", "After jumping down from the trailer", "mg_bus", true},
                    {"lab-start-1", "Underground tunnel completion", "After skipping Ellie's drawning cutscene", "mg_bus", true},
                // THE FIREFLY LAB
                {"mg_lab", "The Firefly Lab", null, "mg_chapters", true},
                    // The hospital
                    {"lab-stairwell-1", "The hospital 1st section cleared", "After the scripted door animation at the end of the lower floor", "mg_lab", true},
                    {"lab-opperating-room-start-1", "The hospital 2nd section cleared", "After the scripted door animation at the end of the upper floor", "mg_lab", true},
                    {"lab-3-post-jump-out-of-jeep", "The hospital completion", "After skipping the post-elevator cutscene", "mg_lab", true},
                // JACKSON
                {"mg_jackson", "Jackson", null, "mg_chapters", true},
                    // Epilogue
                    {"end-game-outro", "Epilogue", "After taking Joel's hand", "mg_jackson", true},
    };

    // Initialize autosplitter settings
    for (int i = 0; i < _settings.GetLength(0); i++){
        // Autosplitter settings entry:
        // settings.Add(id, default_value = true, description = null, parent = null)
        settings.Add(_settings[i, 0], _settings[i, 4], _settings[i, 1], _settings[i, 3]);

        // Tool tip message (if available)
        if(_settings[i, 2] != null){
            settings.SetToolTip(_settings[i, 0], _settings[i, 2]);
        }
    }
}

init{
    // Signals if the time list has to be initiliazed:
    vars.isTimeListReady = false;
    // Identifying game version:
    var module = modules.First(); // tlou-i.exe
    string hash = vars.Funcs.hashModule(module);
    print("\nGAME HASH: " + hash + "\n");

    switch(hash){
        case("2E150B5FE343E3496384B5D3E1547591"):
            version = "v1.1.4.0-Steam";
            break;
        case("5899F93E00BA8D34F87C3B643D6B1274"):
            version = "v1.1.5.0-Steam";
            break;
        // TODO: add the Epic games version hashes:
        case("0"):
            version = "v1.1.5.0-EpicGames";
            break;
        // Default version: Patch 1.1.5.0 Steam:
        default:
            version = "v1.1.5.0-Steam";
            // If no version was identified, show a warning message:
            MessageBox.Show(
                "The Autosplitter could not identify the game version, the default version was set to " + version + ".\nIf this is not the version of your game, the Autosplitter might not work properly.",
                "TLOU Autosplitter",
                MessageBoxButtons.OK,
                MessageBoxIcon.Warning
            );
            break;
    }
    print("\nSELECTED GAME VERSION: " + version + "\n");

    // Initialize the time list if the timeListBase pointer is not empty:
    if(current.timeListBase != null && current.timeListBase > 0){
        print("\nUPDATING TIME LIST POINTERS [INIT]...\n");
        vars.Funcs.initTimePointerList(current.timeListBase);
        vars.isTimeListReady = true;
    }
}

update{
    // Fall back for an empty timeListBase pointer.
    // It executes only once:
    if(!vars.isTimeListReady && current.timeListBase != null && current.timeListBase > 0){
        print("\nUPDATING TIME LIST POINTERS [UPDATE]...\n");
        vars.Funcs.initTimePointerList(current.timeListBase);
        vars.isTimeListReady = true;
    }
}

isLoading{
    // As described in the official documentation (https://github.com/LiveSplit/LiveSplit.AutoSplitters#game-time-1),
    // we permanently return true to avoid timer flickering:
    return true;
}

start{
    return // Start the timer if:
        settings.ContainsKey(current.task + "-start") && // the current segment is a valid starting point,
        settings[current.task + "-start"] && // this starting point was selected by the user in the settings,
        current.segmentTime == 0 // the in-game timer is 00:00:00.0
        && current.isMainMenu == 0; // and we are not in  the main menu
}

// Pegs the LiveSplit GameTime timer to the game's IGT.
gameTime{
    // All this does is add the segment times from memory and the current segment time
    // if speedrun mode is on, or only the current segment time otherwise
    // (just like the in-game timer does):
    return vars.Funcs.getAccurateIGT(game, current.segmentTime, current.isSpeedrun == 1);
}

split {
    if(
        current.task != old.task && // On task change,
        settings.ContainsKey(current.task) && // if the current segment is part of the split list,
        settings[current.task] && // and if the current segment was selected by the user in the settings,
        !vars.splitted.Contains(current.task) // and the current segment hasn't been split before, then:
    ){
        vars.splitted.Add(current.task); // Add the segment to the list of already split segments
        print("SPLIT: " + current.task);
        return true; // Split
    }
}

onReset{
    // Resets the list of split segments:
    vars.splitted = new HashSet<string>();
}
