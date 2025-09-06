// Base address signatures:
    // TaskManager: 48 8B 0D ?? ?? ?? ?? 48 8B 01 FF 50 ?? E8 ?? ?? ?? ?? 48 8B C8
    // TimerBase: C5 F8 11 0D ?? ?? ?? ?? C5 F8 77 E8 ?? ?? ?? ?? 49 8B C5 48 8B 8D ?? ?? ?? ??
    // MainMenuFlag: C6 05 ?? ?? ?? ?? 01 C3 CC CC CC CC CC CC CC CC C6 05 ?? ?? ?? ?? 00
state("tlou-i", "v1.1.4.0-Steam"){
    // Timer:
    // TimerBase, 0x40, 0x488, 0xB38;
    int p1 : 0x067F4478, 0x40, 0x488, 0xB38; // first position
    // TimerBase, 0x40, 0x488, 0xB48;
    int p2 : 0x067F4478, 0x40, 0x488, 0xB48; // second position
    // TimerBase, 0x40, 0x488, 0xB58;
    int p3 : 0x067F4478, 0x40, 0x488, 0xB58; // third position
    // TimerBase, 0x40, 0x488, 0xB68;
    int p4 : 0x067F4478, 0x40, 0x488, 0xB68; // fourth position
    // TaskManager, 0x80:
    string52 task : 0x6427ED0, 0x80; // task ID string
    // MainMenuFlag:
    byte isMainMenu : 0x35D8CE8;
}
state("tlou-i", "v1.1.5.0-Steam"){
    // Timer:
    // TimerBase, 0x40, 0x488, 0xB38;
    int p1 : 0x67FFDE8, 0x40, 0x488, 0xB38; // first position
    // TimerBase, 0x40, 0x488, 0xB48;
    int p2 : 0x67FFDE8, 0x40, 0x488, 0xB48; // second position
    // TimerBase, 0x40, 0x488, 0xB58;
    int p3 : 0x67FFDE8, 0x40, 0x488, 0xB58; // third position
    // TimerBase, 0x40, 0x488, 0xB68;
    int p4 : 0x67FFDE8, 0x40, 0x488, 0xB68; // fourth position
    // TaskManager, 0x80:
    string52 task : 0x6433150, 0x80; // task ID string
    // MainMenuFlag:
    byte isMainMenu : 0x35E2CE8;
}

startup{
    // Object containing useful functions:
    vars.Funcs = new ExpandoObject();
    // Contains a copy of the previous time:
    vars.oldTime = new TimeSpan(0, 0, 0, 0, 0);
    // Keeps track of which checkpoints already caused a split:
    vars.splitted = new HashSet<string>();

    // Debug:
    // vars.fullTaskList = new List<string>();

    // Calculates the hash of a given module.
    // Taken from ISO2768mK's Horizon Forbidden West load remover:
    vars.Funcs.hashModule = (Func<ProcessModuleWow64Safe, string>)((module) => {
        byte[]  hashBytes = new byte[0];
        using (var sha256Object = System.Security.Cryptography.SHA256.Create())
        {
            using (var binary = File.Open(module.FileName, FileMode.Open, FileAccess.Read, FileShare.ReadWrite))
            {
                hashBytes = sha256Object.ComputeHash(binary);
            }
        }
        var hexHashString = hashBytes.Select(x => x.ToString("X2")).Aggregate((a, b) => a + b);
        return hexHashString;
    });

    // Contains the autosplitter settings and splits:
    dynamic[,] _settings = {
        // ID, Label, Tool tip, Parent ID, Default setting?
        // Main game
        {"main_game", "Main game", "Main game splits", null, true},
            // STARTING POINTS
            {"mg_starting_points", "Starting points", "Select when livesplit will start the timer", "main_game", true},
                // This accounts for the RTA timer start, although the IGT will be paused:
                {"hom-intro-start", "Any% / NG+", "When the 1st cutscene starts playing (this is when the game actually starts)", "mg_starting_points", true},
            {"mg_chapters", "Chapters", null, "main_game", true},
                {"mg_hometown", "Hometown", null, "mg_chapters", true},
                    {"mil-street-start", "Prologue completion", "After skipping Sarah's death cutscene", "mg_hometown", true},
                {"mg_quarantine", "Quarantine Zone", null, "mg_chapters", true},
                    {"mil-checkpoint-truck-explode", "FEDRA checkpoint", "When reaching the checkpoint checkpoint :P", "mg_quarantine", true},
                    {"mil-exterior-in-the-tunnel", "20 years later completion", "After entering the secret passage behind the bookshelf", "mg_quarantine", true},
                    {"mil-exterior-first-ladder-end", "Ladder checkpoint", "After getting on the ladder", "mg_quarantine", true},
                    {"mil-exterior-warehouse", "Pallet secret entrance unlocked", "Right when the pallet 'door' becomes active", "mg_quarantine", true},
                    {"mil-city-back-to-city", "Beyond the Wall completion", "After talking to the kid and getting out the room", "mg_quarantine", true},
                    {"mil-tess-market-b", "Brive cutscene", "When the brive cutscene starts playing", "mg_quarantine", true},
                    {"mil-city-melee-tutorial-igc", "The slums 1st encounter start", "When the unskipable cutscene starts playing", "mg_quarantine", true},
                    {"mil-city-over-the-fence", "The slums 1st encounter end", "After killing the smugglers", "mg_quarantine", true},
                    {"mil-escape-alley", "The slums completion", "After skipping Robert's final cutscene", "mg_quarantine", true},
                    {"out-wasteland-elevator", "The cargo  completion", "After reaching the meeting point, after skipping the cutscene", "mg_quarantine", true},
                {"mg_outskirts", "The Outskirts", null, "mg_chapters", true},
                    {"out-wasteland-broken-bridge", "Outside completion", "After skipping the tunnel gate cutscene", "mg_outskirts", true},
                    {"out-downtown-tilted-building-cafeteria-puzzle-end", "Tilted building cafeteria puzzle", "After entering the new room", "mg_outskirts", true},
                    {"out-downtown-tilted-building-subway", "Subway completion", "After leaving the subway area", "mg_outskirts", true},
                    {"out-downtown-state-house-loading-dock", "Downtown completion", "After skipping the lift gate cutscene", "mg_outskirts", true},
                    {"out-park-alley", "The museum completion", "After skipping the plank cutscene", "mg_outskirts", true},
                    {"bil-intro-fx", "The Capitol building completion", "After skipping the subway exit cutscene", "mg_outskirts", true},
                {"mg_bill", "Bill's Town", null, "mg_chapters", true},
                    {"bil-bar-explore", "The woods completion", "After skipping the safehouse cutscene at the bar", "mg_bill", true},
                    {"bil-church-training", "Safehouse completion", "After skipping the entering church basement cutscene", "mg_bill", true},
                    {"bil-residential-backyards-start", "Graveyard exit", "After exiting the graveyard area", "mg_bill", true},
                    {"bil-residential-house", "House backyard", "After jumping from the plank into the house backyard, pre-highschool encounter", "mg_bill", true},
                    {"bil-highschool-shop", "Graveyard completion", "After skipping the Highschool window cutscene", "mg_bill", true},
                    {"bill-find-truck", "Ladder cutscene", "When the ladder cutscene starts playing", "mg_bill", true},
                    {"bil-escape-outro", "Truck scape", "After getting on the truck, when the cutscene starts", "mg_bill", true},
                    {"hun-underpass-slam-intro", "High school escape completion", "After skipping the last truck cutscene", "mg_bill", true},
                {"mg_pittsburgh", "Pittsburgh", null, "mg_chapters", true},
                    {"hun-underpass-hunter-camp", "Pittsburgh lift gate", "After the 1st encounter, after the lift gate", "mg_pittsburgh", true},
                    {"hun-checkpoint-maze", "Turnstile", "When reaching the turnstile", "mg_pittsburgh", true},
                    {"hun-hotel-lobby-traverse", "Alone and forsaken completion", "Right after jumping into the hotel", "mg_pittsburgh", true},
                    {"hun-hotel-basement-maze", "Swimming segment", "After reaching the swimming segment at the basement", "mg_pittsburgh", true},
                    {"hun-hotel-kitchen-restaurant-fight", "Restaurant kitchen", "Entering the kitchen", "mg_pittsburgh", true},
                    {"hun-ellie-gun", "Ellie saves Joel", "After Ellie shoots the the bad guy and the cutscene starts", "mg_pittsburgh", true},
                    {"hun-financial-plaza-fight", "Hotel Lobby completion", "After exiting the hotel and skipping the financial discrict cutscene", "mg_pittsburgh", true},
                    {"hun-financial-plaza-seek-exit", "Financial district 1st enconter end", "After skipping Ellie's cutscene", "mg_pittsburgh", true},
                    {"hun-financial-chase-approach", "Financial district 2nd encounter end", "After climbing the ladder and jumping over the bus", "mg_pittsburgh", true},
                    {"hun-camp-apartment-start", "Financial district completion", "After meeting Henry and Sam for the first time and skipping the cutscene", "mg_pittsburgh", true},
                    {"hun-camp-alley-post-fight", "Toy store fight end", "After killing the enemies at the back of the Toy store", "mg_pittsburgh", true},
                    {"hun-overlook-camp", "Henry's office", "'Welcome to my office' cutscene", "mg_pittsburgh", true},
                    {"hun-bridge-henry-and-sam-separated", "Separate ways", "When the cutscene where Henry and Sam go, starts playing", "mg_pittsburgh", true},
                    {"sub-riverbank-start", "Escape the city completion", "After skipping the bridge cutscene", "mg_pittsburgh", true},
                {"mg_suburbs", "The Suburbs", null, "mg_chapters", true},
                    {"sub-sewer-alarm", "Alarm door", "When openning the alarm door at the sewers", "mg_suburbs", true},
                    {"sub-joel-trips-door-trap", "Door trap", "When triggering the door trap at the sewers", "mg_suburbs", true},
                    {"sub-sewer-old-camp-sprint-to-sam-crawl", "Reunion", "When all our heroes reunite... again", "mg_suburbs", true},
                    {"sub-exploration-start", "The sewers completion", "After the sewers exit animation finishes", "mg_suburbs", true},
                    {"sub-sniper-chase-start", "Sniper death", "After killing that annoying sniper", "mg_suburbs", true},
                    {"tom-path-intro-igc", "Suburbs completion", "After skipping the final cutscene, after the snipper sequence", "mg_suburbs", true},
                {"mg_dam", "Tommy's Dam", null, "mg_chapters", true},
                    {"tom-reunited-with-tommy", "Gate cutscene", "When the cutscene starts", "mg_dam", true},
                    {"tom-what-to-do-with-ellie", "Tommy's dialog skip", "After the the skip, when Joel enters the room and the cutscene starts playing", "mg_dam", true},
                    {"tom-road-find-ellie-follow-road", "Hydroelectric dam completion", "After skipping Maria's cutscene, after the pump room fight", "mg_dam", true},
                    {"tom-road-find-ellie-post-ambush", "Ambush fight end", "After killing those annoying MFs", "mg_dam", true},
                    {"tom-ranch-find-ellie-ranch-vista", "Ranch road skip", "On the way to the ranch, when you RC to skip part of the road", "mg_dam", true},
                    {"uni-1-depo-start", "Ranch house completion", "After leaving the ranch house and skipping the cutscene", "mg_dam", true},
                {"mg_university", "The University", null, "mg_chapters", true},
                    {"uni-1-library-generator", "Library encounter", "After killing the Z's ant the library", "mg_university", true},
                    {"uni-2-dorms-nest-end", "Dorms stealth section end", "After the door scripted animation", "mg_university", true},
                    {"uni-4-lab-start", "Go big horns completion", "After entering the lab", "mg_university", true},
                    {"uni-ambush", "Ambush cutscene at the lab", "After forcing the door, when the cutscene starts", "mg_university", true},
                    {"lak-forest-deer-hunt-start-igc", "Science building completion", "After skipping the two cutscenes following the science building exit", "mg_university", true},
                {"mg_lakeside", "Lakeside Resort", null, "mg_chapters", true},
                    {"lak-mining-camp", "Deer cutscene", "When the dead deer cutscene starts playing", "mg_lakeside", true},
                    {"lak-mine-flee-down-hall", "Coal mine 1st encounter end", "After David breaks the door, while walking throug the hall way", "mg_lakeside", true},
                    {"lak-mine-close-door-igc", "Coal mine ladder", "After climbing the ladder", "mg_lakeside", true},
                    {"lak-ellie-leaves-hideout-on-horse-igc", "The hunt completion", "After skipping David's cutscene at the coal mines", "mg_lakeside", true},
                    {"lak-resort-beach-fight", "Horse segment end", "Afther the scripted horse death animation", "mg_lakeside", true},
                    {"lak-resort-trail-start", "First stealth section cleared", "After jumping down towards the pipe", "mg_lakeside", true},
                    {"lak-kitchen-awake", "Cannibal kitchet cutscene", "When the cutscene starts playing", "mg_lakeside", true},
                    {"lak-town-ellie-lands-in-alleyway-igc", "Ellie's stealth section start", "More like a running section actually...", "mg_lakeside", true},
                    {"lak-town-approach-joel", "Joel's running section start", "When Joels arrive to Silver Lake", "mg_lakeside", true},
                    {"lak-town-approach-joel-exits-meatshop-igc", "Joel reaches the steakhouse", "After the scripted animation starts, when Joel opens the door", "mg_lakeside", true},
                    {"wild-1-intro", "Cabin resort completion", "After skipping the final cutscene at the steakhouse", "mg_lakeside", true},
                {"mg_bus", "Bus Depot", null, "mg_chapters", true},
                    {"wild-2-tunnel-entrance", "Highway exit completion", "After crossing the bus", "mg_bus", true},
                    {"wild-3-underground-combat-start", "Stealth section start", "Again, more like a running section...", "mg_bus", true},
                    {"wild-3-flooded-tunnel", "Stealth section cleared", "After jumping down from the trailer", "mg_bus", true},
                    {"lab-start-1", "Underground tunnel completion", "After skipping Ellie's drawning cutscene", "mg_bus", true},
                {"mg_lab", "The Firefly Lab", null, "mg_chapters", true},
                    {"lab-stairwell-1", "The hospital 1st section cleared", "After the scripted door animation at the end of the lower floor", "mg_lab", true},
                    {"lab-opperating-room-start-1", "The hospital 2nd section cleared", "After the scripted door animation at the end of the upper floor", "mg_lab", true},
                    {"lab-3-post-jump-out-of-jeep", "The hospital completion", "After skipping the post-elevator cutscene", "mg_lab", true},
                {"mg_jackson", "Jackson", null, "mg_chapters", true},
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
    // Identifying game version:
    var module = modules.First(); // tlou-i.exe
    var hash = vars.Funcs.hashModule(module);
    print("\nGAME HASH: " + hash + "\n");

    // Default version: Patch 1.1.5.0 Steam
    version = "v1.1.5.0-Steam";
     // TODO: add the Epic games version hash:
    if(hash == "0"){
        version = "v1.1.5.0-EpicGames";
    }else if(hash == "EDB41BE482CEC8F9C6B5EE2528DC04B80EA964D5085953D0A5B0931637CAEF10"){
        version = "v1.1.4.0-Steam";
    }else if(hash == "088D37AFF3B8E3F65715E7E325547C07E6C4D794966C0573CD0F7AF5C6C3503A"){
        // Don't do anything, the default variables are the Steam ones...
    }
    else{
        // If no version was identified, show a warning message:
        MessageBox.Show(
            "The Autosplitter could not identify the game version, the default version was set to " + version + ".\nIf this is not the version of your game, the Autosplitter might not work properly.",
            "TLOU Autosplitter",
            MessageBoxButtons.OK,
            MessageBoxIcon.Warning
        );
    }
}

update{
    // Debugging:
    // print(current.task);
    // print(current.isMainMenu.ToString());
    // print(current.p1 + ":" + current.p2 + ":" + current.p3 + ":" + current.p4);
    // if(current.task != old.task){
    //     vars.fullTaskList.Add(current.task);
    //     var output = "";
    //     foreach (var task in vars.fullTaskList){
    //         output += task + " \n";
    //     }
    //     print(output);
    // }
}

isLoading{
    // No need, the timer follows the in game Timer for GameTime, and for RTA it doesn't matter at all.
}

start{
    return settings.ContainsKey(current.task + "-start") && settings[current.task + "-start"] && (current.p1 + current.p2 + current.p3 + current.p4 == 0);
}

// Pegs the LiveSplit GameTime timer to the game's IGT.
// Timer is trated as a stack of 4 slots in memory (p1, p2, p3 and p4)
// in which the left most value is the highest time.
// Example times:
//      p1  p2  p3  p4
//      ---------------
//      01  00  00  00  | 1 (100 milliseconds)
//      01  02  00  00  | 01.2 (One second and 200 milliseconds)
//      01  02  03  00  | 01:02.3 (One minute, two seconds and 300 milliseconds)
//      01  02  03  04  | 01:02:03.4 (One hour, two minute, three seconds and 400 milliseconds)
gameTime{
    // The game "knows" what the depth of the stack is, we don't.
    // 01  00  00  00 could be eiter 100 milliseconds or 1:00:00.00 (one hour).
    // However, since the first value in changing is the miliseconds position, we can determine the correct time with it:
    if (current.p4 != old.p4) vars.oldTime = new TimeSpan(0, current.p1, current.p2, current.p3, current.p4 * 100); // Above 1 hour
    else if (current.p3 != old.p3) vars.oldTime = new TimeSpan(0, 0, current.p1, current.p2, current.p3 * 100); // Under 1 hour
    else if (current.p2 != old.p2) vars.oldTime = new TimeSpan(0, 0, 0, current.p1, current.p2 * 100); // Under 1 minute
    // Who would split within the first second anyways (¬_¬)
    else if (current.p1 != old.p1) vars.oldTime = new TimeSpan(0, 0, 0, 0, current.p1 * 100); // Under 1 second

    return vars.oldTime;
}

split {
    if(
        current.task != old.task && // On task change,
        settings.ContainsKey(current.task) && // if the current segment is part of the split list,
        settings[current.task] && // and if the current segment was selected from the user in the settings,
        !vars.splitted.Contains(current.task) // and the current segment hasn't been split before, then:
    ){
        vars.splitted.Add(current.task); // Add the segment to the list of split segments
        return true;
    }
}

onReset{
    // Resets timer history tracker:
    vars.oldTime = new TimeSpan(0, 0, 0, 0, 0);
    // Resets the list of split segments:
    vars.splitted = new HashSet<string>();
    // Debuging:
    // vars.fullTaskList = new List<string>();
}
