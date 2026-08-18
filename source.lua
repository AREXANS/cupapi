-- Pandu Hub - Survive The Killer
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local CurrentCamera = workspace.CurrentCamera
local Heartbeat = RunService.Heartbeat
local RenderStepped = RunService.RenderStepped
local InputBegan = UserInputService.InputBegan
local InputEnded = UserInputService.InputEnded

-- Variables
local Character = LocalPlayer.Character
local Team = LocalPlayer.Team
local TeamName = Team and Team.Name or "Unknown"
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- Connection Storage
local Connections = {}
local LoopConnections = {}
local ESPObjects = {}

-- Config
local Config = {
    -- Main Features
    InvisibleFE = false,
    SpeedBoost = false,
    SpeedAmount = 0.02,
    NoClip = false,
    AntiAFK = true,
    Noclip = false,
    FullBright = false,
    NoFog = false,
    NoShadow = false,
    GodMode = false,
    AutoWiggle = false,
    AutoAttack = false,
    AutoKillAll = false,
    AutoHeal = false,
    AutoParry = false,
    ParryAggressive = false,
    ParryCircle = true,
    ParryRadius = 15,
    ParryFace = 7,
    SilentAim = false,
    SilentAimVeil = false,
    VeilShowFOV = true,
    VeilFOV = 150,
    ESP_Master = false,
    ESP_Player = false,
    ESP_Killer = false,
    ESP_Name = false,
    ESP_Distance = false,
    ESP_SCP = false,
    ESP_ItemIcon = false,
    ESP_KillerWarn = false,
    ESP_Generator = false,
    ESP_Pallet = false,
    ESP_Window = false,
    ESP_Hook = false,
    ESP_Gate = false,
    NoSlowdown = false,
    NoSlowdownSurvivor = false,
    BypassGate = false,
    ForceJump = false,
    InfiniteJump = false,
    FleeKiller = false,
    FleeDistance = 40,
    AutoSkillCheck = false,
    BypassGen = false,
    AutoAFKEscape = false,
    SurvivorMode = false,
    NextKillerToggle = false,
    SpectatorToggle = false,
    Crosshair = false,
    CrosshairStyle = "Dot",
    CrosshairSize = 3,
    CrosshairThickness = 4,
    CrosshairGap = 6,
    CrosshairPosX = 0,
    CrosshairPosY = 0,
    CameraFOV = false,
    FOVValue = 90,
    InfinityZoom = false,
    EmoteEnabled = false,
    SelectedEmote = "Friday Night",
    Misc_FakeName = false,
    SpeedInputMode = false,
    SpeedInputValue = 0.1,
    Surv_Perks = false,
    Surv_VaultSlider = 13,
    Surv_AutoCrouch = false,
    SilentAimPredict = false,
    PistolFOVMode = false,
    PistolShowFOV = false,
    PistolFOV = 150,
    AimTargetPart = "Torso",
    Surv_Aimbot_Enabled = false,
    Surv_Aimbot_ShowFOV = true,
    Surv_Aimbot_Radius = 150,
    Surv_Aimbot_MaxDist = 300,
    Surv_Aimbot_Smoothness = 5,
    Killer_Aimbot_Enabled = false,
    Killer_Aimbot_MaxDist = 12,
    Killer_Aimbot_Smoothness = 5,
    Killer_InfAbyssal = false,
    KillerThirdPerson = false,
    InfiniteLunge = false,
    ParrySafety = false,
    Surv_ParrySafety = false,
    Pistol_BlockKnocked = false,
    FlashAim = false,
    FlashAimOffset = 8,
    LockAim = false,
    HideSilentLaser = false,
    VeilTracker = false,
    Veil_SpearSpeed = 165,
    Veil_SpearGravity = 103,
    AutoSkillCheckMode = "Instant",
    SkillFrequency = 10,
    SkillSpeed = 10,
    TimeOfDay = 14,
    IgnoreSkills = {},
    AutoCarryEnabled = false,
    FleeCooldown = 0,
    seatTeleportPosition = Vector3.new(-25.95, 400, 3537.55),
    CrosshairColor = Color3.fromRGB(255, 255, 0),
    Color_Player = Color3.fromRGB(57, 255, 20),
    Color_Killer = Color3.fromRGB(255, 40, 40),
    Color_SCP = Color3.fromRGB(255, 0, 255),
    Color_Generator = Color3.fromRGB(255, 255, 0),
    Color_Pallet = Color3.fromRGB(255, 128, 0),
    Color_Window = Color3.fromRGB(0, 200, 255),
    Color_Hook = Color3.fromRGB(255, 105, 180),
    Color_Gate = Color3.fromRGB(0, 255, 255),
    WebhookEnabled = false,
    WebhookURL = "",
}

-- Utility Functions
local function GetCharacter()
    Character = LocalPlayer.Character
    return Character
end

local function GetHumanoid()
    local char = GetCharacter()
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function GetHumanoidRootPart()
    local char = GetCharacter()
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function IsKiller()
    local team = LocalPlayer.Team
    return team and team.Name == "Killer"
end

local function IsSurvivor()
    local team = LocalPlayer.Team
    return team and team.Name == "Survivors"
end

local function IsSpectator()
    local team = LocalPlayer.Team
    return team and team.Name == "Spectator"
end

local function GetClosestPlayer(ignoreTeam)
    local closest = nil
    local closestDist = math.huge
    local root = GetHumanoidRootPart()
    if not root then return nil end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            if ignoreTeam and player.Team and player.Team.Name == ignoreTeam then
                -- skip
            else
                local char = player.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    local dist = (char.HumanoidRootPart.Position - root.Position).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closest = player
                    end
                end
            end
        end
    end
    return closest
end

-- Load UI Library (Kavo) + compatibility adapter
-- UI library baru: Kavo UI Library. Semua pemanggilan fitur lama dipetakan
-- ke API Kavo sehingga logic fitur di bawah tidak perlu dihapus.
local Kavo = loadstring(game:HttpGet("https://raw.githubusercontent.com/GhostDuckyy/UI-Libraries/refs/heads/main/Kavo/source.lua"))()

local Library = {
    Options = {},
    Toggles = {},
    _controls = {},
    _window = nil,
    _tabs = {}
}

local function normalizeValues(values)
    if type(values) ~= "table" then return {} end
    return values
end

local function registerControl(name, control, isToggle)
    local wrapper = {
        Name = name,
        Control = control,
        Value = nil
    }

    function wrapper:SetValue(value)
        self.Value = value
        if self.Control then
            pcall(function()
                if type(self.Control.SetValue) == "function" then
                    self.Control:SetValue(value)
                elseif type(self.Control.Set) == "function" then
                    self.Control:Set(value)
                end
            end)
        end
    end

    function wrapper:GetValue()
        if self.Control then
            if self.Control.Value ~= nil then return self.Control.Value end
            if self.Control.CurrentValue ~= nil then return self.Control.CurrentValue end
        end
        return self.Value
    end

    function wrapper:AddKeyPicker(keyName, cfg)
        cfg = cfg or {}
        local tab = Library._tabs[#Library._tabs]
        if tab and tab.Section then
            pcall(function()
                tab.Section:NewKeybind(cfg.Text or keyName, cfg.Default or Enum.KeyCode.Unknown, function(key)
                    if cfg.Callback then cfg.Callback(key) end
                end)
            end)
        end
        return self
    end

    function wrapper:AddColorPicker(colorName, cfg)
        cfg = cfg or {}
        local tab = Library._tabs[#Library._tabs]
        if tab and tab.Section then
            local c = tab.Section:NewColorPicker(cfg.Title or colorName, cfg.Default or Color3.new(1,1,1), function(value)
                if cfg.Callback then cfg.Callback(value) end
            end)
            if c then registerControl(colorName, c, false) end
        end
        return self
    end

    Library._controls[name] = wrapper
    if isToggle then
        Library.Toggles[name] = wrapper
    else
        Library.Options[name] = wrapper
    end
    return wrapper
end

local GroupMethods = {}

function GroupMethods:AddToggle(name, cfg)
    cfg = cfg or {}
    local control = self.Section:NewToggle(cfg.Text or name, {
        default = cfg.Default == true,
        callback = function(value)
            if cfg.Callback then cfg.Callback(value) end
        end
    })
    return registerControl(name, control, true)
end

function GroupMethods:AddCheckbox(name, cfg)
    return self:AddToggle(name, cfg)
end

function GroupMethods:AddSlider(name, cfg)
    cfg = cfg or {}
    local control = self.Section:NewSlider(cfg.Text or name, {
        min = cfg.Min or 0,
        max = cfg.Max or 100,
        default = cfg.Default or cfg.Min or 0,
        precision = cfg.Rounding or 0,
        suffix = ""
    }, function(value)
        if cfg.Callback then cfg.Callback(value) end
    end)
    return registerControl(name, control, false)
end

function GroupMethods:AddDropdown(name, cfg)
    cfg = cfg or {}
    local control = self.Section:NewDropdown(cfg.Text or name, normalizeValues(cfg.Values), function(value)
        if cfg.Callback then cfg.Callback(value) end
    end)
    local wrapper = registerControl(name, control, false)
    function wrapper:SetValues(values)
        -- Kavo exposes Refresh on dropdown controls in common builds.
        if self.Control then
            pcall(function()
                if type(self.Control.Refresh) == "function" then
                    self.Control:Refresh(normalizeValues(values), cfg.Default)
                elseif type(self.Control.Update) == "function" then
                    self.Control:Update(normalizeValues(values))
                end
            end)
        end
    end
    return wrapper
end

function GroupMethods:AddInput(name, cfg)
    cfg = cfg or {}
    local control = self.Section:NewTextBox(cfg.Text or name, {
        clear = false,
        value = cfg.Default or ""
    }, function(value)
        if cfg.Callback then cfg.Callback(value) end
    end)
    return registerControl(name, control, false)
end

function GroupMethods:AddButton(cfg)
    cfg = cfg or {}
    return self.Section:NewButton(cfg.Text or "Button", cfg.Callback or function() end)
end

function GroupMethods:AddKeyPicker(name, cfg)
    cfg = cfg or {}
    pcall(function()
        self.Section:NewKeybind(cfg.Text or name, cfg.Default or Enum.KeyCode.Unknown, function(key)
            if cfg.Callback then cfg.Callback(key) end
        end)
    end)
    return self
end

function GroupMethods:AddColorPicker(name, cfg)
    cfg = cfg or {}
    local control = self.Section:NewColorPicker(cfg.Title or name, cfg.Default or Color3.new(1,1,1), function(value)
        if cfg.Callback then cfg.Callback(value) end
    end)
    if control then registerControl(name, control, false) end
    return self
end

function GroupMethods:AddSection(title)
    pcall(function() self.Section:NewLabel(title) end)
    return self
end

local function newGroup(tab, title, icon)
    return setmetatable({
        Section = tab:NewSection(title),
        Title = title,
        Icon = icon
    }, {__index = GroupMethods})
end

function Library:CreateWindow(cfg)
    cfg = cfg or {}
    local window = Kavo.CreateLib(cfg.Title or "Pandu Hub", "Ocean")
    self._window = window
    return setmetatable({}, {
        __index = {
            AddTab = function(_, title, icon)
                local tab = window:NewTab(title)
                local tabWrapper = setmetatable({KavoTab = tab}, {
                    __index = {
                        AddLeftGroupbox = function(obj, groupTitle, groupIcon)
                            return newGroup(obj.KavoTab, groupTitle, groupIcon)
                        end,
                        AddRightGroupbox = function(obj, groupTitle, groupIcon)
                            return newGroup(obj.KavoTab, groupTitle, groupIcon)
                        end
                    }
                })
                table.insert(self._tabs, tabWrapper)
                return tabWrapper
            end
        }
    })
end

function Library:Notify(data, duration)
    if type(data) == "string" then
        pcall(function() Kavo:Notify(data, duration or 2) end)
        return
    end
    data = data or {}
    pcall(function()
        Kavo:Notify((data.Title or "Pandu Hub") .. "\n" .. (data.Description or data.Content or ""), data.Time or data.Duration or 3)
    end)
end

-- Compatibility managers: preserve existing Save/Theme calls.
local ThemeManager = {}
local SaveManager = {}
local CONFIG_FOLDER = "PanduHub/SurviveTheKiller"
local CONFIG_FILE = CONFIG_FOLDER .. "/config.json"
local AUTO_FILE = CONFIG_FOLDER .. "/autoload.txt"

function ThemeManager:SetLibrary(lib) self.Library = lib end
function ThemeManager:SetFolder(folder) self.Folder = folder end
function ThemeManager:ApplyToTab(tab)
    local group = tab:AddLeftGroupbox("Theme", "palette")
    group:AddDropdown("UITheme", {
        Text = "Theme",
        Values = {"Ocean", "Dark", "Light", "Blood", "Synapse"},
        Default = "Ocean",
        Callback = function(value)
            -- Kavo themes are selected when the library is created. Keep the
            -- setting available and rebuild only when supported by the build.
            pcall(function()
                if Kavo.ChangeColor then Kavo:ChangeColor("Theme", value) end
            end)
        end
    })
end

function SaveManager:SetLibrary(lib) self.Library = lib end
function SaveManager:IgnoreThemeSettings() end
function SaveManager:SetIgnoreIndexes() end
function SaveManager:SetFolder(folder)
    CONFIG_FOLDER = folder
    CONFIG_FILE = folder .. "/config.json"
    AUTO_FILE = folder .. "/autoload.txt"
end

local function applySavedValue(name, value)
    local control = Library._controls[name]
    if control then
        if type(value) == "table" and value.__color then
            value = Color3.new(value.r, value.g, value.b)
        end
        control:SetValue(value)
    end
end

function SaveManager:BuildConfigSection(tab)
    local group = tab:AddLeftGroupbox("Config", "save")
    group:AddButton({Text = "Save Config", Callback = function()
        if writefile then
            local data = {}
            for name, control in pairs(Library._controls) do
                local value = control:GetValue()
                if typeof(value) == "Color3" then
                    data[name] = {__color=true, r=value.R, g=value.G, b=value.B}
                elseif type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
                    data[name] = value
                end
            end
            pcall(function()
                if makefolder then
                    pcall(function() makefolder("PanduHub") end)
                    pcall(function() makefolder(CONFIG_FOLDER) end)
                end
                writefile(CONFIG_FILE, HttpService:JSONEncode(data))
                writefile(AUTO_FILE, "1")
            end)
            Library:Notify({Title="Config", Description="Config berhasil disimpan!", Time=3})
        else
            Library:Notify({Title="Config", Description="Executor tidak menyediakan writefile.", Time=3})
        end
    end})
    group:AddButton({Text = "Load Config", Callback = function()
        if isfile and isfile(CONFIG_FILE) and readfile then
            local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
            if ok and type(data) == "table" then
                for name, value in pairs(data) do applySavedValue(name, value) end
                Library:Notify({Title="Config", Description="Config berhasil dimuat!", Time=3})
            end
        end
    end})
end

function SaveManager:LoadAutoloadConfig()
    if isfile and isfile(AUTO_FILE) and readfile and readfile(AUTO_FILE) == "1" and isfile(CONFIG_FILE) then
        task.defer(function()
            task.wait(0.25)
            local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
            if ok and type(data) == "table" then
                for name, value in pairs(data) do applySavedValue(name, value) end
            end
        end)
    end
end

local Options = Library.Options

-- Create Window
local Window = Library:CreateWindow({
    AutoShow = true,
    SidebarCompacted = true,
    NotifySide = "Right",
    EnableCompacting = true,
    EnableSidebarResize = true,
    Title = "Pandu Hub",
    Footer = "Violence District v1.3.6 | By Pandu Hub",
    IconSize = UDim2.fromOffset(50, 50),
    CornerRadius = 20,
    Icon = "109651670989001",
    Size = UDim2.fromOffset(450, 1000)
})

-- Tabs
local TabMain = Window:AddTab("Pandu", "home")
local TabSurvivor = Window:AddTab("Survivor", "users")
local TabKiller = Window:AddTab("Killer", "swords")
local TabESP = Window:AddTab("ESP", "eye")
local TabTeleport = Window:AddTab("Teleport", "map-pin")
local TabSettings = Window:AddTab("UI Settings", "settings")

-- ============================================
-- TAB MAIN
-- ============================================

local GroupExploits = TabMain:AddLeftGroupbox("Exploits", "shield-alert")

-- Invisible FE
GroupExploits:AddToggle("InvisibleFE", {
    Text = "Invisible FE",
    Default = false,
    Tooltip = "Membuat karakter menjadi tidak terlihat",
    Callback = function(value)
        Config.InvisibleFE = value
        if value then
            local char = GetCharacter()
            if char then
                for _, part in pairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                        part.Transparency = 0.9
                    end
                end
            end
            Library:Notify({
                Time = 3,
                Title = "Invisible FE",
                Description = "Mode Invisible AKTIF"
            })
        end
    end
}):AddKeyPicker("InvisibleFEKey", {
    Text = "Invisible FE Key",
    Default = "None",
    Mode = "Toggle",
    Callback = function(value)
        Library.Toggles.InvisibleFE:SetValue(value)
    end
})

-- Speed Boost
GroupExploits:AddToggle("SpeedBoost", {
    Text = "Enable Speed Boost",
    Default = false,
    Callback = function(value)
        Config.SpeedBoost = value
    end
})

GroupExploits:AddSlider("SpeedAmount", {
    Min = 0.01,
    Default = 0.02,
    Max = 3,
    Text = "Speed Boost Value",
    Rounding = 2,
    Callback = function(value)
        Config.SpeedAmount = value
    end
})

-- No Clip
GroupExploits:AddToggle("Noclip", {
    Text = "No Clip",
    Default = false,
    Tooltip = "Tembus semua objek",
    Callback = function(value)
        Config.Noclip = value
        if value then
            Library:Notify({
                Time = 3,
                Title = "No Clip",
                Description = "No Clip Enabled"
            })
        end
    end
})

-- Force Jump
GroupExploits:AddButton({
    Text = "Force Jump",
    Callback = function()
        local humanoid = GetHumanoid()
        if humanoid then
            humanoid.JumpPower = 50
            humanoid:Jump()
        end
    end
})

-- Infinite Jump
GroupExploits:AddToggle("InfiniteJump", {
    Text = "Infinite Jump",
    Default = false,
    Tooltip = "Lompat tanpa batas",
    Callback = function(value)
        Config.InfiniteJump = value
        if value then
            UserInputService.JumpRequest:Connect(function()
                pcall(function()
                    local char = GetCharacter()
                    if char then
                        local humanoid = char:FindFirstChildOfClass("Humanoid")
                        if humanoid then
                            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                        end
                    end
                end)
            end)
        end
    end
})

-- Anti AFK
GroupExploits:AddToggle("AntiAFK", {
    Text = "Anti AFK",
    Default = true,
    Tooltip = "Biar nggak kena kick pas AFK",
    Callback = function(value)
        Config.AntiAFK = value
        if value then
            task.spawn(function()
                while Config.AntiAFK do
                    pcall(function()
                        VirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                        task.wait(1)
                        VirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
                    end)
                    task.wait(60)
                end
            end)
        end
    end
})

-- Speed Input Mode
GroupExploits:AddInput("SpeedInputValue", {
    Placeholder = "0.1",
    Default = "0.1",
    Numeric = true,
    Text = "Speed Value (Input Mode)",
    Callback = function(value)
        local num = tonumber(value)
        if num then
            Config.SpeedInputValue = num
            Library:Notify({
                Time = 2,
                Title = "Speed",
                Description = "Kecepatan diubah ke " .. num
            })
        end
    end
})

GroupExploits:AddToggle("SpeedInputMode", {
    Text = "Enable Speed Boost (Input Mode)",
    Default = false,
    Callback = function(value)
        Config.SpeedInputMode = value
        if value then
            Library:Notify({
                Time = 3,
                Title = "Speed Input",
                Description = "Speed Boost aktif! (" .. Config.SpeedInputValue .. ")"
            })
        end
    end
})

-- Fast Vault
GroupExploits:AddToggle("Surv_Perks", {
    Text = "Fast vault",
    Default = false,
    Callback = function(value)
        Config.Surv_Perks = value
    end
}):AddKeyPicker("Surv_PerksKey", {
    Text = "Toggle Vault Speed",
    Default = "None",
    Mode = "Toggle"
})

GroupExploits:AddSlider("Surv_VaultSlider", {
    Min = 10,
    Default = 13,
    Max = 20,
    Text = "Vault Speed",
    Rounding = 1,
    Callback = function(value)
        Config.Surv_VaultSlider = value
    end
})

-- ============================================
-- EMOTE
-- ============================================

local GroupEmote = TabMain:AddLeftGroupbox("Player Emote", "smile")

GroupEmote:AddToggle("EmoteEnabled", {
    Text = "Aktifkan Emote",
    Default = false,
    Callback = function(value)
        Config.EmoteEnabled = value
        if value then
            local char = GetCharacter()
            if char then
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                local root = char:FindFirstChild("HumanoidRootPart")
                if humanoid and root then
                    local animId = "rbxassetid://83229063951016" -- Friday Night default
                    local soundId = "rbxassetid://85355610204255"
                    
                    local anim = Instance.new("Animation")
                    anim.AnimationId = animId
                    local track = humanoid:LoadAnimation(anim)
                    track.Looped = true
                    track:Play()
                    
                    local sound = Instance.new("Sound")
                    sound.SoundId = soundId
                    sound.Looped = true
                    sound.Volume = 2
                    sound.Parent = root
                    sound:Play()
                end
            end
        end
    end
})

GroupEmote:AddDropdown("EmoteSelect", {
    Text = "Pilih Emote",
    Values = {
        "Friday Night", "WarCry", "24 Hour Cinderella", "Applause",
        "Arm Swing", "Backflip", "California Girls", "Christmas Spirit",
        "Floating Rest", "Ghoul", "Griddy", "Kyoufuu", "OnePlays", "Vulnerable"
    },
    Default = "Friday Night",
    Callback = function(value)
        Config.SelectedEmote = value
    end
})

-- ============================================
-- FUN
-- ============================================

local GroupFun = TabMain:AddLeftGroupbox("Fun", "sparkles")

GroupFun:AddInput("SpoofLevel", {
    Placeholder = "Masukkan Level...",
    Default = "0",
    Numeric = true,
    Text = "Set Level",
    Callback = function(value)
        local num = tonumber(value) or 0
        LocalPlayer:SetAttribute("Level", num)
    end
})

GroupFun:AddInput("SpoofGears", {
    Placeholder = "Masukkan Gears...",
    Default = "0",
    Numeric = true,
    Text = "Set Gears",
    Callback = function(value)
        local num = tonumber(value) or 0
        LocalPlayer:SetAttribute("Gears", num)
    end
})

GroupFun:AddInput("SpoofScrews", {
    Placeholder = "Masukkan Screws...",
    Default = "0",
    Numeric = true,
    Text = "Set Screws",
    Callback = function(value)
        local num = tonumber(value) or 0
        LocalPlayer:SetAttribute("Screws", num)
    end
})

GroupFun:AddButton({
    Text = "Apply Spoof Data",
    Callback = function()
        Library:Notify({
            Time = 2,
            Title = "Spoof",
            Description = "Data diterapkan!"
        })
    end
})

-- ============================================
-- STREAMER MODE
-- ============================================

local GroupStreamer = TabMain:AddRightGroupbox("Streamer Mode", "eye")

GroupStreamer:AddToggle("Misc_FakeName", {
    Text = "Hide Name",
    Default = false,
    Callback = function(value)
        Config.Misc_FakeName = value
        if value then
            local gui = LocalPlayer:FindFirstChild("PlayerGui")
            if gui then
                for _, descendant in pairs(gui:GetDescendants()) do
                    if descendant:IsA("TextLabel") then
                        local text = descendant.Text
                        for _, player in pairs(Players:GetPlayers()) do
                            text = string.gsub(text, player.Name, "PANDU HUB")
                            text = string.gsub(text, player.DisplayName, "PANDU HUB")
                        end
                        descendant.Text = text
                    end
                end
            end
        end
    end
}):AddKeyPicker("FakeNameKey", {
    Text = "Hide Name Key",
    Default = "None",
    Mode = "Toggle"
})

-- ============================================
-- UNIVERSAL
-- ============================================

local GroupUniversal = TabMain:AddRightGroupbox("Universal", "global")

GroupUniversal:AddButton({
    Text = "Fake Generator GUI",
    Callback = function()
        pcall(function()
            loadstring(game:HttpGet("https://pastefy.app/cjJ9sNKl/raw"))()
            Library:Notify({
                Time = 3,
                Title = "Fake Generator",
                Description = "GUI Fake Generator berhasil dimuat!"
            })
        end)
    end
})

GroupUniversal:AddButton({
    Text = "Open Global Chat GUI",
    Callback = function()
        pcall(function()
            loadstring(game:HttpGet("https://pastefy.app/nmSSS371/raw"))()
            Library:Notify({
                Time = 3,
                Title = "Global Chat",
                Description = "GUI Global Chat berhasil dimuat!"
            })
        end)
    end
})

GroupUniversal:AddButton({
    Text = "Open Moonwalk GUI",
    Callback = function()
        pcall(function()
            loadstring(game:HttpGet("https://pastebin.com/raw/JWr0bW8u"))()
            Library:Notify({
                Time = 3,
                Title = "Moonwalk",
                Description = "GUI Moonwalk berhasil dimuat!"
            })
        end)
    end
})

GroupUniversal:AddButton({
    Text = "Fly GUI",
    Callback = function()
        Library:Notify({
            Time = 3,
            Title = "Fly",
            Description = "Fly GUI terbuka"
        })
    end
})

GroupUniversal:AddButton({
    Text = "Rejoin Server",
    Callback = function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end
})

-- ============================================
-- COPY AVATAR
-- ============================================

local GroupCopyAvatar = TabMain:AddRightGroupbox("Copy Avatar", "user-plus")

GroupCopyAvatar:AddButton({
    Text = "BUKA COPY AVATAR",
    Callback = function()
        pcall(function()
            loadstring(game:HttpGet("https://pastefy.app/BcXlgyHh/raw"))()
            Library:Notify({
                Time = 3,
                Title = "Copy Avatar",
                Description = "GUI Copy Avatar dibuka!"
            })
        end)
    end
})

-- ============================================
-- CROSSHAIR
-- ============================================

local GroupCrosshair = TabMain:AddRightGroupbox("Crosshair", "crosshair")

GroupCrosshair:AddToggle("Crosshair", {
    Text = "Enable Crosshair",
    Default = false,
    Callback = function(value)
        Config.Crosshair = value
    end
}):AddColorPicker("CrosshairColor", {
    Default = Color3.fromRGB(255, 255, 0),
    Title = "Crosshair Color",
    Transparency = 0,
    Callback = function(value)
        Config.CrosshairColor = value
    end
})

GroupCrosshair:AddDropdown("CrosshairStyle", {
    Values = {"Dot", "Plus", "X", "Box"},
    Text = "Crosshair Style",
    Default = "Dot",
    Multi = false,
    Callback = function(value)
        Config.CrosshairStyle = value
    end
})

GroupCrosshair:AddSlider("CrosshairSize", {
    Min = 1,
    Default = 3,
    Max = 100,
    Text = "Crosshair Size",
    Rounding = 0,
    Callback = function(value)
        Config.CrosshairSize = value
    end
})

GroupCrosshair:AddSlider("CrosshairThickness", {
    Min = 1,
    Default = 4,
    Max = 20,
    Text = "Crosshair Thickness",
    Rounding = 0,
    Callback = function(value)
        Config.CrosshairThickness = value
    end
})

GroupCrosshair:AddSlider("CrosshairGap", {
    Min = 0,
    Default = 6,
    Max = 50,
    Text = "Crosshair Gap",
    Rounding = 0,
    Callback = function(value)
        Config.CrosshairGap = value
    end
})

GroupCrosshair:AddInput("CrosshairPosX", {
    Placeholder = "0",
    Default = "0",
    Text = "Position X",
    Callback = function(value)
        local num = tonumber(value)
        if num then
            Config.CrosshairPosX = num
        end
    end
})

GroupCrosshair:AddInput("CrosshairPosY", {
    Placeholder = "0",
    Default = "0",
    Text = "Position Y",
    Callback = function(value)
        local num = tonumber(value)
        if num then
            Config.CrosshairPosY = num
        end
    end
})

-- ============================================
-- TAB SURVIVOR
-- ============================================

local GroupAbility = TabSurvivor:AddLeftGroupbox("Ability", "swords")

-- Auto Skill Check
GroupAbility:AddToggle("AutoSkillCheck", {
    Text = "Auto Skill Check",
    Default = false,
    Callback = function(value)
        Config.AutoSkillCheck = value
        if value then
            local skillCheckGui = PlayerGui:FindFirstChild("SkillCheckPromptGui")
            if skillCheckGui then
                local check = skillCheckGui:FindFirstChild("Check")
                if check then
                    check:GetPropertyChangedSignal("Visible"):Connect(function()
                        if check.Visible and Config.AutoSkillCheck then
                            local line = check:FindFirstChild("Line")
                            local goal = check:FindFirstChild("Goal")
                            if line and goal then
                                task.spawn(function()
                                    if Config.AutoSkillCheckMode == "Instant" then
                                        -- Instant success
                                        local goalPos = goal.AbsolutePosition.X
                                        local linePos = line.AbsolutePosition.X
                                        -- Simulate click on goal
                                    end
                                end)
                            end
                        end
                    end)
                end
            end
        end
    end
}):AddKeyPicker("AutoSkillCheckKey", {
    Text = "Auto Skill Check Key",
    Default = "None",
    Mode = "Toggle"
})

GroupAbility:AddDropdown("AutoSkillCheckMode", {
    Values = {"Instant", "Legit"},
    Text = "Auto Skill Check Mode",
    Default = "Instant",
    Callback = function(value)
        Config.AutoSkillCheckMode = value
    end
})

-- Bypass Gen
GroupAbility:AddToggle("BypassGen", {
    Text = "Gen Boost (Multi-Repair)",
    Default = false,
    Tooltip = "Memperbaiki generator dengan cepat tanpa terdeteksi",
    Callback = function(value)
        Config.BypassGen = value
        if value then
            pcall(function()
                loadstring(game:HttpGet("https://pastefy.app/fBHlZlrq/raw"))()
                Library:Notify({
                    Time = 3,
                    Title = "Gen Boost",
                    Description = "Loaded from Pastefy!"
                })
            end)
        end
    end
})

-- Auto Crouch
GroupAbility:AddToggle("Surv_AutoCrouch", {
    Text = "Auto Crouch (Dodge S1)",
    Default = false,
    Tooltip = "Otomatis jongkok saat Abyssal menggunakan S1",
    Callback = function(value)
        Config.Surv_AutoCrouch = value
    end
})

-- Skill Frequency
GroupAbility:AddSlider("SkillFrequency", {
    Min = 1,
    Default = 10,
    Max = 50,
    Text = "Skill Check Frequency",
    Rounding = 0,
    Callback = function(value)
        Config.SkillFrequency = value
    end
})

-- Skill Speed
GroupAbility:AddSlider("SkillSpeed", {
    Min = 1,
    Default = 10,
    Max = 30,
    Text = "Skill Check Speed",
    Tooltip = "Atur kecepatan putaran skill check (1-30, 10 = Normal)",
    Rounding = 1,
    Callback = function(value)
        Config.SkillSpeed = value
    end
})

-- Bypass Gate
GroupAbility:AddToggle("BypassGate", {
    Text = "Bypass Exit Gate",
    Default = false,
    Tooltip = "Tembus gate tanpa collision",
    Callback = function(value)
        Config.BypassGate = value
        if value then
            Library:Notify({
                Time = 3,
                Title = "Bypass Exit Gate",
                Description = "Gate bypass aktif!"
            })
        end
    end
})

-- Auto Heal
GroupAbility:AddToggle("AutoHeal", {
    Text = "Self Heal Progress",
    Default = false,
    Tooltip = "Otomatis menyembuhkan diri sendiri",
    Callback = function(value)
        Config.AutoHeal = value
        if value then
            Library:Notify({
                Time = 2,
                Title = "Auto Heal",
                Description = "AKTIF!"
            })
        end
    end
}):AddKeyPicker("AutoHealKey", {
    Text = "Auto Heal Key",
    Default = "None",
    Mode = "Toggle"
})

-- No Slowdown Survivor
GroupAbility:AddToggle("NoSlowdownSurvivor", {
    Text = "No Slowdown Survivor",
    Default = false,
    Tooltip = "Mencegah slowdown saat kena efek (Survivor Only)",
    Callback = function(value)
        Config.NoSlowdownSurvivor = value
        if value then
            Library:Notify({
                Time = 3,
                Title = "No Slowdown",
                Description = "✔ Aktif untuk Survivor!"
            })
        end
    end
}):AddKeyPicker("NoSlowdownSurvivorKey", {
    Text = "No Slowdown Survivor Key",
    Default = "None",
    Mode = "Toggle"
})

-- Anti Knockdown
GroupAbility:AddToggle("GodMode", {
    Text = "Anti Knockdown",
    Default = false,
    Tooltip = "Ga bisa mati (semi god)",
    Callback = function(value)
        Config.GodMode = value
    end
})

-- Auto Wiggle
GroupAbility:AddToggle("AutoWiggle", {
    Text = "Auto Wiggle",
    Default = false,
    Tooltip = "Biar lebih cepet lepas dari carry killer",
    Callback = function(value)
        Config.AutoWiggle = value
    end
})

-- Flee Killer
GroupAbility:AddToggle("FleeKiller", {
    Text = "Flee Killer",
    Default = false,
    Tooltip = "Teleport saat killer terlalu dekat",
    Callback = function(value)
        Config.FleeKiller = value
    end
})

GroupAbility:AddSlider("FleeDistance", {
    Min = 15,
    Default = 40,
    Max = 80,
    Text = "Flee Distance",
    Tooltip = "Jarak trigger teleport",
    Rounding = 0,
    Callback = function(value)
        Config.FleeDistance = value
    end
})

-- Auto Parry
GroupAbility:AddToggle("AutoParry", {
    Text = "Auto Parry",
    Default = false,
    Callback = function(value)
        Config.AutoParry = value
    end
}):AddKeyPicker("AutoParryKey", {
    Text = "Auto Parry Key",
    Default = "None",
    Mode = "Toggle"
})

GroupAbility:AddCheckbox("Surv_ParrySafety", {
    Text = "Safety Parry",
    Default = false,
    Callback = function(value)
        Config.Surv_ParrySafety = value
    end
})

GroupAbility:AddToggle("ParryAggressive", {
    Text = "Aggressive Mode",
    Default = false,
    Tooltip = "Langsung parry tanpa peduli face direction",
    Callback = function(value)
        Config.ParryAggressive = value
    end
})

GroupAbility:AddToggle("ParryCircle", {
    Text = "ESP Range Circle",
    Default = true,
    Tooltip = "Tampilkan radius jarak parry di karakter",
    Callback = function(value)
        Config.ParryCircle = value
    end
})

GroupAbility:AddSlider("ParryRadius", {
    Min = 5,
    Default = 15,
    Max = 25,
    Text = "Parry Radius",
    Tooltip = "Jarak maksimal parry bereaksi",
    Rounding = 0,
    Callback = function(value)
        Config.ParryRadius = value
    end
})

GroupAbility:AddSlider("ParryFace", {
    Min = -10,
    Default = 7,
    Max = 10,
    Text = "Face Sensitivity",
    Tooltip = "Sensitivitas arah pandang (1-10)",
    Rounding = 0,
    Callback = function(value)
        Config.ParryFace = value
    end
})

GroupAbility:AddDropdown("IgnoreSkills", {
    Values = {"Hidden S1", "Abyssal S1"},
    Text = "Abaikan skill tertentu",
    Tooltip = "Abaikan skill tertentu",
    Multi = true,
    Default = {},
    Callback = function(value)
        Config.IgnoreSkills = value
    end
})

-- Fake Parry GUI
GroupAbility:AddButton({
    Text = "Fake Parry GUI",
    Callback = function()
        pcall(function()
            loadstring(game:HttpGet("https://pastefy.app/lmWRD7sw/raw"))()
            Library:Notify({
                Time = 3,
                Title = "Fake Parry",
                Description = "GUI Fake Parry berhasil dimuat!"
            })
        end)
    end
})

-- ============================================
-- AUTOMATIC
-- ============================================

local GroupAutomatic = TabSurvivor:AddRightGroupbox("Automatic", "bot")

GroupAutomatic:AddToggle("AutoAFKEscape", {
    Text = "Afk Auto Farm Survi",
    Default = false,
    Tooltip = "Auto Farm survivor - teleport ke exit dan server hop",
    Callback = function(value)
        Config.AutoAFKEscape = value
        if value and IsSurvivor() then
            task.spawn(function()
                while Config.AutoAFKEscape and IsSurvivor() do
                    local char = GetCharacter()
                    if char then
                        local root = GetHumanoidRootPart()
                        if root then
                            -- Teleport ke exit
                            local exitPos = Vector3.new(0, 0, 0) -- Ganti dengan posisi exit yang benar
                            root.CFrame = CFrame.new(exitPos)
                        end
                    end
                    task.wait(18)
                    -- Server hop setelah 18 detik
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                    task.wait(60)
                end
            end)
        end
    end
})

-- Webhook
GroupAutomatic:AddToggle("WebhookEnabled", {
    Text = "Aktifkan Webhook",
    Default = false,
    Tooltip = "Kirim statistik auto farm ke Discord",
    Callback = function(value)
        Config.WebhookEnabled = value
    end
})

GroupAutomatic:AddInput("WebhookURL", {
    Placeholder = "https://discord.com/api/webhooks/...",
    Default = "",
    Text = "Webhook URL",
    Callback = function(value)
        Config.WebhookURL = value
    end
})

GroupAutomatic:AddButton({
    Text = "Test Webhook",
    Callback = function()
        if Config.WebhookURL and Config.WebhookURL ~= "" then
            task.spawn(function()
                local data = {
                    content = "✅ Webhook test berhasil! Pandu Hub aktif."
                }
                local success = pcall(function()
                    HttpService:PostAsync(Config.WebhookURL, HttpService:JSONEncode(data))
                end)
                if success then
                    Library:Notify({
                        Time = 3,
                        Title = "Sukses",
                        Description = "Pesan test telah dikirim!"
                    })
                end
            end)
        end
    end
})

-- ============================================
-- SILENT AIM (PISTOL)
-- ============================================

local GroupSilentAim = TabSurvivor:AddRightGroupbox("Silent Aim (Pistol)", "crosshair")

GroupSilentAim:AddToggle("SilentAim", {
    Text = "Silent Aim (Pistol)",
    Default = false,
    Callback = function(value)
        Config.SilentAim = value
    end
}):AddKeyPicker("SilentAimKey", {
    Text = "Silent Aim Key",
    Default = "None",
    Mode = "Toggle"
})

GroupSilentAim:AddCheckbox("Pistol_BlockKnocked", {
    Text = "Block aim Knocked",
    Default = false,
    Callback = function(value)
        Config.Pistol_BlockKnocked = value
    end
})

GroupSilentAim:AddToggle("FlashAim", {
    Text = "Silent Aim (flash)",
    Default = false,
    Callback = function(value)
        Config.FlashAim = value
    end
}):AddKeyPicker("SilentFlashKey", {
    Text = "Silent Flash Key",
    Default = "None",
    Mode = "Toggle"
})

GroupSilentAim:AddSlider("FlashAimOffset", {
    Min = 1,
    Default = 8,
    Max = 15,
    Text = "Flash Head Offset (Y)",
    Tooltip = "Atur posisi bidikan (0 = Badan, 1.5 = Kepala, 8 = Atas Kepala)",
    Rounding = 1,
    Callback = function(value)
        Config.FlashAimOffset = value
    end
})

GroupSilentAim:AddToggle("LockAim", {
    Text = "Lock Aim (Pistol)",
    Default = false,
    Tooltip = "Lock aim untuk item Pistol",
    Callback = function(value)
        Config.LockAim = value
    end
})

GroupSilentAim:AddToggle("HideSilentLaser", {
    Text = "Hide Silent Laser",
    Default = false,
    Tooltip = "Sembunyikan laser merah silent aim",
    Callback = function(value)
        Config.HideSilentLaser = value
    end
})

GroupSilentAim:AddButton({
    Text = "Killer (K)",
    Callback = function()
        Library:Notify("Target: Killer", 1)
    end
})

GroupSilentAim:AddButton({
    Text = "Survivor (J)",
    Callback = function()
        Library:Notify("Target: Survivor", 1)
    end
})

GroupSilentAim:AddButton({
    Text = "SCP (L)",
    Callback = function()
        Library:Notify("Target: SCP", 1)
    end
})

GroupSilentAim:AddToggle("PistolFOVMode", {
    Text = "Pistol FOV Mode",
    Default = false,
    Callback = function(value)
        Config.PistolFOVMode = value
    end
})

GroupSilentAim:AddToggle("PistolShowFOV", {
    Text = "Show Pistol FOV",
    Default = false,
    Callback = function(value)
        Config.PistolShowFOV = value
    end
})

GroupSilentAim:AddSlider("PistolFOV", {
    Min = 50,
    Default = 150,
    Max = 500,
    Text = "Pistol FOV Radius",
    Rounding = 0,
    Callback = function(value)
        Config.PistolFOV = value
    end
})

GroupSilentAim:AddDropdown("AimTargetPart", {
    Values = {"Head", "Torso", "Root", "HumanoidRootPart"},
    Text = "Target Part",
    Default = "Torso",
    Callback = function(value)
        Config.AimTargetPart = value
    end
})

-- ============================================
-- AIMBOT SURVIVOR
-- ============================================

local GroupAimbotSurv = TabSurvivor:AddRightGroupbox("Aimbot Survivor", "target")

GroupAimbotSurv:AddToggle("Surv_Aimbot_Enabled", {
    Text = "Enable Aimbot",
    Default = false,
    Callback = function(value)
        Config.Surv_Aimbot_Enabled = value
    end
})

GroupAimbotSurv:AddCheckbox("Surv_Aimbot_ShowFOV", {
    Text = "Show FOV Circle",
    Default = true,
    Callback = function(value)
        Config.Surv_Aimbot_ShowFOV = value
    end
})

GroupAimbotSurv:AddSlider("Surv_Aimbot_Radius", {
    Min = 50,
    Default = 150,
    Max = 500,
    Text = "FOV Circle Radius",
    Rounding = 0,
    Callback = function(value)
        Config.Surv_Aimbot_Radius = value
    end
})

GroupAimbotSurv:AddSlider("Surv_Aimbot_MaxDist", {
    Min = 50,
    Default = 300,
    Max = 1000,
    Text = "Max Distance",
    Rounding = 0,
    Callback = function(value)
        Config.Surv_Aimbot_MaxDist = value
    end
})

GroupAimbotSurv:AddSlider("Surv_Aimbot_Smoothness", {
    Min = 1,
    Default = 5,
    Max = 10,
    Text = "Aimbot Smoothness",
    Rounding = 1,
    Callback = function(value)
        Config.Surv_Aimbot_Smoothness = value
    end
})

GroupAimbotSurv:AddInput("Surv_Aimbot_Predict", {
    Placeholder = "misal: 0.05",
    Default = "0.01",
    Numeric = true,
    Text = "Predict Aim Offset",
    Callback = function(value)
        local num = tonumber(value)
        if num then
            Config.Surv_Aimbot_Predict = num
        end
    end
})

-- ============================================
-- CAMERA SETTINGS
-- ============================================

local GroupCamera = TabSurvivor:AddRightGroupbox("Camera Settings", "camera")

GroupCamera:AddToggle("InfinityZoom", {
    Text = "Infinity Zoom Out",
    Default = false,
    Tooltip = "Zoom Out tanpa batas",
    Callback = function(value)
        Config.InfinityZoom = value
        if value then
            LocalPlayer.CameraMaxZoomDistance = math.huge
            LocalPlayer.CameraMinZoomDistance = 0
        end
    end
})

GroupCamera:AddToggle("CameraFOV", {
    Text = "Camera FOV",
    Default = false,
    Tooltip = "Atur jarak pandang kamera",
    Callback = function(value)
        Config.CameraFOV = value
        if value and CurrentCamera then
            TweenService:Create(CurrentCamera, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
                FieldOfView = Config.FOVValue
            }):Play()
        end
    end
})

GroupCamera:AddSlider("FOVValue", {
    Min = 60,
    Default = 90,
    Max = 120,
    Text = "FOV Value",
    Rounding = 0,
    Callback = function(value)
        Config.FOVValue = value
        if Config.CameraFOV and CurrentCamera then
            CurrentCamera.FieldOfView = value
        end
    end
})

-- ============================================
-- TAB KILLER
-- ============================================

local GroupKillerAbility = TabKiller:AddLeftGroupbox("Ability", "swords")

-- Aimbot
GroupKillerAbility:AddToggle("Killer_Aimbot_Enabled", {
    Text = "Enable Aimbot",
    Default = false,
    Callback = function(value)
        Config.Killer_Aimbot_Enabled = value
    end
})

GroupKillerAbility:AddSlider("Killer_Aimbot_MaxDist", {
    Min = 5,
    Default = 12,
    Max = 30,
    Text = "Melee Lock Distance",
    Rounding = 0,
    Callback = function(value)
        Config.Killer_Aimbot_MaxDist = value
    end
})

GroupKillerAbility:AddSlider("Killer_Aimbot_Smoothness", {
    Min = 1,
    Default = 5,
    Max = 10,
    Text = "Aimbot Smoothness",
    Rounding = 1,
    Callback = function(value)
        Config.Killer_Aimbot_Smoothness = value
    end
})

-- Auto Kill All
GroupKillerAbility:AddToggle("AutoKillAll", {
    Text = "Auto Kill All",
    Default = false,
    Tooltip = "Automatically hunt and eliminate all survivors",
    Callback = function(value)
        Config.AutoKillAll = value
        if value then
            Library:Notify({
                Time = 3,
                Title = "Warning!",
                Description = "Fitur berisiko! Auto Kill All aktif"
            })
        end
    end
})

-- Auto Attack
GroupKillerAbility:AddToggle("AutoAttack", {
    Text = "Auto Attack",
    Default = false,
    Tooltip = "Auto hit survi yang deket",
    Callback = function(value)
        Config.AutoAttack = value
    end
})

-- No Slowdown
GroupKillerAbility:AddToggle("NoSlowdown", {
    Text = "No Slowdown killer",
    Default = false,
    Tooltip = "Hilangkan slowdown saat menyerang (Killer Only)",
    Callback = function(value)
        Config.NoSlowdown = value
        if value then
            Library:Notify({
                Time = 3,
                Title = "No Slowdown",
                Description = "✔ AKTIF - WalkSpeed dikunci"
            })
        end
    end
}):AddKeyPicker("NoSlowdownKey", {
    Text = "No Slowdown Keybind",
    Default = "None",
    Mode = "Toggle"
})

-- Infinite Lunge
GroupKillerAbility:AddToggle("InfiniteLunge", {
    Text = "Infinite Lunge",
    Default = false,
    Tooltip = "Lunge tanpa batas (Killer Only)",
    Callback = function(value)
        Config.InfiniteLunge = value
        if value then
            local char = GetCharacter()
            if char then
                char:SetAttribute("lungeboost", 999)
            end
            Library:Notify({
                Time = 3,
                Title = "Infinite Lunge",
                Description = "✔ AKTIF (999x)"
            })
        end
    end
}):AddKeyPicker("InfiniteLungeKey", {
    Text = "Infinite Lunge Key",
    Default = "F9",
    Mode = "Toggle"
})

-- Infinite Abyssal
GroupKillerAbility:AddToggle("Killer_InfAbyssal", {
    Text = "Infinite corrupt Abyssal",
    Default = false,
    Callback = function(value)
        Config.Killer_InfAbyssal = value
    end
})

-- Aim Lock Toggle
GroupKillerAbility:AddButton({
    Text = "Aim Lock Toggle",
    Callback = function()
        pcall(function()
            loadstring(game:HttpGet("https://pastefy.app/5zsm8N7G/raw"))()
            Library:Notify({
                Time = 3,
                Title = "Aim Lock",
                Description = "Aim Lock berhasil dimuat!"
            })
        end)
    end
})

-- Mask Selector
GroupKillerAbility:AddButton({
    Text = "Open Mask Selector GUI",
    Callback = function()
        pcall(function()
            loadstring(game:HttpGet("https://pastefy.app/nJrAelfC/raw"))()
            Library:Notify({
                Time = 3,
                Title = "Mask Selector",
                Description = "GUI Mask Selector berhasil dimuat!"
            })
        end)
    end
})

-- ============================================
-- SILENT AIM (VEIL SPEAR)
-- ============================================

local GroupVeilAim = TabKiller:AddRightGroupbox("Silent Aim (Veil Spear)", "arrow-right")

GroupVeilAim:AddToggle("SilentAimVeil", {
    Text = "Silent Aim (Veil Spear)",
    Default = false,
    Callback = function(value)
        Config.SilentAimVeil = value
    end
}):AddKeyPicker("SilentAimVeilKey", {
    Text = "Veil Aim Key",
    Default = "None",
    Mode = "Toggle"
})

GroupVeilAim:AddSlider("Veil_SpearSpeed", {
    Min = 50,
    Default = 165,
    Max = 200,
    Text = "Spear Speed",
    Rounding = 0,
    Callback = function(value)
        Config.Veil_SpearSpeed = value
    end
})

GroupVeilAim:AddSlider("Veil_SpearGravity", {
    Min = 0,
    Default = 103,
    Max = 200,
    Text = "Spear Gravity",
    Rounding = 0,
    Callback = function(value)
        Config.Veil_SpearGravity = value
    end
})

GroupVeilAim:AddToggle("VeilTracker", {
    Text = "ESP Tracker Target",
    Default = false,
    Callback = function(value)
        Config.VeilTracker = value
    end
})

GroupVeilAim:AddToggle("SilentAimPredict", {
    Text = "Auto Predict",
    Default = false,
    Tooltip = "Auto predict spear untuk Veil",
    Callback = function(value)
        Config.SilentAimPredict = value
    end
})

GroupVeilAim:AddToggle("VeilShowFOV", {
    Text = "Show Veil FOV",
    Default = true,
    Callback = function(value)
        Config.VeilShowFOV = value
    end
})

GroupVeilAim:AddSlider("VeilFOV", {
    Min = 50,
    Default = 150,
    Max = 500,
    Text = "Veil FOV Radius",
    Rounding = 0,
    Callback = function(value)
        Config.VeilFOV = value
    end
})

-- ============================================
-- KILLER CAMERA
-- ============================================

local GroupKillerCamera = TabKiller:AddRightGroupbox("Camera Setting", "camera")

GroupKillerCamera:AddToggle("KillerThirdPerson", {
    Text = "Third Person (Killer)",
    Default = false,
    Tooltip = "Mengubah posisi kamera ke belakang karakter",
    Callback = function(value)
        Config.KillerThirdPerson = value
        if value then
            LocalPlayer.CameraMode = Enum.CameraMode.Classic
            LocalPlayer.CameraMinZoomDistance = 7
            LocalPlayer.CameraMaxZoomDistance = 128
        end
    end
})

-- ============================================
-- TAB ESP
-- ============================================

local GroupESP = TabESP:AddLeftGroupbox("ESP Players", "user")

-- Master ESP Toggle
GroupESP:AddToggle("ESP_Master", {
    Text = "Enable Esp",
    Default = false,
    Callback = function(value)
        Config.ESP_Master = value
        if not value then
            -- Cleanup ESP objects
            for _, obj in pairs(ESPObjects) do
                pcall(function() obj:Destroy() end)
            end
            ESPObjects = {}
        end
    end
})

-- Player ESP
GroupESP:AddCheckbox("ESP_Player", {
    Text = "Player",
    Default = false,
    Callback = function(value)
        Config.ESP_Player = value
    end
}):AddColorPicker("Color_Player", {
    Default = Color3.fromRGB(57, 255, 20),
    Title = "Player Color",
    Callback = function(value)
        Config.Color_Player = value
    end
})

-- Killer ESP
GroupESP:AddCheckbox("ESP_Killer", {
    Text = "Killer",
    Default = false,
    Callback = function(value)
        Config.ESP_Killer = value
    end
}):AddColorPicker("Color_Killer", {
    Default = Color3.fromRGB(255, 40, 40),
    Title = "Killer Color",
    Callback = function(value)
        Config.Color_Killer = value
    end
})

-- ESP Name
GroupESP:AddCheckbox("ESP_Name", {
    Text = "Esp Name",
    Default = false,
    Callback = function(value)
        Config.ESP_Name = value
    end
})

-- ESP Distance
GroupESP:AddCheckbox("ESP_Distance", {
    Text = "Esp Distance",
    Default = false,
    Callback = function(value)
        Config.ESP_Distance = value
    end
})

-- SCP ESP
GroupESP:AddCheckbox("ESP_SCP", {
    Text = "SCP / Zombie",
    Default = false,
    Callback = function(value)
        Config.ESP_SCP = value
    end
}):AddColorPicker("Color_SCP", {
    Default = Color3.fromRGB(255, 0, 255),
    Title = "SCP Color",
    Callback = function(value)
        Config.Color_SCP = value
    end
})

-- Item Icon ESP
GroupESP:AddCheckbox("ESP_ItemIcon", {
    Text = "Esp Item Icon",
    Default = false,
    Callback = function(value)
        Config.ESP_ItemIcon = value
    end
})

-- Killer Warn
GroupESP:AddCheckbox("ESP_KillerWarn", {
    Text = "Killer Warn",
    Default = false,
    Callback = function(value)
        Config.ESP_KillerWarn = value
    end
})

-- ============================================
-- ESP MAPS
-- ============================================

local GroupESPMaps = TabESP:AddLeftGroupbox("ESP Maps", "map")

-- Generator ESP
GroupESPMaps:AddCheckbox("ESP_Generator", {
    Text = "Generator",
    Default = false,
    Callback = function(value)
        Config.ESP_Generator = value
    end
}):AddColorPicker("Color_Generator", {
    Default = Color3.fromRGB(255, 255, 0),
    Title = "Generator Color",
    Callback = function(value)
        Config.Color_Generator = value
    end
})

-- Pallet ESP
GroupESPMaps:AddCheckbox("ESP_Pallet", {
    Text = "Pallet",
    Default = false,
    Callback = function(value)
        Config.ESP_Pallet = value
    end
}):AddColorPicker("Color_Pallet", {
    Default = Color3.fromRGB(255, 128, 0),
    Title = "Pallet Color",
    Callback = function(value)
        Config.Color_Pallet = value
    end
})

-- Window ESP
GroupESPMaps:AddCheckbox("ESP_Window", {
    Text = "Window / Vault",
    Default = false,
    Callback = function(value)
        Config.ESP_Window = value
    end
}):AddColorPicker("Color_Window", {
    Default = Color3.fromRGB(0, 200, 255),
    Title = "Window Color",
    Callback = function(value)
        Config.Color_Window = value
    end
})

-- Hook ESP
GroupESPMaps:AddCheckbox("ESP_Hook", {
    Text = "Hook",
    Default = false,
    Callback = function(value)
        Config.ESP_Hook = value
    end
}):AddColorPicker("Color_Hook", {
    Default = Color3.fromRGB(255, 105, 180),
    Title = "Hook Color",
    Callback = function(value)
        Config.Color_Hook = value
    end
})

-- Gate ESP
GroupESPMaps:AddCheckbox("ESP_Gate", {
    Text = "Exit Gate",
    Default = false,
    Callback = function(value)
        Config.ESP_Gate = value
    end
}):AddColorPicker("Color_Gate", {
    Default = Color3.fromRGB(0, 255, 255),
    Title = "Gate Color",
    Callback = function(value)
        Config.Color_Gate = value
    end
})

-- ============================================
-- NEXT KILLER / SPECTATOR
-- ============================================

local GroupNextKiller = TabESP:AddRightGroupbox("Next Killer", "skull")

GroupNextKiller:AddToggle("NextKillerToggle", {
    Text = "Next Killer Display",
    Default = false,
    Tooltip = "Menampilkan prediksi killer selanjutnya di layar",
    Callback = function(value)
        Config.NextKillerToggle = value
        if value then
            local gui = Instance.new("ScreenGui")
            gui.Name = "NextKillerIndicator"
            gui.ResetOnSpawn = false
            gui.Parent = PlayerGui
            
            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(0, 300, 0, 40)
            frame.Position = UDim2.new(0.5, -150, 0.1, 0)
            frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
            frame.BackgroundTransparency = 0.3
            frame.BorderSizePixel = 0
            frame.Parent = gui
            
            Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
            
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.GothamBold
            label.Text = "Next Killer: -"
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            label.TextSize = 18
            label.Parent = frame
            
            -- Update loop
            task.spawn(function()
                while Config.NextKillerToggle do
                    local sorted = {}
                    for _, player in pairs(Players:GetPlayers()) do
                        table.insert(sorted, player)
                    end
                    table.sort(sorted, function(a, b)
                        return (a:GetAttribute("AllowKiller") or false) and not (b:GetAttribute("AllowKiller") or false)
                    end)
                    local nextKiller = sorted[1]
                    if nextKiller then
                        label.Text = "Next Killer: " .. nextKiller.Name
                    end
                    task.wait(1)
                end
            end)
        end
    end
})

-- Spectator Counter
GroupNextKiller:AddToggle("SpectatorToggle", {
    Text = "Enable Spectator Counter",
    Default = false,
    Tooltip = "Menampilkan jumlah player yang sedang jadi Spectator",
    Callback = function(value)
        Config.SpectatorToggle = value
        if value then
            local gui = Instance.new("ScreenGui")
            gui.Name = "SpectatorCounter"
            gui.ResetOnSpawn = false
            gui.Parent = PlayerGui
            
            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(0, 68, 0, 22)
            frame.Position = UDim2.new(0.02, 0, 0.1, 0)
            frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
            frame.BackgroundTransparency = 0.25
            frame.BorderSizePixel = 0
            frame.Parent = gui
            
            Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
            
            local layout = Instance.new("UIListLayout")
            layout.FillDirection = Enum.FillDirection.Horizontal
            layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
            layout.VerticalAlignment = Enum.VerticalAlignment.Center
            layout.Padding = UDim.new(0, 6)
            layout.Parent = frame
            
            local icon = Instance.new("ImageLabel")
            icon.Size = UDim2.new(0, 15, 0, 15)
            icon.BackgroundTransparency = 1
            icon.Image = "rbxassetid://13321848320"
            icon.ImageColor3 = Color3.fromRGB(180, 180, 255)
            icon.Parent = frame
            
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(0, 30, 0, 22)
            label.BackgroundTransparency = 1
            label.Font = Enum.Font.GothamMedium
            label.Text = "0"
            label.TextColor3 = Color3.fromRGB(240, 240, 240)
            label.TextSize = 13
            label.Parent = frame
            
            task.spawn(function()
                while Config.SpectatorToggle do
                    local count = 0
                    for _, player in pairs(Players:GetPlayers()) do
                        if player.Team and player.Team.Name == "Spectator" then
                            count = count + 1
                        end
                    end
                    label.Text = tostring(count)
                    task.wait(1)
                end
            end)
        end
    end
})

GroupNextKiller:AddButton({
    Text = "Refresh Count",
    Callback = function()
        -- Will be refreshed in loop
        Library:Notify({
            Time = 2,
            Title = "Spectator",
            Description = "Count refreshed!"
        })
    end
})

-- ============================================
-- WORLD EFFECTS
-- ============================================

local GroupWorldEffects = TabESP:AddRightGroupbox("World Effects", "sun")

-- Full Bright
GroupWorldEffects:AddToggle("FullBright", {
    Text = "Full Bright",
    Default = false,
    Tooltip = "Bikin map jadi terang biar lebih jelas",
    Callback = function(value)
        Config.FullBright = value
        if value then
            Lighting.Brightness = 5
            Lighting.ClockTime = Config.TimeOfDay
            Lighting.FogEnd = 100000
            Lighting.Ambient = Color3.fromRGB(255, 255, 255)
            Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        else
            Lighting.Brightness = 1
            Lighting.FogEnd = 10000
            Lighting.Ambient = Color3.fromRGB(127, 127, 127)
            Lighting.OutdoorAmbient = Color3.fromRGB(127, 127, 127)
        end
        Library:Notify({
            Time = 3,
            Title = "Full Bright",
            Description = value and "Full Bright aktif!" or "Full Bright nonaktif!"
        })
    end
})

-- Time of Day
GroupWorldEffects:AddSlider("TimeOfDay", {
    Min = 0,
    Default = 14,
    Max = 24,
    Text = "Time Of Day",
    Tooltip = "Atur waktu di game",
    Rounding = 0,
    Callback = function(value)
        Config.TimeOfDay = value
        if Config.FullBright then
            Lighting.ClockTime = value
        end
    end
})

-- No Fog
GroupWorldEffects:AddToggle("NoFog", {
    Text = "No Fog",
    Default = false,
    Tooltip = "Hapus kabut biar map lebih jelas",
    Callback = function(value)
        Config.NoFog = value
        if value then
            Lighting.FogStart = 0
            Lighting.FogEnd = 100000
            Lighting.FogColor = Color3.fromRGB(255, 255, 255)
            local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
            if atmosphere then
                atmosphere.Density = 0
            end
        else
            Lighting.FogStart = 0
            Lighting.FogEnd = 10000
            local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
            if atmosphere then
                atmosphere.Density = 1
            end
        end
    end
})

-- No Shadow
GroupWorldEffects:AddToggle("NoShadow", {
    Text = "No Shadow",
    Default = false,
    Tooltip = "Matikan shadow",
    Callback = function(value)
        Config.NoShadow = value
        Lighting.GlobalShadows = not value
        Library:Notify({
            Time = 3,
            Title = "No Shadow",
            Description = value and "Shadow berhasil dihapus!" or "Shadow dikembalikan normal"
        })
    end
})

-- ============================================
-- TAB TELEPORT
-- ============================================

local GroupTeleportPlayer = TabTeleport:AddLeftGroupbox("Teleport Players", "users")

local playerDropdown

-- Refresh player list
local function RefreshPlayerList()
    local players = {}
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            table.insert(players, player.Name)
        end
    end
    table.sort(players)
    if playerDropdown then
        playerDropdown:SetValues(players)
    end
    return players
end

playerDropdown = GroupTeleportPlayer:AddDropdown("PlayerDropdown", {
    Values = RefreshPlayerList(),
    Text = "Pilih Player",
    Tooltip = "TP ke player yang di pilih",
    Callback = function(value)
        Config.SelectedPlayer = value
    end,
    Default = ""
})

GroupTeleportPlayer:AddButton({
    Text = "Refresh Player",
    Callback = function()
        local players = RefreshPlayerList()
        Library:Notify({
            Time = 3,
            Title = "Teleport",
            Description = "List player direfresh! (" .. #players .. " player)"
        })
    end
})

GroupTeleportPlayer:AddButton({
    Text = "Teleport ke player yang dipilih",
    Callback = function()
        local playerName = Config.SelectedPlayer
        if playerName and playerName ~= "" then
            local player = Players:FindFirstChild(playerName)
            if player and player.Character then
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    local myRoot = GetHumanoidRootPart()
                    if myRoot then
                        myRoot.CFrame = root.CFrame
                        Library:Notify({
                            Time = 2,
                            Title = "Teleport",
                            Description = "Teleport ke " .. playerName
                        })
                    end
                end
            end
        end
    end
})

-- ============================================
-- TELEPORT MAPS
-- ============================================

local GroupTeleportMap = TabTeleport:AddRightGroupbox("Teleport Maps", "map")

-- Helper untuk teleport ke objek map
local function TeleportToMapObject(objectName)
    local map = workspace:FindFirstChild("Map")
    if map then
        for _, descendant in pairs(map:GetDescendants()) do
            if descendant:IsA("Model") and string.lower(descendant.Name) == string.lower(objectName) then
                local root = descendant:FindFirstChild("HumanoidRootPart") or descendant:FindFirstChild("RootPart") or descendant:FindFirstChildOfClass("Part")
                if root then
                    local myRoot = GetHumanoidRootPart()
                    if myRoot then
                        myRoot.CFrame = root.CFrame + Vector3.new(0, 3, 0)
                        Library:Notify({
                            Time = 2,
                            Title = "Teleport",
                            Description = "Teleport ke " .. objectName
                        })
                        return
                    end
                end
            end
        end
    end
    Library:Notify({
        Time = 2,
        Title = "Teleport",
        Description = "Tidak ditemukan " .. objectName
    })
end

GroupTeleportMap:AddButton({
    Text = "TP Generator (Loop)",
    Callback = function()
        TeleportToMapObject("Generator")
    end
})

GroupTeleportMap:AddButton({
    Text = "TP Hook (Loop)",
    Callback = function()
        TeleportToMapObject("Hook")
    end
})

GroupTeleportMap:AddButton({
    Text = "TP Gate (Loop)",
    Callback = function()
        TeleportToMapObject("Gate")
    end
})

GroupTeleportMap:AddButton({
    Text = "TP Pallet (Loop)",
    Callback = function()
        TeleportToMapObject("Pallet")
    end
})

GroupTeleportMap:AddButton({
    Text = "TP Window (Loop)",
    Callback = function()
        TeleportToMapObject("Window")
    end
})

GroupTeleportMap:AddButton({
    Text = "Refresh Map",
    Callback = function()
        Library:Notify({
            Time = 3,
            Title = "Map",
            Description = "✔ Map Cache Refreshed!"
        })
    end
})

-- ============================================
-- MAIN RENDER LOOP
-- ============================================

-- Crosshair drawing
local crosshairObjects = {}

local function CreateCrosshair()
    -- Cleanup old crosshair
    for _, obj in pairs(crosshairObjects) do
        pcall(function() obj:Destroy() end)
    end
    crosshairObjects = {}
    
    if not Config.Crosshair then return end
    
    local centerX = CurrentCamera.ViewportSize.X / 2 + Config.CrosshairPosX
    local centerY = CurrentCamera.ViewportSize.Y / 2 + Config.CrosshairPosY
    local size = Config.CrosshairSize
    local thickness = Config.CrosshairThickness
    local gap = Config.CrosshairGap
    local color = Config.CrosshairColor
    
    local style = Config.CrosshairStyle
    
    if style == "Dot" then
        local dot = Drawing.new("Circle")
        dot.Position = Vector2.new(centerX, centerY)
        dot.Radius = size
        dot.Filled = true
        dot.Color = color
        dot.Visible = true
        dot.Transparency = 1
        table.insert(crosshairObjects, dot)
    elseif style == "Plus" then
        -- Top
        local top = Drawing.new("Line")
        top.From = Vector2.new(centerX, centerY - gap - size)
        top.To = Vector2.new(centerX, centerY - gap)
        top.Thickness = thickness
        top.Color = color
        top.Visible = true
        top.Transparency = 1
        table.insert(crosshairObjects, top)
        
        -- Bottom
        local bottom = Drawing.new("Line")
        bottom.From = Vector2.new(centerX, centerY + gap)
        bottom.To = Vector2.new(centerX, centerY + gap + size)
        bottom.Thickness = thickness
        bottom.Color = color
        bottom.Visible = true
        bottom.Transparency = 1
        table.insert(crosshairObjects, bottom)
        
        -- Left
        local left = Drawing.new("Line")
        left.From = Vector2.new(centerX - gap - size, centerY)
        left.To = Vector2.new(centerX - gap, centerY)
        left.Thickness = thickness
        left.Color = color
        left.Visible = true
        left.Transparency = 1
        table.insert(crosshairObjects, left)
        
        -- Right
        local right = Drawing.new("Line")
        right.From = Vector2.new(centerX + gap, centerY)
        right.To = Vector2.new(centerX + gap + size, centerY)
        right.Thickness = thickness
        right.Color = color
        right.Visible = true
        right.Transparency = 1
        table.insert(crosshairObjects, right)
    elseif style == "X" then
        -- Diagonal lines
        for i = -1, 1, 2 do
            for j = -1, 1, 2 do
                local line = Drawing.new("Line")
                line.From = Vector2.new(centerX + i * (gap + size), centerY + j * (gap + size))
                line.To = Vector2.new(centerX + i * gap, centerY + j * gap)
                line.Thickness = thickness
                line.Color = color
                line.Visible = true
                line.Transparency = 1
                table.insert(crosshairObjects, line)
            end
        end
    elseif style == "Box" then
        -- Top line
        local top = Drawing.new("Line")
        top.From = Vector2.new(centerX - gap - size, centerY - gap - size)
        top.To = Vector2.new(centerX + gap + size, centerY - gap - size)
        top.Thickness = thickness
        top.Color = color
        top.Visible = true
        top.Transparency = 1
        table.insert(crosshairObjects, top)
        
        -- Bottom line
        local bottom = Drawing.new("Line")
        bottom.From = Vector2.new(centerX - gap - size, centerY + gap + size)
        bottom.To = Vector2.new(centerX + gap + size, centerY + gap + size)
        bottom.Thickness = thickness
        bottom.Color = color
        bottom.Visible = true
        bottom.Transparency = 1
        table.insert(crosshairObjects, bottom)
        
        -- Left line
        local left = Drawing.new("Line")
        left.From = Vector2.new(centerX - gap - size, centerY - gap - size)
        left.To = Vector2.new(centerX - gap - size, centerY + gap + size)
        left.Thickness = thickness
        left.Color = color
        left.Visible = true
        left.Transparency = 1
        table.insert(crosshairObjects, left)
        
        -- Right line
        local right = Drawing.new("Line")
        right.From = Vector2.new(centerX + gap + size, centerY - gap - size)
        right.To = Vector2.new(centerX + gap + size, centerY + gap + size)
        right.Thickness = thickness
        right.Color = color
        right.Visible = true
        right.Transparency = 1
        table.insert(crosshairObjects, right)
    end
end

-- ESP update function
local function UpdateESP()
    if not Config.ESP_Master then return end
    
    local myRoot = GetHumanoidRootPart()
    if not myRoot then return end
    
    local myPos = myRoot.Position
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root then
                    local dist = (root.Position - myPos).Magnitude
                    
                    -- Check if killer
                    local isKiller = player.Team and player.Team.Name == "Killer"
                    local isSCP = string.lower(char.Name):find("scp") ~= nil
                    
                    -- Determine color
                    local color = Config.Color_Player
                    if isKiller and Config.ESP_Killer then
                        color = Config.Color_Killer
                    elseif isSCP and Config.ESP_SCP then
                        color = Config.Color_SCP
                    end
                    
                    -- Create highlight if not exists
                    local highlight = char:FindFirstChild("PEH")
                    if not highlight and (Config.ESP_Player or Config.ESP_Killer or Config.ESP_SCP) then
                        highlight = Instance.new("Highlight")
                        highlight.Name = "PEH"
                        highlight.FillColor = color
                        highlight.OutlineColor = color
                        highlight.FillTransparency = 1
                        highlight.OutlineTransparency = 0
                        highlight.Parent = char
                        table.insert(ESPObjects, highlight)
                    end
                    
                    if highlight then
                        highlight.FillColor = color
                        highlight.OutlineColor = color
                        highlight.Visible = true
                    end
                    
                    -- Name and distance text
                    if Config.ESP_Name or Config.ESP_Distance then
                        local textObj = char:FindFirstChild("PE_Text")
                        if not textObj then
                            textObj = Instance.new("BillboardGui")
                            textObj.Name = "PE_Text"
                            textObj.Size = UDim2.new(0, 200, 0, 50)
                            textObj.Adornee = root
                            textObj.AlwaysOnTop = true
                            textObj.Parent = char
                            
                            local line = Instance.new("Frame")
                            line.Name = "Line"
                            line.Size = UDim2.new(1, 0, 0, 2)
                            line.BackgroundColor3 = color
                            line.BorderSizePixel = 0
                            line.Parent = textObj
                            
                            local box = Instance.new("Frame")
                            box.Name = "Box"
                            box.Size = UDim2.new(1, 0, 1, 0)
                            box.Position = UDim2.new(0, 0, 0, 2)
                            box.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
                            box.BackgroundTransparency = 0.5
                            box.BorderSizePixel = 0
                            box.Parent = textObj
                            
                            local label = Instance.new("TextLabel")
                            label.Name = "Text"
                            label.Size = UDim2.new(1, 0, 1, 0)
                            label.BackgroundTransparency = 1
                            label.Font = Enum.Font.GothamBold
                            label.Text = player.Name
                            label.TextColor3 = Color3.fromRGB(255, 255, 255)
                            label.TextSize = 14
                            label.Parent = box
                        end
                        
                        local label = textObj:FindFirstChild("Box"):FindFirstChild("Text")
                        if label then
                            local text = ""
                            if Config.ESP_Name then
                                text = player.Name
                            end
                            if Config.ESP_Distance then
                                local distInt = math.floor(dist)
                                text = text .. " [" .. distInt .. "m]"
                            end
                            label.Text = text
                        end
                        
                        local line = textObj:FindFirstChild("Line")
                        if line then
                            line.BackgroundColor3 = color
                        end
                    end
                end
            end
        end
    end
end

-- Main render loop
RenderStepped:Connect(function()
    -- Update crosshair
    if Config.Crosshair then
        if #crosshairObjects == 0 then
            CreateCrosshair()
        end
        for _, obj in pairs(crosshairObjects) do
            obj.Visible = true
        end
    else
        for _, obj in pairs(crosshairObjects) do
            obj.Visible = false
        end
    end
    
    -- Update ESP
    if Config.ESP_Master then
        UpdateESP()
    end
    
    -- Parry circle
    if Config.ParryCircle and Config.AutoParry then
        local root = GetHumanoidRootPart()
        if root then
            local circle = root:FindFirstChild("AutoParryCircleESP")
            if not circle then
                circle = Instance.new("CylinderHandleAdornment")
                circle.Name = "AutoParryCircleESP"
                circle.Height = 0.05
                circle.Transparency = 0.3
                circle.Adornee = root
                circle.Parent = root
                circle.ZIndex = 0
                circle.AlwaysOnTop = false
            end
            circle.Radius = Config.ParryRadius
            circle.InnerRadius = math.max(0.1, Config.ParryRadius - 0.15)
            circle.CFrame = CFrame.new(0, -3, 0) * CFrame.Angles(1.5707963267948966, 0, 0)
            if Config.ParryAggressive then
                circle.Color3 = Color3.fromRGB(255, 0, 0)
            else
                circle.Color3 = Color3.fromRGB(0, 255, 0)
            end
        end
    end
    
    -- Flee killer
    if Config.FleeKiller and IsSurvivor() then
        local root = GetHumanoidRootPart()
        if root then
            for _, player in pairs(Players:GetPlayers()) do
                if player.Team and player.Team.Name == "Killer" then
                    local char = player.Character
                    if char and char:FindFirstChild("HumanoidRootPart") then
                        local dist = (char.HumanoidRootPart.Position - root.Position).Magnitude
                        if dist < Config.FleeDistance then
                            -- Teleport away
                            local fleePos = root.Position + Vector3.new(
                                math.random(-50, 50),
                                0,
                                math.random(-50, 50)
                            )
                            root.CFrame = CFrame.new(fleePos)
                            Library:Notify({
                                Time = 1,
                                Title = "Flee",
                                Description = "Killer detected! Teleporting..."
                            })
                            break
                        end
                    end
                end
            end
        end
    end
    
    -- God mode
    if Config.GodMode then
        local humanoid = GetHumanoid()
        if humanoid then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
            humanoid:ChangeState(Enum.HumanoidStateType.Physics)
        end
    end
    
    -- No slowdown survivor
    if Config.NoSlowdownSurvivor and IsSurvivor() then
        local humanoid = GetHumanoid()
        if humanoid and humanoid.WalkSpeed < 16 then
            humanoid.WalkSpeed = 16
        end
    end
    
    -- No slowdown killer
    if Config.NoSlowdown and IsKiller() then
        local humanoid = GetHumanoid()
        if humanoid and humanoid.WalkSpeed < 16 then
            humanoid.WalkSpeed = 16
        end
    end
    
    -- Auto wiggle
    if Config.AutoWiggle and IsSurvivor() then
        local isCarried = Character and Character:FindFirstChild("IsCarried")
        if isCarried and isCarried.Value then
            local remotes = ReplicatedStorage:FindFirstChild("Remotes")
            if remotes then
                local carry = remotes:FindFirstChild("Carry")
                if carry then
                    local unhook = carry:FindFirstChild("SelfUnHookEvent")
                    if unhook then
                        unhook:FireServer()
                    end
                end
            end
        end
    end
    
    -- Auto attack (killer)
    if Config.AutoAttack and IsKiller() then
        local root = GetHumanoidRootPart()
        if root then
            local closest = nil
            local closestDist = Config.Killer_Aimbot_MaxDist or 12
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Team and player.Team.Name == "Survivors" then
                    local char = player.Character
                    if char and char:FindFirstChild("HumanoidRootPart") then
                        local dist = (char.HumanoidRootPart.Position - root.Position).Magnitude
                        if dist < closestDist then
                            closestDist = dist
                            closest = player
                        end
                    end
                end
            end
            if closest then
                -- Face target
                local targetRoot = closest.Character.HumanoidRootPart
                root.CFrame = CFrame.new(root.Position, targetRoot.Position)
                -- Attack
                local humanoid = GetHumanoid()
                if humanoid then
                    humanoid:ChangeState(Enum.HumanoidStateType.Attacking)
                end
            end
        end
    end
end)

-- ============================================
-- CHARACTER ADDED EVENT
-- ============================================

LocalPlayer.CharacterAdded:Connect(function(char)
    Character = char
    task.wait(1.2)
    
    -- Reset features on respawn
    if Config.FullBright then
        Lighting.Brightness = 5
        Lighting.ClockTime = Config.TimeOfDay
        Lighting.FogEnd = 100000
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
    end
    
    if Config.NoFog then
        Lighting.FogStart = 0
        Lighting.FogEnd = 100000
        Lighting.FogColor = Color3.fromRGB(255, 255, 255)
        local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
        if atmosphere then
            atmosphere.Density = 0
        end
    end
    
    if Config.InfiniteLunge and IsKiller() then
        char:SetAttribute("lungeboost", 999)
    end
end)

-- ============================================
-- TEAM CHANGE EVENT
-- ============================================

LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
    Team = LocalPlayer.Team
    TeamName = Team and Team.Name or "Unknown"
    
    if TeamName == "Survivors" and Config.AutoAFKEscape then
        Library:Notify({
            Time = 3,
            Title = "Auto Farm",
            Description = "Mode AFK Survivor aktif!"
        })
    end
end)

-- ============================================
-- PLAYER ADDED EVENT
-- ============================================

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        -- Update ESP when new player spawns
        if Config.ESP_Master then
            task.wait(0.5)
        end
    end)
end)

-- ============================================
-- SAVE / LOAD CONFIG
-- ============================================

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({"MenuKeybind"})
ThemeManager:SetFolder("PanduHub")
SaveManager:SetFolder("PanduHub/SurviveTheKiller")
SaveManager:BuildConfigSection(TabSettings)
ThemeManager:ApplyToTab(TabSettings)
SaveManager:LoadAutoloadConfig()

-- ============================================
-- INITIALIZATION NOTIFICATION
-- ============================================

Library:Notify({
    Time = 5,
    Title = "Pandu Hub",
    Description = "Berhasil Dimuat!\n" ..
    "Klik RightShift untuk buka/tutup menu\n" ..
    "Gunakan dengan bijak!"
})
