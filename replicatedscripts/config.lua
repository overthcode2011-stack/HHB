getgenv().__HH_Config = {
    ICONS = {
        Home = "131878842124084",
        Aim  = "119272570124806",
        Vis  = "13321848320",
        Plr  = "16485180075",
        Mov  = "112623004490927",
        Misc = "109962716823639",
        Avt  = "116651535114885",
        Farm = "74133076168703",
    },
    EMOTES = {
        { name = "Take the L",       id = "74430100028293" },
        { name = "Fly",              id = "77529400769588" },
        { name = "Zombie Walk",      id = "81931167118728" },
        { name = "Jamal Brasil",     id = "83796130837213" },
        { name = "Headless Korblox", id = "84323682148776" },
        { name = "Insane Bug",       id = "86036950557685" },
        { name = "Kick",             id = "92249489340640" },
        { name = "Mini Box",         id = "113994067684875" },
        { name = "Gamgam Style",     id = "129764254213842" },
    },
    MUSIC_TRACKS = {
        { name = "Companion",         id = "98012717802240" },
        { name = "Her Boyfriend",     id = "105828916140935" },
        { name = "I Stalk Ur Socials", id = "96622114113241" },
        { name = "EYUHH!",            id = "16190782181" },
        { name = "Low Cortisol",      id = "110919391228823" },
    },
    CUSTOM_ANIMS = {
        idle  = { id = "rbxassetid://130192584268621", priority = Enum.AnimationPriority.Action  },
        walk  = { id = "rbxassetid://81802706102899",  priority = Enum.AnimationPriority.Action2 },
        run   = { id = "rbxassetid://79725699626716",  priority = Enum.AnimationPriority.Action3 },
        fall  = { id = "rbxassetid://10921159222",     priority = Enum.AnimationPriority.Action3 },
        climb = { id = "rbxassetid://132811676666245", priority = Enum.AnimationPriority.Action4 },
        jump  = { id = "rbxassetid://10921160088",     priority = Enum.AnimationPriority.Action4 },
    },
    MINI_BOX_ANIM_ID = "rbxassetid://89158965064756",
    BEAM = { CLEAR = Color3.fromRGB(0, 255, 100), WALL = Color3.fromRGB(255, 50, 50), INNO = Color3.fromRGB(255, 130, 0) },
    AntiVoidSettings = { Threshold = -30, SafeY = 10 },
    
    AimbotSettings = { MM2LockOn = false, MM2Smooth = 8, MM2Range = 500, MM2Target = "Head", TriggerBot = false, TriggerRange = 150, AutoFire = false, WallCheck = true, FOVCircle = false, FOVRadius = 120, AutoKillMurderer = false },
    VisualSettings = { MM2ESP = false, OGESP = false, NameTags = false, GunESP = false, Beam = false },
    MiscSettings = { InfJump = false, AntiAFK = false, AutoTpGun = false, SilentAim = false, MusicCompanion = false, AntiVoid = false, KnifeDodge = true, SelectedMusic = "Companion" },
    MovementSettings = { Noclip = false, God = false, Fly = false, WalkSpeed = 16, JumpPower = 50, FlySpeed = 25, AntiFling = false, Fling = false, TPAll = false, FlingTarget = false, FlingDuration = 3, FlingDistance = 500 },
    AvatarSettings = { Korblox = false, AnimPack = false },
    FarmSettings = { AutoFarm = false, CoinCooldown = 1.5, UltraOpt = true, FarmSpeed = 18, NearBoost = 1.2 },
    
    C = {
        WALL_GRACE_TIME = 0.2, VIS_TTL = 0.05, MURDERER_TTL = 0.4, FARM_GOAL = 50, FARM_TOUCH_RADIUS = 22,
        FARM_ARRIVE_DIST = 5, FARM_DANGER_DIST = 20, FARM_GROUND_OFFSET = -1.2, FARM_TOUCH_COOLDOWN = 0.3,
        FARM_FALLBACK_TIMEOUT = 20, FARM_FALLBACK_COOLDOWN = 8, FARM_STUCK_TIME = 3.2, FARM_STUCK_DIST = 2.2,
        FARM_NEAR_RADIUS = 14, FARM_COLLECT_SPEED_RESET_TIME = 0.45, FARM_FLY_SPEED = 18, FARM_NEAR_BOOST = 1.2,
        FARM_BLACKLIST_TIME = 5, FARM_TARGET_TIMEOUT = 9, FARM_UNSTICK_MAX = 1, AUTO_KILL_COOLDOWN = 2,
        ANTI_FOCUS_RADIUS = 45, ANTI_FOCUS_DURATION = 5, KNIFE_DODGE_MIN_DIST = 12, KNIFE_DODGE_OFFSET = 20,
        KNIFE_DODGE_COOLDOWN = 0.4, YARHM_SHOOT_OFFSET = 2.8
    }
}
