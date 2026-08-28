-- EXPIRY:2026-08-30
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer

-- Helper HTTP GET awal (dipakai juga oleh AC_MORPHCHAR untuk deteksi Korblox/Headless).
-- Definisi lengkap/duplikat lain di bawah nanti tetap aman dipakai untuk fitur lain.
local function httpGetEarly(url)
    local ok, res = pcall(function()
        if request then return request({Url=url,Method="GET"}).Body
        elseif http_request then return http_request({Url=url,Method="GET"}).Body
        elseif syn and syn.request then return syn.request({Url=url,Method="GET"}).Body
        else return game:HttpGet(url) end
    end)
    return ok and res or nil
end

-- ID leg klasik Korblox Deathspeaker (bundle 192) -- dicek terpisah kiri & kanan,
-- karena banyak pemain cuma pakai salah satu kaki saja, bukan selalu dua-duanya.
local KORBLOX_LEFT_LEG_ID  = 139607673
local KORBLOX_RIGHT_LEG_ID = 139607718

-- Cek avatar asset milik userId lewat avatar.roblox.com, kembalikan
-- {hasKorbloxLeft = bool, hasKorbloxRight = bool, hasHeadless = bool}.
-- Aman dipanggil dari client (HTTP GET biasa).
-- Headless dideteksi dari NAMA asset Head (bukan ID tetap) karena Roblox pernah
-- migrasi Head klasik ke "Dynamic Head" dengan asset ID yang beda/berubah-ubah
-- per akun, jadi cek ID mentah tidak reliable.
local function AC_DetectBundleFeatures(userId)
    local result = {hasKorbloxLeft = false, hasKorbloxRight = false, hasHeadless = false}
    local body = httpGetEarly("https://avatar.roblox.com/v1/users/" .. tostring(userId) .. "/avatar")
    if not body then return result end
    local ok, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not ok or not data or not data.assets then return result end
    for _, asset in ipairs(data.assets) do
        if asset.id == KORBLOX_LEFT_LEG_ID then
            result.hasKorbloxLeft = true
        elseif asset.id == KORBLOX_RIGHT_LEG_ID then
            result.hasKorbloxRight = true
        end
        local assetTypeName = asset.assetType and asset.assetType.name
        local nameLower = asset.name and tostring(asset.name):lower() or ""
        if assetTypeName == "Head" and nameLower:find("headless") then
            result.hasHeadless = true
        end
    end
    return result
end

-- Versi global/reusable dari applyHeadless & applyKorblox (parameterized by char),
-- dipakai baik oleh toggle Headless & Korblox di menu maupun oleh avatar changer
-- (AC_MORPHCHAR) supaya kalau target avatar terdeteksi pakai bundle ini, hasilnya
-- ikut ke-apply dengan cara yang sama persis (bukan lewat API server-only yang rusak).
local HEADLESS_MESH_ID = "rbxassetid://1095708"

-- Simpan SpecialMesh/Decal asli Head (R6) sebelum diganti, supaya bisa
-- dikembalikan persis waktu Headless dimatikan.
local _headlessR6Cache = setmetatable({}, {__mode = "k"})

local function GLOBAL_ApplyHeadless(char, state)
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    local isR6 = (char:FindFirstChild("Right Leg") ~= nil) and (char:FindFirstChild("RightUpperLeg") == nil)

    if isR6 then
        pcall(function()
            if state then
                if not _headlessR6Cache[head] then
                    local origChildren = {}
                    for _, v in ipairs(head:GetChildren()) do
                        if v:IsA("SpecialMesh") or v:IsA("CharacterMesh") or v:IsA("Decal") then
                            table.insert(origChildren, v:Clone())
                        end
                    end
                    _headlessR6Cache[head] = {
                        children = origChildren,
                        transparency = head.Transparency,
                        canCollide = head.CanCollide,
                    }
                end

                head.Transparency = 1
                head.CanCollide = false

                local face = head:FindFirstChildOfClass("Decal")
                if face then face:Destroy() end

                for _, v in ipairs(head:GetChildren()) do
                    if v:IsA("SpecialMesh") or v:IsA("CharacterMesh") then
                        v:Destroy()
                    end
                end

                local mesh = Instance.new("SpecialMesh")
                mesh.MeshType = Enum.MeshType.FileMesh
                mesh.MeshId = HEADLESS_MESH_ID
                mesh.Scale = Vector3.new(0.001, 0.001, 0.001)
                mesh.Parent = head
            else
                local saved = _headlessR6Cache[head]
                for _, v in ipairs(head:GetChildren()) do
                    if v:IsA("SpecialMesh") or v:IsA("CharacterMesh") or v:IsA("Decal") then
                        v:Destroy()
                    end
                end
                if saved then
                    head.Transparency = saved.transparency
                    head.CanCollide = saved.canCollide
                    for _, clone in ipairs(saved.children) do
                        clone:Clone().Parent = head
                    end
                    _headlessR6Cache[head] = nil
                else
                    head.Transparency = 0
                    head.CanCollide = true
                end
            end
        end)
        return
    end

    -- R15: Head adalah MeshPart, jadi pakai transparansi (tidak bisa hapus
    -- mesh bawaan tanpa merusak bentuk kepala R15 secara permanen).
    pcall(function()
        if state then
            head.Transparency = 1
            for _, v in ipairs(head:GetChildren()) do
                if v:IsA("Decal") then v.Transparency = 1 end
            end
        else
            head.Transparency = 0
            for _, v in ipairs(head:GetChildren()) do
                if v:IsA("Decal") then v.Transparency = 0 end
            end
        end
    end)
end

-- Cache original leg mesh per karakter (pakai part instance sbg key) supaya waktu
-- di-nonaktifkan, kaki balik ke bentuk aslinya (bukan MeshId kosong yang bikin putih).
local _korbloxOriginalCache = setmetatable({}, {__mode = "k"})

local function _saveKorbloxOriginal(part)
    if not part or _korbloxOriginalCache[part] then return end
    _korbloxOriginalCache[part] = {
        MeshId = part.MeshId,
        TextureID = part.TextureID,
        Transparency = part.Transparency,
    }
end

local function _restoreKorbloxOriginal(part)
    if not part then return end
    local saved = _korbloxOriginalCache[part]
    if saved then
        pcall(function()
            part.MeshId = saved.MeshId
            part.TextureID = saved.TextureID
            part.Transparency = saved.Transparency
        end)
    end
end

-- R6: SpecialMesh dengan ID mentah yang sudah dikonfirmasi bekerja
-- (persis pola script "Headless + Korblox (R6) BY 200" yang terbukti jalan).
-- Cuma kaki KANAN sesuai permintaan -- R6 tidak dapat kaki kiri terpisah.
local KORBLOX_R6_MESH_ID = "rbxassetid://101851696"
local KORBLOX_R6_TEXTURE_ID = "rbxassetid://101851254"

local _korbloxR6Cache = setmetatable({}, {__mode = "k"})

local function _applyKorbloxR6(char, state)
    local rightLeg = char:FindFirstChild("Right Leg")
    if not rightLeg then return end

    if state then
        if not _korbloxR6Cache[rightLeg] then
            local origChildren = {}
            for _, v in ipairs(rightLeg:GetChildren()) do
                if v:IsA("SpecialMesh") or v:IsA("CharacterMesh") then
                    table.insert(origChildren, v:Clone())
                end
            end
            _korbloxR6Cache[rightLeg] = origChildren
        end

        pcall(function()
            for _, v in ipairs(rightLeg:GetChildren()) do
                if v:IsA("SpecialMesh") or v:IsA("CharacterMesh") then
                    v:Destroy()
                end
            end

            local mesh = Instance.new("SpecialMesh")
            mesh.MeshType = Enum.MeshType.FileMesh
            mesh.MeshId = KORBLOX_R6_MESH_ID
            mesh.TextureId = KORBLOX_R6_TEXTURE_ID
            mesh.Scale = Vector3.new(1, 1, 1)
            mesh.Parent = rightLeg
        end)
    else
        pcall(function()
            for _, v in ipairs(rightLeg:GetChildren()) do
                if v:IsA("SpecialMesh") or v:IsA("CharacterMesh") then
                    v:Destroy()
                end
            end
            local saved = _korbloxR6Cache[rightLeg]
            if saved then
                for _, clone in ipairs(saved) do
                    clone:Clone().Parent = rightLeg
                end
                _korbloxR6Cache[rightLeg] = nil
            end
        end)
    end
end

-- MeshId Korblox untuk R15 (kanan pakai ID lama yang terbukti jalan; kiri
-- pakai mesh aslinya sendiri dari asset 139607673 lewat game:GetObjects).
-- Otomatis deteksi R6 vs R15: R6 pakai jalur SpecialMesh kanan-saja di atas,
-- R15 tetap dukung kiri+kanan seperti sebelumnya.
local KORBLOX_LEFT_LEG_CATALOG_ID = 139607673
local _korbloxLeftMeshCache = nil
local function _getKorbloxLeftMeshData()
    if _korbloxLeftMeshCache then return _korbloxLeftMeshCache end
    local ok, objs = pcall(function()
        return game:GetObjects("rbxassetid://" .. tostring(KORBLOX_LEFT_LEG_CATALOG_ID))
    end)
    if not ok or not objs or #objs == 0 then return nil end

    local foundMeshPart = nil
    for _, obj in ipairs(objs) do
        for _, desc in ipairs(obj:GetDescendants()) do
            if desc:IsA("MeshPart") and not foundMeshPart and tostring(desc.MeshId):match("%d+") and tostring(desc.MeshId) ~= "1" then
                foundMeshPart = desc
            end
        end
    end
    if not foundMeshPart then return nil end
    _korbloxLeftMeshCache = {MeshId = foundMeshPart.MeshId, TextureID = foundMeshPart.TextureID}
    return _korbloxLeftMeshCache
end

local function GLOBAL_ApplyKorblox(char, stateRight, stateLeft)
    if not char then return end

    local isR6 = (char:FindFirstChild("Right Leg") ~= nil) and (char:FindFirstChild("RightUpperLeg") == nil)

    if isR6 then
        -- R6 cuma kaki kanan (sesuai permintaan), kaki kiri diabaikan.
        _applyKorbloxR6(char, stateRight)
        return
    end

    local rll = char:FindFirstChild("RightLowerLeg")
    local rul = char:FindFirstChild("RightUpperLeg")
    local rf  = char:FindFirstChild("RightFoot")
    local lll = char:FindFirstChild("LeftLowerLeg")
    local lul = char:FindFirstChild("LeftUpperLeg")
    local lf  = char:FindFirstChild("LeftFoot")

    if stateRight then
        _saveKorbloxOriginal(rll); _saveKorbloxOriginal(rul); _saveKorbloxOriginal(rf)
        pcall(function()
            if rll then rll.MeshId = "rbxassetid://902942093"; rll.Transparency = 1 end
            if rul then rul.MeshId = "http://www.roblox.com/asset/?id=902942096"; rul.TextureID = "http://roblox.com/asset/?id=902843398" end
            if rf  then rf.MeshId  = "rbxassetid://902942089";  rf.Transparency  = 1 end
        end)
    else
        _restoreKorbloxOriginal(rll); _restoreKorbloxOriginal(rul); _restoreKorbloxOriginal(rf)
    end

    if stateLeft then
        _saveKorbloxOriginal(lll); _saveKorbloxOriginal(lul); _saveKorbloxOriginal(lf)
        local meshData = _getKorbloxLeftMeshData()
        pcall(function()
            if meshData and meshData.MeshId then
                if lll then lll.MeshId = meshData.MeshId; lll.Transparency = 1 end
                if lul then lul.MeshId = meshData.MeshId; if meshData.TextureID then lul.TextureID = meshData.TextureID end end
                if lf  then lf.MeshId  = meshData.MeshId; lf.Transparency  = 1 end
            else
                -- Fallback kalau asset gagal diambil (mis. koneksi), pakai bentuk kanan
                -- supaya minimal tetap ada efek Korblox, walau tidak 100% sama bentuknya.
                if lll then lll.MeshId = "rbxassetid://902942093"; lll.Transparency = 1 end
                if lul then lul.MeshId = "http://www.roblox.com/asset/?id=902942096"; lul.TextureID = "http://roblox.com/asset/?id=902843398" end
                if lf  then lf.MeshId  = "rbxassetid://902942089";  lf.Transparency  = 1 end
            end
        end)
    else
        _restoreKorbloxOriginal(lll); _restoreKorbloxOriginal(lul); _restoreKorbloxOriginal(lf)
    end
end


local function makeUI(parent, class, props)
    local obj = Instance.new(class)
    for k, v in pairs(props) do obj[k] = v end
    obj.Parent = parent
    return obj
end

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local CAS = game:GetService("ContextActionService")

local NoclipEnabled = false
local InfiniteJumpEnabled = false
local GodModeEnabled = false
local ZeroMultiFlingEnabled = false
local ZeroMultiFlingOpenBtn = nil
local FlyEnabled = false
local AntiKickEnabled = false
local NameEspEnabled = false
local InvisibleEnabled = false
local SpyEnabled = false
local AntiLagEnabled = false
local CheckpointEspEnabled = false

local NoclipConnection = nil
local JumpConnection = nil
local GodModeConnection = nil
local GodModeConnections = {}
local FlyConnection = nil
local FlyBodyVelocity = nil
local FlyBodyGyro = nil
local AntiKickConnection = nil
local NameEspConnection = nil
local InvisibleConnection = nil
local InvisibleRenderConn = nil
local SpyConnection = nil
local AntiLagConnection = nil
local CheckpointEspConnection = nil
local CheckpointAddedConnection = nil

local currentWalkSpeed = 16
local currentJumpPower = 50

local SpeedEffect = {
    Blur = nil,
    RunBlur = nil,
    runBlurTween = nil,
    wasMoving = false,
    wndPart = nil,
    wndAttachment = nil,
    bodyParticles = {},
    RenderConn = nil,
    tickW = 0,
    Part_upvr = nil,
    enabled = false,

    vibrateConn = nil,
    vibrateRunning = false,
    vibrateDir = {-0.1, 0, 0.1, 0},
    vibrateDirIdx = 1,
    vibrateSound = nil,
    vibrateSoundLoaded = false,

    darkAuraEmitters = {},
    darkAuraBlur = nil,
    darkAuraActive = false,

    flickerTrails = {},
    flickerActive = false,
    flickerThread = nil,

    groundArcActive = false,
    groundArcThread = nil,
    groundRayParams = nil,
}

local JumpEffect = {
    maxJumps        = 1000,
    geppoboost      = 30,
    jumpCount       = 0,
    baseJumpPower   = 0,
    currentChar     = nil,
    currentHumanoid = nil,
    currentRootPart = nil,
    vfxAttachment   = nil,
    emitter2        = nil,
    stateConn       = nil,
    charConn        = nil,
}

local function JumpEffect_createParticle(parent, props)
    local emitter = Instance.new("ParticleEmitter")
    for prop, val in pairs(props) do emitter[prop] = val end
    emitter.VelocityInheritance = 0
    emitter.LockedToPart        = false
    emitter.Drag                = 9
    emitter.Parent              = parent
    return emitter
end

local function JumpEffect_setupVFX(rootPart)
    if JumpEffect.vfxAttachment then
        pcall(function() JumpEffect.vfxAttachment:Destroy() end)
        JumpEffect.vfxAttachment = nil
        JumpEffect.emitter2      = nil
    end
    local att = Instance.new("Attachment")
    att.Name     = "JumpVFXAttachment"
    att.Position = Vector3.new(0, -2.5, 0)
    att.Parent   = rootPart
    JumpEffect.vfxAttachment = att

    JumpEffect.emitter2 = JumpEffect_createParticle(att, {
        Texture   = "rbxassetid://15021706755",
        Color     = ColorSequence.new(Color3.fromRGB(91, 91, 91)),
        Lifetime  = NumberRange.new(0.4, 0.9),
        Rate      = 0,
        Rotation  = NumberRange.new(180),
        Speed     = NumberRange.new(0.121, 2.422),
        Size      = NumberSequence.new({
            NumberSequenceKeypoint.new(0,   0),
            NumberSequenceKeypoint.new(0.1, 7.78),
            NumberSequenceKeypoint.new(0.2, 10),
            NumberSequenceKeypoint.new(0.3, 10),
            NumberSequenceKeypoint.new(0.4, 10),
            NumberSequenceKeypoint.new(0.5, 10),
            NumberSequenceKeypoint.new(0.6, 10),
            NumberSequenceKeypoint.new(0.8, 10),
            NumberSequenceKeypoint.new(0.9, 10),
            NumberSequenceKeypoint.new(1,   10),
        }),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0,      1),
            NumberSequenceKeypoint.new(0.0962, 0.749),
            NumberSequenceKeypoint.new(1,      1),
        }),
        Squash           = NumberSequence.new(0),
        LightEmission    = 0.7,
        LightInfluence   = 0.6,
        Orientation      = Enum.ParticleOrientation.VelocityPerpendicular,
        SpreadAngle      = Vector2.new(5, 5),
        Shape            = Enum.ParticleEmitterShape.Box,
        ShapeInOut       = Enum.ParticleEmitterShapeInOut.Outward,
        Brightness       = 1,
        ZOffset          = 0,
        RotSpeed         = NumberRange.new(-40, 40),
        TimeScale        = 1,
        EmissionDirection = Enum.NormalId.Top,
    })
end

local function JumpEffect_setupCharacter(character)
    if not InfiniteJumpEnabled then return end
    JumpEffect.currentChar     = character
    JumpEffect.currentHumanoid = character:WaitForChild("Humanoid")
    JumpEffect.currentRootPart = character:WaitForChild("HumanoidRootPart")
    JumpEffect.jumpCount       = 0
    JumpEffect.baseJumpPower   = JumpEffect.currentHumanoid.JumpPower
    JumpEffect_setupVFX(JumpEffect.currentRootPart)
    if JumpEffect.stateConn then
        pcall(function() JumpEffect.stateConn:Disconnect() end)
    end
    JumpEffect.stateConn = JumpEffect.currentHumanoid.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Landed then
            JumpEffect.jumpCount = 0
            pcall(function() JumpEffect.currentHumanoid.JumpPower = JumpEffect.baseJumpPower end)
        end
    end)
end

local function JumpEffect_doGeppo()
    if not InfiniteJumpEnabled then return end
    local hum  = JumpEffect.currentHumanoid
    local root = JumpEffect.currentRootPart
    if not hum or not root then return end
    if JumpEffect.jumpCount < JumpEffect.maxJumps then
        if JumpEffect.jumpCount > 0 then
            pcall(function() hum.JumpPower = JumpEffect.baseJumpPower + JumpEffect.geppoboost end)
            if JumpEffect.emitter2 then
                pcall(function() JumpEffect.emitter2:Emit(6) end)
            end
        end
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
        JumpEffect.jumpCount = JumpEffect.jumpCount + 1
    end
end

local function JumpEffect_cleanup()
    if JumpEffect.stateConn then
        pcall(function() JumpEffect.stateConn:Disconnect() end)
        JumpEffect.stateConn = nil
    end
    if JumpEffect.charConn then
        pcall(function() JumpEffect.charConn:Disconnect() end)
        JumpEffect.charConn = nil
    end
    if JumpEffect.vfxAttachment then
        pcall(function() JumpEffect.vfxAttachment:Destroy() end)
        JumpEffect.vfxAttachment = nil
        JumpEffect.emitter2      = nil
    end
    JumpEffect.currentChar     = nil
    JumpEffect.currentHumanoid = nil
    JumpEffect.currentRootPart = nil
    JumpEffect.jumpCount       = 0
end

local NameTags = {}
local CheckpointLabels = {}
local CheckpointGui = nil
local originalProperties = {}
local originalGraphics = {}
local originalRenderSettings = {}
local antiLagConnections = {}
local antiLagCleanupList = {}

local currentAnimationTrack = nil
local currentPlayButton = nil
local currentEmote = nil
local isStuck = false
local originalWalkSpeed = 16
local originalJumpPower = 50

-- ================================================================
-- EMOTE SYSTEM — Load dari JSON URL
-- ================================================================
local EMOTE_JSON_URL = "https://raw.githubusercontent.com/kkkkkk-dev/ZeroExploits/main/emotes.json"
local EmoteList = {}
local _emoteListLoaded = false
local _emoteListCallbacks = {}

local function _onEmoteListReady(cb)
    if _emoteListLoaded then cb() return end
    table.insert(_emoteListCallbacks, cb)
end

local function _fireEmoteListReady()
    _emoteListLoaded = true
    for _, cb in ipairs(_emoteListCallbacks) do pcall(cb) end
    _emoteListCallbacks = {}
end

task.spawn(function()
    local ok, body = pcall(function() return game:HttpGet(EMOTE_JSON_URL) end)
    if ok and body and body ~= "" then
        local okD, data = pcall(function() return HttpService:JSONDecode(body) end)
        if okD and data then
            local list = (type(data) == "table" and (data.data or data)) or {}
            local seen = {}
            for _, emote in ipairs(list) do
                local id = tonumber(emote.id)
                local name = tostring(emote.name or "Unknown")
                if id and not seen[id] then
                    seen[id] = true
                    table.insert(EmoteList, {
                        n           = name,
                        id          = id,
                        imageId     = id,
                        price       = emote.price or 0,
                        creator     = tostring(emote.creatorName or "K6 ZERO FREE!"),
                        isAnimation = false,
                        fav         = false,
                    })
                end
            end
        end
    end
    if #EmoteList == 0 then
        EmoteList = {
            {n="Wave",  id=3576686446, imageId=3576686446, price=0, creator="K6 ZERO FREE!", isAnimation=false, fav=false},
            {n="Point", id=3576823880, imageId=3576823880, price=0, creator="K6 ZERO FREE!", isAnimation=false, fav=false},
            {n="Dance", id=3576720708, imageId=3576720708, price=0, creator="K6 ZERO FREE!", isAnimation=false, fav=false},
            {n="Laugh", id=3576777185, imageId=3576777185, price=0, creator="K6 ZERO FREE!", isAnimation=false, fav=false},
            {n="Cheer", id=3576738018, imageId=3576738018, price=0, creator="K6 ZERO FREE!", isAnimation=false, fav=false},
        }
    end
    _fireEmoteListReady()
end)

local _EMOTE_LIST_PLACEHOLDER = {
    {n = "Gojo Aura Farming",        id = 107769522062955,  imageId = 107769522062955,  price = 0, ugc = true, isAnimation = false, fav = false},
    {n = "Floating on Clouds",        id = 111426928948833,  imageId = 111426928948833,  price = 0, ugc = true, isAnimation = false, fav = false},
    {n = "Sukuna Aura Farming",       id = 134893423132417,  imageId = 134893423132417,  price = 0, ugc = true, isAnimation = false, fav = false},
    {n = "Snoops Walk",               id = 112458012124991,  imageId = 112458012124991,  price = 0, ugc = true, isAnimation = false, fav = false},
    {n = "Dance Moves",               id = 95481300223643,   imageId = 95481300223643,   price = 0, ugc = true, isAnimation = false, fav = false},
    {n = "Rat Dance",                 id = 98603994713783,   imageId = 98603994713783,   price = 0, ugc = true, isAnimation = false, fav = false},
    {n = "Flying",                    id = 84225416876286,   imageId = 84225416876286,   price = 0, ugc = true, isAnimation = false, fav = false},
    {n = "Headless Floating Aura",    id = 136521114251029,  imageId = 136521114251029,  price = 0, ugc = true, isAnimation = false, fav = false},
    {n = "Football Head",             id = 89585914807224,   imageId = 89585914807224,   price = 0, ugc = true, isAnimation = false, fav = false},
    {n = "Floating Pose",             id = 74401455185371,   imageId = 74401455185371,   price = 0, ugc = true, isAnimation = false, fav = false},
    {n = "Folks Drop Moves",          id = 108148450243742,  imageId = 108148450243742,  price = 0, ugc = true, isAnimation = false, fav = false},
    {n = "Jumpstyle Dance",           id = 133248139921782,  imageId = 133248139921782,  price = 0, ugc = true, isAnimation = false, fav = false},
    {n = "Lets Get Sturdy",           id = 119341017234649,  imageId = 119341017234649,  price = 0, ugc = true, isAnimation = false, fav = false},
    {n = "Rakai Dance",               id = 137080431878792,  imageId = 137080431878792,  price = 0, ugc = true, isAnimation = false, fav = false},
    {n = "Coboy Junior Dance",        id = 127330863527694,  imageId = 127330863527694,  price = 0, ugc = true, isAnimation = false, fav = false},
    {n = "Dancing with Eyes Closed",  id = 129637389787927,  imageId = 129637389787927,  price = 0, ugc = true, isAnimation = false, fav = false},
    {n = "Deltarune Tenna Dance",     id = 102492229412911,  imageId = 102492229412911,  price = 0, ugc = true,  isAnimation = false, fav = false},
    {n = "Peter Griffin Death Pose",  id = 120437019363089,  imageId = 120437019363089,  price = 0, ugc = true,  isAnimation = false, fav = false},
    {n = "TV Time Dance",             id = 75017857395637,   imageId = 75017857395637,   price = 0, ugc = true,  isAnimation = false, fav = false},
    {n = "Mates EMOTE [LIMITED]",     id = 113016438012253,  imageId = 113016438012253,  price = 0, ugc = true,  isAnimation = false, fav = false},
    {n = "MM2 Fake Dead",             id = 132384701706046,  imageId = 132384701706046,  price = 0, ugc = true,  isAnimation = false, fav = false},
    {n = "Floating Human Spinner",    id = 137873580964093,  imageId = 137873580964093,  price = 0, ugc = true,  isAnimation = false, fav = false},
    {n = "Parrot Party Dance",        id = 121067808279598,  imageId = 121067808279598,  price = 0, ugc = true,  isAnimation = false, fav = false},
    {n = "Spongebob Shuffle Dance",   id = 107899954696611,  imageId = 107899954696611,  price = 0, ugc = true,  isAnimation = false, fav = false},
    {n = "IShowSpeed Dance",          id = 109755476052324,  imageId = 109755476052324,  price = 0, ugc = true,  isAnimation = false, fav = false},
    {n = "Soda Pop Dance",            id = 91749862405391,   imageId = 91749862405391,   price = 0, ugc = true,  isAnimation = false, fav = false},
    {n = "Pardon Dance",              id = 71192545448542,   imageId = 71192545448542,   price = 0, ugc = true,  isAnimation = false, fav = false},
    {n = "Jackpot Dance",             id = 81005824258133,   imageId = 81005824258133,   price = 0, ugc = true,  isAnimation = false, fav = false},
    {n = "R6 Dance Potion",           id = 90334065717691,   imageId = 90334065717691,   price = 0, ugc = true,  isAnimation = false, fav = false},
    {n = "Classic Retro Jump",        id = 119095524735341,  imageId = 119095524735341,  price = 0, ugc = true,  isAnimation = false, fav = false},
    {n = "Infinite R6 Backflips",     id = 124970376117840,  imageId = 124970376117840,  price = 0, ugc = true,  isAnimation = false, fav = false},
    {n = "2013 Dance",                id = 110226648097430,  imageId = 110226648097430,  price = 0, ugc = true,  isAnimation = false, fav = false},
    {n = "Golden Freddy Glitch Emote",id = 122463450997235,  imageId = 122463450997235,  price = 0, ugc = true,  isAnimation = false, fav = false},
    {n = "Otsukare Summer",id = 71089529660336,  imageId = 71089529660336,   price = 0, ugc = true,  isAnimation = false, fav = false},
    {n = "Flying Head Glitch",        id = 99033587367752,   imageId = 99033587367752,   price = 0, ugc = true,  isAnimation = false, fav = false},
    {n = "Basketball Head Dribble",   id = 95938106134169,   imageId = 95938106134169,   price = 0, ugc = true,  isAnimation = false, fav = false},
    {n = "Slickback Dance",           id = 103789826265487,  imageId = 103789826265487,  price = 0, ugc = true,  isAnimation = false, fav = false},
    {n = "Crip Walk",                 id = 82345000649867,   imageId = 82345000649867,   price = 0, ugc = true,  isAnimation = false, fav = false},
}
-- placeholder tidak dipakai, EmoteList diisi oleh JSON loader di atas

local RANDOM_IDS = {978663613,5261700291,1846241644,4993456331,424866237,4312175249,176548116,2270483006,1387071394,2705922253,10115152913,254675749,5282085572,2819144629,2342272463,3877709773,3641789924,5023103942,2298753899,5022264302,66372478,1059023987,2530406197,1992137495,402058769,1208673935,1735121788,3236271187,4797655515,8820259986,1538346377,7081300715,1648676291,2818915354,263336582,1510381464,683993767,1033636351,4004052767,7709627778,5196381745,4983064295,937392108,974086214,6004535943,744532329,2216132529,797871247,442581442,7927897698,4344692203,113408119,4439685307,670917583,5158458988,373349,2994206407,596318021,2574010621,7757117305,1780106970,3872493784,382383327,1921058820,1817915221,2799348313,189511979}

local AC_CURRENT_AVATAR  = nil
local AC_ORIGINAL_DESC   = nil
local AC_FAVORITES       = {}
local AC_INPUT_BOX = nil
local ac_favDropFrame    = nil
local ac_favDropLayout   = nil
local ac_favDropBtn      = nil
local ac_favDropEmpty    = nil
local ac_favBtnToggle    = nil
local ac_favDropOpen     = false
local ac_statusLabel     = nil
local acc_statusLabel    = nil
local AC_UPDATEFAVBTN, AC_UPDATEFAVLIST, AC_SAVEFAVORITES, AC_APPLYAVATAR, AC_MORPHCHAR
local AC_TARGET_BOX = nil

local AC_ACCESSORY_SLOTS = {
    {label = "Head",  descProp = "HEAD_SPECIAL", isHeadChange = true},
    {label = "Hat",         descProp = "HatAccessory"},
    {label = "Hair",      descProp = "HairAccessory"},
    {label = "Face Accessory",    descProp = "FaceAccessory"},
    {label = "Neck",       descProp = "NeckAccessory"},
    {label = "Back",    descProp = "BackAccessory"},
    {label = "Waist",   descProp = "WaistAccessory"},
    {label = "Shoulder",    descProp = "ShouldersAccessory"},
    {label = "Front",      descProp = "FrontAccessory"},
}
local AC_ACCESSORY_APPLIED = {}
local AC_HEAD_APPLIED = nil
local AC_HEAD_ORIGINAL = nil
local AC_CLOTHES_APPLIED = {}
local AC_ANIM_PRESET_APPLIED = nil
local AC_ACCESSORY_TRANSFORMS = {}
local ACC_PRESETS = {}
local ACC_PRESET_FILE = "Zero Directory/acc_presets.json"
local acc_presetDropUpdate = nil

local clothes_statusLabel = nil

-- Ganti InsertService:LoadAsset() yang diblokir di client dengan game:GetObjects().
-- Mengembalikan "model" tiruan (punya :GetChildren() dan :Destroy()) supaya
-- semua kode yang sudah ada tetap bisa dipakai tanpa diubah strukturnya.
local function LoadAssetLocal(assetId)
    if not assetId or assetId == 0 then return nil end
    local ok, objs = pcall(function()
        return game:GetObjects("rbxassetid://" .. tostring(assetId))
    end)
    if not ok or not objs or #objs == 0 then
        return nil
    end
    local holder = Instance.new("Model")
    holder.Name = "LoadAssetLocal_" .. tostring(assetId)
    for _, o in ipairs(objs) do
        o.Parent = holder
    end
    return holder
end

-- Pasang Accessory ke karakter dengan Weld yang benar (client-only).
-- game:GetObjects() tidak otomatis bikin weld seperti InsertService:LoadAsset(),
-- jadi tanpa ini aksesoris akan lepas dan jatuh karena gravitasi.
local function AttachAccessoryLocal(char, accessory)
    if not char or not accessory then return false end
    if not (accessory:IsA("Accessory") or accessory:IsA("Hat")) then return false end

    local handle = accessory:FindFirstChild("Handle")
    if not handle then
        return false
    end

    -- Coba pakai AddAccessory bawaan dulu (biasanya sudah cukup untuk kebanyakan kasus).
    -- JANGAN set accessory.Parent dulu sebelum ini, karena AddAccessory sendiri yang
    -- akan parent accessory ke karakter -- kalau sudah di-parent duluan, Roblox
    -- menganggapnya "already being worn" dan menolak proses weld.
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        local ok, err = pcall(function() hum:AddAccessory(accessory) end)
        if ok then
            local weld = handle:FindFirstChildOfClass("Weld") or handle:FindFirstChild("AccessoryWeld")
            if weld then
                return true
            else
            end
        else
        end
    end

    -- Fallback: bikin weld manual dari pasangan Attachment (Handle <-> body part)
    accessory.Parent = char
    local handleAtt = handle:FindFirstChildOfClass("Attachment")
    if not handleAtt then
        return false
    end

    local targetAtt = nil
    local targetPart = nil
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            local att = part:FindFirstChild(handleAtt.Name)
            if att and att:IsA("Attachment") then
                targetAtt = att
                targetPart = part
                break
            end
        end
    end

    if targetAtt and targetPart then
        -- Hapus weld lama jika ada
        local oldWeld = handle:FindFirstChildOfClass("Weld") or handle:FindFirstChild("AccessoryWeld")
        if oldWeld then oldWeld:Destroy() end

        local weld = Instance.new("Weld")
        weld.Name = "AccessoryWeld"
        weld.Part0 = targetPart
        weld.Part1 = handle
        weld.C0 = targetAtt.CFrame
        weld.C1 = handleAtt.CFrame
        weld.Parent = handle

        handle.Anchored = false
        handle.CanCollide = false
        return true
    end

    return false
end

local function GetReal(id)
    if not id or id == 0 then return id end
    local ok, obj = pcall(function()
        return game:GetObjects("rbxassetid://" .. tostring(id))
    end)
    if ok and obj and #obj > 0 then
        local root = obj[1]
        if root then
            local function findAnim(o)
                if o:IsA("Animation") and o.AnimationId ~= "" then
                    local r = tonumber(o.AnimationId:match("%d+"))
                    if r then return r end
                end
                local ok2, children = pcall(function() return o:GetChildren() end)
                if ok2 and children then
                    for _, child in ipairs(children) do
                        local r = findAnim(child)
                        if r then return r end
                    end
                end
                return nil
            end
            local resolved = findAnim(root)
            if resolved then return resolved end
        end
    end
    local ok2, animObj = pcall(function()
        local a = Instance.new("Animation")
        a.AnimationId = "rbxassetid://" .. tostring(id)
        return a
    end)
    if ok2 and animObj then
        local r = tonumber(animObj.AnimationId:match("%d+"))
        if r and r ~= id then return r end
    end
    return id
end

local _posLockConnection = nil

local function startPositionLock(char, lockDuration)
    lockDuration = lockDuration or 2.0
    if _posLockConnection then
        pcall(function() _posLockConnection:Disconnect() end)
        _posLockConnection = nil
    end
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local savedCFrame = hrp.CFrame
    local elapsed = 0

    pcall(function() hrp.Anchored = true end)

    _posLockConnection = RunService.Heartbeat:Connect(function(dt)
        elapsed = elapsed + dt
        local currentHRP = char:FindFirstChild("HumanoidRootPart")
        if currentHRP and currentHRP.Parent then
            pcall(function() currentHRP.Anchored = true end)
            pcall(function() currentHRP.CFrame = savedCFrame end)
        end
        if elapsed >= lockDuration then
            if _posLockConnection then
                _posLockConnection:Disconnect()
                _posLockConnection = nil
            end
            local finalHRP = char:FindFirstChild("HumanoidRootPart")
            if finalHRP and finalHRP.Parent then
                pcall(function() finalHRP.Anchored = false end)
            end
        end
    end)
end

;(function()

local function stopCurrentAnimation()
    isStuck = false
    local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local tracks = humanoid:GetPlayingAnimationTracks()
        for _, track in ipairs(tracks) do
            pcall(function()
                track:Stop(0.1)
                task.delay(0.15, function()
                    pcall(function() track:Destroy() end)
                end)
            end)
        end
        humanoid.WalkSpeed = originalWalkSpeed
        humanoid.JumpPower = originalJumpPower
        humanoid.PlatformStand = false
        task.delay(0.25, function()
            if humanoid and humanoid.Parent and not isStuck then
                pcall(function()
                    humanoid:ChangeState(Enum.HumanoidStateType.Running)
                end)
            end
        end)
    end
    if currentAnimationTrack then
        pcall(function()
            currentAnimationTrack:Stop(0.1)
            task.delay(0.15, function()
                pcall(function() currentAnimationTrack:Destroy() end)
            end)
        end)
    end
    if currentPlayButton then
        currentPlayButton.Text = "Play"
        currentPlayButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end
    currentAnimationTrack = nil
    currentPlayButton = nil
    currentEmote = nil
end

local function playAnimation(emote, button)
    stopCurrentAnimation()
    local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    currentPlayButton = button
    currentEmote = emote
    originalWalkSpeed = humanoid.WalkSpeed
    originalJumpPower = humanoid.JumpPower

    for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
        pcall(function()
            track:Stop(0)
            track:Destroy()
        end)
    end

    local rawId = emote.id
    local resolvedId = rawId
    if tostring(rawId):len() >= 13 then
        resolvedId = GetReal(rawId)
    end

    local animation = Instance.new("Animation")
    animation.AnimationId = "rbxassetid://" .. tostring(resolvedId)
    local animator = humanoid:FindFirstChildOfClass("Animator")
        or Instance.new("Animator", humanoid)
    local ok, track = pcall(function() return animator:LoadAnimation(animation) end)
    if ok and track and typeof(track) ~= "boolean" then
        currentAnimationTrack = track
        currentAnimationTrack.Priority = Enum.AnimationPriority.Action
        currentAnimationTrack.Looped = true
        currentAnimationTrack:Play(0.2)

        if not emote.isAnimation then
            pcall(function()
                currentAnimationTrack.Stopped:Once(function()
                    if currentEmote == emote then
                        stopCurrentAnimation()
                    end
                end)
            end)
        end

        currentPlayButton.Text = "Stop"
        currentPlayButton.BackgroundColor3 = Color3.fromRGB(27, 100, 27)
    else
        stopCurrentAnimation()
    end
end

function noclip(state)
    NoclipEnabled = state
    local character = LocalPlayer.Character
    if not character then return end
    if state and not NoclipConnection then
        NoclipConnection = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if not char then return end
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    pcall(function() part.CanCollide = false end)
                end
            end
        end)
    elseif not state and NoclipConnection then
        NoclipConnection:Disconnect()
        NoclipConnection = nil
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                pcall(function() part.CanCollide = true end)
            end
        end
    end
end

function infinityJump(state)
    InfiniteJumpEnabled = state
    if state and not JumpConnection then
        local char = LocalPlayer.Character
        if char then JumpEffect_setupCharacter(char) end

        JumpEffect.charConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
            if InfiniteJumpEnabled then
                JumpEffect_setupCharacter(newChar)
            end
        end)

        JumpConnection = UserInputService.JumpRequest:Connect(function()
            if not InfiniteJumpEnabled then return end
            JumpEffect_doGeppo()
        end)
    elseif not state and JumpConnection then
        JumpConnection:Disconnect()
        JumpConnection = nil
        JumpEffect_cleanup()
    end
end

local function clearGodModeConnections()
    for _, conn in ipairs(GodModeConnections) do
        pcall(function() conn:Disconnect() end)
    end
    GodModeConnections = {}
    GodModeConnection = nil
end

local function setupGodMode(character)
    if not character then return end
    clearGodModeConnections()
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return end

    pcall(function() humanoid.MaxHealth = 1e9 end)
    pcall(function() humanoid.Health = 1e9 end)

    local conn1 = RunService.Heartbeat:Connect(function()
        if not GodModeEnabled then return end
        pcall(function()
            if humanoid and humanoid.Parent then
                if humanoid.Health < humanoid.MaxHealth * 0.9 then
                    humanoid.Health = humanoid.MaxHealth
                end
            end
        end)
    end)
    table.insert(GodModeConnections, conn1)

    local conn2 = humanoid.HealthChanged:Connect(function(newHealth)
        if not GodModeEnabled then return end
        pcall(function()
            if newHealth < humanoid.MaxHealth then humanoid.Health = humanoid.MaxHealth end
        end)
    end)
    table.insert(GodModeConnections, conn2)

    local conn3 = humanoid.StateChanged:Connect(function(old, new)
        if not GodModeEnabled then return end
        if new == Enum.HumanoidStateType.Dead then
            pcall(function()
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                humanoid.Health = humanoid.MaxHealth
            end)
        end
        if new == Enum.HumanoidStateType.Physics then
            pcall(function()
                task.wait(0.05)
                humanoid:ChangeState(Enum.HumanoidStateType.Running)
            end)
        end
    end)
    table.insert(GodModeConnections, conn3)

    local safeY = hrp.Position.Y
    local lastSafePos = hrp.CFrame
    local conn4 = RunService.Stepped:Connect(function()
        if not GodModeEnabled then return end
        pcall(function()
            if hrp and hrp.Parent then
                local posY = hrp.Position.Y
                if posY > -50 then
                    lastSafePos = hrp.CFrame
                    safeY = posY
                else
                    hrp.CFrame = lastSafePos + Vector3.new(0, 5, 0)
                    humanoid.Health = humanoid.MaxHealth
                end
            end
        end)
    end)
    table.insert(GodModeConnections, conn4)

    local ff = character:FindFirstChildOfClass("ForceField")
    if not ff then
        ff = Instance.new("ForceField")
        ff.Visible = false
        ff.Parent = character
    end

    pcall(function()
        local mt = getrawmetatable and getrawmetatable(humanoid)
        if mt then
            local oldIndex = mt.__index
            setreadonly(mt, false)
            mt.__index = function(self, key)
                if key == "TakeDamage" then return function() end end
                return oldIndex(self, key)
            end
            setreadonly(mt, true)
        end
    end)

    local conn5 = character.AncestryChanged:Connect(function(_, parent)
        if not GodModeEnabled then return end
        if not parent then
            pcall(function()
                task.wait(0.1)
                if LocalPlayer.Character ~= character then return end
                character.Parent = Workspace
            end)
        end
    end)
    table.insert(GodModeConnections, conn5)

    local conn6 = character.ChildAdded:Connect(function(child)
        if not GodModeEnabled then return end
        if child:IsA("Humanoid") then
            task.wait(0.1)
            setupGodMode(character)
        end
    end)
    table.insert(GodModeConnections, conn6)

    GodModeConnection = GodModeConnections
end

function godMode(state)
    GodModeEnabled = state
    if state then
        local character = LocalPlayer.Character
        if not character then return end
        setupGodMode(character)
    else
        clearGodModeConnections()
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChildOfClass("Humanoid")
            local ff = character:FindFirstChildOfClass("ForceField")
            if ff then ff:Destroy() end
            if humanoid then
                pcall(function() humanoid.MaxHealth = 100 end)
                pcall(function() humanoid.Health = humanoid.MaxHealth end)
            end
        end
    end
end

local flySpeed       = 60
local flyAccel       = 10
local flyPitchDeadZ  = 0.15
local flyAnalogDeadZ = 0.15
local currentFlyVelocity = Vector3.new(0, 0, 0)

function fly(state)
    FlyEnabled = state
    local character = LocalPlayer.Character
    if not character then return end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not hrp or not humanoid then return end

    if state then
        humanoid.PlatformStand = true
        currentFlyVelocity = Vector3.new(0, 0, 0)

        FlyBodyVelocity = Instance.new("BodyVelocity")
        FlyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
        FlyBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        FlyBodyVelocity.P = 1e4
        FlyBodyVelocity.Parent = hrp

        FlyBodyGyro = Instance.new("BodyGyro")
        FlyBodyGyro.MaxTorque = Vector3.new(0, 9e8, 0)
        FlyBodyGyro.P = 8e4
        FlyBodyGyro.D = 2e3
        FlyBodyGyro.CFrame = hrp.CFrame
        FlyBodyGyro.Parent = hrp

        FlyConnection = RunService.Heartbeat:Connect(function(dt)
            if not FlyEnabled then return end
            pcall(function()
                if not hrp or not hrp.Parent then return end

                local camera  = Workspace.CurrentCamera
                local camCF   = camera.CFrame
                local camLook = camCF.LookVector
                local camRight= camCF.RightVector

                local camFlat = Vector3.new(camLook.X, 0, camLook.Z)
                if camFlat.Magnitude > 0.01 then camFlat = camFlat.Unit end
                local camRightFlat = Vector3.new(camRight.X, 0, camRight.Z)
                if camRightFlat.Magnitude > 0.01 then camRightFlat = camRightFlat.Unit end

                local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
                local targetVelocity = Vector3.new(0, 0, 0)
                local facingDir = nil

                local anyKeyDown = UserInputService:IsKeyDown(Enum.KeyCode.W)
                    or UserInputService:IsKeyDown(Enum.KeyCode.A)
                    or UserInputService:IsKeyDown(Enum.KeyCode.S)
                    or UserInputService:IsKeyDown(Enum.KeyCode.D)
                    or UserInputService:IsKeyDown(Enum.KeyCode.Space)
                    or UserInputService:IsKeyDown(Enum.KeyCode.Q)
                    or UserInputService:IsKeyDown(Enum.KeyCode.E)
                    or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
                if anyKeyDown then isMobile = false end

                if isMobile then
                    local moveVec = humanoid.MoveDirection
                    local analogMag = Vector2.new(moveVec.X, moveVec.Z).Magnitude
                    if analogMag > flyAnalogDeadZ then
                        local fwd   = camFlat:Dot(moveVec)
                        local right = camRightFlat:Dot(moveVec)
                        local horizVel = (camFlat * fwd + camRightFlat * right)
                        if horizVel.Magnitude > 0.01 then
                            horizVel = horizVel.Unit * flySpeed * math.min(analogMag, 1)
                        end
                        local pitchAbs = math.abs(camLook.Y)
                        local vertVel  = 0
                        if pitchAbs > flyPitchDeadZ then
                            local pitchFactor = (pitchAbs - flyPitchDeadZ) / (1 - flyPitchDeadZ)
                            vertVel = camLook.Y * pitchFactor * flySpeed * math.max(fwd, 0)
                            local horizScale = math.sqrt(math.max(1 - pitchFactor * pitchFactor, 0))
                            horizVel = horizVel * horizScale
                        end
                        targetVelocity = Vector3.new(horizVel.X, vertVel, horizVel.Z)
                        facingDir = camFlat
                    end
                else
                    local kbDir = Vector3.new(0, 0, 0)
                    if UserInputService:IsKeyDown(Enum.KeyCode.W) then kbDir = kbDir + camFlat end
                    if UserInputService:IsKeyDown(Enum.KeyCode.S) then kbDir = kbDir - camFlat end
                    if UserInputService:IsKeyDown(Enum.KeyCode.A) then kbDir = kbDir - camRightFlat end
                    if UserInputService:IsKeyDown(Enum.KeyCode.D) then kbDir = kbDir + camRightFlat end
                    local vertDir = 0
                    if UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then
                        vertDir = 1
                    elseif UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl) or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.E) then
                        vertDir = -1
                    end
                    local horizVel = Vector3.new(0, 0, 0)
                    if kbDir.Magnitude > 0.01 then
                        horizVel = kbDir.Unit * flySpeed
                        facingDir = Vector3.new(kbDir.X, 0, kbDir.Z)
                    end
                    targetVelocity = Vector3.new(horizVel.X, vertDir * flySpeed, horizVel.Z)
                end

                local alpha = math.min(dt * flyAccel, 1)
                currentFlyVelocity = currentFlyVelocity:Lerp(targetVelocity, alpha)
                FlyBodyVelocity.Velocity = currentFlyVelocity

                if facingDir and facingDir.Magnitude > 0.1 then
                    local flatFacing = Vector3.new(facingDir.X, 0, facingDir.Z)
                    if flatFacing.Magnitude > 0.01 then
                        FlyBodyGyro.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + flatFacing.Unit)
                    end
                end
            end)
        end)
    else
        if FlyConnection then FlyConnection:Disconnect(); FlyConnection = nil end
        if FlyBodyVelocity then FlyBodyVelocity:Destroy(); FlyBodyVelocity = nil end
        if FlyBodyGyro then FlyBodyGyro:Destroy(); FlyBodyGyro = nil end
        currentFlyVelocity = Vector3.new(0, 0, 0)
        if humanoid then humanoid.PlatformStand = false end
    end
end

function antiKick(state)
    AntiKickEnabled = state

    if AntiKickConnection then
        AntiKickConnection:Disconnect()
        AntiKickConnection = nil
    end

    if not state then return end

    local previousPosition = nil

    AntiKickConnection = RunService.Stepped:Connect(function()
        if not AntiKickEnabled then return end

        local char = LocalPlayer.Character
        if not char then previousPosition = nil; return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not hrp or not humanoid then previousPosition = nil; return end

        local currentPosition = hrp.CFrame

        if previousPosition and (currentPosition.Position - previousPosition.Position).Magnitude > 500 then
            pcall(function() hrp.CFrame = previousPosition end)
        else
            previousPosition = currentPosition
        end

        if char.Parent ~= Workspace then
            pcall(function() char.Parent = Workspace end)
        end

        if humanoid.Health < 1 then
            pcall(function() humanoid.Health = 1 end)
        end
    end)
end

local UIS = game:GetService("UserInputService")

local ESP_Color = Color3.fromRGB(255, 255, 255)
local NameDisplayMode = "Both"
local SelectedTargets = {}

local espUpdateConnection = nil
local espCharConnections = {}
local espHeartbeatConnections = {}

local function cleanupAllESP()
    for userId, conn in pairs(espHeartbeatConnections) do
        pcall(function() conn:Disconnect() end)
    end
    espHeartbeatConnections = {}
    for _, conn in pairs(espCharConnections) do
        pcall(function() conn:Disconnect() end)
    end
    espCharConnections = {}
    if espUpdateConnection then espUpdateConnection:Disconnect(); espUpdateConnection = nil end
    if NameEspConnection then NameEspConnection:Disconnect(); NameEspConnection = nil end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            if char:FindFirstChild("KilasikESP") then char.KilasikESP:Destroy() end
            if char:FindFirstChild("KilasikName") then char.KilasikName:Destroy() end
        end
    end
    NameTags = {}
end

local function createNameTag(p)
    if not NameEspEnabled then return end
    if p == LocalPlayer then return end
    local function Setup(char)
        if not char then return end

        if char:FindFirstChild("KilasikESP") then char.KilasikESP:Destroy() end
        if char:FindFirstChild("KilasikName") then char.KilasikName:Destroy() end

        local Highlight = Instance.new("Highlight")
        Highlight.Name = "KilasikESP"
        Highlight.Adornee = char
        Highlight.FillTransparency = 0.5
        Highlight.OutlineTransparency = 0
        Highlight.FillColor = ESP_Color
        Highlight.OutlineColor = ESP_Color
        Highlight.Parent = char

        local Bill = Instance.new("BillboardGui")
        Bill.Name = "KilasikName"
        Bill.AlwaysOnTop = true
        Bill.Size = UDim2.new(0, 120, 0, 40)
        Bill.ExtentsOffset = Vector3.new(0, 2.8, 0)
        Bill.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
        Bill.LightInfluence = 0
        Bill.ResetOnSpawn = false
        Bill.Parent = char

        local BG = Instance.new("Frame")
        BG.Name = "Background"
        BG.Size = UDim2.new(1, 0, 1, 0)
        BG.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        BG.BackgroundTransparency = 0.5
        BG.BorderSizePixel = 0
        BG.Parent = Bill
        local BGCorner = Instance.new("UICorner", BG)
        BGCorner.CornerRadius = UDim.new(0, 5)

        local Label = Instance.new("TextLabel")
        Label.Name = "NameLabel"
        Label.Size = UDim2.new(1, -6, 0, 18)
        Label.Position = UDim2.new(0, 3, 0, 3)
        Label.BackgroundTransparency = 1
        Label.Font = Enum.Font.GothamBold
        Label.TextSize = 11
        Label.TextColor3 = Color3.fromRGB(255, 255, 255)
        Label.TextXAlignment = Enum.TextXAlignment.Center
        Label.TextTruncate = Enum.TextTruncate.AtEnd
        Label.RichText = true
        Label.ZIndex = 4
        Label.Parent = BG
        local LabelStroke = Instance.new("UIStroke", Label)
        LabelStroke.Thickness = 1
        LabelStroke.Color = Color3.fromRGB(0, 0, 0)
        LabelStroke.Transparency = 0.2

        local SubLabel = Instance.new("TextLabel")
        SubLabel.Name = "SubLabel"
        SubLabel.Size = UDim2.new(1, -6, 0, 12)
        SubLabel.Position = UDim2.new(0, 3, 0, 22)
        SubLabel.BackgroundTransparency = 1
        SubLabel.Font = Enum.Font.Gotham
        SubLabel.TextSize = 9
        SubLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        SubLabel.TextXAlignment = Enum.TextXAlignment.Center
        SubLabel.TextTruncate = Enum.TextTruncate.AtEnd
        SubLabel.RichText = true
        SubLabel.ZIndex = 4
        SubLabel.Parent = BG

        local HpBG = Instance.new("Frame")
        HpBG.Name = "HpBG"
        HpBG.Size = UDim2.new(1, -10, 0, 3)
        HpBG.Position = UDim2.new(0, 5, 1, -5)
        HpBG.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        HpBG.BackgroundTransparency = 0.3
        HpBG.BorderSizePixel = 0
        HpBG.ZIndex = 4
        HpBG.Parent = BG
        local HpBGCorner = Instance.new("UICorner", HpBG)
        HpBGCorner.CornerRadius = UDim.new(1, 0)

        local HpFill = Instance.new("Frame")
        HpFill.Name = "HpFill"
        HpFill.Size = UDim2.new(1, 0, 1, 0)
        HpFill.BackgroundColor3 = Color3.fromRGB(80, 220, 100)
        HpFill.BorderSizePixel = 0
        HpFill.ZIndex = 5
        HpFill.Parent = HpBG
        local HpFillCorner = Instance.new("UICorner", HpFill)
        HpFillCorner.CornerRadius = UDim.new(1, 0)

        local hbConn = RunService.Heartbeat:Connect(function()
            if not NameEspEnabled then return end
            if not p or not p.Parent then return end

            local localChar = LocalPlayer.Character
            local localRoot = localChar and localChar:FindFirstChild("HumanoidRootPart")
            local targetRoot = char and char:FindFirstChild("HumanoidRootPart")
            local distText = ""
            if localRoot and targetRoot then
                local dist = math.floor((localRoot.Position - targetRoot.Position).Magnitude)
                distText = " <font color='#AAAACC'>[" .. dist .. "m]</font>"
            end

            if NameDisplayMode == "Both" then
                Label.Text = "<b>" .. p.DisplayName .. "</b>"
                SubLabel.Text = "<font color='#8888BB'>@" .. p.Name .. "</font>" .. distText
            elseif NameDisplayMode == "Display" then
                Label.Text = "<b>" .. p.DisplayName .. "</b>"
                SubLabel.Text = distText ~= "" and distText or ""
            else
                Label.Text = "<b>@" .. p.Name .. "</b>"
                SubLabel.Text = distText ~= "" and distText or ""
            end

            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and HpFill and HpFill.Parent then
                local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                HpFill.Size = UDim2.new(ratio, 0, 1, 0)
                if ratio > 0.6 then
                    HpFill.BackgroundColor3 = Color3.fromRGB(80, 220, 100)
                elseif ratio > 0.3 then
                    HpFill.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
                else
                    HpFill.BackgroundColor3 = Color3.fromRGB(230, 60, 60)
                end
            end
        end)
        if espHeartbeatConnections[p.UserId] then
            pcall(function() espHeartbeatConnections[p.UserId]:Disconnect() end)
        end
        espHeartbeatConnections[p.UserId] = hbConn

        NameTags[p.UserId] = { highlight = Highlight, label = Label }
    end

    if p.Character then Setup(p.Character) end
    local charConn = p.CharacterAdded:Connect(function(newChar)
        if not NameEspEnabled then return end
        task.wait(0.15)
        Setup(newChar)
    end)
    if espCharConnections[p.UserId] then
        pcall(function() espCharConnections[p.UserId]:Disconnect() end)
    end
    espCharConnections[p.UserId] = charConn
end

function nameEsp(state)
    NameEspEnabled = state
    if not state then cleanupAllESP() return end

    for _, player in ipairs(Players:GetPlayers()) do
        createNameTag(player)
    end

    NameEspConnection = Players.PlayerAdded:Connect(function(player)
        if not NameEspEnabled then return end
        createNameTag(player)
    end)

    local playerRemovedConn = Players.PlayerRemoving:Connect(function(player)
        if espHeartbeatConnections[player.UserId] then
            pcall(function() espHeartbeatConnections[player.UserId]:Disconnect() end)
            espHeartbeatConnections[player.UserId] = nil
        end
        if espCharConnections[player.UserId] then
            pcall(function() espCharConnections[player.UserId]:Disconnect() end)
            espCharConnections[player.UserId] = nil
        end
        NameTags[player.UserId] = nil
    end)
    espCharConnections["__playerRemoving"] = playerRemovedConn

    espUpdateConnection = RunService.RenderStepped:Connect(function()
        if not NameEspEnabled then return end
        local mouseLoc = UIS:GetMouseLocation()
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local highlight = p.Character:FindFirstChild("KilasikESP")
                if highlight then
                    local root = p.Character:FindFirstChild("HumanoidRootPart")
                    if root then
                        local pos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(root.Position)
                        local isHovered = onScreen and (Vector2.new(pos.X, pos.Y) - mouseLoc).Magnitude < 50
                        local bill = p.Character:FindFirstChild("KilasikName")
                        local accentBar = bill and bill:FindFirstChild("Background") and bill.Background:FindFirstChild("AccentBar")
                        local bgStroke = bill and bill:FindFirstChild("Background") and bill.Background:FindFirstChildOfClass("UIStroke")
                        if SelectedTargets[p.Name] then
                            highlight.OutlineColor = Color3.fromRGB(220, 50, 50)
                            highlight.FillColor    = Color3.fromRGB(220, 50, 50)
                            if accentBar then accentBar.BackgroundColor3 = Color3.fromRGB(255, 60, 60) end
                            if bgStroke  then bgStroke.Color = Color3.fromRGB(255, 60, 60); bgStroke.Transparency = 0.1 end
                        elseif isHovered then
                            highlight.OutlineColor = Color3.fromRGB(255, 160, 30)
                            highlight.FillColor    = Color3.fromRGB(255, 160, 30)
                            if accentBar then accentBar.BackgroundColor3 = Color3.fromRGB(255, 180, 40) end
                            if bgStroke  then bgStroke.Color = Color3.fromRGB(255, 180, 40); bgStroke.Transparency = 0.2 end
                        else
                            highlight.OutlineColor = ESP_Color
                            highlight.FillColor    = ESP_Color
                            if accentBar then accentBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255) end
                            if bgStroke  then bgStroke.Color = Color3.fromRGB(255, 255, 255); bgStroke.Transparency = 0.4 end
                        end
                    end
                end
            end
        end
    end)
end

local invis_transparency     = 0.75
local invis_on               = false
local invis_seatTeleportPos  = Vector3.new(-25.95, 400, 3537.55)
local invis_voidThreshold    = -50
local invis_seatHeartbeat    = nil
local invis_ghost_speed      = false
local invis_walkspeed_boost  = false
local invis_generic_speed    = 16

local function setCharacterTransparency(transparency)
    local character = LocalPlayer.Character
    if character then
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Transparency = transparency
            end
        end
    end
end

local function stopInvisSeatHeartbeat()
    if invis_seatHeartbeat then
        invis_seatHeartbeat:Disconnect()
        invis_seatHeartbeat = nil
    end
end

local function cleanupInvisSeat()
    stopInvisSeatHeartbeat()
    local seat = Workspace:FindFirstChild("invischair")
    if seat then pcall(function() seat:Destroy() end) end
    local box = Workspace:FindFirstChild("InvisBoxMethod2")
    if box then pcall(function() box:Destroy() end) end
end

function invisible(state)
    InvisibleEnabled = state

    if InvisibleConnection then
        InvisibleConnection:Disconnect()
        InvisibleConnection = nil
    end
    if InvisibleRenderConn then
        InvisibleRenderConn:Disconnect()
        InvisibleRenderConn = nil
    end

    local character = LocalPlayer.Character
    if not character then return end

    if state then
        invis_on = true
        setCharacterTransparency(invis_transparency)

        task.spawn(function()
            local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
            if not humanoidRootPart then return end
            local humanoid = character:WaitForChild("Humanoid", 5)
            if not humanoid then return end
            local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
            if not torso then
                torso = character:WaitForChild("UpperTorso", 3) or character:WaitForChild("Torso", 3)
            end
            local deadline = tick() + 5
            while humanoid.Health <= 0 and tick() < deadline do task.wait(0.05) end
            if not InvisibleEnabled then return end

            local savedpos = humanoidRootPart.CFrame
            task.wait(0.1)
            pcall(function() character:MoveTo(invis_seatTeleportPos) end)
            task.wait(0.1)
            if not character:FindFirstChild("HumanoidRootPart")
                or character.HumanoidRootPart.Position.Y < invis_voidThreshold then
                pcall(function() character:MoveTo(savedpos.Position) end)
                invis_on = false
                InvisibleEnabled = false
                setCharacterTransparency(0)
                return
            end
            local oldSeat = Workspace:FindFirstChild("invischair")
            if oldSeat then pcall(function() oldSeat:Destroy() end) end
            local Seat = Instance.new("Seat")
            Seat.Parent      = Workspace
            Seat.Anchored    = false
            Seat.CanCollide  = false
            Seat.Name        = "invischair"
            Seat.Transparency = 1
            Seat.Position    = invis_seatTeleportPos
            local Weld   = Instance.new("Weld")
            Weld.Part0   = Seat
            if torso then
                Weld.Part1  = torso
                Weld.Parent = Seat
                task.wait()
                pcall(function() Seat.CFrame = savedpos end)
            else
                Seat:Destroy()
            end
        end)

        InvisibleRenderConn = RunService.RenderStepped:Connect(function()
            if not InvisibleEnabled then return end
            local char = LocalPlayer.Character
            if not char then return end
            for _, part in pairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                    if part.Transparency ~= invis_transparency then
                        pcall(function() part.Transparency = invis_transparency end)
                    end
                end
            end
        end)

        InvisibleConnection = LocalPlayer.CharacterAdded:Connect(function(newChar)
            if not InvisibleEnabled then return end
            task.wait(0.1)
            invisible(true)
        end)

    else
        invis_on = false
        setCharacterTransparency(0)
        cleanupInvisSeat()
    end
end

local function applyWalkSpeed(character, speed)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.WalkSpeed = speed end
end

local antiPauseConn = nil
local function startAntiPause()
    if antiPauseConn then antiPauseConn:Disconnect() end
    antiPauseConn = RunService.Heartbeat:Connect(function()
        if currentWalkSpeed <= 16 then return end
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed ~= currentWalkSpeed then
            hum.WalkSpeed = currentWalkSpeed
        end
    end)
end
startAntiPause()

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.5)
    startAntiPause()
end)

local function setupSpeedEffect()
    if SpeedEffect.enabled then return end
    SpeedEffect.enabled = true

    local character = LocalPlayer.Character
    if not character then return end
    local cam = Workspace.CurrentCamera
    local Debris = game:GetService("Debris")
    local ld = game:GetService("Lighting")

    local Part_upvr = Instance.new("Part")
    Part_upvr.Transparency = 1
    Part_upvr.Anchored = true
    Part_upvr.CanCollide = false
    Part_upvr.Massless = true
    Part_upvr.Size = Vector3.new(0, 0, 0)
    Part_upvr.Parent = Workspace
    SpeedEffect.Part_upvr = Part_upvr

    local wndPart = Instance.new("Part")
    wndPart.Transparency = 1
    wndPart.Anchored = true
    wndPart.CanCollide = false
    wndPart.Massless = true
    wndPart.Size = Vector3.new(1, 1, 1)
    wndPart.Parent = Workspace
    SpeedEffect.wndPart = wndPart

    local wndAttachment = Instance.new("Attachment", wndPart)
    wndAttachment.Name = "Attachment"
    SpeedEffect.wndAttachment = wndAttachment

    local function makeWind(name, emissionDir, lifetimeMin, lifetimeMax, rate, rotSpeedMin, rotSpeedMax, rotMin, rotMax, speedMin, speedMax, spreadAngle, acceleration, drag, sizeSeq, squashSeq, transparencySeq)
        local e = Instance.new("ParticleEmitter")
        e.Brightness = 7
        e.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.new(1,1,1))})
        e.LightEmission = 0.5; e.LightInfluence = 1
        e.Orientation = Enum.ParticleOrientation.VelocityParallel
        e.Size = sizeSeq; e.Squash = squashSeq
        e.Texture = "rbxassetid://4770542473"
        e.Transparency = transparencySeq; e.ZOffset = 0
        e.EmissionDirection = emissionDir; e.Enabled = false
        e.Lifetime = NumberRange.new(lifetimeMin, lifetimeMax)
        e.Rate = rate; e.RotSpeed = NumberRange.new(rotSpeedMin, rotSpeedMax)
        e.Rotation = NumberRange.new(rotMin, rotMax)
        e.Speed = NumberRange.new(speedMin, speedMax)
        e.SpreadAngle = spreadAngle; e.TimeScale = 1
        e.Acceleration = acceleration; e.Drag = drag
        e.VelocityInheritance = 0; e.WindAffectsDrag = false
        e.Shape = Enum.ParticleEmitterShape.Box
        e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
        e.ShapePartial = 1; e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
        e.FlipbookFramerate = NumberRange.new(1,1)
        e.FlipbookLayout = Enum.ParticleFlipbookLayout.None
        e.FlipbookMode = Enum.ParticleFlipbookMode.Loop
        e.FlipbookStartRandom = false; e.LockedToPart = true
        e.Name = name; e.Parent = wndAttachment
    end

    makeWind("Wind1", Enum.NormalId.Top, 0.25, 0.5, 250, -50, 50, -180, 180, 50, 200,
        Vector2.new(0,500), Vector3.new(0,0,500), 5,
        NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,10,0)}),
        NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),
        NumberSequence.new({NumberSequenceKeypoint.new(0,1,0),NumberSequenceKeypoint.new(0.2,0.913,0),NumberSequenceKeypoint.new(1,1,0)}))
    makeWind("Wind2", Enum.NormalId.Top, 0.25, 0.5, 250, 0, 0, -90, -90, 50, 200,
        Vector2.new(0,500), Vector3.new(0,0,500), 5,
        NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,3,1.812)}),
        NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,3,0)}),
        NumberSequence.new({NumberSequenceKeypoint.new(0,1,0),NumberSequenceKeypoint.new(0.2,0.85,0),NumberSequenceKeypoint.new(1,1,0)}))
    makeWind("Wind3", Enum.NormalId.Back, 0.5, 1, 150, -50, 50, -180, 180, 30, 100,
        Vector2.new(50,50), Vector3.new(0,0,100), 0,
        NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,10,0)}),
        NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),
        NumberSequence.new({NumberSequenceKeypoint.new(0,1,0),NumberSequenceKeypoint.new(0.2,0.813,0),NumberSequenceKeypoint.new(1,1,0)}))

    local isR15 = character:FindFirstChild("UpperTorso") ~= nil
    local R15 = {"Head","LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand","LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"}
    local R6 = {"Head","Left Arm","Right Arm","Left Leg","Right Leg"}
    local bodyPartNames = isR15 and R15 or R6
    SpeedEffect.bodyParticles = {}

    local function addBodyParticle(part, name, emitDir, lifetime, rate, speed, spreadAngle, acceleration, drag, sizeSeq, squashSeq, transparencySeq)
        local e = Instance.new("ParticleEmitter")
        e.Brightness = 7
        e.Color = ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.new(1,1,1)),ColorSequenceKeypoint.new(1,Color3.new(1,1,1))})
        e.LightEmission = 0.5; e.LightInfluence = 1
        e.Orientation = Enum.ParticleOrientation.VelocityParallel
        e.Size = sizeSeq; e.Squash = squashSeq
        e.Texture = "rbxassetid://4770542473"
        e.Transparency = transparencySeq; e.ZOffset = 0
        e.EmissionDirection = emitDir; e.Enabled = false
        e.Lifetime = NumberRange.new(lifetime[1], lifetime[2])
        e.Rate = rate; e.RotSpeed = NumberRange.new(speed[3] or -50, speed[4] or 50)
        e.Rotation = NumberRange.new(speed[5] or -180, speed[6] or 180)
        e.Speed = NumberRange.new(speed[1], speed[2])
        e.SpreadAngle = spreadAngle; e.TimeScale = 1
        e.Acceleration = acceleration; e.Drag = drag
        e.VelocityInheritance = 0; e.WindAffectsDrag = false
        e.Shape = Enum.ParticleEmitterShape.Box
        e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
        e.ShapePartial = 1; e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
        e.FlipbookFramerate = NumberRange.new(1,1)
        e.FlipbookLayout = Enum.ParticleFlipbookLayout.None
        e.FlipbookMode = Enum.ParticleFlipbookMode.Loop
        e.FlipbookStartRandom = false; e.LockedToPart = true
        e.Name = name; e.Parent = part
        table.insert(SpeedEffect.bodyParticles, e)
    end

    for _, partName in ipairs(bodyPartNames) do
        local part = character:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            addBodyParticle(part, "SpeedWind1", Enum.NormalId.Top, {0.25,0.5}, 250, {50,200,-50,50,-180,180},
                Vector2.new(0,500), Vector3.new(0,0,500), 5,
                NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,10,0)}),
                NumberSequence.new({NumberSequenceKeypoint.new(0,0,0),NumberSequenceKeypoint.new(1,0,0)}),
                NumberSequence.new({NumberSequenceKeypoint.new(0,1,0),NumberSequenceKeypoint.new(0.2,0.913,0),NumberSequenceKeypoint.new(1,1,0)}))
        end
    end

    local function enableDarkAura()
        if SpeedEffect.darkAuraActive then return end
        SpeedEffect.darkAuraActive = true
        local charDA = LocalPlayer.Character
        if not charDA then return end
        for _, x in next, charDA:GetDescendants() do
            if x:IsA("BasePart") then
                local e = Instance.new("ParticleEmitter")
                e.Parent = x
                e.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.new(0, 0, 0)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(10, 10, 10)),
                    ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0))
                })
                e.Brightness = 3
                e.LightEmission = 0.6
                e.LightInfluence = 0
                e.Size = NumberSequence.new{
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(0.3, 1.4),
                    NumberSequenceKeypoint.new(0.7, 1.0),
                    NumberSequenceKeypoint.new(1, 0)
                }
                e.RotSpeed = NumberRange.new(-30, 30)
                e.Rotation = NumberRange.new(0, 360)
                e.Texture = "rbxassetid://9731596776"
                e.Transparency = NumberSequence.new{
                    NumberSequenceKeypoint.new(0, 0.1),
                    NumberSequenceKeypoint.new(0.5, 0.4),
                    NumberSequenceKeypoint.new(1, 1)
                }
                e.ZOffset = 1.5
                e.EmissionDirection = Enum.NormalId.Top
                e.Lifetime = NumberRange.new(0.2, 0.45)
                e.Rate = 600
                e.Speed = NumberRange.new(2, 8)
                e.SpreadAngle = Vector2.new(40, 40)
                e.Shape = Enum.ParticleEmitterShape.Box
                e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
                e.ShapePartial = 1
                e.TimeScale = 1
                e.Enabled = true
                table.insert(SpeedEffect.darkAuraEmitters, e)
            end
        end

        SpeedEffect.auraUpdateConn = RunService.Heartbeat:Connect(function()
            if not SpeedEffect.darkAuraActive then return end
            local charU = LocalPlayer.Character
            local hrpU = charU and charU:FindFirstChild("HumanoidRootPart")
            if not hrpU then return end
            local isRunning = hrpU.Velocity.Magnitude > 8
            local targetRate = isRunning and 900 or 350
            local targetSpeed = isRunning and NumberRange.new(5, 18) or NumberRange.new(1, 5)
            local targetSize = isRunning and NumberSequence.new{
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.3, 2.2),
                NumberSequenceKeypoint.new(0.7, 1.6),
                NumberSequenceKeypoint.new(1, 0)
            } or NumberSequence.new{
                NumberSequenceKeypoint.new(0, 0),
                NumberSequenceKeypoint.new(0.3, 1.4),
                NumberSequenceKeypoint.new(0.7, 1.0),
                NumberSequenceKeypoint.new(1, 0)
            }
            for _, e in next, SpeedEffect.darkAuraEmitters do
                if e and e.Parent then
                    pcall(function()
                        e.Rate = targetRate
                        e.Speed = targetSpeed
                        e.Size = targetSize
                    end)
                end
            end
        end)
    end

    local function disableDarkAura()
        if not SpeedEffect.darkAuraActive then return end
        SpeedEffect.darkAuraActive = false
        if SpeedEffect.auraUpdateConn then
            SpeedEffect.auraUpdateConn:Disconnect()
            SpeedEffect.auraUpdateConn = nil
        end
        for _, e in next, SpeedEffect.darkAuraEmitters do
            if e and e.Parent then pcall(function() e:Destroy() end) end
        end
        SpeedEffect.darkAuraEmitters = {}
    end

    local flickerPartNames = isR15 and {
        "LeftUpperArm","LeftLowerArm","LeftHand","RightUpperArm","RightLowerArm","RightHand",
        "LeftUpperLeg","LeftLowerLeg","LeftFoot","RightUpperLeg","RightLowerLeg","RightFoot"
    } or {"Left Arm","Right Arm","Left Leg","Right Leg"}

    SpeedEffect.flickerTrails = {}

    local function createFlickerTrail(part)
        if not part or not part.Parent then return end
        local a0 = Instance.new("Attachment", part)
        a0.Position = Vector3.new(0, 0.5, 0); a0.Visible = false
        local a1 = Instance.new("Attachment", part)
        a1.Position = Vector3.new(0, -0.5, 0); a1.Visible = false
        local t = Instance.new("Trail")
        t.Attachment0 = a0; t.Attachment1 = a1
        t.Texture = "rbxassetid://16607923"
        t.TextureLength = 3
        t.TextureMode = Enum.TextureMode.Static
        t.FaceCamera = true
        t.LightEmission = 1
        t.Lifetime = 0.15
        t.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 200, 200)),
            ColorSequenceKeypoint.new(0.2, Color3.fromRGB(30, 30, 30)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
        })
        t.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.4, 0.2),
            NumberSequenceKeypoint.new(1, 1)
        })
        t.WidthScale = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.6, 0.5),
            NumberSequenceKeypoint.new(1, 0)
        })
        t.Enabled = false
        t.Parent = part
        table.insert(SpeedEffect.flickerTrails, {trail = t, a0 = a0, a1 = a1})
    end

    for _, pName in ipairs(flickerPartNames) do
        local p = character:FindFirstChild(pName)
        if p then createFlickerTrail(p) end
    end

    local function startFlicker()
        if SpeedEffect.flickerActive then return end
        SpeedEffect.flickerActive = true
        SpeedEffect.flickerThread = task.spawn(function()
            local tickF = 0
            while SpeedEffect.flickerActive do
                tickF = tickF + 1
                local spd = currentWalkSpeed or 16
                local intensity = math.clamp(spd / 200, 0.2, 1.0)

                local charF = LocalPlayer.Character
                local hrpF = charF and charF:FindFirstChild("HumanoidRootPart")
                local isRunning = hrpF and hrpF.Velocity.Magnitude > 8 or false

                local lifetimeMin = isRunning and 0.25 or 0.04
                local lifetimeMax = isRunning and 0.55 or 0.22
                local enableChance = isRunning and (intensity * 1.4) or (intensity * 0.7)

                for idx, entry in ipairs(SpeedEffect.flickerTrails) do
                    local t = entry.trail
                    if t and t.Parent then
                        t.Lifetime = isRunning
                            and math.random(math.floor(lifetimeMin*100), math.floor(lifetimeMax*100)) / 100
                            or 0.15

                        local sine = math.sin(tickF * 0.4 + idx * 0.9) * 0.25 + 0.75
                        local rand = math.random()
                        if rand < enableChance * sine then
                            t.Enabled = true
                        elseif rand < (isRunning and 0.04 or 0.08) * intensity then
                            t.Enabled = false
                        end
                    end
                end
                task.wait(isRunning and math.random(1, 3) / 100 or math.random(2, 5) / 100)
            end
        end)
    end

    local function stopFlicker()
        SpeedEffect.flickerActive = false
        if SpeedEffect.flickerThread then
            task.cancel(SpeedEffect.flickerThread)
            SpeedEffect.flickerThread = nil
        end
        for _, entry in ipairs(SpeedEffect.flickerTrails) do
            if entry.trail and entry.trail.Parent then
                pcall(function() entry.trail.Enabled = false end)
            end
        end
    end

    SpeedEffect.groundRayParams = RaycastParams.new()
    SpeedEffect.groundRayParams.FilterType = Enum.RaycastFilterType.Exclude

    local GROUND_ARC_SOURCES = isR15 and {
        "LeftFoot","RightFoot","LeftLowerLeg","RightLowerLeg",
        "LeftUpperLeg","RightUpperLeg","HumanoidRootPart"
    } or {"Left Leg","Right Leg","HumanoidRootPart"}

    local ARC_COLOR = Color3.fromRGB(20, 20, 20)

    local function fireGroundArc(originPart)
        if not originPart or not originPart.Parent then return end
        local charArc = LocalPlayer.Character
        if not charArc then return end
        SpeedEffect.groundRayParams.FilterDescendantsInstances = {charArc}

        local spreadX = (math.random() - 0.5) * 5
        local spreadZ = (math.random() - 0.5) * 5
        local rayLength = math.random(5, 20)
        local rayDir = Vector3.new(spreadX * 0.3, -rayLength, spreadZ * 0.3)
        local result = workspace:Raycast(originPart.Position, rayDir, SpeedEffect.groundRayParams)
        if not result then return end

        local groundPos = result.Position + Vector3.new(
            (math.random()-0.5)*2.5, 0.02, (math.random()-0.5)*2.5
        )

        local groundPart = Instance.new("Part")
        groundPart.Anchored = true; groundPart.CanCollide = false
        groundPart.CastShadow = false; groundPart.Transparency = 1
        groundPart.Size = Vector3.new(0.05,0.05,0.05)
        groundPart.Position = groundPos; groundPart.Parent = workspace

        local groundAttach = Instance.new("Attachment", groundPart)
        local bodyAttach = Instance.new("Attachment", originPart)
        bodyAttach.Position = Vector3.new(
            (math.random()-0.5)*0.6, (math.random()-0.5)*0.5, (math.random()-0.5)*0.4
        )

        local whiteCol = Color3.new(1,1,1)
        local beam = Instance.new("Beam")
        beam.Attachment0 = bodyAttach; beam.Attachment1 = groundAttach
        beam.FaceCamera = true; beam.LightEmission = 1; beam.LightInfluence = 0
        beam.Brightness = math.random(6,14)
        beam.Segments = math.random(10,24)
        beam.Width0 = math.random(4,14)/100
        beam.Width1 = math.random(1,7)/100
        beam.CurveSize0 = (math.random()-0.5)*7
        beam.CurveSize1 = (math.random()-0.5)*7
        beam.Texture = "rbxassetid://16607923"
        beam.TextureLength = math.random(1,4)
        beam.TextureMode = Enum.TextureMode.Static
        beam.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, whiteCol),
            ColorSequenceKeypoint.new(0.25, ARC_COLOR),
            ColorSequenceKeypoint.new(0.75, ARC_COLOR),
            ColorSequenceKeypoint.new(1, whiteCol)
        })
        beam.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.15),
            NumberSequenceKeypoint.new(0.4, 0),
            NumberSequenceKeypoint.new(0.6, 0),
            NumberSequenceKeypoint.new(1, 0.6)
        })
        beam.Parent = groundPart

        local lifetime = math.random(3,18)/100
        Debris:AddItem(groundPart, lifetime + 0.08)
        Debris:AddItem(bodyAttach, lifetime + 0.08)

        task.delay(lifetime * 0.35, function()
            if beam and beam.Parent then
                local steps = 10
                local stepTime = (lifetime * 0.65) / steps
                local w0 = beam.Width0
                local w1 = beam.Width1
                task.spawn(function()
                    for i = 1, steps do
                        if not beam or not beam.Parent then break end
                        local t = i / steps
                        beam.Width0 = w0 * (1 - t)
                        beam.Width1 = w1 * (1 - t)
                        beam.Transparency = NumberSequence.new(t)
                        task.wait(stepTime)
                    end
                end)
            end
        end)

        if math.random() < 0.35 then
            task.delay(math.random(1,3)/100, function()
                local charBr = LocalPlayer.Character
                if not charBr or not originPart.Parent then return end
                local brPart = Instance.new("Part")
                brPart.Anchored = true; brPart.CanCollide = false
                brPart.CastShadow = false; brPart.Transparency = 1
                brPart.Size = Vector3.new(0.05,0.05,0.05)
                brPart.Position = groundPos + Vector3.new((math.random()-0.5)*4, 0.02, (math.random()-0.5)*4)
                brPart.Parent = workspace
                local bA0 = Instance.new("Attachment", originPart)
                bA0.Position = bodyAttach.Position + Vector3.new((math.random()-0.5)*0.4,0,0)
                local bA1 = Instance.new("Attachment", brPart)
                local bBeam = Instance.new("Beam")
                bBeam.Attachment0 = bA0; bBeam.Attachment1 = bA1
                bBeam.FaceCamera = true; bBeam.LightEmission = 1; bBeam.LightInfluence = 0
                bBeam.Brightness = math.random(3,7)
                bBeam.Segments = math.random(6,14)
                bBeam.Width0 = math.random(1,6)/100; bBeam.Width1 = math.random(1,3)/100
                bBeam.CurveSize0 = (math.random()-0.5)*5; bBeam.CurveSize1 = (math.random()-0.5)*5
                bBeam.Texture = "rbxassetid://16607923"; bBeam.TextureLength = math.random(1,3)
                bBeam.TextureMode = Enum.TextureMode.Static
                bBeam.Color = ColorSequence.new(ARC_COLOR)
                bBeam.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.3),
                    NumberSequenceKeypoint.new(0.5, 0.1),
                    NumberSequenceKeypoint.new(1, 0.8)
                })
                bBeam.Parent = brPart
                local bLife = lifetime * 0.7
                Debris:AddItem(brPart, bLife + 0.05)
                Debris:AddItem(bA0, bLife + 0.05)
                task.delay(bLife*0.4, function()
                    if bBeam and bBeam.Parent then
                        local steps = 8
                        local stepTime = (bLife * 0.6) / steps
                        local bw0 = bBeam.Width0
                        local bw1 = bBeam.Width1
                        task.spawn(function()
                            for i = 1, steps do
                                if not bBeam or not bBeam.Parent then break end
                                local t = i / steps
                                bBeam.Width0 = bw0 * (1 - t)
                                bBeam.Width1 = bw1 * (1 - t)
                                bBeam.Transparency = NumberSequence.new(t)
                                task.wait(stepTime)
                            end
                        end)
                    end
                end)
            end)
        end
    end

    local function startGroundArcs()
        if SpeedEffect.groundArcActive then return end
        SpeedEffect.groundArcActive = true
        SpeedEffect.groundArcThread = task.spawn(function()
            while SpeedEffect.groundArcActive do
                local spd2 = currentWalkSpeed or 16
                if spd2 > 30 then
                    local charGA = LocalPlayer.Character
                    local hrpGA = charGA and charGA:FindFirstChild("HumanoidRootPart")
                    local humGA = charGA and charGA:FindFirstChildOfClass("Humanoid")
                    if hrpGA and humGA and humGA.MoveDirection.Magnitude > 0 then
                        local numArcs = math.random(1,3)
                        for _ = 1, numArcs do
                            local srcName = GROUND_ARC_SOURCES[math.random(1,#GROUND_ARC_SOURCES)]
                            local srcPart = charGA:FindFirstChild(srcName)
                            if srcPart then pcall(function() fireGroundArc(srcPart) end) end
                        end
                    end
                end
                task.wait(math.random(3,8)/100)
            end
        end)
    end

    local function stopGroundArcs()
        SpeedEffect.groundArcActive = false
        if SpeedEffect.groundArcThread then
            task.cancel(SpeedEffect.groundArcThread)
            SpeedEffect.groundArcThread = nil
        end
    end

    SpeedEffect.RenderConn = RunService.RenderStepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum then return end

        local Magnitude = hrp.Velocity.Magnitude
        SpeedEffect.tickW = SpeedEffect.tickW + 1

        if currentWalkSpeed <= 30 then
            for _, e in ipairs(SpeedEffect.bodyParticles) do
                if e and e.Parent then pcall(function() e.Enabled = false end) end
            end
            for _, v in ipairs(SpeedEffect.wndAttachment and SpeedEffect.wndAttachment:GetChildren() or {}) do
                if v:IsA("ParticleEmitter") then v.Enabled = false end
            end
            SpeedEffect.wasMoving = false
            disableDarkAura()
            stopFlicker()
            stopGroundArcs()
            return
        end

        local isMovingNow = Magnitude > 8
        SpeedEffect.wasMoving = isMovingNow

        local showBody = Magnitude > 20
        for _, e in ipairs(SpeedEffect.bodyParticles) do
            if e and e.Parent then pcall(function() e.Enabled = showBody end) end
        end

        if SpeedEffect.wndPart and cam then
            local wndPos = cam.CFrame.Position + cam.CFrame.LookVector * 15
            SpeedEffect.wndPart.CFrame = CFrame.new(wndPos, wndPos + cam.CFrame.LookVector)
        end
        if SpeedEffect.Part_upvr and cam then
            if Magnitude > 0 then
                SpeedEffect.Part_upvr.CFrame = CFrame.new(cam.CFrame.Position, cam.CFrame.Position + hrp.Velocity * 5)
            else
                SpeedEffect.Part_upvr.Position = cam.CFrame.Position
            end
        end

        if Magnitude >= 80 and SpeedEffect.tickW % math.max(1, math.floor(50 / Magnitude)) == 0 then
            local Part = Instance.new("Part")
            Part.CastShadow = false; Part.Color = Color3.new(1,1,1)
            Part.Material = Enum.Material.ForceField; Part.Transparency = 1
            Part.Size = Vector3.new(0.03, 0.03, Magnitude/60)
            Part.CanCollide = false; Part.Massless = true; Part.Parent = Workspace
            local SpecialMesh = Instance.new("SpecialMesh")
            SpecialMesh.MeshType = Enum.MeshType.Sphere; SpecialMesh.Parent = Part
            local cframe = CFrame.new(math.random(-300,300)/100, math.random(-200,200)/100, -math.floor(Magnitude/50)*2)
            local Weld = Instance.new("Weld", Part)
            Weld.Part0 = SpeedEffect.Part_upvr; Weld.Part1 = Part; Weld.C0 = cframe
            if SpeedEffect.wndAttachment then
                for _, v in ipairs(SpeedEffect.wndAttachment:GetDescendants()) do
                    if v:IsA("ParticleEmitter") then
                        v.Enabled = true
                        if v.Name ~= "Wind3" then
                            v.Speed = NumberRange.new(math.clamp(5*Magnitude/40,-100,50), math.clamp(20*Magnitude/40,-100,200))
                            v.Rate = math.clamp(2*Magnitude/4, 0, 2000)
                        else
                            v.LockedToPart = (hum.FloorMaterial == Enum.Material.Air and Magnitude > 250)
                        end
                    end
                end
            end
            Debris:AddItem(Part, 0.6)
            TweenService:Create(Part, TweenInfo.new(0.05, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {Transparency = 0.8}):Play()
            TweenService:Create(Weld, TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {C0 = CFrame.new(cframe.Position.X, cframe.Position.Y, math.floor(Magnitude/100)*4)}):Play()
            task.delay(0.225, function()
                TweenService:Create(Part, TweenInfo.new(0.095, Enum.EasingStyle.Linear, Enum.EasingDirection.In), {Transparency = 1}):Play()
            end)
        else
            if SpeedEffect.wndAttachment then
                for _, v in ipairs(SpeedEffect.wndAttachment:GetChildren()) do
                    if v:IsA("ParticleEmitter") then v.Enabled = false end
                end
            end
        end

        if currentWalkSpeed > 30 then
            startFlicker()
            enableDarkAura()
            startGroundArcs()
        else
            stopFlicker()
            disableDarkAura()
            stopGroundArcs()
        end
    end)
end

local function cleanupSpeedEffect()
    if not SpeedEffect.enabled then return end
    SpeedEffect.enabled = false

    if SpeedEffect.RenderConn then
        SpeedEffect.RenderConn:Disconnect()
        SpeedEffect.RenderConn = nil
    end

    if SpeedEffect.wndPart then pcall(function() SpeedEffect.wndPart:Destroy() end); SpeedEffect.wndPart = nil end
    if SpeedEffect.Part_upvr then pcall(function() SpeedEffect.Part_upvr:Destroy() end); SpeedEffect.Part_upvr = nil end
    for _, e in ipairs(SpeedEffect.bodyParticles) do pcall(function() e:Destroy() end) end
    SpeedEffect.bodyParticles = {}
    SpeedEffect.wasMoving = false; SpeedEffect.tickW = 0

    if SpeedEffect.auraUpdateConn then
        SpeedEffect.auraUpdateConn:Disconnect()
        SpeedEffect.auraUpdateConn = nil
    end
    for _, e in next, SpeedEffect.darkAuraEmitters do
        if e and e.Parent then pcall(function() e:Destroy() end) end
    end
    SpeedEffect.darkAuraEmitters = {}; SpeedEffect.darkAuraActive = false

    SpeedEffect.flickerActive = false
    if SpeedEffect.flickerThread then task.cancel(SpeedEffect.flickerThread); SpeedEffect.flickerThread = nil end
    for _, entry in ipairs(SpeedEffect.flickerTrails) do
        pcall(function() if entry.trail and entry.trail.Parent then entry.trail:Destroy() end end)
        pcall(function() if entry.a0 and entry.a0.Parent then entry.a0:Destroy() end end)
        pcall(function() if entry.a1 and entry.a1.Parent then entry.a1:Destroy() end end)
    end
    SpeedEffect.flickerTrails = {}

    SpeedEffect.groundArcActive = false
    if SpeedEffect.groundArcThread then task.cancel(SpeedEffect.groundArcThread); SpeedEffect.groundArcThread = nil end
end
local function applyJumpPower(character, power)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        pcall(function()
            if humanoid.UseJumpPower then
                humanoid.JumpPower = power
            else
                humanoid.JumpHeight = power / 4
            end
        end)
    end
end

local spyTarget = nil
local spyCameraOffset = Vector3.new(0, 5, 15)
local spyRotation = 0
local spyPitch = 0.3
local spyConnections = {}
local spyControlGui = nil
local spyHudGui = nil
local spyOriginalCFrame = nil

local function syncLocalCharacterToTarget(_targetHRP) end

local function createSpyHUD(targetPlayer)
    if spyHudGui then spyHudGui:Destroy() end
    spyHudGui = Instance.new("ScreenGui")
    spyHudGui.Name = "SpyHUD"
    spyHudGui.ResetOnSpawn = false
    spyHudGui.DisplayOrder = 999
    spyHudGui.AutoLocalize = false
    spyHudGui.Parent = game:GetService("CoreGui")

    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 220, 0, 90)
    panel.Position = UDim2.new(0, 10, 0, 10)
    panel.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    panel.BackgroundTransparency = 0.3
    panel.BorderSizePixel = 0
    panel.Parent = spyHudGui
    Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
    local pad = Instance.new("UIPadding", panel)
    pad.PaddingLeft = UDim.new(0, 10)
    pad.PaddingTop = UDim.new(0, 8)
    local stroke_ = Instance.new("UIStroke", panel)
    stroke_.Color = Color3.fromRGB(255, 80, 80)
    stroke_.Thickness = 1.5
    stroke_.Transparency = 0.3

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -10, 0, 18)
    titleLabel.BackgroundTransparency = 1
    titleLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 11
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Text = "SPY MODE ACTIVE"
    titleLabel.Parent = panel

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, -10, 0, 16)
    nameLabel.Position = UDim2.new(0, 0, 0, 22)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    nameLabel.Font = Enum.Font.Gotham
    nameLabel.TextSize = 11
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Text = targetPlayer.DisplayName .. " (@" .. targetPlayer.Name .. ")"
    nameLabel.Parent = panel

    local posLabel = Instance.new("TextLabel")
    posLabel.Name = "PosLabel"
    posLabel.Size = UDim2.new(1, -10, 0, 14)
    posLabel.Position = UDim2.new(0, 0, 0, 42)
    posLabel.BackgroundTransparency = 1
    posLabel.TextColor3 = Color3.fromRGB(150, 220, 255)
    posLabel.Font = Enum.Font.Gotham
    posLabel.TextSize = 10
    posLabel.TextXAlignment = Enum.TextXAlignment.Left
    posLabel.Text = "X:0  Y:0  Z:0"
    posLabel.Parent = panel

    local hpLabel = Instance.new("TextLabel")
    hpLabel.Name = "HpLabel"
    hpLabel.Size = UDim2.new(1, -10, 0, 14)
    hpLabel.Position = UDim2.new(0, 0, 0, 58)
    hpLabel.BackgroundTransparency = 1
    hpLabel.TextColor3 = Color3.fromRGB(100, 255, 120)
    hpLabel.Font = Enum.Font.Gotham
    hpLabel.TextSize = 10
    hpLabel.TextXAlignment = Enum.TextXAlignment.Left
    hpLabel.Text = "HP: --"
    hpLabel.Parent = panel

    local stopBtn = Instance.new("TextButton")
    stopBtn.Size = UDim2.new(0, 60, 0, 22)
    stopBtn.Position = UDim2.new(1, -70, 0, 10)
    stopBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
    stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    stopBtn.Font = Enum.Font.GothamBold
    stopBtn.TextSize = 10
    stopBtn.Text = "STOP SPY"
    stopBtn.BorderSizePixel = 0
    stopBtn.Parent = spyHudGui
    Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 6)
    stopBtn.MouseButton1Click:Connect(function() spy(nil) end)

    local tipsLabel = Instance.new("TextLabel")
    tipsLabel.Size = UDim2.new(0, 220, 0, 14)
    tipsLabel.Position = UDim2.new(0, 10, 0, 108)
    tipsLabel.BackgroundTransparency = 1
    tipsLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
    tipsLabel.Font = Enum.Font.Gotham
    tipsLabel.TextSize = 9
    tipsLabel.TextXAlignment = Enum.TextXAlignment.Left
    tipsLabel.Text = "Right Click+Drag=Rotate  WASD=Pan  F=Reset"
    tipsLabel.Parent = spyHudGui

    return spyHudGui, posLabel, hpLabel
end

function spy(targetName)
    if SpyConnection then
        if type(SpyConnection) == "function" then SpyConnection()
        else SpyConnection:Disconnect() end
        SpyConnection = nil
    end
    for _, conn in ipairs(spyConnections) do
        pcall(function() if conn and conn.Disconnect then conn:Disconnect() end end)
    end
    spyConnections = {}
    Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    SpyEnabled = false
    spyTarget = nil
    if spyControlGui then spyControlGui:Destroy(); spyControlGui = nil end
    if spyHudGui then spyHudGui:Destroy(); spyHudGui = nil end
    spyRotation = 0
    spyPitch = 0.3
    spyCameraOffset = Vector3.new(0, 5, 15)
    if not (targetName and targetName ~= "") then return end

    local targetPlayer = nil
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name:lower() == targetName:lower() or player.DisplayName:lower() == targetName:lower() then
            targetPlayer = player
            break
        end
    end
    if not (targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")) then
        warn("Player '" .. targetName .. "' not found or hasn't spawned yet!")
        return
    end

    SpyEnabled = true
    spyTarget = targetPlayer
    local myChar = LocalPlayer.Character
    local myHRP = myChar and myChar:FindFirstChild("HumanoidRootPart")
    spyOriginalCFrame = myHRP and myHRP.CFrame or nil
    if InvisibleEnabled then invisible(false) end
    Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable
    local _, posLabel, hpLabel = createSpyHUD(targetPlayer)
    local moveSpeed = 0.4
    local zoomDistance = 15
    local cameraManualOffset = Vector3.new(0, 0, 0)
    local keysPressed = {}
    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

    if isMobile then
        spyControlGui = Instance.new("ScreenGui")
        spyControlGui.Name = "SpyControls"
        spyControlGui.ResetOnSpawn = false
        spyControlGui.AutoLocalize = false
        spyControlGui.Parent = game:GetService("CoreGui")
        local rotationTouch = nil
        local lastTouchPos = nil
        local touchRotateBegin = UserInputService.TouchStarted:Connect(function(input, gameProcessed)
            if not gameProcessed and input.Position.X > 180 then
                rotationTouch = input; lastTouchPos = input.Position
            end
        end)
        table.insert(spyConnections, touchRotateBegin)
        local touchRotateMove = UserInputService.TouchMoved:Connect(function(input)
            if input == rotationTouch and lastTouchPos then
                local delta = input.Position - lastTouchPos
                spyRotation = spyRotation - (delta.X * 0.008)
                spyPitch = math.clamp(spyPitch - (delta.Y * 0.005), -1.2, 1.2)
                lastTouchPos = input.Position
            end
        end)
        table.insert(spyConnections, touchRotateMove)
        local touchRotateEnd = UserInputService.TouchEnded:Connect(function(input)
            if input == rotationTouch then rotationTouch = nil; lastTouchPos = nil end
        end)
        table.insert(spyConnections, touchRotateEnd)
    end

    local keyInputBegan2 = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        local kc = input.KeyCode
        if kc == Enum.KeyCode.W then keysPressed.W = true
        elseif kc == Enum.KeyCode.A then keysPressed.A = true
        elseif kc == Enum.KeyCode.S then keysPressed.S = true
        elseif kc == Enum.KeyCode.D then keysPressed.D = true
        elseif kc == Enum.KeyCode.Q then keysPressed.Q = true
        elseif kc == Enum.KeyCode.E then keysPressed.E = true
        elseif kc == Enum.KeyCode.Space then keysPressed.Space = true
        elseif kc == Enum.KeyCode.LeftShift then keysPressed.LeftShift = true
        elseif kc == Enum.KeyCode.F then
            cameraManualOffset = Vector3.new(0, 0, 0)
            zoomDistance = 15; spyPitch = 0.3; spyRotation = 0
        end
    end)
    table.insert(spyConnections, keyInputBegan2)
    local keyInputEnded2 = UserInputService.InputEnded:Connect(function(input)
        local kc = input.KeyCode
        if kc == Enum.KeyCode.W then keysPressed.W = false
        elseif kc == Enum.KeyCode.A then keysPressed.A = false
        elseif kc == Enum.KeyCode.S then keysPressed.S = false
        elseif kc == Enum.KeyCode.D then keysPressed.D = false
        elseif kc == Enum.KeyCode.Q then keysPressed.Q = false
        elseif kc == Enum.KeyCode.E then keysPressed.E = false
        elseif kc == Enum.KeyCode.Space then keysPressed.Space = false
        elseif kc == Enum.KeyCode.LeftShift then keysPressed.LeftShift = false
        end
    end)
    table.insert(spyConnections, keyInputEnded2)

    if not isMobile then
        local isDragging = false
        local lastMousePos = nil
        local mouseBtn2Down = UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                isDragging = true; lastMousePos = UserInputService:GetMouseLocation()
            end
        end)
        table.insert(spyConnections, mouseBtn2Down)
        local mouseBtn2Up = UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton2 then
                isDragging = false; lastMousePos = nil
            end
        end)
        table.insert(spyConnections, mouseBtn2Up)
        local mouseMove = UserInputService.InputChanged:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement and isDragging then
                local curr = UserInputService:GetMouseLocation()
                if lastMousePos then
                    local delta = curr - lastMousePos
                    spyRotation = spyRotation - (delta.X * 0.004)
                    spyPitch = math.clamp(spyPitch - (delta.Y * 0.003), -1.2, 1.2)
                end
                lastMousePos = curr
            elseif input.UserInputType == Enum.UserInputType.MouseWheel then
                zoomDistance = math.clamp(zoomDistance - (input.Position.Z * 3), 3, 80)
            end
        end)
        table.insert(spyConnections, mouseMove)
    end

    local streamSyncTimer = 0
    local renderConnection = RunService.RenderStepped:Connect(function(dt)
        if not spyTarget or not spyTarget.Character then task.defer(function() spy(nil) end); return end
        local targetHRP = spyTarget.Character:FindFirstChild("HumanoidRootPart")
        if not targetHRP then task.defer(function() spy(nil) end); return end
        streamSyncTimer = streamSyncTimer + dt
        if streamSyncTimer >= 0.5 then
            streamSyncTimer = 0
            syncLocalCharacterToTarget(targetHRP)
        end
        local currentSpeed = moveSpeed * (keysPressed.LeftShift and 3 or 1)
        local right = CFrame.Angles(0, spyRotation, 0) * Vector3.new(1, 0, 0)
        local forward = CFrame.Angles(0, spyRotation, 0) * Vector3.new(0, 0, -1)
        if keysPressed.W then cameraManualOffset = cameraManualOffset + forward * currentSpeed end
        if keysPressed.S then cameraManualOffset = cameraManualOffset - forward * currentSpeed end
        if keysPressed.A then cameraManualOffset = cameraManualOffset - right * currentSpeed end
        if keysPressed.D then cameraManualOffset = cameraManualOffset + right * currentSpeed end
        if keysPressed.Space then cameraManualOffset = cameraManualOffset + Vector3.new(0, currentSpeed, 0) end
        if keysPressed.Q then cameraManualOffset = cameraManualOffset - Vector3.new(0, currentSpeed, 0) end
        local anyMove = keysPressed.W or keysPressed.S or keysPressed.A or keysPressed.D or keysPressed.Space or keysPressed.Q
        if not anyMove then cameraManualOffset = cameraManualOffset * 0.92 end
        local orbitCF = CFrame.Angles(0, spyRotation, 0) * CFrame.Angles(spyPitch, 0, 0)
        local camOffset = orbitCF * Vector3.new(0, 0, zoomDistance)
        local targetPos = targetHRP.Position + Vector3.new(0, 1.5, 0)
        local camPos = targetPos + camOffset + cameraManualOffset
        Workspace.CurrentCamera.CFrame = CFrame.new(camPos, targetPos)
        if posLabel and posLabel.Parent then
            posLabel.Text = string.format("X:%.0f  Y:%.0f  Z:%.0f", targetHRP.Position.X, targetHRP.Position.Y, targetHRP.Position.Z)
        end
        if hpLabel and hpLabel.Parent then
            local hum = spyTarget.Character:FindFirstChildOfClass("Humanoid")
            if hum then hpLabel.Text = string.format("HP: %.0f / %.0f", hum.Health, hum.MaxHealth) end
        end
    end)
    table.insert(spyConnections, renderConnection)
end

function antiLag(state)
    AntiLagEnabled = state
    task.spawn(function()
        if state then
            originalGraphics = {
                GlobalShadows = Lighting.GlobalShadows,
                Technology = Lighting.Technology,
                FogEnd = Lighting.FogEnd,
                FogStart = Lighting.FogStart,
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                Brightness = Lighting.Brightness,
                ShadowSoftness = Lighting.ShadowSoftness,
                EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
                EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
                ClockTime = Lighting.ClockTime,
            }
            pcall(function()
                originalRenderSettings.QualityLevel = settings().Rendering.QualityLevel
                originalRenderSettings.MeshPartDetailLevel = settings().Rendering.MeshPartDetailLevel
            end)
            Lighting.GlobalShadows = false
            pcall(function() Lighting.Technology = Enum.Technology.Compatibility end)
            Lighting.FogEnd = 100000
            Lighting.FogStart = 99999
            for _, part in pairs(Workspace:GetDescendants()) do
                if part:IsA("ParticleEmitter") or part:IsA("Beam") or part:IsA("Trail")
                    or part:IsA("Fire") or part:IsA("Smoke") or part:IsA("Sparkles") then
                    pcall(function()
                        if part.Enabled then
                            part.Enabled = false
                            table.insert(antiLagCleanupList, {obj = part, prop = "Enabled", value = true})
                        end
                    end)
                elseif part:IsA("Decal") then
                    if part.Transparency < 1 then
                        table.insert(antiLagCleanupList, {obj = part, prop = "Transparency", value = part.Transparency})
                        part.Transparency = 1
                    end
                elseif part:IsA("PointLight") or part:IsA("SpotLight") or part:IsA("SurfaceLight") then
                    if part.Enabled then
                        part.Enabled = false
                        table.insert(antiLagCleanupList, {obj = part, prop = "Enabled", value = true})
                    end
                end
            end
            pcall(function()
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
                settings().Rendering.MeshPartDetailLevel = Enum.MeshPartDetailLevel.Disabled
            end)
            local conn = Workspace.DescendantAdded:Connect(function(newObj)
                if not AntiLagEnabled then return end
                if newObj:IsA("ParticleEmitter") or newObj:IsA("Beam") or newObj:IsA("Trail")
                    or newObj:IsA("Fire") or newObj:IsA("Smoke") or newObj:IsA("Sparkles") then
                    pcall(function()
                        if newObj.Enabled then
                            newObj.Enabled = false
                            table.insert(antiLagCleanupList, {obj = newObj, prop = "Enabled", value = true})
                        end
                    end)
                elseif newObj:IsA("PointLight") or newObj:IsA("SpotLight") or newObj:IsA("SurfaceLight") then
                    pcall(function()
                        if newObj.Enabled then
                            newObj.Enabled = false
                            table.insert(antiLagCleanupList, {obj = newObj, prop = "Enabled", value = true})
                        end
                    end)
                end
            end)
            table.insert(antiLagConnections, conn)
        else
            for _, conn in ipairs(antiLagConnections) do
                pcall(function() conn:Disconnect() end)
            end
            antiLagConnections = {}
            if originalGraphics and next(originalGraphics) then
                Lighting.GlobalShadows = originalGraphics.GlobalShadows
                Lighting.Technology = originalGraphics.Technology
                Lighting.FogEnd = originalGraphics.FogEnd
                Lighting.FogStart = originalGraphics.FogStart
                Lighting.Ambient = originalGraphics.Ambient
                Lighting.OutdoorAmbient = originalGraphics.OutdoorAmbient
                Lighting.Brightness = originalGraphics.Brightness
                Lighting.ShadowSoftness = originalGraphics.ShadowSoftness
                Lighting.EnvironmentDiffuseScale = originalGraphics.EnvironmentDiffuseScale
                Lighting.EnvironmentSpecularScale = originalGraphics.EnvironmentSpecularScale
                pcall(function() Lighting.ClockTime = originalGraphics.ClockTime end)
            end
            pcall(function()
                if originalRenderSettings.QualityLevel then
                    settings().Rendering.QualityLevel = originalRenderSettings.QualityLevel
                end
                if originalRenderSettings.MeshPartDetailLevel then
                    settings().Rendering.MeshPartDetailLevel = originalRenderSettings.MeshPartDetailLevel
                end
            end)
            for _, entry in ipairs(antiLagCleanupList) do
                pcall(function()
                    if entry.obj and entry.obj.Parent then
                        entry.obj[entry.prop] = entry.value
                    end
                end)
            end
            antiLagCleanupList = {}
            originalGraphics = {}
            originalRenderSettings = {}
        end
    end)
end

local function isCheckpoint(part)
    local name = part.Name:lower()
    local keywords = {"stage", "save", "spawn", "teleport", "goal", "lobby", "checkpoint", "win", "finish"}
    for _, keyword in ipairs(keywords) do
        if string.find(name, keyword) then return true end
    end
    if part.Material == Enum.Material.ForceField or part.Material == Enum.Material.Neon then return true end
    if part:FindFirstChild("Checkpoint") or part:FindFirstChildOfClass("Configuration") then return true end
    if part.Size.Y < 2 and part.Anchored and part.CanCollide and part.Position.Y < 5 then return true end
    return false
end

local function createCheckpointLabel(part)
    if CheckpointLabels[part] or not part:IsA("BasePart") or not isCheckpoint(part) then return end
    local label = Instance.new("TextLabel")
    label.Name = "CheckpointLabel_" .. part.Name
    label.Size = UDim2.new(0, 200, 0, 30)
    label.BackgroundTransparency = 1
    label.TextStrokeTransparency = 0
    label.TextColor3 = Color3.new(0, 1, 0)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 14
    label.Text = string.format("%s\n(%.0f, %.0f, %.0f)", part.Name, part.Position.X, part.Position.Y, part.Position.Z)
    label.Parent = CheckpointGui
    CheckpointLabels[part] = label
end

function espCheckpoint(state)
    CheckpointEspEnabled = state
    if state then
        if CheckpointEspConnection then CheckpointEspConnection:Disconnect(); CheckpointEspConnection = nil end
        if CheckpointAddedConnection then CheckpointAddedConnection:Disconnect(); CheckpointAddedConnection = nil end
        if CheckpointGui and CheckpointGui.Parent then CheckpointGui:Destroy() end
        CheckpointGui = Instance.new("ScreenGui")
        CheckpointGui.Name = "CheckpointESP"
        CheckpointGui.AutoLocalize = false
        CheckpointGui.Parent = game:GetService("CoreGui")
        for _, part in pairs(Workspace:GetDescendants()) do createCheckpointLabel(part) end
        CheckpointAddedConnection = Workspace.DescendantAdded:Connect(function(part)
            if part:IsA("BasePart") then createCheckpointLabel(part) end
        end)
        CheckpointEspConnection = RunService.RenderStepped:Connect(function()
            for checkpoint, label in pairs(CheckpointLabels) do
                if checkpoint and checkpoint.Parent then
                    local vector, onScreen = Camera:WorldToScreenPoint(checkpoint.Position)
                    if onScreen then label.Visible = true; label.Position = UDim2.new(0, vector.X, 0, vector.Y)
                    else label.Visible = false end
                else
                    label:Destroy(); CheckpointLabels[checkpoint] = nil
                end
            end
        end)
    else
        if CheckpointEspConnection then CheckpointEspConnection:Disconnect(); CheckpointEspConnection = nil end
        if CheckpointAddedConnection then CheckpointAddedConnection:Disconnect(); CheckpointAddedConnection = nil end
        for _, label in pairs(CheckpointLabels) do label:Destroy() end
        CheckpointLabels = {}
        if CheckpointGui and CheckpointGui.Parent then CheckpointGui:Destroy() end
        CheckpointGui = nil
    end
end

local UIState = { Toggles = {}, Sliders = {}, Dropdowns = {}, Texts = {} }

local uiBlur = makeUI(Lighting, "BlurEffect", {Size = 20, Enabled = false})

local screenGui = makeUI(game:GetService("CoreGui"), "ScreenGui", {
    Name = "ModernAdminUI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    AutoLocalize = false
})

local mainFrame = makeUI(screenGui, "Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0.2, 0),
    Size = UDim2.new(0, 265, 0, 40),
    BackgroundColor3 = Color3.fromRGB(30, 30, 30),
    BackgroundTransparency = 0.3,
    BorderSizePixel = 0,
    Active = true,
    ClipsDescendants = true
})
makeUI(mainFrame, "UICorner", {CornerRadius = UDim.new(0, 12)})

local shadow = makeUI(mainFrame, "ImageLabel", {
    BackgroundTransparency = 1,
    Image = "rbxassetid://5028857084",
    ImageTransparency = 0.75,
    ScaleType = Enum.ScaleType.Slice,
    SliceCenter = Rect.new(24, 24, 276, 276),
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    ZIndex = -1
})
local stroke = makeUI(mainFrame, "UIStroke", {
    Color = Color3.fromRGB(70, 70, 70),
    Thickness = 1.2,
    Transparency = 0.2
})

local glowStroke = makeUI(mainFrame, "UIStroke", {
    Color = Color3.fromRGB(255, 255, 255),
    Thickness = 2.5,
    Transparency = 0,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border
})
local glowGradient = makeUI(glowStroke, "UIGradient", {
    Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 150, 150)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 50, 50))
    },
    Rotation = 0
})

local function animateGlowingBorder()
    local rotateTween = TweenService:Create(glowGradient,
        TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 0),
        {Rotation = 360}
    )
    spawn(function()
        while screenGui.Parent do
            local t1 = TweenService:Create(glowStroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Color = Color3.fromRGB(150,150,150)})
            t1:Play(); t1.Completed:Wait()
            local t2 = TweenService:Create(glowStroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Color = Color3.fromRGB(50,50,50)})
            t2:Play(); t2.Completed:Wait()
            local t3 = TweenService:Create(glowStroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Color = Color3.fromRGB(150,150,150)})
            t3:Play(); t3.Completed:Wait()
            local t4 = TweenService:Create(glowStroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Color = Color3.fromRGB(255,255,255)})
            t4:Play(); t4.Completed:Wait()
        end
    end)
    rotateTween:Play()
end
animateGlowingBorder()

local header = makeUI(mainFrame, "Frame", {
    Size = UDim2.new(1, 0, 0, 28),
    BackgroundColor3 = Color3.fromRGB(20, 20, 20),
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 5
})
makeUI(header, "UICorner", {CornerRadius = UDim.new(0, 12)})

local titleLabel = makeUI(header, "TextLabel", {
    Text = "Zero Exploiters",
    Font = Enum.Font.GothamSemibold,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 12,
    BackgroundTransparency = 1,
    Size = UDim2.new(0.4, 0, 1, 0),
    Position = UDim2.new(0, 8, 0, 0),
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 6
})

local minimizeButton = makeUI(header, "TextButton", {
    Text = "+",
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 0.3,
    BackgroundColor3 = Color3.fromRGB(50, 50, 50),
    Size = UDim2.new(0, 24, 0, 24),
    Position = UDim2.new(1, -4, 0.5, 0),
    AnchorPoint = Vector2.new(1, 0.5),
    ZIndex = 6
})
makeUI(minimizeButton, "UICorner", {CornerRadius = UDim.new(1, 0)})

local dotsFrame = makeUI(header, "Frame", {
    Size = UDim2.new(0, 82, 0, 10),
    Position = UDim2.new(1, -30, 0.5, 0),
    AnchorPoint = Vector2.new(1, 0.5),
    BackgroundTransparency = 1,
    ZIndex = 6
})
makeUI(dotsFrame, "UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 4)
})
local dot1 = makeUI(dotsFrame, "Frame", {
    Size = UDim2.new(0, 7, 0, 7),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BorderSizePixel = 0
})
makeUI(dot1, "UICorner", {CornerRadius = UDim.new(1, 0)})
local dot2 = makeUI(dotsFrame, "Frame", {
    Size = UDim2.new(0, 7, 0, 7),
    BackgroundColor3 = Color3.fromRGB(100, 100, 100),
    BorderSizePixel = 0
})
makeUI(dot2, "UICorner", {CornerRadius = UDim.new(1, 0)})
local dot3 = makeUI(dotsFrame, "Frame", {
    Size = UDim2.new(0, 7, 0, 7),
    BackgroundColor3 = Color3.fromRGB(100, 100, 100),
    BorderSizePixel = 0
})
makeUI(dot3, "UICorner", {CornerRadius = UDim.new(1, 0)})
local dot4 = makeUI(dotsFrame, "Frame", {
    Size = UDim2.new(0, 7, 0, 7),
    BackgroundColor3 = Color3.fromRGB(100, 100, 100),
    BorderSizePixel = 0
})
makeUI(dot4, "UICorner", {CornerRadius = UDim.new(1, 0)})
local dot5 = makeUI(dotsFrame, "Frame", {
    Size = UDim2.new(0, 7, 0, 7),
    BackgroundColor3 = Color3.fromRGB(100, 100, 100),
    BorderSizePixel = 0
})
makeUI(dot5, "UICorner", {CornerRadius = UDim.new(1, 0)})
local dot6 = makeUI(dotsFrame, "Frame", {
    Size = UDim2.new(0, 7, 0, 7),
    BackgroundColor3 = Color3.fromRGB(100, 100, 100),
    BorderSizePixel = 0
})
makeUI(dot6, "UICorner", {CornerRadius = UDim.new(1, 0)})

local viewport = makeUI(mainFrame, "Frame", {
    Position = UDim2.new(0, 0, 0, 28),
    Size = UDim2.new(1, 0, 1, -28),
    BackgroundTransparency = 1,
    ClipsDescendants = true
})

local PAGE_W = 265
local pageContainer = makeUI(viewport, "Frame", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(0, PAGE_W * 6, 1, 0),
    BackgroundTransparency = 1
})

local page1 = makeUI(pageContainer, "Frame", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(0, PAGE_W, 1, 0),
    BackgroundTransparency = 1
})
local optionsFrame = makeUI(page1, "ScrollingFrame", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    ScrollBarThickness = 6,
    CanvasSize = UDim2.new(0, 0, 0, 0),
    VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
    Active = true
})
local layout = makeUI(optionsFrame, "UIListLayout", {
    Padding = UDim.new(0, 5),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Top
})
makeUI(optionsFrame, "UIPadding", {PaddingTop = UDim.new(0, 6)})
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    optionsFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
end)

local page2 = makeUI(pageContainer, "Frame", {
    Position = UDim2.new(0, PAGE_W, 0, 0),
    Size = UDim2.new(0, PAGE_W, 1, 0),
    BackgroundTransparency = 1
})
local optionsFrame2 = makeUI(page2, "ScrollingFrame", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    ScrollBarThickness = 6,
    ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
    Active = true
})
local layout2 = makeUI(optionsFrame2, "UIListLayout", {
    Padding = UDim.new(0, 5),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Top
})
makeUI(optionsFrame2, "UIPadding", {PaddingTop = UDim.new(0, 6)})
layout2:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    optionsFrame2.CanvasSize = UDim2.new(0, 0, 0, layout2.AbsoluteContentSize.Y + 8)
end)

local page3 = makeUI(pageContainer, "Frame", {
    Position = UDim2.new(0, PAGE_W * 2, 0, 0),
    Size = UDim2.new(0, PAGE_W, 1, 0),
    BackgroundTransparency = 1
})
local optionsFrame3 = makeUI(page3, "ScrollingFrame", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    ScrollBarThickness = 6,
    ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
    Active = true
})
local layout3 = makeUI(optionsFrame3, "UIListLayout", {
    Padding = UDim.new(0, 5),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Top
})
makeUI(optionsFrame3, "UIPadding", {PaddingTop = UDim.new(0, 6)})
layout3:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    optionsFrame3.CanvasSize = UDim2.new(0, 0, 0, layout3.AbsoluteContentSize.Y + 8)
end)

local page4 = makeUI(pageContainer, "Frame", {
    Position = UDim2.new(0, PAGE_W * 3, 0, 0),
    Size = UDim2.new(0, PAGE_W, 1, 0),
    BackgroundTransparency = 1
})
local TEMPFRAME_A = makeUI(page4, "ScrollingFrame", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    ScrollBarThickness = 6,
    ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
    Active = true
})
local TEMPLAYOUT_A = makeUI(TEMPFRAME_A, "UIListLayout", {
    Padding = UDim.new(0, 6),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Top
})
makeUI(TEMPFRAME_A, "UIPadding", {PaddingTop = UDim.new(0, 6)})
TEMPLAYOUT_A:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    TEMPFRAME_A.CanvasSize = UDim2.new(0, 0, 0, TEMPLAYOUT_A.AbsoluteContentSize.Y + 8)
end)

local page5 = makeUI(pageContainer, "Frame", {
    Position = UDim2.new(0, PAGE_W * 4, 0, 0),
    Size = UDim2.new(0, PAGE_W, 1, 0),
    BackgroundTransparency = 1
})
local TEMPFRAME_B = makeUI(page5, "ScrollingFrame", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    ScrollBarThickness = 6,
    ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
    Active = true
})
local TEMPLAYOUT_B = makeUI(TEMPFRAME_B, "UIListLayout", {
    Padding = UDim.new(0, 5),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Top
})
makeUI(TEMPFRAME_B, "UIPadding", {PaddingTop = UDim.new(0, 6)})
TEMPLAYOUT_B:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    TEMPFRAME_B.CanvasSize = UDim2.new(0, 0, 0, TEMPLAYOUT_B.AbsoluteContentSize.Y + 8)
end)

local page6 = makeUI(pageContainer, "Frame", {
    Position = UDim2.new(0, PAGE_W * 5, 0, 0),
    Size = UDim2.new(0, PAGE_W, 1, 0),
    BackgroundTransparency = 1
})
local TEMPFRAME_C = makeUI(page6, "ScrollingFrame", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    ScrollBarThickness = 6,
    ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
    Active = true
})
local TEMPLAYOUT_C = makeUI(TEMPFRAME_C, "UIListLayout", {
    Padding = UDim.new(0, 5),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Top
})
makeUI(TEMPFRAME_C, "UIPadding", {PaddingTop = UDim.new(0, 6)})
TEMPLAYOUT_C:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    TEMPFRAME_C.CanvasSize = UDim2.new(0, 0, 0, TEMPLAYOUT_C.AbsoluteContentSize.Y + 8)
end)

local optionsFrame4 = TEMPFRAME_A
local layout4 = TEMPLAYOUT_A
local optionsFrame5 = TEMPFRAME_B
local layout5 = TEMPLAYOUT_B
local optionsFrame6 = TEMPFRAME_C
local layout6 = TEMPLAYOUT_C

local currentPage = 1
local totalPages = 6
local pageNames = {"Zero Exploiters", "Zero Exploiters", "Zero Exploiters", "Zero Exploiters", "Zero Exploiters", "Zero Exploiters"}
local isMinimized = false
local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local minimizedSize = UDim2.new(0, 265, 0, 40)
local UI_HEIGHT = 300

mainFrame.Size = UDim2.new(0, 265, 0, 40)

local function updateDots()
    dot1.BackgroundColor3 = currentPage == 1 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(80, 80, 80)
    dot2.BackgroundColor3 = currentPage == 2 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(80, 80, 80)
    dot3.BackgroundColor3 = currentPage == 3 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(80, 80, 80)
    dot4.BackgroundColor3 = currentPage == 4 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(80, 80, 80)
    dot5.BackgroundColor3 = currentPage == 5 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(80, 80, 80)
    dot6.BackgroundColor3 = currentPage == 6 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(80, 80, 80)
    titleLabel.Text = pageNames[currentPage]
end

local function goToPage(pageNum)
    currentPage = pageNum
    updateDots()
    local targetOffsetX = -(pageNum - 1) * PAGE_W
    TweenService:Create(pageContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, targetOffsetX, 0, 0)
    }):Play()
end

-- ============================================================
-- WindUI-style Drag System (Main UI)
-- Supports PC (MouseButton1) + Mobile (Touch)
-- Smooth tween movement ported from WindUI p.Drag()
-- ============================================================
local _mainDragActive    = false
local _mainDragInput     = nil
local _mainDragStartPos  = nil   -- input Position at drag start
local _mainFrameStartPos = nil   -- mainFrame.Position at drag start
local gestureMode        = nil
local touchDeltaX        = 0
local touchDeltaY        = 0

local function isInsideFrame(frame, x, y)
    local pos  = frame.AbsolutePosition
    local size = frame.AbsoluteSize
    return x >= pos.X and x <= pos.X + size.X and y >= pos.Y and y <= pos.Y + size.Y
end

-- Smooth tween-based position update (WindUI 0.02s micro-tween)
local function _mainDragUpdate(inputPos)
    if not _mainDragActive or not _mainFrameStartPos or not _mainDragStartPos then return end
    local delta = inputPos - _mainDragStartPos
    TweenService:Create(mainFrame, TweenInfo.new(0.02, Enum.EasingStyle.Linear), {
        Position = UDim2.new(
            _mainFrameStartPos.X.Scale,
            _mainFrameStartPos.X.Offset + delta.X,
            _mainFrameStartPos.Y.Scale,
            _mainFrameStartPos.Y.Offset + delta.Y
        )
    }):Play()
    touchDeltaX = delta.X
    touchDeltaY = delta.Y
end

-- Drag handles: header + drag bar (same as WindUI: topbar + drag frame)
local _mainDragHandles = { header }

for _, handle in ipairs(_mainDragHandles) do
    handle.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch)
            and not _mainDragActive
        then
            _mainDragActive    = true
            _mainDragInput     = input
            _mainDragStartPos  = input.Position
            _mainFrameStartPos = mainFrame.Position
            gestureMode        = "drag"
            touchDeltaX        = 0
            touchDeltaY        = 0

            -- Track input end on the input object itself (WindUI pattern)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    _mainDragActive    = false
                    _mainDragInput     = nil
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if _mainDragActive and _mainDragInput == input then
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch
            then
                _mainDragUpdate(input.Position)
            end
        end
    end)
end

-- Global InputChanged fallback (catches mouse movement outside handle, WindUI pattern)
UserInputService.InputChanged:Connect(function(input)
    if _mainDragActive and _mainDragInput ~= nil then
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        then
            _mainDragUpdate(input.Position)
        end
    end
end)

-- Swipe/page gesture: only on content area (not header)
-- Uses a separate, non-drag InputBegan on the full mainFrame
local _swipeTouchStartX   = nil
local _swipeTouchStartY   = nil
local _swipeActive        = false

UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Touch and
       input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local tx, ty
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local mloc = UserInputService:GetMouseLocation()
        tx = mloc.X; ty = mloc.Y
    else
        tx = input.Position.X; ty = input.Position.Y
    end
    if not isInsideFrame(mainFrame, tx, ty) then return end
    if isInsideFrame(header, tx, ty) then return end  -- header handled by drag
    _swipeTouchStartX = tx
    _swipeTouchStartY = ty
    _swipeActive      = false
    touchDeltaX       = 0
    touchDeltaY       = 0
end)

UserInputService.InputChanged:Connect(function(input)
    if not _swipeTouchStartX then return end
    if _mainDragActive then _swipeTouchStartX = nil; return end  -- drag takes priority
    if input.UserInputType ~= Enum.UserInputType.Touch and
       input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local cx, cy
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        local mloc = UserInputService:GetMouseLocation()
        cx = mloc.X; cy = mloc.Y
    else
        cx = input.Position.X; cy = input.Position.Y
    end
    touchDeltaX = cx - _swipeTouchStartX
    touchDeltaY = cy - _swipeTouchStartY
    local absDx, absDy = math.abs(touchDeltaX), math.abs(touchDeltaY)
    if not _swipeActive and (absDx > 12 or absDy > 12) then
        if absDx > absDy * 1.5 then _swipeActive = true else _swipeTouchStartX = nil end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if not _swipeTouchStartX then return end
    if input.UserInputType ~= Enum.UserInputType.Touch and
       input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if _swipeActive then
        if touchDeltaX < -35 and currentPage < totalPages then
            goToPage(currentPage + 1)
        elseif touchDeltaX > 35 and currentPage > 1 then
            goToPage(currentPage - 1)
        end
    end
    _swipeTouchStartX = nil
    _swipeTouchStartY = nil
    _swipeActive      = false
end)

local pageKeyDebounce = false
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if isMinimized then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode ~= Enum.KeyCode.K and input.KeyCode ~= Enum.KeyCode.Six then return end
    if pageKeyDebounce then return end
    if input.KeyCode == Enum.KeyCode.K then
        if currentPage < totalPages then
            pageKeyDebounce = true
            goToPage(currentPage + 1)
            task.delay(0.35, function() pageKeyDebounce = false end)
        end
    elseif input.KeyCode == Enum.KeyCode.Six then
        if currentPage > 1 then
            pageKeyDebounce = true
            goToPage(currentPage - 1)
            task.delay(0.35, function() pageKeyDebounce = false end)
        end
    end
end)

local scrollDebounce = false
UserInputService.InputChanged:Connect(function(input)
    if isMinimized then return end
    if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
    local mousePos = UserInputService:GetMouseLocation()
    if not isInsideFrame(mainFrame, mousePos.X, mousePos.Y) then return end
    if scrollDebounce then return end
    if input.Position.Z < 0 then
        if currentPage < totalPages then
            scrollDebounce = true
            goToPage(currentPage + 1)
            task.delay(0.4, function() scrollDebounce = false end)
        end
    elseif input.Position.Z > 0 then
        if currentPage > 1 then
            scrollDebounce = true
            goToPage(currentPage - 1)
            task.delay(0.4, function() scrollDebounce = false end)
        end
    end
end)

local function createToggleOption(name, text, callback)
    local frame = makeUI(optionsFrame, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 35),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0
    })
    makeUI(frame, "UICorner", {CornerRadius = UDim.new(0, 8)})
    makeUI(frame, "TextLabel", {
        Text = text, Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 13,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.65, 0, 1, 0),
        Position = UDim2.new(0.03, 0, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left
    })
    local toggleTrack = makeUI(frame, "Frame", {
        Size = UDim2.new(0, 50, 0, 24),
        Position = UDim2.new(1, -58, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.fromRGB(70, 70, 70),
        BorderSizePixel = 0
    })
    makeUI(toggleTrack, "UICorner", {CornerRadius = UDim.new(1, 0)})
    local innerShadow = makeUI(toggleTrack, "Frame", {
        Size = UDim2.new(1, -4, 1, -4),
        Position = UDim2.new(0, 2, 0, 2),
        BackgroundColor3 = Color3.fromRGB(20, 20, 20),
        BackgroundTransparency = 0.6,
        BorderSizePixel = 0, ZIndex = 1
    })
    makeUI(innerShadow, "UICorner", {CornerRadius = UDim.new(1, 0)})
    local knob = makeUI(toggleTrack, "Frame", {
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(0, 2, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0, ZIndex = 3
    })
    makeUI(knob, "UICorner", {CornerRadius = UDim.new(1, 0)})
    local knobGlow = makeUI(knob, "ImageLabel", {
        Size = UDim2.new(1, 8, 1, 8),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Image = "rbxassetid://5028857084",
        ImageColor3 = Color3.fromRGB(255, 255, 255),
        ImageTransparency = 0.85,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(24, 24, 276, 276),
        ZIndex = 2
    })
    local toggled = false
    local toggleBtn = makeUI(toggleTrack, "TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = "",
        ZIndex = 4
    })
    toggleBtn.MouseButton1Click:Connect(function()
        toggled = not toggled
        UIState.Toggles[name] = toggled
        if toggled then
            TweenService:Create(toggleTrack, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(50, 180, 50)}):Play()
            TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = UDim2.new(1, -22, 0.5, 0)}):Play()
            TweenService:Create(knobGlow, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(50, 220, 50), ImageTransparency = 0.6}):Play()
        else
            TweenService:Create(toggleTrack, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(70, 70, 70)}):Play()
            TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = UDim2.new(0, 2, 0.5, 0)}):Play()
            TweenService:Create(knobGlow, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(255, 255, 255), ImageTransparency = 0.85}):Play()
        end
        if callback then callback(toggled) end
    end)
    UIState.Toggles[name] = false
    return {frame = frame, toggleBtn = toggleBtn}
end

local function createSlider(name, min, max, default, step, callback)
    step = step or 1
    local frame = makeUI(optionsFrame, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 36),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0
    })
    makeUI(frame, "UICorner", {CornerRadius = UDim.new(0, 6)})
    makeUI(frame, "TextLabel", {
        Text = name, Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 12,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.35, 0, 1, 0),
        Position = UDim2.new(0.03, 0, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left
    })
    local sliderFrame = makeUI(frame, "Frame", {
        Size = UDim2.new(0.55, 0, 0.35, 0),
        Position = UDim2.new(0.42, 0, 0.35, 0),
        BackgroundColor3 = Color3.fromRGB(60, 60, 60),
        Active = true
    })
    makeUI(sliderFrame, "UICorner", {CornerRadius = UDim.new(0, 4)})
    local handle = makeUI(sliderFrame, "Frame", {
        Size = UDim2.new(0, 12, 1, 0),
        BackgroundColor3 = Color3.fromRGB(50, 150, 50),
        Active = true
    })
    makeUI(handle, "UICorner", {CornerRadius = UDim.new(0, 6)})
    local valueLabel = makeUI(frame, "TextLabel", {
        Text = tostring(default), Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 12,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.15, 0, 1, 0),
        Position = UDim2.new(0.88, 0, 0, 0)
    })
    local rel = (default - min) / (max - min)
    handle.Position = UDim2.new(rel, 0, 0, 0)
    local function valueToColor(val)
        local t = (val - min) / (max - min)
        if t < 0.5 then
            local f = t / 0.5
            return Color3.fromRGB(50 + 205 * f, 150 + 105 * f, 50)
        else
            local f = (t - 0.5) / 0.5
            return Color3.fromRGB(255, 255 - 255 * f, 50)
        end
    end
    local draggingSlider = false
    local function updateSlider(input)
        local r = math.clamp((input.Position.X - sliderFrame.AbsolutePosition.X) / sliderFrame.AbsoluteSize.X, 0, 1)
        r = math.floor(r * (max - min) / step + 0.5) * step / (max - min)
        handle.Position = UDim2.new(r, 0, 0, 0)
        local value = min + r * (max - min)
        valueLabel.Text = tostring(math.floor(value))
        handle.BackgroundColor3 = valueToColor(value)
        UIState.Sliders[name] = value
        if callback then callback(value) end
    end
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = true; updateSlider(input)
        end
    end)
    handle.InputEnded:Connect(function() draggingSlider = false end)
    sliderFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            draggingSlider = true; updateSlider(input)
        end
    end)
    sliderFrame.InputEnded:Connect(function() draggingSlider = false end)
    UserInputService.InputChanged:Connect(function(input)
        if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input)
        end
    end)
    UIState.Sliders[name] = default
    return {frame = frame, valueLabel = valueLabel}
end

local function createTextBox(name, placeholder, callback, autoClear)
    local frame = makeUI(optionsFrame, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 32),
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        BorderSizePixel = 0
    })
    makeUI(frame, "UICorner", {CornerRadius = UDim.new(0, 8)})
    makeUI(frame, "TextLabel", {
        Text = name, Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 12,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.35, 0, 1, 0),
        Position = UDim2.new(0.03, 0, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left
    })
    local box = makeUI(frame, "TextBox", {
        Size = UDim2.new(0.6, 0, 0.75, 0),
        Position = UDim2.new(0.38, 0, 0.125, 0),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        TextColor3 = Color3.fromRGB(150, 150, 150),
        PlaceholderText = placeholder,
        Font = Enum.Font.Gotham, TextSize = 12,
        ClearTextOnFocus = false, BorderSizePixel = 0,
        TextWrapped = false
    })
    makeUI(box, "UICorner", {CornerRadius = UDim.new(0, 6)})
    local defaultText = placeholder
    box.Text = defaultText
    box.Focused:Connect(function()
        TweenService:Create(box, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(60, 60, 60)}):Play()
        if box.Text == defaultText then box.Text = ""; box.TextColor3 = Color3.fromRGB(255, 255, 255) end
    end)
    box.FocusLost:Connect(function(enterPressed)
        TweenService:Create(box, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40, 40, 40)}):Play()
        if enterPressed and callback then
            callback(box.Text)
            if autoClear then box.Text = defaultText; box.TextColor3 = Color3.fromRGB(150, 150, 150) end
        end
        if box.Text == "" then box.Text = defaultText; box.TextColor3 = Color3.fromRGB(150, 150, 150) end
        UIState.Texts[name] = box.Text
    end)
    UIState.Texts[name] = ""
    return box
end

local function createDropdown(name, options, callback)
    local dropdownContainer = makeUI(optionsFrame, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 62),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0, ClipsDescendants = false
    })
    makeUI(dropdownContainer, "UICorner", {CornerRadius = UDim.new(0, 8)})
    makeUI(dropdownContainer, "TextLabel", {
        Text = name, Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 11,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -12, 0, 18),
        Position = UDim2.new(0, 8, 0, 4),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    })
    local dropdownBtnFrame = makeUI(dropdownContainer, "Frame", {
        Size = UDim2.new(1, -76, 0, 26),
        Position = UDim2.new(0, 6, 0, 28),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40), BackgroundTransparency = 0.2, BorderSizePixel = 0
    })
    makeUI(dropdownBtnFrame, "UICorner", {CornerRadius = UDim.new(0, 6)})
    makeUI(dropdownBtnFrame, "UIStroke", {Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.4})
    local selectedEmoteLabel = makeUI(dropdownBtnFrame, "TextLabel", {
        Text = "Select Emote...", Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 10,
        BackgroundTransparency = 1, Size = UDim2.new(0.8, 0, 1, 0),
        Position = UDim2.new(0.04, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    })
    local arrow = makeUI(dropdownBtnFrame, "TextLabel", {
        Text = "▼", Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 10,
        BackgroundTransparency = 1, Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -22, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Center
    })
    local dropdownButton = makeUI(dropdownBtnFrame, "TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        AutoButtonColor = false, Text = ""
    })
    local playButton = makeUI(dropdownContainer, "TextButton", {
        Size = UDim2.new(0, 56, 0, 26),
        Position = UDim2.new(1, -62, 0, 28),
        BackgroundColor3 = Color3.fromRGB(80, 80, 80),
        Text = "Play", TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold, TextSize = 10,
        BorderSizePixel = 0
    })
    makeUI(playButton, "UICorner", {CornerRadius = UDim.new(0, 6)})
    local listWidth = UDim2.new(1, -12, 0, 0)
    local outerDropFrame = makeUI(dropdownContainer, "Frame", {
        Size = listWidth,
        Position = UDim2.new(0, 6, 1, 4),
        BackgroundColor3 = Color3.fromRGB(32, 32, 32),
        BorderSizePixel = 0,
        Visible = false, ZIndex = 20,
        ClipsDescendants = true
    })
    makeUI(outerDropFrame, "UICorner", {CornerRadius = UDim.new(0, 6)})
    makeUI(outerDropFrame, "UIStroke", {Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.5})

    local isOpen = false
    local selectedOption = nil
    local itemHeight = 26
    local itemPadding = 2
    local maxVisibleItems = 5

    local searchBoxHeight = 28
    local searchBox = makeUI(outerDropFrame, "TextBox", {
        Size = UDim2.new(1, -8, 0, searchBoxHeight),
        Position = UDim2.new(0, 4, 0, 4),
        BackgroundColor3 = Color3.fromRGB(55, 55, 55),
        PlaceholderText = "Search emote...",
        PlaceholderColor3 = Color3.fromRGB(130, 130, 130),
        Text = "",
        TextColor3 = Color3.fromRGB(220, 220, 220),
        Font = Enum.Font.Gotham, TextSize = 10,
        BorderSizePixel = 0,
        ZIndex = 22,
        ClearTextOnFocus = false,
    })
    makeUI(searchBox, "UICorner", {CornerRadius = UDim.new(0, 6)})
    makeUI(searchBox, "UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 6)})

    local optionsList = makeUI(outerDropFrame, "ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -(searchBoxHeight + 8)),
        Position = UDim2.new(0, 0, 0, searchBoxHeight + 8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100),
        ZIndex = 20,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true
    })
    local optionsListLayout = makeUI(optionsList, "UIListLayout", {
        Padding = UDim.new(0, 2),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder
    })
    optionsListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        optionsList.CanvasSize = UDim2.new(0, 0, 0, optionsListLayout.AbsoluteContentSize.Y + 4)
    end)

    -- ============================================================
    -- CARD STYLE EMOTE LIST
    -- Setiap item = card: thumbnail kiri | nama + creator + harga
    -- ============================================================
    local CARD_H       = 64   -- tinggi tiap card
    local CARD_PAD     = 5    -- jarak antar card
    local MAX_VIS_CARD = 4    -- max card terlihat sebelum scroll
    local PAGE_SIZE    = 10   -- Load More per batch

    local emptyLabel = makeUI(optionsList, "TextLabel", {
        Size = UDim2.new(0.96, 0, 0, CARD_H),
        BackgroundTransparency = 1,
        Text = "No results",
        TextColor3 = Color3.fromRGB(130, 130, 130),
        Font = Enum.Font.Gotham, TextSize = 10,
        BorderSizePixel = 0, ZIndex = 21,
        Visible = false, LayoutOrder = 1
    })

    local optionButtons  = {}   -- { card=Frame, option=table }
    local currentPage    = 1
    local filteredList   = {}

    -- Load More button (dalam scrollframe, di bawah cards)
    local loadMoreCard = makeUI(optionsList, "Frame", {
        Size = UDim2.new(0.96, 0, 0, 32),
        BackgroundColor3 = Color3.fromRGB(45, 45, 45),
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        ZIndex = 21,
        Visible = false,
        LayoutOrder = 99999
    })
    makeUI(loadMoreCard, "UICorner", {CornerRadius = UDim.new(0, 8)})
    makeUI(loadMoreCard, "UIStroke", {Color = Color3.fromRGB(70,70,70), Thickness = 1, Transparency = 0.4})
    local loadMoreBtn = makeUI(loadMoreCard, "TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0, AutoButtonColor = false,
        Text = "Load More",
        TextColor3 = Color3.fromRGB(200, 200, 200),
        Font = Enum.Font.GothamBold, TextSize = 11,
        ZIndex = 22
    })

    -- Buat satu emote card
    local function makeEmoteCard(option, layoutOrder)
        local imgId    = tostring(option.imageId or option.id)
        local thumbUrl = "rbxthumb://type=Asset&id=" .. imgId .. "&w=150&h=150"
        local priceStr = (option.price and option.price > 0) and (tostring(option.price) .. " R$") or "Free"
        local creator  = option.creator or "QUICK UGC!"

        local card = makeUI(optionsList, "Frame", {
            Size = UDim2.new(0.96, 0, 0, CARD_H),
            BackgroundColor3 = Color3.fromRGB(28, 28, 28),
            BackgroundTransparency = 0.05,
            BorderSizePixel = 0,
            ZIndex = 21,
            LayoutOrder = layoutOrder
        })
        makeUI(card, "UICorner", {CornerRadius = UDim.new(0, 10)})
        makeUI(card, "UIStroke", {Color = Color3.fromRGB(55,55,55), Thickness = 1, Transparency = 0.3, ZIndex = 22})

        -- Thumbnail kiri
        local thumbFrame = makeUI(card, "Frame", {
            Size = UDim2.new(0, 52, 0, 52),
            Position = UDim2.new(0, 6, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Color3.fromRGB(20, 20, 20),
            BorderSizePixel = 0, ZIndex = 22
        })
        makeUI(thumbFrame, "UICorner", {CornerRadius = UDim.new(0, 8)})
        makeUI(thumbFrame, "UIStroke", {Color = Color3.fromRGB(60,60,60), Thickness = 1, Transparency = 0.4})
        makeUI(thumbFrame, "ImageLabel", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Image = thumbUrl,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 23
        })

        -- Nama emote (putih bold)
        makeUI(card, "TextLabel", {
            Text = option.n,
            Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextSize = 12,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 120, 0, 16),
            Position = UDim2.new(0, 64, 0, 7),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 22
        })

        -- Creator (biru)
        makeUI(card, "TextLabel", {
            Text = "@" .. creator:gsub("^@", ""),
            Font = Enum.Font.Gotham,
            TextColor3 = Color3.fromRGB(80, 160, 255),
            TextSize = 10,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 120, 0, 14),
            Position = UDim2.new(0, 64, 0, 25),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 22
        })

        -- Harga (kuning bold)
        makeUI(card, "TextLabel", {
            Text = priceStr,
            Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(255, 210, 60),
            TextSize = 11,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 80, 0, 14),
            Position = UDim2.new(0, 64, 0, 41),
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 22
        })

        -- Hitbox klik (pilih emote, tutup dropdown)
        local hitbox = makeUI(card, "TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0, AutoButtonColor = false,
            Text = "", ZIndex = 24
        })
        hitbox.MouseEnter:Connect(function()
            TweenService:Create(card, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(40,40,40)}):Play()
        end)
        hitbox.MouseLeave:Connect(function()
            TweenService:Create(card, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(28,28,28)}):Play()
        end)
        hitbox.MouseButton1Click:Connect(function()
            selectedOption = option
            selectedEmoteLabel.Text = option.n
            selectedEmoteLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            isOpen = false
            searchBox.Text = ""
            searchBox.TextEditable = false
            TweenService:Create(outerDropFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = listWidth}):Play()
            TweenService:Create(arrow, TweenInfo.new(0.2), {Rotation = 0}):Play()
            task.delay(0.21, function()
                outerDropFrame.Visible = false
                outerDropFrame.Size = listWidth
                uiBlur.Enabled = true
                if callback then callback(option) end
            end)
        end)

        return card
    end

    -- Render cards sesuai filter & halaman
    local function renderCards()
        -- Hapus semua card lama (kecuali emptyLabel & loadMoreCard)
        for _, entry in ipairs(optionButtons) do
            if entry.card and entry.card.Parent then entry.card:Destroy() end
        end
        optionButtons = {}

        local q = searchBox.Text:lower():match("^%s*(.-)%s*$")
        filteredList = {}
        for _, opt in ipairs(options) do
            if q == "" or opt.n:lower():find(q, 1, true)
                or (opt.creator or ""):lower():find(q, 1, true)
            then
                table.insert(filteredList, opt)
            end
        end

        local total     = #filteredList
        local showCount = math.min(currentPage * PAGE_SIZE, total)

        emptyLabel.Visible   = (total == 0)
        loadMoreCard.Visible = (showCount < total)
        if loadMoreCard.Visible then
            loadMoreBtn.Text = "Load More  (" .. (total - showCount) .. " remaining)"
            loadMoreCard.LayoutOrder = 99999
        end

        for i = 1, showCount do
            local card = makeEmoteCard(filteredList[i], i + 1)
            table.insert(optionButtons, {card = card, option = filteredList[i]})
        end

        -- Hitung tinggi dropdown
        local visCards  = math.min(showCount + (total == 0 and 1 or 0), MAX_VIS_CARD)
        local extraLoad = loadMoreCard.Visible and (32 + CARD_PAD) or 0
        local newH      = searchBoxHeight + 8 + 4
                        + visCards * CARD_H
                        + math.max(visCards - 1, 0) * CARD_PAD
                        + extraLoad + 8
        TweenService:Create(outerDropFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            Size = UDim2.new(1, -12, 0, newH)
        }):Play()
    end

    loadMoreBtn.MouseButton1Click:Connect(function()
        currentPage = currentPage + 1
        renderCards()
    end)

    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        currentPage = 1
        renderCards()
    end)

    local function closeDropdown()
        isOpen = false
        searchBox.Text = ""
        searchBox.TextEditable = false
        TweenService:Create(outerDropFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = listWidth}):Play()
        TweenService:Create(arrow, TweenInfo.new(0.18), {Rotation = 0}):Play()
        task.delay(0.19, function()
            outerDropFrame.Visible = false
            outerDropFrame.Size = listWidth
            uiBlur.Enabled = true
        end)
    end

    local function getTargetHeight()
        local visCards = math.min(#options, MAX_VIS_CARD)
        return searchBoxHeight + 8 + 4 + visCards * CARD_H + math.max(visCards-1,0) * CARD_PAD + 8
    end

    -- Saat dropdown dibuka, kalau EmoteList belum siap tunggu dulu
    dropdownButton.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        if isOpen then
            uiBlur.Enabled = false
            outerDropFrame.Size = listWidth
            outerDropFrame.Visible = true
            searchBox.TextEditable = true
            TweenService:Create(arrow, TweenInfo.new(0.2), {Rotation = 180}):Play()
            if _emoteListLoaded then
                renderCards()
                TweenService:Create(outerDropFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, -12, 0, getTargetHeight())}):Play()
            else
                -- Tampilkan loading sementara
                emptyLabel.Text    = "Loading emotes..."
                emptyLabel.Visible = true
                local loadH = searchBoxHeight + 8 + 4 + CARD_H + 8
                TweenService:Create(outerDropFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, -12, 0, loadH)}):Play()
                _onEmoteListReady(function()
                    emptyLabel.Text    = "No results"
                    emptyLabel.Visible = false
                    if isOpen then renderCards() end
                end)
            end
        else
            closeDropdown()
        end
    end)
    playButton.MouseButton1Click:Connect(function()
        if selectedOption then
            if currentPlayButton == playButton and currentAnimationTrack then
                stopCurrentAnimation()
            else
                playAnimation(selectedOption, playButton)
            end
        else
            game.StarterGui:SetCore("SendNotification", {
                Title = "No Emote Selected";
                Text = "Please select an emote first!";
                Duration = 3;
            })
        end
    end)
    UIState.Dropdowns[name] = selectedOption
    return {container = dropdownContainer, button = dropdownButton, list = optionsList, playButton = playButton}
end

local function createPlaylistDropdown(songs, DEFAULT_COUNT, callbacks)
    -- Outer wrapper: clipsDescendants=false agar expand tidak terpotong UIListLayout
    local dropdownContainer = makeUI(optionsFrame6, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 62),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0, ClipsDescendants = false,
        ZIndex = 2
    })
    makeUI(dropdownContainer, "UICorner", {CornerRadius = UDim.new(0, 8)})

    makeUI(dropdownContainer, "TextLabel", {
        Text = "Playlist", Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(150, 150, 150), TextSize = 10,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -12, 0, 18),
        Position = UDim2.new(0, 8, 0, 4),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 3
    })

    local dropdownButton = makeUI(dropdownContainer, "TextButton", {
        Size = UDim2.new(1, -12, 0, 26),
        Position = UDim2.new(0, 6, 0, 28),
        BackgroundColor3 = Color3.fromRGB(50, 50, 50),
        Text = "",
        TextColor3 = Color3.fromRGB(200, 200, 200),
        Font = Enum.Font.Gotham, TextSize = 10,
        BorderSizePixel = 0,
        ClipsDescendants = false,
        ZIndex = 3
    })
    makeUI(dropdownButton, "UICorner", {CornerRadius = UDim.new(0, 6)})

    local dropIconImg = makeUI(dropdownButton, "ImageLabel", {
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new(0, 7, 0.5, -8),
        BackgroundTransparency = 1,
        Image = songs[1] and songs[1].Icon or "",
        ZIndex = 6
    })

    local dropLabel = makeUI(dropdownButton, "TextLabel", {
        Size = UDim2.new(1, -50, 1, 0),
        Position = UDim2.new(0, 30, 0, 0),
        BackgroundTransparency = 1,
        Text = songs[1] and songs[1].Name or "No songs",
        Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(220, 220, 220),
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
        ZIndex = 6
    })

    -- Arrow chevron (teks ▼/▲)
    local arrow = makeUI(dropdownButton, "TextLabel", {
        Size = UDim2.new(0, 18, 0, 18),
        Position = UDim2.new(1, -22, 0.5, -9),
        BackgroundTransparency = 1,
        Text = "▼",
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(180, 180, 180),
        TextSize = 9,
        ZIndex = 6
    })

    local itemHeight = 26
    local itemPadding = 2
    local maxVisibleItems = 5

    -- ScrollingFrame inline, child dari dropdownContainer, muncul di bawah button
    local optionsList = makeUI(dropdownContainer, "ScrollingFrame", {
        Size = UDim2.new(1, -12, 0, 0),
        Position = UDim2.new(0, 6, 0, 58),  -- tepat di bawah dropdownButton (28+26+4)
        BackgroundColor3 = Color3.fromRGB(32, 32, 32),
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100),
        Visible = false, ZIndex = 10,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true
    })
    makeUI(optionsList, "UICorner", {CornerRadius = UDim.new(0, 6)})
    makeUI(optionsList, "UIStroke", {Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.5})
    local optionsListLayout = makeUI(optionsList, "UIListLayout", {
        Padding = UDim.new(0, 2),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder
    })
    makeUI(optionsList, "UIPadding", {
        PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3)
    })
    optionsListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        optionsList.CanvasSize = UDim2.new(0, 0, 0, optionsListLayout.AbsoluteContentSize.Y + 6)
    end)

    local isOpen = false

    -- Hitung tinggi list dan update ukuran container secara inline
    local function updateInlineSize(visible)
        local count = 0
        for _, child in ipairs(optionsList:GetChildren()) do
            if child:IsA("TextButton") or child:IsA("Frame") then
                count = count + 1
            end
        end
        local visibleCount = math.min(count, maxVisibleItems)
        if visibleCount < 1 then visibleCount = 1 end
        local listH = visibleCount * itemHeight + (visibleCount - 1) * itemPadding + 6
        if visible then
            optionsList.Size = UDim2.new(1, -12, 0, listH)
            dropdownContainer.Size = UDim2.new(0.95, 0, 0, 62 + listH + 4)
        else
            optionsList.Size = UDim2.new(1, -12, 0, 0)
            dropdownContainer.Size = UDim2.new(0.95, 0, 0, 62)
        end
        -- Update CanvasSize parent agar scrolling frame optionsFrame6 menyesuaikan
        task.defer(function()
            optionsFrame6.CanvasSize = UDim2.new(0, 0, 0, layout6.AbsoluteContentSize.Y + 8)
        end)
    end

    local function rebuildItems(songsList, defCount, cbs)
        for _, child in ipairs(optionsList:GetChildren()) do
            if child:IsA("TextButton") or (child:IsA("Frame") and child.Name ~= "") then
                child:Destroy()
            end
        end

        local visibleCount = math.min(#songsList, maxVisibleItems)
        local targetH = visibleCount * itemHeight + (visibleCount - 1) * itemPadding + 6

        local renderOrder = {}
        for i = #songsList, defCount + 1, -1 do
            table.insert(renderOrder, i)
        end
        for i = 1, defCount do
            table.insert(renderOrder, i)
        end

        for order, i in ipairs(renderOrder) do
            local song = songsList[i]
            if song then
            local isCustom = (i > defCount)
            local optionButton = makeUI(optionsList, "TextButton", {
                Size = UDim2.new(0.96, 0, 0, itemHeight),
                BackgroundColor3 = Color3.fromRGB(45, 45, 45),
                Text = "",
                TextColor3 = Color3.fromRGB(200, 200, 200),
                Font = Enum.Font.Gotham, TextSize = 10,
                BorderSizePixel = 0,
                TextXAlignment = Enum.TextXAlignment.Left,
                LayoutOrder = order,
                ZIndex = 21
            })
            makeUI(optionButton, "UICorner", {CornerRadius = UDim.new(0, 4)})

            makeUI(optionButton, "ImageLabel", {
                Size = UDim2.new(0, 14, 0, 14),
                Position = UDim2.new(0, 7, 0.5, -7),
                BackgroundTransparency = 1, Image = song.Icon, ZIndex = 23
            })

            local labelRightPad = isCustom and 28 or 6
            makeUI(optionButton, "TextLabel", {
                Size = UDim2.new(1, -(28 + labelRightPad), 1, 0),
                Position = UDim2.new(0, 28, 0, 0),
                BackgroundTransparency = 1, Text = song.Name,
                Font = Enum.Font.Gotham,
                TextColor3 = Color3.fromRGB(210, 210, 210),
                TextSize = 10,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 22
            })

            local delBtn = nil
            if isCustom then
                delBtn = makeUI(optionButton, "TextButton", {
                    Size = UDim2.new(0, 16, 0, 16),
                    Position = UDim2.new(1, -20, 0.5, -8),
                    BackgroundColor3 = Color3.fromRGB(160, 50, 50),
                    BackgroundTransparency = 0.3, BorderSizePixel = 0,
                    Text = "x", Font = Enum.Font.GothamBold,
                    TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 9, ZIndex = 25,
                    Active = true, AutoButtonColor = false
                })
                makeUI(delBtn, "UICorner", {CornerRadius = UDim.new(1, 0)})
                delBtn.MouseEnter:Connect(function()
                    TweenService:Create(delBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(200, 60, 60)}):Play()
                end)
                delBtn.MouseLeave:Connect(function()
                    TweenService:Create(delBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(160, 50, 50)}):Play()
                end)
                local idx = i
                delBtn.MouseButton1Click:Connect(function()
                    if cbs and cbs.onDelete then cbs.onDelete(idx) end
                end)
            end

            optionButton.MouseEnter:Connect(function()
                TweenService:Create(optionButton, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(62, 62, 62)}):Play()
            end)
            optionButton.MouseLeave:Connect(function()
                TweenService:Create(optionButton, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(45, 45, 45)}):Play()
            end)

            local idx = i
            optionButton.MouseButton1Click:Connect(function()
                if delBtn then
                    local mouse = UserInputService:GetMouseLocation()
                    local abs = delBtn.AbsolutePosition
                    local sz = delBtn.AbsoluteSize
                    if mouse.X >= abs.X and mouse.X <= abs.X + sz.X and
                       mouse.Y >= abs.Y and mouse.Y <= abs.Y + sz.Y then
                        return
                    end
                end
                dropIconImg.Image = song.Icon
                dropLabel.Text = song.Name
                isOpen = false
                optionsList.Visible = false
                updateInlineSize(false)
                arrow.Text = "▼"
                if cbs and cbs.onSelect then cbs.onSelect(idx, song) end
            end)
            end
        end

        return targetH
    end

    rebuildItems(songs, DEFAULT_COUNT, callbacks)

    local function getTargetHeight()
        local count = math.min(#songs, maxVisibleItems)
        return count * itemHeight + (count - 1) * itemPadding + 6
    end

    dropdownButton.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        if isOpen then
            optionsList.Visible = true
            updateInlineSize(true)
            arrow.Text = "▲"
        else
            optionsList.Visible = false
            updateInlineSize(false)
            arrow.Text = "▼"
        end
    end)

    UserInputService.InputBegan:Connect(function(input)
        if isOpen and (input.UserInputType == Enum.UserInputType.MouseButton1
                    or input.UserInputType == Enum.UserInputType.Touch) then
            local mousePos = UserInputService:GetMouseLocation()
            local listPos  = optionsList.AbsolutePosition
            local listSize = optionsList.AbsoluteSize
            local inList = mousePos.X >= listPos.X and mousePos.X <= listPos.X + listSize.X
                       and mousePos.Y >= listPos.Y and mousePos.Y <= listPos.Y + listSize.Y
            local btnPos  = dropdownButton.AbsolutePosition
            local btnSize = dropdownButton.AbsoluteSize
            local inBtn = mousePos.X >= btnPos.X and mousePos.X <= btnPos.X + btnSize.X
                      and mousePos.Y >= btnPos.Y and mousePos.Y <= btnPos.Y + btnSize.Y
            if not inList and not inBtn then
                isOpen = false
                optionsList.Visible = false
                updateInlineSize(false)
                arrow.Text = "▼"
            end
        end
    end)

    local api = {}

    function api.setCurrentSong(idx, songsList)
        local s = (songsList or songs)[idx]
        if s then
            dropIconImg.Image = s.Icon
            dropLabel.Text = s.Name
        end
    end

    function api.rebuild(newSongs, newDefaultCount, newCallbacks)
        songs = newSongs
        DEFAULT_COUNT = newDefaultCount
        callbacks = newCallbacks
        rebuildItems(newSongs, newDefaultCount, newCallbacks)
        if isOpen then updateInlineSize(true) end
    end

    function api.close()
        if isOpen then
            isOpen = false
            optionsList.Visible = false
            updateInlineSize(false)
            arrow.Text = "▼"
        end
    end

    api.container      = dropdownContainer
    api.button         = dropdownButton
    api.list           = optionsList
    api.arrow          = arrow
    api.iconImg        = dropIconImg
    api.nameLabel      = dropLabel

    return api
end

if LocalPlayer.Character then
    local HUM = LocalPlayer.Character:FindFirstChild("Humanoid")
    if HUM then AC_ORIGINAL_DESC = HUM:GetAppliedDescription() end
end

local function ac_setStatus(text, color)
    if ac_statusLabel then
        ac_statusLabel.Text = "Status: " .. text
        ac_statusLabel.TextColor3 = color or Color3.fromRGB(145, 145, 145)
    end
end

local function acc_setStatus(text, color)
    if acc_statusLabel then
        acc_statusLabel.Text = "Status: " .. text
        acc_statusLabel.TextColor3 = color or Color3.fromRGB(145, 145, 145)
    end
end

-- Terapkan HumanoidDescription secara LOCAL-ONLY (client-side saja).
-- Tidak memanggil Humanoid:ApplyDescription() sama sekali, jadi tidak akan
-- pernah kena error "can only be called by the backend server" dan
-- perubahan HANYA terlihat di layar sendiri (player lain tidak melihat apapun).
local function LocalApplyDescription(char, desc)
    if not char or not desc then return end
    local HUM = char:FindFirstChildOfClass("Humanoid")
    if not HUM then return end

    -- Body colors
    pcall(function()
        local bc = char:FindFirstChildOfClass("BodyColors")
        if not bc then
            bc = Instance.new("BodyColors")
            bc.Parent = char
        end
        bc.HeadColor3     = desc.HeadColor  or bc.HeadColor3
        bc.TorsoColor3    = desc.TorsoColor or bc.TorsoColor3
        bc.LeftArmColor3  = desc.LeftArmColor  or bc.LeftArmColor3
        bc.RightArmColor3 = desc.RightArmColor or bc.RightArmColor3
        bc.LeftLegColor3  = desc.LeftLegColor  or bc.LeftLegColor3
        bc.RightLegColor3 = desc.RightLegColor or bc.RightLegColor3
    end)

    -- Body scale (height/width/head/proportion/bodytype) via Humanoid scale values
    pcall(function()
        local scaleProps = {
            {desc = "HeightScale",     inst = "BodyHeightScale"},
            {desc = "WidthScale",      inst = "BodyWidthScale"},
            {desc = "HeadScale",       inst = "BodyHeadScale"},
            {desc = "BodyTypeScale",   inst = "BodyTypeScale"},
            {desc = "ProportionScale", inst = "BodyProportionScale"},
        }
        for _, sp in ipairs(scaleProps) do
            local val = desc[sp.desc]
            if val ~= nil then
                local sv = HUM:FindFirstChild(sp.inst)
                if not sv then
                    sv = Instance.new("NumberValue")
                    sv.Name = sp.inst
                    sv.Parent = HUM
                end
                pcall(function() sv.Value = val end)
            end
        end
    end)

    -- Face decal
    pcall(function()
        if desc.Face and tostring(desc.Face) ~= "" and tostring(desc.Face) ~= "0" then
            local head = char:FindFirstChild("Head")
            if head then
                local ok, objs = pcall(function()
                    return game:GetObjects("rbxassetid://" .. tostring(desc.Face))
                end)
                local texId = nil
                if ok and objs and #objs > 0 then
                    local function deepFindDecal(root)
                        if root:IsA("Decal") then return root end
                        for _, d in ipairs(root:GetDescendants()) do
                            if d:IsA("Decal") then return d end
                        end
                        return nil
                    end
                    for _, obj in ipairs(objs) do
                        local dec = deepFindDecal(obj)
                        if dec then texId = dec.Texture; break end
                    end
                end
                if texId then
                    local faceDecal = head:FindFirstChild("face") or head:FindFirstChildOfClass("Decal")
                    if not faceDecal then
                        faceDecal = Instance.new("Decal")
                        faceDecal.Name = "face"
                        faceDecal.Parent = head
                    end
                    faceDecal.Texture = texId
                end
            end
        end
    end)

end

AC_MORPHCHAR = function(char, name, id, desc)
    task.spawn(function()
        xpcall(function()
            local HUM = char:WaitForChild("Humanoid", 5)
            if not HUM then return end

            local HRP = char:FindFirstChild("HumanoidRootPart")
            local savedCF = HRP and HRP.CFrame
            startPositionLock(char, 2.5)

            for _, v in ipairs(char:GetChildren()) do
                if v:IsA("Accessory") or v:IsA("Hat")
                or v:IsA("Shirt") or v:IsA("Pants")
                or v:IsA("ShirtGraphic") or v:IsA("CharacterMesh")
                or v:IsA("BodyColors") then
                    v:Destroy()
                end
            end

            -- Bersihkan decal wajah default Roblox di Head supaya tidak nampang
            -- di belakang/di depan Face Accessory UGC yang baru dipasang.
            pcall(function()
                local head = char:FindFirstChild("Head")
                if head then
                    for _, d in ipairs(head:GetChildren()) do
                        if d:IsA("Decal") then
                            d:Destroy()
                        end
                    end
                end
            end)

            LocalApplyDescription(char, desc)
            HUM.DisplayName = name

            task.wait(0.05)
            local hrpPost = char:FindFirstChild("HumanoidRootPart")
            if hrpPost and hrpPost.Parent then
                pcall(function() hrpPost.CFrame = savedCF end)
            end

            local InsertService = game:GetService("InsertService")

            local function insertAsset(assetId)
                if not assetId or assetId == 0 then return end
                local ok, model = pcall(function()
                    return LoadAssetLocal(assetId)
                end)
                if ok and model then
                    local movedAny = false
                    for _, child in ipairs(model:GetChildren()) do
                        if child:IsA("Accessory") or child:IsA("Hat") then
                            AttachAccessoryLocal(char, child)
                        else
                            child.Parent = char
                        end
                        movedAny = true
                    end
                    model:Destroy()
                    if movedAny then return end
                else
                end
            end

            if desc.Shirt and desc.Shirt ~= 0 then
                insertAsset(desc.Shirt)
            end
            if desc.Pants and desc.Pants ~= 0 then
                insertAsset(desc.Pants)
            end
            if desc.GraphicTShirt and desc.GraphicTShirt ~= 0 then
                insertAsset(desc.GraphicTShirt)
            end

            local accIds = {}
            local seenAcc = {}
            local ok_ga, accList = pcall(function() return desc:GetAccessories(true) end)
            if ok_ga and accList then
                for _, info in ipairs(accList) do
                    if info.AssetId and info.AssetId ~= 0 and not seenAcc[info.AssetId] then
                        seenAcc[info.AssetId] = true
                        table.insert(accIds, info.AssetId)
                    end
                end
            else
                -- Fallback lama kalau GetAccessories tidak tersedia
                local accSlots = {
                    desc.HatAccessory, desc.HairAccessory, desc.FaceAccessory, desc.NeckAccessory,
                    desc.BackAccessory, desc.WaistAccessory, desc.ShouldersAccessory, desc.FrontAccessory
                }
                for _, slotStr in ipairs(accSlots) do
                    if slotStr and slotStr ~= "" then
                        for idStr in tostring(slotStr):gmatch("[^,]+") do
                            local aid = tonumber(idStr:match("^%s*(.-)%s*$"))
                            if aid and aid ~= 0 and not seenAcc[aid] then
                                seenAcc[aid] = true
                                table.insert(accIds, aid)
                            end
                        end
                    end
                end
            end

            for _, aid in ipairs(accIds) do
                insertAsset(aid)
            end

            -- Korblox & Headless tidak tercatat di HumanoidDescription sama sekali
            -- (itu body-part swap dari Bundle, bukan field/accessory biasa), jadi
            -- dicek terpisah lewat avatar.roblox.com berdasarkan UserId target.
            -- Selalu reset dulu ke normal supaya tidak ada sisa dari avatar sebelumnya.
            GLOBAL_ApplyHeadless(char, false)
            GLOBAL_ApplyKorblox(char, false, false)
            if id then
                task.spawn(function()
                    local features = AC_DetectBundleFeatures(id)
                    if char and char.Parent then
                        if features.hasHeadless then
                            GLOBAL_ApplyHeadless(char, true)
                        end
                        if features.hasKorbloxLeft or features.hasKorbloxRight then
                            GLOBAL_ApplyKorblox(char, features.hasKorbloxRight, features.hasKorbloxLeft)
                        end
                    end
                end)
            end

            -- Bentuk Head (mis. Faceless Head, atau Head khusus lain yang tidak
            -- terwakili sebagai Face/HatAccessory biasa) disalin lewat
            -- Players:CreateHumanoidModelFromDescription, API resmi yang
            -- menghasilkan rig yang benar dari sebuah HumanoidDescription.
            -- Dibatasi HANYA ke part Head (bukan torso/lengan/kaki) supaya tidak
            -- mengganggu Korblox (yang sudah ditangani terpisah di atas).
            -- PENTING: rig referensi HARUS sama dengan rig karakter tujuan
            -- (R6 vs R15) -- kalau tidak, mesh Head R15 ditempel ke Head R6
            -- (atau sebaliknya) dan hasilnya jadi kotak/rusak karena beda
            -- geometri & class part (MeshPart vs Part biasa).
            pcall(function()
                local charIsR6 = (char:FindFirstChild("Right Leg") ~= nil) and (char:FindFirstChild("RightUpperLeg") == nil)
                local rigType = charIsR6 and Enum.HumanoidRigType.R6 or Enum.HumanoidRigType.R15

                local ok_model, refModel = pcall(function()
                    return Players:CreateHumanoidModelFromDescription(desc, rigType)
                end)
                if ok_model and refModel then
                    local srcPart = refModel:FindFirstChild("Head")
                    local dstPart = char:FindFirstChild("Head")
                    if srcPart and dstPart then
                        if srcPart:IsA("MeshPart") and dstPart:IsA("MeshPart") then
                            pcall(function() dstPart.MeshId = srcPart.MeshId end)
                            pcall(function() dstPart.TextureID = srcPart.TextureID end)
                        else
                            local srcMesh = srcPart:FindFirstChildOfClass("SpecialMesh")
                            if srcMesh then
                                local dstMesh = dstPart:FindFirstChildOfClass("SpecialMesh")
                                if not dstMesh then
                                    dstMesh = Instance.new("SpecialMesh")
                                    dstMesh.Parent = dstPart
                                end
                                pcall(function() dstMesh.MeshId = srcMesh.MeshId end)
                                pcall(function() dstMesh.TextureId = srcMesh.TextureId end)
                                pcall(function() dstMesh.Scale = srcMesh.Scale end)
                                pcall(function() dstMesh.MeshType = srcMesh.MeshType end)
                            end
                            -- Kalau srcMesh tidak ada (R6 default Head memang tidak
                            -- punya SpecialMesh -- kepala kotak polos itu bentuk
                            -- aslinya), tidak perlu dipaksa pasang mesh apapun.
                        end
                    end
                    refModel:Destroy()
                end
            end)

        end, warn)
    end)
end

AC_APPLYAVATAR = function(userid)
    task.spawn(function()
        xpcall(function()
            ac_setStatus("Fetching...", Color3.fromRGB(195, 165, 50))
            local txt = tostring(userid):gsub("%s+", "")
            local ID = tonumber(txt)
            local NAME = nil

            if ID then
                local ok = pcall(function() NAME = Players:GetNameFromUserIdAsync(ID) end)
                if not ok or not NAME then
                    ac_setStatus("User not found!", Color3.fromRGB(155, 45, 45)); return
                end
            else
                local ok = pcall(function()
                    ID = Players:GetUserIdFromNameAsync(txt)
                    NAME = txt
                end)
                if not ok or not ID then
                    ac_setStatus("User not found!", Color3.fromRGB(155, 45, 45)); return
                end
                pcall(function() NAME = Players:GetNameFromUserIdAsync(ID) end)
                NAME = NAME or txt
            end

            ac_setStatus("Loading avatar...", Color3.fromRGB(195, 165, 50))
            local DESC = Players:GetHumanoidDescriptionFromUserId(ID)

            local oldConn = AC_CURRENT_AVATAR and AC_CURRENT_AVATAR._conn
            if oldConn then oldConn:Disconnect() end

            AC_CURRENT_AVATAR = {id = ID, name = NAME, desc = DESC}

            if LocalPlayer.Character then
                AC_MORPHCHAR(LocalPlayer.Character, NAME, ID, DESC)
            end

            AC_CURRENT_AVATAR._conn = LocalPlayer.CharacterAdded:Connect(function(char)
                if AC_CURRENT_AVATAR and AC_CURRENT_AVATAR.id == ID then
                    AC_MORPHCHAR(char, NAME, ID, DESC)
                end
            end)

            ac_setStatus("Applied: " .. NAME, Color3.fromRGB(55, 175, 55))
            AC_UPDATEFAVBTN()
        end, function(err)
            ac_setStatus("Error!", Color3.fromRGB(155, 45, 45)); warn(err)
        end)
    end)
end

local AC_APPLY_TO_PLAYER = function(targetInput)
    task.spawn(function()
        xpcall(function()
            if not AC_CURRENT_AVATAR then
                ac_setStatus("Apply your avatar first!", Color3.fromRGB(195, 165, 50))
                return
            end

            local txt = tostring(targetInput):gsub("%s+", "")
            if txt == "" then
                ac_setStatus("Enter target username/ID!", Color3.fromRGB(195, 165, 50))
                return
            end

            ac_setStatus("Searching for target...", Color3.fromRGB(195, 165, 50))

            local targetPlayer = nil
            local txtLower = txt:lower()
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    if plr.Name:lower() == txtLower or plr.DisplayName:lower() == txtLower then
                        targetPlayer = plr
                        break
                    end
                end
            end

            if not targetPlayer then
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer then
                        if plr.Name:lower():find(txtLower, 1, true) or plr.DisplayName:lower():find(txtLower, 1, true) then
                            targetPlayer = plr
                            break
                        end
                    end
                end
            end

            local numId = tonumber(txt)
            if not targetPlayer and numId then
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer and plr.UserId == numId then
                        targetPlayer = plr
                        break
                    end
                end
            end

            if not targetPlayer then
                ac_setStatus("Player not found on server!", Color3.fromRGB(155, 45, 45))
                return
            end

            local targetChar = targetPlayer.Character
            if not targetChar then
                ac_setStatus("Character " .. targetPlayer.Name .. " not found!", Color3.fromRGB(155, 45, 45))
                return
            end

            ac_setStatus("Applying to " .. targetPlayer.Name .. "...", Color3.fromRGB(195, 165, 50))
            local originalDisplayName = targetPlayer.DisplayName
            AC_MORPHCHAR(targetChar, originalDisplayName, AC_CURRENT_AVATAR.id, AC_CURRENT_AVATAR.desc)
            ac_setStatus("Applied to: " .. targetPlayer.Name, Color3.fromRGB(55, 175, 55))

        end, function(err)
            ac_setStatus("Error!", Color3.fromRGB(155, 45, 45))
        end)
    end)
end

AC_UPDATEFAVBTN = function()
    if not ac_favBtnToggle then return end
    local fw = ac_favBtnToggle.Parent
    if not AC_CURRENT_AVATAR then
        ac_favBtnToggle.Text = "Add Favorite"
        if fw then fw.BackgroundColor3 = Color3.fromRGB(40, 40, 40) end
        return
    end
    local isFav = false
    for _, v in ipairs(AC_FAVORITES) do
        if v.id == AC_CURRENT_AVATAR.id then isFav = true; break end
    end
    if isFav then
        ac_favBtnToggle.Text = "Favorited"
        if fw then fw.BackgroundColor3 = Color3.fromRGB(120, 35, 35) end
    else
        ac_favBtnToggle.Text = "Add Favorite"
        if fw then fw.BackgroundColor3 = Color3.fromRGB(40, 40, 40) end
    end
end

AC_SAVEFAVORITES = function()
    task.spawn(function()
        pcall(function()
            if not isfolder("Zero Directory") then makefolder("Zero Directory") end
            writefile("Zero Directory/favorites.json", HttpService:JSONEncode(AC_FAVORITES))
        end)
    end)
end

local function acc_canFileIO()
    return type(writefile)=="function" and type(readfile)=="function"
        and type(isfile)=="function" and type(isfolder)=="function"
end

local function acc_savePresets()
    if not acc_canFileIO() then return end
    pcall(function()
        if not isfolder("Zero Directory") then makefolder("Zero Directory") end
        writefile(ACC_PRESET_FILE, HttpService:JSONEncode(ACC_PRESETS))
    end)
end

local function acc_loadPresetsFromFile()
    if not acc_canFileIO() then return end
    pcall(function()
        if not isfolder("Zero Directory") then makefolder("Zero Directory") end
        if isfile(ACC_PRESET_FILE) then
            local ok, decoded = pcall(function()
                return HttpService:JSONDecode(readfile(ACC_PRESET_FILE))
            end)
            if ok and decoded then ACC_PRESETS = decoded end
        end
    end)
end

local function acc_collectCurrentSlots()
    local slots = {}
    local char = LocalPlayer.Character
    if not char then return slots end
    local HUM = char:FindFirstChildOfClass("Humanoid")
    if not HUM then return slots end
    local desc = HUM:GetAppliedDescription()
    local slotProps = {"HatAccessory","HairAccessory","FaceAccessory","NeckAccessory","BackAccessory",
                       "WaistAccessory","ShouldersAccessory","FrontAccessory"}
    for _, prop in ipairs(slotProps) do
        local val = tostring(desc[prop] or ""):gsub("%s+","")
        if val ~= "" then slots[prop] = val end
    end
    return slots
end

local function acc_collectCurrentTransforms()
    local transforms = {}
    local char = LocalPlayer.Character
    if not char then return transforms end
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Accessory") or obj:IsA("Hat") then
            local handle = obj:FindFirstChild("Handle")
            if handle then
                local weld = handle:FindFirstChildOfClass("Weld") or handle:FindFirstChild("AccessoryWeld")
                if not weld then
                    for _, c in ipairs(handle:GetChildren()) do
                        if c:IsA("Weld") then weld = c; break end
                    end
                end
                local cf
                if weld then
                    cf = weld.C0
                else
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if hrp then
                        cf = hrp.CFrame:ToObjectSpace(handle.CFrame)
                    else
                        cf = handle.CFrame
                    end
                end
                transforms[obj.Name] = {
                    px = cf.X, py = cf.Y, pz = cf.Z,
                    r00 = cf.RightVector.X, r01 = cf.UpVector.X, r02 = -cf.LookVector.X,
                    r10 = cf.RightVector.Y, r11 = cf.UpVector.Y, r12 = -cf.LookVector.Y,
                    r20 = cf.RightVector.Z, r21 = cf.UpVector.Z, r22 = -cf.LookVector.Z,
                    isWeld = weld ~= nil,
                }
            end
        end
    end
    return transforms
end

local function acc_applyPreset(preset)
    task.spawn(function()
        local char = LocalPlayer.Character
        if not char then acc_setStatus("Character not found!", Color3.fromRGB(155,45,45)); return end
        local HUM = char:FindFirstChildOfClass("Humanoid")
        if not HUM then return end
        acc_setStatus("Loading preset...", Color3.fromRGB(195,165,50))

        local HRP = char:FindFirstChild("HumanoidRootPart")
        startPositionLock(char, 2.5)

        local allSlotProps2 = {
            "HatAccessory", "HairAccessory", "FaceAccessory", "NeckAccessory",
            "BackAccessory", "WaistAccessory", "ShouldersAccessory", "FrontAccessory"
        }

        -- Cuma hapus accessory dari slot yang memang disebutkan preset.
        -- Slot yang TIDAK ada di preset dibiarkan apa adanya (misal rambut tetap ada).
        for _, prop in ipairs(allSlotProps2) do
            local presetVal = preset.slots and preset.slots[prop]
            if presetVal and tostring(presetVal) ~= "" then
                local slotType = ({
                    HatAccessory       = Enum.AccessoryType.Hat,
                    HairAccessory      = Enum.AccessoryType.Hair,
                    FaceAccessory      = Enum.AccessoryType.Face,
                    NeckAccessory      = Enum.AccessoryType.Neck,
                    BackAccessory      = Enum.AccessoryType.Back,
                    WaistAccessory     = Enum.AccessoryType.Waist,
                    ShouldersAccessory = Enum.AccessoryType.Shoulder,
                    FrontAccessory     = Enum.AccessoryType.Front,
                })[prop]
                if slotType then
                    for _, obj in ipairs(char:GetChildren()) do
                        if (obj:IsA("Accessory") or obj:IsA("Hat")) and obj.AccessoryType == slotType then
                            pcall(function() obj:Destroy() end)
                        end
                    end
                end
            end
        end
        task.wait(0.05)

        -- AC_ACCESSORY_APPLIED: hanya update slot yang ada di preset, slot lain
        -- (misal rambut kalau preset tidak menyebutkannya) tetap seperti sebelumnya.
        local allSlotProps = allSlotProps2
        for _, prop in ipairs(allSlotProps) do
            local idStr = preset.slots and preset.slots[prop]
            if idStr and tostring(idStr) ~= "" then
                AC_ACCESSORY_APPLIED[prop] = tostring(idStr)
            end
        end

        local InsertService = game:GetService("InsertService")
        local allIds = {}
        for _, idStr in pairs(preset.slots or {}) do
            for id in tostring(idStr):gmatch("[^,]+") do
                local aid = tonumber(id:match("^%s*(.-)%s*$"))
                if aid then table.insert(allIds, aid) end
            end
        end
        for _, aid in ipairs(allIds) do
            pcall(function()
                local model = LoadAssetLocal(aid)
                if model then
                    for _, child in ipairs(model:GetChildren()) do
                        if child:IsA("Accessory") or child:IsA("Hat") then
                            local dup = char:FindFirstChild(child.Name)
                            if dup and (dup:IsA("Accessory") or dup:IsA("Hat")) then dup:Destroy() end
                            AttachAccessoryLocal(char, child)
                        end
                    end
                    model:Destroy()
                end
            end)
        end

        local transforms = preset.transforms or {}
        if next(transforms) then
            AC_ACCESSORY_TRANSFORMS = transforms

            task.wait(0.8)

            local function applyTransformToAcc(obj, t)
                local handle = obj:FindFirstChild("Handle")
                if not handle then return end
                local cf = CFrame.new(
                    t.px, t.py, t.pz,
                    t.r00, t.r01, t.r02,
                    t.r10, t.r11, t.r12,
                    t.r20, t.r21, t.r22
                )
                local weld = handle:FindFirstChildOfClass("Weld") or handle:FindFirstChild("AccessoryWeld")
                if not weld then
                    for _, c in ipairs(handle:GetChildren()) do
                        if c:IsA("Weld") then weld = c; break end
                    end
                end
                pcall(function()
                    if weld and weld.Parent then
                        weld.C0 = cf
                    else
                        handle.CFrame = cf
                    end
                end)
            end

            for _, obj in ipairs(char:GetChildren()) do
                if (obj:IsA("Accessory") or obj:IsA("Hat")) then
                    local t = transforms[obj.Name]
                    if t then applyTransformToAcc(obj, t) end
                end
            end

            task.wait(0.3)
            for _, obj in ipairs(char:GetChildren()) do
                if (obj:IsA("Accessory") or obj:IsA("Hat")) then
                    local t = transforms[obj.Name]
                    if t then applyTransformToAcc(obj, t) end
                end
            end
        end

        -- Restore head jika ada di preset
        if preset.head and preset.head ~= "" then
            local headId = tonumber(preset.head)
            if headId and headId ~= 0 then
                task.wait(0.3)
                pcall(function()
                    local headPart = char:FindFirstChild("Head")
                    if not headPart then return end

                    -- Simpan original head sebelum diubah (untuk restore saat Remove All)
                    if not AC_HEAD_ORIGINAL then
                        local isDyn = headPart:IsA("MeshPart") or headPart:FindFirstChildOfClass("FaceControls") ~= nil
                        if isDyn then
                            AC_HEAD_ORIGINAL = {
                                isDynamic = true,
                                meshId    = headPart.MeshId,
                                textureId = headPart.TextureID,
                                color     = headPart.Color,
                                material  = headPart.Material,
                            }
                        else
                            local origMesh = headPart:FindFirstChildOfClass("SpecialMesh")
                            AC_HEAD_ORIGINAL = {
                                isDynamic = false,
                                meshId    = origMesh and origMesh.MeshId or "",
                                textureId = origMesh and origMesh.TextureId or "",
                                scale     = origMesh and origMesh.Scale or Vector3.new(1,1,1),
                                color     = headPart.Color,
                                material  = headPart.Material,
                            }
                        end
                    end

                    local ok_get, objs = pcall(function()
                        return game:GetObjects("rbxassetid://" .. tostring(headId))
                    end)

                    local function deepFind(root, className)
                        if root:IsA(className) then return root end
                        for _, d in ipairs(root:GetDescendants()) do
                            if d:IsA(className) then return d end
                        end
                        return nil
                    end

                    local srcMeshPart, srcPart, srcSpecialMesh = nil, nil, nil
                    if ok_get and objs and #objs > 0 then
                        for _, obj in ipairs(objs) do
                            if not srcMeshPart    then srcMeshPart    = deepFind(obj, "MeshPart")    end
                            if not srcPart        then srcPart        = deepFind(obj, "Part")        end
                            if not srcSpecialMesh then srcSpecialMesh = deepFind(obj, "SpecialMesh") end
                        end
                        if srcPart and srcPart:FindFirstChildOfClass("SpecialMesh") then
                            srcSpecialMesh = srcPart:FindFirstChildOfClass("SpecialMesh")
                        end
                    end

                    local isDynamic = headPart:IsA("MeshPart") or headPart:FindFirstChildOfClass("FaceControls") ~= nil

                    local function applyMeshToHead(meshId, texId, srcPartRef)
                        if meshId == "" then meshId = "rbxassetid://" .. tostring(headId) end
                        if isDynamic then
                            pcall(function() headPart.MeshId    = meshId end)
                            pcall(function() headPart.TextureID = texId  end)
                        else
                            for _, m in ipairs(headPart:GetChildren()) do
                                if m:IsA("SpecialMesh") then pcall(function() m:Destroy() end) end
                            end
                            local sm = Instance.new("SpecialMesh")
                            sm.MeshType  = Enum.MeshType.FileMesh
                            sm.MeshId    = meshId
                            sm.TextureId = texId
                            sm.Scale     = Vector3.new(1,1,1)
                            sm.Parent    = headPart
                        end
                        if srcPartRef then
                            pcall(function() headPart.Color    = srcPartRef.Color    end)
                            pcall(function() headPart.Material = srcPartRef.Material end)
                        end
                    end

                    if srcMeshPart then
                        applyMeshToHead(srcMeshPart.MeshId or "", srcMeshPart.TextureID or "", srcMeshPart)
                    elseif srcSpecialMesh then
                        applyMeshToHead(srcSpecialMesh.MeshId or "", srcSpecialMesh.TextureId or "", srcPart)
                    else
                        applyMeshToHead("", "", nil)
                    end

                    AC_HEAD_APPLIED = headId
                end)
            end
        end

        acc_setStatus("Preset applied!", Color3.fromRGB(55,175,55))
    end)
end

local function ac_applyAccessory(descProp, assetIdStr, slotInfo)
    slotInfo = slotInfo or {}
    task.spawn(function()
        xpcall(function()
            local char = LocalPlayer.Character
            if not char then acc_setStatus("Character not found!", Color3.fromRGB(155, 45, 45)) return end
            local HUM = char:FindFirstChildOfClass("Humanoid")
            if not HUM then acc_setStatus("Humanoid not found!", Color3.fromRGB(155, 45, 45)) return end

            assetIdStr = tostring(assetIdStr):gsub("%s+", "")
            if assetIdStr == "" then
                acc_setStatus("Enter Asset ID!", Color3.fromRGB(195, 165, 50))
                return
            end

            if slotInfo and slotInfo.isHeadChange then
                local aid = tonumber(assetIdStr)
                if not aid or aid == 0 then
                    acc_setStatus("Invalid Head ID!", Color3.fromRGB(195, 80, 50))
                    return
                end
                acc_setStatus("Loading head...", Color3.fromRGB(195, 165, 50))

                local headPart = char:FindFirstChild("Head")
                if not headPart then
                    acc_setStatus("Head not found!", Color3.fromRGB(155, 45, 45))
                    return
                end

                if not AC_HEAD_ORIGINAL then
                    local isDyn = headPart:IsA("MeshPart") or headPart:FindFirstChildOfClass("FaceControls") ~= nil
                    if isDyn then
                        AC_HEAD_ORIGINAL = {
                            isDynamic  = true,
                            meshId     = headPart.MeshId,
                            textureId  = headPart.TextureID,
                            color      = headPart.Color,
                            material   = headPart.Material,
                        }
                    else
                        local origMesh = headPart:FindFirstChildOfClass("SpecialMesh")
                        AC_HEAD_ORIGINAL = {
                            isDynamic  = false,
                            meshId     = origMesh and origMesh.MeshId or "",
                            textureId  = origMesh and origMesh.TextureId or "",
                            scale      = origMesh and origMesh.Scale or Vector3.new(1,1,1),
                            color      = headPart.Color,
                            material   = headPart.Material,
                        }
                    end
                end

                local isDynamic = headPart:IsA("MeshPart") or headPart:FindFirstChildOfClass("FaceControls") ~= nil

                local ok_get, objs = pcall(function()
                    return game:GetObjects("rbxassetid://" .. tostring(aid))
                end)

                local function deepFind(root, className)
                    if root:IsA(className) then return root end
                    for _, d in ipairs(root:GetDescendants()) do
                        if d:IsA(className) then return d end
                    end
                    return nil
                end

                local srcMeshPart, srcPart, srcSpecialMesh = nil, nil, nil
                if ok_get and objs and #objs > 0 then
                    for _, obj in ipairs(objs) do
                        if not srcMeshPart    then srcMeshPart    = deepFind(obj, "MeshPart")    end
                        if not srcPart        then srcPart        = deepFind(obj, "Part")        end
                        if not srcSpecialMesh then srcSpecialMesh = deepFind(obj, "SpecialMesh") end
                    end
                    if srcPart and srcPart:FindFirstChildOfClass("SpecialMesh") then
                        srcSpecialMesh = srcPart:FindFirstChildOfClass("SpecialMesh")
                    end
                end

                local function applyMeshToHead(meshId, texId, srcPartRef)
                    if meshId == "" then meshId = "rbxassetid://" .. tostring(aid) end
                    if isDynamic then
                        pcall(function() headPart.MeshId    = meshId end)
                        pcall(function() headPart.TextureID = texId  end)
                    else
                        for _, m in ipairs(headPart:GetChildren()) do
                            if m:IsA("SpecialMesh") then pcall(function() m:Destroy() end) end
                        end
                        local sm = Instance.new("SpecialMesh")
                        sm.MeshType  = Enum.MeshType.FileMesh
                        sm.MeshId    = meshId
                        sm.TextureId = texId
                        sm.Scale     = Vector3.new(1,1,1)
                        sm.Parent    = headPart
                    end
                    if srcPartRef then
                        pcall(function() headPart.Color    = srcPartRef.Color    end)
                        pcall(function() headPart.Material = srcPartRef.Material end)
                    end
                end

                if srcMeshPart then
                    applyMeshToHead(srcMeshPart.MeshId or "", srcMeshPart.TextureID or "", srcMeshPart)
                elseif srcSpecialMesh then
                    applyMeshToHead(srcSpecialMesh.MeshId or "", srcSpecialMesh.TextureId or "", srcPart)
                else
                    applyMeshToHead("", "", nil)
                end

                AC_HEAD_APPLIED = aid

                local tag = isDynamic and " (Dynamic)" or " (Regular)"
                acc_setStatus("Head changed!" .. tag, Color3.fromRGB(55, 175, 55))
                return
            end

            acc_setStatus("Applying accessory...", Color3.fromRGB(195, 165, 50))

            local HRP = char:FindFirstChild("HumanoidRootPart")
            local savedCF_acc = HRP and HRP.CFrame
            startPositionLock(char, 2.0)

            local desc = HUM:GetAppliedDescription()
            local InsertService = game:GetService("InsertService")

            if descProp then
                local replaceMode = (descProp == "HatAccessory" or descProp == "HairAccessory")

                local validIds = {}
                for idStr in assetIdStr:gmatch("[^,]+") do
                    local clean = idStr:match("^%s*(.-)%s*$")
                    local aid = tonumber(clean)
                    if aid and aid ~= 0 then table.insert(validIds, clean) end
                end
                if #validIds == 0 then
                    acc_setStatus("Invalid ID!", Color3.fromRGB(195, 80, 50))
                    return
                end

                if replaceMode then
                    local removeTypes = nil
                    local trackedName = nil
                    if descProp == "HatAccessory" then
                        removeTypes = {Enum.AccessoryType.Hat}
                        trackedName = "HatAccessory"
                    elseif descProp == "HairAccessory" then
                        removeTypes = {Enum.AccessoryType.Hair}
                        trackedName = "HairAccessory"
                        desc[descProp] = ""
                    end
                    -- ID accessory yang lagi dipakai di slot INI (dari track sebelumnya),
                    -- supaya cuma hapus yang memang milik slot ini walau AccessoryType == Unknown
                    local trackedIds = {}
                    if trackedName and AC_ACCESSORY_APPLIED[trackedName] then
                        for id in tostring(AC_ACCESSORY_APPLIED[trackedName]):gmatch("[^,]+") do
                            trackedIds[id:match("^%s*(.-)%s*$")] = true
                        end
                    end
                    for _, obj in ipairs(char:GetChildren()) do
                        if obj:IsA("Accessory") or obj:IsA("Hat") then
                            local shouldRemove = false
                            if removeTypes then
                                for _, t in ipairs(removeTypes) do
                                    if obj.AccessoryType == t then shouldRemove = true; break end
                                end
                            end
                            if not shouldRemove and obj.AccessoryType == Enum.AccessoryType.Unknown then
                                -- Hanya hapus accessory Unknown kalau memang sebelumnya
                                -- di-track sebagai bagian dari slot ini (mis. hair legacy)
                                if trackedIds[obj.Name] then shouldRemove = true end
                            end
                            if shouldRemove then
                                pcall(function() obj:Destroy() end)
                            end
                        end
                    end
                end

                local ids = {}
                if not replaceMode then
                    local existing = tostring(desc[descProp] or ""):gsub("%s+","")
                    if existing ~= "" then
                        for id in existing:gmatch("[^,]+") do table.insert(ids, id) end
                    end
                end
                for _, clean in ipairs(validIds) do
                    local found = false
                    for _, ex in ipairs(ids) do if ex == clean then found = true; break end end
                    if not found then table.insert(ids, clean) end
                end
                desc[descProp] = table.concat(ids, ",")
                AC_ACCESSORY_APPLIED[descProp] = desc[descProp]

                task.wait(0.05)
                local hrpPost2 = char:FindFirstChild("HumanoidRootPart")
                if hrpPost2 and hrpPost2.Parent and savedCF_acc then
                    pcall(function() hrpPost2.CFrame = savedCF_acc end)
                end
                task.wait(0.15)

                for _, clean in ipairs(validIds) do
                    local aid = tonumber(clean)
                    if aid and aid ~= 0 then
                        pcall(function()
                            local model = LoadAssetLocal(aid)
                            if model then
                                for _, child in ipairs(model:GetChildren()) do
                                    if child:IsA("Accessory") or child:IsA("Hat") then
                                        local dup = char:FindFirstChild(child.Name)
                                        if dup and (dup:IsA("Accessory") or dup:IsA("Hat")) then dup:Destroy() end
                                        AttachAccessoryLocal(char, child)
                                    end
                                end
                                model:Destroy()
                            end
                        end)
                    end
                end

                if next(AC_ACCESSORY_TRANSFORMS) then
                    local function reapplyTransform(obj, t)
                        local handle = obj:FindFirstChild("Handle")
                        if not handle then return end
                        local cf = CFrame.new(
                            t.px, t.py, t.pz,
                            t.r00, t.r01, t.r02,
                            t.r10, t.r11, t.r12,
                            t.r20, t.r21, t.r22
                        )
                        local weld = handle:FindFirstChildOfClass("Weld") or handle:FindFirstChild("AccessoryWeld")
                        if not weld then
                            for _, c in ipairs(handle:GetChildren()) do
                                if c:IsA("Weld") then weld = c; break end
                            end
                        end
                        pcall(function()
                            if weld and weld.Parent then
                                weld.C0 = cf
                            else
                                handle.CFrame = cf
                            end
                        end)
                    end

                    for _, obj in ipairs(char:GetChildren()) do
                        if obj:IsA("Accessory") or obj:IsA("Hat") then
                            local t = AC_ACCESSORY_TRANSFORMS[obj.Name]
                            if t then reapplyTransform(obj, t) end
                        end
                    end
                    task.wait(0.3)
                    for _, obj in ipairs(char:GetChildren()) do
                        if obj:IsA("Accessory") or obj:IsA("Hat") then
                            local t = AC_ACCESSORY_TRANSFORMS[obj.Name]
                            if t then reapplyTransform(obj, t) end
                        end
                    end
                end

                acc_setStatus("Accessory applied!", Color3.fromRGB(55, 175, 55))
            else
                for idStr in assetIdStr:gmatch("[^,]+") do
                    local aid = tonumber(idStr:match("^%s*(.-)%s*$"))
                    if aid then
                        pcall(function()
                            local model = LoadAssetLocal(aid)
                            if model then
                                for _, child in ipairs(model:GetChildren()) do
                                    if child:IsA("Accessory") or child:IsA("Hat") then
                                        AttachAccessoryLocal(char, child)
                                    else
                                        child.Parent = char
                                    end
                                end
                                model:Destroy()
                            end
                        end)
                    end
                end
                acc_setStatus("Accessory equipped!", Color3.fromRGB(55, 175, 55))
            end
        end, function(err)
            acc_setStatus("Error: " .. tostring(err):sub(1,40), Color3.fromRGB(155, 45, 45))
        end)
    end)
end

local function ac_clearAllAccessories()
    task.spawn(function()
        xpcall(function()
            local char = LocalPlayer.Character
            if not char then return end
            local HUM = char:FindFirstChildOfClass("Humanoid")
            if not HUM then return end

            local HRP = char:FindFirstChild("HumanoidRootPart")
            startPositionLock(char, 2.0)

            local originalHair = ""
            if AC_ORIGINAL_DESC then
                originalHair = AC_ORIGINAL_DESC.HairAccessory or ""
            end

            -- Hapus semua accessory/hat secara lokal (client-only)
            for _, obj in ipairs(char:GetChildren()) do
                if obj:IsA("Accessory") or obj:IsA("Hat") then
                    pcall(function() obj:Destroy() end)
                end
            end
            task.wait(0.05)

            -- Pasang kembali rambut original (jika ada) via InsertService
            if originalHair ~= "" then
                local InsertService = game:GetService("InsertService")
                for idStr in tostring(originalHair):gmatch("[^,]+") do
                    local aid = tonumber(idStr:match("^%s*(.-)%s*$"))
                    if aid and aid ~= 0 then
                        pcall(function()
                            local model = LoadAssetLocal(aid)
                            if model then
                                for _, child in ipairs(model:GetChildren()) do
                                    if child:IsA("Accessory") or child:IsA("Hat") then
                                        AttachAccessoryLocal(char, child)
                                    end
                                end
                                model:Destroy()
                            end
                        end)
                    end
                end
            end

            AC_ACCESSORY_APPLIED = {}
            if originalHair ~= "" then
                AC_ACCESSORY_APPLIED["HairAccessory"] = originalHair
            end
            AC_ACCESSORY_TRANSFORMS = {}

            if AC_HEAD_ORIGINAL then
                local headPart = char:FindFirstChild("Head")
                if headPart then
                    local orig = AC_HEAD_ORIGINAL
                    if orig.isDynamic then
                        pcall(function() headPart.MeshId    = orig.meshId    end)
                        pcall(function() headPart.TextureID = orig.textureId end)
                        pcall(function() headPart.Color     = orig.color     end)
                        pcall(function() headPart.Material  = orig.material  end)
                    else
                        for _, m in ipairs(headPart:GetChildren()) do
                            if m:IsA("SpecialMesh") then pcall(function() m:Destroy() end) end
                        end
                        local sm = Instance.new("SpecialMesh")
                        sm.MeshType  = Enum.MeshType.FileMesh
                        sm.MeshId    = orig.meshId
                        sm.TextureId = orig.textureId
                        sm.Scale     = orig.scale or Vector3.new(1,1,1)
                        sm.Parent    = headPart
                        pcall(function() headPart.Color    = orig.color    end)
                        pcall(function() headPart.Material = orig.material end)
                    end
                end
                AC_HEAD_APPLIED  = nil
                AC_HEAD_ORIGINAL = nil
            end

            acc_setStatus("All accessories removed!", Color3.fromRGB(145, 145, 145))
        end, warn)
    end)
end

AC_UPDATEFAVLIST = function()
    if not ac_favDropFrame then return end
    for _, v in ac_favDropFrame:GetChildren() do
        if v:IsA("Frame") then v:Destroy() end
    end
    if #AC_FAVORITES == 0 then
        ac_favDropEmpty.Visible = true
        return
    end
    ac_favDropEmpty.Visible = false
    for _, fav in ipairs(AC_FAVORITES) do
        local item = makeUI(ac_favDropFrame, "Frame", {
            Size = UDim2.new(0.92, 0, 0, 34),
            BackgroundColor3 = Color3.fromRGB(42, 42, 42),
            BorderSizePixel = 0
        })
        makeUI(item, "UICorner", {CornerRadius = UDim.new(0, 6)})
        makeUI(item, "UIStroke", {Color = Color3.fromRGB(65, 65, 65), Thickness = 1, Transparency = 0.5})
        makeUI(item, "TextLabel", {
            Text = fav.name .. " (" .. fav.id .. ")",
            Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(220, 220, 220), TextSize = 11,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -76, 1, 0),
            Position = UDim2.new(0, 6, 0, 0),
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd
        })
        local applyBtn = makeUI(item, "TextButton", {
            Size = UDim2.new(0, 48, 0, 22),
            Position = UDim2.new(1, -72, 0.5, -11),
            BackgroundColor3 = Color3.fromRGB(55, 55, 55),
            BorderSizePixel = 0, AutoButtonColor = false,
            Text = "APPLY", TextColor3 = Color3.fromRGB(220, 220, 220),
            TextSize = 10, Font = Enum.Font.GothamBold
        })
        makeUI(applyBtn, "UICorner", {CornerRadius = UDim.new(0, 5)})
        local removeBtn = makeUI(item, "TextButton", {
            Size = UDim2.new(0, 22, 0, 22),
            Position = UDim2.new(1, -22, 0.5, -11),
            BackgroundColor3 = Color3.fromRGB(155, 45, 45),
            BorderSizePixel = 0, AutoButtonColor = false,
            Text = "×", TextColor3 = Color3.fromRGB(220, 220, 220),
            TextSize = 15, Font = Enum.Font.GothamBold
        })
        makeUI(removeBtn, "UICorner", {CornerRadius = UDim.new(0, 5)})
        applyBtn.MouseButton1Click:Connect(function()
            if AC_INPUT_BOX then AC_INPUT_BOX.Text = tostring(fav.id) end
            if LocalPlayer.Character then AC_MORPHCHAR(LocalPlayer.Character, fav.name, fav.id, fav.desc) end
            AC_CURRENT_AVATAR = fav
            ac_setStatus("Applied: " .. fav.name, Color3.fromRGB(55, 175, 55))
            AC_UPDATEFAVBTN()
        end)
        removeBtn.MouseButton1Click:Connect(function()
            local NEW = {}
            for _, v2 in ipairs(AC_FAVORITES) do
                if v2.id ~= fav.id then table.insert(NEW, v2) end
            end
            AC_FAVORITES = NEW; AC_SAVEFAVORITES(); AC_UPDATEFAVLIST(); AC_UPDATEFAVBTN()
        end)
    end
    if ac_favDropOpen then
        local h = math.max(ac_favDropLayout.AbsoluteContentSize.Y + 10, 38)
        ac_favDropFrame.Size = UDim2.new(0.95, 0, 0, h)
    end
end

local function ac_makeBtn(parent, text, callback)
    local w = makeUI(parent, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 35),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0
    })
    makeUI(w, "UICorner", {CornerRadius = UDim.new(0, 8)})
    local btn = makeUI(w, "TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0, AutoButtonColor = false,
        Text = text, TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = 13, Font = Enum.Font.GothamBold
    })
    btn.MouseButton1Click:Connect(function()
        TweenService:Create(w, TweenInfo.new(0.07), {BackgroundTransparency = 0}):Play()
        task.wait(0.12)
        TweenService:Create(w, TweenInfo.new(0.1), {BackgroundTransparency = 0.2}):Play()
        if callback then callback() end
    end)
    return btn
end

local function ac_makeTextBox(parent, labelText, placeholder, callback, autoClear)
    local f = makeUI(parent, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 35),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0
    })
    makeUI(f, "UICorner", {CornerRadius = UDim.new(0, 8)})
    makeUI(f, "TextLabel", {
        Text = labelText, Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 13,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.3, 0, 1, 0),
        Position = UDim2.new(0.03, 0, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left
    })
    local box = makeUI(f, "TextBox", {
        Size = UDim2.new(0.62, 0, 0.65, 0),
        Position = UDim2.new(0.35, 0, 0.175, 0),
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        BackgroundTransparency = 0.3,
        TextColor3 = Color3.fromRGB(200, 200, 200),
        PlaceholderText = placeholder,
        PlaceholderColor3 = Color3.fromRGB(100, 100, 100),
        Font = Enum.Font.Gotham, TextSize = 12,
        ClearTextOnFocus = false, BorderSizePixel = 0, TextWrapped = false
    })
    makeUI(box, "UICorner", {CornerRadius = UDim.new(0, 6)})
    local def = placeholder; box.Text = def
    box.Focused:Connect(function()
        TweenService:Create(box, TweenInfo.new(0.2), {BackgroundTransparency = 0}):Play()
        if box.Text == def then box.Text = ""; box.TextColor3 = Color3.fromRGB(255, 255, 255) end
    end)
    box.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then box:CaptureFocus() end
    end)
    box.FocusLost:Connect(function(entered)
        TweenService:Create(box, TweenInfo.new(0.2), {BackgroundTransparency = 0.3}):Play()
        if entered and callback then
            callback(box.Text)
            if autoClear then box.Text = def; box.TextColor3 = Color3.fromRGB(100, 100, 100) end
        end
        if box.Text == "" then box.Text = def; box.TextColor3 = Color3.fromRGB(100, 100, 100) end
    end)
    return box
end

function createAvatarChangerPage()
    local headerLbl = makeUI(optionsFrame2, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 22),
        BackgroundTransparency = 1, BorderSizePixel = 0
    })
    makeUI(headerLbl, "TextLabel", {
        Text = "Avatar Changer",
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 12,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center
    })
    AC_INPUT_BOX = ac_makeTextBox(optionsFrame2, "User", "User ID / Username", function(txt)
    end, false)
    AC_TARGET_BOX = ac_makeTextBox(optionsFrame2, "Target", "Username / Display Name", function(txt)
    end, false)
    ac_makeBtn(optionsFrame2, "Apply Avatar", function()
        if AC_INPUT_BOX and AC_INPUT_BOX.Text ~= "" and AC_INPUT_BOX.Text ~= "User ID / Username" then
            AC_APPLYAVATAR(AC_INPUT_BOX.Text)
        end
    end)
    ac_makeBtn(optionsFrame2, "Apply to Player", function()
        local targetTxt = AC_TARGET_BOX and AC_TARGET_BOX.Text or ""
        if targetTxt == "" or targetTxt == "Username / Display Name" then
            ac_setStatus("Enter target name/ID!", Color3.fromRGB(195, 165, 50))
            return
        end
        AC_APPLY_TO_PLAYER(targetTxt)
    end)
    ac_makeBtn(optionsFrame2, "Random Avatar", function()
        local rnd = RANDOM_IDS[math.random(1, #RANDOM_IDS)]
        if AC_INPUT_BOX then AC_INPUT_BOX.Text = tostring(rnd) end
        AC_APPLYAVATAR(rnd)
    end)
    local sf = makeUI(optionsFrame2, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 22),
        BackgroundTransparency = 1, BorderSizePixel = 0
    })
    ac_statusLabel = makeUI(sf, "TextLabel", {
        Text = "Status: Idle",
        Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(145, 145, 145), TextSize = 11,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center
    })
    local fw = makeUI(optionsFrame2, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 35),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0
    })
    makeUI(fw, "UICorner", {CornerRadius = UDim.new(0, 8)})
    ac_favBtnToggle = makeUI(fw, "TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0, AutoButtonColor = false,
        Text = "Add Favorite",
        TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 13, Font = Enum.Font.GothamBold
    })
    makeUI(ac_favBtnToggle, "UICorner", {CornerRadius = UDim.new(0, 8)})
    ac_favBtnToggle.MouseButton1Click:Connect(function()
        if not AC_CURRENT_AVATAR then return end
        TweenService:Create(fw, TweenInfo.new(0.07), {BackgroundTransparency = 0}):Play()
        task.wait(0.12)
        TweenService:Create(fw, TweenInfo.new(0.1), {BackgroundTransparency = 0.2}):Play()
        local exists, idx = false, 0
        for i, v in ipairs(AC_FAVORITES) do
            if v.id == AC_CURRENT_AVATAR.id then exists = true; idx = i; break end
        end
        if exists then table.remove(AC_FAVORITES, idx) else table.insert(AC_FAVORITES, AC_CURRENT_AVATAR) end
        AC_SAVEFAVORITES(); AC_UPDATEFAVBTN(); AC_UPDATEFAVLIST()
    end)
    ac_makeBtn(optionsFrame2, "Reset to Original", function()
        if AC_ORIGINAL_DESC and LocalPlayer.Character then
            local char = LocalPlayer.Character
            local HUM = char:FindFirstChildOfClass("Humanoid")
            if HUM then
                AC_MORPHCHAR(char, LocalPlayer.DisplayName, LocalPlayer.UserId, AC_ORIGINAL_DESC)
            end
        end
        AC_CURRENT_AVATAR = nil; AC_UPDATEFAVBTN()
        ac_setStatus("Reset to original", Color3.fromRGB(145, 145, 145))
    end)
    local favRow = makeUI(optionsFrame2, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 35),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        BackgroundTransparency = 0.2, BorderSizePixel = 0
    })
    makeUI(favRow, "UICorner", {CornerRadius = UDim.new(0, 8)})
    makeUI(favRow, "TextLabel", {
        Text = "Favorites",
        Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 13,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.55, 0, 1, 0),
        Position = UDim2.new(0.04, 0, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left
    })
    ac_favDropBtn = makeUI(favRow, "TextButton", {
        Text = "Open", Font = Enum.Font.GothamBold, TextSize = 11,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundColor3 = Color3.fromRGB(60, 60, 60),
        BackgroundTransparency = 0.3,
        Size = UDim2.new(0.35, 0, 0.65, 0),
        Position = UDim2.new(0.61, 0, 0.175, 0),
        Active = true
    })
    makeUI(ac_favDropBtn, "UICorner", {CornerRadius = UDim.new(0, 6)})
    ac_favDropFrame = makeUI(optionsFrame2, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        BackgroundTransparency = 0.2, BorderSizePixel = 0,
        ClipsDescendants = true, Visible = false
    })
    makeUI(ac_favDropFrame, "UICorner", {CornerRadius = UDim.new(0, 8)})
    ac_favDropLayout = makeUI(ac_favDropFrame, "UIListLayout", {
        Padding = UDim.new(0, 4),
        SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center
    })
    makeUI(ac_favDropFrame, "UIPadding", {PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5)})
    ac_favDropEmpty = makeUI(ac_favDropFrame, "TextLabel", {
        Text = "No favorites yet",
        Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(145, 145, 145), TextSize = 11,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 28),
        TextXAlignment = Enum.TextXAlignment.Center,
        Visible = true
    })
    ac_favDropBtn.MouseButton1Click:Connect(function()
        ac_favDropOpen = not ac_favDropOpen
        if ac_favDropOpen then
            ac_favDropBtn.Text = "Close"
            ac_favDropFrame.Visible = true
            local h = math.max(ac_favDropLayout.AbsoluteContentSize.Y + 10, 38)
            ac_favDropFrame.Size = UDim2.new(0.95, 0, 0, h)
        else
            ac_favDropBtn.Text = "Open"
            ac_favDropFrame.Visible = false
            ac_favDropFrame.Size = UDim2.new(0.95, 0, 0, 0)
        end
    end)
    ac_favDropLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        if ac_favDropOpen then
            local h = math.max(ac_favDropLayout.AbsoluteContentSize.Y + 10, 38)
            ac_favDropFrame.Size = UDim2.new(0.95, 0, 0, h)
        end
    end)
    task.spawn(function()
        pcall(function()
            if not isfolder("Zero Directory") then makefolder("Zero Directory") end
            if isfile("Zero Directory/favorites.json") then
                AC_FAVORITES = HttpService:JSONDecode(readfile("Zero Directory/favorites.json"))
                task.wait(0.2); AC_UPDATEFAVLIST()
            end
        end)
    end)
end

acc_loadPresetsFromFile()

function createAccessoriesPage()
    local headerAcc = makeUI(optionsFrame3, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 22),
        BackgroundTransparency = 1, BorderSizePixel = 0
    })
    makeUI(headerAcc, "TextLabel", {
        Text = "Accessories Changer",
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 12,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center
    })

    local acc_slotBoxRegistry = {}

    for _, slotInfo in ipairs(AC_ACCESSORY_SLOTS) do
        local rowFrame = makeUI(optionsFrame3, "Frame", {
            Size = UDim2.new(0.95, 0, 0, 34),
            BackgroundColor3 = Color3.fromRGB(35, 35, 35), BackgroundTransparency = 0.15, BorderSizePixel = 0
        })
        makeUI(rowFrame, "UICorner", {CornerRadius = UDim.new(0, 7)})
        makeUI(rowFrame, "UIStroke", {Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.5})
        makeUI(rowFrame, "TextLabel", {
            Text = slotInfo.label, Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(210, 210, 210), TextSize = 10,
            BackgroundTransparency = 1, Size = UDim2.new(0.34, 0, 1, 0),
            Position = UDim2.new(0.02, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true
        })
        local slotBox = makeUI(rowFrame, "TextBox", {
            Size = UDim2.new(0.43, 0, 0.62, 0), Position = UDim2.new(0.36, 0, 0.19, 0),
            BackgroundColor3 = Color3.fromRGB(22, 22, 22), BackgroundTransparency = 0.1,
            TextColor3 = Color3.fromRGB(200, 200, 200), PlaceholderText = "Asset ID...",
            PlaceholderColor3 = Color3.fromRGB(85, 85, 85), Font = Enum.Font.Gotham, TextSize = 11,
            ClearTextOnFocus = false, BorderSizePixel = 0, Text = "", TextWrapped = false,
            TextTruncate = Enum.TextTruncate.AtEnd, ClipsDescendants = true
        })
        makeUI(slotBox, "UICorner", {CornerRadius = UDim.new(0, 5)})
        slotBox.Focused:Connect(function() TweenService:Create(slotBox, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play() end)
        slotBox.FocusLost:Connect(function() TweenService:Create(slotBox, TweenInfo.new(0.12), {BackgroundTransparency = 0.1}):Play() end)
        slotBox.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch then slotBox:CaptureFocus() end end)
        if slotInfo.descProp then
            acc_slotBoxRegistry[slotInfo.descProp] = slotBox
        end

        local applyBtn = makeUI(rowFrame, "TextButton", {
            Size = UDim2.new(0.17, 0, 0.62, 0), Position = UDim2.new(0.81, 0, 0.19, 0),
            BackgroundColor3 = Color3.fromRGB(40, 110, 45), TextColor3 = Color3.fromRGB(255, 255, 255),
            Font = Enum.Font.GothamBold, TextSize = 16, Text = "+", BorderSizePixel = 0, Active = true
        })
        makeUI(applyBtn, "UICorner", {CornerRadius = UDim.new(0, 5)})
        local cSlot = slotInfo; local cBox = slotBox
        applyBtn.MouseButton1Click:Connect(function()
            TweenService:Create(applyBtn, TweenInfo.new(0.07), {BackgroundColor3 = Color3.fromRGB(70, 180, 70)}):Play()
            task.wait(0.15)
            TweenService:Create(applyBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(40, 110, 45)}):Play()
            if cBox.Text == "" then acc_setStatus("Enter Asset ID!", Color3.fromRGB(195, 165, 50)); return end
            ac_applyAccessory(cSlot.descProp, cBox.Text, cSlot)
        end)
    end

    local accListLayout
    local accListFrame = makeUI(optionsFrame3, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = false
    })
    accListLayout = makeUI(accListFrame, "UIListLayout", {
        Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center
    })
    accListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        accListFrame.Size = UDim2.new(0.95, 0, 0, accListLayout.AbsoluteContentSize.Y)
    end)

    local function makeSliderRow(parent, labelTxt, minV, maxV, defaultV, step, callback)
        local ROW_H = 28
        local row = makeUI(parent, "Frame", {
            Size = UDim2.new(1, 0, 0, ROW_H),
            BackgroundTransparency = 1, BorderSizePixel = 0
        })
        makeUI(row, "TextLabel", {
            Text = labelTxt, Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(180, 180, 180), TextSize = 10,
            BackgroundTransparency = 1, Size = UDim2.new(0.18, 0, 1, 0), Position = UDim2.new(0, 0, 0, 0),
            TextXAlignment = Enum.TextXAlignment.Left
        })
        local valLabel = makeUI(row, "TextLabel", {
            Text = tostring(defaultV), Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 10,
            BackgroundTransparency = 1, Size = UDim2.new(0.14, 0, 1, 0), Position = UDim2.new(0.86, 0, 0, 0),
            TextXAlignment = Enum.TextXAlignment.Right
        })
        local track = makeUI(row, "Frame", {
            Size = UDim2.new(0.64, 0, 0, 6), Position = UDim2.new(0.19, 0, 0.5, -3),
            BackgroundColor3 = Color3.fromRGB(55, 55, 55), BorderSizePixel = 0
        })
        makeUI(track, "UICorner", {CornerRadius = UDim.new(1, 0)})
        local fill = makeUI(track, "Frame", {
            Size = UDim2.new((defaultV - minV) / (maxV - minV), 0, 1, 0),
            BackgroundColor3 = Color3.fromRGB(180, 180, 180), BorderSizePixel = 0
        })
        makeUI(fill, "UICorner", {CornerRadius = UDim.new(1, 0)})
        local thumb = makeUI(track, "Frame", {
            Size = UDim2.new(0, 14, 0, 14),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new((defaultV - minV) / (maxV - minV), 0, 0.5, 0),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0
        })
        makeUI(thumb, "UICorner", {CornerRadius = UDim.new(1, 0)})

        local curVal = defaultV
        local dragging = false

        local function updateSlider(absX)
            local rel = math.clamp((absX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local rawVal = minV + rel * (maxV - minV)
            local steppedVal = math.floor(rawVal / step + 0.5) * step
            steppedVal = math.clamp(steppedVal, minV, maxV)
            if steppedVal == curVal then return end
            curVal = steppedVal
            local ratio = (curVal - minV) / (maxV - minV)
            fill.Size = UDim2.new(ratio, 0, 1, 0)
            thumb.Position = UDim2.new(ratio, 0, 0.5, 0)
            valLabel.Text = string.format("%.1f", curVal)
            if callback then callback(curVal) end
        end

        thumb.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = true
            end
        end)
        track.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = true; updateSlider(i.Position.X)
            end
        end)
        UserInputService.InputChanged:Connect(function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                updateSlider(i.Position.X)
            end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        return row, function() return curVal end
    end

    local function buildAccPanel(acc, panelParent, onClose)
        local existing = panelParent:FindFirstChild("AccPanel_" .. acc.Name)
        if existing then existing:Destroy() end

        local panel = makeUI(panelParent, "Frame", {
            Name = "AccPanel_" .. acc.Name,
            Size = UDim2.new(1, 0, 0, 0),
            BackgroundColor3 = Color3.fromRGB(40, 40, 40),
            BackgroundTransparency = 0.1, BorderSizePixel = 0,
            ClipsDescendants = true
        })
        makeUI(panel, "UICorner", {CornerRadius = UDim.new(0, 8)})
        makeUI(panel, "UIStroke", {Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.4})

        local panelLayout = makeUI(panel, "UIListLayout", {
            Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder,
            HorizontalAlignment = Enum.HorizontalAlignment.Center
        })
        makeUI(panel, "UIPadding", {PaddingTop = UDim.new(0,5), PaddingBottom = UDim.new(0,5), PaddingLeft = UDim.new(0,6), PaddingRight = UDim.new(0,6)})

        local hdr = makeUI(panel, "Frame", {
            Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, BorderSizePixel = 0
        })
        makeUI(hdr, "TextLabel", {
            Text = acc.Name, Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 11,
            BackgroundTransparency = 1, Size = UDim2.new(0.8, 0, 1, 0),
            TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false
        })
        local closeBtn = makeUI(hdr, "TextButton", {
            Text = "x", Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(200, 100, 100), TextSize = 12,
            BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
            Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -20, 0, 0),
            TextXAlignment = Enum.TextXAlignment.Center
        })
        closeBtn.MouseButton1Click:Connect(function()
            panel:Destroy()
            if onClose then onClose() end
        end)

        local handle = acc:FindFirstChild("Handle")
        local accWeld = nil
        if handle then
            accWeld = handle:FindFirstChildOfClass("Weld") or handle:FindFirstChild("AccessoryWeld")
            if not accWeld then
                for _, c in ipairs(handle:GetChildren()) do
                    if c:IsA("Weld") then accWeld = c; break end
                end
            end
        end

        local baseC0 = accWeld and accWeld.C0 or (handle and CFrame.new(handle.Position) or CFrame.new())
        local basePosVec = baseC0.Position
        local baseRotVec = Vector3.new(
            math.deg(math.atan2(baseC0.UpVector.Z - 0, baseC0.LookVector.Y - 0) * 0),
            0, 0
        )
        local deltaX, deltaY, deltaZ = 0, 0, 0
        local deltaRX, deltaRY, deltaRZ = 0, 0, 0

        local function applyOffsets()
            pcall(function()
                if not handle or not handle.Parent then return end
                local posOffset = CFrame.new(deltaX, deltaY, deltaZ)
                local rotOffset = CFrame.Angles(math.rad(deltaRX), math.rad(deltaRY), math.rad(deltaRZ))
                local finalCF
                if accWeld and accWeld.Parent then
                    finalCF = baseC0 * posOffset * rotOffset
                    accWeld.C0 = finalCF
                else
                    finalCF = CFrame.new(basePosVec + Vector3.new(deltaX, deltaY, deltaZ))
                        * CFrame.Angles(math.rad(deltaRX), math.rad(deltaRY), math.rad(deltaRZ))
                    handle.CFrame = finalCF
                end
                AC_ACCESSORY_TRANSFORMS[acc.Name] = {
                    px  = finalCF.X,             py  = finalCF.Y,             pz  = finalCF.Z,
                    r00 = finalCF.RightVector.X,  r01 = finalCF.UpVector.X,  r02 = -finalCF.LookVector.X,
                    r10 = finalCF.RightVector.Y,  r11 = finalCF.UpVector.Y,  r12 = -finalCF.LookVector.Y,
                    r20 = finalCF.RightVector.Z,  r21 = finalCF.UpVector.Z,  r22 = -finalCF.LookVector.Z,
                    isWeld = (accWeld ~= nil),
                }
            end)
        end

        local posHdr = makeUI(panel, "TextLabel", {
            Text = "Position", Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 10,
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Left
        })

        local rowPX, getX = makeSliderRow(panel, "X", -5, 5, 0, 0.1, function(v)
            deltaX = v; applyOffsets()
        end)
        local rowPY, getY = makeSliderRow(panel, "Y", -5, 5, 0, 0.1, function(v)
            deltaY = v; applyOffsets()
        end)
        local rowPZ, getPZ = makeSliderRow(panel, "Z", -5, 5, 0, 0.1, function(v)
            deltaZ = v; applyOffsets()
        end)

        local rotHdr = makeUI(panel, "TextLabel", {
            Text = "Rotation", Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 10,
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Left
        })

        local rowRX, getRX = makeSliderRow(panel, "X", -180, 180, 0, 1, function(v)
            deltaRX = v; applyOffsets()
        end)
        local rowRY, getRY = makeSliderRow(panel, "Y", -180, 180, 0, 1, function(v)
            deltaRY = v; applyOffsets()
        end)
        local rowRZ, getRZ = makeSliderRow(panel, "Z", -180, 180, 0, 1, function(v)
            deltaRZ = v; applyOffsets()
        end)

        local colorHdr = makeUI(panel, "TextLabel", {
            Text = "Color", Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 10,
            BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14),
            TextXAlignment = Enum.TextXAlignment.Left
        })

        local pickerR, pickerG, pickerB = 255, 255, 255
        local colorOriginals = {}

        if handle then
            for _, part in ipairs(acc:GetDescendants()) do
                if part:IsA("BasePart") then
                    colorOriginals[part] = part.Color
                end
            end
        end

        local function applyAccColor()
            pcall(function()
                local c = Color3.fromRGB(pickerR, pickerG, pickerB)
                for _, part in ipairs(acc:GetDescendants()) do
                    if part:IsA("BasePart") then
                        part.Color = c
                    end
                end
            end)
        end

        local swatchRow = makeUI(panel, "Frame", {
            Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1, BorderSizePixel = 0
        })
        local colorSwatch = makeUI(swatchRow, "Frame", {
            Size = UDim2.new(0, 22, 0, 22), Position = UDim2.new(0, 0, 0.5, -11),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0
        })
        makeUI(colorSwatch, "UICorner", {CornerRadius = UDim.new(0, 5)})
        makeUI(colorSwatch, "UIStroke", {Color = Color3.fromRGB(120, 120, 120), Thickness = 1, Transparency = 0.3})

        local hexLabel = makeUI(swatchRow, "TextLabel", {
            Text = "#FFFFFF", Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 10,
            BackgroundTransparency = 1, Size = UDim2.new(0, 58, 1, 0),
            Position = UDim2.new(0, 28, 0, 0), TextXAlignment = Enum.TextXAlignment.Left
        })

        local resetColorBtn = makeUI(swatchRow, "TextButton", {
            Text = "Reset", Font = Enum.Font.Gotham, TextSize = 10,
            TextColor3 = Color3.fromRGB(200, 200, 200), BackgroundColor3 = Color3.fromRGB(55, 55, 55),
            BackgroundTransparency = 0.3, BorderSizePixel = 0, AutoButtonColor = false,
            Size = UDim2.new(0, 44, 0, 20), Position = UDim2.new(1, -44, 0.5, -10)
        })
        makeUI(resetColorBtn, "UICorner", {CornerRadius = UDim.new(0, 5)})
        resetColorBtn.MouseButton1Click:Connect(function()
            pcall(function()
                for part, origColor in pairs(colorOriginals) do
                    if part and part.Parent then
                        part.Color = origColor
                    end
                end
            end)
            pickerR, pickerG, pickerB = 255, 255, 255
            colorSwatch.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            hexLabel.Text = "#FFFFFF"
        end)

        local function updateSwatchDisplay()
            local c = Color3.fromRGB(pickerR, pickerG, pickerB)
            colorSwatch.BackgroundColor3 = c
            hexLabel.Text = string.format("#%02X%02X%02X", pickerR, pickerG, pickerB)
        end

        local presetColors = {
            {name="Red",    r=220, g=50,  b=50 },
            {name="Orange", r=255, g=140, b=0  },
            {name="Yellow", r=255, g=220, b=0  },
            {name="Green",  r=50,  g=200, b=80 },
            {name="Cyan",   r=0,   g=200, b=220},
            {name="Blue",   r=50,  g=100, b=220},
            {name="Purple", r=150, g=50,  b=220},
            {name="Pink",   r=240, g=80,  b=160},
            {name="White",  r=255, g=255, b=255},
            {name="Black",  r=20,  g=20,  b=20 },
        }

        local presetRow = makeUI(panel, "Frame", {
            Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, BorderSizePixel = 0
        })
        local presetLayout = makeUI(presetRow, "UIListLayout", {
            FillDirection = Enum.FillDirection.Horizontal,
            Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Center
        })

        for _, pc in ipairs(presetColors) do
            local dot = makeUI(presetRow, "TextButton", {
                Size = UDim2.new(0, 17, 0, 17),
                BackgroundColor3 = Color3.fromRGB(pc.r, pc.g, pc.b),
                BorderSizePixel = 0, AutoButtonColor = false, Text = ""
            })
            makeUI(dot, "UICorner", {CornerRadius = UDim.new(0, 4)})
            makeUI(dot, "UIStroke", {Color = Color3.fromRGB(120, 120, 120), Thickness = 1, Transparency = 0.5})
            local pr, pg, pb_ = pc.r, pc.g, pc.b
            dot.MouseButton1Click:Connect(function()
                pickerR, pickerG, pickerB = pr, pg, pb_
                updateSwatchDisplay()
                applyAccColor()
            end)
        end

        local function makeColorSliderRow(labelText, getVal, setVal, accentColor)
            local row = makeUI(panel, "Frame", {
                Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, BorderSizePixel = 0
            })
            makeUI(row, "TextLabel", {
                Text = labelText, Font = Enum.Font.GothamBold,
                TextColor3 = accentColor, TextSize = 10,
                BackgroundTransparency = 1, Size = UDim2.new(0, 14, 1, 0),
                TextXAlignment = Enum.TextXAlignment.Left
            })
            local track = makeUI(row, "Frame", {
                Size = UDim2.new(1, -50, 0, 6), Position = UDim2.new(0, 18, 0.5, -3),
                BackgroundColor3 = Color3.fromRGB(55, 55, 55), BorderSizePixel = 0
            })
            makeUI(track, "UICorner", {CornerRadius = UDim.new(1, 0)})
            local fill = makeUI(track, "Frame", {
                Size = UDim2.new(getVal()/255, 0, 1, 0),
                BackgroundColor3 = accentColor, BorderSizePixel = 0
            })
            makeUI(fill, "UICorner", {CornerRadius = UDim.new(1, 0)})
            local thumb = makeUI(track, "Frame", {
                Size = UDim2.new(0, 10, 0, 10), AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.new(getVal()/255, 0, 0.5, 0),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0
            })
            makeUI(thumb, "UICorner", {CornerRadius = UDim.new(1, 0)})
            makeUI(thumb, "UIStroke", {Color = accentColor, Thickness = 1.5, Transparency = 0.2})
            local valLabel = makeUI(row, "TextLabel", {
                Text = tostring(getVal()), Font = Enum.Font.Gotham,
                TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 10,
                BackgroundTransparency = 1, Size = UDim2.new(0, 28, 1, 0),
                Position = UDim2.new(1, -28, 0, 0), TextXAlignment = Enum.TextXAlignment.Right
            })

            local dragging = false
            local function updateSlider(inputX)
                local relX = math.clamp((inputX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
                local val = math.floor(relX * 255)
                setVal(val)
                fill.Size = UDim2.new(relX, 0, 1, 0)
                thumb.Position = UDim2.new(relX, 0, 0.5, 0)
                valLabel.Text = tostring(val)
                updateSwatchDisplay()
                applyAccColor()
            end

            thumb.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                end
            end)
            track.InputBegan:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    updateSlider(inp.Position.X)
                end
            end)
            UserInputService.InputChanged:Connect(function(inp)
                if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement or inp.UserInputType == Enum.UserInputType.Touch) then
                    updateSlider(inp.Position.X)
                end
            end)
            UserInputService.InputEnded:Connect(function(inp)
                if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)

            return row
        end

        local sliderR = makeColorSliderRow("R", function() return pickerR end, function(v) pickerR = v end, Color3.fromRGB(220, 80, 80))
        local sliderG = makeColorSliderRow("G", function() return pickerG end, function(v) pickerG = v end, Color3.fromRGB(80, 200, 100))
        local sliderB = makeColorSliderRow("B", function() return pickerB end, function(v) pickerB = v end, Color3.fromRGB(80, 140, 220))

        panelLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            panel.Size = UDim2.new(1, 0, 0, panelLayout.AbsoluteContentSize.Y + 14)
        end)
    end

    local accStatusFrame = makeUI(optionsFrame3, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 18), BackgroundTransparency = 1, BorderSizePixel = 0
    })
    local accStatusLabel = makeUI(accStatusFrame, "TextLabel", {
        Text = "Status: Idle",
        Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(145, 145, 145), TextSize = 10,
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center
    })
    acc_statusLabel = accStatusLabel

    local refreshBtnFrame = makeUI(optionsFrame3, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 35),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40), BackgroundTransparency = 0.2, BorderSizePixel = 0
    })
    makeUI(refreshBtnFrame, "UICorner", {CornerRadius = UDim.new(0, 8)})
    local refreshBtn = makeUI(refreshBtnFrame, "TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
        Text = "Edit Position Accessories  \xe2\x96\xb6",
        TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 13, Font = Enum.Font.GothamBold
    })

    local accListContainer = makeUI(optionsFrame3, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        Visible = false
    })
    local accListContainerLayout = makeUI(accListContainer, "UIListLayout", {
        Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center
    })
    accListContainerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        accListContainer.Size = UDim2.new(0.95, 0, 0, accListContainerLayout.AbsoluteContentSize.Y)
    end)

    local noAccLabel = makeUI(accListContainer, "TextLabel", {
        Text = "Scanning accessories...",
        Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(110, 110, 110), TextSize = 11,
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28),
        TextXAlignment = Enum.TextXAlignment.Center
    })

    local editPanelOpen = false

    refreshBtn.MouseButton1Click:Connect(function()
        editPanelOpen = not editPanelOpen

        TweenService:Create(refreshBtnFrame, TweenInfo.new(0.07), {BackgroundTransparency = 0}):Play()
        task.wait(0.12)
        TweenService:Create(refreshBtnFrame, TweenInfo.new(0.1), {BackgroundTransparency = 0.2}):Play()

        if not editPanelOpen then
            refreshBtn.Text = "Edit Position Accessories  \xe2\x96\xb6"
            accListContainer.Visible = false
            uiBlur.Enabled = true
            return
        end

        refreshBtn.Text = "Edit Position Accessories  \xe2\x96\xbc"
        accListContainer.Visible = true
        uiBlur.Enabled = false

        for _, v in ipairs(accListContainer:GetChildren()) do
            if not v:IsA("UIListLayout") then v:Destroy() end
        end

        local char = LocalPlayer.Character
        if not char then
            acc_setStatus("Character not found!", Color3.fromRGB(155, 45, 45)); return
        end

        local found = 0
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Accessory") or obj:IsA("Hat") then
                found = found + 1
                local handle = obj:FindFirstChild("Handle")

                local accBtn = makeUI(accListContainer, "TextButton", {
                    Name = "AccBtn_" .. obj.Name,
                    Size = UDim2.new(1, 0, 0, 30),
                    BackgroundColor3 = Color3.fromRGB(40, 40, 40), BackgroundTransparency = 0.2,
                    BorderSizePixel = 0, AutoButtonColor = false,
                    Text = "  " .. obj.Name,
                    TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 11,
                    Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left
                })
                makeUI(accBtn, "UICorner", {CornerRadius = UDim.new(0, 7)})
                makeUI(accBtn, "UIStroke", {Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.4})

                local arrow = makeUI(accBtn, "TextLabel", {
                    Text = "\xe2\x96\xb6", Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 10,
                    BackgroundTransparency = 1, Size = UDim2.new(0, 18, 1, 0), Position = UDim2.new(1, -20, 0, 0),
                    TextXAlignment = Enum.TextXAlignment.Center
                })

                local panelWrap = makeUI(accListContainer, "Frame", {
                    Name = "PanelWrap_" .. obj.Name,
                    Size = UDim2.new(1, 0, 0, 0),
                    BackgroundTransparency = 1, BorderSizePixel = 0,
                    ClipsDescendants = true, Visible = false
                })
                local panelOpen = false

                local capturedObj = obj
                accBtn.MouseButton1Click:Connect(function()
                    panelOpen = not panelOpen
                    if panelOpen then
                        arrow.Text = "▼"
                        for _, v in ipairs(panelWrap:GetChildren()) do v:Destroy() end
                        buildAccPanel(capturedObj, panelWrap, function()
                            panelOpen = false
                            arrow.Text = "\xe2\x96\xb6"
                            panelWrap.Visible = false
                            panelWrap.Size = UDim2.new(1, 0, 0, 0)
                        end)
                        panelWrap.Visible = true
                        task.wait(0.05)
                        local innerPanel = panelWrap:FindFirstChildWhichIsA("Frame")
                        if innerPanel then
                            panelWrap.Size = UDim2.new(1, 0, 0, innerPanel.AbsoluteSize.Y)
                            innerPanel:GetPropertyChangedSignal("Size"):Connect(function()
                                panelWrap.Size = UDim2.new(1, 0, 0, innerPanel.AbsoluteSize.Y)
                            end)
                        end
                    else
                        arrow.Text = "▶"
                        panelWrap.Visible = false
                        panelWrap.Size = UDim2.new(1, 0, 0, 0)
                    end
                end)
            end
        end

        if found == 0 then
            makeUI(accListContainer, "TextLabel", {
                Text = "No accessories found",
                Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(120, 120, 120), TextSize = 11,
                BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28),
                TextXAlignment = Enum.TextXAlignment.Center
            })
            acc_setStatus("No accessories", Color3.fromRGB(155, 100, 45))
        else
            acc_setStatus(found .. " accessories found", Color3.fromRGB(55, 175, 55))
        end
    end)

    local headlessEnabled = false
    local korbloxEnabled  = false

    local _headlessOriginals = {}
    local _korbloxOriginals  = {}

    local function applyHeadless(state)
        local char = LocalPlayer.Character
        if not char then return end
        pcall(function()
            local head = char:FindFirstChild("Head")
            if not head then return end
            if state then
                local saved = { Transparency = head.Transparency, decals = {} }
                for _, v in ipairs(head:GetChildren()) do
                    if v:IsA("Decal") then saved.decals[v.Name] = v.Transparency end
                end
                _headlessOriginals["Head"] = saved
                head.Transparency = 1
                for _, v in ipairs(head:GetChildren()) do
                    if v:IsA("Decal") then v.Transparency = 1 end
                end
            else
                local saved = _headlessOriginals["Head"]
                if saved then
                    head.Transparency = saved.Transparency
                    for _, v in ipairs(head:GetChildren()) do
                        if v:IsA("Decal") and saved.decals[v.Name] ~= nil then
                            v.Transparency = saved.decals[v.Name]
                        end
                    end
                    _headlessOriginals["Head"] = nil
                else
                    head.Transparency = 0
                    for _, v in ipairs(head:GetChildren()) do
                        if v:IsA("Decal") then v.Transparency = 0 end
                    end
                end
            end
        end)
    end

    local function _restoreKorbloxPart(part, name)
        if not part then return end
        local saved = _korbloxOriginals[name]
        if saved then
            pcall(function() part.MeshId = saved.MeshId end)
            pcall(function() part.TextureID = saved.TextureID end)
            pcall(function() part.Transparency = saved.Transparency end)
            _korbloxOriginals[name] = nil
        else
            pcall(function() part.MeshId = "" end)
            pcall(function() part.TextureID = "" end)
            pcall(function() part.Transparency = 0 end)
        end
    end

    local function applyKorblox(state)
        local char = LocalPlayer.Character
        if not char then return end
        -- Delegasi ke GLOBAL_ApplyKorblox supaya otomatis dukung R6 & R15
        -- lewat satu tempat saja (tidak ada logic ganda yang bisa beda hasil).
        GLOBAL_ApplyKorblox(char, state, false)
    end

    do
        local hkFrame = makeUI(optionsFrame3, "Frame", {
            Size = UDim2.new(0.95, 0, 0, 35),
            BackgroundColor3 = Color3.fromRGB(40, 40, 40),
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0
        })
        makeUI(hkFrame, "UICorner", {CornerRadius = UDim.new(0, 8)})
        makeUI(hkFrame, "TextLabel", {
            Text = "Headless & Korblox", Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 13,
            BackgroundTransparency = 1,
            Size = UDim2.new(0.65, 0, 1, 0),
            Position = UDim2.new(0.03, 0, 0, 0),
            TextXAlignment = Enum.TextXAlignment.Left
        })
        local hkTrack = makeUI(hkFrame, "Frame", {
            Size = UDim2.new(0, 50, 0, 24),
            Position = UDim2.new(1, -58, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Color3.fromRGB(70, 70, 70),
            BorderSizePixel = 0
        })
        makeUI(hkTrack, "UICorner", {CornerRadius = UDim.new(1, 0)})
        local hkInnerShadow = makeUI(hkTrack, "Frame", {
            Size = UDim2.new(1, -4, 1, -4),
            Position = UDim2.new(0, 2, 0, 2),
            BackgroundColor3 = Color3.fromRGB(20, 20, 20),
            BackgroundTransparency = 0.6,
            BorderSizePixel = 0, ZIndex = 1
        })
        makeUI(hkInnerShadow, "UICorner", {CornerRadius = UDim.new(1, 0)})
        local hkKnob = makeUI(hkTrack, "Frame", {
            Size = UDim2.new(0, 20, 0, 20),
            Position = UDim2.new(0, 2, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BorderSizePixel = 0, ZIndex = 3
        })
        makeUI(hkKnob, "UICorner", {CornerRadius = UDim.new(1, 0)})
        local hkKnobGlow = makeUI(hkKnob, "ImageLabel", {
            Size = UDim2.new(1, 8, 1, 8),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image = "rbxassetid://5028857084",
            ImageColor3 = Color3.fromRGB(255, 255, 255),
            ImageTransparency = 0.85,
            ScaleType = Enum.ScaleType.Slice,
            SliceCenter = Rect.new(24, 24, 276, 276),
            ZIndex = 2
        })
        local hkToggled = false
        local hkBtn = makeUI(hkTrack, "TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "", ZIndex = 4
        })
        hkBtn.MouseButton1Click:Connect(function()
            hkToggled = not hkToggled
            headlessEnabled = hkToggled
            korbloxEnabled  = hkToggled
            if hkToggled then
                TweenService:Create(hkTrack, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(50, 180, 50)}):Play()
                TweenService:Create(hkKnob, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = UDim2.new(1, -22, 0.5, 0)}):Play()
                TweenService:Create(hkKnobGlow, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(50, 220, 50), ImageTransparency = 0.6}):Play()
            else
                TweenService:Create(hkTrack, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(70, 70, 70)}):Play()
                TweenService:Create(hkKnob, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = UDim2.new(0, 2, 0.5, 0)}):Play()
                TweenService:Create(hkKnobGlow, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(255, 255, 255), ImageTransparency = 0.85}):Play()
            end
            applyHeadless(hkToggled)
            applyKorblox(hkToggled)
            if acc_statusLabel then
                if hkToggled then
                    acc_statusLabel.Text = "Status: Headless & Korblox ON"
                    acc_statusLabel.TextColor3 = Color3.fromRGB(55, 175, 55)
                else
                    acc_statusLabel.Text = "Status: Headless & Korblox OFF"
                    acc_statusLabel.TextColor3 = Color3.fromRGB(145, 145, 145)
                end
            end
        end)
        LocalPlayer.CharacterAdded:Connect(function()
            _headlessOriginals = {}
            _korbloxOriginals  = {}
            if headlessEnabled then task.wait(1); applyHeadless(true) end
            if korbloxEnabled  then task.wait(1); applyKorblox(true)  end
        end)
    end

    do
        local avatarRgbEnabled = false
        local rgbHue = 0
        local rgbSpeed = 1.0
        local rgbConnection = nil

        local rgbOriginals = {}

        local function saveRgbOriginals(character)
            rgbOriginals = {}
            for _, obj in ipairs(character:GetDescendants()) do
                if (obj:IsA("BasePart") or obj:IsA("MeshPart")) and obj.Name ~= "HumanoidRootPart" then
                    rgbOriginals[obj] = {
                        Color        = obj.Color,
                        Material     = obj.Material,
                        Transparency = obj.Transparency,
                    }
                end
            end
            local head = character:FindFirstChild("Head")
            if head then
                for _, d in ipairs(head:GetDescendants()) do
                    if d:IsA("Decal") or d:IsA("SpecialMesh") then
                        rgbOriginals[d] = { Transparency = d.Transparency }
                    end
                end
            end
        end

        local function restoreRgbOriginals()
            for obj, saved in pairs(rgbOriginals) do
                pcall(function()
                    if obj and obj.Parent then
                        if saved.Color        then obj.Color        = saved.Color        end
                        if saved.Material     then obj.Material     = saved.Material     end
                        if saved.Transparency then obj.Transparency = saved.Transparency end
                    end
                end)
            end
            rgbOriginals = {}
        end

        local function applyAvatarRGB(state)
            if state then
                local character = LocalPlayer.Character
                if character then
                    saveRgbOriginals(character)

                    local head = character:FindFirstChild("Head")
                    if head then
                        pcall(function() head.Transparency = 1 end)
                        for _, d in ipairs(head:GetDescendants()) do
                            if d:IsA("Decal") or d:IsA("SpecialMesh") then
                                pcall(function() d.Transparency = 1 end)
                            end
                        end
                    end
                end

                if not rgbConnection then
                    rgbConnection = RunService.RenderStepped:Connect(function(dt)
                        rgbHue = (rgbHue + dt * rgbSpeed) % 1
                        local char = LocalPlayer.Character
                        if char then
                            for _, obj in ipairs(char:GetDescendants()) do
                                if (obj:IsA("BasePart") or obj:IsA("MeshPart"))
                                    and obj.Name ~= "HumanoidRootPart"
                                    and obj.Name ~= "Head" then
                                    pcall(function()
                                        obj.Material = Enum.Material.ForceField
                                        obj.Color = Color3.fromHSV(rgbHue, 1, 1)
                                        obj.Transparency = 0.4
                                    end)
                                end
                            end
                        end
                    end)
                end
            else
                if rgbConnection then
                    rgbConnection:Disconnect()
                    rgbConnection = nil
                end
                restoreRgbOriginals()
            end
        end

        local rgbFrame = makeUI(optionsFrame3, "Frame", {
            Size = UDim2.new(0.95, 0, 0, 35),
            BackgroundColor3 = Color3.fromRGB(40, 40, 40),
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0
        })
        makeUI(rgbFrame, "UICorner", {CornerRadius = UDim.new(0, 8)})
        makeUI(rgbFrame, "TextLabel", {
            Text = "Avatar RGB", Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 13,
            BackgroundTransparency = 1,
            Size = UDim2.new(0.65, 0, 1, 0),
            Position = UDim2.new(0.03, 0, 0, 0),
            TextXAlignment = Enum.TextXAlignment.Left
        })
        local rgbTrack = makeUI(rgbFrame, "Frame", {
            Size = UDim2.new(0, 50, 0, 24),
            Position = UDim2.new(1, -58, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Color3.fromRGB(70, 70, 70),
            BorderSizePixel = 0
        })
        makeUI(rgbTrack, "UICorner", {CornerRadius = UDim.new(1, 0)})
        local rgbInnerShadow = makeUI(rgbTrack, "Frame", {
            Size = UDim2.new(1, -4, 1, -4),
            Position = UDim2.new(0, 2, 0, 2),
            BackgroundColor3 = Color3.fromRGB(20, 20, 20),
            BackgroundTransparency = 0.6,
            BorderSizePixel = 0, ZIndex = 1
        })
        makeUI(rgbInnerShadow, "UICorner", {CornerRadius = UDim.new(1, 0)})
        local rgbKnob = makeUI(rgbTrack, "Frame", {
            Size = UDim2.new(0, 20, 0, 20),
            Position = UDim2.new(0, 2, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BorderSizePixel = 0, ZIndex = 3
        })
        makeUI(rgbKnob, "UICorner", {CornerRadius = UDim.new(1, 0)})
        local rgbKnobGlow = makeUI(rgbKnob, "ImageLabel", {
            Size = UDim2.new(1, 8, 1, 8),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image = "rbxassetid://5028857084",
            ImageColor3 = Color3.fromRGB(255, 255, 255),
            ImageTransparency = 0.85,
            ScaleType = Enum.ScaleType.Slice,
            SliceCenter = Rect.new(24, 24, 276, 276),
            ZIndex = 2
        })
        local rgbBtn = makeUI(rgbTrack, "TextButton", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "", ZIndex = 4
        })

        rgbBtn.MouseButton1Click:Connect(function()
            avatarRgbEnabled = not avatarRgbEnabled
            if avatarRgbEnabled then
                TweenService:Create(rgbTrack, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(50, 180, 50)}):Play()
                TweenService:Create(rgbKnob, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = UDim2.new(1, -22, 0.5, 0)}):Play()
                TweenService:Create(rgbKnobGlow, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(50, 220, 50), ImageTransparency = 0.6}):Play()
            else
                TweenService:Create(rgbTrack, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(70, 70, 70)}):Play()
                TweenService:Create(rgbKnob, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = UDim2.new(0, 2, 0.5, 0)}):Play()
                TweenService:Create(rgbKnobGlow, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(255, 255, 255), ImageTransparency = 0.85}):Play()
            end
            applyAvatarRGB(avatarRgbEnabled)
            if acc_statusLabel then
                if avatarRgbEnabled then
                    acc_statusLabel.Text = "Status: Avatar RGB ON"
                    acc_statusLabel.TextColor3 = Color3.fromRGB(55, 175, 55)
                else
                    acc_statusLabel.Text = "Status: Avatar RGB OFF"
                    acc_statusLabel.TextColor3 = Color3.fromRGB(145, 145, 145)
                end
            end
        end)

        LocalPlayer.CharacterAdded:Connect(function(character)
            if rgbConnection then
                rgbConnection:Disconnect()
                rgbConnection = nil
            end
            rgbOriginals = {}

            if avatarRgbEnabled then
                task.wait(1.5)
                saveRgbOriginals(character)
                local head = character:FindFirstChild("Head")
                if head then
                    pcall(function() head.Transparency = 1 end)
                    for _, d in ipairs(head:GetDescendants()) do
                        if d:IsA("Decal") or d:IsA("SpecialMesh") then
                            pcall(function() d.Transparency = 1 end)
                        end
                    end
                end
                if not rgbConnection then
                    rgbConnection = RunService.RenderStepped:Connect(function(dt)
                        rgbHue = (rgbHue + dt * rgbSpeed) % 1
                        local char = LocalPlayer.Character
                        if char then
                            for _, obj in ipairs(char:GetDescendants()) do
                                if (obj:IsA("BasePart") or obj:IsA("MeshPart"))
                                    and obj.Name ~= "HumanoidRootPart"
                                    and obj.Name ~= "Head" then
                                    pcall(function()
                                        obj.Material = Enum.Material.ForceField
                                        obj.Color = Color3.fromHSV(rgbHue, 1, 1)
                                        obj.Transparency = 0.4
                                    end)
                                end
                            end
                        end
                    end)
                end
            end
        end)
    end

    makeUI(optionsFrame3, "Frame", {
        Size = UDim2.new(0.9, 0, 0, 1), BackgroundColor3 = Color3.fromRGB(60, 60, 60),
        BackgroundTransparency = 0, BorderSizePixel = 0
    })

    local presetHdr = makeUI(optionsFrame3, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 20), BackgroundTransparency = 1, BorderSizePixel = 0
    })
    makeUI(presetHdr, "TextLabel", {
        Text = "Save Preset",
        Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 11,
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center
    })

    local saveRow = makeUI(optionsFrame3, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 34),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40), BackgroundTransparency = 0.2, BorderSizePixel = 0
    })
    makeUI(saveRow, "UICorner", {CornerRadius = UDim.new(0, 8)})
    makeUI(saveRow, "UIStroke", {Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.4})

    local presetNameBox = makeUI(saveRow, "TextBox", {
        Size = UDim2.new(0.68, 0, 0.65, 0), Position = UDim2.new(0.02, 0, 0.175, 0),
        BackgroundColor3 = Color3.fromRGB(30, 30, 30), BackgroundTransparency = 0.1,
        TextColor3 = Color3.fromRGB(220, 220, 220),
        PlaceholderText = "Preset name...",
        PlaceholderColor3 = Color3.fromRGB(100, 100, 100),
        Font = Enum.Font.Gotham, TextSize = 11,
        ClearTextOnFocus = false, BorderSizePixel = 0, Text = ""
    })
    makeUI(presetNameBox, "UICorner", {CornerRadius = UDim.new(0, 5)})
    presetNameBox.Focused:Connect(function()
        TweenService:Create(presetNameBox, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play()
    end)
    presetNameBox.FocusLost:Connect(function()
        TweenService:Create(presetNameBox, TweenInfo.new(0.12), {BackgroundTransparency = 0.1}):Play()
    end)
    presetNameBox.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then presetNameBox:CaptureFocus() end
    end)

    local saveBtnF = makeUI(saveRow, "Frame", {
        Size = UDim2.new(0.27, 0, 0.65, 0), Position = UDim2.new(0.71, 0, 0.175, 0),
        BackgroundColor3 = Color3.fromRGB(60, 60, 60), BorderSizePixel = 0
    })
    makeUI(saveBtnF, "UICorner", {CornerRadius = UDim.new(0, 5)})
    local saveBtn = makeUI(saveBtnF, "TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
        Text = "Save", Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 11
    })

    local dropOpen = false
    local selectedPresetIdx = nil
    local dropArrow, selectedLabel

    local dropBtnFrame = makeUI(optionsFrame3, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 34),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40), BackgroundTransparency = 0.2, BorderSizePixel = 0
    })
    makeUI(dropBtnFrame, "UICorner", {CornerRadius = UDim.new(0, 8)})
    makeUI(dropBtnFrame, "UIStroke", {Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.4})

    selectedLabel = makeUI(dropBtnFrame, "TextLabel", {
        Text = "Select preset...", Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 11,
        BackgroundTransparency = 1, Size = UDim2.new(0.8, 0, 1, 0),
        Position = UDim2.new(0.04, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    })
    dropArrow = makeUI(dropBtnFrame, "TextLabel", {
        Text = "▼", Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 10,
        BackgroundTransparency = 1, Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -22, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Center
    })
    local dropClickBtn = makeUI(dropBtnFrame, "TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        AutoButtonColor = false, Text = ""
    })

    local dropListOuter = makeUI(optionsFrame3, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(35, 35, 35), BackgroundTransparency = 0,
        BorderSizePixel = 0, Visible = false, ClipsDescendants = true
    })
    makeUI(dropListOuter, "UICorner", {CornerRadius = UDim.new(0, 7)})
    makeUI(dropListOuter, "UIStroke", {Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.3})
    local dropList = makeUI(dropListOuter, "ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true
    })
    local dropListLayout = makeUI(dropList, "UIListLayout", {
        Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center
    })
    makeUI(dropList, "UIPadding", {PaddingTop = UDim.new(0,4), PaddingBottom = UDim.new(0,4)})
    dropListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        dropList.CanvasSize = UDim2.new(0, 0, 0, dropListLayout.AbsoluteContentSize.Y + 8)
    end)

    local actionRow = makeUI(optionsFrame3, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 34),
        BackgroundTransparency = 1, BorderSizePixel = 0
    })
    makeUI(actionRow, "UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6)
    })

    local function makeActionBtn(parent, txt, bgColor, textColor)
        local f = makeUI(parent, "Frame", {
            Size = UDim2.new(0.46, 0, 0, 32),
            BackgroundColor3 = bgColor, BackgroundTransparency = 0.15, BorderSizePixel = 0
        })
        makeUI(f, "UICorner", {CornerRadius = UDim.new(0, 7)})
        local b = makeUI(f, "TextButton", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
            Text = txt, Font = Enum.Font.GothamBold, TextColor3 = textColor, TextSize = 12
        })
        return b, f
    end

    local loadBtn, loadBtnF = makeActionBtn(actionRow, "Load", Color3.fromRGB(40, 40, 40), Color3.fromRGB(255, 255, 255))
    local deleteBtn, deleteBtnF = makeActionBtn(actionRow, "Delete", Color3.fromRGB(40, 40, 40), Color3.fromRGB(255, 255, 255))

    local function closeDropdown()
        dropOpen = false
        dropArrow.Text = "▼"
        TweenService:Create(dropListOuter, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0.95, 0, 0, 0)}):Play()
        task.delay(0.16, function() dropListOuter.Visible = false end)
    end

    local function rebuildDropdown()
        for _, v in ipairs(dropList:GetChildren()) do
            if not v:IsA("UIListLayout") and not v:IsA("UIPadding") then v:Destroy() end
        end

        if #ACC_PRESETS == 0 then
            makeUI(dropList, "TextLabel", {
                Text = "No presets yet",
                Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(120, 120, 120), TextSize = 11,
                BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 26),
                TextXAlignment = Enum.TextXAlignment.Center
            })
            dropListOuter.Size = UDim2.new(0.95, 0, 0, 34)
            return
        end

        for i, preset in ipairs(ACC_PRESETS) do
            local itemF = makeUI(dropList, "Frame", {
                Size = UDim2.new(1, -8, 0, 28),
                BackgroundColor3 = Color3.fromRGB(50, 50, 50), BackgroundTransparency = 0.3, BorderSizePixel = 0
            })
            makeUI(itemF, "UICorner", {CornerRadius = UDim.new(0, 5)})
            local itemBtn = makeUI(itemF, "TextButton", {
                Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
                Text = "  " .. preset.name,
                Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(220, 220, 220), TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd
            })

            local count = 0
            for _, v in pairs(preset.slots or {}) do
                for _ in tostring(v):gmatch("[^,]+") do count = count + 1 end
            end
            makeUI(itemF, "TextLabel", {
                Text = count .. " item", Font = Enum.Font.Gotham,
                TextColor3 = Color3.fromRGB(150, 150, 150), TextSize = 10,
                BackgroundTransparency = 1, Size = UDim2.new(0.25, 0, 1, 0),
                Position = UDim2.new(0.75, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Center
            })

            local capturedI = i
            itemBtn.MouseButton1Click:Connect(function()
                selectedPresetIdx = capturedI
                selectedLabel.Text = ACC_PRESETS[capturedI].name
                selectedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                closeDropdown()
            end)
        end

        local totalH = math.min(dropListLayout.AbsoluteContentSize.Y + 10, 150)
        dropListOuter.Size = UDim2.new(0.95, 0, 0, totalH)
    end

    acc_presetDropUpdate = rebuildDropdown

    dropClickBtn.MouseButton1Click:Connect(function()
        dropOpen = not dropOpen
        rebuildDropdown()
        if dropOpen then
            dropArrow.Text = "▲"
            dropListOuter.Visible = true
            task.wait()
            local totalH = math.min(dropListLayout.AbsoluteContentSize.Y + 10, 150)
            dropListOuter.Size = UDim2.new(0.95, 0, 0, 0)
            TweenService:Create(dropListOuter, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Size = UDim2.new(0.95, 0, 0, totalH)}):Play()
        else
            closeDropdown()
        end
    end)

    saveBtn.MouseButton1Click:Connect(function()
        TweenService:Create(saveBtnF, TweenInfo.new(0.07), {BackgroundTransparency = 0}):Play()
        task.wait(0.12)
        TweenService:Create(saveBtnF, TweenInfo.new(0.1), {BackgroundTransparency = 0.1}):Play()

        local name = presetNameBox.Text:match("^%s*(.-)%s*$")
        if name == "" then
            acc_setStatus("Enter preset name!", Color3.fromRGB(195, 165, 50)); return
        end

        local function collectSlotsFromBoxes()
            local slots = {}
            for descProp, box in pairs(acc_slotBoxRegistry) do
                local val = box.Text:match("^%s*(.-)%s*$")
                if val and val ~= "" then
                    slots[descProp] = val
                end
            end
            return slots
        end

        for i, p in ipairs(ACC_PRESETS) do
            if p.name:lower() == name:lower() then
                ACC_PRESETS[i].slots = collectSlotsFromBoxes()
                ACC_PRESETS[i].transforms = acc_collectCurrentTransforms()
                ACC_PRESETS[i].head = AC_HEAD_APPLIED and tostring(AC_HEAD_APPLIED) or nil
                acc_savePresets()
                rebuildDropdown()
                acc_setStatus("Preset '" .. name .. "' updated!", Color3.fromRGB(55, 175, 55))
                presetNameBox.Text = ""
                return
            end
        end

        local slots = collectSlotsFromBoxes()
        local transforms = acc_collectCurrentTransforms()
        local headId = AC_HEAD_APPLIED and tostring(AC_HEAD_APPLIED) or nil
        table.insert(ACC_PRESETS, {name = name, slots = slots, transforms = transforms, head = headId})
        acc_savePresets()
        rebuildDropdown()
        acc_setStatus("Preset '" .. name .. "' saved!", Color3.fromRGB(55, 175, 55))
        presetNameBox.Text = ""
    end)

    loadBtn.MouseButton1Click:Connect(function()
        TweenService:Create(loadBtnF, TweenInfo.new(0.07), {BackgroundTransparency = 0}):Play()
        task.wait(0.12)
        TweenService:Create(loadBtnF, TweenInfo.new(0.1), {BackgroundTransparency = 0.15}):Play()

        if not selectedPresetIdx or not ACC_PRESETS[selectedPresetIdx] then
            acc_setStatus("Select a preset first!", Color3.fromRGB(195, 165, 50)); return
        end
        local preset = ACC_PRESETS[selectedPresetIdx]
        for descProp, box in pairs(acc_slotBoxRegistry) do
            local val = preset.slots and preset.slots[descProp]
            if val and tostring(val) ~= "" then
                box.Text = tostring(val)
                box.TextColor3 = Color3.fromRGB(200, 200, 200)
            else
                box.Text = ""
            end
        end
        acc_applyPreset(preset)
    end)

    deleteBtn.MouseButton1Click:Connect(function()
        TweenService:Create(deleteBtnF, TweenInfo.new(0.07), {BackgroundTransparency = 0}):Play()
        task.wait(0.12)
        TweenService:Create(deleteBtnF, TweenInfo.new(0.1), {BackgroundTransparency = 0.15}):Play()

        if not selectedPresetIdx or not ACC_PRESETS[selectedPresetIdx] then
            acc_setStatus("Select a preset first!", Color3.fromRGB(195, 165, 50)); return
        end
        local removedName = ACC_PRESETS[selectedPresetIdx].name
        table.remove(ACC_PRESETS, selectedPresetIdx)
        selectedPresetIdx = nil
        selectedLabel.Text = "Select preset..."
        selectedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        acc_savePresets()
        rebuildDropdown()
        acc_setStatus("Preset '" .. removedName .. "' deleted", Color3.fromRGB(145, 145, 145))
    end)

    rebuildDropdown()

    makeUI(optionsFrame3, "Frame", {
        Size = UDim2.new(0.9, 0, 0, 1), BackgroundColor3 = Color3.fromRGB(60, 60, 60),
        BackgroundTransparency = 0, BorderSizePixel = 0
    })

    local clearAccFrame = makeUI(optionsFrame3, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 35),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40), BackgroundTransparency = 0.2, BorderSizePixel = 0
    })
    makeUI(clearAccFrame, "UICorner", {CornerRadius = UDim.new(0, 8)})
    local clearAccBtn = makeUI(clearAccFrame, "TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
        Text = "Remove All Accessories",
        TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 13, Font = Enum.Font.GothamBold
    })
    clearAccBtn.MouseButton1Click:Connect(function()
        TweenService:Create(clearAccFrame, TweenInfo.new(0.07), {BackgroundTransparency = 0}):Play()
        task.wait(0.12)
        TweenService:Create(clearAccFrame, TweenInfo.new(0.1), {BackgroundTransparency = 0.2}):Play()
        ac_clearAllAccessories()
        for _, v in ipairs(accListContainer:GetChildren()) do
            if not v:IsA("UIListLayout") then v:Destroy() end
        end
        acc_setStatus("All accessories removed!", Color3.fromRGB(145, 145, 145))
    end)
end

local animChangerEnabled = false
local animChangerConnections = {}
local animCustomIds = {
    Run = nil, Walk = nil, Fall = nil, Jump = nil,
    Idle = nil, Swim = nil, Climb = nil
}

local ANIM_PRESETS = {
    {name="Adidas Community",  idle1=122257458498464,  idle2=102357151005774,  walk=122150855457006,   run=82598234841035,     jump=75290611992385,    fall=98600215928904,    climb=88763136693023,   swimidle=109346520324160, swim=133308483266208, useGetObjects=true},
    {name="Glow Motion",       idle1=72213510878866,   idle2=72213510878866,   walk=124733969277188,   run=91745899537026,     jump=126137138096765,   fall=76868289213402,    climb=122281742555667,  swimidle=78813763153341,  swim=78813763153341,    useGetObjects=true},
    {name="Billie Eilish",     idle1=82009039247070,   idle2=82009039247070,   walk=74056522836252,    run=107895705891639,    jump=114806832298003,   fall=132771121298158,   climb=95937554524959,   swimidle=78340083978503,  swim=78340083978503,    useGetObjects=true},
    {name="Handstand Animation Pack", idle1=135575165028849, idle2=135575165028849, walk=117765825848453, run=99875831172373, jump=128965057150875, fall=111831828617770, climb=112505979110458, swimidle=82730580219519, swim=82730580219519, useGetObjects=true},
    {name="Dog Bunny Animation Pack", idle1=136322765510200, idle2=136322765510200, walk=93195124672420, run=80744014032460, jump=91689511109384, fall=138712913675658, climb=139564919712366, swimidle=88811196999845, swim=88811196999845, useGetObjects=true},
    {name="Hoverboard Animation Pack", idle1=93616657066536, idle2=93616657066536, walk=97065248057640, run=89532448464946, jump=102860697251632, fall=90353939293034, climb=128257589957243, swimidle=133596372835000, swim=133596372835000, useGetObjects=true},
    {name="Sprinter Animation Pack", idle1=129794821448421, idle2=129794821448421, walk=102423799534100, run=120741731730819, jump=139321637247351, fall=76408670644983, climb=123076402162196, swimidle=94399444567795, swim=94399444567795, useGetObjects=true},
    {name="Fighter Animation Pack", idle1=88016093360951, idle2=88016093360951, walk=82280787041246, run=74327884548186, jump=131675266554473, fall=134961140457349, climb=136141293963563, swimidle=96909954438932, swim=96909954438932, useGetObjects=true},
    {name="Moonwalker Animation Pack", idle1=92710716765283, idle2=92710716765283, walk=114763801999339, run=101531926378460, jump=104533631513747, fall=70566441403811, climb=79306475091221, swimidle=98563274763262, swim=98563274763262, useGetObjects=true},
    {name="Bruiser Animation Pack", idle1=91486182566842, idle2=91486182566842, walk=110119880881706, run=136670254583990, jump=110949855044563, fall=114388482037548, climb=113866830860789, swimidle=113544566765768, swim=113544566765768, useGetObjects=true},
    {name="Angel Animation Pack", idle1=106617557168449, idle2=106617557168449, walk=129380445505644, run=110540935388974, jump=117028353539960, fall=137098035754306, climb=72948750270080, swimidle=125903638047924, swim=125903638047924, useGetObjects=true},
    {name="Aura Animation Pack", idle1=103073671112449, idle2=103073671112449, walk=107974792006222, run=126690709549004, jump=131932286655764, fall=74746323396145, climb=103443334658077, swimidle=128846499821276, swim=128846499821276, useGetObjects=true},
    {name="Floating & Hovering In The Air", idle1=115906557603671, idle2=115906557603671, walk=119786323122017, run=129278715401446, jump=112005766742735, fall=72058760380261, climb=106619418917040, swimidle=94244427859958, swim=94244427859958, useGetObjects=true},
    {name="Underwater Siren Mermaid", idle1=72100162263901, idle2=72100162263901, walk=139341244827854, run=73336016052986, jump=75942009951199, fall=70703952625242, climb=102631234037365, swimidle=135995507444253, swim=135995507444253, useGetObjects=true},
    {name="Riding On My Bike", idle1=132700029208610, idle2=132700029208610, walk=93570377820495, run=73184418176779, jump=86465002608207, fall=133447118806772, climb=123731540239693, swimidle=137128132254475, swim=137128132254475, useGetObjects=true},
    {name="Effortless Aura", idle1=106390953994044, idle2=106390953994044, walk=111484087971615, run=112515971043909, jump=89547925261998, fall=135065867268215, climb=116904502538281, swimidle=133821165523889, swim=133821165523889, useGetObjects=true},
    {name="Bicyclist / Bike",  idle1=110301614683999, idle2=110301614683999, walk=78201729008814, run=82563400820481, jump=107759406184171, fall=116348378285841, climb=106713991255001, swimidle=77327275394482, swim=77327275394482, useGetObjects=true},
    {name="Cute Sit", idle1=110542674051174, idle2=110542674051174, walk=118167050072619, run=113254670339077, jump=124327113511763, fall=99664258493491, climb=125102831404256, swimidle=112149520105094, swim=112149520105094, useGetObjects=true},
    {name="Cute Bouncy", idle1=112758171987743, idle2=112758171987743, walk=105398643971664, run=81980688988481, jump=95845383984913, fall=91206221270256, climb=77455242814172, swimidle=137674505873151, swim=137674505873151, useGetObjects=true},
    {name="Astronaut",         idle1=891621366,        idle2=891633237,        walk=891667138,         run=10921039308,        jump=891627522,         fall=891617961,         climb=10921032124,      swimidle=891663592,     swim=891663592},
    {name="Bold",              idle1=16738333868,      idle2=16738334710,      walk=16738340646,       run=16738337225,        jump=16738336650,       fall=16738333171,       climb=16738332169,      swimidle=16738339817,   swim=16738339158},
    {name="Bubbly",            idle1=910004836,        idle2=910009958,        walk=910034870,         run=10921057244,        jump=910016857,         fall=910001910,         climb=nil,              swimidle=910030921,     swim=910028158},
    {name="Cartoony",          idle1=742637544,        idle2=742638445,        walk=742640026,         run=10921076136,        jump=742637942,         fall=742637151,         climb=742636889,        swimidle=10921079380,   swim=10921079380},
    {name="Elder",             idle1=10921101664,      idle2=10921102574,      walk=10921111375,       run=10921104374,        jump=10921107367,       fall=10921105765,       climb=845392038,        swimidle=10921110146,   swim=10921108971},
    {name="Knight",            idle1=657595757,        idle2=657568135,        walk=10921127095,       run=10921121197,        jump=910016857,         fall=10921122579,       climb=10921125160,      swimidle=10921125935,   swim=10921125160},
    {name="Levitation",        idle1=616006778,        idle2=616008087,        walk=616013216,         run=616010382,          jump=616008936,         fall=616005863,         climb=10921132092,      swimidle=10921139478,   swim=10921138209},
    {name="Mage",              idle1=707742142,        idle2=707855907,        walk=707897309,         run=10921148209,        jump=10921149743,       fall=707829716,         climb=707826056,        swimidle=707894699,     swim=707876443},
    {name="Ninja",             idle1=656117400,        idle2=656118341,        walk=656121766,         run=656118852,          jump=656117878,         fall=656115606,         climb=656114359,        swimidle=656118341,     swim=nil},
    {name="OldSchool",         idle1=10921230744,      idle2=10921232093,      walk=10921244891,       run=10921240218,        jump=10921242013,       fall=10921241244,       climb=10921229866,      swimidle=10921244018,   swim=10921243048},
    {name="Pirate",            idle1=750781874,        idle2=750782770,        walk=750785693,         run=750783738,          jump=750782230,         fall=750780242,         climb=750779899,        swimidle=750785176,     swim=750784579},
    {name="Robot",             idle1=616088211,        idle2=616089559,        walk=616095330,         run=10921250460,        jump=616090535,         fall=616087089,         climb=616086039,        swimidle=10921253767,   swim=10921253142},
    {name="Stylish",           idle1=616136790,        idle2=616138447,        walk=616146177,         run=10921276116,        jump=616139451,         fall=616134815,         climb=10921271391,      swimidle=10921281964,   swim=10921281000},
    {name="SuperHero",         idle1=10921288909,      idle2=10921290167,      walk=10921298616,       run=10921291831,        jump=10921294559,       fall=10921293373,       climb=10921286911,      swimidle=10921297391,   swim=10921295495},
    {name="Toy",               idle1=782841498,        idle2=782845736,        walk=782843345,         run=10921306285,        jump=10921308158,       fall=782846423,         climb=10921300839,      swimidle=10921310341,   swim=10921309319},
    {name="Vampire",           idle1=1083445855,       idle2=1083450166,       walk=1083473930,        run=10921320299,        jump=1083455352,        fall=1083443587,        climb=1083439238,       swimidle=10921325443,   swim=10921324408},
    {name="Werewolf",          idle1=1083195517,       idle2=1083214717,       walk=1083178339,        run=10921336997,        jump=1083218792,        fall=1083189019,        climb=10921329322,      swimidle=10921341319,   swim=10921340419},
    {name="Cowboy",            idle1=1014390418,       idle2=1014398616,       walk=1014421541,        run=1014401683,         jump=1014394726,        fall=1014384571,        climb=1014380606,       swimidle=1014411816,    swim=1014406523},
    {name="Ghost",             idle1=616006778,        idle2=616008087,        walk=616013216,         run=616013216,          jump=616008936,         fall=616005863,         climb=616003713,        swimidle=616012453,     swim=616011509},
    {name="Patrol",            idle1=1149612882,       idle2=1150842221,       walk=1151231493,        run=1150967949,         jump=1148811837,        fall=1148863382,        climb=1148811837,       swimidle=1151221899,    swim=1151204998},
    {name="Sneaky",            idle1=1132473842,       idle2=1132477671,       walk=1132510133,        run=1132494274,         jump=1132489853,        fall=1132469004,        climb=1132461372,       swimidle=1132506407,    swim=1132500520},
    {name="Sports (Adidas)",   idle1=18537376492,      idle2=18537371272,      walk=18537392113,       run=18537384940,        jump=18537380791,        fall=18537367238,       climb=18537363391,      swimidle=18537387180,   swim=18537389531},
    {name="Wicked Dancing",    idle1=92849173543269,   idle2=132238900951109,  walk=73718308412641,    run=135515454877967,    jump=78508480717326,    fall=78147885297412,    climb=129447497744818,  swimidle=129183123083281, swim=110657013921774, useGetObjects=true},
    {name="Adidas Aura",       idle1=110211186840347,  idle2=114191137265065,  walk=83842218823011,    run=118320322718866,    jump=109996626521204,   fall=95603166884636,    climb=97824616490448,   swimidle=94922130551805,  swim=134530128383903,  useGetObjects=true},
    {name="None (Reset)",      idle1=0,                idle2=0,                walk=0,                 run=0,                  jump=0,                 fall=0,                 climb=nil,              swimidle=0,             swim=0},
}

local currentAnimChanger = nil
local function stopCustomAnimate()
    if currentAnimChanger then
        pcall(function() currentAnimChanger:Disconnect() end)
        currentAnimChanger = nil
    end
end

local function az_freeze(hum, char)
    pcall(function()
        hum.PlatformStand = true
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and not part.Anchored then
                part.Anchored = true
            end
        end
    end)
end

local function az_unfreeze(hum, char)
    pcall(function()
        hum.PlatformStand = false
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.Anchored then
                part.Anchored = false
            end
        end
        pcall(function()
            if hum.UseJumpPower then
                hum.JumpPower = currentJumpPower
            else
                hum.JumpHeight = currentJumpPower / 4
            end
        end)
        if InfiniteJumpEnabled and JumpEffect.currentHumanoid == hum then
            JumpEffect.baseJumpPower = currentJumpPower
        end
    end)
end

local function az_stopAllTracks(hum)
    pcall(function()
        for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
            track:Stop(0)
        end
    end)
end

local function az_refresh(hum)
    pcall(function()
        hum:ChangeState(Enum.HumanoidStateType.Freefall)
    end)
end

local function az_refreshSwim(hum)
    pcall(function()
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        task.wait(0.1)
        hum:ChangeState(Enum.HumanoidStateType.Swimming)
    end)
end

local function az_refreshClimb(hum)
    pcall(function()
        hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        task.wait(0.1)
        hum:ChangeState(Enum.HumanoidStateType.Climbing)
    end)
end

local function waitForAnimateSlots(Animate, timeoutSec)
    timeoutSec = timeoutSec or 5
    local slots = {"idle", "walk", "run", "jump", "fall", "climb", "swimidle", "swim"}
    local children = {
        idle     = "Animation1",
        walk     = "WalkAnim",
        run      = "RunAnim",
        jump     = "JumpAnim",
        fall     = "FallAnim",
        climb    = "ClimbAnim",
        swimidle = "SwimIdle",
        swim     = "Swim",
    }
    local startT = os.clock()
    while os.clock() - startT < timeoutSec do
        local ready = true
        for _, slot in ipairs(slots) do
            local folder = Animate:FindFirstChild(slot)
            if not folder or not folder:FindFirstChild(children[slot]) then
                ready = false
                break
            end
        end
        if ready then return true end
        task.wait(0.1)
    end
    return false
end

local function fetchAndApplyBundle(preset, statusCb)
    if statusCb then statusCb("Status: Applying...", Color3.fromRGB(195,165,50)) end

    local char = LocalPlayer.Character
    if not char then
        if statusCb then statusCb("Status: No character!", Color3.fromRGB(200,60,60)) end
        return
    end
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
    if not hum then return end
    local Animate = char:FindFirstChild("Animate") or char:WaitForChild("Animate", 5)
    if not Animate then
        if statusCb then statusCb("Status: Animate script not found!", Color3.fromRGB(200,60,60)) end
        return
    end
    if not waitForAnimateSlots(Animate, 5) then
        if statusCb then statusCb("Status: Animate not ready, retrying...", Color3.fromRGB(195,165,50)) end
    end

    task.spawn(function()
        local function resolveId(id)
            if preset.useGetObjects and id and id ~= 0 then
                return GetReal(id)
            end
            return id
        end

        local ids = {
            idle1    = resolveId(preset.idle1),
            idle2    = resolveId(preset.idle2),
            walk     = resolveId(preset.walk),
            run      = resolveId(preset.run),
            jump     = resolveId(preset.jump),
            fall     = resolveId(preset.fall),
            climb    = resolveId(preset.climb),
            swimidle = resolveId(preset.swimidle),
            swim     = resolveId(preset.swim),
        }

        az_freeze(hum, char)
        task.wait(0.1)

        az_stopAllTracks(hum)

        local needRefresh      = false
        local needRefreshSwim  = false
        local needRefreshClimb = false

        pcall(function()
            if ids.idle1 and ids.idle1 ~= 0 and Animate.idle and Animate.idle.Animation1 then
                Animate.idle.Animation1.AnimationId = "rbxassetid://" .. tostring(ids.idle1)
                needRefresh = true
            end
            if ids.idle2 and ids.idle2 ~= 0 and Animate.idle and Animate.idle.Animation2 then
                Animate.idle.Animation2.AnimationId = "rbxassetid://" .. tostring(ids.idle2)
                needRefresh = true
            end
            if ids.walk and ids.walk ~= 0 and Animate.walk and Animate.walk.WalkAnim then
                Animate.walk.WalkAnim.AnimationId = "rbxassetid://" .. tostring(ids.walk)
                needRefresh = true
            end
            if ids.run and ids.run ~= 0 and Animate.run and Animate.run.RunAnim then
                Animate.run.RunAnim.AnimationId = "rbxassetid://" .. tostring(ids.run)
                needRefresh = true
            end
            if ids.jump and ids.jump ~= 0 and Animate.jump and Animate.jump.JumpAnim then
                Animate.jump.JumpAnim.AnimationId = "rbxassetid://" .. tostring(ids.jump)
                needRefresh = true
            end
            if ids.fall and ids.fall ~= 0 and Animate.fall and Animate.fall.FallAnim then
                Animate.fall.FallAnim.AnimationId = "rbxassetid://" .. tostring(ids.fall)
                needRefresh = true
            end
            if ids.climb and ids.climb ~= 0 and Animate.climb and Animate.climb.ClimbAnim then
                Animate.climb.ClimbAnim.AnimationId = "rbxassetid://" .. tostring(ids.climb)
                needRefreshClimb = true
            end
            if ids.swimidle and ids.swimidle ~= 0 and Animate.swimidle and Animate.swimidle.SwimIdle then
                Animate.swimidle.SwimIdle.AnimationId = "rbxassetid://" .. tostring(ids.swimidle)
                needRefreshSwim = true
            end
            if ids.swim and ids.swim ~= 0 and Animate.swim and Animate.swim.Swim then
                Animate.swim.Swim.AnimationId = "rbxassetid://" .. tostring(ids.swim)
                needRefreshSwim = true
            end
        end)

        if needRefresh      then az_refresh(hum) end
        if needRefreshSwim  then az_refreshSwim(hum) end
        if needRefreshClimb then az_refreshClimb(hum) end

        task.wait(0.1)
        az_unfreeze(hum, char)

        if statusCb then
            statusCb("Status: " .. preset.name .. " applied!", Color3.fromRGB(55,175,55))
        end
    end)
end

local function applyCustomSingleSlot(slotName, animId, statusCb)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
    if not hum then return end
    local Animate = char:FindFirstChild("Animate") or char:WaitForChild("Animate", 5)
    if not Animate then return end
    waitForAnimateSlots(Animate, 5)

    local numId = tonumber(animId)
    if numId and tostring(numId):len() >= 13 then
        numId = GetReal(numId)
    end
    local url = "rbxassetid://" .. tostring(numId or animId)

    az_freeze(hum, char)
    task.wait(0.1)
    az_stopAllTracks(hum)

    pcall(function()
        if slotName == "Run" then
            Animate.run.RunAnim.AnimationId = url
            az_refresh(hum)
        elseif slotName == "Walk" then
            Animate.walk.WalkAnim.AnimationId = url
            az_refresh(hum)
        elseif slotName == "Fall" then
            Animate.fall.FallAnim.AnimationId = url
            az_refresh(hum)
        elseif slotName == "Jump" then
            Animate.jump.JumpAnim.AnimationId = url
            az_refresh(hum)
        elseif slotName == "Idle" then
            Animate.idle.Animation1.AnimationId = url
            az_refresh(hum)
        elseif slotName == "Swim" then
            Animate.swim.Swim.AnimationId = url
            az_refreshSwim(hum)
        elseif slotName == "Climb" then
            Animate.climb.ClimbAnim.AnimationId = url
            az_refreshClimb(hum)
        end
    end)

    task.wait(0.1)
    az_unfreeze(hum, char)

    if statusCb then statusCb("Status: " .. slotName .. " applied!", Color3.fromRGB(55,175,55)) end
end

local function applyAllCustomIds(statusCb)
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
    if not hum then return end
    local Animate = char:FindFirstChild("Animate") or char:WaitForChild("Animate", 5)
    if not Animate then return end
    waitForAnimateSlots(Animate, 5)

    local count = 0
    stopCustomAnimate()

    az_freeze(hum, char)
    task.wait(0.1)
    az_stopAllTracks(hum)

    local needRefresh      = false
    local needRefreshSwim  = false
    local needRefreshClimb = false

    for slotName, animId in pairs(animCustomIds) do
        if animId and animId ~= "" then
            local numId = tonumber(animId)
            if numId and tostring(numId):len() >= 13 then
                numId = GetReal(numId)
            end
            local url = "rbxassetid://" .. tostring(numId or animId)
            pcall(function()
                if slotName == "Run" and Animate.run and Animate.run.RunAnim then
                    Animate.run.RunAnim.AnimationId = url; needRefresh = true; count = count + 1
                elseif slotName == "Walk" and Animate.walk and Animate.walk.WalkAnim then
                    Animate.walk.WalkAnim.AnimationId = url; needRefresh = true; count = count + 1
                elseif slotName == "Fall" and Animate.fall and Animate.fall.FallAnim then
                    Animate.fall.FallAnim.AnimationId = url; needRefresh = true; count = count + 1
                elseif slotName == "Jump" and Animate.jump and Animate.jump.JumpAnim then
                    Animate.jump.JumpAnim.AnimationId = url; needRefresh = true; count = count + 1
                elseif slotName == "Idle" and Animate.idle and Animate.idle.Animation1 then
                    Animate.idle.Animation1.AnimationId = url; needRefresh = true; count = count + 1
                elseif slotName == "Swim" and Animate.swim and Animate.swim.Swim then
                    Animate.swim.Swim.AnimationId = url; needRefreshSwim = true; count = count + 1
                elseif slotName == "Climb" and Animate.climb and Animate.climb.ClimbAnim then
                    Animate.climb.ClimbAnim.AnimationId = url; needRefreshClimb = true; count = count + 1
                end
            end)
        end
    end

    if needRefresh      then az_refresh(hum) end
    if needRefreshSwim  then az_refreshSwim(hum) end
    if needRefreshClimb then az_refreshClimb(hum) end

    task.wait(0.1)
    az_unfreeze(hum, char)

    if statusCb then
        if count > 0 then
            statusCb("Status: " .. count .. " custom anims applied!", Color3.fromRGB(55,175,55))
        else
            statusCb("Status: Set animation first!", Color3.fromRGB(195,165,50))
        end
    end
end

local function disableAnimationChanger()
    stopCustomAnimate()

    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local Animate = char:FindFirstChild("Animate")
    if not Animate or not hum then return end

    az_freeze(hum, char)
    task.wait(0.1)
    az_stopAllTracks(hum)

    local defaults = {
        {slot="run",      child="RunAnim",   id=507767714},
        {slot="walk",     child="WalkAnim",  id=507777826},
        {slot="fall",     child="FallAnim",  id=507767453},
        {slot="jump",     child="JumpAnim",  id=507765000},
        {slot="idle",     child="Animation1",id=507766388},
        {slot="swim",     child="Swim",      id=507784897},
        {slot="climb",    child="ClimbAnim", id=507770905},
    }
    for _, d in ipairs(defaults) do
        pcall(function()
            local folder = Animate:FindFirstChild(d.slot)
            if folder then
                local anim = folder:FindFirstChild(d.child)
                if anim then
                    anim.AnimationId = "rbxassetid://" .. tostring(d.id)
                end
            end
        end)
    end

    az_refresh(hum)
    task.wait(0.1)
    az_unfreeze(hum, char)
end

function createAnimationChangerPage()
    local headerAnim = makeUI(optionsFrame5, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 22),
        BackgroundTransparency = 1, BorderSizePixel = 0
    })
    makeUI(headerAnim, "TextLabel", {
        Text = "Animation Changer",
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 12,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center
    })

    local animSelectedPreset = AC_ANIM_PRESET_APPLIED
    local animToggleFrame = makeUI(optionsFrame5, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 35),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        BackgroundTransparency = 0.2, BorderSizePixel = 0
    })
    makeUI(animToggleFrame, "UICorner", {CornerRadius = UDim.new(0, 8)})
    makeUI(animToggleFrame, "TextLabel", {
        Text = "Enable Animation Changer",
        Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 13,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.65, 0, 1, 0),
        Position = UDim2.new(0.03, 0, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Left
    })
    local animToggleTrack = makeUI(animToggleFrame, "Frame", {
        Size = UDim2.new(0, 50, 0, 24),
        Position = UDim2.new(1, -58, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.fromRGB(70, 70, 70),
        BorderSizePixel = 0
    })
    makeUI(animToggleTrack, "UICorner", {CornerRadius = UDim.new(1, 0)})
    local animInnerShadow = makeUI(animToggleTrack, "Frame", {
        Size = UDim2.new(1, -4, 1, -4),
        Position = UDim2.new(0, 2, 0, 2),
        BackgroundColor3 = Color3.fromRGB(20, 20, 20),
        BackgroundTransparency = 0.6,
        BorderSizePixel = 0, ZIndex = 1
    })
    makeUI(animInnerShadow, "UICorner", {CornerRadius = UDim.new(1, 0)})
    local animKnob = makeUI(animToggleTrack, "Frame", {
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(0, 2, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BorderSizePixel = 0, ZIndex = 3
    })
    makeUI(animKnob, "UICorner", {CornerRadius = UDim.new(1, 0)})
    local animKnobGlow = makeUI(animKnob, "ImageLabel", {
        Size = UDim2.new(1, 8, 1, 8),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Image = "rbxassetid://5028857084",
        ImageColor3 = Color3.fromRGB(255, 255, 255),
        ImageTransparency = 0.85,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(24, 24, 276, 276),
        ZIndex = 2
    })
    local animToggleBtn = makeUI(animToggleTrack, "TextButton", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1, Text = "", ZIndex = 4
    })

    local animStatusLabel

    local animDropContainer = makeUI(optionsFrame5, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 62),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0, ClipsDescendants = false
    })
    makeUI(animDropContainer, "UICorner", {CornerRadius = UDim.new(0, 8)})
    makeUI(animDropContainer, "TextLabel", {
        Text = "Animation Changer", Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 11,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, -12, 0, 18),
        Position = UDim2.new(0, 8, 0, 4),
        TextXAlignment = Enum.TextXAlignment.Left
    })
    local animDropBtnFrame = makeUI(animDropContainer, "Frame", {
        Size = UDim2.new(1, -76, 0, 26),
        Position = UDim2.new(0, 6, 0, 28),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40), BackgroundTransparency = 0.2, BorderSizePixel = 0
    })
    makeUI(animDropBtnFrame, "UICorner", {CornerRadius = UDim.new(0, 6)})
    makeUI(animDropBtnFrame, "UIStroke", {Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.4})
    local animSelectedLabel = makeUI(animDropBtnFrame, "TextLabel", {
        Text = "Select Animation...", Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 10,
        BackgroundTransparency = 1, Size = UDim2.new(0.8, 0, 1, 0),
        Position = UDim2.new(0.04, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    })
    local animArrow = makeUI(animDropBtnFrame, "TextLabel", {
        Text = "▼", Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 10,
        BackgroundTransparency = 1, Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -22, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Center
    })
    local animDropBtn = makeUI(animDropBtnFrame, "TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        AutoButtonColor = false, Text = ""
    })
    local animApplyBtn = makeUI(animDropContainer, "TextButton", {
        Size = UDim2.new(0, 56, 0, 26),
        Position = UDim2.new(1, -62, 0, 28),
        BackgroundColor3 = Color3.fromRGB(80, 80, 80),
        Text = "Apply", TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold, TextSize = 10,
        BorderSizePixel = 0
    })
    makeUI(animApplyBtn, "UICorner", {CornerRadius = UDim.new(0, 6)})

    local animOuterFrame = makeUI(animDropContainer, "Frame", {
        Size = UDim2.new(1, -12, 0, 0),
        Position = UDim2.new(0, 6, 1, 4),
        BackgroundColor3 = Color3.fromRGB(32, 32, 32),
        BorderSizePixel = 0,
        Visible = false, ZIndex = 20,
        ClipsDescendants = true
    })
    makeUI(animOuterFrame, "UICorner", {CornerRadius = UDim.new(0, 6)})
    makeUI(animOuterFrame, "UIStroke", {Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.5})

    local animSearchBoxH = 28
    local animSearchBox = makeUI(animOuterFrame, "TextBox", {
        Size = UDim2.new(1, -8, 0, animSearchBoxH),
        Position = UDim2.new(0, 4, 0, 4),
        BackgroundColor3 = Color3.fromRGB(55, 55, 55),
        PlaceholderText = "Search animation...",
        PlaceholderColor3 = Color3.fromRGB(130, 130, 130),
        Text = "",
        TextColor3 = Color3.fromRGB(220, 220, 220),
        Font = Enum.Font.Gotham, TextSize = 10,
        BorderSizePixel = 0,
        ZIndex = 22,
        ClearTextOnFocus = false,
        TextEditable = false,
    })
    makeUI(animSearchBox, "UICorner", {CornerRadius = UDim.new(0, 6)})
    makeUI(animSearchBox, "UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 6)})

    local animOptionsList = makeUI(animOuterFrame, "ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, -(animSearchBoxH + 8)),
        Position = UDim2.new(0, 0, 0, animSearchBoxH + 8),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100),
        ZIndex = 20,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true
    })
    local animOptionsLayout = makeUI(animOptionsList, "UIListLayout", {
        Padding = UDim.new(0, 2),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder
    })
    animOptionsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        animOptionsList.CanvasSize = UDim2.new(0, 0, 0, animOptionsLayout.AbsoluteContentSize.Y + 4)
    end)

    local animEmptyLabel = makeUI(animOptionsList, "TextLabel", {
        Size = UDim2.new(0.96, 0, 0, 26),
        BackgroundTransparency = 1,
        Text = "No results",
        TextColor3 = Color3.fromRGB(130, 130, 130),
        Font = Enum.Font.Gotham, TextSize = 10,
        BorderSizePixel = 0, ZIndex = 21,
        Visible = false,
        LayoutOrder = 0
    })

    local animDropOpen = false
    local animOptButtons = {}
    for i, preset in ipairs(ANIM_PRESETS) do
        local optBtn = makeUI(animOptionsList, "TextButton", {
            Size = UDim2.new(0.96, 0, 0, 26),
            BackgroundColor3 = Color3.fromRGB(45, 45, 45),
            Text = preset.name,
            TextColor3 = Color3.fromRGB(200, 200, 200),
            Font = Enum.Font.Gotham, TextSize = 10,
            BorderSizePixel = 0,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
            ZIndex = 21,
            LayoutOrder = i
        })
        makeUI(optBtn, "UICorner", {CornerRadius = UDim.new(0, 4)})
        makeUI(optBtn, "UIPadding", {PaddingLeft = UDim.new(0, 8)})
        optBtn.MouseEnter:Connect(function()
            TweenService:Create(optBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(62, 62, 62)}):Play()
        end)
        optBtn.MouseLeave:Connect(function()
            TweenService:Create(optBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(45, 45, 45)}):Play()
        end)
        local cap = preset
        optBtn.MouseButton1Click:Connect(function()
            animSelectedPreset = cap
            AC_ANIM_PRESET_APPLIED = cap
            animSelectedLabel.Text = cap.name
            animSelectedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            animDropOpen = false
            animSearchBox.Text = ""
            animSearchBox.TextEditable = false
            for _, entry in ipairs(animOptButtons) do entry.button.Visible = true end
            animEmptyLabel.Visible = false
            TweenService:Create(animOuterFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(1, -12, 0, 0)}):Play()
            TweenService:Create(animArrow, TweenInfo.new(0.2), {Rotation = 0}):Play()
            task.delay(0.21, function()
                animOuterFrame.Visible = false
                animOuterFrame.Size = UDim2.new(1, -12, 0, 0)
            end)
        end)
        table.insert(animOptButtons, {button = optBtn, preset = preset})
    end

    local animItemH = 26
    local animItemPad = 2
    local animMaxVisible = 5
    local function applyAnimSearch(query)
        local q = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
        local visibleCount = 0
        for _, entry in ipairs(animOptButtons) do
            local matches = q == "" or entry.preset.name:lower():find(q, 1, true)
            entry.button.Visible = matches and true or false
            if matches then visibleCount = visibleCount + 1 end
        end
        animEmptyLabel.Visible = (visibleCount == 0)
        local count = math.min(visibleCount, animMaxVisible)
        local extraH = (visibleCount == 0) and animItemH or 0
        local newH = animSearchBoxH + 8 + 4 + count * animItemH + (math.max(count - 1, 0)) * animItemPad + extraH + 8
        TweenService:Create(animOuterFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            Size = UDim2.new(1, -12, 0, newH)
        }):Play()
    end
    animSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        applyAnimSearch(animSearchBox.Text)
    end)

    local function getAnimListHeight()
        local count = math.min(#ANIM_PRESETS, animMaxVisible)
        return animSearchBoxH + 8 + 4 + count * animItemH + (count - 1) * animItemPad + 8
    end
    animDropBtn.MouseButton1Click:Connect(function()
        animDropOpen = not animDropOpen
        if animDropOpen then
            animOuterFrame.Size = UDim2.new(1, -12, 0, 0)
            animOuterFrame.Visible = true
            animSearchBox.TextEditable = true
            TweenService:Create(animOuterFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(1, -12, 0, getAnimListHeight())}):Play()
            TweenService:Create(animArrow, TweenInfo.new(0.2), {Rotation = 180}):Play()
        else
            animSearchBox.Text = ""
            animSearchBox.TextEditable = false
            for _, entry in ipairs(animOptButtons) do entry.button.Visible = true end
            animEmptyLabel.Visible = false
            TweenService:Create(animOuterFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = UDim2.new(1, -12, 0, 0)}):Play()
            TweenService:Create(animArrow, TweenInfo.new(0.18), {Rotation = 0}):Play()
            task.delay(0.19, function()
                animOuterFrame.Visible = false
                animOuterFrame.Size = UDim2.new(1, -12, 0, 0)
            end)
        end
    end)

    animApplyBtn.MouseButton1Click:Connect(function()
        if not animSelectedPreset then
            animStatusLabel.Text = "Status: Select animation first!"
            animStatusLabel.TextColor3 = Color3.fromRGB(195, 165, 50)
            return
        end
        if not animChangerEnabled then
            animChangerEnabled = true
            TweenService:Create(animToggleTrack, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(50, 180, 50)}):Play()
            TweenService:Create(animKnob, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = UDim2.new(1, -22, 0.5, 0)}):Play()
            TweenService:Create(animKnobGlow, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(50, 220, 50), ImageTransparency = 0.6}):Play()
        end
        fetchAndApplyBundle(animSelectedPreset, function(text, color)
            animStatusLabel.Text = text
            animStatusLabel.TextColor3 = color
        end)
    end)

    makeUI(optionsFrame5, "Frame", {
        Size = UDim2.new(0.9, 0, 0, 1), BackgroundColor3 = Color3.fromRGB(60, 60, 60),
        BackgroundTransparency = 0, BorderSizePixel = 0
    })

    local customHdr = makeUI(optionsFrame5, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 20), BackgroundTransparency = 1, BorderSizePixel = 0
    })
    makeUI(customHdr, "TextLabel", {
        Text = "Custom Animation",
        Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 11,
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center
    })

    local SLOT_TO_PRESET_KEY = {
        Run = "run", Walk = "walk", Fall = "fall", Jump = "jump",
        Idle = "idle1", Swim = "swim", Climb = "climb"
    }
    local function getIdFromPresetName(presetName, slot)
        local nameLower = presetName:lower():gsub("%s+", "")
        local key = SLOT_TO_PRESET_KEY[slot]
        if not key then return nil end
        for _, p in ipairs(ANIM_PRESETS) do
            if p.name:lower():gsub("%s+", "") == nameLower then
                return p[key]
            end
        end
        return nil
    end

    local presetNames = {}
    for _, p in ipairs(ANIM_PRESETS) do table.insert(presetNames, p.name) end
    local hintNames = table.concat(presetNames, ", ")

    local hintFrame = makeUI(optionsFrame5, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 28), BackgroundTransparency = 1, BorderSizePixel = 0
    })
    local hintLabel = makeUI(hintFrame, "TextLabel", {
        Text = "Names: " .. hintNames,
        Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(100, 100, 100), TextSize = 9,
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true
    })

    local ANIM_SLOTS = {"Run", "Walk", "Fall", "Jump", "Idle", "Swim", "Climb"}
    local customBoxes = {}
    for _, slotName in ipairs(ANIM_SLOTS) do
        local rowFrame = makeUI(optionsFrame5, "Frame", {
            Size = UDim2.new(0.95, 0, 0, 34),
            BackgroundColor3 = Color3.fromRGB(35, 35, 35), BackgroundTransparency = 0.15, BorderSizePixel = 0
        })
        makeUI(rowFrame, "UICorner", {CornerRadius = UDim.new(0, 7)})
        makeUI(rowFrame, "UIStroke", {Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.5})
        makeUI(rowFrame, "TextLabel", {
            Text = slotName, Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(210, 210, 210), TextSize = 11,
            BackgroundTransparency = 1, Size = UDim2.new(0.28, 0, 1, 0),
            Position = UDim2.new(0.02, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Left
        })
        local customBox = makeUI(rowFrame, "TextBox", {
            Size = UDim2.new(0.49, 0, 0.62, 0), Position = UDim2.new(0.30, 0, 0.19, 0),
            BackgroundColor3 = Color3.fromRGB(22, 22, 22), BackgroundTransparency = 0.1,
            TextColor3 = Color3.fromRGB(200, 200, 200), PlaceholderText = "Name (e.g.: Cowboy)",
            PlaceholderColor3 = Color3.fromRGB(85, 85, 85), Font = Enum.Font.Gotham, TextSize = 10,
            ClearTextOnFocus = false, BorderSizePixel = 0, Text = "", TextWrapped = false
        })
        makeUI(customBox, "UICorner", {CornerRadius = UDim.new(0, 5)})
        customBox.Focused:Connect(function() TweenService:Create(customBox, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play() end)
        customBox.FocusLost:Connect(function() TweenService:Create(customBox, TweenInfo.new(0.12), {BackgroundTransparency = 0.1}):Play() end)
        customBox.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch then customBox:CaptureFocus() end end)

        local setBtn = makeUI(rowFrame, "TextButton", {
            Size = UDim2.new(0.17, 0, 0.62, 0), Position = UDim2.new(0.81, 0, 0.19, 0),
            BackgroundColor3 = Color3.fromRGB(40, 110, 45), TextColor3 = Color3.fromRGB(255, 255, 255),
            Font = Enum.Font.GothamBold, TextSize = 11, Text = "Set", BorderSizePixel = 0, Active = true
        })
        makeUI(setBtn, "UICorner", {CornerRadius = UDim.new(0, 5)})

        local capSlot = slotName; local capBox = customBox
        setBtn.MouseButton1Click:Connect(function()
            TweenService:Create(setBtn, TweenInfo.new(0.07), {BackgroundColor3 = Color3.fromRGB(70, 180, 70)}):Play()
            task.wait(0.15)
            TweenService:Create(setBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(40, 110, 45)}):Play()

            local inputName = capBox.Text:match("^%s*(.-)%s*$")
            if inputName == "" then
                animStatusLabel.Text = "Status: Type animation name!"
                animStatusLabel.TextColor3 = Color3.fromRGB(195, 165, 50)
                return
            end

            local animId = getIdFromPresetName(inputName, capSlot)
            if not animId or animId == 0 then
                animStatusLabel.Text = "Status: '" .. inputName .. "' not found!"
                animStatusLabel.TextColor3 = Color3.fromRGB(200, 60, 60)
                return
            end

            animCustomIds[capSlot] = tostring(animId)
            for _, p in ipairs(ANIM_PRESETS) do
                if p.name:lower():gsub("%s+","") == inputName:lower():gsub("%s+","") then
                    capBox.Text = p.name
                    break
                end
            end

            if animChangerEnabled then
                applyCustomSingleSlot(capSlot, tostring(animId), function(text, color)
                    animStatusLabel.Text = text
                    animStatusLabel.TextColor3 = color
                end)
            else
                animStatusLabel.Text = "Status: " .. capSlot .. " = " .. inputName .. " ✓"
                animStatusLabel.TextColor3 = Color3.fromRGB(55, 175, 55)
            end
        end)
        customBoxes[slotName] = customBox
    end

    makeUI(optionsFrame5, "Frame", {
        Size = UDim2.new(0.9, 0, 0, 1), BackgroundColor3 = Color3.fromRGB(60, 60, 60),
        BackgroundTransparency = 0, BorderSizePixel = 0
    })

    local animStatusFrame = makeUI(optionsFrame5, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 18),
        BackgroundTransparency = 1, BorderSizePixel = 0
    })
    animStatusLabel = makeUI(animStatusFrame, "TextLabel", {
        Text = "Status: Disabled",
        Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(145, 145, 145), TextSize = 10,
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center
    })

    local animPresetHdr = makeUI(optionsFrame5, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 20), BackgroundTransparency = 1, BorderSizePixel = 0
    })
    makeUI(animPresetHdr, "TextLabel", {
        Text = "Save Preset",
        Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 11,
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center
    })

    local ap_saveRow = makeUI(optionsFrame5, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 34),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40), BackgroundTransparency = 0.2, BorderSizePixel = 0
    })
    makeUI(ap_saveRow, "UICorner", {CornerRadius = UDim.new(0, 8)})
    makeUI(ap_saveRow, "UIStroke", {Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.4})

    local ap_presetNameBox = makeUI(ap_saveRow, "TextBox", {
        Size = UDim2.new(0.68, 0, 0.65, 0), Position = UDim2.new(0.02, 0, 0.175, 0),
        BackgroundColor3 = Color3.fromRGB(30, 30, 30), BackgroundTransparency = 0.1,
        TextColor3 = Color3.fromRGB(220, 220, 220),
        PlaceholderText = "Preset name...",
        PlaceholderColor3 = Color3.fromRGB(100, 100, 100),
        Font = Enum.Font.Gotham, TextSize = 11,
        ClearTextOnFocus = false, BorderSizePixel = 0, Text = ""
    })
    makeUI(ap_presetNameBox, "UICorner", {CornerRadius = UDim.new(0, 5)})
    ap_presetNameBox.Focused:Connect(function()
        TweenService:Create(ap_presetNameBox, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play()
    end)
    ap_presetNameBox.FocusLost:Connect(function()
        TweenService:Create(ap_presetNameBox, TweenInfo.new(0.12), {BackgroundTransparency = 0.1}):Play()
    end)
    ap_presetNameBox.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then ap_presetNameBox:CaptureFocus() end
    end)

    local ap_saveBtnF = makeUI(ap_saveRow, "Frame", {
        Size = UDim2.new(0.27, 0, 0.65, 0), Position = UDim2.new(0.71, 0, 0.175, 0),
        BackgroundColor3 = Color3.fromRGB(60, 60, 60), BorderSizePixel = 0
    })
    makeUI(ap_saveBtnF, "UICorner", {CornerRadius = UDim.new(0, 5)})
    local ap_saveBtn = makeUI(ap_saveBtnF, "TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
        Text = "Save", Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 11
    })

    local ap_dropOpen = false
    local ap_selectedIdx = nil
    local ap_dropArrow, ap_selectedLabel

    local ap_dropBtnFrame = makeUI(optionsFrame5, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 34),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40), BackgroundTransparency = 0.2, BorderSizePixel = 0
    })
    makeUI(ap_dropBtnFrame, "UICorner", {CornerRadius = UDim.new(0, 8)})
    makeUI(ap_dropBtnFrame, "UIStroke", {Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.4})

    ap_selectedLabel = makeUI(ap_dropBtnFrame, "TextLabel", {
        Text = "Select preset...", Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 11,
        BackgroundTransparency = 1, Size = UDim2.new(0.8, 0, 1, 0),
        Position = UDim2.new(0.04, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    })
    ap_dropArrow = makeUI(ap_dropBtnFrame, "TextLabel", {
        Text = "▼", Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 10,
        BackgroundTransparency = 1, Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -22, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Center
    })
    local ap_dropClickBtn = makeUI(ap_dropBtnFrame, "TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        AutoButtonColor = false, Text = ""
    })

    local ap_dropListOuter = makeUI(optionsFrame5, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(35, 35, 35), BackgroundTransparency = 0,
        BorderSizePixel = 0, Visible = false, ClipsDescendants = true
    })
    makeUI(ap_dropListOuter, "UICorner", {CornerRadius = UDim.new(0, 7)})
    makeUI(ap_dropListOuter, "UIStroke", {Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.3})
    local ap_dropList = makeUI(ap_dropListOuter, "ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true
    })
    local ap_dropListLayout = makeUI(ap_dropList, "UIListLayout", {
        Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center
    })
    makeUI(ap_dropList, "UIPadding", {PaddingTop = UDim.new(0,4), PaddingBottom = UDim.new(0,4)})
    ap_dropListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        ap_dropList.CanvasSize = UDim2.new(0, 0, 0, ap_dropListLayout.AbsoluteContentSize.Y + 8)
    end)

    local ap_actionRow = makeUI(optionsFrame5, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 34),
        BackgroundTransparency = 1, BorderSizePixel = 0
    })
    makeUI(ap_actionRow, "UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6)
    })

    local function ap_makeActionBtn(parent, txt, bgColor, textColor)
        local f = makeUI(parent, "Frame", {
            Size = UDim2.new(0.46, 0, 0, 32),
            BackgroundColor3 = bgColor, BackgroundTransparency = 0.15, BorderSizePixel = 0
        })
        makeUI(f, "UICorner", {CornerRadius = UDim.new(0, 7)})
        local b = makeUI(f, "TextButton", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
            Text = txt, Font = Enum.Font.GothamBold, TextColor3 = textColor, TextSize = 12
        })
        return b, f
    end

    local ap_loadBtn,   ap_loadBtnF   = ap_makeActionBtn(ap_actionRow, "Load",  Color3.fromRGB(40,40,40), Color3.fromRGB(255,255,255))
    local ap_deleteBtn, ap_deleteBtnF = ap_makeActionBtn(ap_actionRow, "Delete", Color3.fromRGB(40,40,40), Color3.fromRGB(255,255,255))

    local AP_PRESETS = {}
    local AP_PRESET_FILE = "Zero Directory/anim_presets.json"

    local function ap_canFileIO()
        return type(writefile)=="function" and type(readfile)=="function"
            and type(isfile)=="function" and type(isfolder)=="function"
    end
    local function ap_savePresets()
        if not ap_canFileIO() then return end
        pcall(function()
            if not isfolder("Zero Directory") then makefolder("Zero Directory") end
            writefile(AP_PRESET_FILE, HttpService:JSONEncode(AP_PRESETS))
        end)
    end
    local function ap_loadPresetsFromFile()
        if not ap_canFileIO() then return end
        pcall(function()
            if not isfolder("Zero Directory") then makefolder("Zero Directory") end
            if isfile(AP_PRESET_FILE) then
                local ok, decoded = pcall(function()
                    return HttpService:JSONDecode(readfile(AP_PRESET_FILE))
                end)
                if ok and decoded then AP_PRESETS = decoded end
            end
        end)
    end

    local function ap_collectCurrentCustom()
        local data = {}
        for slot, id in pairs(animCustomIds) do
            if id and id ~= "" then data[slot] = id end
        end
        return data
    end

    local function ap_applyPreset(preset)
        if not preset or not preset.anims then return end
        for slot, id in pairs(preset.anims) do
            animCustomIds[slot] = tostring(id)
            if customBoxes[slot] then
                local idNum = tonumber(id)
                local foundName = tostring(id)
                for _, p in ipairs(ANIM_PRESETS) do
                    local SLOT_TO_PRESET_KEY2 = {Run="run",Walk="walk",Fall="fall",Jump="jump",Idle="idle1",Swim="swim",Climb="climb"}
                    local key = SLOT_TO_PRESET_KEY2[slot]
                    if key and p[key] == idNum then foundName = p.name; break end
                end
                customBoxes[slot].Text = foundName
            end
        end
        if animChangerEnabled then
            applyAllCustomIds(function(text, color)
                animStatusLabel.Text = text
                animStatusLabel.TextColor3 = color
            end)
        else
            animStatusLabel.Text = "Status: Preset '" .. (preset.name or "?") .. "' loaded!"
            animStatusLabel.TextColor3 = Color3.fromRGB(55, 175, 55)
        end
    end

    local function ap_rebuildDropdown()
        for _, v in ipairs(ap_dropList:GetChildren()) do
            if not v:IsA("UIListLayout") and not v:IsA("UIPadding") then v:Destroy() end
        end
        if #AP_PRESETS == 0 then
            makeUI(ap_dropList, "TextLabel", {
                Text = "No presets yet",
                Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(120,120,120), TextSize = 11,
                BackgroundTransparency = 1, Size = UDim2.new(1,-8,0,26),
                TextXAlignment = Enum.TextXAlignment.Center
            })
            ap_dropListOuter.Size = UDim2.new(0.95, 0, 0, 34)
            return
        end
        for i, preset in ipairs(AP_PRESETS) do
            local itemF = makeUI(ap_dropList, "Frame", {
                Size = UDim2.new(1,-8,0,28),
                BackgroundColor3 = Color3.fromRGB(50,50,50), BackgroundTransparency = 0.3, BorderSizePixel = 0
            })
            makeUI(itemF, "UICorner", {CornerRadius = UDim.new(0,5)})
            local count = 0
            for _ in pairs(preset.anims or {}) do count = count + 1 end
            local itemBtn = makeUI(itemF, "TextButton", {
                Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
                Text = "  " .. preset.name,
                Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(220,220,220), TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd
            })
            makeUI(itemF, "TextLabel", {
                Text = count .. " slot", Font = Enum.Font.Gotham,
                TextColor3 = Color3.fromRGB(150,150,150), TextSize = 10,
                BackgroundTransparency = 1, Size = UDim2.new(0.25,0,1,0),
                Position = UDim2.new(0.75,0,0,0), TextXAlignment = Enum.TextXAlignment.Center
            })
            local capturedI = i
            itemBtn.MouseButton1Click:Connect(function()
                ap_selectedIdx = capturedI
                ap_selectedLabel.Text = AP_PRESETS[capturedI].name
                ap_selectedLabel.TextColor3 = Color3.fromRGB(255,255,255)
                ap_dropOpen = false
                ap_dropArrow.Text = "▼"
                TweenService:Create(ap_dropListOuter, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {Size = UDim2.new(0.95,0,0,0)}):Play()
                task.delay(0.16, function() ap_dropListOuter.Visible = false end)
            end)
        end
        local totalH = math.min(ap_dropListLayout.AbsoluteContentSize.Y + 10, 150)
        ap_dropListOuter.Size = UDim2.new(0.95, 0, 0, totalH)
    end

    ap_dropClickBtn.MouseButton1Click:Connect(function()
        ap_dropOpen = not ap_dropOpen
        ap_rebuildDropdown()
        if ap_dropOpen then
            ap_dropArrow.Text = "▲"
            ap_dropListOuter.Visible = true
            task.wait()
            local totalH = math.min(ap_dropListLayout.AbsoluteContentSize.Y + 10, 150)
            ap_dropListOuter.Size = UDim2.new(0.95,0,0,0)
            TweenService:Create(ap_dropListOuter, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Size = UDim2.new(0.95,0,0,totalH)}):Play()
        else
            ap_dropArrow.Text = "▼"
            TweenService:Create(ap_dropListOuter, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Size = UDim2.new(0.95,0,0,0)}):Play()
            task.delay(0.16, function() ap_dropListOuter.Visible = false end)
        end
    end)

    ap_saveBtn.MouseButton1Click:Connect(function()
        TweenService:Create(ap_saveBtnF, TweenInfo.new(0.07), {BackgroundTransparency = 0}):Play()
        task.wait(0.12)
        TweenService:Create(ap_saveBtnF, TweenInfo.new(0.1), {BackgroundTransparency = 0.1}):Play()
        local name = ap_presetNameBox.Text:match("^%s*(.-)%s*$")
        if name == "" then
            animStatusLabel.Text = "Status: Enter preset name!"
            animStatusLabel.TextColor3 = Color3.fromRGB(195,165,50)
            return
        end
        local anims = ap_collectCurrentCustom()
        if next(anims) == nil then
            animStatusLabel.Text = "Status: Set at least 1 slot first!"
            animStatusLabel.TextColor3 = Color3.fromRGB(195,165,50)
            return
        end
        for i, p in ipairs(AP_PRESETS) do
            if p.name:lower() == name:lower() then
                AP_PRESETS[i].anims = anims
                ap_savePresets(); ap_rebuildDropdown()
                animStatusLabel.Text = "Status: Preset '" .. name .. "' updated!"
                animStatusLabel.TextColor3 = Color3.fromRGB(55,175,55)
                ap_presetNameBox.Text = ""
                return
            end
        end
        table.insert(AP_PRESETS, {name = name, anims = anims})
        ap_savePresets(); ap_rebuildDropdown()
        animStatusLabel.Text = "Status: Preset '" .. name .. "' saved!"
        animStatusLabel.TextColor3 = Color3.fromRGB(55,175,55)
        ap_presetNameBox.Text = ""
    end)

    ap_loadBtn.MouseButton1Click:Connect(function()
        TweenService:Create(ap_loadBtnF, TweenInfo.new(0.07), {BackgroundTransparency = 0}):Play()
        task.wait(0.12)
        TweenService:Create(ap_loadBtnF, TweenInfo.new(0.1), {BackgroundTransparency = 0.15}):Play()
        if not ap_selectedIdx or not AP_PRESETS[ap_selectedIdx] then
            animStatusLabel.Text = "Status: Select a preset first!"
            animStatusLabel.TextColor3 = Color3.fromRGB(195,165,50)
            return
        end
        ap_applyPreset(AP_PRESETS[ap_selectedIdx])
    end)

    ap_deleteBtn.MouseButton1Click:Connect(function()
        TweenService:Create(ap_deleteBtnF, TweenInfo.new(0.07), {BackgroundTransparency = 0}):Play()
        task.wait(0.12)
        TweenService:Create(ap_deleteBtnF, TweenInfo.new(0.1), {BackgroundTransparency = 0.15}):Play()
        if not ap_selectedIdx or not AP_PRESETS[ap_selectedIdx] then
            animStatusLabel.Text = "Status: Select a preset first!"
            animStatusLabel.TextColor3 = Color3.fromRGB(195,165,50)
            return
        end
        local removedName = AP_PRESETS[ap_selectedIdx].name
        table.remove(AP_PRESETS, ap_selectedIdx)
        ap_selectedIdx = nil
        ap_selectedLabel.Text = "Select preset..."
        ap_selectedLabel.TextColor3 = Color3.fromRGB(200,200,200)
        ap_savePresets(); ap_rebuildDropdown()
        animStatusLabel.Text = "Status: Preset '" .. removedName .. "' deleted"
        animStatusLabel.TextColor3 = Color3.fromRGB(145,145,145)
    end)

    ap_loadPresetsFromFile()
    ap_rebuildDropdown()

    makeUI(optionsFrame5, "Frame", {
        Size = UDim2.new(0.9, 0, 0, 1), BackgroundColor3 = Color3.fromRGB(60, 60, 60),
        BackgroundTransparency = 0, BorderSizePixel = 0
    })

    local ap_randomFrame = makeUI(optionsFrame5, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 35),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40), BackgroundTransparency = 0.2, BorderSizePixel = 0
    })
    makeUI(ap_randomFrame, "UICorner", {CornerRadius = UDim.new(0, 8)})
    local ap_randomBtn = makeUI(ap_randomFrame, "TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
        Text = "Random Preset",
        TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 13, Font = Enum.Font.GothamBold
    })
    ap_randomBtn.MouseButton1Click:Connect(function()
        TweenService:Create(ap_randomFrame, TweenInfo.new(0.07), {BackgroundTransparency = 0}):Play()
        task.wait(0.12)
        TweenService:Create(ap_randomFrame, TweenInfo.new(0.1), {BackgroundTransparency = 0.2}):Play()

        local RANDOM_SLOTS = {"Run","Walk","Fall","Jump","Idle","Swim","Climb"}
        local SLOT_KEY = {Run="run",Walk="walk",Fall="fall",Jump="jump",Idle="idle1",Swim="swim",Climb="climb"}

        local validPresets = {}
        for _, p in ipairs(ANIM_PRESETS) do
            if p.name ~= "None (Reset)" then
                table.insert(validPresets, p)
            end
        end

        if #validPresets == 0 then return end

        local char = LocalPlayer.Character
        if not char then
            animStatusLabel.Text = "Status: No character!"
            animStatusLabel.TextColor3 = Color3.fromRGB(200,60,60)
            return
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local Animate = char:FindFirstChild("Animate")
        if not hum or not Animate then return end

        az_freeze(hum, char)
        task.wait(0.1)
        az_stopAllTracks(hum)

        local needRefresh      = false
        local needRefreshSwim  = false
        local needRefreshClimb = false

        for _, slotName in ipairs(RANDOM_SLOTS) do
            local key = SLOT_KEY[slotName]
            local candidates = {}
            for _, p in ipairs(validPresets) do
                if p[key] and p[key] ~= 0 then
                    table.insert(candidates, p)
                end
            end
            if #candidates > 0 then
                local chosen = candidates[math.random(1, #candidates)]
                local id = chosen[key]
                local url = "rbxassetid://" .. tostring(id)
                pcall(function()
                    if slotName == "Run" then
                        Animate.run.RunAnim.AnimationId = url; needRefresh = true
                    elseif slotName == "Walk" then
                        Animate.walk.WalkAnim.AnimationId = url; needRefresh = true
                    elseif slotName == "Fall" then
                        Animate.fall.FallAnim.AnimationId = url; needRefresh = true
                    elseif slotName == "Jump" then
                        Animate.jump.JumpAnim.AnimationId = url; needRefresh = true
                    elseif slotName == "Idle" then
                        Animate.idle.Animation1.AnimationId = url; needRefresh = true
                    elseif slotName == "Swim" then
                        Animate.swim.Swim.AnimationId = url; needRefreshSwim = true
                    elseif slotName == "Climb" then
                        Animate.climb.ClimbAnim.AnimationId = url; needRefreshClimb = true
                    end
                end)
                animCustomIds[slotName] = tostring(id)
                if customBoxes[slotName] then
                    customBoxes[slotName].Text = chosen.name
                end
            end
        end

        if needRefresh      then az_refresh(hum) end
        if needRefreshSwim  then az_refreshSwim(hum) end
        if needRefreshClimb then az_refreshClimb(hum) end

        task.wait(0.1)
        az_unfreeze(hum, char)

        animStatusLabel.Text = "Status: Random applied!"
        animStatusLabel.TextColor3 = Color3.fromRGB(55, 175, 55)
    end)

    animToggleBtn.MouseButton1Click:Connect(function()
        animChangerEnabled = not animChangerEnabled
        if animChangerEnabled then
            TweenService:Create(animToggleTrack, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(50, 180, 50)}):Play()
            TweenService:Create(animKnob, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = UDim2.new(1, -22, 0.5, 0)}):Play()
            TweenService:Create(animKnobGlow, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(50, 220, 50), ImageTransparency = 0.6}):Play()
            animStatusLabel.Text = "Status: Enabled"
            animStatusLabel.TextColor3 = Color3.fromRGB(55, 175, 55)
            if animSelectedPreset then
                fetchAndApplyBundle(animSelectedPreset, function(text, color)
                    animStatusLabel.Text = text
                    animStatusLabel.TextColor3 = color
                end)
            end
        else
            TweenService:Create(animToggleTrack, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(70, 70, 70)}):Play()
            TweenService:Create(animKnob, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = UDim2.new(0, 2, 0.5, 0)}):Play()
            TweenService:Create(animKnobGlow, TweenInfo.new(0.2), {ImageColor3 = Color3.fromRGB(255, 255, 255), ImageTransparency = 0.85}):Play()
            animStatusLabel.Text = "Status: Disabled"
            animStatusLabel.TextColor3 = Color3.fromRGB(145, 145, 145)
            disableAnimationChanger()
        end
    end)
end

local function jsonEncodeString(s)
    return '"' .. s:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t') .. '"'
end
local function jsonEncodeSongs(tbl)
    local items = {}
    for _, song in ipairs(tbl) do
        local entry = string.format('{"Name":%s,"Id":%s,"Icon":%s}',
            jsonEncodeString(song.Name), jsonEncodeString(song.Id), jsonEncodeString(song.Icon))
        table.insert(items, entry)
    end
    return "[" .. table.concat(items, ",") .. "]"
end
local function jsonDecodeSongs(str)
    local result = {}
    local pos = 1
    while pos <= #str do
        local objStart = str:find("{", pos, true)
        if not objStart then break end
        local objEnd = str:find("}", objStart, true)
        if not objEnd then break end
        local obj = str:sub(objStart, objEnd)
        local entry = {}
        for key in obj:gmatch('"(%w+)"%s*:') do
            local _, valQ = obj:find('"' .. key .. '"%s*:%s*"', 1)
            if valQ then
                local val = {}
                local i = valQ + 1
                while i <= #obj do
                    local c = obj:sub(i, i)
                    if c == '"' then break end
                    if c == '\\' then
                        i = i + 1
                        local esc = obj:sub(i, i)
                        local map = {['"']='"',['\\']='\\',['n']='\n',['r']='\r',['t']='\t'}
                        table.insert(val, map[esc] or esc)
                    else
                        table.insert(val, c)
                    end
                    i = i + 1
                end
                entry[key] = table.concat(val)
            end
        end
        if entry.Name and entry.Id and entry.Icon then table.insert(result, entry) end
        pos = objEnd + 1
    end
    return result
end

local MP_SAVE_FILE = "Zero Directory/Music_Player.json"
local function mp_canFileIO()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end
local function mp_saveCustomSongs(songsTable, defaultCount)
    if not mp_canFileIO() then return end
    local custom = {}
    for i = defaultCount + 1, #songsTable do table.insert(custom, songsTable[i]) end
    if not isfolder("Zero Directory") then makefolder("Zero Directory") end
    pcall(writefile, MP_SAVE_FILE, jsonEncodeSongs(custom))
end
local function mp_loadCustomSongs()
    if not mp_canFileIO() then return {} end
    local existOk, exists = pcall(isfile, MP_SAVE_FILE)
    if not existOk or not exists then return {} end
    local ok, content = pcall(readfile, MP_SAVE_FILE)
    if not ok or not content or content == "" then return {} end
    local ok2, decoded = pcall(jsonDecodeSongs, content)
    return ok2 and decoded or {}
end

local MP_MUSIC_FOLDER     = "Zero Music"
local MP_ICON_SONG_FOLDER = "rbxthumb://type=Asset&id=13780950281&w=150&h=150"

-- Supported audio extensions with magic-byte signatures for validation
local MP_AUDIO_EXTS = {
    ogg = { magic = "OggS" },
    mp3 = { magic = "\255\251", alt = "ID3" },
}

local function mp_canFolderIO()
    return mp_canFileIO()
        and type(isfolder)   == "function"
        and type(makefolder) == "function"
        and type(listfiles)  == "function"
end

local function mp_ensureMusicFolder()
    if not mp_canFolderIO() then return false end
    local ok, exists = pcall(isfolder, MP_MUSIC_FOLDER)
    if not ok or not exists then
        pcall(makefolder, MP_MUSIC_FOLDER)
    end
    return true
end

-- Resolves a local file path to a rbxasset:// URI via GetCustomAsset (preferred),
-- with fallbacks to getsynasset / getasset for older executors.
-- Supports both MP3 and OGG formats.
local function mp_resolveLocalAudio(path)
    if type(getcustomasset) == "function" then
        local ok, res = pcall(getcustomasset, path)
        if ok and res and res ~= "" then return res end
    end
    if type(getsynasset) == "function" then
        local ok, res = pcall(getsynasset, path)
        if ok and res and res ~= "" then return res end
    end
    if type(getasset) == "function" then
        local ok, res = pcall(getasset, path)
        if ok and res and res ~= "" then return res end
    end
    return nil
end

-- Validates file magic bytes to confirm the actual audio format.
local function mp_validateAudioFile(data, ext)
    if not data or #data < 4 then return false end
    local info = MP_AUDIO_EXTS[ext]
    if not info then return false end
    local header = data:sub(1, 4)
    if header:sub(1, #info.magic) == info.magic then return true end
    if info.alt and header:sub(1, #info.alt) == info.alt then return true end
    return false
end

-- Scans the Zero Music folder for MP3 and OGG files.
-- Uses getcustomasset() to resolve local paths into Sound.SoundId-compatible URIs.
local function mp_loadFolderSongs()
    if not mp_canFolderIO() then return {} end
    mp_ensureMusicFolder()
    local okL, files = pcall(listfiles, MP_MUSIC_FOLDER)
    if not okL or type(files) ~= "table" then return {} end

    local result = {}
    for _, path in ipairs(files) do
        local filename    = path:match("[^/\\]+$") or path
        local ext         = (filename:match("%.([^%.]+)$") or ""):lower()

        if MP_AUDIO_EXTS[ext] then
            local displayName = filename:match("^(.-)%.[^%.]+$") or filename
            local okD, data   = pcall(readfile, path)
            local canPlay     = mp_validateAudioFile(data, ext)
            local resolvedId  = nil

            if canPlay then
                -- GetCustomAsset converts the local path to a usable rbxasset:// URI
                resolvedId = mp_resolveLocalAudio(path)
            end

            table.insert(result, {
                Name    = canPlay
                            and displayName
                            or  (displayName .. " (corrupt/unsupported)"),
                Id      = resolvedId or "",
                Icon    = MP_ICON_SONG_FOLDER,
                IsFile  = true,
                RawPath = path,
                CanPlay = canPlay,
                FileExt = ext,
            })
        end
    end
    return result
end


local IC = Color3.fromRGB(215, 215, 215)
local function rr(parent, x, y, w, h, col, rad, zi)
    local f = makeUI(parent, "Frame", {
        Position = UDim2.new(0, x, 0, y), Size = UDim2.new(0, w, 0, h),
        BackgroundColor3 = col, BorderSizePixel = 0, ZIndex = zi or 3
    })
    makeUI(f, "UICorner", { CornerRadius = UDim.new(0, rad or 1) })
    return f
end
local function clickLayer(parent, zi)
    return makeUI(parent, "TextButton", {
        Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "", ZIndex = zi or 20
    })
end
local function iconSkipBack(parent, S, color)
    local bsz = parent.Size.X.Offset
    local pad = math.floor((bsz - S) / 2)
    rr(parent, pad, pad, 2, S, color, 1, 3)
    local t1 = makeUI(parent, "Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, pad+4, 0, pad+S/2),
        Size = UDim2.new(0, S-5, 0, 2), BackgroundColor3 = color, BorderSizePixel = 0, Rotation = -35, ZIndex = 3
    })
    makeUI(t1, "UICorner", { CornerRadius = UDim.new(0, 1) })
    local t2 = makeUI(parent, "Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, pad+4, 0, pad+S/2),
        Size = UDim2.new(0, S-5, 0, 2), BackgroundColor3 = color, BorderSizePixel = 0, Rotation = 35, ZIndex = 3
    })
    makeUI(t2, "UICorner", { CornerRadius = UDim.new(0, 1) })
    rr(parent, pad+S-3, pad, 2, S, color, 1, 3)
end
local function iconSkipForward(parent, S, color)
    local bsz = parent.Size.X.Offset
    local pad = math.floor((bsz - S) / 2)
    rr(parent, pad+S-2, pad, 2, S, color, 1, 3)
    local t1 = makeUI(parent, "Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, pad, 0, pad+S/2),
        Size = UDim2.new(0, S-5, 0, 2), BackgroundColor3 = color, BorderSizePixel = 0, Rotation = 35, ZIndex = 3
    })
    makeUI(t1, "UICorner", { CornerRadius = UDim.new(0, 1) })
    local t2 = makeUI(parent, "Frame", {
        AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, pad, 0, pad+S/2),
        Size = UDim2.new(0, S-5, 0, 2), BackgroundColor3 = color, BorderSizePixel = 0, Rotation = -35, ZIndex = 3
    })
    makeUI(t2, "UICorner", { CornerRadius = UDim.new(0, 1) })
    rr(parent, pad, pad, 2, S, color, 1, 3)
end
local function iconPlay(parent, S, color, bsz)
    bsz = bsz or parent.Size.X.Offset
    local cx = math.floor(bsz/2) + 1
    local cy = math.floor(bsz/2)
    local half = math.floor(S/2)
    rr(parent, cx-half, cy-half, 2, S, color, 1, 3)
    local t1 = makeUI(parent, "Frame", {
        AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, cx-half, 0, cy),
        Size = UDim2.new(0, S-1, 0, 2), BackgroundColor3 = color, BorderSizePixel = 0, Rotation = -30, ZIndex = 3
    })
    makeUI(t1, "UICorner", { CornerRadius = UDim.new(0, 1) })
    local t2 = makeUI(parent, "Frame", {
        AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, cx-half, 0, cy),
        Size = UDim2.new(0, S-1, 0, 2), BackgroundColor3 = color, BorderSizePixel = 0, Rotation = 30, ZIndex = 3
    })
    makeUI(t2, "UICorner", { CornerRadius = UDim.new(0, 1) })
end
local function iconPause(parent, S, color, bsz)
    bsz = bsz or parent.Size.X.Offset
    local barW = 3
    local gap = math.floor(S * 0.38)
    local totalW = barW*2 + gap
    local startX = math.floor((bsz - totalW) / 2)
    local startY = math.floor((bsz - S) / 2)
    rr(parent, startX, startY, barW, S, color, 1, 3)
    rr(parent, startX+barW+gap, startY, barW, S, color, 1, 3)
end

function createMusicPlayerPage()
    local MP_ICON_SONG   = "rbxthumb://type=Asset&id=13780950281&w=150&h=150"
    local MP_ICON_VOL    = "rbxthumb://type=Asset&id=117386765962827&w=150&h=150"
    local MP_ICON_MUTE   = "rbxthumb://type=Asset&id=96383895319411&w=150&h=150"
    task.spawn(function()
        local ContentProvider = game:GetService("ContentProvider")
        local preloadInstances = {}
        for _, url in ipairs({ MP_ICON_SONG, MP_ICON_VOL, MP_ICON_MUTE }) do
            local img = Instance.new("ImageLabel")
            img.Image = url
            table.insert(preloadInstances, img)
        end
        pcall(function()
            ContentProvider:PreloadAsync(preloadInstances)
        end)
        for _, img in ipairs(preloadInstances) do img:Destroy() end
    end)

    local DEFAULT_SONGS = {
        { Name = "The Death Glasses",      Id = "rbxassetid://111189764768935", Icon = MP_ICON_SONG },
        { Name = "Losing You",             Id = "rbxassetid://99597515538931",  Icon = MP_ICON_SONG },
        { Name = "Last Tuesday",           Id = "rbxassetid://88204325031714",  Icon = MP_ICON_SONG },
        { Name = "Missing Love",           Id = "rbxassetid://73889409537043",  Icon = MP_ICON_SONG },
        { Name = "Forgot My Name",         Id = "rbxassetid://96944250631515",  Icon = MP_ICON_SONG },
        { Name = "I Stayed Feeling",       Id = "rbxassetid://128245292391041", Icon = MP_ICON_SONG },
        { Name = "Another Song About You", Id = "rbxassetid://124894144431579", Icon = MP_ICON_SONG },
        { Name = "Three Hearts Breaking",  Id = "rbxassetid://76618664260545",  Icon = MP_ICON_SONG },
        { Name = "輝く瞬間 ((Kagayaku Shunkan))",               Id = "rbxassetid://113287483392873", Icon = MP_ICON_SONG },
        { Name = "ビーチサイド・サマーラブ", Id = "rbxassetid://91639046717047",  Icon = MP_ICON_SONG },
    }
    local DEFAULT_COUNT = #DEFAULT_SONGS
    local songs = {}
    for _, s in ipairs(DEFAULT_SONGS) do table.insert(songs, s) end
    for _, s in ipairs(mp_loadCustomSongs()) do table.insert(songs, s) end

    local sound = Instance.new("Sound")
    sound.Name = "ZeroMusicPlayer"
    sound.Volume = 0.5
    sound.Parent = LocalPlayer.Character or LocalPlayer
    LocalPlayer.CharacterAdded:Connect(function(char) sound.Parent = char end)

    local currentSongIndex = 1
    local isPlaying = false
    local isMuted = false
    local savedVolume = 0.5

    local headerLbl = makeUI(optionsFrame6, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 22),
        BackgroundTransparency = 1, BorderSizePixel = 0
    })
    makeUI(headerLbl, "TextLabel", {
        Text = "Music Player",
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 12,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center
    })

    local VIZ_COUNT  = 12
    local VIZ_BAR_W  = 3
    local VIZ_GAP    = 2
    local VIZ_MAX_H  = 18
    local VIZ_MIN_H  = 2
    local VIZ_COL_ON  = Color3.fromRGB(210, 210, 210)
    local VIZ_COL_OFF = Color3.fromRGB(60, 60, 60)

    local songInfoFrame = makeUI(optionsFrame6, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 50),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        BackgroundTransparency = 0.2, BorderSizePixel = 0
    })
    makeUI(songInfoFrame, "UICorner", { CornerRadius = UDim.new(0, 8) })
    makeUI(songInfoFrame, "TextLabel", {
        Size = UDim2.new(1, -10, 0, 14), Position = UDim2.new(0, 8, 0, 4),
        BackgroundTransparency = 1, Text = "NOW PLAYING",
        TextColor3 = Color3.fromRGB(160, 160, 160), TextSize = 9,
        Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left
    })
    local vizTotalW = VIZ_COUNT * VIZ_BAR_W + (VIZ_COUNT - 1) * VIZ_GAP + 8
    local songNameLabel = makeUI(songInfoFrame, "TextLabel", {
        Size = UDim2.new(1, -(vizTotalW + 16), 0, 20),
        Position = UDim2.new(0, 8, 0, 24),
        BackgroundTransparency = 1, Text = "Select a song",
        TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 12,
        Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    })

    local vizFrame = makeUI(songInfoFrame, "Frame", {
        Size = UDim2.new(0, VIZ_COUNT * VIZ_BAR_W + (VIZ_COUNT - 1) * VIZ_GAP, 0, VIZ_MAX_H),
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -8, 0.5, 8),
        BackgroundTransparency = 1, ClipsDescendants = false
    })
    local vizBars = {}
    local vizTargetH = {}
    local vizPhase = 0
    for i = 1, VIZ_COUNT do
        vizTargetH[i] = VIZ_MIN_H
        local xPos = (i-1)*(VIZ_BAR_W+VIZ_GAP)
        local bar = makeUI(vizFrame, "Frame", {
            Size = UDim2.new(0, VIZ_BAR_W, 0, VIZ_MIN_H),
            Position = UDim2.new(0, xPos, 1, -VIZ_MIN_H),
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = VIZ_COL_OFF, BorderSizePixel = 0, ZIndex = 3
        })
        makeUI(bar, "UICorner", { CornerRadius = UDim.new(0, 1) })
        vizBars[i] = bar
    end
    local function updateViz(playing, vol)
        for i = 1, VIZ_COUNT do
            local targetH, targetCol
            if playing and vol > 0 then
                local wave = math.sin(vizPhase + i * 0.7) * 0.5 + 0.5
                targetH = math.max(VIZ_MIN_H, math.floor(VIZ_MIN_H + wave * (VIZ_MAX_H - VIZ_MIN_H) * vol))
                targetCol = VIZ_COL_ON
            else
                targetH = VIZ_MIN_H
                targetCol = VIZ_COL_OFF
            end
            vizTargetH[i] = targetH
            local cur = vizBars[i].Size.Y.Offset
            local new = cur + (targetH - cur) * 0.3
            vizBars[i].Size = UDim2.new(0, VIZ_BAR_W, 0, math.max(VIZ_MIN_H, new))
            vizBars[i].Position = UDim2.new(0, (i-1)*(VIZ_BAR_W+VIZ_GAP), 1, -math.max(VIZ_MIN_H, new))
            vizBars[i].BackgroundColor3 = targetCol
        end
    end

    local function formatTime(s)
        if not s or s < 0 then return "0:00" end
        return string.format("%d:%02d", math.floor(s/60), math.floor(s%60))
    end

    local progressOuter = makeUI(optionsFrame6, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 6),
        BackgroundColor3 = Color3.fromRGB(55, 55, 55), BorderSizePixel = 0, ZIndex = 2
    })
    makeUI(progressOuter, "UICorner", { CornerRadius = UDim.new(1, 0) })
    local progressBar = makeUI(progressOuter, "Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(130, 130, 130), BorderSizePixel = 0, ZIndex = 3
    })
    makeUI(progressBar, "UICorner", { CornerRadius = UDim.new(1, 0) })
    local progressThumb = makeUI(progressOuter, "Frame", {
        Size = UDim2.new(0, 10, 0, 10),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0, 0, 0.5, 0),
        BackgroundColor3 = Color3.fromRGB(220, 220, 220),
        BorderSizePixel = 0, ZIndex = 5, Visible = false
    })
    makeUI(progressThumb, "UICorner", { CornerRadius = UDim.new(1, 0) })
    local progressHit = makeUI(progressOuter, "TextButton", {
        Size = UDim2.new(1, 0, 0, 20),
        Position = UDim2.new(0, 0, 0.5, -10),
        BackgroundTransparency = 1, Text = "", ZIndex = 10
    })
    local isScrubbing = false
    local function getSeekRatio(inputPos)
        local outerPos  = progressOuter.AbsolutePosition
        local outerSize = progressOuter.AbsoluteSize
        local ratio = (inputPos.X - outerPos.X) / outerSize.X
        return math.clamp(ratio, 0, 1)
    end

    local timeRow = makeUI(optionsFrame6, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 12), BackgroundTransparency = 1, BorderSizePixel = 0
    })
    local currentTimeLabel = makeUI(timeRow, "TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0), BackgroundTransparency = 1, Text = "0:00",
        TextColor3 = Color3.fromRGB(150,150,150), TextSize = 10,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Left
    })
    local totalTimeLabel = makeUI(timeRow, "TextLabel", {
        Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.new(0.5, 0, 0, 0),
        BackgroundTransparency = 1, Text = "0:00",
        TextColor3 = Color3.fromRGB(150,150,150), TextSize = 10,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Right
    })

    local function seekTo(ratio)
        if sound.IsLoaded and sound.TimeLength and sound.TimeLength > 0 then
            sound.TimePosition = ratio * sound.TimeLength
            progressBar.Size = UDim2.new(ratio, 0, 1, 0)
            progressThumb.Position = UDim2.new(ratio, 0, 0.5, 0)
            currentTimeLabel.Text = formatTime(ratio * sound.TimeLength)
        end
    end

    progressHit.MouseEnter:Connect(function()
        progressThumb.Visible = true
        TweenService:Create(progressOuter, TweenInfo.new(0.1), { Size = UDim2.new(0.95, 0, 0, 8) }):Play()
        TweenService:Create(progressBar, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(180, 180, 180) }):Play()
    end)
    progressHit.MouseLeave:Connect(function()
        if not isScrubbing then
            progressThumb.Visible = false
            TweenService:Create(progressOuter, TweenInfo.new(0.1), { Size = UDim2.new(0.95, 0, 0, 6) }):Play()
            TweenService:Create(progressBar, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(130, 130, 130) }):Play()
        end
    end)
    progressHit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isScrubbing = true; progressThumb.Visible = true; seekTo(getSeekRatio(input.Position))
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if isScrubbing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            seekTo(getSeekRatio(input.Position))
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if isScrubbing and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
            isScrubbing = false
            seekTo(getSeekRatio(input.Position))
            progressThumb.Visible = false
            TweenService:Create(progressOuter, TweenInfo.new(0.1), { Size = UDim2.new(0.95, 0, 0, 6) }):Play()
            TweenService:Create(progressBar, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(130, 130, 130) }):Play()
        end
    end)

    local BTN_SM = 34; local BTN_LG = 44
    local ICON_SM = 14; local ICON_LG = 16
    local controlRow = makeUI(optionsFrame6, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 52), BackgroundTransparency = 1, BorderSizePixel = 0
    })
    local prevFrame = makeUI(controlRow, "Frame", {
        Size = UDim2.new(0, BTN_SM, 0, BTN_SM),
        Position = UDim2.new(0.5, -BTN_LG/2-BTN_SM-8, 0.5, -BTN_SM/2),
        BackgroundColor3 = Color3.fromRGB(48,48,48), BorderSizePixel = 0
    })
    makeUI(prevFrame, "UICorner", { CornerRadius = UDim.new(1,0) })
    makeUI(prevFrame, "UIStroke", { Color = Color3.fromRGB(80,80,80), Thickness = 1, Transparency = 0.2 })
    iconSkipBack(prevFrame, ICON_SM, IC)
    local prevClick = clickLayer(prevFrame, 20)
    local playFrame = makeUI(controlRow, "Frame", {
        Size = UDim2.new(0, BTN_LG, 0, BTN_LG),
        Position = UDim2.new(0.5, -BTN_LG/2, 0.5, -BTN_LG/2),
        BackgroundColor3 = Color3.fromRGB(55,55,55), BorderSizePixel = 0
    })
    makeUI(playFrame, "UICorner", { CornerRadius = UDim.new(1,0) })
    makeUI(playFrame, "UIStroke", { Color = Color3.fromRGB(100,100,100), Thickness = 1.2, Transparency = 0.1 })
    local playIconHolder = makeUI(playFrame, "Frame", { Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, ZIndex = 2 })
    iconPlay(playIconHolder, ICON_LG, IC, BTN_LG)
    local pauseIconHolder = makeUI(playFrame, "Frame", { Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, ZIndex = 2, Visible = false })
    iconPause(pauseIconHolder, ICON_LG, IC, BTN_LG)
    local playClick = clickLayer(playFrame, 20)
    local nextFrame = makeUI(controlRow, "Frame", {
        Size = UDim2.new(0, BTN_SM, 0, BTN_SM),
        Position = UDim2.new(0.5, BTN_LG/2+8, 0.5, -BTN_SM/2),
        BackgroundColor3 = Color3.fromRGB(48,48,48), BorderSizePixel = 0
    })
    makeUI(nextFrame, "UICorner", { CornerRadius = UDim.new(1,0) })
    makeUI(nextFrame, "UIStroke", { Color = Color3.fromRGB(80,80,80), Thickness = 1, Transparency = 0.2 })
    iconSkipForward(nextFrame, ICON_SM, IC)
    local nextClick = clickLayer(nextFrame, 20)

    local function setPlayState(playing)
        playIconHolder.Visible = not playing
        pauseIconHolder.Visible = playing
    end
    local function hoverSM(f, e)
        TweenService:Create(f, TweenInfo.new(0.12), { BackgroundColor3 = e and Color3.fromRGB(68,68,68) or Color3.fromRGB(48,48,48) }):Play()
    end
    local function hoverLG(e)
        TweenService:Create(playFrame, TweenInfo.new(0.12), { BackgroundColor3 = e and Color3.fromRGB(75,75,75) or Color3.fromRGB(55,55,55) }):Play()
    end
    prevClick.MouseEnter:Connect(function() hoverSM(prevFrame, true) end)
    prevClick.MouseLeave:Connect(function() hoverSM(prevFrame, false) end)
    nextClick.MouseEnter:Connect(function() hoverSM(nextFrame, true) end)
    nextClick.MouseLeave:Connect(function() hoverSM(nextFrame, false) end)
    playClick.MouseEnter:Connect(function() hoverLG(true) end)
    playClick.MouseLeave:Connect(function() hoverLG(false) end)

    local BAR_W = 4; local BAR_GAP = 2; local BAR_MAX_H = 26; local BAR_MIN_H = 3; local BAR_COUNT = 31
    local VOL_COL_ON = Color3.fromRGB(200, 200, 200); local VOL_COL_OFF = Color3.fromRGB(55, 55, 55)
    local volRow = makeUI(optionsFrame6, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 38), BackgroundTransparency = 1, BorderSizePixel = 0
    })
    local volIconBtn = makeUI(volRow, "ImageButton", {
        Size = UDim2.new(0, 22, 0, 22),
        Position = UDim2.new(0, 0, 0.5, -11),
        BackgroundTransparency = 1,
        Image = MP_ICON_VOL,
        ZIndex = 2
    })
    local volPercent = makeUI(volRow, "TextLabel", {
        Size = UDim2.new(0, 34, 1, 0),
        Position = UDim2.new(1, -34, 0, 0),
        BackgroundTransparency = 1, Text = "50%",
        TextColor3 = Color3.fromRGB(160, 160, 160), TextSize = 10,
        Font = Enum.Font.Gotham, TextXAlignment = Enum.TextXAlignment.Right
    })
    local vizContainer = makeUI(volRow, "Frame", {
        Size = UDim2.new(1, -60, 0, BAR_MAX_H),
        Position = UDim2.new(0, 26, 1, -BAR_MAX_H),
        BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = false
    })
    local bars = {}
    local barTargetH = {}
    for i = 1, BAR_COUNT do
        barTargetH[i] = BAR_MIN_H
        local xPos = (i - 1) * (BAR_W + BAR_GAP)
        local bar = makeUI(vizContainer, "Frame", {
            Size = UDim2.new(0, BAR_W, 0, BAR_MIN_H),
            Position = UDim2.new(0, xPos, 1, -BAR_MIN_H),
            AnchorPoint = Vector2.new(0, 1),
            BackgroundColor3 = VOL_COL_OFF, BorderSizePixel = 0, ZIndex = 2
        })
        makeUI(bar, "UICorner", { CornerRadius = UDim.new(0, 2) })
        bars[i] = bar
    end
    local volHit = makeUI(volRow, "TextButton", {
        Size = UDim2.new(1, -60, 1, 0),
        Position = UDim2.new(0, 26, 0, 0),
        BackgroundTransparency = 1, Text = "", ZIndex = 10
    })
    local animPhase = 0
    local function updateVolBars(vol, phase, animate)
        local activeCount = math.floor(vol * BAR_COUNT + 0.5)
        for i = 1, BAR_COUNT do
            local active = (i <= activeCount)
            local targetH
            if active and animate then
                local wave = math.sin(phase + i * 0.6) * 0.5 + 0.5
                targetH = math.floor(BAR_MIN_H + wave * (BAR_MAX_H - BAR_MIN_H))
            elseif active then
                local t = (i / BAR_COUNT)
                targetH = math.floor(BAR_MIN_H + t * (BAR_MAX_H - BAR_MIN_H - 4))
            else
                targetH = BAR_MIN_H
            end
            barTargetH[i] = targetH
            bars[i].BackgroundColor3 = active and VOL_COL_ON or VOL_COL_OFF
        end
    end

    local volDragging = false
    local function setVolume(vol)
        vol = math.clamp(vol, 0, 1)
        sound.Volume = vol
        if not isMuted then savedVolume = vol end
        volPercent.Text = math.floor(vol * 100) .. "%"
    end
    local function volFromInput(input)
        local rel = math.clamp((input.Position.X - vizContainer.AbsolutePosition.X) / vizContainer.AbsoluteSize.X, 0, 1)
        setVolume(rel)
    end
    volHit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            volDragging = true; volFromInput(input)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if volDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            volFromInput(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            volDragging = false
        end
    end)
    volIconBtn.MouseButton1Click:Connect(function()
        isMuted = not isMuted
        if isMuted then
            savedVolume = sound.Volume > 0 and sound.Volume or savedVolume
            sound.Volume = 0
            volIconBtn.Image = MP_ICON_MUTE
            volPercent.Text = "0%"
        else
            setVolume(savedVolume)
            volIconBtn.Image = MP_ICON_VOL
        end
    end)

    local playlistDD = createPlaylistDropdown(songs, DEFAULT_COUNT, {
        onSelect = function(idx, song)
            currentSongIndex = idx
            songNameLabel.Text = song.Name
            sound:Stop()
            sound.SoundId = song.Id
            task.wait(0.05)
            sound:Play()
            isPlaying = true
            setPlayState(true)
        end,
        onDelete = function(idx)
            table.remove(songs, idx)
            if currentSongIndex >= idx and currentSongIndex > 1 then
                currentSongIndex = currentSongIndex - 1
            end
            mp_saveCustomSongs(songs, DEFAULT_COUNT)
            playlistDD.rebuild(songs, DEFAULT_COUNT, playlistDD._cbs)
        end,
    })
    playlistDD._cbs = playlistDD._cbs or {}

    local dropIconImg  = playlistDD.iconImg
    local dropLabel    = playlistDD.nameLabel

    local function rebuildDropdown()
        playlistDD.rebuild(songs, DEFAULT_COUNT, {
            onSelect = function(idx, song)
                currentSongIndex = idx
                songNameLabel.Text = song.Name
                sound:Stop()
                sound.SoundId = song.Id
                task.wait(0.05)
                sound:Play()
                isPlaying = true
                setPlayState(true)
            end,
            onDelete = function(idx)
                table.remove(songs, idx)
                if currentSongIndex >= idx and currentSongIndex > 1 then
                    currentSongIndex = currentSongIndex - 1
                end
                mp_saveCustomSongs(songs, DEFAULT_COUNT)
                rebuildDropdown()
            end,
        })
    end

    local folderLabelRow = makeUI(optionsFrame6, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 14), BackgroundTransparency = 1, BorderSizePixel = 0
    })
    makeUI(folderLabelRow, "TextLabel", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
        Text = "ZERO MUSIC FOLDER",
        Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(150, 150, 150),
        TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left
    })
    local folderFrame = makeUI(optionsFrame6, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 58),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        BackgroundTransparency = 0.2, BorderSizePixel = 0
    })
    makeUI(folderFrame, "UICorner", { CornerRadius = UDim.new(0, 8) })
    makeUI(folderFrame, "UIStroke", { Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.4 })
    makeUI(folderFrame, "TextLabel", {
        Size = UDim2.new(1, -12, 0, 18), Position = UDim2.new(0, 8, 0, 4),
        BackgroundTransparency = 1,
        Text = "Place .mp3 / .ogg files in:  Zero Music/",
        Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(160, 160, 160),
        TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3
    })
    local scanBtn = makeUI(folderFrame, "TextButton", {
        Size = UDim2.new(0, 100, 0, 22), Position = UDim2.new(0, 6, 0, 28),
        BackgroundColor3 = Color3.fromRGB(60, 60, 60), BorderSizePixel = 0,
        Text = "Scan", Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 9, ZIndex = 4,
        AutoButtonColor = false
    })
    makeUI(scanBtn, "UICorner", { CornerRadius = UDim.new(0, 5) })
    local folderStatusLabel = makeUI(folderFrame, "TextLabel", {
        Size = UDim2.new(1, -120, 0, 22), Position = UDim2.new(0, 112, 0, 28),
        BackgroundTransparency = 1,
        Text = mp_canFolderIO() and "Ready (MP3 + OGG)" or "File IO not supported",
        Font = Enum.Font.Gotham,
        TextColor3 = mp_canFolderIO() and Color3.fromRGB(100, 200, 120) or Color3.fromRGB(220, 120, 80),
        TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 4,
        TextTruncate = Enum.TextTruncate.AtEnd
    })
    local scanBtnTween = nil
    local scanBtnHovered = false
    local function setScanColor(color)
        if scanBtnTween then scanBtnTween:Cancel() end
        scanBtnTween = TweenService:Create(scanBtn, TweenInfo.new(0.1), { BackgroundColor3 = color })
        scanBtnTween:Play()
    end
    scanBtn.MouseEnter:Connect(function()
        scanBtnHovered = true
        setScanColor(Color3.fromRGB(30, 80, 30))
    end)
    scanBtn.MouseLeave:Connect(function()
        scanBtnHovered = false
        setScanColor(Color3.fromRGB(60, 60, 60))
    end)
    scanBtn.MouseButton1Down:Connect(function()
        setScanColor(scanBtnHovered and Color3.fromRGB(30, 80, 30) or Color3.fromRGB(60, 60, 60))
    end)
    scanBtn.MouseButton1Up:Connect(function()
        setScanColor(scanBtnHovered and Color3.fromRGB(30, 80, 30) or Color3.fromRGB(60, 60, 60))
    end)
    scanBtn.MouseButton1Click:Connect(function()
        if not mp_canFolderIO() then
            folderStatusLabel.Text = "File IO not supported"
            folderStatusLabel.TextColor3 = Color3.fromRGB(220, 120, 80)
            return
        end
        folderStatusLabel.Text = "Scanning OGG..."
        folderStatusLabel.TextColor3 = Color3.fromRGB(200, 200, 100)
        task.spawn(function()
            local newSongs = {}
            for _, s in ipairs(songs) do
                if not s.IsFile then table.insert(newSongs, s) end
            end
            local folderSongs = mp_loadFolderSongs()
            for _, s in ipairs(folderSongs) do table.insert(newSongs, s) end
            while #songs > 0 do table.remove(songs) end
            for _, s in ipairs(newSongs) do table.insert(songs, s) end
            rebuildDropdown()
            local count = #folderSongs
            if count == 0 then
                folderStatusLabel.Text = "No MP3 or OGG files found in folder"
                folderStatusLabel.TextColor3 = Color3.fromRGB(200, 160, 60)
            else
                folderStatusLabel.Text = count .. " audio file(s) found (MP3/OGG)!"
                folderStatusLabel.TextColor3 = Color3.fromRGB(100, 220, 120)
            end
            task.delay(4, function()
                if folderStatusLabel then
                    folderStatusLabel.Text = "Ready (MP3 + OGG)"
                    folderStatusLabel.TextColor3 = Color3.fromRGB(100, 200, 120)
                end
            end)
        end)
    end)

    local addLabelRow = makeUI(optionsFrame6, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 14), BackgroundTransparency = 1, BorderSizePixel = 0
    })
    makeUI(addLabelRow, "TextLabel", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "ADD SONG",
        Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(150,150,150),
        TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left
    })
    local addFrame = makeUI(optionsFrame6, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 72),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        BackgroundTransparency = 0.2, BorderSizePixel = 0
    })
    makeUI(addFrame, "UICorner", { CornerRadius = UDim.new(0, 8) })
    makeUI(addFrame, "UIStroke", { Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.4 })
    local nameBox = makeUI(addFrame, "TextBox", {
        Size = UDim2.new(1, -12, 0, 22), Position = UDim2.new(0, 6, 0, 6),
        BackgroundColor3 = Color3.fromRGB(28, 28, 28), BackgroundTransparency = 0.1,
        BorderSizePixel = 0, Text = "",
        PlaceholderText = "Song name...", PlaceholderColor3 = Color3.fromRGB(100, 100, 100),
        TextColor3 = Color3.fromRGB(220, 220, 220), Font = Enum.Font.Gotham, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ZIndex = 6
    })
    makeUI(nameBox, "UICorner", { CornerRadius = UDim.new(0, 5) })
    makeUI(nameBox, "UIPadding", { PaddingLeft = UDim.new(0, 7) })
    local idBox = makeUI(addFrame, "TextBox", {
        Size = UDim2.new(1, -62, 0, 22), Position = UDim2.new(0, 6, 0, 34),
        BackgroundColor3 = Color3.fromRGB(28, 28, 28), BackgroundTransparency = 0.1,
        BorderSizePixel = 0, Text = "",
        PlaceholderText = "Sound ID / rbxassetid://...", PlaceholderColor3 = Color3.fromRGB(100, 100, 100),
        TextColor3 = Color3.fromRGB(220, 220, 220), Font = Enum.Font.Gotham, TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false, ZIndex = 6
    })
    makeUI(idBox, "UICorner", { CornerRadius = UDim.new(0, 5) })
    makeUI(idBox, "UIPadding", { PaddingLeft = UDim.new(0, 7) })
    local addBtn = makeUI(addFrame, "TextButton", {
        Size = UDim2.new(0, 46, 0, 22), Position = UDim2.new(1, -52, 0, 34),
        BackgroundColor3 = Color3.fromRGB(40, 110, 45), BorderSizePixel = 0,
        Text = "+ Add", Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 10, ZIndex = 6
    })
    makeUI(addBtn, "UICorner", { CornerRadius = UDim.new(0, 5) })
    local statusLabel = makeUI(addFrame, "TextLabel", {
        Size = UDim2.new(1, -12, 0, 12), Position = UDim2.new(0, 6, 1, -14),
        BackgroundTransparency = 1, Text = "",
        Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(100, 200, 120),
        TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 6
    })
    addBtn.MouseEnter:Connect(function()
        TweenService:Create(addBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(70, 180, 70) }):Play()
    end)
    addBtn.MouseLeave:Connect(function()
        TweenService:Create(addBtn, TweenInfo.new(0.1), { BackgroundColor3 = Color3.fromRGB(40, 110, 45) }):Play()
    end)
    -- Update placeholder to hint MP3/OGG path support
    idBox.PlaceholderText = "Sound ID, rbxassetid://, or local path"

    addBtn.MouseButton1Click:Connect(function()
        local rawName = nameBox.Text:match("^%s*(.-)%s*$")
        local rawId   = idBox.Text:match("^%s*(.-)%s*$")
        if rawName == "" then
            statusLabel.Text = "Song name cannot be empty!"
            statusLabel.TextColor3 = Color3.fromRGB(220, 100, 80)
            return
        end
        if rawId == "" then
            statusLabel.Text = "Enter a Sound ID or local file path!"
            statusLabel.TextColor3 = Color3.fromRGB(220, 100, 80)
            return
        end

        local finalId
        local isFile = false

        -- Case 1: already a full rbxassetid:// URI
        if rawId:match("^rbxassetid://") then
            finalId = rawId

        -- Case 2: plain numeric Roblox sound ID
        elseif rawId:match("^%d+$") then
            finalId = "rbxassetid://" .. rawId

        -- Case 3: local file path (.mp3 or .ogg) -> resolve via GetCustomAsset
        elseif rawId:lower():match("%.mp3$") or rawId:lower():match("%.ogg$") then
            if not mp_canFolderIO() then
                statusLabel.Text = "File IO not supported on this executor!"
                statusLabel.TextColor3 = Color3.fromRGB(220, 100, 80)
                return
            end
            local okD, data = pcall(readfile, rawId)
            local ext = (rawId:match("%.([^%.]+)$") or ""):lower()
            if not mp_validateAudioFile(data, ext) then
                statusLabel.Text = "File not found or corrupt: " .. rawId
                statusLabel.TextColor3 = Color3.fromRGB(220, 100, 80)
                return
            end
            local resolved = mp_resolveLocalAudio(rawId)
            if not resolved then
                statusLabel.Text = "GetCustomAsset() failed for this file!"
                statusLabel.TextColor3 = Color3.fromRGB(220, 100, 80)
                return
            end
            finalId = resolved
            isFile  = true

        else
            statusLabel.Text = "Invalid input! Use ID, rbxassetid://, or .mp3/.ogg path"
            statusLabel.TextColor3 = Color3.fromRGB(220, 100, 80)
            return
        end

        table.insert(songs, {
            Name    = rawName,
            Id      = finalId,
            Icon    = MP_ICON_SONG,
            IsFile  = isFile,
            RawPath = isFile and rawId or nil,
            CanPlay = true,
        })
        mp_saveCustomSongs(songs, DEFAULT_COUNT)
        rebuildDropdown()
        nameBox.Text = ""; idBox.Text = ""
        statusLabel.Text = "\"" .. rawName .. "\" added" .. (mp_canFileIO() and " & saved!" or " (no file IO)")
        statusLabel.TextColor3 = Color3.fromRGB(100, 200, 120)
        task.delay(3, function() if statusLabel then statusLabel.Text = "" end end)
    end)

    local isChangingSong = false
    local function playSong(idx, autoPlay)
        isChangingSong = true
        currentSongIndex = idx
        sound:Stop()
        sound.TimePosition = 0
        local songEntry = songs[idx]
        if songEntry.IsFile then
            if songEntry.CanPlay == false then
                songNameLabel.Text = "File corrupt or unsupported format!"
                isPlaying = false
                setPlayState(false)
                task.defer(function() isChangingSong = false end)
                return
            end
            local assigned = false
            -- Prefer cached resolved ID (already a rbxasset:// URI from GetCustomAsset)
            if songEntry.Id and songEntry.Id ~= "" then
                local ok1 = pcall(function() sound.SoundId = songEntry.Id end)
                if ok1 then assigned = true end
            end
            -- If cache miss, re-resolve via GetCustomAsset (works for both MP3 and OGG)
            if not assigned and songEntry.RawPath then
                local resolved = mp_resolveLocalAudio(songEntry.RawPath)
                if resolved then
                    songEntry.Id = resolved  -- cache for next time
                    local ok2 = pcall(function() sound.SoundId = resolved end)
                    if ok2 then assigned = true end
                end
            end
            if not assigned then
                local fmt = songEntry.FileExt and songEntry.FileExt:upper() or "audio"
                songNameLabel.Text = "Failed to load " .. fmt .. " file!"
                isPlaying = false
                setPlayState(false)
                task.defer(function() isChangingSong = false end)
                return
            end
        else
            sound.SoundId = songEntry.Id
        end
        songNameLabel.Text = songEntry.Name
        dropIconImg.Image = songEntry.Icon
        dropLabel.Text = songEntry.Name
        if autoPlay then
            isPlaying = true
            setPlayState(true)
            task.spawn(function()
                pcall(function()
                    if not sound.IsLoaded then sound.Loaded:Wait() end
                    sound.TimePosition = 0
                    sound:Play()
                end)
            end)
        end
        task.defer(function() isChangingSong = false end)
    end
    playSong(1, false)

    playClick.MouseButton1Click:Connect(function()
        if not isPlaying then sound:Resume(); isPlaying = true; setPlayState(true)
        else sound:Pause(); isPlaying = false; setPlayState(false) end
    end)
    nextClick.MouseButton1Click:Connect(function() playSong(currentSongIndex % #songs + 1, true) end)
    prevClick.MouseButton1Click:Connect(function() playSong(((currentSongIndex-2) % #songs)+1, true) end)
    sound.Ended:Connect(function()
        if isChangingSong then return end
        if isPlaying then
            task.defer(function()
                pcall(function()
                    playSong(currentSongIndex % #songs + 1, true)
                end)
            end)
        end
    end)

    RunService.Heartbeat:Connect(function(dt)
        if not isScrubbing and sound.IsLoaded and sound.TimeLength and sound.TimeLength > 0 then
            local pos = sound.TimePosition or 0
            local len = sound.TimeLength
            local ratio = pos / len
            progressBar.Size = UDim2.new(ratio, 0, 1, 0)
            progressThumb.Position = UDim2.new(ratio, 0, 0.5, 0)
            currentTimeLabel.Text = formatTime(pos)
            totalTimeLabel.Text = formatTime(len)
        end
        if isPlaying then
            vizPhase = vizPhase + dt * 5
            animPhase = animPhase + dt * 4.5
        end
        updateViz(isPlaying, isMuted and 0 or savedVolume)
        updateVolBars(isMuted and 0 or savedVolume, animPhase, isPlaying)
        for i = 1, BAR_COUNT do
            local cur = bars[i].Size.Y.Offset
            local tgt = barTargetH[i]
            local new = cur + (tgt - cur) * 0.25
            bars[i].Size = UDim2.new(0, BAR_W, 0, new)
            bars[i].Position = UDim2.new(0, (i-1)*(BAR_W+BAR_GAP), 1, -new)
        end
    end)
end

local function clothes_setStatus(text, color)
    if clothes_statusLabel then
        clothes_statusLabel.Text = "Status: " .. text
        clothes_statusLabel.TextColor3 = color or Color3.fromRGB(145, 145, 145)
    end
end

function createClothesPage()
    local headerClothes = makeUI(optionsFrame4, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 22),
        BackgroundTransparency = 1, BorderSizePixel = 0
    })
    makeUI(headerClothes, "TextLabel", {
        Text = "Clothes Changer",
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 12,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center
    })

    local AC_CLOTHES_SLOTS = {
        {label = "Classic Shirt",  clothesMode = "ClassicShirt"},
        {label = "Classic Pants",  clothesMode = "ClassicPants"},
        {label = "Shirt",         clothesMode = "Shirt"},
        {label = "T-Shirt",           clothesMode = "TShirt"},
        {label = "Sweater",        clothesMode = "Sweater"},
        {label = "Jacket",          clothesMode = "Jacket"},
        {label = "Pants", clothesMode = "Pants"},
        {label = "Shorts",  clothesMode = "Shorts"},
        {label = "Bodysuit",       clothesMode = "Bodysuit"},
        {label = "Shoes",         clothesMode = "Shoes"},
    }

    local function ac_applyClothes(clothesMode, assetIdStr)
        task.spawn(function()
            xpcall(function()
                local char = LocalPlayer.Character
                if not char then clothes_setStatus("Character not found!", Color3.fromRGB(155, 45, 45)); return end
                local HUM = char:FindFirstChildOfClass("Humanoid")
                if not HUM then clothes_setStatus("Humanoid not found!", Color3.fromRGB(155, 45, 45)); return end

                assetIdStr = tostring(assetIdStr):gsub("%s+", "")
                local assetId = tonumber(assetIdStr)
                if not assetId or assetId == 0 then
                    clothes_setStatus("Invalid ID!", Color3.fromRGB(195, 80, 50)); return
                end

                clothes_setStatus("Applying clothes...", Color3.fromRGB(195, 165, 50))

                startPositionLock(char, 2.0)

                local DESC_MAP = {
                    ClassicShirt = "Shirt",
                    ClassicPants = "Pants",
                    Shirt        = "Shirt",
                    TShirt       = "GraphicTShirt",
                    Sweater      = "Shirt",
                    Jacket       = "Shirt",
                    Pants        = "Pants",
                    Shorts       = "Pants",
                    Bodysuit     = "Shirt",
                    Shoes        = "Pants",
                }

                local descProp = DESC_MAP[clothesMode]
                local desc = HUM:GetAppliedDescription()

                if descProp then
                    for _, obj in ipairs(char:GetChildren()) do
                        if descProp == "Shirt" and obj:IsA("Shirt") then obj:Destroy()
                        elseif descProp == "Pants" and obj:IsA("Pants") then obj:Destroy()
                        elseif descProp == "GraphicTShirt" and obj:IsA("ShirtGraphic") then obj:Destroy()
                        end
                    end

                    desc[descProp] = assetId
                    task.wait(0.1)

                    local InsertService = game:GetService("InsertService")
                    pcall(function()
                        local model = LoadAssetLocal(assetId)
                        if model then
                            for _, child in ipairs(model:GetChildren()) do
                                if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
                                    for _, existing in ipairs(char:GetChildren()) do
                                        if existing:IsA(child.ClassName) then existing:Destroy() end
                                    end
                                    child.Parent = char
                                end
                            end
                            model:Destroy()
                        end
                    end)

                    clothes_setStatus("Clothes applied!", Color3.fromRGB(55, 175, 55))
                    AC_CLOTHES_APPLIED[descProp] = assetId
                else
                    clothes_setStatus("Unknown clothing type!", Color3.fromRGB(195, 80, 50))
                end
            end, function(err)
                clothes_setStatus("Error: " .. tostring(err):sub(1,40), Color3.fromRGB(155, 45, 45))
            end)
        end)
    end

    local cl_slotBoxRegistry = {}
    for _, clothesInfo in ipairs(AC_CLOTHES_SLOTS) do
        local rowFrame = makeUI(optionsFrame4, "Frame", {
            Size = UDim2.new(0.95, 0, 0, 34),
            BackgroundColor3 = Color3.fromRGB(35, 35, 35), BackgroundTransparency = 0.15, BorderSizePixel = 0
        })
        makeUI(rowFrame, "UICorner", {CornerRadius = UDim.new(0, 7)})
        makeUI(rowFrame, "UIStroke", {Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.5})
        makeUI(rowFrame, "TextLabel", {
            Text = clothesInfo.label, Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(210, 210, 210), TextSize = 10,
            BackgroundTransparency = 1, Size = UDim2.new(0.34, 0, 1, 0),
            Position = UDim2.new(0.02, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true
        })
        local clothesBox = makeUI(rowFrame, "TextBox", {
            Size = UDim2.new(0.43, 0, 0.62, 0), Position = UDim2.new(0.36, 0, 0.19, 0),
            BackgroundColor3 = Color3.fromRGB(22, 22, 22), BackgroundTransparency = 0.1,
            TextColor3 = Color3.fromRGB(200, 200, 200), PlaceholderText = "Asset ID...",
            PlaceholderColor3 = Color3.fromRGB(85, 85, 85), Font = Enum.Font.Gotham, TextSize = 11,
            ClearTextOnFocus = false, BorderSizePixel = 0, Text = "", TextWrapped = false,
            TextTruncate = Enum.TextTruncate.AtEnd, ClipsDescendants = true
        })
        makeUI(clothesBox, "UICorner", {CornerRadius = UDim.new(0, 5)})
        clothesBox.Focused:Connect(function() TweenService:Create(clothesBox, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play() end)
        clothesBox.FocusLost:Connect(function() TweenService:Create(clothesBox, TweenInfo.new(0.12), {BackgroundTransparency = 0.1}):Play() end)
        clothesBox.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.Touch then clothesBox:CaptureFocus() end end)
        cl_slotBoxRegistry[clothesInfo.clothesMode] = clothesBox

        local applyBtn = makeUI(rowFrame, "TextButton", {
            Size = UDim2.new(0.17, 0, 0.62, 0), Position = UDim2.new(0.81, 0, 0.19, 0),
            BackgroundColor3 = Color3.fromRGB(40, 110, 45), TextColor3 = Color3.fromRGB(255, 255, 255),
            Font = Enum.Font.GothamBold, TextSize = 16, Text = "+", BorderSizePixel = 0, Active = true
        })
        makeUI(applyBtn, "UICorner", {CornerRadius = UDim.new(0, 5)})
        local cInfo = clothesInfo; local cBox = clothesBox
        applyBtn.MouseButton1Click:Connect(function()
            TweenService:Create(applyBtn, TweenInfo.new(0.07), {BackgroundColor3 = Color3.fromRGB(70, 180, 70)}):Play()
            task.wait(0.15)
            TweenService:Create(applyBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(40, 110, 45)}):Play()
            if cBox.Text == "" then clothes_setStatus("Enter Asset ID!", Color3.fromRGB(195, 165, 50)); return end
            ac_applyClothes(cInfo.clothesMode, cBox.Text)
        end)
    end
    makeUI(optionsFrame4, "Frame", {
        Size = UDim2.new(0.9, 0, 0, 1), BackgroundColor3 = Color3.fromRGB(60, 60, 60),
        BackgroundTransparency = 0, BorderSizePixel = 0
    })

    local sf = makeUI(optionsFrame4, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 18),
        BackgroundTransparency = 1, BorderSizePixel = 0
    })
    clothes_statusLabel = makeUI(sf, "TextLabel", {
        Text = "Status: Idle",
        Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(145, 145, 145), TextSize = 11,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center
    })

    local presetHdr = makeUI(optionsFrame4, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 20), BackgroundTransparency = 1, BorderSizePixel = 0
    })
    makeUI(presetHdr, "TextLabel", {
        Text = "Save Preset",
        Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 11,
        BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center
    })

    local cl_saveRow = makeUI(optionsFrame4, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 34),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40), BackgroundTransparency = 0.2, BorderSizePixel = 0
    })
    makeUI(cl_saveRow, "UICorner", {CornerRadius = UDim.new(0, 8)})
    makeUI(cl_saveRow, "UIStroke", {Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.4})

    local cl_presetNameBox = makeUI(cl_saveRow, "TextBox", {
        Size = UDim2.new(0.68, 0, 0.65, 0), Position = UDim2.new(0.02, 0, 0.175, 0),
        BackgroundColor3 = Color3.fromRGB(30, 30, 30), BackgroundTransparency = 0.1,
        TextColor3 = Color3.fromRGB(220, 220, 220),
        PlaceholderText = "Preset name...",
        PlaceholderColor3 = Color3.fromRGB(100, 100, 100),
        Font = Enum.Font.Gotham, TextSize = 11,
        ClearTextOnFocus = false, BorderSizePixel = 0, Text = ""
    })
    makeUI(cl_presetNameBox, "UICorner", {CornerRadius = UDim.new(0, 5)})
    cl_presetNameBox.Focused:Connect(function()
        TweenService:Create(cl_presetNameBox, TweenInfo.new(0.12), {BackgroundTransparency = 0}):Play()
    end)
    cl_presetNameBox.FocusLost:Connect(function()
        TweenService:Create(cl_presetNameBox, TweenInfo.new(0.12), {BackgroundTransparency = 0.1}):Play()
    end)
    cl_presetNameBox.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.Touch then cl_presetNameBox:CaptureFocus() end
    end)

    local cl_saveBtnF = makeUI(cl_saveRow, "Frame", {
        Size = UDim2.new(0.27, 0, 0.65, 0), Position = UDim2.new(0.71, 0, 0.175, 0),
        BackgroundColor3 = Color3.fromRGB(60, 60, 60), BorderSizePixel = 0
    })
    makeUI(cl_saveBtnF, "UICorner", {CornerRadius = UDim.new(0, 5)})
    local cl_saveBtn = makeUI(cl_saveBtnF, "TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
        Text = "Save", Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 11
    })

    local cl_dropOpen = false
    local cl_selectedIdx = nil
    local cl_dropArrow, cl_selectedLabel

    local cl_dropBtnFrame = makeUI(optionsFrame4, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 34),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40), BackgroundTransparency = 0.2, BorderSizePixel = 0
    })
    makeUI(cl_dropBtnFrame, "UICorner", {CornerRadius = UDim.new(0, 8)})
    makeUI(cl_dropBtnFrame, "UIStroke", {Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.4})

    cl_selectedLabel = makeUI(cl_dropBtnFrame, "TextLabel", {
        Text = "Select preset...", Font = Enum.Font.Gotham,
        TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 11,
        BackgroundTransparency = 1, Size = UDim2.new(0.8, 0, 1, 0),
        Position = UDim2.new(0.04, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd
    })
    cl_dropArrow = makeUI(cl_dropBtnFrame, "TextLabel", {
        Text = "▼", Font = Enum.Font.GothamBold, TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 10,
        BackgroundTransparency = 1, Size = UDim2.new(0, 20, 1, 0), Position = UDim2.new(1, -22, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Center
    })
    local cl_dropClickBtn = makeUI(cl_dropBtnFrame, "TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
        AutoButtonColor = false, Text = ""
    })

    local cl_dropListOuter = makeUI(optionsFrame4, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(35, 35, 35), BackgroundTransparency = 0,
        BorderSizePixel = 0, Visible = false, ClipsDescendants = true
    })
    makeUI(cl_dropListOuter, "UICorner", {CornerRadius = UDim.new(0, 7)})
    makeUI(cl_dropListOuter, "UIStroke", {Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.3})
    local cl_dropList = makeUI(cl_dropListOuter, "ScrollingFrame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100),
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ClipsDescendants = true
    })
    local cl_dropListLayout = makeUI(cl_dropList, "UIListLayout", {
        Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder,
        HorizontalAlignment = Enum.HorizontalAlignment.Center
    })
    makeUI(cl_dropList, "UIPadding", {PaddingTop = UDim.new(0,4), PaddingBottom = UDim.new(0,4)})
    cl_dropListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        cl_dropList.CanvasSize = UDim2.new(0, 0, 0, cl_dropListLayout.AbsoluteContentSize.Y + 8)
    end)

    local cl_actionRow = makeUI(optionsFrame4, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 34),
        BackgroundTransparency = 1, BorderSizePixel = 0
    })
    makeUI(cl_actionRow, "UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Padding = UDim.new(0, 6)
    })

    local function cl_makeActionBtn(parent, txt, bgColor, textColor)
        local f = makeUI(parent, "Frame", {
            Size = UDim2.new(0.46, 0, 0, 32),
            BackgroundColor3 = bgColor, BackgroundTransparency = 0.15, BorderSizePixel = 0
        })
        makeUI(f, "UICorner", {CornerRadius = UDim.new(0, 7)})
        local b = makeUI(f, "TextButton", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
            Text = txt, Font = Enum.Font.GothamBold, TextColor3 = textColor, TextSize = 12
        })
        return b, f
    end

    local cl_loadBtn, cl_loadBtnF   = cl_makeActionBtn(cl_actionRow, "Load",  Color3.fromRGB(40,40,40), Color3.fromRGB(255,255,255))
    local cl_deleteBtn, cl_deleteBtnF = cl_makeActionBtn(cl_actionRow, "Delete", Color3.fromRGB(40,40,40), Color3.fromRGB(255,255,255))

    local CL_PRESETS = {}
    local CL_PRESET_FILE = "Zero Directory/clothes_presets.json"

    local function cl_canFileIO()
        return type(writefile)=="function" and type(readfile)=="function"
            and type(isfile)=="function" and type(isfolder)=="function"
    end
    local function cl_savePresets()
        if not cl_canFileIO() then return end
        pcall(function()
            if not isfolder("Zero Directory") then makefolder("Zero Directory") end
            writefile(CL_PRESET_FILE, HttpService:JSONEncode(CL_PRESETS))
        end)
    end
    local function cl_loadPresetsFromFile()
        if not cl_canFileIO() then return end
        pcall(function()
            if not isfolder("Zero Directory") then makefolder("Zero Directory") end
            if isfile(CL_PRESET_FILE) then
                local ok, decoded = pcall(function()
                    return HttpService:JSONDecode(readfile(CL_PRESET_FILE))
                end)
                if ok and decoded then CL_PRESETS = decoded end
            end
        end)
    end

    local function cl_collectCurrentClothes()
        local clothes = {}
        local char = LocalPlayer.Character
        if not char then return clothes end
        local HUM = char:FindFirstChildOfClass("Humanoid")
        if not HUM then return clothes end
        local desc = HUM:GetAppliedDescription()
        local props = {"Shirt","Pants","GraphicTShirt"}
        for _, prop in ipairs(props) do
            local val = desc[prop]
            if val and val ~= 0 then clothes[prop] = val end
        end
        return clothes
    end

    local function cl_applyPreset(preset)
        task.spawn(function()
            local char = LocalPlayer.Character
            if not char then clothes_setStatus("Character not found!", Color3.fromRGB(155,45,45)); return end
            local HUM = char:FindFirstChildOfClass("Humanoid")
            if not HUM then return end
            clothes_setStatus("Loading preset...", Color3.fromRGB(195,165,50))

            local desc = HUM:GetAppliedDescription()
            local InsertService = game:GetService("InsertService")

            for prop, assetId in pairs(preset.clothes or {}) do
                for _, obj in ipairs(char:GetChildren()) do
                    if prop == "Shirt" and obj:IsA("Shirt") then obj:Destroy()
                    elseif prop == "Pants" and obj:IsA("Pants") then obj:Destroy()
                    elseif prop == "GraphicTShirt" and obj:IsA("ShirtGraphic") then obj:Destroy()
                    end
                end
                desc[prop] = assetId
                task.wait(0.05)
                pcall(function()
                    local model = LoadAssetLocal(assetId)
                    if model then
                        for _, child in ipairs(model:GetChildren()) do
                            if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
                                for _, ex in ipairs(char:GetChildren()) do
                                    if ex:IsA(child.ClassName) then ex:Destroy() end
                                end
                                child.Parent = char
                            end
                        end
                        model:Destroy()
                    end
                end)
                AC_CLOTHES_APPLIED[prop] = assetId
            end
            clothes_setStatus("Preset applied!", Color3.fromRGB(55,175,55))
        end)
    end

    local function cl_rebuildDropdown()
        for _, v in ipairs(cl_dropList:GetChildren()) do
            if not v:IsA("UIListLayout") and not v:IsA("UIPadding") then v:Destroy() end
        end

        if #CL_PRESETS == 0 then
            makeUI(cl_dropList, "TextLabel", {
                Text = "No presets yet",
                Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(120,120,120), TextSize = 11,
                BackgroundTransparency = 1, Size = UDim2.new(1,-8,0,26),
                TextXAlignment = Enum.TextXAlignment.Center
            })
            cl_dropListOuter.Size = UDim2.new(0.95, 0, 0, 34)
            return
        end

        for i, preset in ipairs(CL_PRESETS) do
            local itemF = makeUI(cl_dropList, "Frame", {
                Size = UDim2.new(1,-8,0,28),
                BackgroundColor3 = Color3.fromRGB(50,50,50), BackgroundTransparency = 0.3, BorderSizePixel = 0
            })
            makeUI(itemF, "UICorner", {CornerRadius = UDim.new(0,5)})
            local itemBtn = makeUI(itemF, "TextButton", {
                Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
                Text = "  " .. preset.name,
                Font = Enum.Font.Gotham, TextColor3 = Color3.fromRGB(220,220,220), TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd
            })
            local count = 0
            for _ in pairs(preset.clothes or {}) do count = count + 1 end
            makeUI(itemF, "TextLabel", {
                Text = count .. " item", Font = Enum.Font.Gotham,
                TextColor3 = Color3.fromRGB(150,150,150), TextSize = 10,
                BackgroundTransparency = 1, Size = UDim2.new(0.25,0,1,0),
                Position = UDim2.new(0.75,0,0,0), TextXAlignment = Enum.TextXAlignment.Center
            })
            local capturedI = i
            itemBtn.MouseButton1Click:Connect(function()
                cl_selectedIdx = capturedI
                cl_selectedLabel.Text = CL_PRESETS[capturedI].name
                cl_selectedLabel.TextColor3 = Color3.fromRGB(255,255,255)
                cl_dropOpen = false
                cl_dropArrow.Text = "▼"
                TweenService:Create(cl_dropListOuter, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {Size = UDim2.new(0.95,0,0,0)}):Play()
                task.delay(0.16, function() cl_dropListOuter.Visible = false end)
            end)
        end

        local totalH = math.min(cl_dropListLayout.AbsoluteContentSize.Y + 10, 150)
        cl_dropListOuter.Size = UDim2.new(0.95, 0, 0, totalH)
    end

    cl_dropClickBtn.MouseButton1Click:Connect(function()
        cl_dropOpen = not cl_dropOpen
        cl_rebuildDropdown()
        if cl_dropOpen then
            cl_dropArrow.Text = "▲"
            cl_dropListOuter.Visible = true
            task.wait()
            local totalH = math.min(cl_dropListLayout.AbsoluteContentSize.Y + 10, 150)
            cl_dropListOuter.Size = UDim2.new(0.95,0,0,0)
            TweenService:Create(cl_dropListOuter, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Size = UDim2.new(0.95,0,0,totalH)}):Play()
        else
            cl_dropArrow.Text = "▼"
            TweenService:Create(cl_dropListOuter, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Size = UDim2.new(0.95,0,0,0)}):Play()
            task.delay(0.16, function() cl_dropListOuter.Visible = false end)
        end
    end)

    cl_saveBtn.MouseButton1Click:Connect(function()
        TweenService:Create(cl_saveBtnF, TweenInfo.new(0.07), {BackgroundTransparency = 0}):Play()
        task.wait(0.12)
        TweenService:Create(cl_saveBtnF, TweenInfo.new(0.1), {BackgroundTransparency = 0.1}):Play()

        local name = cl_presetNameBox.Text:match("^%s*(.-)%s*$")
        if name == "" then
            clothes_setStatus("Enter preset name!", Color3.fromRGB(195,165,50)); return
        end
        for i, p in ipairs(CL_PRESETS) do
            if p.name:lower() == name:lower() then
                CL_PRESETS[i].clothes = cl_collectCurrentClothes()
                cl_savePresets()
                cl_rebuildDropdown()
                clothes_setStatus("Preset '" .. name .. "' updated!", Color3.fromRGB(55,175,55))
                cl_presetNameBox.Text = ""
                return
            end
        end
        local clothes = cl_collectCurrentClothes()
        table.insert(CL_PRESETS, {name = name, clothes = clothes})
        cl_savePresets()
        cl_rebuildDropdown()
        clothes_setStatus("Preset '" .. name .. "' saved!", Color3.fromRGB(55,175,55))
        cl_presetNameBox.Text = ""
    end)

    cl_loadBtn.MouseButton1Click:Connect(function()
        TweenService:Create(cl_loadBtnF, TweenInfo.new(0.07), {BackgroundTransparency = 0}):Play()
        task.wait(0.12)
        TweenService:Create(cl_loadBtnF, TweenInfo.new(0.1), {BackgroundTransparency = 0.15}):Play()
        if not cl_selectedIdx or not CL_PRESETS[cl_selectedIdx] then
            clothes_setStatus("Select a preset first!", Color3.fromRGB(195,165,50)); return
        end
        local preset = CL_PRESETS[cl_selectedIdx]
        local CL_DESC_MAP = {
            ClassicShirt = "Shirt",  ClassicPants = "Pants",
            Shirt        = "Shirt",  TShirt       = "GraphicTShirt",
            Sweater      = "Shirt",  Jacket       = "Shirt",
            Pants        = "Pants",  Shorts       = "Pants",
            Bodysuit     = "Shirt",  Shoes        = "Pants",
        }
        local CL_PRIORITY = {
            Shirt         = {"ClassicShirt", "Shirt", "Sweater", "Jacket", "Bodysuit"},
            Pants         = {"ClassicPants", "Pants", "Shorts", "Shoes"},
            GraphicTShirt = {"TShirt"},
        }
        local descFilled = {}
        for _, box in pairs(cl_slotBoxRegistry) do
            box.Text = ""
        end
        for descProp, modeList in pairs(CL_PRIORITY) do
            local val = preset.clothes and preset.clothes[descProp]
            if val and val ~= 0 then
                for _, mode in ipairs(modeList) do
                    local box = cl_slotBoxRegistry[mode]
                    if box and not descFilled[descProp] then
                        box.Text = tostring(val)
                        box.TextColor3 = Color3.fromRGB(200, 200, 200)
                        descFilled[descProp] = true
                        break
                    end
                end
            end
        end
        cl_applyPreset(preset)
    end)

    cl_deleteBtn.MouseButton1Click:Connect(function()
        TweenService:Create(cl_deleteBtnF, TweenInfo.new(0.07), {BackgroundTransparency = 0}):Play()
        task.wait(0.12)
        TweenService:Create(cl_deleteBtnF, TweenInfo.new(0.1), {BackgroundTransparency = 0.15}):Play()
        if not cl_selectedIdx or not CL_PRESETS[cl_selectedIdx] then
            clothes_setStatus("Select a preset first!", Color3.fromRGB(195,165,50)); return
        end
        local removedName = CL_PRESETS[cl_selectedIdx].name
        table.remove(CL_PRESETS, cl_selectedIdx)
        cl_selectedIdx = nil
        cl_selectedLabel.Text = "Select preset..."
        cl_selectedLabel.TextColor3 = Color3.fromRGB(200,200,200)
        cl_savePresets()
        cl_rebuildDropdown()
        clothes_setStatus("Preset '" .. removedName .. "' deleted", Color3.fromRGB(145,145,145))
    end)

    cl_loadPresetsFromFile()
    cl_rebuildDropdown()

    makeUI(optionsFrame4, "Frame", {
        Size = UDim2.new(0.9, 0, 0, 1), BackgroundColor3 = Color3.fromRGB(60, 60, 60),
        BackgroundTransparency = 0, BorderSizePixel = 0
    })

    local cl_clearFrame = makeUI(optionsFrame4, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 35),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40), BackgroundTransparency = 0.2, BorderSizePixel = 0
    })
    makeUI(cl_clearFrame, "UICorner", {CornerRadius = UDim.new(0, 8)})
    local cl_clearBtn = makeUI(cl_clearFrame, "TextButton", {
        Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
        Text = "Remove All Clothes",
        TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 13, Font = Enum.Font.GothamBold
    })
    cl_clearBtn.MouseButton1Click:Connect(function()
        TweenService:Create(cl_clearFrame, TweenInfo.new(0.07), {BackgroundTransparency = 0}):Play()
        task.wait(0.12)
        TweenService:Create(cl_clearFrame, TweenInfo.new(0.1), {BackgroundTransparency = 0.2}):Play()
        local char = LocalPlayer.Character
        if not char then clothes_setStatus("Character not found!", Color3.fromRGB(155,45,45)); return end
        local HUM = char:FindFirstChildOfClass("Humanoid")
        if HUM then
            for _, obj in ipairs(char:GetChildren()) do
                if obj:IsA("Shirt") or obj:IsA("Pants") or obj:IsA("ShirtGraphic") then
                    obj:Destroy()
                end
            end
            if AC_ORIGINAL_DESC then
                local InsertService = game:GetService("InsertService")
                local origIds = {
                    AC_ORIGINAL_DESC.Shirt,
                    AC_ORIGINAL_DESC.Pants,
                    AC_ORIGINAL_DESC.GraphicTShirt,
                }
                for _, aid in ipairs(origIds) do
                    if aid and aid ~= 0 then
                        pcall(function()
                            local model = LoadAssetLocal(aid)
                            if model then
                                for _, child in ipairs(model:GetChildren()) do
                                    if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
                                        for _, ex in ipairs(char:GetChildren()) do
                                            if ex:IsA(child.ClassName) then ex:Destroy() end
                                        end
                                        child.Parent = char
                                    end
                                end
                                model:Destroy()
                            end
                        end)
                    end
                end
            end
        end
        clothes_setStatus("Clothes reset to original!", Color3.fromRGB(145,145,145))
        AC_CLOTHES_APPLIED = {}
    end)

end

local optionsCreated = {false, false, false, false, false, false}

local function createPage1Options()
    local creditsHeader = makeUI(optionsFrame, "Frame", {
        Size = UDim2.new(0.95, 0, 0, 22),
        BackgroundTransparency = 1, BorderSizePixel = 0
    })
    makeUI(creditsHeader, "TextLabel", {
        Text = "Scripter kkkkkk",
        Font = Enum.Font.GothamBold,
        TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 12,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        TextXAlignment = Enum.TextXAlignment.Center
    })
    createToggleOption("ZeroMultiFling", "Zero Extension", function(state)
        ZeroMultiFlingEnabled = state
        if ZeroMultiFlingOpenBtn then
            ZeroMultiFlingOpenBtn.Visible = state
        end
        if state then
            currentPage_MF = 1
            pcall(updateMFDots)
            if mfPageContainer then
                mfPageContainer.Position = UDim2.new(0, 0, 0, 0)
            end
        end
    end)
    createToggleOption("InfiniteJump", "Infinite Jump", function(state) infinityJump(state) end)
    -- EmoteList diisi async, createDropdown pakai referensi langsung
    -- agar saat dropdown dibuka, data sudah tersedia
    createDropdown("Emotes", EmoteList, function(selectedEmote)
    end)
    -- Setelah JSON loaded, options di dalam createDropdown merujuk ke
    -- EmoteList yang sama (table reference), jadi renderCards() otomatis
    -- membaca data terbaru saat dropdown dibuka.

    do
        -- ============================================================
        -- TELEPORT TO PLAYER — Card Style Dropdown
        -- Card: avatar thumbnail kiri | DisplayName | @Username | team
        -- ============================================================
        local tpSelectedPlayer = nil
        local tpSelectedLabel, tpArrow
        local tpCardRefs    = {}   -- { card, player }
        local TP_CARD_H     = 62
        local TP_CARD_PAD   = 5
        local TP_MAX_VIS    = 4

        local tpContainer = makeUI(optionsFrame, "Frame", {
            Size = UDim2.new(0.95, 0, 0, 62),
            BackgroundColor3 = Color3.fromRGB(40, 40, 40),
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0, ClipsDescendants = false
        })
        makeUI(tpContainer, "UICorner", {CornerRadius = UDim.new(0, 8)})
        makeUI(tpContainer, "TextLabel", {
            Text = "Teleport to Player", Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 11,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -12, 0, 18),
            Position = UDim2.new(0, 8, 0, 4),
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        -- Dropdown button bar (Select Player + arrow)
        local tpDropBtnFrame = makeUI(tpContainer, "Frame", {
            Size = UDim2.new(1, -76, 0, 26),
            Position = UDim2.new(0, 6, 0, 28),
            BackgroundColor3 = Color3.fromRGB(40, 40, 40),
            BackgroundTransparency = 0.2, BorderSizePixel = 0
        })
        makeUI(tpDropBtnFrame, "UICorner", {CornerRadius = UDim.new(0, 6)})
        makeUI(tpDropBtnFrame, "UIStroke", {Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.4})
        tpSelectedLabel = makeUI(tpDropBtnFrame, "TextLabel", {
            Text = "Select Player...", Font = Enum.Font.Gotham,
            TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 10,
            BackgroundTransparency = 1, Size = UDim2.new(0.8, 0, 1, 0),
            Position = UDim2.new(0.04, 0, 0, 0), TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd
        })
        tpArrow = makeUI(tpDropBtnFrame, "TextLabel", {
            Text = "▼", Font = Enum.Font.GothamBold,
            TextColor3 = Color3.fromRGB(200, 200, 200), TextSize = 10,
            BackgroundTransparency = 1, Size = UDim2.new(0, 20, 1, 0),
            Position = UDim2.new(1, -22, 0, 0), TextXAlignment = Enum.TextXAlignment.Center
        })
        local tpClickBtn = makeUI(tpDropBtnFrame, "TextButton", {
            Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
            BorderSizePixel = 0, AutoButtonColor = false, Text = ""
        })

        -- Go! button (kanan)
        local tpGoBtn = makeUI(tpContainer, "TextButton", {
            Size = UDim2.new(0, 56, 0, 26),
            Position = UDim2.new(1, -62, 0, 28),
            BackgroundColor3 = Color3.fromRGB(80, 80, 80),
            Text = "Go!", TextColor3 = Color3.fromRGB(255, 255, 255),
            Font = Enum.Font.GothamBold, TextSize = 10,
            BorderSizePixel = 0
        })
        makeUI(tpGoBtn, "UICorner", {CornerRadius = UDim.new(0, 6)})

        -- Outer dropdown frame
        local tpListWidth  = UDim2.new(1, -12, 0, 0)
        local tpOuterFrame = makeUI(tpContainer, "Frame", {
            Size = tpListWidth,
            Position = UDim2.new(0, 6, 1, 4),
            BackgroundColor3 = Color3.fromRGB(32, 32, 32),
            BorderSizePixel = 0,
            Visible = false, ZIndex = 20,
            ClipsDescendants = true
        })
        makeUI(tpOuterFrame, "UICorner", {CornerRadius = UDim.new(0, 6)})
        makeUI(tpOuterFrame, "UIStroke", {Color = Color3.fromRGB(70, 70, 70), Thickness = 1, Transparency = 0.5})

        -- ScrollingFrame untuk card-card player
        local tpScrollList = makeUI(tpOuterFrame, "ScrollingFrame", {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100),
            ZIndex = 20, CanvasSize = UDim2.new(0, 0, 0, 0),
            ScrollingDirection = Enum.ScrollingDirection.Y,
            ClipsDescendants = true
        })
        local tpListLayout = makeUI(tpScrollList, "UIListLayout", {
            Padding = UDim.new(0, TP_CARD_PAD),
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder
        })
        makeUI(tpScrollList, "UIPadding", {PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5)})
        tpListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            tpScrollList.CanvasSize = UDim2.new(0, 0, 0, tpListLayout.AbsoluteContentSize.Y + 10)
        end)

        local tpEmptyLabel = makeUI(tpScrollList, "TextLabel", {
            Size = UDim2.new(0.96, 0, 0, TP_CARD_H),
            BackgroundTransparency = 1,
            Text = "No players found",
            TextColor3 = Color3.fromRGB(130, 130, 130),
            Font = Enum.Font.Gotham, TextSize = 10,
            BorderSizePixel = 0, ZIndex = 21,
            Visible = false, LayoutOrder = 1
        })

        local tpIsOpen = false

        local function tpCloseDropdown()
            tpIsOpen = false
            TweenService:Create(tpArrow, TweenInfo.new(0.2), {Rotation = 0}):Play()
            TweenService:Create(tpOuterFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
                {Size = tpListWidth}):Play()
            task.delay(0.19, function()
                tpOuterFrame.Visible = false
                tpOuterFrame.Size = tpListWidth
            end)
        end

        -- Buat satu player card
        local function makeTpCard(player, layoutOrder)
            local userId   = player.UserId
            local thumbRbx = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(userId) .. "&w=150&h=150"

            local card = makeUI(tpScrollList, "Frame", {
                Size = UDim2.new(0.96, 0, 0, TP_CARD_H),
                BackgroundColor3 = Color3.fromRGB(28, 28, 28),
                BackgroundTransparency = 0.05,
                BorderSizePixel = 0, ZIndex = 21,
                LayoutOrder = layoutOrder
            })
            makeUI(card, "UICorner", {CornerRadius = UDim.new(0, 10)})
            makeUI(card, "UIStroke", {Color = Color3.fromRGB(55,55,55), Thickness = 1, Transparency = 0.3, ZIndex = 22})

            -- Avatar headshot bulat kiri
            -- Teknik: ImageLabel sendiri yang di-round pakai UICorner,
            -- lalu frame luar hanya sebagai border ring
            local thumbRing = makeUI(card, "Frame", {
                Size = UDim2.new(0, 48, 0, 48),
                Position = UDim2.new(0, 7, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = Color3.fromRGB(80, 80, 80),
                BackgroundTransparency = 0.5,
                BorderSizePixel = 0, ZIndex = 22,
            })
            makeUI(thumbRing, "UICorner", {CornerRadius = UDim.new(1, 0)})

            -- ImageLabel bulat di dalam ring (2px inset)
            local thumbImg = makeUI(thumbRing, "ImageLabel", {
                Size = UDim2.new(0, 44, 0, 44),
                Position = UDim2.new(0.5, 0, 0.5, 0),
                AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = Color3.fromRGB(20, 20, 20),
                BackgroundTransparency = 0,
                Image = thumbRbx,
                ScaleType = Enum.ScaleType.Crop,
                ZIndex = 23,
                ClipsDescendants = true,
            })
            makeUI(thumbImg, "UICorner", {CornerRadius = UDim.new(1, 0)})

            -- DisplayName (putih bold) — tengah vertikal
            makeUI(card, "TextLabel", {
                Text = player.DisplayName,
                Font = Enum.Font.GothamBold,
                TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 12,
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 130, 0, 18),
                Position = UDim2.new(0, 62, 0.5, -14),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 22
            })

            -- @Username (biru)
            makeUI(card, "TextLabel", {
                Text = "@" .. player.Name,
                Font = Enum.Font.Gotham,
                TextColor3 = Color3.fromRGB(80, 160, 255), TextSize = 10,
                BackgroundTransparency = 1,
                Size = UDim2.new(0, 130, 0, 14),
                Position = UDim2.new(0, 62, 0.5, 6),
                TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 22
            })

            -- Hitbox klik
            local hitbox = makeUI(card, "TextButton", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1, BorderSizePixel = 0,
                AutoButtonColor = false, Text = "", ZIndex = 24
            })

            local isSelected = (tpSelectedPlayer == player)

            local function setSelected(sel)
                TweenService:Create(card, TweenInfo.new(0.15), {
                    BackgroundColor3 = sel and Color3.fromRGB(20, 60, 30) or Color3.fromRGB(28, 28, 28),
                    BackgroundTransparency = sel and 0 or 0.05
                }):Play()
            end

            if isSelected then setSelected(true) end

            hitbox.MouseEnter:Connect(function()
                if tpSelectedPlayer ~= player then
                    TweenService:Create(card, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(40, 40, 40)}):Play()
                end
            end)
            hitbox.MouseLeave:Connect(function()
                if tpSelectedPlayer ~= player then
                    TweenService:Create(card, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(28, 28, 28)}):Play()
                end
            end)
            hitbox.MouseButton1Click:Connect(function()
                tpSelectedPlayer = player
                tpSelectedLabel.Text = player.DisplayName .. " (@" .. player.Name .. ")"
                tpSelectedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
                -- reset semua card
                for _, ref in ipairs(tpCardRefs) do
                    TweenService:Create(ref.card, TweenInfo.new(0.15), {
                        BackgroundColor3 = Color3.fromRGB(28,28,28),
                        BackgroundTransparency = 0.05
                    }):Play()
                end
                setSelected(true)
                tpCloseDropdown()
            end)

            return card
        end

        -- Rebuild daftar card saat dropdown dibuka
        local function tpRebuildList()
            for _, ref in ipairs(tpCardRefs) do
                if ref.card and ref.card.Parent then ref.card:Destroy() end
            end
            tpCardRefs = {}

            local playerList = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then table.insert(playerList, p) end
            end

            if #playerList == 0 then
                tpEmptyLabel.Visible = true
                return 1
            end
            tpEmptyLabel.Visible = false

            for i, p in ipairs(playerList) do
                local card = makeTpCard(p, i + 1)
                table.insert(tpCardRefs, {card = card, player = p})
            end

            return #playerList
        end

        tpClickBtn.MouseButton1Click:Connect(function()
            tpIsOpen = not tpIsOpen
            if tpIsOpen then
                local count = tpRebuildList()
                local visCount = math.min(count, TP_MAX_VIS)
                local targetH  = visCount * TP_CARD_H + math.max(visCount - 1, 0) * TP_CARD_PAD + 10
                tpOuterFrame.Size    = tpListWidth
                tpOuterFrame.Visible = true
                TweenService:Create(tpArrow, TweenInfo.new(0.2), {Rotation = 180}):Play()
                TweenService:Create(tpOuterFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                    {Size = UDim2.new(1, -12, 0, targetH)}):Play()
            else
                tpCloseDropdown()
            end
        end)

        -- Teleport logic (sama seperti sebelumnya)
        tpGoBtn.MouseButton1Click:Connect(function()
            if not tpSelectedPlayer then return end
            local char       = LocalPlayer.Character
            local humanoid   = char and char:FindFirstChildOfClass("Humanoid")
            local myHRP      = humanoid and humanoid.RootPart
            local targetChar = tpSelectedPlayer.Character
            if not char or not humanoid or not myHRP or not targetChar then return end

            local THumanoid = targetChar:FindFirstChildOfClass("Humanoid")
            local TRootPart = THumanoid and THumanoid.RootPart
            local THead     = targetChar:FindFirstChild("Head")
            local Accessory = targetChar:FindFirstChildOfClass("Accessory")
            local Handle    = Accessory and Accessory:FindFirstChild("Handle")
            local BasePart  = TRootPart or THead or Handle
            if not BasePart then return end

            pcall(function()
                local destCF = CFrame.new(BasePart.Position) * CFrame.new(0, 0, 3)
                myHRP.CFrame = destCF
                char:SetPrimaryPartCFrame(destCF)
            end)

            TweenService:Create(tpGoBtn, TweenInfo.new(0.07), {BackgroundColor3 = Color3.fromRGB(27, 100, 27)}):Play()
            task.delay(0.5, function()
                TweenService:Create(tpGoBtn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(80, 80, 80)}):Play()
            end)
        end)
    end

    createSlider("WalkSpeed", 16, 200, 16, 1, function(value)
        currentWalkSpeed = value
        if LocalPlayer.Character then applyWalkSpeed(LocalPlayer.Character, value) end
        if value > 16 then
            if not SpeedEffect.enabled then
                setupSpeedEffect()
            end
        else
            cleanupSpeedEffect()
        end
    end)
    createSlider("JumpPower", 50, 300, 50, 1, function(value)
        currentJumpPower = value
        if LocalPlayer.Character then applyJumpPower(LocalPlayer.Character, value) end
    end)
    createToggleOption("Noclip", "Noclip", function(state) noclip(state) end)
    createToggleOption("GodMode", "God Mode", function(state) godMode(state) end)
    createToggleOption("Flying", "Flying Mode", function(state) fly(state) end)
    createToggleOption("AntiKick", "Anti-Kick", function(state) antiKick(state) end)
    createToggleOption("NameESP", "Name ESP", function(state) nameEsp(state) end)
    createToggleOption("CheckpointESP", "Checkpoint ESP", function(state) espCheckpoint(state) end)
    createToggleOption("Invisible", "Invisible", function(state) invisible(state) end)
    createToggleOption("AntiLag", "Anti-Lag", function(state) antiLag(state) end)
    createTextBox("SpyPlayer", "Username/Display", function(text) spy(text) end, true)
end

local _minimizeDebounce = false

local function toggleMinimize()
    if _minimizeDebounce then return end
    _minimizeDebounce = true

    if isMinimized then
        isMinimized = false
        minimizeButton.Text = "-"
        uiBlur.Enabled = true

        -- Halaman sudah di-preload di background saat startup.
        -- Fallback: buat secara sinkron hanya jika preload belum selesai.
        if not optionsCreated[1] then createPage1Options(); optionsCreated[1] = true end
        if not optionsCreated[2] then createAvatarChangerPage(); optionsCreated[2] = true end
        if not optionsCreated[3] then createAccessoriesPage(); optionsCreated[3] = true end
        if not optionsCreated[4] then createClothesPage(); optionsCreated[4] = true end
        if not optionsCreated[5] then createAnimationChangerPage(); optionsCreated[5] = true end
        if not optionsCreated[6] then createMusicPlayerPage(); optionsCreated[6] = true end

        optionsFrame.Visible = true
        optionsFrame2.Visible = true
        optionsFrame3.Visible = true
        optionsFrame4.Visible = true
        optionsFrame5.Visible = true
        optionsFrame6.Visible = true

        local maxSize = UDim2.new(0, 265, 0, UI_HEIGHT)
        local tw1 = TweenService:Create(mainFrame, tweenInfo, {Size = maxSize})
        local tw2 = TweenService:Create(shadow, tweenInfo, {Size = maxSize, ImageTransparency = 0.6})
        local tw3 = TweenService:Create(stroke, tweenInfo, {Transparency = 0, Thickness = 1.8})
        tw1:Play(); tw2:Play(); tw3:Play()
        tw1.Completed:Wait()
    else
        isMinimized = true
        minimizeButton.Text = "+"
        uiBlur.Enabled = false
        optionsFrame.Visible = false
        optionsFrame2.Visible = false
        optionsFrame3.Visible = false
        optionsFrame4.Visible = false
        optionsFrame5.Visible = false
        optionsFrame6.Visible = false

        local tw1 = TweenService:Create(mainFrame, tweenInfo, {Size = minimizedSize})
        local tw2 = TweenService:Create(shadow, tweenInfo, {Size = minimizedSize, ImageTransparency = 0.75})
        local tw3 = TweenService:Create(stroke, tweenInfo, {Transparency = 0.2, Thickness = 1.2})
        tw1:Play(); tw2:Play(); tw3:Play()
        tw1.Completed:Wait()
    end

    task.wait(0.05)
    _minimizeDebounce = false
end
minimizeButton.MouseButton1Click:Connect(toggleMinimize)

-- ============================================================
-- OPTIMASI: Preload semua halaman di background saat startup
-- Setiap halaman dibuat satu per satu dengan yield task.wait()
-- agar tidak memblokir main thread sekaligus.
-- Hasilnya: saat tombol diklik pertama kali, semua halaman
-- sudah siap → UI langsung terbuka tanpa lag/freeze.
-- ============================================================
task.spawn(function()
    task.wait(1.0) -- tunggu script selesai init + karakter load
    if not optionsCreated[1] then
        pcall(createPage1Options)
        optionsCreated[1] = true
        task.wait()
    end
    if not optionsCreated[2] then
        pcall(createAvatarChangerPage)
        optionsCreated[2] = true
        task.wait()
    end
    if not optionsCreated[3] then
        pcall(createAccessoriesPage)
        optionsCreated[3] = true
        task.wait()
    end
    if not optionsCreated[4] then
        pcall(createClothesPage)
        optionsCreated[4] = true
        task.wait()
    end
    if not optionsCreated[5] then
        pcall(createAnimationChangerPage)
        optionsCreated[5] = true
        task.wait()
    end
    if not optionsCreated[6] then
        pcall(createMusicPlayerPage)
        optionsCreated[6] = true
    end
end)

isMinimized = true
minimizeButton.Text = "+"
uiBlur.Enabled = false
optionsFrame.Visible = false
optionsFrame2.Visible = false
optionsFrame3.Visible = false
optionsFrame4.Visible = false
optionsFrame5.Visible = false
optionsFrame6.Visible = false
mainFrame.Size = minimizedSize
shadow.Size = minimizedSize
shadow.ImageTransparency = 0.75
stroke.Transparency = 0.2
stroke.Thickness = 1.2

updateDots()

task.wait(0.1)
screenGui.Enabled = true
mainFrame.Visible = true

local CoreGui = game:GetService("CoreGui")
local function protectGui(gui)
    if not gui then return end
    gui.AncestryChanged:Connect(function(_, parent)
        if not parent then
            task.wait(0.02)
            pcall(function() gui.Parent = CoreGui end)
        end
    end)
end
protectGui(screenGui)
protectGui(espScreenGui)
protectGui(spyHudGui)
protectGui(spyControlGui)
protectGui(CheckpointGui)

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            if screenGui and not screenGui:IsDescendantOf(CoreGui) then screenGui.Parent = CoreGui end
            if espScreenGui and not espScreenGui:IsDescendantOf(CoreGui) then espScreenGui.Parent = CoreGui end
            if spyHudGui and not spyHudGui:IsDescendantOf(CoreGui) then spyHudGui.Parent = CoreGui end
            if spyControlGui and not spyControlGui:IsDescendantOf(CoreGui) then spyControlGui.Parent = CoreGui end
            if CheckpointGui and not CheckpointGui:IsDescendantOf(CoreGui) then CheckpointGui.Parent = CoreGui end
        end)
    end
end)

LocalPlayer.CharacterAdded:Connect(function(character)
    character:WaitForChild("HumanoidRootPart", 10)
    character:WaitForChild("Humanoid", 10)
    task.wait(0.3)

    applyWalkSpeed(character, currentWalkSpeed)
    applyJumpPower(character, currentJumpPower)

    if currentWalkSpeed > 16 then
        cleanupSpeedEffect()
        task.wait(0.2)
        setupSpeedEffect()
    end
    if NoclipEnabled then noclip(true) end
    if InfiniteJumpEnabled then infinityJump(true) end
    if GodModeEnabled then
        local humanoid = character:WaitForChild("Humanoid", 5)
        local hrp = character:WaitForChild("HumanoidRootPart", 5)
        if humanoid and hrp then task.wait(0.2); setupGodMode(character) end
    end
    if FlyEnabled then task.wait(0.2); fly(true) end
    if AntiKickEnabled then antiKick(true) end
    if NameEspEnabled then nameEsp(true) end
    if InvisibleEnabled then invisible(true) end
    if AntiLagEnabled then antiLag(true) end
    if CheckpointEspEnabled then espCheckpoint(true) end
    stopCurrentAnimation()
    local HUM = character:FindFirstChild("Humanoid")
    if HUM and not AC_ORIGINAL_DESC then
        task.wait(0.5)
        AC_ORIGINAL_DESC = HUM:GetAppliedDescription()
    end

    local hasAcc = false
    for _ in pairs(AC_ACCESSORY_APPLIED) do hasAcc = true; break end
    if hasAcc then
        task.spawn(function()
            task.wait(1.0)
            local hum = character:FindFirstChildOfClass("Humanoid")
            if not hum then return end

            if hasAcc then
                local desc = hum:GetAppliedDescription()
                local InsertService = game:GetService("InsertService")

                local allSlots = {
                    "HatAccessory", "HairAccessory", "FaceAccessory", "NeckAccessory",
                    "BackAccessory", "WaistAccessory", "ShouldersAccessory", "FrontAccessory"
                }

                for _, prop in ipairs(allSlots) do
                    local appliedVal = AC_ACCESSORY_APPLIED[prop]
                    if appliedVal ~= nil and tostring(appliedVal) ~= "" then
                        pcall(function() desc[prop] = appliedVal end)
                    elseif AC_ORIGINAL_DESC and (tostring(desc[prop] or "") == "") then
                        pcall(function() desc[prop] = AC_ORIGINAL_DESC[prop] end)
                    end
                end

                for prop, _ in pairs(AC_ACCESSORY_APPLIED) do
                    local slotType = ({
                        HatAccessory       = {Enum.AccessoryType.Hat},
                        HairAccessory      = {Enum.AccessoryType.Hair},
                        FaceAccessory      = {Enum.AccessoryType.Face},
                        NeckAccessory      = {Enum.AccessoryType.Neck},
                        BackAccessory      = {Enum.AccessoryType.Back},
                        WaistAccessory     = {Enum.AccessoryType.Waist},
                        ShouldersAccessory = {Enum.AccessoryType.Shoulder},
                        FrontAccessory     = {Enum.AccessoryType.Front},
                    })[prop]
                    if slotType then
                        for _, obj in ipairs(character:GetChildren()) do
                            if obj:IsA("Accessory") or obj:IsA("Hat") then
                                for _, t in ipairs(slotType) do
                                    if obj.AccessoryType == t then
                                        pcall(function() obj:Destroy() end); break
                                    end
                                end
                            end
                        end
                    end
                end

                startPositionLock(character, 2.5)
                task.wait(0.3)

                -- Load semua aksesori via InsertService (termasuk hair)
                local hairIds = {}
                for prop, ids in pairs(AC_ACCESSORY_APPLIED) do
                    for idStr in tostring(ids):gmatch("[^,]+") do
                        local aid = tonumber(idStr:match("^%s*(.-)%s*$"))
                        if aid and aid ~= 0 then
                            if prop == "HairAccessory" then
                                table.insert(hairIds, aid)
                            else
                                pcall(function()
                                    local model = LoadAssetLocal(aid)
                                    if model then
                                        for _, child in ipairs(model:GetChildren()) do
                                            if child:IsA("Accessory") or child:IsA("Hat") then
                                                local dup = character:FindFirstChild(child.Name)
                                                if dup and (dup:IsA("Accessory") or dup:IsA("Hat")) then
                                                    dup:Destroy()
                                                end
                                                AttachAccessoryLocal(character, child)
                                            end
                                        end
                                        model:Destroy()
                                    end
                                end)
                            end
                        end
                    end
                end

                -- Load hair terakhir setelah aksesori lain, dengan tambahan delay
                if #hairIds > 0 then
                    task.wait(0.3)
                    -- Hapus semua hair lama sebelum load baru
                    for _, obj in ipairs(character:GetChildren()) do
                        if (obj:IsA("Accessory") or obj:IsA("Hat")) then
                            if obj.AccessoryType == Enum.AccessoryType.Hair
                                or obj.AccessoryType == Enum.AccessoryType.Unknown then
                                pcall(function() obj:Destroy() end)
                            end
                        end
                    end
                    task.wait(0.1)
                    for _, aid in ipairs(hairIds) do
                        pcall(function()
                            local model = LoadAssetLocal(aid)
                            if model then
                                for _, child in ipairs(model:GetChildren()) do
                                    if child:IsA("Accessory") or child:IsA("Hat") then
                                        local dup = character:FindFirstChild(child.Name)
                                        if dup and (dup:IsA("Accessory") or dup:IsA("Hat")) then
                                            dup:Destroy()
                                        end
                                        AttachAccessoryLocal(character, child)
                                    end
                                end
                                model:Destroy()
                            end
                        end)
                    end
                end
            end

            if next(AC_ACCESSORY_TRANSFORMS) then
                task.wait(0.5)
                local function reApplyTransform(obj, t)
                    local handle = obj:FindFirstChild("Handle")
                    if not handle then return end
                    local cf = CFrame.new(
                        t.px, t.py, t.pz,
                        t.r00, t.r01, t.r02,
                        t.r10, t.r11, t.r12,
                        t.r20, t.r21, t.r22
                    )
                    local weld = handle:FindFirstChildOfClass("Weld") or handle:FindFirstChild("AccessoryWeld")
                    if not weld then
                        for _, c in ipairs(handle:GetChildren()) do
                            if c:IsA("Weld") then weld = c; break end
                        end
                    end
                    pcall(function()
                        if weld and weld.Parent then
                            weld.C0 = cf
                        else
                            handle.CFrame = cf
                        end
                    end)
                end
                for _, obj in ipairs(character:GetChildren()) do
                    if (obj:IsA("Accessory") or obj:IsA("Hat")) then
                        local t = AC_ACCESSORY_TRANSFORMS[obj.Name]
                        if t then reApplyTransform(obj, t) end
                    end
                end
                task.wait(0.3)
                for _, obj in ipairs(character:GetChildren()) do
                    if (obj:IsA("Accessory") or obj:IsA("Hat")) then
                        local t = AC_ACCESSORY_TRANSFORMS[obj.Name]
                        if t then reApplyTransform(obj, t) end
                    end
                end
            end

        end)
    end

    if AC_HEAD_APPLIED then
        task.spawn(function()
            task.wait(2.0)
            local headPart = character:FindFirstChild("Head")
            if not headPart then return end
            local isDynamic = headPart:IsA("MeshPart") or headPart:FindFirstChildOfClass("FaceControls") ~= nil
            local ok_get, objs = pcall(function()
                return game:GetObjects("rbxassetid://" .. tostring(AC_HEAD_APPLIED))
            end)
            local function deepFind(root, className)
                if root:IsA(className) then return root end
                for _, d in ipairs(root:GetDescendants()) do
                    if d:IsA(className) then return d end
                end
                return nil
            end
            local srcMeshPart, srcPart, srcSpecialMesh = nil, nil, nil
            if ok_get and objs and #objs > 0 then
                for _, obj in ipairs(objs) do
                    if not srcMeshPart    then srcMeshPart    = deepFind(obj, "MeshPart")    end
                    if not srcPart        then srcPart        = deepFind(obj, "Part")        end
                    if not srcSpecialMesh then srcSpecialMesh = deepFind(obj, "SpecialMesh") end
                end
                if srcPart and srcPart:FindFirstChildOfClass("SpecialMesh") then
                    srcSpecialMesh = srcPart:FindFirstChildOfClass("SpecialMesh")
                end
            end
            local function applyMesh(meshId, texId, srcRef)
                if meshId == "" then meshId = "rbxassetid://" .. tostring(AC_HEAD_APPLIED) end
                if isDynamic then
                    pcall(function() headPart.MeshId    = meshId end)
                    pcall(function() headPart.TextureID = texId  end)
                else
                    for _, m in ipairs(headPart:GetChildren()) do
                        if m:IsA("SpecialMesh") then pcall(function() m:Destroy() end) end
                    end
                    local sm = Instance.new("SpecialMesh")
                    sm.MeshType  = Enum.MeshType.FileMesh
                    sm.MeshId    = meshId
                    sm.TextureId = texId
                    sm.Scale     = Vector3.new(1,1,1)
                    sm.Parent    = headPart
                end
                if srcRef then
                    pcall(function() headPart.Color    = srcRef.Color    end)
                    pcall(function() headPart.Material = srcRef.Material end)
                end
            end
            if srcMeshPart then
                applyMesh(srcMeshPart.MeshId or "", srcMeshPart.TextureID or "", srcMeshPart)
            elseif srcSpecialMesh then
                applyMesh(srcSpecialMesh.MeshId or "", srcSpecialMesh.TextureId or "", srcPart)
            else
                applyMesh("", "", nil)
            end
        end)
    end

    local hasClothes = false
    for _ in pairs(AC_CLOTHES_APPLIED) do hasClothes = true; break end
    if hasClothes then
        task.spawn(function()
            task.wait(1.2)
            local hum = character:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            local InsertService = game:GetService("InsertService")
            local desc = hum:GetAppliedDescription()
            for prop, assetId in pairs(AC_CLOTHES_APPLIED) do
                pcall(function() desc[prop] = assetId end)
            end
            startPositionLock(character, 2.5)
            task.wait(0.15)
            for _, assetId in pairs(AC_CLOTHES_APPLIED) do
                if assetId and assetId ~= 0 then
                    pcall(function()
                        local model = LoadAssetLocal(assetId)
                        if model then
                            for _, child in ipairs(model:GetChildren()) do
                                if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
                                    for _, existing in ipairs(character:GetChildren()) do
                                        if existing:IsA(child.ClassName) then existing:Destroy() end
                                    end
                                    child.Parent = character
                                end
                            end
                            model:Destroy()
                        end
                    end)
                end
            end
        end)
    end

    if animChangerEnabled and AC_ANIM_PRESET_APPLIED then
        task.spawn(function()
            task.wait(0.5)
            fetchAndApplyBundle(AC_ANIM_PRESET_APPLIED, function() end)
        end)
    elseif animChangerEnabled then
        task.spawn(function()
            task.wait(0.5)
            applyAllCustomIds(function() end)
        end)
    end
end)

LocalPlayer.CharacterRemoving:Connect(function(character)
    if NoclipEnabled then noclip(false) end
    if InfiniteJumpEnabled then infinityJump(false) end
    if GodModeEnabled then clearGodModeConnections() end
    if FlyEnabled then fly(false) end
    if AntiKickEnabled then antiKick(false) end
    if InvisibleEnabled then invisible(false) end
    cleanupInvisSeat()
    cleanupSpeedEffect()
    SpeedEffect.enabled = false
    if NameTags[LocalPlayer.UserId] then
        NameTags[LocalPlayer.UserId] = nil
    end
    stopCurrentAnimation()
end)

end)()

;(function()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local HttpService = game:GetService("HttpService")
local Player = Players.LocalPlayer

local SelectedTargets = {}
local WhitelistedUsers = {}
local FlingActive = false
local TouchFlingActive = false
local SmartFlingEnabled = false
local AutoFlingAllEnabled = false
getgenv().OldPos = nil
getgenv().FPDH = workspace.FallenPartsDestroyHeight

local UI_ToggleKey = Enum.KeyCode.RightControl
local FlingKeybind = Enum.KeyCode.E
local SettingKey = false
getgenv().UI_COLOR = Color3.fromRGB(255, 65, 65)
local SearchText = ""
local ReturnMode = "Original"
local ManualPos = nil
local NameDisplayMode = "Both"

local function makeUI(parent, class, props)
    local obj = Instance.new(class)
    for k, v in pairs(props) do obj[k] = v end
    obj.Parent = parent
    return obj
end

local ScreenGui = makeUI(game:GetService("CoreGui"), "ScreenGui", {
    DisplayOrder = 10,
    Name = "KilasikProFling",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    AutoLocalize = false,
})

ZeroMultiFlingOpenBtn = nil
local OpenBtn = makeUI(ScreenGui, "TextButton", {
    Size = UDim2.new(0, 42, 0, 42),
    Position = UDim2.new(0, 16, 0, 400),
    BackgroundTransparency = 1,
    Text = "",
    BorderSizePixel = 0,
    Visible = false,
    AutoButtonColor = false,
    ZIndex = 9,
})
local OpenBtnBubble = makeUI(OpenBtn, "Frame", {
    Size = UDim2.new(1, 0, 1, 0),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BackgroundTransparency = 0.45,
    BorderSizePixel = 0,
    ZIndex = 9,
})
makeUI(OpenBtnBubble, "UICorner", {CornerRadius = UDim.new(1, 0)})
local OpenBtnIcon = makeUI(OpenBtn, "ImageLabel", {
    Size = UDim2.new(0, 42, 0, 42),
    Position = UDim2.new(0, 0, 0, 0),
    BackgroundTransparency = 1,
    Image = "rbxthumb://type=Asset&id=88426174810609&w=420&h=420",
    ScaleType = Enum.ScaleType.Fit,
    ZIndex = 11,
})
ZeroMultiFlingOpenBtn = OpenBtn

-- ============================================================
-- OPTIMASI: Preload asset gambar di background agar tidak ada
-- jeda loading saat pertama kali UI ditampilkan.
-- ============================================================
task.spawn(function()
    local ContentProvider = game:GetService("ContentProvider")
    local assets = {}
    local imgIds = {
        "rbxthumb://type=Asset&id=88426174810609&w=420&h=420", -- OpenBtn icon
        "rbxassetid://5028857084",                              -- shadow frame
    }
    for _, id in ipairs(imgIds) do
        local img = Instance.new("ImageLabel")
        img.Image = id
        table.insert(assets, img)
    end
    pcall(function() ContentProvider:PreloadAsync(assets) end)
    for _, img in ipairs(assets) do img:Destroy() end
end)

local bubbleSavedX = 0
local bubbleSavedY = 0

local UI_WIDTH      = 265
local UI_HEIGHT     = 300
local minimizedSize = UDim2.new(0, UI_WIDTH, 0, 28)
local expandedSize  = UDim2.new(0, UI_WIDTH, 0, UI_HEIGHT)
local tweenInfo     = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local isMinimized   = false

local currentPage_MF = 1
local totalPages_MF  = 4
local pageTitles_MF  = {"Zero Catalog Searcher", "Zero Multi Fling", "Zero Server Hop", "Zero Purchase"}

local MainFrame = makeUI(ScreenGui, "Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = expandedSize,
    BackgroundColor3 = Color3.fromRGB(30, 30, 30),
    BackgroundTransparency = 0.3,
    BorderSizePixel = 0,
    Active = true,
    ClipsDescendants = false,
})
makeUI(MainFrame, "UICorner", {CornerRadius = UDim.new(0, 12)})

local shadow = makeUI(MainFrame, "ImageLabel", {
    BackgroundTransparency = 1,
    Image = "rbxassetid://5028857084",
    ImageTransparency = 0.75,
    ScaleType = Enum.ScaleType.Slice,
    SliceCenter = Rect.new(24, 24, 276, 276),
    Size = UDim2.new(1, 0, 1, 0),
    ZIndex = -1,
})

local baseStroke = makeUI(MainFrame, "UIStroke", {
    Color = Color3.fromRGB(70, 70, 70),
    Thickness = 1.2,
    Transparency = 0.2,
})

local glowStroke = makeUI(MainFrame, "UIStroke", {
    Color = Color3.fromRGB(255, 255, 255),
    Thickness = 2.5,
    Transparency = 0,
    ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
})
local glowGradient = makeUI(glowStroke, "UIGradient", {
    Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 150, 150)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 50, 50)),
    },
    Rotation = 0,
})
local function animateGlowingBorder()
    local rotateTween = TweenService:Create(glowGradient,
        TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 0),
        {Rotation = 360}
    )
    task.spawn(function()
        while ScreenGui.Parent do
            local t1 = TweenService:Create(glowStroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Color = Color3.fromRGB(150,150,150)})
            t1:Play(); t1.Completed:Wait()
            local t2 = TweenService:Create(glowStroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Color = Color3.fromRGB(50,50,50)})
            t2:Play(); t2.Completed:Wait()
            local t3 = TweenService:Create(glowStroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Color = Color3.fromRGB(150,150,150)})
            t3:Play(); t3.Completed:Wait()
            local t4 = TweenService:Create(glowStroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Color = Color3.fromRGB(255,255,255)})
            t4:Play(); t4.Completed:Wait()
        end
    end)
    rotateTween:Play()
end
-- OPTIMASI: task.defer menunda eksekusi ke akhir frame saat ini,
-- memastikan semua Instance UI sudah selesai dibuat dulu,
-- dan loop tween tidak memblokir inisialisasi awal script.
task.defer(animateGlowingBorder)

local Header = makeUI(MainFrame, "Frame", {
    Size = UDim2.new(1, 0, 0, 28),
    BackgroundColor3 = Color3.fromRGB(20, 20, 20),
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 5,
})
makeUI(Header, "UICorner", {CornerRadius = UDim.new(0, 12)})

local titleLabelMF = makeUI(Header, "TextLabel", {
    Text = pageTitles_MF[1],
    Font = Enum.Font.GothamSemibold,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    TextSize = 12,
    BackgroundTransparency = 1,
    Size = UDim2.new(0.45, 0, 1, 0),
    Position = UDim2.new(0, 8, 0, 0),
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 6,
})

local minimizeBtn = makeUI(Header, "TextButton", {
    Text = "-",
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    TextColor3 = Color3.fromRGB(255, 255, 255),
    BackgroundTransparency = 0.3,
    BackgroundColor3 = Color3.fromRGB(50, 50, 50),
    Size = UDim2.new(0, 24, 0, 24),
    Position = UDim2.new(1, -4, 0.5, 0),
    AnchorPoint = Vector2.new(1, 0.5),
    ZIndex = 6,
})
makeUI(minimizeBtn, "UICorner", {CornerRadius = UDim.new(1, 0)})

local mfDotsFrame = makeUI(Header, "Frame", {
    Size = UDim2.new(0, 42, 0, 10),
    Position = UDim2.new(1, -32, 0.5, 0),
    AnchorPoint = Vector2.new(1, 0.5),
    BackgroundTransparency = 1,
    ZIndex = 6,
})
makeUI(mfDotsFrame, "UIListLayout", {
    FillDirection = Enum.FillDirection.Horizontal,
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
    VerticalAlignment = Enum.VerticalAlignment.Center,
    Padding = UDim.new(0, 4),
})
local mfDot1 = makeUI(mfDotsFrame, "Frame", {
    Size = UDim2.new(0, 7, 0, 7),
    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    BorderSizePixel = 0,
})
makeUI(mfDot1, "UICorner", {CornerRadius = UDim.new(1, 0)})
local mfDot2 = makeUI(mfDotsFrame, "Frame", {
    Size = UDim2.new(0, 7, 0, 7),
    BackgroundColor3 = Color3.fromRGB(80, 80, 80),
    BorderSizePixel = 0,
})
makeUI(mfDot2, "UICorner", {CornerRadius = UDim.new(1, 0)})
local mfDot3 = makeUI(mfDotsFrame, "Frame", {
    Size = UDim2.new(0, 7, 0, 7),
    BackgroundColor3 = Color3.fromRGB(80, 80, 80),
    BorderSizePixel = 0,
})
makeUI(mfDot3, "UICorner", {CornerRadius = UDim.new(1, 0)})
local mfDot4 = makeUI(mfDotsFrame, "Frame", {
    Size = UDim2.new(0, 7, 0, 7),
    BackgroundColor3 = Color3.fromRGB(80, 80, 80),
    BorderSizePixel = 0,
})
makeUI(mfDot4, "UICorner", {CornerRadius = UDim.new(1, 0)})

local function updateMFDots()
    local dots = {mfDot1, mfDot2, mfDot3, mfDot4}
    for i, dot in ipairs(dots) do
        TweenService:Create(dot, TweenInfo.new(0.2), {
            BackgroundColor3 = currentPage_MF == i and Color3.fromRGB(255,255,255) or Color3.fromRGB(80,80,80)
        }):Play()
    end
    titleLabelMF.Text = pageTitles_MF[currentPage_MF]
end

local ContentViewport = makeUI(MainFrame, "Frame", {
    Position = UDim2.new(0, 0, 0, 28),
    Size = UDim2.new(1, 0, 1, -28),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = true,
})

local mfPageContainer = makeUI(ContentViewport, "Frame", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(0, UI_WIDTH * 4, 1, 0),
    BackgroundTransparency = 1,
})

local function goToMFPage(pageNum)
    currentPage_MF = pageNum
    updateMFDots()
    local targetX = -(pageNum - 1) * UI_WIDTH
    TweenService:Create(mfPageContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Position = UDim2.new(0, targetX, 0, 0)
    }):Play()
end

local MFPage1 = makeUI(mfPageContainer, "Frame", {
    Position = UDim2.new(0, UI_WIDTH, 0, 0),
    Size = UDim2.new(0, UI_WIDTH, 1, 0),
    BackgroundTransparency = 1,
})

local StatusLabel = makeUI(MFPage1, "TextLabel", {
    Position = UDim2.new(0, 10, 0, 6),
    Size = UDim2.new(1, -20, 0, 16),
    BackgroundTransparency = 1,
    Text = "Fling system disengaged",
    TextColor3 = Color3.fromRGB(140, 140, 140),
    Font = Enum.Font.GothamSemibold,
    TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left,
})

local SearchBox = makeUI(MFPage1, "TextBox", {
    Size = UDim2.new(1, -16, 0, 26),
    Position = UDim2.new(0, 8, 0, 26),
    BackgroundColor3 = Color3.fromRGB(40, 40, 40),
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
    PlaceholderText = "Search players...",
    Text = "",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.Gotham,
    TextSize = 12,
    ClearTextOnFocus = false,
})
makeUI(SearchBox, "UICorner", {CornerRadius = UDim.new(0, 8)})
makeUI(SearchBox, "UIStroke", {Color = Color3.fromRGB(70,70,70), Thickness = 1, Transparency = 0.4})
SearchBox.Focused:Connect(function()
    TweenService:Create(SearchBox, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(55,55,55)}):Play()
end)
SearchBox.FocusLost:Connect(function()
    TweenService:Create(SearchBox, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40,40,40)}):Play()
end)

local PlayerSelection = makeUI(MFPage1, "ScrollingFrame", {
    Position = UDim2.new(0, 8, 0, 58),
    Size = UDim2.new(1, -16, 0, 75),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 6,
    ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
    ScrollingDirection = Enum.ScrollingDirection.Y,
})
local ListLayout = makeUI(PlayerSelection, "UIListLayout", {Padding = UDim.new(0, 5)})
makeUI(PlayerSelection, "UIPadding", {
    PaddingLeft = UDim.new(0,2), PaddingRight = UDim.new(0,4),
    PaddingTop = UDim.new(0,2), PaddingBottom = UDim.new(0,2),
})

local function MakeBtn(parent, text, pos, size, bgColor)
    local btn = makeUI(parent, "TextButton", {
        Text = text, Position = pos, Size = size,
        BackgroundColor3 = bgColor, BackgroundTransparency = 0.2,
        Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1,1,1),
        TextSize = 12, AutoButtonColor = false, BorderSizePixel = 0,
    })
    makeUI(btn, "UICorner", {CornerRadius = UDim.new(0, 8)})
    btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play() end)
    return btn
end

local StartBtn = MakeBtn(MFPage1, "START FLING",
    UDim2.new(0, 8, 0, 140), UDim2.new(0.5, -10, 0, 28),
    Color3.fromRGB(40, 130, 80))
local StopBtn = MakeBtn(MFPage1, "STOP FLING",
    UDim2.new(0.5, 2, 0, 140), UDim2.new(0.5, -10, 0, 28),
    Color3.fromRGB(160, 40, 40))

local ControlScroll = makeUI(MFPage1, "ScrollingFrame", {
    Position = UDim2.new(0, 8, 0, 174),
    Size = UDim2.new(1, -16, 1, -174),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 6,
    ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollingDirection = Enum.ScrollingDirection.Y,
})
local CtrlLayout = makeUI(ControlScroll, "UIListLayout", {Padding = UDim.new(0, 5)})
makeUI(ControlScroll, "UIPadding", {
    PaddingLeft = UDim.new(0,2), PaddingRight = UDim.new(0,10),
    PaddingTop = UDim.new(0,2), PaddingBottom = UDim.new(0,4),
})

local function MakeScrollBtn(text, bgColor)
    local btn = makeUI(ControlScroll, "TextButton", {
        Text = text, Size = UDim2.new(1, 0, 0, 26),
        BackgroundColor3 = bgColor, BackgroundTransparency = 0.2,
        Font = Enum.Font.GothamBold, TextColor3 = Color3.new(1,1,1),
        TextSize = 12, AutoButtonColor = false, BorderSizePixel = 0,
    })
    makeUI(btn, "UICorner", {CornerRadius = UDim.new(0, 8)})
    btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play() end)
    return btn
end

local SelectAllBtn      = MakeScrollBtn("SELECT ALL",            Color3.fromRGB(40,40,40))
local DeselectBtn       = MakeScrollBtn("DESELECT ALL",          Color3.fromRGB(40,40,40))
local FlingAllToggleBtn = MakeScrollBtn("FLING ALL: OFF",        Color3.fromRGB(30,30,30))
local TouchFlingBtn     = MakeScrollBtn("TOUCH FLING: OFF",      Color3.fromRGB(30,30,30))
local SmartFlingBtn     = MakeScrollBtn("SMART FLING: OFF",      Color3.fromRGB(30,30,30))
local ModeBtn           = MakeScrollBtn("RETURN MODE: ORIGINAL", Color3.fromRGB(30,30,30))
local ManualBtn         = MakeScrollBtn("SET MANUAL POSITION",   Color3.fromRGB(30,30,30))
ManualBtn.Visible = false

local function setToggleActive(btn, active)
    TweenService:Create(btn, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
        BackgroundColor3 = active and Color3.fromRGB(40,130,80) or Color3.fromRGB(30,30,30)
    }):Play()
end

local function UpdateControlCanvas()
    ControlScroll.CanvasSize = UDim2.new(0, 0, 0, CtrlLayout.AbsoluteContentSize.Y + 8)
end
CtrlLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(UpdateControlCanvas)

local MFPage2 = makeUI(mfPageContainer, "Frame", {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(0, UI_WIDTH, 1, 0),
    BackgroundTransparency = 1,
})

local catSearchBox = makeUI(MFPage2, "TextBox", {
    Size = UDim2.new(1, -70, 0, 26),
    Position = UDim2.new(0, 8, 0, 8),
    BackgroundColor3 = Color3.fromRGB(40, 40, 40),
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
    PlaceholderText = "Search catalog (hair, shirt...)",
    Text = "",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    PlaceholderColor3 = Color3.fromRGB(110, 110, 110),
    Font = Enum.Font.Gotham,
    TextSize = 11,
    ClearTextOnFocus = false,
})
makeUI(catSearchBox, "UICorner", {CornerRadius = UDim.new(0, 8)})
makeUI(catSearchBox, "UIStroke", {Color = Color3.fromRGB(70,70,70), Thickness = 1, Transparency = 0.4})
catSearchBox.Focused:Connect(function()
    TweenService:Create(catSearchBox, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(55,55,55)}):Play()
end)
catSearchBox.FocusLost:Connect(function()
    TweenService:Create(catSearchBox, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(40,40,40)}):Play()
end)

local catSearchBtn = makeUI(MFPage2, "TextButton", {
    Size = UDim2.new(0, 50, 0, 26),
    Position = UDim2.new(1, -58, 0, 8),
    BackgroundColor3 = Color3.fromRGB(60, 60, 60),
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
    Text = "GO",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    AutoButtonColor = false,
})
makeUI(catSearchBtn, "UICorner", {CornerRadius = UDim.new(0, 8)})
catSearchBtn.MouseEnter:Connect(function() TweenService:Create(catSearchBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play() end)
catSearchBtn.MouseLeave:Connect(function() TweenService:Create(catSearchBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play() end)

local catStatusLabel = makeUI(MFPage2, "TextLabel", {
    Size = UDim2.new(1, -16, 0, 14),
    Position = UDim2.new(0, 8, 0, 38),
    BackgroundTransparency = 1,
    Text = "Type a keyword and tap GO",
    TextColor3 = Color3.fromRGB(110, 110, 110),
    Font = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
})

local catScroll = makeUI(MFPage2, "ScrollingFrame", {
    Size = UDim2.new(1, -8, 1, -90),
    Position = UDim2.new(0, 4, 0, 55),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 5,
    ScrollBarImageColor3 = Color3.fromRGB(200, 200, 200),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollingDirection = Enum.ScrollingDirection.Y,
})
local catListLayout = makeUI(catScroll, "UIListLayout", {
    Padding = UDim.new(0, 5),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
})
makeUI(catScroll, "UIPadding", {
    PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3),
    PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2),
})
catListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    catScroll.CanvasSize = UDim2.new(0, 0, 0, catListLayout.AbsoluteContentSize.Y + 10)
end)

local catLoadMoreBtn = makeUI(MFPage2, "TextButton", {
    Size = UDim2.new(1, -16, 0, 24),
    Position = UDim2.new(0, 8, 1, -28),
    BackgroundColor3 = Color3.fromRGB(60, 60, 60),
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
    Text = "Load More",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    AutoButtonColor = false,
    Visible = false,
})
makeUI(catLoadMoreBtn, "UICorner", {CornerRadius = UDim.new(0, 8)})
catLoadMoreBtn.MouseEnter:Connect(function() TweenService:Create(catLoadMoreBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play() end)
catLoadMoreBtn.MouseLeave:Connect(function() TweenService:Create(catLoadMoreBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play() end)

local function httpGet(url)
    local ok, res = pcall(function()
        if request then return request({Url=url,Method="GET"}).Body
        elseif http_request then return http_request({Url=url,Method="GET"}).Body
        elseif syn and syn.request then return syn.request({Url=url,Method="GET"}).Body
        else return game:HttpGet(url) end
    end)
    return ok and res or nil
end

local function copyToClipboard(text)
    pcall(function()
        if setclipboard then setclipboard(text)
        elseif syn and syn.setclipboard then syn.setclipboard(text) end
    end)
end

local function createCatalogCard(item)
    local card = makeUI(catScroll, "Frame", {
        Size = UDim2.new(1, 0, 0, 56),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
    })
    makeUI(card, "UICorner", {CornerRadius = UDim.new(0, 8)})
    makeUI(card, "UIStroke", {Color = Color3.fromRGB(70,70,70), Thickness = 1, Transparency = 0.5})

    local thumb = makeUI(card, "ImageLabel", {
        Size = UDim2.new(0, 42, 0, 42),
        Position = UDim2.new(0, 6, 0.5, -21),
        BackgroundColor3 = Color3.fromRGB(25, 25, 25),
        BackgroundTransparency = 0.3,
        Image = "https://www.roblox.com/asset-thumbnail/image?assetId=" .. (item.id or 0) .. "&width=150&height=150&format=png",
        ScaleType = Enum.ScaleType.Fit,
    })
    makeUI(thumb, "UICorner", {CornerRadius = UDim.new(0, 6)})

    local nameLabel = makeUI(card, "TextLabel", {
        Size = UDim2.new(1, -118, 0, 18),
        Position = UDim2.new(0, 54, 0, 6),
        BackgroundTransparency = 1,
        Text = item.name or "Unknown",
        TextColor3 = Color3.fromRGB(240, 240, 240),
        Font = Enum.Font.GothamSemibold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local creatorLabel = makeUI(card, "TextLabel", {
        Size = UDim2.new(1, -118, 0, 14),
        Position = UDim2.new(0, 54, 0, 24),
        BackgroundTransparency = 1,
        Text = "@" .. (item.creatorName or "Unknown"),
        TextColor3 = Color3.fromRGB(100, 180, 255),
        Font = Enum.Font.Gotham,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    })

    local priceText = (item.price and item.price > 0) and (tostring(item.price) .. " R$") or "Free"
    local priceLabel = makeUI(card, "TextLabel", {
        Size = UDim2.new(1, -118, 0, 13),
        Position = UDim2.new(0, 54, 0, 38),
        BackgroundTransparency = 1,
        Text = priceText,
        TextColor3 = item.price and item.price > 0 and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(60, 220, 120),
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local copyBtn = makeUI(card, "TextButton", {
        Size = UDim2.new(0, 56, 0, 30),
        Position = UDim2.new(1, -62, 0.5, -15),
        BackgroundColor3 = Color3.fromRGB(180, 30, 30),
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Text = "Copy ID",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        AutoButtonColor = false,
    })
    makeUI(copyBtn, "UICorner", {CornerRadius = UDim.new(0, 6)})
    copyBtn.MouseEnter:Connect(function() TweenService:Create(copyBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play() end)
    copyBtn.MouseLeave:Connect(function() TweenService:Create(copyBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play() end)
    copyBtn.MouseButton1Click:Connect(function()
        copyToClipboard(tostring(item.id))
        local origText = copyBtn.Text
        copyBtn.Text = "Done"
        TweenService:Create(copyBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(30, 150, 60)}):Play()
        task.delay(1.2, function()
            copyBtn.Text = origText
            TweenService:Create(copyBtn, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(180, 30, 30)}):Play()
        end)
    end)
end

local catCurrentQuery  = ""
local catCurrentCursor = nil
local catIsLoading     = false

local function catClearResults()
    for _, v in ipairs(catScroll:GetChildren()) do
        if v:IsA("Frame") then v:Destroy() end
    end
end

local function catPerformSearch(query, cursor)
    if catIsLoading then return end
    catIsLoading = true

    if query and query ~= "" then
        catCurrentQuery  = query
        catCurrentCursor = nil
        catClearResults()
    end

    if catCurrentQuery == "" then
        catIsLoading = false
        return
    end

    catStatusLabel.Text = "Searching..."
    catStatusLabel.TextColor3 = Color3.fromRGB(110, 110, 110)

    local encoded = HttpService:UrlEncode(catCurrentQuery)
    local url = "https://catalog.roblox.com/v2/search/items/details?keyword=" .. encoded .. "&limit=30&includeNotForSale=true"
    if cursor then url = url .. "&cursor=" .. HttpService:UrlEncode(cursor) end

    task.spawn(function()
        local response = httpGet(url)
        if not response then
            catStatusLabel.Text = "⚠ Failed to connect"
            catStatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
            catIsLoading = false
            return
        end

        local ok, data = pcall(function() return HttpService:JSONDecode(response) end)
        if not ok or not data or not data.data then
            catStatusLabel.Text = "⚠ Parse error"
            catStatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
            catIsLoading = false
            return
        end

        if #data.data == 0 then
            catStatusLabel.Text = "No results found"
            catStatusLabel.TextColor3 = Color3.fromRGB(110, 110, 110)
        else
            catStatusLabel.Text = tostring(#data.data) .. " result(s) — '" .. catCurrentQuery .. "'"
            catStatusLabel.TextColor3 = Color3.fromRGB(60, 220, 120)
        end

        for _, item in ipairs(data.data) do
            createCatalogCard(item)
        end

        catCurrentCursor = data.nextPageCursor
        catLoadMoreBtn.Text = "Load More"
        catLoadMoreBtn.Visible = (catCurrentCursor ~= nil)

        catIsLoading = false
    end)
end

catSearchBtn.MouseButton1Click:Connect(function()
    local q = catSearchBox.Text:match("^%s*(.-)%s*$")
    if q ~= "" then catPerformSearch(q) end
end)
catLoadMoreBtn.MouseButton1Click:Connect(function()
    if catCurrentCursor then
        catLoadMoreBtn.Text = "Loading..."
        catPerformSearch(nil, catCurrentCursor)
    end
end)

local MFPage3 = makeUI(mfPageContainer, "Frame", {
    Position = UDim2.new(0, UI_WIDTH * 2, 0, 0),
    Size = UDim2.new(0, UI_WIDTH, 1, 0),
    BackgroundTransparency = 1,
})

local sh_placeId      = game.PlaceId
local sh_currentJobId = game.JobId
local sh_isLoading    = false

local function sh_getServerRegion(jobId)
    local hash = 0
    for i = 1, #jobId do hash = hash + string.byte(jobId, i) end
    local regions = {
        [0] = "🇺🇸 US", [1] = "🇪🇺 EU", [2] = "🇦🇺 AU", [3] = "🇸🇬 AS", [4] = "🇧🇷 SA"
    }
    return regions[hash % 5] or "🌍 UNK"
end

local function sh_fetchServers()
    if sh_isLoading then return {} end
    sh_isLoading = true
    local servers = {}
    local ok, result = pcall(function()
        local raw = httpGet("https://games.roblox.com/v1/games/" .. sh_placeId .. "/servers/Public?limit=100")
        return raw and HttpService:JSONDecode(raw) or nil
    end)
    if ok and result and result.data then
        for _, s in pairs(result.data) do
            if s.id ~= sh_currentJobId then
                table.insert(servers, {
                    id         = s.id,
                    playing    = s.playing or 0,
                    maxPlayers = s.maxPlayers or 0,
                    ping       = s.ping or 0,
                    region     = sh_getServerRegion(s.id),
                })
            end
        end
    end
    sh_isLoading = false
    return servers
end

local shStatusLabel = makeUI(MFPage3, "TextLabel", {
    Size     = UDim2.new(1, -16, 0, 14),
    Position = UDim2.new(0, 8, 0, 8),
    BackgroundTransparency = 1,
    Text     = "Tap Refresh to load servers",
    TextColor3 = Color3.fromRGB(110, 110, 110),
    Font     = Enum.Font.Gotham,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
})

local shScroll = makeUI(MFPage3, "ScrollingFrame", {
    Size     = UDim2.new(1, -8, 1, -52),
    Position = UDim2.new(0, 4, 0, 24),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 5,
    ScrollBarImageColor3 = Color3.fromRGB(200, 200, 200),
    CanvasSize = UDim2.new(0, 0, 0, 0),
    ScrollingDirection = Enum.ScrollingDirection.Y,
})
local shListLayout = makeUI(shScroll, "UIListLayout", {
    Padding = UDim.new(0, 5),
    HorizontalAlignment = Enum.HorizontalAlignment.Center,
})
makeUI(shScroll, "UIPadding", {
    PaddingTop = UDim.new(0, 3), PaddingBottom = UDim.new(0, 3),
    PaddingLeft = UDim.new(0, 2), PaddingRight = UDim.new(0, 2),
})
shListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    shScroll.CanvasSize = UDim2.new(0, 0, 0, shListLayout.AbsoluteContentSize.Y + 10)
end)

local shRefreshBtn = makeUI(MFPage3, "TextButton", {
    Size     = UDim2.new(1, -16, 0, 24),
    Position = UDim2.new(0, 8, 1, -34),
    BackgroundColor3 = Color3.fromRGB(60, 60, 60),
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
    Text     = "Refresh Server List",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font     = Enum.Font.GothamBold,
    TextSize = 12,
    AutoButtonColor = false,
})
makeUI(shRefreshBtn, "UICorner", {CornerRadius = UDim.new(0, 8)})
shRefreshBtn.MouseEnter:Connect(function() TweenService:Create(shRefreshBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play() end)
shRefreshBtn.MouseLeave:Connect(function() TweenService:Create(shRefreshBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play() end)

local function sh_clearCards()
    for _, v in ipairs(shScroll:GetChildren()) do
        if v:IsA("Frame") then v:Destroy() end
    end
end

local function sh_createCard(serverData, index)
    local card = makeUI(shScroll, "Frame", {
        Size     = UDim2.new(1, 0, 0, 62),
        BackgroundColor3 = Color3.fromRGB(40, 40, 40),
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        LayoutOrder = index,
    })
    makeUI(card, "UICorner", {CornerRadius = UDim.new(0, 8)})
    makeUI(card, "UIStroke", {Color = Color3.fromRGB(70,70,70), Thickness = 1, Transparency = 0.5})

    makeUI(card, "TextLabel", {
        Size     = UDim2.new(0, 120, 0, 16),
        Position = UDim2.new(0, 8, 0, 4),
        BackgroundTransparency = 1,
        Text     = serverData.region,
        TextColor3 = Color3.fromRGB(200, 200, 220),
        Font     = Enum.Font.Gotham,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local pct = serverData.maxPlayers > 0 and (serverData.playing / serverData.maxPlayers) or 0
    makeUI(card, "TextLabel", {
        Size     = UDim2.new(1, -80, 0, 16),
        Position = UDim2.new(0, 8, 0, 22),
        BackgroundTransparency = 1,
        Text     = "👥 " .. serverData.playing .. " / " .. serverData.maxPlayers,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font     = Enum.Font.GothamSemibold,
        TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local pbg = makeUI(card, "Frame", {
        Size     = UDim2.new(1, -78, 0, 5),
        Position = UDim2.new(0, 8, 0, 42),
        BackgroundColor3 = Color3.fromRGB(50, 50, 60),
        BorderSizePixel = 0,
    })
    makeUI(pbg, "UICorner", {CornerRadius = UDim.new(1, 0)})
    local pfill = makeUI(pbg, "Frame", {
        Size     = UDim2.new(math.clamp(pct, 0, 1), 0, 1, 0),
        BackgroundColor3 = pct > 0.8 and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(0, 180, 100),
        BorderSizePixel = 0,
    })
    makeUI(pfill, "UICorner", {CornerRadius = UDim.new(1, 0)})

    local hopBtn = makeUI(card, "TextButton", {
        Size     = UDim2.new(0, 52, 0, 28),
        Position = UDim2.new(1, -60, 0.5, -14),
        BackgroundColor3 = Color3.fromRGB(60, 60, 60),
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Text     = "Hop",
        TextColor3 = Color3.fromRGB(255, 255, 255),
        Font     = Enum.Font.GothamBold,
        TextSize = 12,
        AutoButtonColor = false,
    })
    makeUI(hopBtn, "UICorner", {CornerRadius = UDim.new(0, 6)})
    hopBtn.MouseEnter:Connect(function() TweenService:Create(hopBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play() end)
    hopBtn.MouseLeave:Connect(function() TweenService:Create(hopBtn, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play() end)
    hopBtn.MouseButton1Click:Connect(function()
        hopBtn.Text = "..."
        TweenService:Create(hopBtn, TweenInfo.new(0.1), {BackgroundColor3 = Color3.fromRGB(40,40,40)}):Play()
        pcall(function()
            game:GetService("TeleportService"):TeleportToPlaceInstance(sh_placeId, serverData.id, LocalPlayer)
        end)
    end)

    return card
end

local function sh_refreshList()
    if sh_isLoading then return end
    sh_clearCards()
    shStatusLabel.Text = "Fetching servers..."
    shStatusLabel.TextColor3 = Color3.fromRGB(110, 110, 110)
    task.spawn(function()
        local servers = sh_fetchServers()
        if #servers == 0 then
            shStatusLabel.Text = "⚠ No other servers found"
            shStatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
            return
        end
        table.sort(servers, function(a, b)
            if a.playing == b.playing then return a.ping < b.ping end
            return a.playing < b.playing
        end)
        shStatusLabel.Text = tostring(#servers) .. " server(s) found"
        shStatusLabel.TextColor3 = Color3.fromRGB(60, 220, 120)
        for i, sv in ipairs(servers) do sh_createCard(sv, i) end
    end)
end

shRefreshBtn.MouseButton1Click:Connect(sh_refreshList)

-- ============================================================
-- MFPage4: Zero Purchase (Product Spoofer)
-- ============================================================
local MPS_ZP        = game:GetService("MarketplaceService")
local zp_suppressCounter  = 0
local zp_autoSpeed        = 100
local zp_entries          = {}
local zp_eventCount       = 0
local zp_activeAutoButtons = {}
local zp_activeSpamButtons = {}
local zp_latestEvent       = nil

local ZP_SIG_COLOR = {
    Product  = Color3.fromRGB(100, 200, 255),
    Gamepass = Color3.fromRGB(61,  255, 160),
    Bulk     = Color3.fromRGB(255, 190,  60),
    Purchase = Color3.fromRGB(200, 200, 200),
}

local MFPage4 = makeUI(mfPageContainer, "Frame", {
    Position = UDim2.new(0, UI_WIDTH * 3, 0, 0),
    Size     = UDim2.new(0, UI_WIDTH, 1, 0),
    BackgroundTransparency = 1,
})

-- ---- SINGLE PAGE (no tabs) ----
local zp_mainPage = makeUI(MFPage4, "Frame", {
    Position = UDim2.new(0, 0, 0, 0),
    Size     = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ClipsDescendants = true,
})

-- Status label
local zp_statusLbl = makeUI(zp_mainPage, "TextLabel", {
    Size       = UDim2.new(1, -16, 0, 14),
    Position   = UDim2.new(0, 8, 0, 4),
    BackgroundTransparency = 1,
    Text       = "Waiting for purchase events...",
    TextColor3 = Color3.fromRGB(110,110,110),
    Font       = Enum.Font.Gotham,
    TextSize   = 10,
    TextXAlignment = Enum.TextXAlignment.Left,
})

-- Count label
local zp_countLbl = makeUI(zp_mainPage, "TextLabel", {
    Size       = UDim2.new(1, -16, 0, 12),
    Position   = UDim2.new(0, 8, 0, 20),
    BackgroundTransparency = 1,
    Text       = "0 events captured",
    TextColor3 = Color3.fromRGB(80,80,80),
    Font       = Enum.Font.Gotham,
    TextSize   = 9,
    TextXAlignment = Enum.TextXAlignment.Left,
})

-- ---- SETTINGS SECTION ----
local zp_settSection = makeUI(zp_mainPage, "Frame", {
    Size            = UDim2.new(1, -8, 0, 116),
    Position        = UDim2.new(0, 4, 0, 36),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
})
makeUI(zp_settSection, "UIListLayout", {
    Padding       = UDim.new(0, 4),
    SortOrder     = Enum.SortOrder.LayoutOrder,
    FillDirection = Enum.FillDirection.Vertical,
})

local function zp_makeSettingRow(title, desc, layoutOrder)
    local row = makeUI(zp_settSection, "Frame", {
        Size             = UDim2.new(1, -2, 0, 52),
        BackgroundColor3 = Color3.fromRGB(30,30,30),
        BorderSizePixel  = 0,
        LayoutOrder      = layoutOrder,
    })
    makeUI(row, "UICorner", {CornerRadius = UDim.new(0,8)})
    makeUI(row, "UIStroke", {Color=Color3.fromRGB(60,60,60), Thickness=1, Transparency=0.5})
    makeUI(row, "TextLabel", {
        Size=UDim2.new(0.65,0,0,18), Position=UDim2.new(0,10,0,8),
        BackgroundTransparency=1, Text=title, TextColor3=Color3.fromRGB(220,220,220),
        TextSize=11, Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Left,
    })
    makeUI(row, "TextLabel", {
        Size=UDim2.new(0.65,0,0,12), Position=UDim2.new(0,10,0,26),
        BackgroundTransparency=1, Text=desc, TextColor3=Color3.fromRGB(80,80,80),
        TextSize=9, Font=Enum.Font.Gotham, TextXAlignment=Enum.TextXAlignment.Left,
    })
    return row
end

-- Speed row
local zp_speedRow = zp_makeSettingRow("Signals per second", "1 slowest  |  10000 fastest  |  Default: 100", 1)
local zp_speedBox = makeUI(zp_speedRow, "TextBox", {
    Size=UDim2.new(0,80,0,26), Position=UDim2.new(1,-90,0.5,-13),
    BackgroundColor3=Color3.fromRGB(22,22,22), Text=tostring(zp_autoSpeed),
    TextColor3=Color3.fromRGB(220,220,220), TextSize=11, Font=Enum.Font.RobotoMono,
    BorderSizePixel=0, ClearTextOnFocus=false,
})
makeUI(zp_speedBox, "UICorner", {CornerRadius=UDim.new(0,6)})
makeUI(zp_speedBox, "UIStroke", {Color=Color3.fromRGB(60,60,60), Thickness=1})
makeUI(zp_speedBox, "UIPadding", {PaddingLeft=UDim.new(0,6)})
zp_speedBox.FocusLost:Connect(function()
    local n = tonumber(zp_speedBox.Text)
    if n and n >= 1 and n <= 10000 then
        zp_autoSpeed = math.floor(n)
        zp_speedBox.Text = tostring(zp_autoSpeed)
        TweenService:Create(zp_speedBox, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(20,50,25)}):Play()
        task.delay(0.6, function() TweenService:Create(zp_speedBox, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(22,22,22)}):Play() end)
    else
        TweenService:Create(zp_speedBox, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(50,20,20)}):Play()
        task.delay(0.6, function()
            TweenService:Create(zp_speedBox, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(22,22,22)}):Play()
            zp_speedBox.Text = tostring(zp_autoSpeed)
        end)
    end
end)

-- Manual fire row
local zp_manualRow = zp_makeSettingRow("Manual Fire", "Enter an ID and signal type to fire", 2)
local zp_manualBox = makeUI(zp_manualRow, "TextBox", {
    Size=UDim2.new(0,70,0,22), Position=UDim2.new(0,10,1,-30),
    BackgroundColor3=Color3.fromRGB(22,22,22), PlaceholderText="ID", Text="",
    TextColor3=Color3.fromRGB(220,220,220), PlaceholderColor3=Color3.fromRGB(80,80,80),
    TextSize=10, Font=Enum.Font.RobotoMono, BorderSizePixel=0, ClearTextOnFocus=false,
})
makeUI(zp_manualBox, "UICorner", {CornerRadius=UDim.new(0,5)})
makeUI(zp_manualBox, "UIStroke", {Color=Color3.fromRGB(60,60,60), Thickness=1})
makeUI(zp_manualBox, "UIPadding", {PaddingLeft=UDim.new(0,5)})

local zp_sigTypes = {"Product","Gamepass","Purchase","Bulk"}
local zp_sigIdx   = 1
local zp_sigCycleBtn = makeUI(zp_manualRow, "TextButton", {
    Size=UDim2.new(0,62,0,22), Position=UDim2.new(0,84,1,-30),
    BackgroundColor3=Color3.fromRGB(50,50,50), BackgroundTransparency=0.2,
    BorderSizePixel=0, Text=zp_sigTypes[1], TextColor3=Color3.fromRGB(140,140,140),
    Font=Enum.Font.GothamBold, TextSize=9, AutoButtonColor=false,
})
makeUI(zp_sigCycleBtn, "UICorner", {CornerRadius=UDim.new(0,5)})
zp_sigCycleBtn.MouseButton1Click:Connect(function()
    zp_sigIdx = (zp_sigIdx % #zp_sigTypes) + 1
    zp_sigCycleBtn.Text = zp_sigTypes[zp_sigIdx]
    local c = zp_sigTypes[zp_sigIdx] == "Product"
        and Color3.fromRGB(140,140,140)
        or (ZP_SIG_COLOR[zp_sigTypes[zp_sigIdx]] or Color3.fromRGB(200,200,200))
    zp_sigCycleBtn.TextColor3 = c
end)

local zp_fireManualBtn = makeUI(zp_manualRow, "TextButton", {
    Size=UDim2.new(0,40,0,22), Position=UDim2.new(1,-48,1,-30),
    BackgroundColor3=Color3.fromRGB(40,130,80), BackgroundTransparency=0.2,
    BorderSizePixel=0, Text="Fire", TextColor3=Color3.fromRGB(255,255,255),
    Font=Enum.Font.GothamBold, TextSize=10, AutoButtonColor=false,
})
makeUI(zp_fireManualBtn, "UICorner", {CornerRadius=UDim.new(0,5)})

-- ---- LOG SCROLL ----
local zp_logScroll = makeUI(zp_mainPage, "ScrollingFrame", {
    Size     = UDim2.new(1, -8, 1, -192),
    Position = UDim2.new(0, 4, 0, 158),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Color3.fromRGB(140,140,140),
    CanvasSize = UDim2.new(0,0,0,0),
    ScrollingDirection = Enum.ScrollingDirection.Y,
})
local zp_logLayout = makeUI(zp_logScroll, "UIListLayout", {
    Padding   = UDim.new(0,4),
    SortOrder = Enum.SortOrder.LayoutOrder,
})
makeUI(zp_logScroll, "UIPadding", {
    PaddingTop=UDim.new(0,3), PaddingBottom=UDim.new(0,3),
    PaddingLeft=UDim.new(0,2), PaddingRight=UDim.new(0,3),
})
zp_logLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    zp_logScroll.CanvasSize = UDim2.new(0,0,0,zp_logLayout.AbsoluteContentSize.Y+8)
end)

-- ---- BOTTOM BAR ----
local zp_clearBtn = makeUI(zp_mainPage, "TextButton", {
    Size     = UDim2.new(0.5, -6, 0, 26),
    Position = UDim2.new(0, 4, 1, -30),
    BackgroundColor3 = Color3.fromRGB(50,50,50),
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
    Text = "Clear All",
    TextColor3 = Color3.fromRGB(200,200,200),
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    AutoButtonColor = false,
})
makeUI(zp_clearBtn, "UICorner", {CornerRadius=UDim.new(0,6)})
makeUI(zp_clearBtn, "UIStroke", {Color=Color3.fromRGB(80,80,80), Thickness=1, Transparency=0.5})
zp_clearBtn.MouseEnter:Connect(function() TweenService:Create(zp_clearBtn, TweenInfo.new(0.15), {BackgroundTransparency=0}):Play() end)
zp_clearBtn.MouseLeave:Connect(function() TweenService:Create(zp_clearBtn, TweenInfo.new(0.15), {BackgroundTransparency=0.2}):Play() end)

local zp_stopAllBtn = makeUI(zp_mainPage, "TextButton", {
    Size     = UDim2.new(0.5, -6, 0, 26),
    Position = UDim2.new(0.5, 2, 1, -30),
    BackgroundColor3 = Color3.fromRGB(120,30,30),
    BackgroundTransparency = 0.2,
    BorderSizePixel = 0,
    Text = "Stop All",
    TextColor3 = Color3.fromRGB(255,120,120),
    Font = Enum.Font.GothamBold,
    TextSize = 11,
    AutoButtonColor = false,
})
makeUI(zp_stopAllBtn, "UICorner", {CornerRadius=UDim.new(0,6)})
makeUI(zp_stopAllBtn, "UIStroke", {Color=Color3.fromRGB(180,50,50), Thickness=1, Transparency=0.5})
zp_stopAllBtn.MouseEnter:Connect(function() TweenService:Create(zp_stopAllBtn, TweenInfo.new(0.15), {BackgroundTransparency=0}):Play() end)
zp_stopAllBtn.MouseLeave:Connect(function() TweenService:Create(zp_stopAllBtn, TweenInfo.new(0.15), {BackgroundTransparency=0.2}):Play() end)

-- ---- EMPTY STATE ----
local function zp_setEmpty(show)
    local e = zp_logScroll:FindFirstChild("ZP_EmptyState")
    if show and not e then
        makeUI(zp_logScroll, "TextLabel", {
            Name = "ZP_EmptyState",
            Size = UDim2.new(1,0,0,180),
            BackgroundTransparency = 1,
            Text = "Waiting for events...\nAll marketplace signals will appear here.",
            TextColor3 = Color3.fromRGB(80,80,80),
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextWrapped = true,
            LayoutOrder = 99999,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
    elseif not show and e then
        e:Destroy()
    end
end
zp_setEmpty(true)

-- ---- CORE FUNCTIONS (dari spoofer asli) ----
local function zp_fireFakeSignal(sigType, id)
    zp_suppressCounter = zp_suppressCounter + 1
    pcall(function()
        if     sigType == "Product"  then MPS_ZP:SignalPromptProductPurchaseFinished(LocalPlayer.UserId, id, true)
        elseif sigType == "Gamepass" then MPS_ZP:SignalPromptGamePassPurchaseFinished(LocalPlayer, id, true)
        elseif sigType == "Bulk"     then MPS_ZP:SignalPromptBulkPurchaseFinished(LocalPlayer.UserId, id, true)
        elseif sigType == "Purchase" then MPS_ZP:SignalPromptPurchaseFinished(LocalPlayer.UserId, id, true)
        end
    end)
    zp_suppressCounter = zp_suppressCounter - 1
end

local function zp_stopAllAutoAndSpam()
    for btn, data in pairs(zp_activeAutoButtons) do
        data.active = false
        if data.loop then task.cancel(data.loop) end
        if btn and btn.Parent then
            btn.Text = "Auto"
            btn.TextColor3 = Color3.fromRGB(160,160,160)
            btn.BackgroundColor3 = Color3.fromRGB(50,50,50)
        end
    end
    table.clear(zp_activeAutoButtons)
    for btn, data in pairs(zp_activeSpamButtons) do
        data.active = false
        if data.loop then task.cancel(data.loop) end
        if btn and btn.Parent then
            btn.Text = "\226\150\182"
            btn.TextColor3 = Color3.fromRGB(160,160,160)
            btn.BackgroundColor3 = Color3.fromRGB(50,50,50)
        end
    end
    table.clear(zp_activeSpamButtons)
end

zp_stopAllBtn.MouseButton1Click:Connect(zp_stopAllAutoAndSpam)

zp_clearBtn.MouseButton1Click:Connect(function()
    zp_stopAllAutoAndSpam()
    for _, e in ipairs(zp_entries) do pcall(function() e:Destroy() end) end
    zp_entries = {}
    zp_eventCount = 0
    zp_countLbl.Text = "0 events captured"
    zp_statusLbl.Text = "Waiting for purchase events..."
    zp_statusLbl.TextColor3 = Color3.fromRGB(110,110,110)
    zp_setEmpty(true)
end)

-- Helper: small button inside entry row
local function zp_mkBtn(parent, txt, xOff, w)
    w = w or 52
    local b = makeUI(parent, "TextButton", {
        Size = UDim2.new(0, w, 0, 22),
        Position = UDim2.new(0, xOff, 0.5, -11),
        BackgroundColor3 = Color3.fromRGB(50,50,50),
        BackgroundTransparency = 0.2,
        BorderSizePixel = 0,
        Text = txt,
        TextColor3 = Color3.fromRGB(160,160,160),
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        AutoButtonColor = false,
    })
    makeUI(b, "UICorner", {CornerRadius=UDim.new(0,5)})
    makeUI(b, "UIStroke", {Color=Color3.fromRGB(70,70,70), Thickness=1, Transparency=0.4})
    return b
end

-- ---- addLog: buat entry card di log (langsung dari spoofer asli) ----
local function zp_addLog(label, id, sigType)
    if zp_suppressCounter > 0 then return end
    zp_setEmpty(false)

    local sigCol = ZP_SIG_COLOR[sigType] or Color3.fromRGB(200,200,200)

    local entry = makeUI(zp_logScroll, "Frame", {
        Size             = UDim2.new(1, -2, 0, 52),
        BackgroundColor3 = Color3.fromRGB(25,25,25),
        BorderSizePixel  = 0,
        LayoutOrder      = zp_eventCount + 1,
    })
    entry:SetAttribute("ZP_SigID", id)
    makeUI(entry, "UICorner", {CornerRadius=UDim.new(0,8)})
    makeUI(entry, "UIStroke", {Color=Color3.fromRGB(55,55,55), Thickness=1, Transparency=0.5})
    entry.BackgroundTransparency = 1
    TweenService:Create(entry, TweenInfo.new(0.18), {BackgroundTransparency=0}):Play()

    -- Colored dot
    local dot = makeUI(entry, "Frame", {
        Size=UDim2.new(0,8,0,8), Position=UDim2.new(0,10,0.5,-4),
        BackgroundColor3=sigCol, BorderSizePixel=0,
    })
    makeUI(dot, "UICorner", {CornerRadius=UDim.new(1,0)})

    -- Type label
    makeUI(entry, "TextLabel", {
        Size=UDim2.new(0,60,0,14), Position=UDim2.new(0,22,0,7),
        BackgroundTransparency=1, Text=string.upper(label),
        TextColor3=sigCol, Font=Enum.Font.GothamBold, TextSize=9,
        TextXAlignment=Enum.TextXAlignment.Left,
    })

    -- ID label
    makeUI(entry, "TextLabel", {
        Size=UDim2.new(0,100,0,14), Position=UDim2.new(0,22,0,22),
        BackgroundTransparency=1, Text=tostring(id),
        TextColor3=Color3.fromRGB(230,230,230), Font=Enum.Font.GothamBold, TextSize=11,
        TextXAlignment=Enum.TextXAlignment.Left, TextTruncate=Enum.TextTruncate.AtEnd,
    })

    -- Time label
    makeUI(entry, "TextLabel", {
        Size=UDim2.new(0,55,0,12), Position=UDim2.new(0,22,0,38),
        BackgroundTransparency=1, Text=os.date("%H:%M:%S"),
        TextColor3=Color3.fromRGB(75,75,75), Font=Enum.Font.Gotham, TextSize=9,
        TextXAlignment=Enum.TextXAlignment.Left,
    })

    -- Buttons frame
    local bf = makeUI(entry, "Frame", {
        Size=UDim2.new(0,162,1,0), Position=UDim2.new(1,-165,0,0),
        BackgroundTransparency=1,
    })

    local autoBtn = zp_mkBtn(bf, "Auto", 0)
    local copyBtn = zp_mkBtn(bf, "Copy", 56)
    local runBtn  = zp_mkBtn(bf, "\226\150\182", 112, 42)
    runBtn.TextSize = 16

    -- COPY
    copyBtn.MouseButton1Click:Connect(function()
        pcall(setclipboard, tostring(id))
        copyBtn.Text = "Done!"; copyBtn.TextColor3 = Color3.fromRGB(100,220,100)
        task.delay(1.5, function()
            if copyBtn.Parent then copyBtn.Text = "Copy"; copyBtn.TextColor3 = Color3.fromRGB(160,160,160) end
        end)
    end)

    -- AUTO
    local autoActive = false; local autoLoop = nil
    local function startAuto()
        if autoActive then return end
        autoActive = true
        autoBtn.Text = "Stop"; autoBtn.TextColor3 = Color3.fromRGB(255,90,90)
        autoBtn.BackgroundColor3 = Color3.fromRGB(60,15,15)
        autoLoop = task.spawn(function()
            while autoActive and autoBtn.Parent do
                zp_fireFakeSignal(sigType, id)
                task.wait(zp_autoSpeed > 0 and 1/zp_autoSpeed or 0.01)
            end
        end)
        zp_activeAutoButtons[autoBtn] = {active=true, loop=autoLoop}
    end
    local function stopAuto()
        autoActive = false
        if autoLoop then task.cancel(autoLoop) end
        zp_activeAutoButtons[autoBtn] = nil
        if autoBtn.Parent then
            autoBtn.Text = "Auto"; autoBtn.TextColor3 = Color3.fromRGB(160,160,160)
            autoBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
        end
    end
    autoBtn.MouseButton1Click:Connect(function() if autoActive then stopAuto() else startAuto() end end)

    -- RUN (klik = sekali, tahan 3s = spam) -- langsung dari spoofer asli
    local holdStart = nil; local holdConn = nil; local spamLoop = nil; local isSpamming = false
    local function startSpam()
        if isSpamming then return end
        isSpamming = true
        runBtn.Text = "SPAM"; runBtn.TextSize = 9; runBtn.TextColor3 = Color3.fromRGB(255,200,60)
        runBtn.BackgroundColor3 = Color3.fromRGB(60,45,10)
        spamLoop = task.spawn(function()
            while isSpamming and runBtn.Parent do
                zp_fireFakeSignal(sigType, id); task.wait(0.08)
            end
        end)
        zp_activeSpamButtons[runBtn] = {active=true, loop=spamLoop}
    end
    local function stopSpam()
        isSpamming = false
        if spamLoop then task.cancel(spamLoop) end
        zp_activeSpamButtons[runBtn] = nil
        if runBtn.Parent then
            runBtn.Text = "\226\150\182"; runBtn.TextSize = 16
            runBtn.TextColor3 = Color3.fromRGB(160,160,160)
            runBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
        end
    end
    runBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            holdStart = tick()
            holdConn = task.spawn(function()
                while holdStart and (tick() - holdStart) < 3 do task.wait(0.1) end
                if holdStart and not isSpamming then startSpam() end
            end)
        end
    end)
    runBtn.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 or inp.UserInputType == Enum.UserInputType.Touch then
            local dur = holdStart and (tick() - holdStart) or 0
            holdStart = nil
            if holdConn then task.cancel(holdConn) end
            if isSpamming then
                stopSpam()
            elseif dur < 3 then
                zp_fireFakeSignal(sigType, id)
                runBtn.Text = "Sent!"; runBtn.TextSize = 9
                task.delay(1.5, function()
                    if runBtn.Parent then runBtn.Text = "\226\150\182"; runBtn.TextSize = 16 end
                end)
            end
        end
    end)

    entry.AncestryChanged:Connect(function()
        if not entry.Parent then
            if autoActive then stopAuto() end
            if isSpamming then stopSpam() end
            for i, e in ipairs(zp_entries) do
                if e == entry then table.remove(zp_entries, i); break end
            end
        end
    end)

    zp_eventCount = zp_eventCount + 1
    zp_countLbl.Text = zp_eventCount .. (zp_eventCount == 1 and " event captured" or " events captured")
    zp_statusLbl.Text = string.upper(sigType) .. "  \183  " .. tostring(id)
    zp_statusLbl.TextColor3 = sigCol
    table.insert(zp_entries, entry)
    zp_latestEvent = {sigType=sigType, id=id}
    task.defer(function() zp_logScroll.CanvasPosition = Vector2.new(0, zp_logScroll.AbsoluteCanvasSize.Y) end)
end

-- Manual fire connect (setelah zp_addLog didefinisikan)
zp_fireManualBtn.MouseButton1Click:Connect(function()
    local id = tonumber(zp_manualBox.Text:match("^%s*(.-)%s*$"))
    if not id then return end
    local sig = zp_sigTypes[zp_sigIdx]
    zp_fireFakeSignal(sig, id)
    zp_addLog(sig, id, sig)
    TweenService:Create(zp_fireManualBtn, TweenInfo.new(0.1), {BackgroundColor3=Color3.fromRGB(27,100,27)}):Play()
    task.delay(0.5, function()
        TweenService:Create(zp_fireManualBtn, TweenInfo.new(0.3), {BackgroundColor3=Color3.fromRGB(40,130,80)}):Play()
    end)
end)

-- ---- MARKETPLACE LISTENERS (langsung dari spoofer asli) ----
local _zp_conns = {}
pcall(function()
    table.insert(_zp_conns, MPS_ZP.PromptProductPurchaseFinished:Connect(function(_, id, _)
        if zp_suppressCounter == 0 then zp_addLog("Product", id, "Product") end
    end))
end)
pcall(function()
    table.insert(_zp_conns, MPS_ZP.PromptGamePassPurchaseFinished:Connect(function(_, id, _)
        if zp_suppressCounter == 0 then zp_addLog("Gamepass", id, "Gamepass") end
    end))
end)
pcall(function()
    table.insert(_zp_conns, MPS_ZP.PromptBulkPurchaseFinished:Connect(function(_, id, _)
        if zp_suppressCounter == 0 then zp_addLog("Bulk", id, "Bulk") end
    end))
end)
pcall(function()
    table.insert(_zp_conns, MPS_ZP.PromptPurchaseFinished:Connect(function(_, id, _)
        if zp_suppressCounter == 0 then zp_addLog("Purchase", id, "Purchase") end
    end))
end)
-- ============================================================
-- END: Zero Purchase Page
-- ============================================================
-- ============================================================
-- WindUI-style Drag System (Zero Extension / MultiFling UI)
-- Supports PC (MouseButton1) + Mobile (Touch)
-- Smooth tween movement ported from WindUI p.Drag()
-- ============================================================
local _mfDragActive    = false
local _mfDragInput     = nil
local _mfDragStartPos  = nil   -- input Position at drag start
local _mfFrameStartPos = nil   -- MainFrame.Position at drag start
local mfTouchDeltaX    = 0
local mfTouchDeltaY    = 0

local function isInside(frame, x, y)
    local pos = frame.AbsolutePosition
    local sz  = frame.AbsoluteSize
    return x >= pos.X and x <= pos.X + sz.X and y >= pos.Y and y <= pos.Y + sz.Y
end

-- Smooth tween-based position update (WindUI 0.02s micro-tween)
local function _mfDragUpdate(inputPos)
    if not _mfDragActive or not _mfFrameStartPos or not _mfDragStartPos then return end
    local delta = inputPos - _mfDragStartPos
    TweenService:Create(MainFrame, TweenInfo.new(0.02, Enum.EasingStyle.Linear), {
        Position = UDim2.new(
            _mfFrameStartPos.X.Scale,
            _mfFrameStartPos.X.Offset + delta.X,
            _mfFrameStartPos.Y.Scale,
            _mfFrameStartPos.Y.Offset + delta.Y
        )
    }):Play()
    mfTouchDeltaX = delta.X
    mfTouchDeltaY = delta.Y
end

-- Drag handles: Header + OpenBtn bubble (drag bar equivalent)
local _mfDragHandles = { Header, OpenBtnBubble }

for _, handle in ipairs(_mfDragHandles) do
    handle.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch)
            and not _mfDragActive
        then
            _mfDragActive    = true
            _mfDragInput     = input
            _mfDragStartPos  = input.Position
            _mfFrameStartPos = MainFrame.Position
            mfTouchDeltaX    = 0
            mfTouchDeltaY    = 0

            -- Track input end on the input object itself (WindUI pattern)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    _mfDragActive = false
                    _mfDragInput  = nil
                end
            end)
        end
    end)

    handle.InputChanged:Connect(function(input)
        if _mfDragActive and _mfDragInput == input then
            if input.UserInputType == Enum.UserInputType.MouseMovement
                or input.UserInputType == Enum.UserInputType.Touch
            then
                _mfDragUpdate(input.Position)
            end
        end
    end)
end

-- Global InputChanged fallback (catches mouse movement outside handle, WindUI pattern)
UIS.InputChanged:Connect(function(input)
    if _mfDragActive and _mfDragInput ~= nil then
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch
        then
            _mfDragUpdate(input.Position)
        end
    end
end)

-- Swipe/page gesture: only on content area (not header)
local _mfSwipeTouchStartX = nil
local _mfSwipeTouchStartY = nil
local _mfSwipeActive      = false

UIS.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Touch and
       input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if not MainFrame.Visible then return end
    local tx, ty
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local mloc = UIS:GetMouseLocation()
        tx = mloc.X; ty = mloc.Y
    else
        tx = input.Position.X; ty = input.Position.Y
    end
    if not isInside(MainFrame, tx, ty) then return end
    if isInside(Header, tx, ty) then return end  -- header handled by drag
    _mfSwipeTouchStartX = tx
    _mfSwipeTouchStartY = ty
    _mfSwipeActive      = false
    mfTouchDeltaX       = 0
    mfTouchDeltaY       = 0
end)

UIS.InputChanged:Connect(function(input)
    if not _mfSwipeTouchStartX then return end
    if _mfDragActive then _mfSwipeTouchStartX = nil; return end  -- drag takes priority
    if input.UserInputType ~= Enum.UserInputType.Touch and
       input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local cx, cy
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        local mloc = UIS:GetMouseLocation()
        cx = mloc.X; cy = mloc.Y
    else
        cx = input.Position.X; cy = input.Position.Y
    end
    mfTouchDeltaX = cx - _mfSwipeTouchStartX
    mfTouchDeltaY = cy - _mfSwipeTouchStartY
    local adx, ady = math.abs(mfTouchDeltaX), math.abs(mfTouchDeltaY)
    if not _mfSwipeActive and (adx > 12 or ady > 12) then
        if adx > ady * 1.5 then _mfSwipeActive = true else _mfSwipeTouchStartX = nil end
    end
end)

UIS.InputEnded:Connect(function(input)
    if not _mfSwipeTouchStartX then return end
    if input.UserInputType ~= Enum.UserInputType.Touch and
       input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if _mfSwipeActive then
        if mfTouchDeltaX < -35 and currentPage_MF < totalPages_MF then
            goToMFPage(currentPage_MF + 1)
        elseif mfTouchDeltaX > 35 and currentPage_MF > 1 then
            goToMFPage(currentPage_MF - 1)
        end
    end
    _mfSwipeTouchStartX = nil
    _mfSwipeTouchStartY = nil
    _mfSwipeActive      = false
end)

local mfPageKeyDebounce = false
UIS.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if isMinimized then return end
    if not MainFrame.Visible then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if input.KeyCode ~= Enum.KeyCode.K and input.KeyCode ~= Enum.KeyCode.Six then return end
    if mfPageKeyDebounce then return end
    if input.KeyCode == Enum.KeyCode.K then
        if currentPage_MF < totalPages_MF then
            mfPageKeyDebounce = true
            goToMFPage(currentPage_MF + 1)
            task.delay(0.35, function() mfPageKeyDebounce = false end)
        end
    elseif input.KeyCode == Enum.KeyCode.Six then
        if currentPage_MF > 1 then
            mfPageKeyDebounce = true
            goToMFPage(currentPage_MF - 1)
            task.delay(0.35, function() mfPageKeyDebounce = false end)
        end
    end
end)

local mfScrollDebounce = false
UIS.InputChanged:Connect(function(input)
    if isMinimized then return end
    if not MainFrame.Visible then return end
    if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
    local mousePos = UIS:GetMouseLocation()
    if not isInside(MainFrame, mousePos.X, mousePos.Y) then return end
    if mfScrollDebounce then return end
    if input.Position.Z < 0 then
        if currentPage_MF < totalPages_MF then
            mfScrollDebounce = true
            goToMFPage(currentPage_MF + 1)
            task.delay(0.4, function() mfScrollDebounce = false end)
        end
    elseif input.Position.Z > 0 then
        if currentPage_MF > 1 then
            mfScrollDebounce = true
            goToMFPage(currentPage_MF - 1)
            task.delay(0.4, function() mfScrollDebounce = false end)
        end
    end
end)

local _minimizeDebounce = false
local function toggleMinimize()
    if _minimizeDebounce then return end
    _minimizeDebounce = true
    if isMinimized then
        bubbleSavedX = OpenBtn.Position.X.Offset
        bubbleSavedY = OpenBtn.Position.Y.Offset
        isMinimized = false
        minimizeBtn.Text = "-"
        OpenBtn.Visible = ZeroMultiFlingEnabled
        -- OPTIMASI: Set Visible langsung tanpa delay agar responsif instan
        MainFrame.Visible = true
    else
        isMinimized = true
        OpenBtn.AnchorPoint = Vector2.new(0, 0)
        OpenBtn.Position = UDim2.new(0, bubbleSavedX, 0, bubbleSavedY)
        OpenBtn.Visible = ZeroMultiFlingEnabled
        MainFrame.Visible = false
    end
    -- OPTIMASI: Kurangi dari 0.1 → 0.05 agar debounce lebih responsif
    task.wait(0.05)
    _minimizeDebounce = false
end
minimizeBtn.MouseButton1Click:Connect(toggleMinimize)

local bubbleHeld       = false
local bubbleDragging   = false
local bubbleStartInputX = 0
local bubbleStartInputY = 0
local bubbleStartPosX   = 0
local bubbleStartPosY   = 0
local DRAG_THRESHOLD   = 12

OpenBtn.InputBegan:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Touch and
       input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local absX = OpenBtn.AbsolutePosition.X
    local absY = OpenBtn.AbsolutePosition.Y
    if OpenBtn.AnchorPoint.X ~= 0 then
        OpenBtn.AnchorPoint = Vector2.new(0, 0)
        OpenBtn.Position = UDim2.new(0, absX, 0, absY)
        bubbleSavedX = absX; bubbleSavedY = absY
    end
    bubbleHeld = true; bubbleDragging = false
    bubbleStartInputX = input.Position.X; bubbleStartInputY = input.Position.Y
    bubbleStartPosX = OpenBtn.Position.X.Offset; bubbleStartPosY = OpenBtn.Position.Y.Offset
    TweenService:Create(OpenBtnIcon, TweenInfo.new(0.08), {
        Size = UDim2.new(0, 35, 0, 35), Position = UDim2.new(0, 3, 0, 3)
    }):Play()
end)

UIS.InputChanged:Connect(function(input)
    if not bubbleHeld then return end
    if input.UserInputType ~= Enum.UserInputType.Touch and
       input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
    local dx = input.Position.X - bubbleStartInputX
    local dy = input.Position.Y - bubbleStartInputY
    if not bubbleDragging then
        if math.abs(dx) >= DRAG_THRESHOLD or math.abs(dy) >= DRAG_THRESHOLD then
            bubbleDragging = true
        else return end
    end
    local vp = workspace.CurrentCamera.ViewportSize
    local newX = math.clamp(bubbleStartPosX + dx, 0, vp.X - 42)
    local newY = math.clamp(bubbleStartPosY + dy, 0, vp.Y - 42)
    -- WindUI micro-tween (0.02s) for smooth bubble drag on PC and Mobile
    TweenService:Create(OpenBtn, TweenInfo.new(0.02, Enum.EasingStyle.Linear), {
        Position = UDim2.new(0, newX, 0, newY)
    }):Play()
    bubbleSavedX = newX; bubbleSavedY = newY
end)

UIS.InputEnded:Connect(function(input)
    if not bubbleHeld then return end
    if input.UserInputType ~= Enum.UserInputType.Touch and
       input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    TweenService:Create(OpenBtnIcon, TweenInfo.new(0.1), {
        Size = UDim2.new(0, 42, 0, 42), Position = UDim2.new(0, 0, 0, 0)
    }):Play()
    if not bubbleDragging then
        isMinimized = false
        minimizeBtn.Text = "-"
        -- OPTIMASI: Tampilkan MainFrame secara instan tanpa menunggu
        -- agar respons terasa langsung saat jari/klik dilepas
        MainFrame.Visible = true
        OpenBtn.Visible = ZeroMultiFlingEnabled
    end
    bubbleHeld = false; bubbleDragging = false
end)

ModeBtn.MouseButton1Click:Connect(function()
    if ReturnMode == "Original" then
        ReturnMode = "Manual"; ModeBtn.Text = "RETURN MODE: MANUAL"; ManualBtn.Visible = true
    elseif ReturnMode == "Manual" then
        ReturnMode = "Target"; ModeBtn.Text = "RETURN MODE: TARGET"; ManualBtn.Visible = false
    else
        ReturnMode = "Original"; ModeBtn.Text = "RETURN MODE: ORIGINAL"; ManualBtn.Visible = false
    end
end)

ManualBtn.MouseButton1Click:Connect(function()
    if Player.Character and Player.Character:FindFirstChild("HumanoidRootPart") then
        ManualPos = Player.Character.HumanoidRootPart.CFrame
        StatusLabel.Text = "SYSTEM: Return point saved"
    end
end)

SmartFlingBtn.MouseButton1Click:Connect(function()
    SmartFlingEnabled = not SmartFlingEnabled
    SmartFlingBtn.Text = SmartFlingEnabled and "SMART FLING: ON" or "SMART FLING: OFF"
    setToggleActive(SmartFlingBtn, SmartFlingEnabled)
    if SmartFlingEnabled then StatusLabel.Text = "SYSTEM: Displacement detection active" end
end)

local function IsAlreadyFlung(TargetPlayer)
    if not SmartFlingEnabled then return false end
    local char = TargetPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    local hum  = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return false end
    if hum.FloorMaterial ~= Enum.Material.Air then return false end
    local velocity = hrp.AssemblyLinearVelocity.Magnitude
    local rayParams = RaycastParams.new()
    rayParams.FilterDescendantsInstances = {char, Player.Character}
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local groundCheck = workspace:Raycast(hrp.Position, Vector3.new(0, -65, 0), rayParams)
    if not groundCheck or velocity > 175 then return true end
    return false
end

local function TouchFlingLoop()
    local movel = 0.1
    while TouchFlingActive do
        RunService.Heartbeat:Wait()
        local c = Player.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        if hrp then
            local vel = hrp.Velocity
            hrp.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)
            RunService.RenderStepped:Wait()
            hrp.Velocity = vel
            RunService.Stepped:Wait()
            hrp.Velocity = vel + Vector3.new(0, movel, 0)
            movel = -movel
        end
    end
end
TouchFlingBtn.MouseButton1Click:Connect(function()
    TouchFlingActive = not TouchFlingActive
    TouchFlingBtn.Text = TouchFlingActive and "TOUCH FLING: ON" or "TOUCH FLING: OFF"
    setToggleActive(TouchFlingBtn, TouchFlingActive)
    if TouchFlingActive then task.spawn(TouchFlingLoop) end
end)

local function SkidFling(TargetPlayer)
    if IsAlreadyFlung(TargetPlayer) then return end
    local Character = Player.Character
    local Humanoid  = Character and Character:FindFirstChildOfClass("Humanoid")
    local RootPart  = Humanoid and Humanoid.RootPart
    local TCharacter = TargetPlayer.Character
    if not TCharacter then return end

    local THumanoid, TRootPart, THead, Accessory, Handle
    if TCharacter:FindFirstChildOfClass("Humanoid") then THumanoid = TCharacter:FindFirstChildOfClass("Humanoid") end
    if THumanoid and THumanoid.RootPart then TRootPart = THumanoid.RootPart end
    if TCharacter:FindFirstChild("Head") then THead = TCharacter.Head end
    if TCharacter:FindFirstChildOfClass("Accessory") then Accessory = TCharacter:FindFirstChildOfClass("Accessory") end
    if Accessory and Accessory:FindFirstChild("Handle") then Handle = Accessory.Handle end

    if Character and Humanoid and RootPart then
        if RootPart.Velocity.Magnitude < 50 then
            if ReturnMode == "Original" then getgenv().OldPos = RootPart.CFrame
            elseif ReturnMode == "Manual" and ManualPos then getgenv().OldPos = ManualPos
            elseif ReturnMode == "Target" and TRootPart then getgenv().OldPos = TRootPart.CFrame
            else getgenv().OldPos = RootPart.CFrame end
        end
        if THumanoid and THumanoid.Sit then return end
        workspace.CurrentCamera.CameraSubject = THead or Handle or (THumanoid and TRootPart)

        local FPos = function(BasePart, Pos, Ang)
            RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
            Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)
            RootPart.Velocity = Vector3.new(90000, 900000, 90000)
            RootPart.RotVelocity = Vector3.new(900000, 900000, 900000)
        end

        local SFBasePart = function(BasePart)
            local TimeToWait = 2
            local Time = tick()
            local Angle = 0
            repeat
                if IsAlreadyFlung(TargetPlayer) then break end
                if RootPart and THumanoid then
                    if BasePart.Velocity.Magnitude < 50 then
                        Angle = Angle + 100
                        FPos(BasePart, CFrame.new(0,1.5,0)+THumanoid.MoveDirection*BasePart.Velocity.Magnitude/1.25, CFrame.Angles(math.rad(Angle),0,0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0,-1.5,0)+THumanoid.MoveDirection*BasePart.Velocity.Magnitude/1.25, CFrame.Angles(math.rad(Angle),0,0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0,1.5,0)+THumanoid.MoveDirection, CFrame.Angles(math.rad(Angle),0,0))
                        task.wait()
                    else
                        FPos(BasePart, CFrame.new(0,1.5,THumanoid.WalkSpeed), CFrame.Angles(math.rad(90),0,0))
                        task.wait()
                        FPos(BasePart, CFrame.new(0,-1.5,-THumanoid.WalkSpeed), CFrame.Angles(0,0,0))
                        task.wait()
                    end
                end
            until Time + TimeToWait < tick() or not FlingActive
        end

        workspace.FallenPartsDestroyHeight = 0/0
        local BV_Ex = Instance.new("BodyVelocity", RootPart)
        BV_Ex.Velocity = Vector3.new(0,0,0)
        BV_Ex.MaxForce = Vector3.new(9e9,9e9,9e9)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

        if TRootPart then SFBasePart(TRootPart)
        elseif THead then SFBasePart(THead)
        elseif Handle then SFBasePart(Handle) end

        BV_Ex:Destroy()
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        workspace.CurrentCamera.CameraSubject = Humanoid

        if getgenv().OldPos then
            repeat
                RootPart.CFrame = getgenv().OldPos * CFrame.new(0,.5,0)
                Character:SetPrimaryPartCFrame(getgenv().OldPos * CFrame.new(0,.5,0))
                Humanoid:ChangeState("GettingUp")
                for _, part in pairs(Character:GetChildren()) do
                    if part:IsA("BasePart") then part.Velocity, part.RotVelocity = Vector3.new(), Vector3.new() end
                end
                task.wait()
            until (RootPart.Position - getgenv().OldPos.p).Magnitude < 25
            workspace.FallenPartsDestroyHeight = getgenv().FPDH
        end
    end
end

local function Start()
    if FlingActive then return end
    local count = 0; for _ in pairs(SelectedTargets) do count = count + 1 end
    if count == 0 then return end
    FlingActive = true
    StatusLabel.Text = "ACTIVE: Target count " .. count
    task.spawn(function()
        while FlingActive do
            local foundTarget = false
            for _, p in pairs(SelectedTargets) do
                if not FlingActive then break end
                if p and p.Parent and p.Character then foundTarget = true; SkidFling(p) end
            end
            if not foundTarget or getgenv().SinglePass then FlingActive = false; break end
            task.wait(0.1)
        end
        FlingActive = false
        getgenv().SinglePass = false
        StatusLabel.Text = "Fling system disengaged"
    end)
end

local function Stop()
    FlingActive = false
    AutoFlingAllEnabled = false
    FlingAllToggleBtn.Text = "FLING ALL: OFF"
    setToggleActive(FlingAllToggleBtn, false)
    getgenv().SinglePass = false
    StatusLabel.Text = "Fling system disengaged"
end

local function ToggleFlingAll()
    AutoFlingAllEnabled = not AutoFlingAllEnabled
    if AutoFlingAllEnabled then
        FlingAllToggleBtn.Text = "FLING ALL: ON"
        setToggleActive(FlingAllToggleBtn, true)
        SelectedTargets = {}
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= Player and not WhitelistedUsers[p.Name] then SelectedTargets[p.Name] = p end
        end
        getgenv().SinglePass = false
        Start()
    else
        Stop(); SelectedTargets = {}; RefreshList()
    end
end
FlingAllToggleBtn.MouseButton1Click:Connect(ToggleFlingAll)

Players.PlayerAdded:Connect(function(newPlayer)
    if AutoFlingAllEnabled then
        newPlayer.CharacterAdded:Wait()
        task.wait(1.5)
        SelectedTargets[newPlayer.Name] = newPlayer
        if not FlingActive then Start() end
    end
end)

local function HandleCommand(msg, speaker)
    if not WhitelistedUsers[speaker.Name] then return end
    local args = msg:split(" ")
    local cmd  = args[1]:lower()
    if cmd == ".fling" and args[2] then
        local tn = args[2]:lower()
        if tn == "all" then
            Stop(); task.wait(0.1); SelectedTargets = {}
            for _, p in pairs(Players:GetPlayers()) do if p~=Player and p~=speaker then SelectedTargets[p.Name]=p end end
            getgenv().SinglePass = true; Start()
        else
            local found = nil
            for _, p in pairs(Players:GetPlayers()) do
                if p.Name:lower():sub(1,#tn)==tn or p.DisplayName:lower():sub(1,#tn)==tn then found=p; break end
            end
            if found and found~=Player and found~=speaker then
                Stop(); task.wait(0.1); SelectedTargets={[found.Name]=found}; getgenv().SinglePass=true; Start()
            end
        end
    elseif cmd == ".loopfling" and args[2] then
        local tn = args[2]:lower()
        if tn == "all" then
            if not AutoFlingAllEnabled then ToggleFlingAll() end
        else
            local found = nil
            for _, p in pairs(Players:GetPlayers()) do
                if p.Name:lower():sub(1,#tn)==tn or p.DisplayName:lower():sub(1,#tn)==tn then found=p; break end
            end
            if found and found~=Player and found~=speaker then
                Stop(); task.wait(0.1); SelectedTargets={[found.Name]=found}; getgenv().SinglePass=false; Start()
            end
        end
    elseif (cmd==".unloopfling" or cmd==".stopfling" or cmd==".unfling") and args[2]=="all" then
        if AutoFlingAllEnabled then ToggleFlingAll() end
    elseif cmd==".unfling" or cmd==".unloopfling" then
        Stop()
    end
end

UIS.InputBegan:Connect(function(input, gp)
    if SettingKey then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            FlingKeybind = input.KeyCode; SettingKey = false
        end
        return
    end
    if gp then return end
    if input.KeyCode == FlingKeybind then
        if FlingActive then
            Stop(); SelectedTargets = {}; RefreshList()
        else
            local mouse = UIS:GetMouseLocation()
            local closest, dist = nil, 250
            for _, p in pairs(Players:GetPlayers()) do
                if p~=Player and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                    local pos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(p.Character.HumanoidRootPart.Position)
                    if onScreen then
                        local mag = (Vector2.new(pos.X,pos.Y)-mouse).Magnitude
                        if mag < dist then dist=mag; closest=p end
                    end
                end
            end
            if closest then SelectedTargets={[closest.Name]=closest}; Start(); RefreshList() end
        end
    end
    if input.KeyCode == UI_ToggleKey then MainFrame.Visible = not MainFrame.Visible end
end)

local _refreshDebounce = false
RefreshList = function()
    -- OPTIMASI: Debounce ringan untuk mencegah rebuild berulang
    -- dalam frame yang sama (misalnya saat PlayerAdded + init bersamaan)
    if _refreshDebounce then return end
    _refreshDebounce = true
    task.defer(function() _refreshDebounce = false end)

    for _, v in pairs(PlayerSelection:GetChildren()) do if v:IsA("Frame") then v:Destroy() end end
    for _, p in pairs(Players:GetPlayers()) do
        local dn, un = p.DisplayName:lower(), p.Name:lower()
        if p ~= Player and (dn:find(SearchText) or un:find(SearchText)) then
            local isSel = SelectedTargets[p.Name]
            local Card = makeUI(PlayerSelection, "Frame", {
                Size = UDim2.new(1, -8, 0, 52),
                BackgroundColor3 = isSel and Color3.fromRGB(20,50,25) or Color3.fromRGB(40,40,40),
                BackgroundTransparency = 0.2, BorderSizePixel = 0,
            })
            makeUI(Card, "UICorner", {CornerRadius = UDim.new(0, 8)})
            makeUI(Card, "UIStroke", {
                Thickness = 1, Transparency = 0.3,
                Color = isSel and Color3.fromRGB(50,200,80)
                    or WhitelistedUsers[p.Name] and Color3.fromRGB(0,200,100)
                    or Color3.fromRGB(70,70,70)
            })
            local Thumb = makeUI(Card, "ImageLabel", {
                Size = UDim2.new(0,40,0,40), Position = UDim2.new(0,6,0.5,-20),
                BackgroundColor3 = Color3.fromRGB(20,20,20), BackgroundTransparency = 0.3,
            })
            pcall(function() Thumb.Image = Players:GetUserThumbnailAsync(p.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48) end)
            makeUI(Thumb, "UICorner", {CornerRadius = UDim.new(1, 0)})
            local NameLabel = makeUI(Card, "TextLabel", {
                Size = UDim2.new(1,-60,1,0), Position = UDim2.new(0,54,0,0),
                BackgroundTransparency = 1, RichText = true,
                TextColor3 = Color3.new(1,1,1), Font = Enum.Font.GothamSemibold,
                TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
                TextTruncate = Enum.TextTruncate.AtEnd,
            })
            if NameDisplayMode == "Both" then
                NameLabel.Text = p.DisplayName.."\n<font size='10' color='#AAAAAA'>@"..p.Name.."</font>"
            elseif NameDisplayMode == "Display" then
                NameLabel.Text = p.DisplayName
            else
                NameLabel.Text = "@"..p.Name
            end
            local CardClick = makeUI(Card, "TextButton", {Size=UDim2.new(1,0,1,0), BackgroundTransparency=1, Text="", AutoButtonColor=false})
            CardClick.MouseButton1Click:Connect(function()
                if SelectedTargets[p.Name] then SelectedTargets[p.Name]=nil else SelectedTargets[p.Name]=p end
                RefreshList()
            end)
        end
    end
    PlayerSelection.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y + 8)
end

SearchBox:GetPropertyChangedSignal("Text"):Connect(function() SearchText=SearchBox.Text:lower(); RefreshList() end)
StartBtn.MouseButton1Click:Connect(Start)
StopBtn.MouseButton1Click:Connect(Stop)
SelectAllBtn.MouseButton1Click:Connect(function()
    for _, p in pairs(Players:GetPlayers()) do if p~=Player then SelectedTargets[p.Name]=p end end; RefreshList()
end)
DeselectBtn.MouseButton1Click:Connect(function() SelectedTargets={}; Stop(); RefreshList() end)

for _, p in pairs(Players:GetPlayers()) do p.Chatted:Connect(function(msg) HandleCommand(msg, p) end) end
Players.PlayerAdded:Connect(function(p) p.Chatted:Connect(function(msg) HandleCommand(msg, p) end); RefreshList() end)
Players.PlayerRemoving:Connect(function() task.wait(0.1); RefreshList() end)

MainFrame.Visible = false
isMinimized = true
do
    OpenBtn.AnchorPoint = Vector2.new(0.5, 0.5)
    OpenBtn.Position = UDim2.new(0.5, 0, 0.5, 0)
    local vp = workspace.CurrentCamera.ViewportSize
    bubbleSavedX = math.clamp(vp.X / 2 - 21, 0, vp.X - 42)
    bubbleSavedY = math.clamp(vp.Y / 2 - 21, 0, vp.Y - 42)
    OpenBtn.Visible = ZeroMultiFlingEnabled
end

-- OPTIMASI: Defer semua pemanggilan fungsi berat di akhir init
-- agar main thread tidak tertahan saat script pertama kali selesai load.
-- updateMFDots, UpdateControlCanvas, RefreshList, goToMFPage
-- semua dijadwalkan di frame berikutnya.
task.defer(function()
    updateMFDots()
    UpdateControlCanvas()
    RefreshList()
    goToMFPage(1)
end)

end)()
