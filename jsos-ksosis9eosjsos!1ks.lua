local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local isSmoothPaused = false
local lastFrame, nextFrame

function playNextRecording()
    if nextRecordingIndex then
        task.wait(0.15)
        playRecording(nextRecordingIndex)
    end
end

-- Playback Loop Baru



--[[

-- Integrasi ke playback utama (disisipkan di loop RunService.RenderStepped)



--[[
🔥 PATCH: Playback Rekaman Halus & Kecepatan Dinamis
===================================================
- Animasi rekaman kini tidak kaku (interpolasi posisi halus).
- Kecepatan langkah kaki (WalkSpeed humanoid) otomatis mengikuti kecepatan gerak rekaman.
- Saat pause/jeda playback, karakter diam secara natural tanpa freeze/stuck.
- Bypass Animation kini ikut menyesuaikan kecepatan gerak dan arah.
--]]

function promptInput(message)
    local input = ""
    local done = false
    local coreGuiParent = game:GetService("CoreGui")
    if coreGuiParent:FindFirstChild("PromptInputGui") then
        coreGuiParent:FindFirstChild("PromptInputGui"):Destroy()
    end
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "PromptInputGui"
    ScreenGui.Parent = coreGuiParent
    ScreenGui.DisplayOrder = 20
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local Frame = Instance.new("Frame", ScreenGui)
    Frame.Size = UDim2.new(0, 220, 0, 100)
    Frame.Position = UDim2.new(0.5, -110, 0.5, -50)
    Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
    Frame.BackgroundTransparency = 0.3
    Frame.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner", Frame)
    corner.CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", Frame)
    stroke.Color = Color3.fromRGB(0, 150, 255)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.5

    local TitleLabel = Instance.new("TextLabel", Frame)
    TitleLabel.Size = UDim2.new(1, -30, 0, 20)
    TitleLabel.Position = UDim2.new(0, 10, 0, 5)
    TitleLabel.Text = message
    TitleLabel.TextColor3 = Color3.new(1,1,1)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Font = Enum.Font.SourceSansBold
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

    local CloseButton = Instance.new("TextButton", Frame)
    CloseButton.Name = "CloseButton"
    CloseButton.Size = UDim2.new(0, 20, 0, 20)
    CloseButton.Position = UDim2.new(1, -25, 0, 5)
    CloseButton.BackgroundTransparency = 1
    CloseButton.Font = Enum.Font.SourceSansBold
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextSize = 18
    CloseButton.MouseButton1Click:Connect(function()
        input = "" -- Return empty string on cancel
        done = true
        if ScreenGui and ScreenGui.Parent then ScreenGui:Destroy() end
    end)

    local TextBox = Instance.new("TextBox", Frame)
    TextBox.Size = UDim2.new(1, -20, 0, 25)
    TextBox.Position = UDim2.new(0, 10, 0, 30)
    TextBox.Text = ""
    TextBox.PlaceholderText = "Nama file..."
    TextBox.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    TextBox.TextColor3 = Color3.new(1,1,1)
    local tbCorner = Instance.new("UICorner", TextBox)
    tbCorner.CornerRadius = UDim.new(0, 5)

    local Button = Instance.new("TextButton", Frame)
    Button.Size = UDim2.new(1, -20, 0, 25)
    Button.Position = UDim2.new(0, 10, 1, -30)
    Button.Text = "OK"
    Button.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    Button.TextColor3 = Color3.new(1,1,1)
    Button.Font = Enum.Font.SourceSansBold
    local btnCorner = Instance.new("UICorner", Button)
    btnCorner.CornerRadius = UDim.new(0, 6)

    Button.MouseButton1Click:Connect(function()
        input = TextBox.Text
        done = true
        if ScreenGui and ScreenGui.Parent then ScreenGui:Destroy() end
    end)
    repeat task.wait() until done
    return input
end

function showConfirmationPrompt(message, callback)
    local coreGuiParent = game:GetService("CoreGui")
    if coreGuiParent:FindFirstChild("ConfirmationPromptGUI") then
        coreGuiParent:FindFirstChild("ConfirmationPromptGUI"):Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ConfirmationPromptGUI"
    ScreenGui.Parent = coreGuiParent
    ScreenGui.DisplayOrder = 22 -- Higher than other prompts
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local Frame = Instance.new("Frame", ScreenGui)
    Frame.Size = UDim2.new(0, 220, 0, 100)
    Frame.Position = UDim2.new(0.5, -110, 0.5, -50)
    Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 45)
    Frame.BackgroundTransparency = 0.2
    Frame.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner", Frame); corner.CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", Frame); stroke.Color = Color3.fromRGB(200, 100, 100); stroke.Thickness = 1.5; stroke.Transparency = 0.5

    local TitleLabel = Instance.new("TextLabel", Frame)
    TitleLabel.Size = UDim2.new(1, -20, 0, 50)
    TitleLabel.Position = UDim2.new(0, 10, 0, 5)
    TitleLabel.Text = message
    TitleLabel.TextColor3 = Color3.new(1,1,1)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Font = Enum.Font.SourceSans
    TitleLabel.TextWrapped = true
    TitleLabel.TextSize = 14
    TitleLabel.TextYAlignment = Enum.TextYAlignment.Center

    local function createButton(parent, text, color)
        local btn = Instance.new("TextButton", parent)
        btn.Size = UDim2.new(0.5, -15, 0, 25)
        btn.BackgroundColor3 = color
        btn.TextColor3 = Color3.new(1,1,1)
        btn.Font = Enum.Font.SourceSansBold
        btn.Text = text
        btn.TextSize = 14
        local btnCorner = Instance.new("UICorner", btn); btnCorner.CornerRadius = UDim.new(0, 6)
        return btn
    end

    local yesButton = createButton(Frame, "Ya", Color3.fromRGB(200, 50, 50))
    yesButton.Position = UDim2.new(0, 10, 1, -35)

    local noButton = createButton(Frame, "Tidak", Color3.fromRGB(80, 80, 80))
    noButton.Position = UDim2.new(0.5, 5, 1, -35)

    yesButton.MouseButton1Click:Connect(function()
        if ScreenGui and ScreenGui.Parent then ScreenGui:Destroy() end
        callback(true)
    end)
    noButton.MouseButton1Click:Connect(function()
        if ScreenGui and ScreenGui.Parent then ScreenGui:Destroy() end
        callback(false)
    end)
end

function showRecordingFilePicker(RECORDING_FOLDER, callback)
    local coreGuiParent = game:GetService("CoreGui")
    if coreGuiParent:FindFirstChild("RecordingFilePickerGUI") then
        coreGuiParent:FindFirstChild("RecordingFilePickerGUI"):Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "RecordingFilePickerGUI"
    ScreenGui.Parent = coreGuiParent
    ScreenGui.DisplayOrder = 21 -- Higher than the prompt
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local Frame = Instance.new("Frame", ScreenGui)
    Frame.Size = UDim2.new(0, 250, 0, 300)
    Frame.Position = UDim2.new(0.5, -125, 0.5, -150)
    Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
    Frame.BackgroundTransparency = 0.3
    Frame.BorderSizePixel = 0
    
    local corner = Instance.new("UICorner", Frame)
    corner.CornerRadius = UDim.new(0, 8)
    local stroke = Instance.new("UIStroke", Frame)
    stroke.Color = Color3.fromRGB(0, 150, 255)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.5

    local TitleLabel = Instance.new("TextLabel", Frame)
    TitleLabel.Size = UDim2.new(1, -30, 0, 25)
    TitleLabel.Position = UDim2.new(0, 10, 0, 5)
    TitleLabel.Text = "Pilih File Rekaman"
    TitleLabel.TextColor3 = Color3.new(1,1,1)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Font = Enum.Font.SourceSansBold
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

    local CloseButton = Instance.new("TextButton", Frame)
    CloseButton.Name = "CloseButton"
    CloseButton.Size = UDim2.new(0, 20, 0, 20)
    CloseButton.Position = UDim2.new(1, -25, 0, 5)
    CloseButton.BackgroundTransparency = 1
    CloseButton.Font = Enum.Font.SourceSansBold
    CloseButton.Text = "X"
    CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseButton.TextSize = 18
    CloseButton.MouseButton1Click:Connect(function()
        if ScreenGui and ScreenGui.Parent then ScreenGui:Destroy() end
    end)

    local SearchBox = Instance.new("TextBox", Frame)
    SearchBox.Size = UDim2.new(1, -20, 0, 25)
    SearchBox.Position = UDim2.new(0, 10, 0, 35)
    SearchBox.PlaceholderText = "Cari nama file..."
    SearchBox.Text = ""
    SearchBox.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    SearchBox.TextColor3 = Color3.new(1,1,1)
    SearchBox.ClearTextOnFocus = false
    local sbCorner = Instance.new("UICorner", SearchBox)
    sbCorner.CornerRadius = UDim.new(0, 5)

    local FileListContainer = Instance.new("ScrollingFrame", Frame)
    FileListContainer.Size = UDim2.new(1, -20, 1, -75)
    FileListContainer.Position = UDim2.new(0, 10, 0, 70)
    FileListContainer.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    FileListContainer.BackgroundTransparency = 0.5
    FileListContainer.BorderSizePixel = 0
    FileListContainer.ScrollBarThickness = 6
    FileListContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    local flcCorner = Instance.new("UICorner", FileListContainer)
    flcCorner.CornerRadius = UDim.new(0, 4)

    local FileListLayout = Instance.new("UIListLayout", FileListContainer)
    FileListLayout.Padding = UDim.new(0, 5)
    FileListLayout.SortOrder = Enum.SortOrder.Name
    local FileListPadding = Instance.new("UIPadding", FileListContainer)
    FileListPadding.PaddingLeft = UDim.new(0, 5)
    FileListPadding.PaddingRight = UDim.new(0, 5)
    FileListPadding.PaddingTop = UDim.new(0, 5)

    local fileButtons = {}

    local function populateFiles(filter)
        filter = filter and filter:lower() or ""
        for _, child in ipairs(FileListContainer:GetChildren()) do
            if not (child:IsA("UIListLayout") or child:IsA("UIPadding")) then
                child:Destroy()
            end
        end
        
        if not listfiles or not isfolder or not isfolder(RECORDING_FOLDER) then
            local noFilesLabel = Instance.new("TextLabel", FileListContainer)
            noFilesLabel.Size = UDim2.new(1, 0, 0, 25)
            noFilesLabel.Text = "Folder 'Rekaman' tidak ditemukan."
            noFilesLabel.TextColor3 = Color3.fromRGB(255, 180, 180)
            noFilesLabel.BackgroundTransparency = 1
            return
        end

        local files = listfiles(RECORDING_FOLDER)
        local filesFound = 0
        for _, fullPath in ipairs(files) do
            local fileName = fullPath:match("([^/]+)$") or fullPath
            if fileName:lower():match(".json$") and (filter == "" or fileName:lower():find(filter, 1, true)) then
                filesFound = filesFound + 1
                local itemFrame = Instance.new("Frame", FileListContainer)
                itemFrame.Name = fileName
                itemFrame.Size = UDim2.new(1, 0, 0, 25)
                itemFrame.BackgroundTransparency = 1

                local itemLayout = Instance.new("UIListLayout", itemFrame)
                itemLayout.FillDirection = Enum.FillDirection.Horizontal
                itemLayout.VerticalAlignment = Enum.VerticalAlignment.Center
                itemLayout.Padding = UDim.new(0, 4)

                local fileButton = Instance.new("TextButton", itemFrame)
                fileButton.Size = UDim2.new(1, -30, 1, 0)
                fileButton.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
                fileButton.Text = fileName:gsub(".json", "")
                fileButton.TextColor3 = Color3.new(1,1,1)
                fileButton.Font = Enum.Font.SourceSans
                fileButton.TextXAlignment = Enum.TextXAlignment.Left
                local textPadding = Instance.new("UIPadding", fileButton); textPadding.PaddingLeft = UDim.new(0, 5)
                fileButton.TextSize = 12
                local btnCorner = Instance.new("UICorner", fileButton)
                btnCorner.CornerRadius = UDim.new(0, 4)

                local deleteButton = Instance.new("TextButton", itemFrame)
                deleteButton.Size = UDim2.new(0, 25, 0, 22)
                deleteButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                deleteButton.Text = "🗑️"
                deleteButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                deleteButton.Font = Enum.Font.SourceSansBold
                deleteButton.TextSize = 14
                local delCorner = Instance.new("UICorner", deleteButton)
                delCorner.CornerRadius = UDim.new(0, 4)

                fileButton.MouseButton1Click:Connect(function()
                    callback(fileName:gsub(".json", ""))
                    if ScreenGui and ScreenGui.Parent then ScreenGui:Destroy() end
                end)
                
                deleteButton.MouseButton1Click:Connect(function()
                    showConfirmationPrompt("Yakin ingin menghapus '"..fileName:gsub(".json", "").."'?", function(confirmed)
                        if confirmed then
                            local filePath = RECORDING_FOLDER .. "/" .. fileName
                            if isfile and isfile(filePath) and delfile then
                                local success, err = pcall(delfile, filePath)
                                if not success then showNotification("Gagal menghapus file: "..err, Color3.fromRGB(200,50,50)) end
                                populateFiles(SearchBox.Text) -- Refresh list
                            end
                        end
                    end)
                end)
            end
        end

        if filesFound == 0 then
             local noFilesLabel = Instance.new("TextLabel", FileListContainer)
            noFilesLabel.Size = UDim2.new(1, 0, 0, 25)
            noFilesLabel.Text = (filter == "") and "Tidak ada file rekaman." or "File tidak ditemukan."
            noFilesLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            noFilesLabel.BackgroundTransparency = 1
        end
    end

    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        populateFiles(SearchBox.Text)
    end)

    populateFiles("") -- Initial population

    FileListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        FileListContainer.CanvasSize = UDim2.new(0, 0, 0, FileListLayout.AbsoluteContentSize.Y + 10)
    end)
end

local SCRIPT_URL = "https://raw.githubusercontent.com/AREXANS/emoteff/refs/heads/main/Arexanstools.lua" -- << WAJIB DIISI!

-- Mencegah GUI dibuat berulang kali jika skrip dieksekusi lebih dari sekali tanpa me-refresh game.
if game:GetService("CoreGui"):FindFirstChild("ArexanstoolsGUI") then
    game:GetService("CoreGui"):FindFirstChild("ArexanstoolsGUI"):Destroy()
end
if game:GetService("CoreGui"):FindFirstChild("ArexansSpectatorGUI") then
    game:GetService("CoreGui"):FindFirstChild("ArexansSpectatorGUI"):Destroy()
end
if game:GetService("CoreGui"):FindFirstChild("FlingStatusGUI") then
    game:GetService("CoreGui"):FindFirstChild("FlingStatusGUI"):Destroy()
end
-- [[ PERUBAHAN BARU: Hapus GUI spectate lokasi jika ada ]]
if game:GetService("CoreGui"):FindFirstChild("ArexansLocationSpectatorGUI") then
    game:GetService("CoreGui"):FindFirstChild("ArexansLocationSpectatorGUI"):Destroy()
end


task.spawn(function()
    -- ====================================================================
    -- == BAGIAN OTENTIKASI DAN INISIALISASI                           ==
    -- ====================================================================
    local HttpService = game:GetService("HttpService")
    local CoreGui = game:GetService("CoreGui")
    local currentUserRole = "Normal" -- << [NEW] Role variable

    -- << [NEW] Permission checking function
    local function hasPermission(requiredRole)
        local hierarchy = {Free = 1, Normal = 2, VIP = 3, Developer = 4}
        local userLevel = hierarchy[currentUserRole] or 1
        local requiredLevel = hierarchy[requiredRole] or 1
        return userLevel >= requiredLevel
    end

    local function parseISO8601(iso)
        local y, mo, d, h, mi, s = iso:match("^(%d%d%d%d)-(%d%d)-(%d%d)T(%d%d):(%d%d):(%d%d)")
        if not y then return nil end
        -- os.time in Roblox is UTC
        return os.time({year=tonumber(y), month=tonumber(mo), day=tonumber(d), hour=tonumber(h), min=tonumber(mi), sec=tonumber(s)})
    end

    -- [[ PERUBAHAN BESAR: Pengelola Koneksi untuk Total Shutdown ]]
    local AllConnections = {}
    local function ConnectEvent(event, func)
        local conn = event:Connect(func)
        table.insert(AllConnections, conn)
        return conn
    end

    -- [[ FUNGSI DRAGGABLE YANG DI-REFACTOR UNTUK KENYAMANAN PENGGUNA ]] --
    local function MakeDraggable(guiObject, dragHandle, isDraggableCheck, clickCallback)
        local UserInputService = game:GetService("UserInputService")
        local dragInput = nil
        local dragStart = nil
        local startPos = nil
        local wasDragged = false

        ConnectEvent(dragHandle.InputBegan, function(input)
            if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then return end
            if dragInput then return end

            if isDraggableCheck and not isDraggableCheck() then
                if clickCallback then
                    -- Periksa lagi untuk memastikan ini bukan event yang tidak diinginkan
                    local timeSinceBegan = tick()
                    local endedConn
                    endedConn = UserInputService.InputEnded:Connect(function(endInput)
                        if endInput.UserInputType == input.UserInputType then
                            if tick() - timeSinceBegan < 0.2 then -- Hanya panggil jika itu klik cepat
                                clickCallback()
                            end
                            if endedConn then endedConn:Disconnect() end
                        end
                    end)
                end
                return
            end
            
            dragInput = input
            dragStart = input.Position
            startPos = guiObject.Position
            wasDragged = false
        end)

        ConnectEvent(UserInputService.InputChanged, function(input)
            if dragInput and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local newPos = input.Position
                local delta = newPos - dragStart
                guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                if not wasDragged and delta.Magnitude > 5 then -- Threshold untuk dianggap sebagai seretan
                    wasDragged = true
                end
            end
        end)

        ConnectEvent(UserInputService.InputEnded, function(input)
            if dragInput and input.UserInputType == dragInput.UserInputType then
                if not wasDragged and clickCallback then
                    clickCallback()
                end
                -- Simpan posisi GUI setelah diseret
                if wasDragged and saveGuiPositions then
                    pcall(saveGuiPositions)
                end
                dragInput = nil
            end
        end)
    end

    -- [PERUBAHAN] Variabel path file dipindahkan ke lingkup luar
    local SAVE_FOLDER = "ArexansTools"
    if isfolder and not isfolder(SAVE_FOLDER) then
        pcall(makefolder, SAVE_FOLDER)
    end
    local RECORDING_FOLDER = SAVE_FOLDER .. "/Rekaman"
    if isfolder and not isfolder(RECORDING_FOLDER) then
        pcall(makefolder, RECORDING_FOLDER)
    end
    local TELEPORT_SAVE_FILE = SAVE_FOLDER .. "/ArexansTools_Teleports_" .. tostring(game.PlaceId) .. ".json"
    local GUI_POSITIONS_SAVE_FILE = SAVE_FOLDER .. "/ArexansTools_GuiPositions_" .. tostring(game.PlaceId) .. ".json"
    local FEATURE_STATES_SAVE_FILE = SAVE_FOLDER .. "/ArexansTools_FeatureStates_" .. tostring(game.PlaceId) .. ".json"
    local ANIMATION_SAVE_FILE = SAVE_FOLDER .. "/ArexansTools_Animations.json"
    local EMOTE_FAVORITES_SAVE_FILE = SAVE_FOLDER .. "/EmoteFavorites.json" -- [[ PERUBAHAN BARU ]]
    local RECORDING_SAVE_FILE = SAVE_FOLDER .. "/ArexansTools_Recordings_" .. tostring(game.PlaceId) .. ".json" -- [[ PERUBAHAN BARU ]]
    local SESSION_SAVE_FILE = SAVE_FOLDER .. "/ArexansTools_Session.json"

    -- [[ PERUBAHAN BARU: Variabel dan fungsi untuk favorit emote ]]
    local favoriteEmotes = {}

    local function saveFavorites()
        if not writefile then return end
        pcall(function()
            writefile(EMOTE_FAVORITES_SAVE_FILE, HttpService:JSONEncode(favoriteEmotes))
        end)
    end

    local function loadFavorites()
        if not readfile or not isfile or not isfile(EMOTE_FAVORITES_SAVE_FILE) then return end
        local success, result = pcall(function()
            local content = readfile(EMOTE_FAVORITES_SAVE_FILE)
            local data = HttpService:JSONDecode(content)
            if type(data) == "table" then
                favoriteEmotes = data
            end
        end)
        if not success then
            warn("Gagal memuat favorit emote:", result)
        end
    end

    -- [[ PERUBAHAN BARU: Fungsi untuk mengelola sesi login dipindahkan ke lingkup luar ]]
    local function saveSession(expirationTimestamp, userRole, userPassword)
        if not writefile then return end
        local sessionData = {
            expiration = expirationTimestamp,
            role = userRole,
            password = userPassword
        }
        pcall(function()
            writefile(SESSION_SAVE_FILE, HttpService:JSONEncode(sessionData))
        end)
    end

    local function loadSession()
        if not readfile or not isfile or not isfile(SESSION_SAVE_FILE) then
            return nil, nil, nil -- No session file
        end
        local success, content = pcall(readfile, SESSION_SAVE_FILE)
        if not success then return nil, nil, nil end

        local success, data = pcall(HttpService.JSONDecode, HttpService, content)
        if not success or type(data) ~= "table" then return nil, nil, nil end

        -- Return password even if expired, but return nil for expiration and role if it is.
        if data.password then
            if data.expiration and os.time() < data.expiration then
                return data.expiration, data.role or "Normal", data.password
            else
                -- Session expired, but we still have a password to re-validate
                return nil, nil, data.password
            end
        end

        return nil, nil, nil -- No password in session
    end

    local function deleteSession()
        if isfile and isfile(SESSION_SAVE_FILE) and delfile then
            pcall(delfile, SESSION_SAVE_FILE)
        end
    end

    -- Moved all these declarations to the higher scope to fix "out of local registers" error
    local Players, UserInputService, RunService, Workspace, LocalPlayer, TweenService, Lighting, MaterialService, TeleportService
    local Settings, IsFlying, IsNoclipEnabled, IsGodModeEnabled, IsWalkSpeedEnabled, OriginalWalkSpeed, FlyConnections, godModeConnection, IsInfinityJumpEnabled, infinityJumpConnection, PlayerButtons, CurrentPlayerFilter, touchFlingGui, isUpdatingPlayerList, isMiniToggleDraggable, IsAntiLagEnabled, antiLagConnection, IsShiftLockEnabled, shiftLockConnection
    local IsFEInvisibleEnabled, feInvisSeat, IsEspNameEnabled, IsEspBodyEnabled, EspRenderConnection, espCache, IsBoostFPSEnabled, boostFpsOriginalSettings, boostFpsDescendantConnection, IsAntiAFKEnabled, antiAFKConnection
    local IsViewingPlayer, viewingPlayerConnection, currentlyViewedPlayer, SpectatorGui, originalPlayerCFrame, originalCameraSubject
    local isSpectatingLocation, spectateLocationGui, originalCameraProperties, spectateCameraConnections, areTeleportIconsVisible, isAutoLooping
    local isEmoteToggleDraggable, isAnimationToggleDraggable, isEmoteTransparent, isAnimationTransparent
    local isMagnetActive, magnetPower, magnetRange, magnetConnection, scannedParts, partGoals, scanCenterPosition, magnetMode, MagnetGUI
    local PartControllerGUI, pc_config, pc_state, PC_MODES
    local savedTeleportLocations, loadedGuiPositions, originalCharacterAppearance
    local antifling_velocity_threshold, antifling_angular_threshold, antifling_last_safe_cframe, antifling_enabled, antifling_connection
    local currentFlingTarget, flingLoopConnection, flingStartPosition, flingStatusGui
    local isRecording, isPlaying, recordingConnection, playbackConnection, savedRecordings, currentRecordingData, loadedRecordingName, currentRecordingTarget
    local isCopyingMovement, copiedPlayer, copyMovementConnection, copyAnimationCache, copyMovementMovers
    local isEmoteEnabled, EmoteScreenGui, isAnimationEnabled, AnimationScreenGui, lastAnimations
    local ScreenGui, MiniToggleContainer, MiniToggleButton, EmoteToggleButton, AnimationShowButton, MainFrame, TitleBar, ExpirationLabel, TabsFrame, ContentFrame
    local PlayerTabContent, PlayerListContainer, GeneralTabContent, TeleportTabContent, VipTabContent, SettingsTabContent, RekamanTabContent
    local PlayerListLayout, GeneralListLayout, TeleportListLayout, VipListLayout, SettingsListLayout, RekamanListLayout
    local setupPlayerTab, setupGeneralTab, setupTeleportTab, setupVipTab, setupSettingsTab, setupRekamanTab
    local startRecording, stopRecording, stopActions, stopPlayback

    local function InitializeMainGUI(expirationTimestamp, userRole)
        currentUserRole = userRole
        -- Layanan dan Variabel Global
        Players = game:GetService("Players")
        UserInputService = game:GetService("UserInputService")
        RunService = game:GetService("RunService")
        Workspace = game:GetService("Workspace")
        LocalPlayer = Players.LocalPlayer
        TweenService = game:GetService("TweenService")
        Lighting = game:GetService("Lighting")
        MaterialService = game:GetService("MaterialService")
        TeleportService = game:GetService("TeleportService")
    
        -- Pengaturan Default
        Settings = {
            FlySpeed = 1,
            WalkSpeed = 16,
            MaxFlySpeed = 10,
            MaxWalkSpeed = 500,
            TeleportDistance = 100,
            FEInvisibleTransparency = 0.75,
        }
    
        -- Variabel Status
        IsFlying = false
        IsNoclipEnabled = false
        IsGodModeEnabled = false 
        IsWalkSpeedEnabled = false
        OriginalWalkSpeed = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") and LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed or 16
        FlyConnections = {}
        godModeConnection = nil 
        IsInfinityJumpEnabled = false
        infinityJumpConnection = nil
        PlayerButtons = {} -- Cache untuk elemen UI pemain
        CurrentPlayerFilter = ""
        touchFlingGui = nil
        isUpdatingPlayerList = false 
        isMiniToggleDraggable = true 
        IsAntiLagEnabled = false 
        antiLagConnection = nil 
        IsShiftLockEnabled = false
        shiftLockConnection = nil
        IsAntiAFKEnabled = false
        antiAFKConnection = nil
    
        -- [[ FE INVISIBLE INTEGRATION ]]
        IsFEInvisibleEnabled = false
        feInvisSeat = nil
        -- [[ END FE INVISIBLE INTEGRATION ]]

        -- [[ PERUBAHAN DIMULAI: Variabel ESP dipisahkan ]]
        IsEspNameEnabled = false
        IsEspBodyEnabled = false
        -- [[ PERUBAHAN SELESAI ]]
        EspRenderConnection = nil
        espCache = {} -- Cache untuk elemen GUI ESP agar tidak dibuat ulang terus-menerus
    
        -- [[ INTEGRASI BOOST FPS ]] --
        IsBoostFPSEnabled = false
        boostFpsOriginalSettings = {}
        boostFpsDescendantConnection = nil
    
        -- [[ VARIABEL VIEW PLAYER ]] --
        IsViewingPlayer = false
        viewingPlayerConnection = nil
        currentlyViewedPlayer = nil
        SpectatorGui = nil
        originalPlayerCFrame = nil -- Untuk menyimpan CFrame asli pemain
        originalCameraSubject = nil -- Untuk menyimpan subjek kamera asli
    
        -- [[ PERUBAHAN BARU: Variabel untuk Spectate Lokasi ]]
        isSpectatingLocation = false
        spectateLocationGui = nil
        originalCameraProperties = {}
        spectateCameraConnections = {}
        areTeleportIconsVisible = true
        isAutoLooping = false
    
        isEmoteToggleDraggable = true
        isAnimationToggleDraggable = true

        isEmoteTransparent = true
        isAnimationTransparent = true

        -- [[ AWAL INTEGRASI MAGNET.LUA ]]
        isMagnetActive = false
        magnetPower = 999
        magnetRange = 150
        magnetConnection = nil
        scannedParts = {}
        partGoals = {}
        scanCenterPosition = Vector3.zero
        magnetMode = "target_player" -- "target_player" atau "random_free"
        MagnetGUI = nil
        -- [[ AKHIR INTEGRASI MAGNET.LUA ]]

        -- [[ AWAL INTEGRASI PARTCONTROLLER.LUA ]]
        PartControllerGUI = nil
        pc_config = {
            partLimit = 100,
            radius = 150,
            magnetForce = 1000000,
            speed = 5,
            launchSpeed = 100,
            updateRate = 0.03,
            batchSize = 10
        }
        pc_state = {
            mode = "bring",
            active = false,
            parts = {},
            originalProperties = {},
            removedItems = {},
            timeOffset = 0,
            connection = nil,
            bodyPositions = {},
            currentModeIndex = 1
        }
        PC_MODES = {
            {n="Bring",v="bring"}, {n="Ring",v="ring"}, {n="Tornado",v="tornado"},
            {n="Blackhole",v="blackhole"}, {n="Orbit",v="orbit"}, {n="Spiral",v="spiral"},
            {n="Wave",v="wave"}, {n="Fountain",v="fountain"}, {n="Shield",v="shield"},
            {n="Sphere",v="sphere"}, {n="Launch",v="launch"}, {n="Explosion",v="explosion"},
            {n="Galaxy",v="galaxy"}, {n="DNA",v="dna"}, {n="Supernova",v="supernova"},
            {n="Matrix",v="matrix"}, {n="Vortex",v="vortex"}, {n="Meteor",v="meteor"},
            {n="Portal",v="portal"}, {n="Dragon",v="dragon"}, {n="Infinity",v="infinity"},
            {n="Tsunami",v="tsunami"}, {n="Solar",v="solar"}, {n="Quantum",v="quantum"}
        }
        -- [[ AKHIR INTEGRASI PARTCONTROLLER.LUA ]]

        -- Variabel Teleport
        savedTeleportLocations = {}
    
        -- Variabel untuk menyimpan posisi GUI
        loadedGuiPositions = nil
    
        -- Variabel untuk menyimpan status fitur
    
        -- Variabel untuk menyimpan data original karakter saat invisible
        originalCharacterAppearance = {}

        -- Variabel AntiFling
        antifling_velocity_threshold = 85
        antifling_angular_threshold = 25
        antifling_last_safe_cframe = nil
        antifling_enabled = false
        antifling_connection = nil
    
        -- [[ VARIABEL UNTUK FITUR FLING ]] --
        currentFlingTarget = nil
        flingLoopConnection = nil
        flingStartPosition = nil 
        flingStatusGui = nil 

        -- [[ VARIABEL UNTUK FITUR REKAMAN ]] --
        isRecording = false
        isPlaying = false
        recordingConnection = nil
        playbackConnection = nil
        savedRecordings = {}
        currentRecordingData = {}
        loadedRecordingName = nil
        currentRecordingTarget = nil -- [[ PERUBAHAN BARU ]]

        -- [[ VARIABEL UNTUK FITUR COPY MOVEMENT ]] --
        isCopyingMovement = false
        copiedPlayer = nil
        copyMovementConnection = nil
        copyAnimationCache = {}
        copyMovementMovers = {}

        -- [[ VARIABEL UNTUK FITUR KUNCI KECEPATAN ]] --
        local speedLock_currentSpeed = 16
        local speedLock_humanoid = nil
        local speedLock_isEnforced = false
        local speedLock_isPaused = false
        local speedLock_connections = {}
        local speedLock_lastTick = 0
        local speedLock_tickInterval = 0.12
        local speedLock_serverBaseline = nil
    
        -- ====================================================================
        -- == VARIABEL UNTUK FITUR EMOTE DAN ANIMASI (DIPISAHKAN)          ==
        -- ====================================================================
        isEmoteEnabled = false
        EmoteScreenGui = nil
        isAnimationEnabled = false 
        AnimationScreenGui = nil
        local isGameAnimationOverrideActive = false -- [BARU] Lacak jika game menimpa animasi
    
        -- Variabel Global untuk menyimpan animasi
        lastAnimations = {}

        -- Membuat GUI utama
        ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ArexanstoolsGUI"
    ScreenGui.Parent = CoreGui
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.ResetOnSpawn = false
    ScreenGui.DisplayOrder = 10 -- [PERBAIKAN] Atur agar selalu di depan

    -- Kontainer untuk semua tombol mini
    local MiniToggleContainer = Instance.new("Frame") -- Diubah dari TextButton ke Frame
    MiniToggleContainer.Name = "MiniToggleContainer"
    MiniToggleContainer.AnchorPoint = Vector2.new(1, 0.5)
    MiniToggleContainer.Position = UDim2.new(1, -25, 0.5, -7.5) 
    MiniToggleContainer.BackgroundTransparency = 1
    MiniToggleContainer.BorderSizePixel = 0
    MiniToggleContainer.AutomaticSize = Enum.AutomaticSize.X
    MiniToggleContainer.Size = UDim2.new(0,0,0,25) 
    MiniToggleContainer.Parent = ScreenGui
    
    local MiniToggleLayout = Instance.new("UIListLayout")
    MiniToggleLayout.FillDirection = Enum.FillDirection.Horizontal
    MiniToggleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    MiniToggleLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    MiniToggleLayout.SortOrder = Enum.SortOrder.LayoutOrder
    MiniToggleLayout.Padding = UDim.new(0, 5)
    MiniToggleLayout.Parent = MiniToggleContainer
    
    -- Tombol toggle utama
    local MiniToggleButton = Instance.new("TextButton")
    MiniToggleButton.Name = "MiniToggleButton"
    MiniToggleButton.LayoutOrder = 1
    MiniToggleButton.Size = UDim2.new(0, 30, 0, 30) 
    MiniToggleButton.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    MiniToggleButton.BackgroundTransparency = 1
    MiniToggleButton.BorderSizePixel = 0
    MiniToggleButton.Text = "◀"
    MiniToggleButton.TextColor3 = Color3.fromRGB(0, 200, 255)
    MiniToggleButton.TextSize = 18 
    MiniToggleButton.Font = Enum.Font.SourceSansBold
    MiniToggleButton.Parent = MiniToggleContainer
    
    local MiniUICorner = Instance.new("UICorner", MiniToggleButton)
    MiniUICorner.CornerRadius = UDim.new(0, 8)
    
    local MiniUIStroke = Instance.new("UIStroke", MiniToggleButton)
    MiniUIStroke.Color = Color3.fromRGB(0, 150, 255)
    MiniUIStroke.Thickness = 2
    MiniUIStroke.Transparency = 0.5
    MiniUIStroke.Parent = MiniToggleButton
    
    -- Tombol toggle Emote (🤡)
    local EmoteToggleButton = Instance.new("TextButton")
    EmoteToggleButton.Name = "EmoteToggleButton"
    EmoteToggleButton.LayoutOrder = 2
    EmoteToggleButton.Size = UDim2.new(0, 25, 0, 25)
    EmoteToggleButton.BackgroundColor3 = Color3.fromRGB(48, 63, 90)
    EmoteToggleButton.BorderColor3 = Color3.fromRGB(90, 150, 255)
    EmoteToggleButton.BorderSizePixel = 1
    EmoteToggleButton.Font = Enum.Font.GothamBold
    EmoteToggleButton.Text = "🤡"
    EmoteToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    EmoteToggleButton.TextSize = 24
    EmoteToggleButton.Visible = false
    EmoteToggleButton.Parent = MiniToggleContainer
    local EmoteToggleCorner = Instance.new("UICorner", EmoteToggleButton)
    EmoteToggleCorner.CornerRadius = UDim.new(0, 8)
    
    -- Tombol toggle Animasi (😀)
    local AnimationShowButton = Instance.new("TextButton")
    AnimationShowButton.Name = "AnimationShowButton"
    AnimationShowButton.LayoutOrder = 3
    AnimationShowButton.Size = UDim2.new(0, 25, 0, 25)
    AnimationShowButton.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    AnimationShowButton.BackgroundTransparency = 0.3
    AnimationShowButton.Font = Enum.Font.SourceSansBold
    AnimationShowButton.Text = "😀"
    AnimationShowButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    AnimationShowButton.TextScaled = true
    AnimationShowButton.Visible = false
    AnimationShowButton.Parent = MiniToggleContainer
    local AnimationToggleCorner = Instance.new("UICorner", AnimationShowButton)
    AnimationToggleCorner.CornerRadius = UDim.new(0.5, 0)

    
    -- Frame GUI utama
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 200, 0, 280) -- Ukuran diperkecil
    MainFrame.Position = UDim2.new(0.5, -100, 0.5, -140) -- Posisi disesuaikan
    MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    MainFrame.BackgroundTransparency = 0.5
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    MainFrame.Visible = false
    
    local MainUICorner = Instance.new("UICorner")
    MainUICorner.CornerRadius = UDim.new(0, 8)
    MainUICorner.Parent = MainFrame
    
    local UIStroke = Instance.new("UIStroke")
    UIStroke.Color = Color3.fromRGB(0, 150, 255)
    UIStroke.Thickness = 2
    UIStroke.Transparency = 0.5
    UIStroke.Parent = MainFrame

    -- [[ PERUBAHAN BARU: Pegangan untuk mengubah ukuran jendela utama ]]
    local MainResizeHandle = Instance.new("TextButton")
    MainResizeHandle.Name = "MainResizeHandle"
    MainResizeHandle.Text = ""
    MainResizeHandle.Size = UDim2.new(0, 15, 0, 15)
    MainResizeHandle.Position = UDim2.new(1, -15, 1, -15)
    MainResizeHandle.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    MainResizeHandle.BackgroundTransparency = 0.5
    MainResizeHandle.BorderSizePixel = 0
    MainResizeHandle.ZIndex = 2 -- Pastikan di atas konten lain
    MainResizeHandle.Parent = MainFrame
    
    local TitleBar = Instance.new("TextButton")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 30)
    TitleBar.Position = UDim2.new(0, 0, 0, 0)
    TitleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    TitleBar.BorderSizePixel = 0
    TitleBar.Text = ""
    TitleBar.AutoButtonColor = false
    TitleBar.Parent = MainFrame
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "TitleLabel"
    TitleLabel.Size = UDim2.new(1, 0, 1, 0)
    TitleLabel.Position = UDim2.new(0, 0, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Font = Enum.Font.SourceSansBold
    TitleLabel.TextSize = 14
    TitleLabel.Parent = TitleBar
    
    -- << [NEW] Role Display
    local roleColors = {Normal = Color3.fromRGB(0, 255, 0), VIP = Color3.fromRGB(170, 0, 255), Developer = Color3.fromRGB(0, 170, 255), Free = Color3.fromRGB(128, 128, 128)}
    local roleColor = roleColors[currentUserRole] or Color3.fromRGB(255, 255, 255)
    
    TitleLabel.Text = "Arexans Tools"
    TitleLabel.TextColor3 = Color3.fromRGB(0, 170, 255)
    TitleLabel.TextXAlignment = Enum.TextXAlignment.Center

    local RoleLabel = Instance.new("TextButton")
    RoleLabel.Name = "RoleLabel"
    RoleLabel.BackgroundTransparency = 1
    RoleLabel.Font = Enum.Font.SourceSansBold
    RoleLabel.Text = currentUserRole
    RoleLabel.TextColor3 = roleColor
    RoleLabel.TextSize = 12
    RoleLabel.TextXAlignment = Enum.TextXAlignment.Left
    RoleLabel.Size = UDim2.new(0, 60, 1, 0)
    RoleLabel.Position = UDim2.new(0, 5, 0, 0)
    RoleLabel.Parent = TitleBar
    RoleLabel.AutoButtonColor = false

    local InfoButton = Instance.new("TextButton")
    InfoButton.Name = "InfoButton"
    InfoButton.Size = UDim2.new(0, 20, 0, 20)
    InfoButton.Position = UDim2.new(1, -25, 0.5, -10)
    InfoButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    InfoButton.Text = "i"
    InfoButton.Font = Enum.Font.SourceSansBold
    InfoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    InfoButton.TextSize = 14
    local infoCorner = Instance.new("UICorner", InfoButton)
    infoCorner.CornerRadius = UDim.new(1, 0)
    InfoButton.Parent = TitleBar

    InfoButton.MouseButton1Click:Connect(function()
        task.spawn(function()
            local success, infoScript = pcall(function()
                return game:HttpGet("https://raw.githubusercontent.com/AREXANS/emoteff/refs/heads/main/info.lua")
            end)
            if success and infoScript then
                pcall(loadstring(infoScript))
            else
                warn("Gagal memuat atau menjalankan script info.")
            end
        end)
    end)

    -- ExpirationLabel is now a child of MainFrame, positioned below the TitleBar
    local ExpirationLabel = Instance.new("TextLabel")
    ExpirationLabel.Name = "ExpirationLabel"
    ExpirationLabel.Size = UDim2.new(1, 0, 0, 15)
    ExpirationLabel.Position = UDim2.new(0, 0, 0, 30) -- Positioned at Y=30, just below the TitleBar
    ExpirationLabel.BackgroundTransparency = 1
    ExpirationLabel.Text = "..."
    ExpirationLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    ExpirationLabel.TextSize = 10
    ExpirationLabel.Font = Enum.Font.SourceSans
    ExpirationLabel.Parent = MainFrame
    
    local TabsFrame = Instance.new("ScrollingFrame")
    TabsFrame.Name = "TabsFrame"
    TabsFrame.Size = UDim2.new(0, 60, 1, -45) -- Lebar diperkecil
    TabsFrame.Position = UDim2.new(0, 0, 0, 45) -- Y position adjusted for the 15px ExpirationLabel
    TabsFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    TabsFrame.BorderSizePixel = 0
    TabsFrame.Parent = MainFrame
    TabsFrame.ScrollingDirection = Enum.ScrollingDirection.Y
    TabsFrame.ScrollBarThickness = 0
    TabsFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255)
    
    local TabListLayout = Instance.new("UIListLayout")
    TabListLayout.Name = "TabListLayout"
    TabListLayout.Padding = UDim.new(0, 5)
    TabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    TabListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    TabListLayout.FillDirection = Enum.FillDirection.Vertical
    TabListLayout.Parent = TabsFrame

    local TabPadding = Instance.new("UIPadding", TabsFrame)
    TabPadding.PaddingTop = UDim.new(0, 5)
    TabPadding.PaddingBottom = UDim.new(0, 5)

    TabListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        TabsFrame.CanvasSize = UDim2.new(0, 0, 0, TabListLayout.AbsoluteContentSize.Y)
    end)
    
    local ContentFrame = Instance.new("Frame")
    ContentFrame.Name = "ContentFrame"
    ContentFrame.Size = UDim2.new(1, -60, 1, -45) -- Disesuaikan dengan TabsFrame
    ContentFrame.Position = UDim2.new(0, 60, 0, 45) -- Disesuaikan dengan TabsFrame
    ContentFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.BorderSizePixel = 0
    ContentFrame.Parent = MainFrame
    
    -- Frame konten tab
    local PlayerTabContent = Instance.new("Frame")
    PlayerTabContent.Name = "PlayerTab"
    PlayerTabContent.Size = UDim2.new(1, -10, 1, -10)
    PlayerTabContent.Position = UDim2.new(0, 5, 0, 5)
    PlayerTabContent.BackgroundTransparency = 1
    PlayerTabContent.Visible = false
    PlayerTabContent.Parent = ContentFrame
    
    local PlayerListContainer = Instance.new("ScrollingFrame")
    PlayerListContainer.Name = "PlayerListContainer"
    PlayerListContainer.Size = UDim2.new(1, 0, 1, -55)
    PlayerListContainer.Position = UDim2.new(0, 0, 0, 55)
    PlayerListContainer.BackgroundTransparency = 1
    PlayerListContainer.CanvasSize = UDim2.new(0, 0, 0, 0)
    PlayerListContainer.ScrollBarThickness = 4
    PlayerListContainer.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255)
    PlayerListContainer.ElasticBehavior = Enum.ElasticBehavior.Never
    PlayerListContainer.VerticalScrollBarInset = Enum.ScrollBarInset.Always
    PlayerListContainer.ScrollingDirection = Enum.ScrollingDirection.Y
    PlayerListContainer.Parent = PlayerTabContent
    
    local GeneralTabContent = Instance.new("ScrollingFrame")
    GeneralTabContent.Name = "GeneralTab"
    GeneralTabContent.Size = UDim2.new(1, -10, 1, -10)
    GeneralTabContent.Position = UDim2.new(0, 5, 0, 5)
    GeneralTabContent.BackgroundTransparency = 1
    GeneralTabContent.Visible = false
    GeneralTabContent.CanvasSize = UDim2.new(0, 0, 0, 0) 
    GeneralTabContent.ScrollBarThickness = 4
    GeneralTabContent.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255)
    GeneralTabContent.ElasticBehavior = Enum.ElasticBehavior.Never
    GeneralTabContent.VerticalScrollBarInset = Enum.ScrollBarInset.Always
    GeneralTabContent.ScrollingDirection = Enum.ScrollingDirection.Y
    GeneralTabContent.Parent = ContentFrame
    
    local TeleportTabContent = Instance.new("ScrollingFrame")
    TeleportTabContent.Name = "TeleportTab"
    TeleportTabContent.Size = UDim2.new(1, -10, 1, -10)
    TeleportTabContent.Position = UDim2.new(0, 5, 0, 5)
    TeleportTabContent.BackgroundTransparency = 1
    TeleportTabContent.Visible = false
    TeleportTabContent.CanvasSize = UDim2.new(0, 0, 0, 0)
    TeleportTabContent.ScrollBarThickness = 4
    TeleportTabContent.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255)
    TeleportTabContent.ElasticBehavior = Enum.ElasticBehavior.Never
    TeleportTabContent.VerticalScrollBarInset = Enum.ScrollBarInset.Always
    TeleportTabContent.ScrollingDirection = Enum.ScrollingDirection.Y
    TeleportTabContent.Parent = ContentFrame
    
    local VipTabContent = Instance.new("ScrollingFrame")
    VipTabContent.Name = "VipTab"
    VipTabContent.Size = UDim2.new(1, -10, 1, -10)
    VipTabContent.Position = UDim2.new(0, 5, 0, 5)
    VipTabContent.BackgroundTransparency = 1
    VipTabContent.Visible = false
    VipTabContent.CanvasSize = UDim2.new(0, 0, 0, 0)
    VipTabContent.ScrollBarThickness = 4
    VipTabContent.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255)
    VipTabContent.ElasticBehavior = Enum.ElasticBehavior.Never
    VipTabContent.VerticalScrollBarInset = Enum.ScrollBarInset.Always
    VipTabContent.ScrollingDirection = Enum.ScrollingDirection.Y
    VipTabContent.Parent = ContentFrame

    local SettingsTabContent = Instance.new("ScrollingFrame")
    SettingsTabContent.Name = "SettingsTab"
    SettingsTabContent.Size = UDim2.new(1, -10, 1, -10)
    SettingsTabContent.Position = UDim2.new(0, 5, 0, 5)
    SettingsTabContent.BackgroundTransparency = 1
    SettingsTabContent.Visible = false
    SettingsTabContent.CanvasSize = UDim2.new(0, 0, 0, 0)
    SettingsTabContent.ScrollBarThickness = 4
    SettingsTabContent.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255)
    SettingsTabContent.ElasticBehavior = Enum.ElasticBehavior.Never
    SettingsTabContent.VerticalScrollBarInset = Enum.ScrollBarInset.Always
    SettingsTabContent.ScrollingDirection = Enum.ScrollingDirection.Y
    SettingsTabContent.Parent = ContentFrame

    local RekamanTabContent = Instance.new("Frame") -- [[ PERBAIKAN: Diubah menjadi Frame biasa ]]
    RekamanTabContent.Name = "RekamanTab"
    RekamanTabContent.Size = UDim2.new(1, -10, 1, -10)
    RekamanTabContent.Position = UDim2.new(0, 5, 0, 5)
    RekamanTabContent.BackgroundTransparency = 1
    RekamanTabContent.Visible = false
    RekamanTabContent.Parent = ContentFrame
    
    -- Menambahkan UIListLayout ke konten tab
    local PlayerListLayout = Instance.new("UIListLayout")
    PlayerListLayout.Name = "PlayerListLayout"
    PlayerListLayout.Padding = UDim.new(0, 5)
    PlayerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    PlayerListLayout.Parent = PlayerListContainer
    
    local GeneralListLayout = Instance.new("UIListLayout")
    GeneralListLayout.Padding = UDim.new(0, 5)
    GeneralListLayout.Parent = GeneralTabContent
    
    
    local TeleportListLayout = Instance.new("UIListLayout")
    TeleportListLayout.Padding = UDim.new(0, 2)
    TeleportListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TeleportListLayout.Parent = TeleportTabContent
    
    local VipListLayout = Instance.new("UIListLayout")
    VipListLayout.Padding = UDim.new(0, 5)
    VipListLayout.Parent = VipTabContent

    local SettingsListLayout = Instance.new("UIListLayout")
    SettingsListLayout.Padding = UDim.new(0, 5)
    SettingsListLayout.Parent = SettingsTabContent

    local RekamanListLayout = Instance.new("UIListLayout")
    RekamanListLayout.Padding = UDim.new(0, 10)
    RekamanListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    RekamanListLayout.Parent = RekamanTabContent
    
    -- Atur CanvasSize untuk Tab secara dinamis
    local function setupCanvasSize(listLayout, scrollingFrame)
        listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            scrollingFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
        end)
    end
    
    setupCanvasSize(PlayerListLayout, PlayerListContainer)
    setupCanvasSize(GeneralListLayout, GeneralTabContent)
    setupCanvasSize(TeleportListLayout, TeleportTabContent)
    setupCanvasSize(VipListLayout, VipTabContent)
    setupCanvasSize(SettingsListLayout, SettingsTabContent)
    -- setupCanvasSize(RekamanListLayout, RekamanTabContent) -- [[ PERBAIKAN: Dihapus karena RekamanTabContent bukan lagi ScrollingFrame ]]
    
    -- Deklarasi fungsi di awal
    -- [[ PERUBAHAN BARU: Ukuran tombol default diperkecil ]]
    local function createButton(parent, name, callback)
        local button = Instance.new("TextButton")
        button.Size = UDim2.new(1, 0, 0, 22) -- Ukuran diperkecil lagi
        button.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
        button.BorderSizePixel = 0
        button.Text = name
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 12 -- Font diperkecil
        button.Font = Enum.Font.SourceSansBold
        button.Parent = parent
        local buttonUICorner = Instance.new("UICorner", button)
        buttonUICorner.CornerRadius = UDim.new(0, 5)
        button.MouseButton1Click:Connect(callback)
        return button
    end
    
    -- ====================================================================
    -- == BAGIAN TELEPORT DAN FUNGSI UTILITAS                          ==
    -- ====================================================================
    local saveFeatureStates -- Deklarasi awal agar bisa diakses
    local saveGuiPositions -- Deklarasi awal
    
    local function naturalCompare(a, b)
        local function split(s)
            local parts = {}; for text, number in s:gmatch("([^%d]*)(%d*)") do if text ~= "" then table.insert(parts, text:lower()) end; if number ~= "" then table.insert(parts, tonumber(number)) end end; return parts
        end
        local partsA = split(a.Name or ""); local partsB = split(b.Name or ""); for i = 1, math.min(#partsA, #partsB) do local partA = partsA[i]; local partB = partsB[i]; if type(partA) ~= type(partB) then return type(partA) == "number" end; if partA < partB then return true elseif partA > partB then return false end end; return #partsA < #partsB
    end
    
    local updateTeleportList, updateRecordingsList
    local updatePlayerList
    
    local function showNotification(message, color)
        local notifFrame = Instance.new("Frame", ScreenGui)
        notifFrame.Size = UDim2.new(0, 180, 0, 25) -- Perkecil ukuran frame
        notifFrame.Position = UDim2.new(0.5, -90, 0, -30) -- Sesuaikan posisi awal
        notifFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 25)
        notifFrame.BackgroundTransparency = 0.3
        notifFrame.BorderSizePixel = 0
        
        local corner = Instance.new("UICorner", notifFrame)
        corner.CornerRadius = UDim.new(0, 6) -- Sedikit perkecil corner
        
        local stroke = Instance.new("UIStroke", notifFrame)
        stroke.Color = color or Color3.fromRGB(0, 150, 255) 
        stroke.Thickness = 1
        stroke.Transparency = 0.4
        
        local notifLabel = Instance.new("TextLabel", notifFrame)
        notifLabel.Size = UDim2.new(1, -10, 1, 0)
        notifLabel.Position = UDim2.new(0, 5, 0, 0)
        notifLabel.BackgroundTransparency = 1
        notifLabel.Text = message
        notifLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        notifLabel.Font = Enum.Font.SourceSans -- Ganti ke font yang lebih tipis
        notifLabel.TextSize = 12 -- Perkecil ukuran font
        notifLabel.TextWrapped = true

        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out) -- Percepat animasi
        local startPosition = UDim2.new(0.5, -90, 0, -30) -- Sesuaikan posisi
        local goalPosition = UDim2.new(0.5, -90, 0, 10) -- Sesuaikan posisi akhir
        
        notifFrame.Position = startPosition
        TweenService:Create(notifFrame, tweenInfo, {Position = goalPosition}):Play()
        
        task.delay(3, function()
            if notifFrame and notifFrame.Parent then
                TweenService:Create(notifFrame, tweenInfo, {Position = startPosition}):Play()
                task.wait(0.4)
                notifFrame:Destroy()
            end
        end)
    end
    
    saveGuiPositions = function()
        if not writefile then
            return
        end
    
        local guiDataToSave = {}
    
        local function getGuiData(guiObject)
            if guiObject and guiObject.Parent then
                return {
                    XScale = guiObject.Position.X.Scale,
                    XOffset = guiObject.Position.X.Offset,
                    YScale = guiObject.Position.Y.Scale,
                    YOffset = guiObject.Position.Y.Offset,
                    SizeX = guiObject.Size.X.Offset,
                    SizeY = guiObject.Size.Y.Offset
                }
            end
            return nil
        end
    
        guiDataToSave.MainFrame = getGuiData(MainFrame)
        guiDataToSave.MiniToggleContainer = getGuiData(MiniToggleContainer)
        if EmoteScreenGui then
            guiDataToSave.EmoteFrame = getGuiData(EmoteScreenGui:FindFirstChild("MainFrame"))
        end
        if AnimationScreenGui then
            guiDataToSave.Animationframe = getGuiData(AnimationScreenGui:FindFirstChild("GazeBro"))
        end
        if touchFlingGui then
             guiDataToSave.FlingFrame = getGuiData(touchFlingGui:FindFirstChild("Frame"))
        end
    
        local success, result = pcall(function()
            local jsonData = HttpService:JSONEncode(guiDataToSave)
            writefile(GUI_POSITIONS_SAVE_FILE, jsonData)
        end)
    
        if not success then
            warn("Gagal menyimpan posisi GUI:", result)
        end
    end
    
    local function loadGuiPositions()
        if not readfile or not isfile or not isfile(GUI_POSITIONS_SAVE_FILE) then
            return
        end
    
        local success, result = pcall(function()
            local fileContent = readfile(GUI_POSITIONS_SAVE_FILE)
            loadedGuiPositions = HttpService:JSONDecode(fileContent)
    
            local function applyGuiData(guiObject, data)
                if guiObject and guiObject.Parent and data then
                    -- Terapkan posisi jika ada
                    if data.XScale ~= nil and data.XOffset ~= nil and data.YScale ~= nil and data.YOffset ~= nil then
                        guiObject.Position = UDim2.new(data.XScale, data.XOffset, data.YScale, data.YOffset)
                    end
                    -- Terapkan ukuran jika ada
                    if data.SizeX ~= nil and data.SizeY ~= nil then
                        guiObject.Size = UDim2.new(0, data.SizeX, 0, data.SizeY)
                    end
                end
            end
    
            applyGuiData(MainFrame, loadedGuiPositions.MainFrame)
            applyGuiData(MiniToggleContainer, loadedGuiPositions.MiniToggleContainer)
        end)
        
        if not success then
            warn("Gagal memuat posisi GUI:", result)
            loadedGuiPositions = nil
        end
    end

    local function saveTeleportData()
        if not writefile then showNotification("Executor tidak mendukung penyimpanan file.", Color3.fromRGB(200, 50, 50)); return end
        local dataToSave = {}; for _, loc in ipairs(savedTeleportLocations) do table.insert(dataToSave, {Name = loc.Name, CFrameData = {loc.CFrame:GetComponents()}}) end
        local success, result = pcall(function() local jsonData = HttpService:JSONEncode(dataToSave); writefile(TELEPORT_SAVE_FILE, jsonData) end)
        if not success then warn("Gagal menyimpan data teleport:", result) end
    end
    
    local function loadTeleportData()
        if not readfile or not isfile or not isfile(TELEPORT_SAVE_FILE) then return end
        local success, result = pcall(function()
            local fileContent = readfile(TELEPORT_SAVE_FILE); local decodedData = HttpService:JSONDecode(fileContent); savedTeleportLocations = {}
            for _, data in ipairs(decodedData) do table.insert(savedTeleportLocations, {Name = data.Name, CFrame = CFrame.new(unpack(data.CFrameData))}) end
            table.sort(savedTeleportLocations, naturalCompare)
            if updateTeleportList then updateTeleportList() end
        end)
        if not success then warn("Gagal memuat data teleport:", result) end
    end
    
    local function loadAnimations()
        if isfile and isfile(ANIMATION_SAVE_FILE) and readfile then
            local success, data = pcall(function() return HttpService:JSONDecode(readfile(ANIMATION_SAVE_FILE)) end)
            if success and type(data) == "table" then
                lastAnimations = data
            end
        end
    end

    -- [[ PERUBAHAN BARU: Fungsi simpan dan muat untuk rekaman ]]
    local function saveRecordingsData()
        if not writefile then return end
        pcall(function()
            local jsonData = HttpService:JSONEncode(savedRecordings)
            writefile(RECORDING_SAVE_FILE, jsonData)
        end)
    end

    local function loadRecordingsData()
        if not readfile or not isfile or not isfile(RECORDING_SAVE_FILE) then return end
        local success, result = pcall(function()
            local fileContent = readfile(RECORDING_SAVE_FILE)
            local decodedData = HttpService:JSONDecode(fileContent)
            if type(decodedData) == "table" then
                savedRecordings = decodedData
            end
            if updateRecordingsList then
                updateRecordingsList()
            end
        end)
        if not success then
            warn("Gagal memuat data rekaman:", result)
        end
    end

    saveFeatureStates = function()
        if not writefile then return end
        
        local statesToSave = {
            WalkSpeed = IsWalkSpeedEnabled,
            Fly = IsFlying,
            Noclip = IsNoclipEnabled,
            InfinityJump = IsInfinityJumpEnabled,
            GodMode = IsGodModeEnabled,
            AntiFling = antifling_enabled,
            AntiLag = IsAntiLagEnabled,
            BoostFPS = IsBoostFPSEnabled,
            FEInvisible = IsFEInvisibleEnabled,
            ShiftLock = IsShiftLockEnabled,
            -- [[ PERUBAHAN DIMULAI: Simpan status ESP terpisah ]]
            ESPName = IsEspNameEnabled,
            ESPBody = IsEspBodyEnabled,
            -- [[ PERUBAHAN SELESAI ]]
            EmoteVIP = isEmoteEnabled,
            AnimationVIP = isAnimationEnabled,
            EmoteTransparent = isEmoteTransparent,
            AnimationTransparent = isAnimationTransparent,
            WalkSpeedValue = Settings.WalkSpeed,
            FlySpeedValue = Settings.FlySpeed,
            FEInvisibleTransparencyValue = Settings.FEInvisibleTransparency,
            SpeedLockEnabled = speedLock_isEnforced,
            SpeedLockValue = speedLock_currentSpeed
        }
        
        pcall(function()
            writefile(FEATURE_STATES_SAVE_FILE, HttpService:JSONEncode(statesToSave))
        end)
    end
    
    local function loadFeatureStates()
        if not readfile or not isfile or not isfile(FEATURE_STATES_SAVE_FILE) then return end
        
        local success, result = pcall(function()
            local fileContent = readfile(FEATURE_STATES_SAVE_FILE)
            local decodedData = HttpService:JSONDecode(fileContent)
            
            if type(decodedData) == "table" then
                IsWalkSpeedEnabled = decodedData.WalkSpeed or false
                IsFlying = decodedData.Fly or false
                IsNoclipEnabled = decodedData.Noclip or false
                IsInfinityJumpEnabled = decodedData.InfinityJump or false
                IsGodModeEnabled = decodedData.GodMode or false
                antifling_enabled = decodedData.AntiFling or false
                IsAntiLagEnabled = decodedData.AntiLag or false
                IsBoostFPSEnabled = decodedData.BoostFPS or false
                IsFEInvisibleEnabled = decodedData.FEInvisible or false
                IsShiftLockEnabled = decodedData.ShiftLock or false
                -- [[ PERUBAHAN DIMULAI: Muat status ESP terpisah ]]
                IsEspNameEnabled = decodedData.ESPName or false
                IsEspBodyEnabled = decodedData.ESPBody or false
                isEmoteEnabled = decodedData.EmoteVIP or false
                isAnimationEnabled = decodedData.AnimationVIP or false
                isEmoteTransparent = decodedData.EmoteTransparent ~= false
                isAnimationTransparent = decodedData.AnimationTransparent or false
                -- [[ PERUBAHAN SELESAI ]]
                
                Settings.WalkSpeed = decodedData.WalkSpeedValue or 16
                Settings.FlySpeed = decodedData.FlySpeedValue or 1
                Settings.FEInvisibleTransparency = decodedData.FEInvisibleTransparencyValue or 0.75
                speedLock_isEnforced = decodedData.SpeedLockEnabled or false
                speedLock_currentSpeed = decodedData.SpeedLockValue or 16
            end
        end)
        if not success then
            warn("Gagal memuat status fitur:", result)
        end
    end

    local function showGenericRenamePrompt(oldName, callback)
        local promptFrame = Instance.new("Frame"); promptFrame.Size = UDim2.new(0, 200, 0, 100); promptFrame.Position = UDim2.new(0.5, -100, 0.5, -50); promptFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30); promptFrame.BorderSizePixel = 0; promptFrame.ZIndex = 10; promptFrame.Parent = MainFrame
        local corner = Instance.new("UICorner", promptFrame); corner.CornerRadius = UDim.new(0, 8); local stroke = Instance.new("UIStroke", promptFrame); stroke.Color = Color3.fromRGB(0, 150, 255); stroke.Thickness = 1
        local title = Instance.new("TextLabel", promptFrame); title.Size = UDim2.new(1, 0, 0, 20); title.Text = "Ganti Nama"; title.TextColor3 = Color3.fromRGB(255, 255, 255); title.BackgroundTransparency = 1; title.Font = Enum.Font.SourceSansBold
        local textBox = Instance.new("TextBox", promptFrame); textBox.Size = UDim2.new(1, -20, 0, 30); textBox.Position = UDim2.new(0.5, -90, 0, 30); textBox.Text = oldName; textBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50); textBox.TextColor3 = Color3.fromRGB(255, 255, 255); textBox.ClearTextOnFocus = false; local tbCorner = Instance.new("UICorner", textBox); tbCorner.CornerRadius = UDim.new(0, 5)
        local okButton = createButton(promptFrame, "OK", function() callback(textBox.Text); promptFrame:Destroy() end); okButton.Size = UDim2.new(0.5, -10, 0, 25); okButton.Position = UDim2.new(0, 5, 1, -30)
        local cancelButton = createButton(promptFrame, "Batal", function() promptFrame:Destroy() end); cancelButton.Size = UDim2.new(0.5, -10, 0, 25); cancelButton.Position = UDim2.new(0.5, 5, 1, -30); cancelButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    end

    
    local function showImportPrompt(callback)
        local promptFrame = Instance.new("Frame"); promptFrame.Size = UDim2.new(0, 220, 0, 150); promptFrame.Position = UDim2.new(0.5, -110, 0.5, -75); promptFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30); promptFrame.BorderSizePixel = 0; promptFrame.ZIndex = 10; promptFrame.Parent = MainFrame
        local corner = Instance.new("UICorner", promptFrame); corner.CornerRadius = UDim.new(0, 8); local stroke = Instance.new("UIStroke", promptFrame); stroke.Color = Color3.fromRGB(0, 150, 255); stroke.Thickness = 1
        local title = Instance.new("TextLabel", promptFrame); title.Size = UDim2.new(1, 0, 0, 20); title.Text = "Impor Lokasi"; title.TextColor3 = Color3.fromRGB(255, 255, 255); title.BackgroundTransparency = 1; title.Font = Enum.Font.SourceSansBold
        local textBox = Instance.new("TextBox", promptFrame); textBox.Size = UDim2.new(1, -20, 1, -60); textBox.Position = UDim2.new(0.5, -100, 0, 25); textBox.PlaceholderText = "Tempel data di sini..."; textBox.MultiLine = true; textBox.TextXAlignment = Enum.TextXAlignment.Left; textBox.TextYAlignment = Enum.TextYAlignment.Top; textBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50); textBox.TextColor3 = Color3.fromRGB(255, 255, 255); local tbCorner = Instance.new("UICorner", textBox); tbCorner.CornerRadius = UDim.new(0, 5)
        local okButton = createButton(promptFrame, "Impor", function() callback(textBox.Text); promptFrame:Destroy() end); okButton.Size = UDim2.new(0.5, -10, 0, 25); okButton.Position = UDim2.new(0, 5, 1, -30)
        local cancelButton = createButton(promptFrame, "Batal", function() promptFrame:Destroy() end); cancelButton.Size = UDim2.new(0.5, -10, 0, 25); cancelButton.Position = UDim2.new(0.5, 5, 1, -30); cancelButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    end
    
    local function addTeleportLocation(name, cframe)
        for _, loc in pairs(savedTeleportLocations) do if loc.Name == name then return end end
        table.insert(savedTeleportLocations, {Name = name, CFrame = cframe}); table.sort(savedTeleportLocations, naturalCompare); saveTeleportData(); if updateTeleportList then updateTeleportList() end
    end
    
    -- [[ PERUBAHAN BARU: Deklarasi awal untuk fungsi spectate ]]
    local startLocationSpectate;
    
    -- [[ PERBAIKAN 1: Fungsi untuk memperbarui visibilitas ikon DAN ukuran tombol ]]
    local function updateTeleportIconVisibility()
        for _, child in pairs(TeleportTabContent:GetChildren()) do
            if child.Name == "TeleportLocationFrame" then
                local actionsFrame = child:FindFirstChild("ActionsFrame")
                local tpButton = child:FindFirstChildOfClass("TextButton")

                if actionsFrame and tpButton then
                    actionsFrame.Visible = areTeleportIconsVisible
                    if areTeleportIconsVisible then
                        tpButton.Size = UDim2.new(1, -65, 1, 0)
                    else
                        tpButton.Size = UDim2.new(1, 0, 1, 0)
                    end
                end
            end
        end
    end
    
    -- [[ PERBAIKAN 1: Fungsi updateTeleportList dirombak untuk menangani ukuran awal tombol ]]
    updateTeleportList = function()
        for _, child in pairs(TeleportTabContent:GetChildren()) do 
            if child.Name == "TeleportLocationFrame" then 
                child:Destroy() 
            end 
        end
    
        local layoutOrderOffset = 5 -- Urutan setelah tombol utama
    
        for i, locData in ipairs(savedTeleportLocations) do
            local locFrame = Instance.new("Frame")
            locFrame.Name = "TeleportLocationFrame"
            locFrame.Size = UDim2.new(1, 0, 0, 22) -- Disesuaikan dengan createButton
            locFrame.BackgroundTransparency = 1
            locFrame.Parent = TeleportTabContent
            locFrame.LayoutOrder = i + layoutOrderOffset
            locFrame.ZIndex = 2
    
            local tpButton = createButton(locFrame, locData.Name, function() 
                if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then 
                    LocalPlayer.Character.HumanoidRootPart.CFrame = locData.CFrame * CFrame.new(0, 3, 0) 
                end 
            end)
            -- Atur ukuran awal tombol berdasarkan status visibilitas ikon
            tpButton.Size = areTeleportIconsVisible and UDim2.new(1, -65, 1, 0) or UDim2.new(1, 0, 1, 0)
            tpButton.TextSize = 10
            tpButton.TextXAlignment = Enum.TextXAlignment.Left
            local pad = Instance.new("UIPadding", tpButton)
            pad.PaddingLeft = UDim.new(0, 5)
    
            -- Frame untuk tombol aksi (View, Rename, Delete)
            local actionsFrame = Instance.new("Frame")
            actionsFrame.Name = "ActionsFrame"
            actionsFrame.Size = UDim2.new(0, 62, 1, 0)
            actionsFrame.Position = UDim2.new(1, -62, 0, 0)
            actionsFrame.BackgroundTransparency = 1
            actionsFrame.Parent = locFrame
            actionsFrame.Visible = areTeleportIconsVisible -- Atur visibilitas frame
    
            local actionsLayout = Instance.new("UIListLayout")
            actionsLayout.FillDirection = Enum.FillDirection.Horizontal
            actionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
            actionsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
            actionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
            actionsLayout.Padding = UDim.new(0, 2)
            actionsLayout.Parent = actionsFrame
            
            -- Tombol View (👁️)
            local viewButton = createButton(actionsFrame, "👁️", function()
                startLocationSpectate(locData.CFrame)
            end)
            viewButton.Size = UDim2.new(0, 18, 0, 18)
            viewButton.TextSize = 12
            viewButton.BackgroundColor3 = Color3.fromRGB(50, 150, 200)
    
            -- Tombol Rename (R)
            local renameButton = createButton(actionsFrame, "R", function() 
                showGenericRenamePrompt(locData.Name, function(newName) 
                    if newName and newName ~= "" and newName ~= savedTeleportLocations[i].Name then 
                        savedTeleportLocations[i].Name = newName
                        table.sort(savedTeleportLocations, naturalCompare)
                        saveTeleportData()
                        updateTeleportList() 
                    end 
                end) 
            end)
            renameButton.Size = UDim2.new(0, 18, 0, 18)
            renameButton.TextSize = 10
    
            -- Tombol Delete (X)
            local deleteButton = createButton(actionsFrame, "X", function() 
                table.remove(savedTeleportLocations, i)
                saveTeleportData()
                updateTeleportList() 
            end)
            deleteButton.Size = UDim2.new(0, 18, 0, 18)
            deleteButton.TextSize = 10
            deleteButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        end
    end

    local function updateSinglePlayerButton(player)
        local button = PlayerButtons[player.UserId]
        if not button or not button.Parent then return end
    
        local distLabel = button:FindFirstChild("DistanceLabel")
        if distLabel then
            local localHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            local targetHRP = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            distLabel.Text = (localHRP and targetHRP) and tostring(math.floor((localHRP.Position - targetHRP.Position).Magnitude)) .. "m" or "..."
        end
    
        local avatarImgBtn = button:FindFirstChild("AvatarImageButton")
        if avatarImgBtn then
            local stroke = avatarImgBtn:FindFirstChild("SpectateStroke")
            if stroke then
                stroke.Transparency = (IsViewingPlayer and currentlyViewedPlayer == player) and 0 or 1
            end
        end
    
        local flingButton = button:FindFirstChild("FlingButton", true)
        if flingButton then
            flingButton.BackgroundColor3 = (currentFlingTarget == player) and Color3.fromRGB(200, 50, 50) or Color3.fromRGB(80, 80, 80)
        end
    
        local recButton = button:FindFirstChild("RecordPlayerButton", true)
        if recButton then
            local isCurrentlyRecordingThisPlayer = isRecording and currentRecordingTarget == player
            recButton.Text = isCurrentlyRecordingThisPlayer and "⏹️" or "🔴"
            recButton.BackgroundColor3 = isCurrentlyRecordingThisPlayer and Color3.fromRGB(80, 80, 80) or Color3.fromRGB(200, 50, 50)
        end
    
        local copyMovementButton = button:FindFirstChild("CopyMovementButton", true)
        if copyMovementButton then
            local isCopyingThisPlayer = isCopyingMovement and copiedPlayer == player
            copyMovementButton.BackgroundColor3 = isCopyingThisPlayer and Color3.fromRGB(40, 200, 40) or Color3.fromRGB(80, 80, 80)
        end
    end
    
    updatePlayerList = function()
        local playerCountLabel = PlayerTabContent:FindFirstChild("PlayerCountLabel", true)
        if not (MainFrame.Visible and PlayerTabContent.Visible) or not playerCountLabel then return end
    
        playerCountLabel.Text = "Pemain Online: " .. #Players:GetPlayers()
    
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local passesFilter = (CurrentPlayerFilter == "" or CurrentPlayerFilter == "Cari Pemain..." or player.Name:lower():find(CurrentPlayerFilter:lower(), 1, true) or player.DisplayName:lower():find(CurrentPlayerFilter:lower(), 1, true))
                local existingButton = PlayerButtons[player.UserId]
                
                if existingButton then
                    existingButton.Visible = passesFilter
                    updateSinglePlayerButton(player)
                end
            end
        end
    end
    
    local function switchTab(tabName)
        PlayerTabContent.Visible = (tabName == "Player"); GeneralTabContent.Visible = (tabName == "Umum"); TeleportTabContent.Visible = (tabName == "Teleport"); VipTabContent.Visible = (tabName == "VIP"); SettingsTabContent.Visible = (tabName == "Pengaturan"); RekamanTabContent.Visible = (tabName == "Rekaman")
        if tabName == "Player" and updatePlayerList then updatePlayerList() end
    end
    
    local function createTabButton(name, parent)
        local button = Instance.new("TextButton"); button.Size = UDim2.new(1, 0, 0, 25); button.BackgroundColor3 = Color3.fromRGB(30, 30, 30); button.BorderSizePixel = 0; button.Text = name; button.TextColor3 = Color3.fromRGB(255, 255, 255); button.TextSize = 12; button.Font = Enum.Font.SourceSansSemibold; button.Parent = parent; local btnCorner = Instance.new("UICorner", button); btnCorner.CornerRadius = UDim.new(0, 5); button.MouseButton1Click:Connect(function() switchTab(name) end); return button
    end
    
    local PlayerTabButton = createTabButton("Player", TabsFrame)
    local GeneralTabButton = createTabButton("Umum", TabsFrame)
    local TeleportTabButton = createTabButton("Teleport", TabsFrame)
    local RekamanTabButton = createTabButton("Rekaman", TabsFrame)
    local VipTabButton = createTabButton("VIP", TabsFrame)
    local SettingsTabButton = createTabButton("Pengaturan", TabsFrame)
    

    
    -- ====================================================================
    -- == BAGIAN FUNGSI ANIMASI (INTEGRASI DARI animation.lua)         ==
    -- ====================================================================
    local applyEmoteTransparency
    local applyAnimationTransparency

    local function destroyAnimationGUI()
        if AnimationScreenGui and AnimationScreenGui.Parent then
            AnimationScreenGui:Destroy()
        end
        AnimationScreenGui = nil
    end

    local function destroyEmoteGUI()
        if EmoteScreenGui and EmoteScreenGui.Parent then
            EmoteScreenGui:Destroy()
            EmoteScreenGui = nil
        end
        -- Also destroy the new window if it exists
        local existingGui = CoreGui:FindFirstChild("EmoteWindowGUI")
        if existingGui then
            existingGui:Destroy()
        end
    end

    applyEmoteTransparency = function(isTransparent)
        local frame = EmoteScreenGui and EmoteScreenGui:FindFirstChild("MainFrame")
        if not frame then return end

        local baseTransparency = isTransparent and 0.85 or 0
        local handleTransparency = isTransparent and 0.85 or 0.5

        -- Helper to apply transparency
        local function applyTo(element, transparency)
            if element then
                element.BackgroundTransparency = transparency
            end
        end

        applyTo(frame, baseTransparency)
        applyTo(frame:FindFirstChild("Header"), baseTransparency)
        applyTo(frame:FindFirstChild("SearchBox"), baseTransparency)
        applyTo(frame:FindFirstChild("EmoteResizeHandle"), handleTransparency)

        local filterFrame = frame:FindFirstChild("FilterFrame")
        if filterFrame then
            for _, button in ipairs(filterFrame:GetChildren()) do
                if button:IsA("TextButton") then
                    applyTo(button, baseTransparency)
                end
            end
        end
        
        local emoteArea = frame:FindFirstChild("EmoteArea")
        if emoteArea then
            for _, container in ipairs(emoteArea:GetChildren()) do
                if container:IsA("Frame") then
                    local emoteButton = container:FindFirstChild("EmoteImageButton")
                    local starButton = container:FindFirstChild("FavoriteButton")
                    applyTo(emoteButton, baseTransparency)
                    applyTo(starButton, baseTransparency)
                end
            end
        end
    end

    local function initializeEmoteGUI()
        if not hasPermission("VIP") then
            showNotification("Silahkan upgrade ke VIP terlebih dahulu, Terimakasih", Color3.fromRGB(255,100,0))
            return
        end
        if EmoteScreenGui and EmoteScreenGui.Parent then
            destroyEmoteGUI()
            return
        end

        loadFavorites()

        EmoteScreenGui = Instance.new("ScreenGui")
        EmoteScreenGui.Name = "EmoteWindowGUI"
        EmoteScreenGui.Parent = CoreGui
        EmoteScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        EmoteScreenGui.DisplayOrder = 11

        local EmoteMainFrame = Instance.new("Frame")
        EmoteMainFrame.Name = "MainFrame"
        EmoteMainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
        EmoteMainFrame.Size = UDim2.new(0, 160, 0, 180)
        EmoteMainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        
        if loadedGuiPositions and loadedGuiPositions.EmoteFrame then
            local posData = loadedGuiPositions.EmoteFrame
            pcall(function() 
                EmoteMainFrame.Position = UDim2.new(posData.XScale, posData.XOffset, posData.YScale, posData.YOffset)
                EmoteMainFrame.Size = UDim2.new(0, posData.SizeX or 160, 0, posData.SizeY or 180)
            end)
        end
        
        EmoteMainFrame.BackgroundColor3 = Color3.fromRGB(28, 43, 70)
        EmoteMainFrame.BorderColor3 = Color3.fromRGB(90, 150, 255)
        EmoteMainFrame.BorderSizePixel = 1
        EmoteMainFrame.ClipsDescendants = true
        EmoteMainFrame.Parent = EmoteScreenGui
        EmoteMainFrame.Visible = true

        local UICorner = Instance.new("UICorner", EmoteMainFrame)
        UICorner.CornerRadius = UDim.new(0, 8)

        local Header = Instance.new("TextButton") 
        Header.Name = "Header"
        Header.Size = UDim2.new(1, 0, 0, 30)
        Header.BackgroundColor3 = Color3.fromRGB(48, 63, 90)
        Header.BorderSizePixel = 0
        Header.Text = "" 
        Header.AutoButtonColor = false 
        Header.Parent = EmoteMainFrame

        local Title = Instance.new("TextLabel")
        Title.Name = "Title"
        Title.Size = UDim2.new(1, -40, 1, 0)
        Title.Position = UDim2.new(0, 10, 0, 0)
        Title.BackgroundTransparency = 1
        Title.Font = Enum.Font.GothamBold
        Title.Text = "Arexans Emotes [VIP]"
        Title.TextColor3 = Color3.fromRGB(255, 255, 255)
        Title.TextXAlignment = Enum.TextXAlignment.Left
        Title.Parent = Header

        local CloseButton = Instance.new("TextButton")
        CloseButton.Name = "CloseButton"
        CloseButton.Size = UDim2.new(0, 20, 0, 20)
        CloseButton.Position = UDim2.new(1, -15, 0.5, 0)
        CloseButton.AnchorPoint = Vector2.new(0.5, 0.5)
        CloseButton.BackgroundTransparency = 1
        CloseButton.Font = Enum.Font.GothamBold
        CloseButton.Text = "X"
        CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        CloseButton.TextSize = 18
        CloseButton.Parent = Header
        CloseButton.MouseButton1Click:Connect(destroyEmoteGUI) 
        
        MakeDraggable(EmoteMainFrame, Header, function() return true end, nil)

        local EmoteResizeHandle = Instance.new("TextButton")
        EmoteResizeHandle.Name = "EmoteResizeHandle"
        EmoteResizeHandle.Text = ""
        EmoteResizeHandle.Size = UDim2.new(0, 15, 0, 15)
        EmoteResizeHandle.Position = UDim2.new(1, -15, 1, -15)
        EmoteResizeHandle.BackgroundColor3 = Color3.fromRGB(90, 150, 255)
        EmoteResizeHandle.BorderSizePixel = 0
        EmoteResizeHandle.ZIndex = 2
        EmoteResizeHandle.Parent = EmoteMainFrame

        EmoteResizeHandle.InputBegan:Connect(function(input)
            if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then return end
            local isResizing = true
            local initialMousePosition = UserInputService:GetMouseLocation()
            local initialFrameSize = EmoteMainFrame.AbsoluteSize
            local inputChangedConnection, inputEndedConnection
            inputChangedConnection = UserInputService.InputChanged:Connect(function(changedInput)
                if isResizing and (changedInput.UserInputType == Enum.UserInputType.MouseMovement or changedInput.UserInputType == Enum.UserInputType.Touch) then
                    local delta = UserInputService:GetMouseLocation() - initialMousePosition
                    local newSizeX = math.max(160, initialFrameSize.X + delta.X)
                    local newSizeY = math.max(180, initialFrameSize.Y + delta.Y)
                    EmoteMainFrame.Size = UDim2.new(0, newSizeX, 0, newSizeY)
                end
            end)
            inputEndedConnection = UserInputService.InputEnded:Connect(function(endedInput)
                if endedInput.UserInputType == input.UserInputType then
                    isResizing = false
                    if inputChangedConnection then inputChangedConnection:Disconnect() end
                    if inputEndedConnection then inputEndedConnection:Disconnect() end
                    saveGuiPositions()
                end
            end)
        end)

        local SearchBox = Instance.new("TextBox")
        SearchBox.Name = "SearchBox"
        SearchBox.Size = UDim2.new(1, -20, 0, 25)
        SearchBox.Position = UDim2.new(0, 10, 0, 35)
        SearchBox.BackgroundColor3 = Color3.fromRGB(48, 63, 90)
        SearchBox.PlaceholderText = "Cari emote..."
        SearchBox.Text = ""
        SearchBox.PlaceholderColor3 = Color3.fromRGB(180, 190, 210)
        SearchBox.Font = Enum.Font.Gotham
        SearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
        SearchBox.ClearTextOnFocus = false
        SearchBox.Parent = EmoteMainFrame
        local SearchCorner = Instance.new("UICorner", SearchBox); SearchCorner.CornerRadius = UDim.new(0, 6)
        local SearchPadding = Instance.new("UIPadding", SearchBox); SearchPadding.PaddingLeft = UDim.new(0, 10); SearchPadding.PaddingRight = UDim.new(0, 10)

        local FilterFrame = Instance.new("Frame")
        FilterFrame.Name = "FilterFrame"
        FilterFrame.Size = UDim2.new(1, -20, 0, 25)
        FilterFrame.Position = UDim2.new(0, 10, 0, 65)
        FilterFrame.BackgroundTransparency = 1
        FilterFrame.Parent = EmoteMainFrame

        local FilterLayout = Instance.new("UIListLayout", FilterFrame)
        FilterLayout.FillDirection = Enum.FillDirection.Horizontal
        FilterLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        FilterLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        FilterLayout.Padding = UDim.new(0, 5)

        local filterButtons = {}
        local favoriteFilterState = 1
        local function createFilterButton(text, state)
            local button = Instance.new("TextButton", FilterFrame)
            button.Name = text .. "FilterButton"
            button.Size = UDim2.new(0.33, -5, 1, 0)
            button.Font = Enum.Font.SourceSansBold
            button.Text = text
            button.TextSize = 12
            local btnCorner = Instance.new("UICorner", button); btnCorner.CornerRadius = UDim.new(0, 4)
            table.insert(filterButtons, {button=button, state=state})
            return button
        end

        local favButton = createFilterButton("Favorite", 2)
        local allButton = createFilterButton("Semua", 1)
        local unfavButton = createFilterButton("Unfavorite", 3)

        local function updateFilterButtons()
            for _, btnInfo in ipairs(filterButtons) do
                local isActive = (btnInfo.state == favoriteFilterState)
                btnInfo.button.BackgroundColor3 = isActive and Color3.fromRGB(90, 150, 255) or Color3.fromRGB(48, 63, 90)
                btnInfo.button.TextColor3 = isActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(180, 190, 210)
            end
        end
        
        local EmoteArea = Instance.new("ScrollingFrame")
        EmoteArea.Name = "EmoteArea"
        EmoteArea.Size = UDim2.new(1, 0, 1, -100)
        EmoteArea.Position = UDim2.new(0, 0, 0, 95)
        EmoteArea.BackgroundTransparency = 1
        EmoteArea.BorderSizePixel = 0
        EmoteArea.ScrollBarImageColor3 = Color3.fromRGB(90, 150, 255)
        EmoteArea.ScrollBarThickness = 5
        EmoteArea.ScrollingDirection = Enum.ScrollingDirection.Y
        EmoteArea.Parent = EmoteMainFrame
        local UIPadding = Instance.new("UIPadding", EmoteArea); UIPadding.PaddingLeft = UDim.new(0, 10); UIPadding.PaddingRight = UDim.new(0, 10); UIPadding.PaddingTop = UDim.new(0, 5); UIPadding.PaddingBottom = UDim.new(0, 10)

        local UIGridLayout = Instance.new("UIGridLayout")
        UIGridLayout.CellPadding = UDim2.new(0, 4, 0, 4)
        UIGridLayout.CellSize = UDim2.new(0, 32, 0, 44)
        UIGridLayout.SortOrder = Enum.SortOrder.Name
        UIGridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        UIGridLayout.Parent = EmoteArea
        
        local function populateEmotes(filter)
            filter = filter and filter:lower() or ""
            for _, container in pairs(EmoteArea:GetChildren()) do
                if container:IsA("Frame") and container:FindFirstChild("EmoteImageButton") then
                    local isFavorite = favoriteEmotes[container.Name] == true
                    local passesSearch = (filter == "" or container.Name:lower():find(filter, 1, true))
                    
                    local passesFavoriteFilter = false
                    if favoriteFilterState == 1 then passesFavoriteFilter = true
                    elseif favoriteFilterState == 2 then if isFavorite then passesFavoriteFilter = true end
                    elseif favoriteFilterState == 3 then if not isFavorite then passesFavoriteFilter = true end
                    end
                    
                    container.Visible = passesSearch and passesFavoriteFilter
                end
            end
            task.wait()
            EmoteArea.CanvasSize = UDim2.new(0, 0, 0, UIGridLayout.AbsoluteContentSize.Y)
        end
        
        for _, btnInfo in ipairs(filterButtons) do
            btnInfo.button.MouseButton1Click:Connect(function()
                favoriteFilterState = btnInfo.state
                updateFilterButtons()
                loadFavorites() 
                populateEmotes(SearchBox.Text)
            end)
        end
        
        updateFilterButtons()

        local function toggleAnimation(animId)
            local char = LocalPlayer.Character
            if not char or not char:FindFirstChild("Humanoid") then return end
            local humanoid = char.Humanoid
            local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid

            -- Cari dan hentikan emote yang sedang berjalan
            for _, playingTrack in ipairs(animator:GetPlayingAnimationTracks()) do
                if playingTrack.Name == "ArexansEmoteTrack" then
                    playingTrack:Stop(0.2)
                    -- Jika emote yang sama diklik lagi, kita hanya menghentikannya.
                    if playingTrack.Animation.AnimationId == animId then
                        return
                    end
                end
            end

            -- Mainkan emote baru
            local anim = Instance.new("Animation")
            anim.AnimationId = animId
            
            local newTrack = animator:LoadAnimation(anim)
            newTrack.Name = "ArexansEmoteTrack" -- Beri nama khusus untuk identifikasi
            newTrack:Play(0.1)

            anim:Destroy()
        end

        local function createEmoteButton(emoteData)
            local container = Instance.new("Frame")
            container.Name = emoteData.name
            container.Size = UDim2.new(0, 32, 0, 44)
            container.BackgroundTransparency = 1
            container.Parent = EmoteArea

            local button = Instance.new("ImageButton", container)
            button.Name = "EmoteImageButton"
            button.BackgroundColor3 = Color3.fromRGB(48, 63, 90)
            button.BackgroundTransparency = isEmoteTransparent and 0.85 or 0
            button.Size = UDim2.new(1, 0, 1, 0)
            local corner = Instance.new("UICorner", button); corner.CornerRadius = UDim.new(0, 6)

            local image = Instance.new("ImageLabel", button)
            image.Size = UDim2.new(1, -4, 0, 30)
            image.Position = UDim2.new(0.5, 0, 0, 2)
            image.AnchorPoint = Vector2.new(0.5, 0)
            image.BackgroundTransparency = 1
            image.Image = "rbxthumb://type=Asset&id=" .. tostring(emoteData.id) .. "&w=420&h=420"

            local nameLabel = Instance.new("TextLabel", button)
            nameLabel.Size = UDim2.new(1, -4, 0, 10)
            nameLabel.Position = UDim2.new(0, 2, 1, -11)
            nameLabel.BackgroundTransparency = 1
            nameLabel.Font = Enum.Font.Gotham
            nameLabel.Text = emoteData.name
            nameLabel.TextScaled = true
            nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

            button.MouseButton1Click:Connect(function() toggleAnimation(emoteData.animationid) end)

            local starButton = Instance.new("TextButton", container)
            starButton.Name = "FavoriteButton"
            starButton.Size = UDim2.new(0, 16, 0, 16)
            starButton.Position = UDim2.new(1, 0, 0, 0)
            starButton.AnchorPoint = Vector2.new(1, 0)
            starButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        starButton.BackgroundTransparency = isEmoteTransparent and 0.85 or 0
            starButton.Font = Enum.Font.SourceSansBold
            starButton.Text = "♥"
            starButton.TextSize = 12
            starButton.ZIndex = 2
            local starCorner = Instance.new("UICorner", starButton); starCorner.CornerRadius = UDim.new(0, 4)

            local function updateStarVisual()
                local isFavorite = favoriteEmotes[emoteData.name] == true
                starButton.TextColor3 = isFavorite and Color3.fromRGB(255, 80, 120) or Color3.fromRGB(150, 150, 150)
            end

            starButton.MouseButton1Click:Connect(function()
                favoriteEmotes[emoteData.name] = not favoriteEmotes[emoteData.name]
                saveFavorites()
                updateStarVisual()
                populateEmotes(SearchBox.Text)
            end)
            updateStarVisual()
        end

        task.spawn(function()
            local success, result = pcall(function() return HttpService:JSONDecode(game:HttpGet("https://raw.githubusercontent.com/AREXANS/emoteff/refs/heads/main/emote.json")) end)
            if success and type(result) == "table" then
                local existingEmotes = {}
                for _, emote in pairs(result) do
                    if emote.name and emote.animationid and emote.id and not existingEmotes[emote.name:lower()] then
                        createEmoteButton(emote); existingEmotes[emote.name:lower()] = true
                    end
                end
            else
                warn("Gagal mengambil daftar emote:", result)
            end
            populateEmotes("")
        end)
        SearchBox:GetPropertyChangedSignal("Text"):Connect(function() populateEmotes(SearchBox.Text) end)

        -- Apply initial transparency
        applyEmoteTransparency(isEmoteTransparent)
    end

    local function initializeAnimationGUI()
        if isGameAnimationOverrideActive then
            showNotification("Fitur animasi dinonaktifkan oleh game ini.", Color3.fromRGB(255, 150, 0))
            return
        end
        if not hasPermission("VIP") then
            showNotification("Silahkan upgrade ke VIP terlebih dahulu, Terimakasih", Color3.fromRGB(255,100,0))
            return
        end
        destroyAnimationGUI()

        pcall(function()
            local GazeGoGui = CoreGui or Players.LocalPlayer:WaitForChild("PlayerGui")

            local guiName = "GazeVerificator"
            if GazeGoGui:FindFirstChild(guiName) then return end

            AnimationScreenGui = Instance.new("ScreenGui")
            AnimationScreenGui.Name = guiName
            AnimationScreenGui.Parent = GazeGoGui
            AnimationScreenGui.DisplayOrder = 10 -- [PERBAIKAN] Atur agar selalu di depan

            local camera = workspace.CurrentCamera
            local function getScaledSize(relativeWidth, relativeHeight)
                local viewportSize = camera.ViewportSize
                return UDim2.new(0, viewportSize.X * relativeWidth, 0, viewportSize.Y * relativeHeight)
            end
            
            local frame = Instance.new("Frame")
            frame.Name = "GazeBro"
            frame.Size = getScaledSize(0.15, 0.25) -- Ukuran relatif diperkecil
            frame.Position = UDim2.new(0.5, -frame.Size.X.Offset / 2, 0.5, -frame.Size.Y.Offset / 2)
            if loadedGuiPositions and loadedGuiPositions.Animationframe then
                local posData = loadedGuiPositions.Animationframe
                pcall(function() frame.Position = UDim2.new(posData.XScale, posData.XOffset, posData.YScale, posData.YOffset) end)
            end
            frame.BackgroundColor3 = Color3.fromRGB(25, 28, 40)
            frame.BackgroundTransparency = 0.2
            frame.BorderSizePixel = 2
            frame.BorderColor3 = Color3.fromRGB(0, 120, 255)
            frame.Visible = false 
            frame.Parent = AnimationScreenGui

            local animHeader = Instance.new("TextButton", frame)
            animHeader.Name = "AnimHeader"
            animHeader.Text = ""
            animHeader.Size = UDim2.new(1, 0, 0.15, 0)
            animHeader.Position = UDim2.new(0, 0, 0, 0)
            animHeader.BackgroundColor3 = Color3.fromRGB(25, 28, 40)
            animHeader.BorderSizePixel = 0
            animHeader.AutoButtonColor = false
            MakeDraggable(frame, animHeader, function() return true end, nil)


            local labelSize = UDim2.new(1, 0, 1, 0)
            local gazeLabel = Instance.new("TextLabel", animHeader)
            gazeLabel.Name = "GazeLabel"
            gazeLabel.Text = "Arexans Anim [VIP]"
            gazeLabel.Font = Enum.Font.SourceSansBold
            gazeLabel.TextScaled = true
            gazeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
            gazeLabel.BackgroundTransparency = 1
            gazeLabel.Size = labelSize
            gazeLabel.Position = UDim2.new(0, 0, 0, 0)

            local hideButton = Instance.new("TextButton", animHeader)
            hideButton.Name = "HideButton"
            hideButton.Text = "😑"
            hideButton.Font = Enum.Font.SourceSansBold
            hideButton.TextScaled = true
            hideButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            hideButton.BackgroundTransparency = 1
            hideButton.BorderSizePixel = 0
            hideButton.Size = UDim2.new(0.1, 0, 1, 0)
            hideButton.Position = UDim2.new(0.9, 0, 0, 0)
            hideButton.MouseButton1Click:Connect(function()
                frame.Visible = false
                AnimationShowButton.Visible = true
            end)

            local searchBar = Instance.new("TextBox", frame)
            searchBar.Name = "SearchBar"
            searchBar.PlaceholderText = "Search..."
            searchBar.Text = ""
            searchBar.Font = Enum.Font.SourceSans
            searchBar.TextScaled = true
            searchBar.TextColor3 = Color3.fromRGB(200, 200, 200)
            searchBar.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
            searchBar.BorderSizePixel = 0
            searchBar.Size = UDim2.new(0.9, 0, 0.1, 0)
            searchBar.Position = UDim2.new(0.05, 0, 0.17, 0)
            searchBar.ClearTextOnFocus = true

            local scrollFrame = Instance.new("ScrollingFrame", frame)
            scrollFrame.Name = "ScrollFrame"
            scrollFrame.Size = UDim2.new(0.9, 0, 0.7, 0)
            scrollFrame.Position = UDim2.new(0.05, 0, 0.28, 0)
            scrollFrame.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
            scrollFrame.BorderSizePixel = 0
            scrollFrame.ScrollBarThickness = 6
            scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
            scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
            scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 120, 255)

            local resizeHandle = Instance.new("TextButton", frame)
            resizeHandle.Name = "ResizeHandle"
            resizeHandle.Text = ""
            resizeHandle.Size = UDim2.new(0, 15, 0, 15)
            resizeHandle.Position = UDim2.new(1, -15, 1, -15)
            resizeHandle.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
            resizeHandle.BackgroundTransparency = 0.5
            resizeHandle.BorderSizePixel = 0
            resizeHandle.ZIndex = 2
            
            task.spawn(function()
                local buttons = {}
                local activeAnimationButtons = {}
                local defaultButtonColor = Color3.fromRGB(0, 120, 255)
                local activeButtonColor = Color3.fromRGB(28, 184, 88) -- Warna hijau untuk tombol aktif

                local function createTheButton(text, callback)
                    local button = Instance.new("TextButton", scrollFrame)
                    button.Text = text
                    button.Font = Enum.Font.SourceSans
                    button.TextScaled = false 
                    button.TextSize = 9 -- Diperkecil
                    button.TextColor3 = Color3.fromRGB(255, 255, 255)
                    button.BackgroundColor3 = defaultButtonColor -- Menggunakan warna default
                    button.Size = UDim2.new(1, 0, 0, 22) -- Diperkecil
                    button.Position = UDim2.new(1, 0, 0, #buttons * 26) -- Disesuaikan
                    button.BackgroundTransparency = 1
                    button.BorderSizePixel = 0
                    button.MouseButton1Click:Connect(callback)
                    local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                    local targetTransparency = isAnimationTransparent and 0.85 or 0.3
                    local goal = {Position = UDim2.new(0, 0, 0, #buttons * 26), BackgroundTransparency = targetTransparency} 
                    TweenService:Create(button, tweenInfo, goal):Play()
                    table.insert(buttons, button)
                    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, #buttons * 26)
                    return button -- Mengembalikan instance tombol
                end

                searchBar:GetPropertyChangedSignal("Text"):Connect(function()
                    local searchText = searchBar.Text:lower()
                    local order = 0
                    for _, button in ipairs(buttons) do
                        if searchText == "" or button.Text:lower():find(searchText) then
                            button.Visible = true
                            button.Position = UDim2.new(0, 0, 0, order * 30) 
                            order = order + 1
                        else
                            button.Visible = false
                        end
                    end
                    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, order * 30)
                end)
                
                local isResizing = false
                local initialMousePosition, initialFrameSize
                resizeHandle.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then isResizing = true; initialMousePosition = UserInputService:GetMouseLocation(); initialFrameSize = frame.AbsoluteSize; end end)
                UserInputService.InputChanged:Connect(function(input) if isResizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then local delta = UserInputService:GetMouseLocation() - initialMousePosition; local newSizeX = math.max(100, initialFrameSize.X + delta.X); local newSizeY = math.max(100, initialFrameSize.Y + delta.Y); frame.Size = UDim2.new(0, newSizeX, 0, newSizeY); frame.Position = UDim2.new(frame.Position.X.Scale, frame.Position.X.Offset, frame.Position.Y.Scale, frame.Position.Y.Offset) end end)
                UserInputService.InputEnded:Connect(function(input) if isResizing and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then isResizing = false; end end)
                
                local speaker = Players.LocalPlayer
                
                -- [[ PERUBAHAN DIMULAI: Memuat animasi dari JSON ]]
                local Animations = {}
                local success, animData = pcall(function()
                    return HttpService:JSONDecode(game:HttpGet("https://raw.githubusercontent.com/AREXANS/emoteff/refs/heads/main/animation.json"))
                end)

                if not success or type(animData) ~= "table" then
                    warn("ArexansTools - Gagal memuat data animasi:", animData)
                    showNotification("Gagal memuat animasi VIP.", Color3.fromRGB(200, 50, 50))
                    return -- Hentikan fungsi jika data tidak bisa dimuat
                end
                
                Animations = animData -- Tetapkan data yang dimuat ke variabel Animations
                -- [[ PERUBAHAN SELESAI ]]

                local function loadAnimation(animationId) local char = speaker.Character or speaker.CharacterAdded:Wait(); local anim = Instance.new("Animation"); anim.AnimationId = "rbxassetid://"..tostring(animationId); return char:WaitForChild("Humanoid"):LoadAnimation(anim) end
                for _, sets in pairs(Animations) do for _, ids in pairs(sets) do if type(ids)=="table" then for _, id in ipairs(ids) do task.spawn(loadAnimation, id) end else task.spawn(loadAnimation, ids) end end end

                local function Buy(gamePassID)
                    pcall(function() game:GetService("MarketplaceService"):PromptGamePassPurchase(speaker, gamePassID) end)
                end
                
                -- [[ FUNGSI PENERAPAN ANIMASI (DIPERBAIKI) ]]
                local function setAnimation(animationType, animationId)
                    if isGameAnimationOverrideActive then return end
                    local function saveLastAnimations() 
                        if writefile then 
                            pcall(function() 
                                local data = HttpService:JSONEncode(lastAnimations)
                                writefile(ANIMATION_SAVE_FILE, data) 
                            end) 
                        end 
                    end

                    local char = speaker.Character
                    if not char then return end
                    local animateScript = char:FindFirstChild("Animate")
                    if not animateScript then return end

                    -- Helper function to replace an animation for smoother replication
                    local function replaceAnimation(parent, animName, newId)
                        if not parent then return end
                        -- Destroy the old animation object if it exists
                        local oldAnim = parent:FindFirstChild(animName)
                        if oldAnim then
                            oldAnim:Destroy()
                        end
                        -- Create a new animation instance
                        local newAnim = Instance.new("Animation")
                        newAnim.Name = animName
                        newAnim.AnimationId = "http://www.roblox.com/asset/?id=" .. tostring(newId)
                        newAnim.Parent = parent
                    end

                    if animationType == "Idle" then 
                        lastAnimations.Idle = animationId
                        replaceAnimation(animateScript.idle, "Animation1", animationId[1])
                        replaceAnimation(animateScript.idle, "Animation2", animationId[2])
                    elseif animationType == "Walk" then 
                        lastAnimations.Walk = animationId
                        replaceAnimation(animateScript.walk, "WalkAnim", animationId)
                    elseif animationType == "Run" then 
                        lastAnimations.Run = animationId
                        replaceAnimation(animateScript.run, "RunAnim", animationId)
                    elseif animationType == "Jump" then 
                        lastAnimations.Jump = animationId
                        replaceAnimation(animateScript.jump, "JumpAnim", animationId)
                    elseif animationType == "Fall" then 
                        lastAnimations.Fall = animationId
                        replaceAnimation(animateScript.fall, "FallAnim", animationId)
                    elseif animationType == "Swim" and animateScript.swim then 
                        lastAnimations.Swim = animationId
                        replaceAnimation(animateScript.swim, "Swim", animationId)
                    elseif animationType == "SwimIdle" and animateScript.swimidle then 
                        lastAnimations.SwimIdle = animationId
                        replaceAnimation(animateScript.swimidle, "SwimIdle", animationId)
                    elseif animationType == "Climb" then 
                        lastAnimations.Climb = animationId
                        replaceAnimation(animateScript.climb, "ClimbAnim", animationId)
                    end
                    saveLastAnimations()
                end
                
                local function PlayEmote(animationId) 
                    local char = speaker.Character; if not char or not char:FindFirstChildOfClass("Humanoid") then return end
                    local Hum = char:FindFirstChildOfClass("Humanoid")
                    for _, v in next, Hum:GetPlayingAnimationTracks() do v:Stop() end
                    local track = loadAnimation(animationId); track:Play()
                    local conn; conn = RunService.RenderStepped:Connect(function() if speaker.Character:WaitForChild("Humanoid").MoveDirection.Magnitude > 0 then track:Stop(); conn:Disconnect() end end) 
                end
                local function ZeroPlayEmote(animationId) 
                    local char = speaker.Character; if not char or not char:FindFirstChildOfClass("Humanoid") then return end
                    local Hum = char:FindFirstChildOfClass("Humanoid")
                    for _, v in next, Hum:GetPlayingAnimationTracks() do v:Stop() end
                    local track = loadAnimation(animationId); track:Play(); track:AdjustSpeed(0)
                    local conn; conn = RunService.RenderStepped:Connect(function() if speaker.Character:WaitForChild("Humanoid").MoveDirection.Magnitude > 0 then track:Stop(); conn:Disconnect() end end) 
                end
                local function FPlayEmote(animationId) 
                    local char = speaker.Character; if not char or not char:FindFirstChildOfClass("Humanoid") then return end
                    local Hum = char:FindFirstChildOfClass("Humanoid")
                    for _, v in next, Hum:GetPlayingAnimationTracks() do v:Stop() end
                    local track = loadAnimation(animationId); track:Play(); task.delay(track.Length * 0.9, function() track:AdjustSpeed(0) end)
                    local conn; conn = RunService.RenderStepped:Connect(function() if speaker.Character:WaitForChild("Humanoid").MoveDirection.Magnitude > 0 then track:Stop(); conn:Disconnect() end end) 
                end
                
                local function AddEmote(name, id) createTheButton(name.." - Emote", function() PlayEmote(id) end) end
                local function ZeroAddEmote(name, id) createTheButton(name.." - Emote", function() ZeroPlayEmote(id) end) end
                local function AddFEmote(name, id) createTheButton(name.." - Emote", function() FPlayEmote(id) end) end
                local function AddDonate(Price, Id) createTheButton("Donate "..Price.." Robux", function() Buy(Id) end) end
                
                -- [PERBAIKAN DIMULAI]
                -- Fungsi bantuan untuk membandingkan ID animasi (termasuk yang berbentuk tabel seperti Idle)
                local function areAnimIdsEqual(id1, id2)
                    if type(id1) ~= type(id2) then return false end
                    if type(id1) == "table" then
                        if #id1 ~= #id2 then return false end
                        for i = 1, #id1 do
                            if id1[i] ~= id2[i] then return false end
                        end
                        return true
                    else
                        return id1 == id2
                    end
                end

                local function createAnimationButton(text, animType, animId)
                    local btn
                    btn = createTheButton(text.." - "..animType, function()
                        -- Saat tombol diklik, warnai ulang tombol aktif sebelumnya menjadi biru
                        if activeAnimationButtons[animType] and activeAnimationButtons[animType] ~= btn then
                            activeAnimationButtons[animType].BackgroundColor3 = defaultButtonColor
                        end
                        -- Warnai tombol yang baru diklik menjadi hijau
                        btn.BackgroundColor3 = activeButtonColor
                        -- Simpan tombol ini sebagai tombol yang aktif untuk tipe animasi ini
                        activeAnimationButtons[animType] = btn
                        -- Terapkan dan simpan animasi
                        setAnimation(animType, animId)
                    end)
                    
                    -- Cek apakah animasi ini adalah yang terakhir digunakan saat GUI dibuat
                    if lastAnimations[animType] and areAnimIdsEqual(lastAnimations[animType], animId) then
                        -- Jika ya, langsung warnai hijau dan tandai sebagai aktif
                        btn.BackgroundColor3 = activeButtonColor
                        activeAnimationButtons[animType] = btn
                    end
                end
                -- [PERBAIKAN SELESAI]
                
                local function resetToRthroPack()
                    local anims = Animations
                    if anims.Idle["Rthro"] then setAnimation("Idle", anims.Idle["Rthro"]) end
                    if anims.Walk["Rthro"] then setAnimation("Walk", anims.Walk["Rthro"]) end
                    if anims.Run["Rthro"] then setAnimation("Run", anims.Run["Rthro"]) end
                    if anims.Jump["Rthro"] then setAnimation("Jump", anims.Jump["Rthro"]) end
                    if anims.Fall["Rthro"] then setAnimation("Fall", anims.Fall["Rthro"]) end
                    if anims.SwimIdle["Rthro"] then setAnimation("SwimIdle", anims.SwimIdle["Rthro"]) end
                    if anims.Swim["Rthro"] then setAnimation("Swim", anims.Swim["Rthro"]) end
                    if anims.Climb["Rthro"] then setAnimation("Climb", anims.Climb["Rthro"]) end

                    for animType, button in pairs(activeAnimationButtons) do
                        if button and button.Parent then
                            button.BackgroundColor3 = defaultButtonColor
                        end
                    end
                    activeAnimationButtons = {}
                    
                    showNotification("Semua animasi direset ke Rthro Pack", Color3.fromRGB(50, 150, 255))
                end

                local resetButton = createTheButton("Reset Semua Animasi Rthro", resetToRthroPack)
                resetButton.BackgroundColor3 = Color3.fromRGB(200, 70, 70)

                local function resetToAdidasSport()
                    local anims = Animations
                    if anims.Walk["Sports (Adidas)"] then setAnimation("Walk", anims.Walk["Sports (Adidas)"]) end
                    if anims.Run["Sports (Adidas)"] then setAnimation("Run", anims.Run["Sports (Adidas)"]) end
                    if anims.Jump["Sports (Adidas)"] then setAnimation("Jump", anims.Jump["Sports (Adidas)"]) end
                    if anims.Fall["Sports (Adidas)"] then setAnimation("Fall", anims.Fall["Sports (Adidas)"]) end
                    if anims.Swim["Sports (Adidas)"] then setAnimation("Swim", anims.Swim["Sports (Adidas)"]) end
                    if anims.SwimIdle["Sports (Adidas)"] then setAnimation("SwimIdle", anims.SwimIdle["Sports (Adidas)"]) end
                    if anims.Climb["Sports (Adidas)"] then setAnimation("Climb", anims.Climb["Sports (Adidas)"]) end
                end
                createTheButton("Reset to Adidas Sport", resetToAdidasSport)
                
                for name, ids in pairs(Animations.Idle) do task.wait(); createAnimationButton(name, "Idle", ids) end
                for name, id in pairs(Animations.Walk) do task.wait(); createAnimationButton(name, "Walk", id) end
                for name, id in pairs(Animations.Run) do task.wait(); createAnimationButton(name, "Run", id) end
                for name, id in pairs(Animations.Jump) do task.wait(); createAnimationButton(name, "Jump", id) end
                for name, id in pairs(Animations.Fall) do task.wait(); createAnimationButton(name, "Fall", id) end
                for name, id in pairs(Animations.SwimIdle) do task.wait(); createAnimationButton(name, "SwimIdle", id) end
                for name, id in pairs(Animations.Swim) do task.wait(); createAnimationButton(name, "Swim", id) end
                for name, id in pairs(Animations.Climb) do task.wait(); createAnimationButton(name, "Climb", id) end

                AddDonate(20, 1131371530); AddDonate(200, 1131065702); AddDonate(183, 1129915318); AddDonate(2000, 1128299749)
                AddEmote("Dance 1", 12521009666); AddEmote("Dance 2", 12521169800); AddEmote("Dance 3", 12521178362); AddEmote("Cheer", 12521021991); AddEmote("Laugh", 12521018724); AddEmote("Point", 12521007694); AddEmote("Wave", 12521004586)
                AddFEmote("Soldier - Assault Fire", 4713811763); AddEmote("Soldier - Assault Aim", 4713633512); AddEmote("Zombie - Attack", 3489169607); AddFEmote("Zombie - Death", 3716468774); AddEmote("Roblox - Sleep", 2695918332); AddEmote("Roblox - Quake", 2917204509); AddEmote("Roblox - Rifle Reload", 3972131105)
                ZeroAddEmote("Accurate T Pose", 2516930867)
            end)

            if applyAnimationTransparency then
                applyAnimationTransparency(isAnimationTransparent)
            end
        end)
    end
    
    applyAnimationTransparency = function(isTransparent)
        if not AnimationScreenGui then return end
        local frame = AnimationScreenGui:FindFirstChild("GazeBro", true)
        
        local transValue = 0.85

        if frame then
            local searchBar = frame:FindFirstChild("SearchBar")
            local scrollFrame = frame:FindFirstChild("ScrollFrame")
            local resizeHandle = frame:FindFirstChild("ResizeHandle")
            
            frame.BackgroundTransparency = isTransparent and transValue or 0.2
            AnimationShowButton.BackgroundTransparency = isTransparent and transValue or 0.3
            if searchBar then searchBar.BackgroundTransparency = isTransparent and transValue or 0 end
            if scrollFrame then scrollFrame.BackgroundTransparency = isTransparent and transValue or 0 end
            if resizeHandle then resizeHandle.BackgroundTransparency = isTransparent and 0.9 or 0.5 end

            if scrollFrame then
                for _, button in ipairs(scrollFrame:GetChildren()) do
                    if button:IsA("TextButton") then
                        local targetTransparency = isTransparent and transValue or 0.3
                        TweenService:Create(button, TweenInfo.new(0.1), {BackgroundTransparency = targetTransparency}):Play()
                    end
                end
            end
        end
    end

    -- [[ PERUBAHAN DIMULAI: Bagian fungsi ESP ditulis ulang ]]
    -- ====================================================================
    -- == BAGIAN FUNGSI ESP (DIPERBARUI)                               ==
    -- ====================================================================

    local function UpdateESP()
        if not IsEspNameEnabled and not IsEspBodyEnabled then return end
    
        local localPlayerTeam = LocalPlayer.Team
    
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local char = player.Character
                local head = char and char:FindFirstChild("Head")
    
                if head and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
                    local espElements = espCache[player.UserId]
                    if not espElements then
                        espElements = {}
                        espCache[player.UserId] = espElements
                    end
    
                    -- Logika ESP Nama
                    if IsEspNameEnabled then
                        if not espElements.billboard then
                            local billboardGui = Instance.new("BillboardGui")
                            billboardGui.Name = "PlayerESP_Name"
                            billboardGui.AlwaysOnTop = true
                            billboardGui.Size = UDim2.new(0, 150, 0, 40)
                            billboardGui.StudsOffset = Vector3.new(0, 2.5, 0)
    
                            local textLabel = Instance.new("TextLabel", billboardGui)
                            textLabel.Name = "NameLabel"
                            textLabel.Size = UDim2.new(1, 0, 0.5, 0)
                            textLabel.BackgroundTransparency = 1
                            textLabel.Font = Enum.Font.SourceSansBold
                            textLabel.TextSize = 14
                            textLabel.Text = player.DisplayName
    
                            local distLabel = Instance.new("TextLabel", billboardGui)
                            distLabel.Name = "DistanceLabel"
                            distLabel.Size = UDim2.new(1, 0, 0.5, 0)
                            distLabel.Position = UDim2.new(0, 0, 0.5, 0)
                            distLabel.BackgroundTransparency = 1
                            distLabel.Font = Enum.Font.SourceSans
                            distLabel.TextSize = 12
                            distLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
                            
                            espElements.billboard = billboardGui
                        end
    
                        espElements.billboard.Adornee = head
                        espElements.billboard.Parent = CoreGui
    
                        local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if localRoot then
                            local distance = math.floor((localRoot.Position - head.Position).Magnitude)
                            espElements.billboard.DistanceLabel.Text = "[" .. tostring(distance) .. "m]"
                        end
                        
                        if player.Team == localPlayerTeam and localPlayerTeam ~= nil then
                            espElements.billboard.NameLabel.TextColor3 = Color3.fromRGB(100, 255, 100) -- Hijau untuk tim
                        else
                            espElements.billboard.NameLabel.TextColor3 = Color3.fromRGB(100, 100, 255) -- Biru untuk musuh/netral
                        end
                    elseif espElements.billboard then
                        espElements.billboard:Destroy()
                        espElements.billboard = nil
                    end
    
                    -- Logika ESP Tubuh (Highlight)
                    if IsEspBodyEnabled then
                        if not espElements.highlight then
                            local highlight = Instance.new("Highlight")
                            highlight.Name = "ESPHighlight"
                            highlight.FillTransparency = 0.7
                            highlight.OutlineTransparency = 0.5
                            highlight.Parent = char
                            espElements.highlight = highlight
                        end
                        
                        if espElements.highlight.Parent ~= char then
                            espElements.highlight.Parent = char
                        end
    
                        if player.Team == localPlayerTeam and localPlayerTeam ~= nil then
                            espElements.highlight.FillColor = Color3.fromRGB(100, 255, 100)
                        else
                            espElements.highlight.FillColor = Color3.fromRGB(100, 100, 255) -- Biru untuk musuh/netral
                        end
                    elseif espElements.highlight then
                        espElements.highlight:Destroy()
                        espElements.highlight = nil
                    end
    
                else
                    -- Pemain tidak punya karakter atau mati, bersihkan ESP mereka
                    if espCache[player.UserId] then
                        if espCache[player.UserId].billboard then espCache[player.UserId].billboard:Destroy() end
                        if espCache[player.UserId].highlight then espCache[player.UserId].highlight:Destroy() end
                        espCache[player.UserId] = nil
                    end
                end
            end
        end
    end
    
    local function manageEspConnection()
        if (IsEspNameEnabled or IsEspBodyEnabled) and not EspRenderConnection then
            EspRenderConnection = RunService.RenderStepped:Connect(UpdateESP)
        elseif not IsEspNameEnabled and not IsEspBodyEnabled and EspRenderConnection then
            EspRenderConnection:Disconnect()
            EspRenderConnection = nil
            for userId, elements in pairs(espCache) do
                if elements.billboard then elements.billboard:Destroy() end
                if elements.highlight then elements.highlight:Destroy() end
            end
            espCache = {}
        end
    end
    
    local function ToggleESPName(enabled)
        IsEspNameEnabled = enabled
        saveFeatureStates()
        manageEspConnection()
    end
    
    local function ToggleESPBody(enabled)
        IsEspBodyEnabled = enabled
        saveFeatureStates()
        manageEspConnection()
    end
    -- [[ PERUBAHAN SELESAI ]]

	
    -- ====================================================================
    -- == BAGIAN FUNGSI UTAMA (PLAYER, COMBAT, DLL)                      ==
    -- ====================================================================

    -- [[ FUNGSI UNTUK FITUR KUNCI KECEPATAN ]] --
    local speedLock_disconnectAll, speedLock_bindHumanoid
    
    local function speedLock_canonicalDefault()
        local ok, val = pcall(function() return game:GetService("StarterPlayer").CharacterWalkSpeed end)
        if ok and typeof(val) == "number" and val > 0 then return val end
        return 16
    end

    local function speedLock_setWalkSpeed(humanoid, speed)
        if humanoid and humanoid.Parent then
            pcall(function() humanoid.WalkSpeed = speed end)
        end
    end

    local function speedLock_canEnforce()
        local h = speedLock_humanoid
        if not speedLock_isEnforced then return false end
        if not h or not h.Parent then return false end
        if speedLock_isPaused then return false end
        if h.Health <= 0 then return false end
        if h.PlatformStand or h.Sit then return false end
        local st = h:GetState()
        if st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown or st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.GettingUp or st == Enum.HumanoidStateType.Seated then return false end
        local hrp = h.Parent:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.Anchored then return false end
        return true
    end

    local function speedLock_heartbeat()
        if not speedLock_humanoid then return end
        local t = tick()
        if t - speedLock_lastTick < speedLock_tickInterval then return end
        speedLock_lastTick = t
        if not speedLock_canEnforce() then return end
        if speedLock_humanoid.WalkSpeed ~= speedLock_currentSpeed then
            speedLock_setWalkSpeed(speedLock_humanoid, speedLock_currentSpeed)
        end
    end

    speedLock_disconnectAll = function()
        for _, conn in ipairs(speedLock_connections) do
            if conn then conn:Disconnect() end
        end
        speedLock_connections = {}
    end
    
    local function speedLock_captureServerBaseline()
        task.spawn(function()
            local h = speedLock_humanoid
            if not h or not h.Parent then return end
            local start = tick()
            local last = h.WalkSpeed
            while tick() - start < 0.6 do
                last = h.WalkSpeed
                task.wait(0.1)
            end
            if typeof(last) == "number" and last > 0 then
                speedLock_serverBaseline = last
            end
        end)
    end

    local function speedLock_applyDisabledState()
        local h = speedLock_humanoid
        if not h or not h.Parent then return end
        local target = speedLock_serverBaseline or speedLock_canonicalDefault()
        speedLock_setWalkSpeed(h, target)
        speedLock_captureServerBaseline()
    end

    speedLock_bindHumanoid = function(humanoid)
        if not humanoid then return end
        speedLock_humanoid = humanoid
        speedLock_disconnectAll()

        table.insert(speedLock_connections, humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if speedLock_isEnforced and speedLock_canEnforce() and humanoid.WalkSpeed ~= speedLock_currentSpeed then
                speedLock_setWalkSpeed(humanoid, speedLock_currentSpeed)
            end
        end))

        table.insert(speedLock_connections, humanoid.StateChanged:Connect(function(_, new)
            if new == Enum.HumanoidStateType.Ragdoll or new == Enum.HumanoidStateType.FallingDown or new == Enum.HumanoidStateType.Physics or new == Enum.HumanoidStateType.GettingUp or new == Enum.HumanoidStateType.Seated then
                speedLock_isPaused = true
                task.delay(1.0, function() speedLock_isPaused = false end)
            end
        end))
        
        table.insert(speedLock_connections, humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(function() 
            speedLock_isPaused = humanoid.PlatformStand 
        end))

        table.insert(speedLock_connections, humanoid.AncestryChanged:Connect(function(_, parent)
            if not parent then speedLock_disconnectAll() end
        end))

        if speedLock_isEnforced then
            if not table.find(speedLock_connections, "heartbeat") then
                speedLock_lastTick = 0
                local conn = RunService.Heartbeat:Connect(speedLock_heartbeat)
                table.insert(speedLock_connections, conn)
            end
            if speedLock_canEnforce() then speedLock_setWalkSpeed(humanoid, speedLock_currentSpeed) end
        else
            speedLock_applyDisabledState()
        end
    end
    -- [[ AKHIR FUNGSI KUNCI KECEPATAN ]]

    local stopSpectate; -- Deklarasi awal
    local cycleSpectate;
    local startSpectate; -- Deklarasi awal

    -- [[ FUNGSI UNTUK FITUR COPY MOVEMENT ]] --
    local startCopyMovement, stopCopyMovement, toggleCopyMovement

    stopCopyMovement = function()
        if not isCopyingMovement then return end

        if copyMovementConnection then
            copyMovementConnection:Disconnect()
            copyMovementConnection = nil
        end

        if copyMovementMovers.attachment and copyMovementMovers.attachment.Parent then
            copyMovementMovers.attachment:Destroy()
        end
        copyMovementMovers = {}

        local previousCopiedPlayer = copiedPlayer -- Store for UI update
        isCopyingMovement = false
        copiedPlayer = nil

        local char = LocalPlayer.Character
        if char then
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            if humanoid then
                -- Stop all cached animations
                for id, track in pairs(copyAnimationCache) do
                    if track and track.IsPlaying then
                        track:Stop(0.1)
                    end
                end
            end
        end
        copyAnimationCache = {}

        if previousCopiedPlayer then
            showNotification("Berhenti mengikuti " .. previousCopiedPlayer.DisplayName, Color3.fromRGB(200, 150, 50))
        end
        
        if updatePlayerList then updatePlayerList() end
    end

    startCopyMovement = function(targetPlayer)
        if isCopyingMovement then
            stopCopyMovement()
            task.wait(0.1) -- Brief pause to ensure everything is reset
        end

        local localChar = LocalPlayer.Character
        local localHrp = localChar and localChar:FindFirstChild("HumanoidRootPart")
        local localHumanoid = localChar and localChar:FindFirstChildOfClass("Humanoid")

        local targetChar = targetPlayer.Character
        local targetHrp = targetChar and targetChar:FindFirstChild("HumanoidRootPart")
        local targetHumanoid = targetChar and targetChar:FindFirstChildOfClass("Humanoid")

        if not (localHrp and localHumanoid and targetHrp and targetHumanoid) then
            showNotification("Target atau karakter Anda tidak valid.", Color3.fromRGB(200, 50, 50))
            return
        end

        isCopyingMovement = true
        copiedPlayer = targetPlayer
        
        -- Create physics movers
        pcall(function()
            local attachment = Instance.new("Attachment", localHrp)
            attachment.Name = "CopyMovementAttachment"
            local alignPos = Instance.new("AlignPosition", attachment)
            alignPos.Attachment0 = attachment
            alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment
            alignPos.Responsiveness = 200
            alignPos.MaxForce = 100000
            local alignOrient = Instance.new("AlignOrientation", attachment)
            alignOrient.Attachment0 = attachment
            alignOrient.Mode = Enum.OrientationAlignmentMode.OneAttachment
            alignOrient.Responsiveness = 200
            alignOrient.MaxTorque = 100000
            copyMovementMovers = {attachment = attachment, alignPos = alignPos, alignOrient = alignOrient}
        end)

        showNotification("Mulai mengikuti " .. targetPlayer.DisplayName, Color3.fromRGB(50, 150, 255))
        if updatePlayerList then updatePlayerList() end

        copyMovementConnection = RunService.Heartbeat:Connect(function()
            if not isCopyingMovement or not copiedPlayer or not copiedPlayer.Parent then
                stopCopyMovement()
                return
            end

            local lChar = LocalPlayer.Character
            local lHrp = lChar and lChar:FindFirstChild("HumanoidRootPart")
            local lHumanoid = lChar and lChar:FindFirstChildOfClass("Humanoid")

            local tChar = copiedPlayer.Character
            local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart")
            local tHumanoid = tChar and tChar:FindFirstChildOfClass("Humanoid")

            if not (lHrp and lHumanoid and tHrp and tHumanoid and tHumanoid.Health > 0 and copyMovementMovers.alignPos and copyMovementMovers.alignOrient) then
                stopCopyMovement()
                return
            end

            -- Copy CFrame using physics movers
            local targetCFrame = tHrp.CFrame * CFrame.new(0, 0, 2)
            copyMovementMovers.alignPos.Position = targetCFrame.Position
            copyMovementMovers.alignOrient.CFrame = targetCFrame

            -- Copy Animations
            local requiredAnims = {}
            for _, track in ipairs(tHumanoid:GetPlayingAnimationTracks()) do
                local animId = track.Animation.AnimationId
                requiredAnims[animId] = true
                
                if not copyAnimationCache[animId] then
                    local anim = Instance.new("Animation")
                    anim.AnimationId = animId
                    copyAnimationCache[animId] = lHumanoid:LoadAnimation(anim)
                end

                local localTrack = copyAnimationCache[animId]
                if not localTrack.IsPlaying then
                    localTrack:Play(0.1)
                end
                localTrack.TimePosition = track.TimePosition
                localTrack:AdjustSpeed(track.Speed)
            end

            for id, track in pairs(copyAnimationCache) do
                if not requiredAnims[id] and track.IsPlaying then
                    track:Stop(0.1)
                end
            end
        end)
    end

    toggleCopyMovement = function(targetPlayer)
        if not hasPermission("Normal") then
            showNotification("Tingkatkan ke Normal/VIP untuk menggunakan fitur ini.", Color3.fromRGB(255,100,0))
            return
        end
        if isCopyingMovement and copiedPlayer == targetPlayer then
            stopCopyMovement()
        else
            startCopyMovement(targetPlayer)
        end
    end
    
    local function SkidFling(TargetPlayer)
        local Character = LocalPlayer.Character
        local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
        local RootPart = Humanoid and Humanoid.RootPart
        if not (Character and Humanoid and RootPart) then return end

        local TCharacter = TargetPlayer.Character
        if not TCharacter then return end
        
        local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
        local TRootPart = THumanoid and THumanoid.RootPart
        local THead = TCharacter:FindFirstChild("Head")
        local Accessory = TCharacter:FindFirstChildOfClass("Accessory")
        local Handle = Accessory and Accessory:FindFirstChild("Handle")

        if RootPart.Velocity.Magnitude < 50 then
            getgenv().OldPos = RootPart.CFrame
        end
        if THumanoid and THumanoid.Sit then
            return showNotification("Target is sitting", Color3.fromRGB(255,100,0))
        end
        
        -- [PERBAIKAN] Hanya ubah kamera jika tidak sedang dalam mode spectate
        if not IsViewingPlayer then
            if THead then
                workspace.CurrentCamera.CameraSubject = THead
            elseif not THead and Handle then
                workspace.CurrentCamera.CameraSubject = Handle
            elseif THumanoid and TRootPart then
                workspace.CurrentCamera.CameraSubject = THumanoid
            end
        end
        
        if not TCharacter:FindFirstChildWhichIsA("BasePart") then
            return
        end
        
        local FPos = function(BasePart, Pos, Ang)
            -- [PERBAIKAN] Hapus pengecekan .Parent agar Fling berfungsi saat spectate (karakter disembunyikan)
            if not (RootPart and Character) then return end
            RootPart.CFrame = CFrame.new(BasePart.Position) * Pos * Ang
            Character:SetPrimaryPartCFrame(CFrame.new(BasePart.Position) * Pos * Ang)
            RootPart.Velocity = Vector3.new(9e8, 9e8 * 10, 9e8)
            RootPart.RotVelocity = Vector3.new(9e9, 9e9, 9e9)
        end
        
        local SFBasePart = function(BasePart)
            local TimeToWait = 2
            local Time = tick()
            local Angle = 0

            repeat
                if RootPart and THumanoid and BasePart and BasePart.Parent then
                    if BasePart.Velocity.Magnitude < 50 then
                        Angle = Angle + 100
                        FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle),0 ,0)); task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0)); task.wait()
                        FPos(BasePart, CFrame.new(2.25, 1.5, -2.25) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0)); task.wait()
                        FPos(BasePart, CFrame.new(-2.25, -1.5, 2.25) + THumanoid.MoveDirection * BasePart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0)); task.wait()
                        FPos(BasePart, CFrame.new(0, 1.5, 0) + THumanoid.MoveDirection,CFrame.Angles(math.rad(Angle), 0, 0)); task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0) + THumanoid.MoveDirection,CFrame.Angles(math.rad(Angle), 0, 0)); task.wait()
                    else
                        FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0)); task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, -THumanoid.WalkSpeed), CFrame.Angles(0, 0, 0)); task.wait()
                        FPos(BasePart, CFrame.new(0, 1.5, THumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0)); task.wait()
                        FPos(BasePart, CFrame.new(0, 1.5, TRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(math.rad(90), 0, 0)); task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, -TRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(0, 0, 0)); task.wait()
                        FPos(BasePart, CFrame.new(0, 1.5, TRootPart.Velocity.Magnitude / 1.25), CFrame.Angles(math.rad(90), 0, 0)); task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0)); task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0)); task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5 ,0), CFrame.Angles(math.rad(-90), 0, 0)); task.wait()
                        FPos(BasePart, CFrame.new(0, -1.5, 0), CFrame.Angles(0, 0, 0)); task.wait()
                    end
                else
                    break
                end
            until not (BasePart and BasePart.Parent) or BasePart.Velocity.Magnitude > 500 or BasePart.Parent ~= TargetPlayer.Character or TargetPlayer.Parent ~= Players or not TargetPlayer.Character == TCharacter or THumanoid.Sit or Humanoid.Health <= 0 or tick() > Time + TimeToWait
        end
        
        workspace.FallenPartsDestroyHeight = 0/0
        
        local BV = Instance.new("BodyVelocity")
        BV.Name = "EpixVel"
        BV.Parent = RootPart
        BV.Velocity = Vector3.new(9e8, 9e8, 9e8)
        BV.MaxForce = Vector3.new(1/0, 1/0, 1/0)
        
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
        
        if TRootPart and THead then
            if (TRootPart.CFrame.p - THead.CFrame.p).Magnitude > 5 then
                SFBasePart(THead)
            else
                SFBasePart(TRootPart)
            end
        elseif TRootPart and not THead then
            SFBasePart(TRootPart)
        elseif not TRootPart and THead then
            SFBasePart(THead)
        elseif not TRootPart and not THead and Accessory and Handle then
            SFBasePart(Handle)
        end
        
        BV:Destroy()
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        
        -- [PERBAIKAN] Hanya kembalikan kamera ke player lokal jika tidak sedang spectate
        if not IsViewingPlayer then
            workspace.CurrentCamera.CameraSubject = Humanoid
        end
        
        repeat
            if not (RootPart and RootPart.Parent and Character and Character.Parent) then break end
            RootPart.CFrame = getgenv().OldPos * CFrame.new(0, .5, 0)
            Character:SetPrimaryPartCFrame(getgenv().OldPos * CFrame.new(0, .5, 0))
            Humanoid:ChangeState("GettingUp")
            table.foreach(Character:GetChildren(), function(_, x)
                if x:IsA("BasePart") then
                    x.Velocity, x.RotVelocity = Vector3.new(), Vector3.new()
                end
            end)
            task.wait()
        until not RootPart or not RootPart.Parent or (RootPart.Position - getgenv().OldPos.p).Magnitude < 25
        workspace.FallenPartsDestroyHeight = getgenv().FPDH
    end

    local ToggleFlingOnPlayer

    local function createOrUpdateFlingStatusBar(targetPlayer)
        if flingStatusGui and flingStatusGui.Parent then
            flingStatusGui:Destroy()
            flingStatusGui = nil
        end
    
        if not targetPlayer then
            return
        end
    
        flingStatusGui = Instance.new("ScreenGui")
        flingStatusGui.Name = "FlingStatusGUI"
        flingStatusGui.Parent = CoreGui
        flingStatusGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        flingStatusGui.ResetOnSpawn = false
        flingStatusGui.DisplayOrder = 5 -- [PERBAIKAN] Atur agar di bawah menu utama
    
        local FlingBar = Instance.new("Frame")
        FlingBar.Name = "FlingBar"
        FlingBar.Size = UDim2.new(0, 250, 0, 35)
        FlingBar.Position = UDim2.new(0.5, -125, 0, 15)
        FlingBar.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        FlingBar.BackgroundTransparency = 0.2
        FlingBar.BorderSizePixel = 0
        FlingBar.Parent = flingStatusGui
    
        local UICorner = Instance.new("UICorner", FlingBar)
        UICorner.CornerRadius = UDim.new(0, 8)
        local UIStroke = Instance.new("UIStroke", FlingBar)
        UIStroke.Color = Color3.fromRGB(255, 100, 100)
        UIStroke.Thickness = 1
        UIStroke.Transparency = 0.5
    
        local DisableButton = Instance.new("TextButton")
        DisableButton.Name = "DisableButton"
        DisableButton.Size = UDim2.new(1, 0, 1, 0)
        DisableButton.BackgroundTransparency = 1
        DisableButton.Font = Enum.Font.SourceSansBold
        DisableButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        DisableButton.TextSize = 14
        DisableButton.Text = "Hentikan Fling: " .. targetPlayer.DisplayName
        DisableButton.Parent = FlingBar
    
        DisableButton.MouseButton1Click:Connect(function()
            if currentFlingTarget then
                ToggleFlingOnPlayer(currentFlingTarget)
            end
        end)
    end
    
    ToggleFlingOnPlayer = function(targetPlayer)
        if not hasPermission("VIP") then
            showNotification("Silahkan upgrade ke VIP terlebih dahulu, Terimakasih", Color3.fromRGB(255,100,0))
            return
        end
        if flingLoopConnection then
            flingLoopConnection:Disconnect()
            flingLoopConnection = nil
        end
    
        if currentFlingTarget == targetPlayer then
            currentFlingTarget = nil
            showNotification("Fling dihentikan.", Color3.fromRGB(200, 150, 50))
            
            createOrUpdateFlingStatusBar(nil)
            
            local Character = LocalPlayer.Character
            if Character and flingStartPosition then
                local Humanoid = Character:FindFirstChildOfClass("Humanoid")
                local RootPart = Humanoid and Humanoid.RootPart
                
                if RootPart and Humanoid then
                    -- [PERBAIKAN] Hanya kembalikan kamera jika tidak sedang spectate
                    if not IsViewingPlayer then
                        workspace.CurrentCamera.CameraSubject = Humanoid
                    end
                    repeat
                        if not RootPart or not RootPart.Parent then break end
                        RootPart.CFrame = flingStartPosition * CFrame.new(0, 0.5, 0)
                        Character:SetPrimaryPartCFrame(flingStartPosition * CFrame.new(0, 0.5, 0))
                        Humanoid:ChangeState("GettingUp")
                        for _, x in ipairs(Character:GetChildren()) do
                            if x:IsA("BasePart") then
                                x.Velocity, x.RotVelocity = Vector3.new(), Vector3.new()
                            end
                        end
                        task.wait()
                    until not RootPart or not RootPart.Parent or (RootPart.Position - flingStartPosition.p).Magnitude < 25
                end
                flingStartPosition = nil 
            end
        else
            local char = LocalPlayer.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                flingStartPosition = root.CFrame 
            else
                showNotification("Karakter Anda tidak dapat ditemukan untuk memulai fling.", Color3.fromRGB(255, 100, 0))
                return
            end
    
            currentFlingTarget = targetPlayer
            showNotification("Mengaktifkan fling pada " .. targetPlayer.Name, Color3.fromRGB(200, 50, 50))
            
            createOrUpdateFlingStatusBar(targetPlayer)

            flingLoopConnection = RunService.Heartbeat:Connect(function()
                if currentFlingTarget and currentFlingTarget.Parent == Players and currentFlingTarget.Character then
                    pcall(SkidFling, currentFlingTarget)
                else
                    ToggleFlingOnPlayer(currentFlingTarget)
                end
            end)
        end
        updatePlayerList() 
    end

    local function PlayAnim(id, time, speed)
        pcall(function()
            local char = LocalPlayer.Character
            if not (char and char:FindFirstChild("Animate") and char:FindFirstChildOfClass("Humanoid")) then return end
            
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            
            -- Stop previous custom animations to prevent overlap
            for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
                if track.Name == "CustomFlyAnim" then
                    track:Stop(0.1)
                end
            end

            -- Ensure default animations are off
            char.Animate.Disabled = true

            local anim = Instance.new("Animation")
            anim.Name = "CustomFlyAnim" -- Give it a name to identify it later
            anim.AnimationId = "rbxassetid://" .. tostring(id)
            
            local loadanim = humanoid:LoadAnimation(anim)
            loadanim:Play(0.1)
            loadanim.Looped = true -- Fly animations should loop
            
            -- The time and speed parameters seem to be for setting a specific pose
            if time then loadanim.TimePosition = time end
            if speed ~= nil then loadanim:AdjustSpeed(speed) end
        end)
    end

    local function StopAnim()
        local char = LocalPlayer.Character
        if not (char and char:FindFirstChild("Animate") and char:FindFirstChildOfClass("Humanoid")) then return end

        local humanoid = char:FindFirstChildOfClass("Humanoid")
        
        -- Stop all custom flying animations
        for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
            -- A bit more robust check
            if track.Name == "CustomFlyAnim" or (track.Animation and track.Animation.Name == "CustomFlyAnim") then
                track:Stop(0.2)
            end
        end
        
        -- Re-enable default character animations
        pcall(function()
            char.Animate.Disabled = false
        end)
    end

    local function StartFly()
        if IsFlying then return end
        local character = LocalPlayer.Character
        if not (character and character:FindFirstChild("HumanoidRootPart") and character:FindFirstChildOfClass("Humanoid")) then return end
        
        local root = character:WaitForChild("HumanoidRootPart")
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        
        IsFlying = true
        saveFeatureStates()
        humanoid.PlatformStand = true
        
        local bodyGyro = Instance.new("BodyGyro", root)
        bodyGyro.Name = "FlyGyro"
        bodyGyro.P = 9e4
        bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        bodyGyro.CFrame = root.CFrame
        
        local bodyVelocity = Instance.new("BodyVelocity", root)
        bodyVelocity.Name = "FlyVelocity"
        bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)
        
        local controls = {F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0}
        local currentAnim = "idle" -- Lacak status animasi saat ini
        
        -- Animasi idle awal
        PlayAnim(10714347256, 4, 0)

        table.insert(FlyConnections, UserInputService.InputBegan:Connect(function(input, processed)
            if processed or not IsFlying then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local key = input.KeyCode.Name:lower()
                if key == "w" then controls.F = 1
                elseif key == "s" then controls.B = -1
                elseif key == "a" then controls.L = -1
                elseif key == "d" then controls.R = 1
                elseif key == "e" then controls.Q = 1
                elseif key == "q" then controls.E = -1 end
            end
        end))
        
        table.insert(FlyConnections, UserInputService.InputEnded:Connect(function(input, processed)
            if processed or not IsFlying then return end
            if input.UserInputType == Enum.UserInputType.Keyboard then
                local key = input.KeyCode.Name:lower()
                if key == "w" then controls.F = 0
                elseif key == "s" then controls.B = 0
                elseif key == "a" then controls.L = 0
                elseif key == "d" then controls.R = 0
                elseif key == "e" then controls.Q = 0
                elseif key == "q" then controls.E = 0 end
            end
        end))
        
        table.insert(FlyConnections, RunService.RenderStepped:Connect(function()
            if not IsFlying then return end
            
            -- Logika Animasi
            local newAnim = "idle"
            if controls.F > 0 then
                newAnim = "forward"
            elseif controls.B < 0 then
                newAnim = "backward"
            elseif controls.L < 0 then
                newAnim = "left"
            elseif controls.R > 0 then
                newAnim = "right"
            end

            if newAnim ~= currentAnim then
                if newAnim == "idle" then
                    PlayAnim(10714347256, 4, 0) -- Idle
                elseif newAnim == "forward" then
                    PlayAnim(10714177846, 4.65, 0) -- Maju
                elseif newAnim == "backward" then
                    PlayAnim(10147823318, 4.11, 0) -- Mundur
                elseif newAnim == "left" then
                    PlayAnim(10147823318, 3.55, 0) -- Kiri
                elseif newAnim == "right" then
                    PlayAnim(10147823318, 4.81, 0) -- Kanan
                end
                currentAnim = newAnim
            end

            -- Logika Gerakan
            local speed = (controls.L + controls.R ~= 0 or controls.F + controls.B ~= 0 or controls.Q + controls.E ~= 0) and (Settings.FlySpeed * 50) or 0
            local camera = Workspace.CurrentCamera
            
            if speed ~= 0 then
                local moveVector = Vector3.new(controls.L + controls.R, controls.Q + controls.E, -(controls.F + controls.B))
                bodyVelocity.Velocity = (camera.CFrame:VectorToWorldSpace(moveVector.Unit)) * speed
            else
                bodyVelocity.Velocity = Vector3.new(0, 0.1, 0) -- Sedikit gaya ke atas untuk melawan gravitasi
            end
            
            bodyGyro.CFrame = camera.CFrame
        end))
    end

    local function StopFly()
        if not IsFlying then return end
        IsFlying = false
        saveFeatureStates()
        
        StopAnim() -- Stop custom animations and re-enable default ones
        
        local character = LocalPlayer.Character
        if character and character:FindFirstChildOfClass("Humanoid") then
            character.Humanoid.PlatformStand = false
        end
        
        for _, conn in pairs(FlyConnections) do conn:Disconnect() end
        FlyConnections = {}
        
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root then
            if root:FindFirstChild("FlyGyro") then root.FlyGyro:Destroy() end
            if root:FindFirstChild("FlyVelocity") then root.FlyVelocity:Destroy() end
        end
        
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    end

    local function StopMobileFly()
        if not IsFlying then return end
        IsFlying = false
        saveFeatureStates()
        
        StopAnim() -- Stop custom animations

        local character = LocalPlayer.Character
        if character and character:FindFirstChildOfClass("Humanoid") then
            character.Humanoid.PlatformStand = false
        end
        
        for _, conn in pairs(FlyConnections) do conn:Disconnect() end
        FlyConnections = {}
        
        local root = character and character:FindFirstChild("HumanoidRootPart")
        if root then
            if root:FindFirstChild("FlyGyro") then root.FlyGyro:Destroy() end
            if root:FindFirstChild("FlyVelocity") then root.FlyVelocity:Destroy() end
        end
        
        Workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
    end

    local function StartMobileFly()
        if IsFlying then return end
        local character = LocalPlayer.Character
        if not (character and character:FindFirstChild("HumanoidRootPart") and character:FindFirstChildOfClass("Humanoid")) then return end

        local root = character:WaitForChild("HumanoidRootPart")
        local humanoid = character:FindFirstChildOfClass("Humanoid")

        local success, controlModule = pcall(require, LocalPlayer.PlayerScripts:WaitForChild("PlayerModule"):WaitForChild("ControlModule"))
        if not success then
            showNotification("Gagal memuat modul kontrol mobile.", Color3.fromRGB(255, 100, 100))
            return
        end

        IsFlying = true
        saveFeatureStates()
        humanoid.PlatformStand = true

        local bodyVelocity = Instance.new("BodyVelocity", root)
        bodyVelocity.Name = "FlyVelocity"
        bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bodyVelocity.Velocity = Vector3.new(0, 0, 0)

        local bodyGyro = Instance.new("BodyGyro", root)
        bodyGyro.Name = "FlyGyro"
        bodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        bodyGyro.P = 1000
        bodyGyro.D = 50

        local currentAnim = "idle"
        PlayAnim(10714347256, 4, 0) -- Animasi idle awal

        table.insert(FlyConnections, RunService.RenderStepped:Connect(function()
            if not IsFlying then return end

            local camera = Workspace.CurrentCamera
            if not (character and root and root:FindFirstChild("FlyVelocity") and root:FindFirstChild("FlyGyro")) then
                StopMobileFly()
                return
            end

            root.FlyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            root.FlyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
            root.FlyGyro.CFrame = camera.CFrame

            local direction = controlModule:GetMoveVector()
            local speed = Settings.FlySpeed * 50

            -- Logika Animasi Mobile
            local newAnim = "idle"
            if direction.Magnitude > 0.1 then
                if direction.Z < -0.5 then
                    newAnim = "forward"
                elseif direction.Z > 0.5 then
                    newAnim = "backward"
                elseif direction.X < -0.5 then
                    newAnim = "left"
                elseif direction.X > 0.5 then
                    newAnim = "right"
                else
                    newAnim = "forward" -- Default ke depan jika bergerak diagonal
                end
            end

            if newAnim ~= currentAnim then
                if newAnim == "idle" then
                    PlayAnim(10714347256, 4, 0) -- Idle
                elseif newAnim == "forward" then
                    PlayAnim(10714177846, 4.65, 0) -- Maju
                elseif newAnim == "backward" then
                    PlayAnim(10147823318, 4.11, 0) -- Mundur
                elseif newAnim == "left" then
                    PlayAnim(10147823318, 3.55, 0) -- Kiri
                elseif newAnim == "right" then
                    PlayAnim(10147823318, 4.81, 0) -- Kanan
                end
                currentAnim = newAnim
            end

            -- Logika Gerakan Mobile
            if direction.Magnitude > 0.1 then
                root.FlyVelocity.Velocity = (camera.CFrame.RightVector * direction.X + camera.CFrame.LookVector * -direction.Z) * speed
            else
                root.FlyVelocity.Velocity = Vector3.new(0, 0.1, 0) -- Melawan gravitasi
            end
        end))
    end

    local function ToggleNoclip(enabled)
        IsNoclipEnabled = enabled
        saveFeatureStates()
        if enabled then task.spawn(function() while IsNoclipEnabled and LocalPlayer.Character do for _, part in pairs(LocalPlayer.Character:GetDescendants()) do if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end end; task.wait(0.1) end; if LocalPlayer.Character then for _, part in pairs(LocalPlayer.Character:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = true end end end end) end
    end

    local function applyGodMode(character)
        if not character then return end; local humanoid = character:FindFirstChildOfClass("Humanoid"); if not humanoid then return end; if godModeConnection then godModeConnection:Disconnect(); godModeConnection = nil end
        godModeConnection = humanoid.HealthChanged:Connect(function(newHealth) if newHealth <= 0 and IsGodModeEnabled then humanoid.Health = humanoid.MaxHealth end end)
    end

    local function ToggleGodMode(enabled)
        IsGodModeEnabled = enabled; saveFeatureStates(); if enabled then if LocalPlayer.Character then applyGodMode(LocalPlayer.Character) end elseif godModeConnection then godModeConnection:Disconnect(); godModeConnection = nil end
    end

    local function ToggleWalkSpeed(enabled)
        IsWalkSpeedEnabled = enabled; saveFeatureStates(); if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then LocalPlayer.Character.Humanoid.WalkSpeed = enabled and Settings.WalkSpeed or OriginalWalkSpeed end
    end

    local function CreateTouchFlingGUI()
        if not hasPermission("VIP") then
            showNotification("Silahkan upgrade ke VIP terlebih dahulu, Terimakasih", Color3.fromRGB(255,100,0))
            return
        end
        if touchFlingGui and touchFlingGui.Parent then return end; local FlingScreenGui = Instance.new("ScreenGui"); FlingScreenGui.Name = "ArexansTouchFlingGUI"; FlingScreenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui"); FlingScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; FlingScreenGui.ResetOnSpawn = false; touchFlingGui = FlingScreenGui
        local Frame = Instance.new("Frame", FlingScreenGui); Frame.BackgroundColor3 = Color3.fromRGB(170, 200, 255); Frame.BackgroundTransparency = 0.3; Frame.BorderSizePixel = 0; 
        Frame.Position = UDim2.new(0.5, -45, 0, 20); 
        if loadedGuiPositions and loadedGuiPositions.FlingFrame then
            local posData = loadedGuiPositions.FlingFrame
            pcall(function() Frame.Position = UDim2.new(posData.XScale, posData.XOffset, posData.YScale, posData.YOffset) end)
        end
        Frame.Size = UDim2.new(0, 90, 0, 56); local FrameUICorner = Instance.new("UICorner", Frame); FrameUICorner.CornerRadius = UDim.new(0, 6); local FrameUIStroke = Instance.new("UIStroke", Frame); FrameUIStroke.Color = Color3.fromRGB(0, 100, 255); FrameUIStroke.Thickness = 1.5; FrameUIStroke.Transparency = 0.2
        local TitleBar = Instance.new("TextButton", Frame); TitleBar.BackgroundColor3 = Color3.fromRGB(140, 170, 235); TitleBar.BackgroundTransparency = 0.4; TitleBar.BorderSizePixel = 0; TitleBar.Size = UDim2.new(1, 0, 0, 18); TitleBar.Text = ""; TitleBar.AutoButtonColor = false
        MakeDraggable(Frame, TitleBar, function() return true end, nil)
        
        local TitleLabel = Instance.new("TextLabel", TitleBar); TitleLabel.BackgroundTransparency = 1.0; TitleLabel.Size = UDim2.new(1, -20, 1, 0); TitleLabel.Position = UDim2.new(0, 5, 0, 0); TitleLabel.Font = Enum.Font.SourceSansBold; TitleLabel.Text = "Touch Fling"; TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255); TitleLabel.TextSize = 11; TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
        local OnOffButton = Instance.new("TextButton", Frame); OnOffButton.BackgroundColor3 = Color3.fromRGB(0, 120, 255); OnOffButton.BorderSizePixel = 0; OnOffButton.Position = UDim2.new(0.5, -30, 0, 25); OnOffButton.Size = UDim2.new(0, 60, 0, 22); OnOffButton.Font = Enum.Font.SourceSansBold; OnOffButton.Text = "OFF"; OnOffButton.TextColor3 = Color3.fromRGB(255, 255, 255); OnOffButton.TextSize = 14; local OnOffButtonCorner = Instance.new("UICorner", OnOffButton); OnOffButtonCorner.CornerRadius = UDim.new(0, 5); local OnOffButtonGradient = Instance.new("UIGradient", OnOffButton); OnOffButtonGradient.Color = ColorSequence.new(Color3.fromRGB(100, 180, 255), Color3.fromRGB(80, 150, 255)); OnOffButtonGradient.Rotation = 90
        local CloseButton = Instance.new("TextButton", TitleBar); CloseButton.Size = UDim2.new(0, 16, 0, 16); CloseButton.Position = UDim2.new(1, -18, 0.5, -8); CloseButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50); CloseButton.Text = "X"; CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255); CloseButton.Font = Enum.Font.SourceSansBold; CloseButton.TextSize = 11; local corner = Instance.new("UICorner", CloseButton); corner.CornerRadius = UDim.new(1, 0)
        local hiddenfling, flingThread = false, nil
        local function fling() while hiddenfling do local hrp = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if hrp then local vel = hrp.Velocity; hrp.Velocity = vel * 50000 + Vector3.new(0, 50000, 0); RunService.RenderStepped:Wait(); if hrp and hrp.Parent then hrp.Velocity = vel end; RunService.Stepped:Wait(); if hrp and hrp.Parent then hrp.Velocity = vel + Vector3.new(0, 0.1 * (math.random(0, 1) == 0 and -1 or 1), 0) end end; RunService.Heartbeat:Wait() end end
        OnOffButton.MouseButton1Click:Connect(function() hiddenfling = not hiddenfling; OnOffButton.Text = hiddenfling and "ON" or "OFF"; if hiddenfling then if not flingThread or coroutine.status(flingThread) == "dead" then flingThread = coroutine.create(fling); coroutine.resume(flingThread) end end end)
        CloseButton.MouseButton1Click:Connect(function() hiddenfling = false; FlingScreenGui:Destroy(); touchFlingGui = nil end)
    end
    
    
    local function protect_character()
        local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"); if root and antifling_enabled then if root.Velocity.Magnitude <= antifling_velocity_threshold then antifling_last_safe_cframe = root.CFrame end; if root.Velocity.Magnitude > antifling_velocity_threshold and antifling_last_safe_cframe then root.Velocity, root.AssemblyLinearVelocity, root.AssemblyAngularVelocity, root.CFrame = Vector3.new(), Vector3.new(), Vector3.new(), antifling_last_safe_cframe end; if root.AssemblyAngularVelocity.Magnitude > antifling_angular_threshold then root.AssemblyAngularVelocity = Vector3.new() end; if LocalPlayer.Character.Humanoid:GetState() == Enum.HumanoidStateType.FallingDown then LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end end
    end
    
    -- [[ FE INVISIBLE INTEGRATION ]]
    local function setCharacterTransparency(character, transparency)
        if not character then return end
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                part.Transparency = transparency
            end
        end
    end

    local function ToggleFEInvisible(enabled)
        IsFEInvisibleEnabled = enabled
        saveFeatureStates()

        local character = LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            if enabled then
                IsFEInvisibleEnabled = false -- Turn it back off if there's no character
                saveFeatureStates()
            end
            return
        end

        feInvisSeat = Workspace:FindFirstChild("ArexansInvisSeat")

        if enabled then
            setCharacterTransparency(character, Settings.FEInvisibleTransparency)
            
            local savedpos = character:GetPrimaryPartCFrame()
            
            task.wait(0.05)
            character:SetPrimaryPartCFrame(CFrame.new(0, 10000, 0)) -- Teleport to a safe height
            task.wait(0.05)

            if not character.PrimaryPart or character.PrimaryPart.Position.Y < -500 then
                character:SetPrimaryPartCFrame(savedpos)
                ToggleFEInvisible(false) -- Revert if teleport failed
                return
            end

            local Seat = Instance.new('Seat', Workspace)
            Seat.Name = "ArexansInvisSeat"
            Seat.Anchored = true
            Seat.CanCollide = false
            Seat.Transparency = 1
            Seat.CFrame = character:GetPrimaryPartCFrame()

            local Weld = Instance.new("WeldConstraint")
            Weld.Part0 = Seat
            Weld.Part1 = character.PrimaryPart
            Weld.Parent = Seat
            
            task.wait()
            Seat.Anchored = false
            pcall(function() Seat.CFrame = savedpos end)
            feInvisSeat = Seat
        else
            setCharacterTransparency(character, 0)
            if feInvisSeat and feInvisSeat.Parent then
                feInvisSeat:Destroy()
            end
            feInvisSeat = nil
        end
    end
    -- [[ END FE INVISIBLE INTEGRATION ]]

    local function UpdateShiftLock()
        if not IsShiftLockEnabled then return end
        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")

        if not (humanoid and rootPart and humanoid.Health > 0) then return end
        
        humanoid.AutoRotate = false
        local cameraLookVector = Workspace.CurrentCamera.CFrame.LookVector
        local lookAtPosition = rootPart.Position + Vector3.new(cameraLookVector.X, 0, cameraLookVector.Z)
        rootPart.CFrame = CFrame.new(rootPart.Position, lookAtPosition)
    end

    local function ToggleShiftLock(enabled)
        IsShiftLockEnabled = enabled
        saveFeatureStates()

        local character = LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")

        if enabled then
            if humanoid then humanoid.AutoRotate = false end
            if not shiftLockConnection then
                shiftLockConnection = RunService.RenderStepped:Connect(UpdateShiftLock)
            end
        else
            if humanoid then humanoid.AutoRotate = true end
            if shiftLockConnection then
                shiftLockConnection:Disconnect()
                shiftLockConnection = nil
            end
        end
    end

    local function ToggleAntiFling(enabled)
        antifling_enabled = enabled; saveFeatureStates(); if enabled and not antifling_connection then antifling_connection = RunService.Heartbeat:Connect(protect_character) elseif not enabled and antifling_connection then antifling_connection:Disconnect(); antifling_connection = nil end
    end

    local function ToggleAntiAFK(enabled)
        IsAntiAFKEnabled = enabled
        saveFeatureStates()
        if enabled then
            if not antiAFKConnection then
                antiAFKConnection = ConnectEvent(LocalPlayer.Idled, function()
                    local VirtualUser = game:GetService("VirtualUser")
                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            end
        else
            if antiAFKConnection then
                antiAFKConnection:Disconnect()
                antiAFKConnection = nil
            end
        end
    end

    -- [[ AWAL INTEGRASI FUNGSI MAGNET.LUA ]]
    local stopMagnet, playMagnet, scanForParts, createMagnetGUI

    stopMagnet = function()
        if not isMagnetActive then return end
        isMagnetActive = false
        if magnetConnection then magnetConnection:Disconnect(); magnetConnection = nil end
        
        task.spawn(function()
            for _, part in ipairs(scannedParts) do
                if part and part.Parent and part:IsA("BasePart") then
                    part.AssemblyLinearVelocity = Vector3.zero
                    pcall(function() part:SetNetworkOwner(nil) end)
                end
            end
        end)
    end

    scanForParts = function(rangeBox, statusLabel)
        local rangeValue = tonumber(rangeBox.Text)
        if not rangeValue or rangeValue <= 0 then showNotification("Range tidak valid!", Color3.fromRGB(255, 100, 100)); return end
        
        stopMagnet()
        scannedParts = {}
        partGoals = {}
        
        showNotification("Mencari objek...", Color3.fromRGB(220, 220, 220))
        task.wait(0.1)
        local character = LocalPlayer.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then showNotification("Karakter tidak ditemukan!", Color3.fromRGB(255, 100, 100)); return end
        
        scanCenterPosition = character.HumanoidRootPart.Position
        
        local partsInWorkspace = Workspace:GetPartBoundsInRadius(scanCenterPosition, rangeValue)
        for _, part in ipairs(partsInWorkspace) do
            if part:IsA("BasePart") and not part.Anchored and not character:IsAncestorOf(part) then
                pcall(function() part:SetNetworkOwner(LocalPlayer) end)
                table.insert(scannedParts, part)
            end
        end
        local count = #scannedParts
        showNotification("Scan Selesai: " .. count .. " objek ditemukan.", Color3.fromRGB(100, 255, 100))
        if statusLabel then
            statusLabel.Text = "Parts: " .. count
            statusLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
        end
    end

    playMagnet = function(powerBox)
        if isMagnetActive then return false end
        local powerValue = tonumber(powerBox.Text)
        if not powerValue or powerValue <= 0 then showNotification("Power tidak valid!", Color3.fromRGB(255, 100, 100)); return false end
        magnetPower = powerValue
        if #scannedParts == 0 then showNotification("Tidak ada objek hasil scan. Scan dulu!", Color3.fromRGB(255, 200, 100)); return false end
        isMagnetActive = true

        magnetConnection = RunService.Heartbeat:Connect(function(deltaTime)
            if not isMagnetActive then
                if magnetConnection then magnetConnection:Disconnect(); magnetConnection = nil end
                return
            end
            local character = LocalPlayer.Character
            local rootPart = character and character:FindFirstChild("HumanoidRootPart")
            if not rootPart then stopMagnet(); return end
            
            local forceMultiplier = magnetPower * 2500 * deltaTime

            for i = #scannedParts, 1, -1 do
                local part = scannedParts[i]
                if part and part.Parent then
                    local targetPosition
                    
                    if magnetMode == "random_free" then
                        local goal = partGoals[part]
                        local distanceToGoal = goal and (part.Position - goal).Magnitude or 100
                        
                        if not goal or distanceToGoal < 15 then
                            local randomOffset = Vector3.new(math.random(-magnetRange, magnetRange), math.random(5, 50), math.random(-magnetRange, magnetRange))
                            partGoals[part] = scanCenterPosition + randomOffset
                        end
                        targetPosition = partGoals[part]
                    else -- Mode "target_player"
                        targetPosition = rootPart.Position
                    end

                    local direction = (targetPosition - part.Position)
                    local distance = direction.Magnitude
                    if distance < 1 then distance = 1 end
                    
                    local velocity = direction.Unit * forceMultiplier * (1 / distance)
                    part.AssemblyLinearVelocity = velocity
                else
                    table.remove(scannedParts, i)
                end
            end
        end)
        return true
    end

    createMagnetGUI = function()
        if not hasPermission("VIP") then
            showNotification("Silahkan upgrade ke VIP terlebih dahulu, Terimakasih", Color3.fromRGB(255,100,0))
            return
        end
        if MagnetGUI and MagnetGUI.Parent then
            MagnetGUI:Destroy()
        end
        MagnetGUI = Instance.new("ScreenGui", CoreGui)
        MagnetGUI.Name = "MagnetGUI"
        MagnetGUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        MagnetGUI.ResetOnSpawn = false

        local MainFrame = Instance.new("Frame", MagnetGUI)
        MainFrame.Name = "MainFrame"
        MainFrame.Size = UDim2.new(0, 180, 0, 95)
        MainFrame.Position = UDim2.new(0.1, 0, 0.5, -55)
        MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        MainFrame.BackgroundTransparency = 0.5
        local MainUICorner = Instance.new("UICorner", MainFrame); MainUICorner.CornerRadius = UDim.new(0, 8)
        local UIStroke = Instance.new("UIStroke", MainFrame); UIStroke.Color = Color3.fromRGB(0, 150, 255); UIStroke.Thickness = 1.5

        local TitleBar = Instance.new("TextButton", MainFrame)
        TitleBar.Name = "TitleBar"; TitleBar.Size = UDim2.new(1, 0, 0, 25)
        TitleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25); TitleBar.Text = ""
        local TitleBarCorner = Instance.new("UICorner", TitleBar); TitleBarCorner.CornerRadius = UDim.new(0, 8)
        TitleBar.AutoButtonColor = false
        MakeDraggable(MainFrame, TitleBar, function() return true end, nil)

        local TitleLabel = Instance.new("TextLabel", TitleBar)
        TitleLabel.Size = UDim2.new(0.4, 0, 1, 0); TitleLabel.Position = UDim2.new(0, 8, 0, 0)
        TitleLabel.BackgroundTransparency = 1; TitleLabel.Text = "Magnet"
        TitleLabel.TextColor3 = Color3.fromRGB(0, 200, 255); TitleLabel.TextSize = 12
        TitleLabel.Font = Enum.Font.SourceSansBold; TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

        local statusLabel = Instance.new("TextLabel", TitleBar)
        statusLabel.Size = UDim2.new(0.5, 0, 1, 0); statusLabel.Position = UDim2.new(0.3, 0, 0, 0)
        statusLabel.BackgroundTransparency = 1; statusLabel.Text = "Parts: " .. #scannedParts
        statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180); statusLabel.TextSize = 10
        statusLabel.Font = Enum.Font.SourceSans; statusLabel.TextXAlignment = Enum.TextXAlignment.Center
        
        local closeBtn = Instance.new("TextButton",TitleBar)
        closeBtn.Size = UDim2.new(0,18,0,18); closeBtn.Position = UDim2.new(1,-22,0.5,-9); closeBtn.BackgroundTransparency = 1; closeBtn.Font = Enum.Font.SourceSansBold; closeBtn.Text = "X"; closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); closeBtn.TextSize = 16

        local minimizeBtn = Instance.new("TextButton", TitleBar)
        minimizeBtn.Size = UDim2.new(0, 18, 0, 18); minimizeBtn.Position = UDim2.new(1, -42, 0.5, -9); minimizeBtn.BackgroundTransparency = 1; minimizeBtn.Font = Enum.Font.SourceSansBold; minimizeBtn.Text = "-"; minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); minimizeBtn.TextSize = 20

        local ContentFrame = Instance.new("Frame", MainFrame)
        ContentFrame.Name = "ContentFrame"; ContentFrame.ClipsDescendants = true
        ContentFrame.Size = UDim2.new(1, -10, 1, -30)
        ContentFrame.Position = UDim2.new(0, 5, 0, 25)
        ContentFrame.BackgroundTransparency = 1
        local ContentLayout = Instance.new("UIListLayout", ContentFrame); ContentLayout.Padding = UDim.new(0, 4)

        local function createIconButton(parent, text, size, callback)
            local btn = Instance.new("TextButton", parent)
            btn.Size = UDim2.new(0, size, 0, 24); btn.Text = text
            btn.Font = Enum.Font.SourceSansBold; btn.TextSize = 16
            btn.TextColor3 = Color3.new(1, 1, 1)
            local corner = Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0, 5)
            if callback then btn.MouseButton1Click:Connect(callback) end
            return btn
        end
        
        local function createCompactTextBox(parent, name, defaultValue)
            local frame = Instance.new("Frame", parent)
            frame.BackgroundTransparency = 1; frame.Size = UDim2.new(0, 55, 0, 24)
            
            local label = Instance.new("TextLabel", frame)
            label.Size = UDim2.new(1, 0, 0, 12); label.BackgroundTransparency = 1; label.Font = Enum.Font.SourceSans
            label.Text = name; label.TextColor3 = Color3.fromRGB(200, 200, 200); label.TextSize = 10
            label.TextXAlignment = Enum.TextXAlignment.Center
            
            local textBox = Instance.new("TextBox", frame)
            textBox.Size = UDim2.new(1, 0, 1, -12); textBox.Position = UDim2.new(0, 0, 0, 12)
            textBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35); textBox.TextColor3 = Color3.fromRGB(220, 220, 220)
            textBox.Text = tostring(defaultValue); textBox.Font = Enum.Font.SourceSans; textBox.TextSize = 11
            textBox.TextXAlignment = Enum.TextXAlignment.Center
            local corner = Instance.new("UICorner", textBox); corner.CornerRadius = UDim.new(0, 4)
            
            return frame, textBox 
        end

        local controlsRow = Instance.new("Frame", ContentFrame)
        controlsRow.BackgroundTransparency = 1; controlsRow.Size = UDim2.new(1, 0, 0, 28)

        local rangeFrame, rangeTextBox = createCompactTextBox(controlsRow, "Range", magnetRange)
        rangeFrame.Position = UDim2.new(0, 0, 0.5, -12)

        local powerFrame, powerTextBox = createCompactTextBox(controlsRow, "Power", magnetPower)
        powerFrame.Position = UDim2.new(0, 70, 0.5, -12)

        local scanButton = createIconButton(controlsRow, "📡", 30, function() scanForParts(rangeTextBox, statusLabel) end)
        scanButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255)
        scanButton.Position = UDim2.new(0, 140, 0.5, -12) 

        local modeRow = Instance.new("Frame", ContentFrame)
        modeRow.BackgroundTransparency = 1; modeRow.Size = UDim2.new(1, 0, 0, 28)

        local MODES = { {Name = "Ke Karakter", ID = "target_player"}, {Name = "Acak", ID = "random_free"} }
        local currentModeIndex = 1

        local prevBtn = createIconButton(modeRow, "<", 25)
        prevBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        prevBtn.Position = UDim2.new(0, 0, 0.5, -12)

        local nextBtn = createIconButton(modeRow, ">", 25)
        nextBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        nextBtn.Position = UDim2.new(0, 95, 0.5, -12)

        local modeLabel = Instance.new("TextLabel", modeRow)
        modeLabel.Size = UDim2.new(0, 70, 1, 0); 
        modeLabel.Position = UDim2.new(0, 25, 0, 0)
        modeLabel.BackgroundTransparency = 1; modeLabel.Font = Enum.Font.SourceSansBold
        modeLabel.TextSize = 10; modeLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        modeLabel.TextWrapped = true; modeLabel.TextXAlignment = Enum.TextXAlignment.Center
        
        local toggleButton = createIconButton(modeRow, "▶️", 30)
        toggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        toggleButton.Position = UDim2.new(1, -30, 0.5, -12)
        
        local function updateModeDisplay()
            local currentModeData = MODES[currentModeIndex]
            magnetMode = currentModeData.ID
            modeLabel.Text = currentModeData.Name
        end
        
        prevBtn.MouseButton1Click:Connect(function()
            currentModeIndex = currentModeIndex - 1
            if currentModeIndex < 1 then currentModeIndex = #MODES end
            updateModeDisplay()
        end)
        
        nextBtn.MouseButton1Click:Connect(function()
            currentModeIndex = currentModeIndex + 1
            if currentModeIndex > #MODES then currentModeIndex = 1 end
            updateModeDisplay()
        end)
        
        updateModeDisplay()

        toggleButton.MouseButton1Click:Connect(function()
            if isMagnetActive then
                stopMagnet(); toggleButton.Text = "▶️"; toggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
            else
                if playMagnet(powerTextBox) then toggleButton.Text = "⏹️"; toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50) end
            end
        end)
        
        closeBtn.MouseButton1Click:Connect(function() if isMagnetActive then stopMagnet() end; MagnetGUI:Destroy() end)
        
        local isMinimized = false; 
        local originalSize = MainFrame.Size
        local minimizedSize = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, TitleBar.Size.Y.Offset)
        
        minimizeBtn.MouseButton1Click:Connect(function()
            isMinimized = not isMinimized
            ContentFrame.Visible = not isMinimized
            local targetSize = isMinimized and minimizedSize or originalSize
            TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = targetSize}):Play()
        end)
    end
    -- [[ AKHIR INTEGRASI FUNGSI MAGNET.LUA ]]

    -- [[ AWAL INTEGRASI FUNGSI PARTCONTROLLER.LUA ]]
    local pc_modes = {}
    local startPartController, stopPartController, createPartControllerGUI, pc_fullRestore

    local function pc_getPos() return LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position end
    local function pc_getLook() return LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.CFrame.LookVector or Vector3.new(0,0,-1) end

    local function pc_cleanBodyPositions()
        for _, bp in pairs(pc_state.bodyPositions) do
            if bp and bp.Parent then bp:Destroy() end
        end
        pc_state.bodyPositions = {}
    end
    
    local function pc_force(part, targetPos)
        if not part or not part.Parent then return end
        pcall(function()
            part.Anchored = false
            part.CanCollide = false
            for _, child in pairs(part:GetChildren()) do if child:IsA("BodyPosition") or child:IsA("BodyVelocity") or child:IsA("BodyGyro") then child:Destroy() end end
            local bp = Instance.new("BodyPosition")
            bp.MaxForce = Vector3.new(pc_config.magnetForce, pc_config.magnetForce, pc_config.magnetForce)
            bp.Position = targetPos; bp.P = 10000; bp.D = 500; bp.Parent = part
            table.insert(pc_state.bodyPositions, bp)
        end)
    end

    pc_modes.bring = function() local p=pc_getPos() if not p then return end for i,pt in pairs(pc_state.parts) do if pt and pt.Parent then local o=Vector3.new(math.random(-15,15),math.random(10,30),math.random(-15,15)) pc_force(pt,p+o) end end end
    pc_modes.ring = function() local p=pc_getPos() if not p then return end local t=tick()*pc_config.speed*0.5 for i,pt in pairs(pc_state.parts) do if pt and pt.Parent then local a=((i/#pc_state.parts)*math.pi*2)+t local r=8 local o=Vector3.new(math.cos(a)*r,5,math.sin(a)*r) pc_force(pt,p+o) end end end
    pc_modes.tornado = function() local p=pc_getPos() if not p then return end local t=tick()*pc_config.speed for i,pt in pairs(pc_state.parts) do if pt and pt.Parent then local h=((i-1)%10)*4 local r=5+(h/8) local a=t+(i*0.5) local o=Vector3.new(math.cos(a)*r,h,math.sin(a)*r) pc_force(pt,p+o) end end end
    pc_modes.blackhole = function() local p=pc_getPos() if not p then return end local c=p+Vector3.new(0,10,0) local t=tick()*pc_config.speed for i,pt in pairs(pc_state.parts) do if pt and pt.Parent then local a=(i*0.5)+(t*0.3) local r=3 local o=Vector3.new(math.cos(a)*r,math.sin(t+i*0.2)*2,math.sin(a)*r) pc_force(pt,c+o) end end end
    pc_modes.orbit = function() local p=pc_getPos() if not p then return end local c=p+Vector3.new(0,8,0) local t=tick()*pc_config.speed*0.3 for i,pt in pairs(pc_state.parts) do if pt and pt.Parent then local r=10+((i%3)*3) local a=t+(i*0.8) local o=Vector3.new(math.cos(a)*r,math.sin(a*0.5)*4,math.sin(a)*r) pc_force(pt,c+o) end end end
    pc_modes.spiral = function() local p=pc_getPos() if not p then return end local t=tick()*pc_config.speed*0.5 for i,pt in pairs(pc_state.parts) do if pt and pt.Parent then local h=p.Y+(i*1)+(t%15) local a=(i*0.5)+t local r=8 pc_force(pt,Vector3.new(p.X+math.cos(a)*r,h,p.Z+math.sin(a)*r)) end end end
    pc_modes.wave = function() local p=pc_getPos() if not p then return end local t=tick()*pc_config.speed for i,pt in pairs(pc_state.parts) do if pt and pt.Parent then local h=p.Y+8+math.sin(t+i*0.5)*5 pc_force(pt,Vector3.new(p.X+((i%10)*3)-15,h,p.Z+math.cos(t+i*0.3)*5)) end end end
    pc_modes.fountain = function() local p=pc_getPos() if not p then return end local t=tick()*pc_config.speed for i,pt in pairs(pc_state.parts) do if pt and pt.Parent then local a=(i/#pc_state.parts)*math.pi*2 local h=p.Y+3+math.abs(math.sin(t+i*0.5))*12 local r=4 pc_force(pt,Vector3.new(p.X+math.cos(a)*r,h,p.Z+math.sin(a)*r)) end end end
    pc_modes.shield = function() local p=pc_getPos() if not p then return end local t=tick()*pc_config.speed for i,pt in pairs(pc_state.parts) do if pt and pt.Parent then local a=((i/#pc_state.parts)*math.pi*2)+t local r=8 pc_force(pt,Vector3.new(p.X+math.cos(a)*r,p.Y+2,p.Z+math.sin(a)*r)) end end end
    pc_modes.sphere = function() local p=pc_getPos() if not p then return end local c=p+Vector3.new(0,10,0) for i,pt in pairs(pc_state.parts) do if pt and pt.Parent then local phi=math.acos(-1+(2*i)/#pc_state.parts) local theta=math.sqrt(#pc_state.parts*math.pi)*phi local r=10 local o=Vector3.new(r*math.cos(theta)*math.sin(phi),r*math.cos(phi),r*math.sin(theta)*math.sin(phi)) pc_force(pt,c+o) end end end
    pc_modes.launch = function() local p=pc_getPos() if not p then return end local l=pc_getLook() for i=1,math.min(5,#pc_state.parts) do local idx=((pc_state.timeOffset+i-1)%#pc_state.parts)+1 local pt=pc_state.parts[idx] if pt and pt.Parent then pcall(function() pt:BreakJoints() for _,c in pairs(pt:GetChildren()) do if c:IsA("BodyVelocity") then c:Destroy() end end local bv=Instance.new("BodyVelocity") bv.MaxForce=Vector3.new(math.huge,math.huge,math.huge) bv.Velocity=l*pc_config.launchSpeed+Vector3.new(math.random(-10,10),math.random(0,20),math.random(-10,10)) bv.Parent=pt task.delay(2,function() if bv and bv.Parent then bv:Destroy() end end) end) end end end
    pc_modes.explosion=pc_modes.launch; pc_modes.galaxy=pc_modes.ring; pc_modes.dna=pc_modes.spiral; pc_modes.supernova=pc_modes.blackhole; pc_modes.matrix=pc_modes.bring; pc_modes.vortex=pc_modes.tornado; pc_modes.meteor=pc_modes.launch; pc_modes.portal=pc_modes.ring; pc_modes.dragon=pc_modes.spiral; pc_modes.infinity=pc_modes.wave; pc_modes.tsunami=pc_modes.wave; pc_modes.solar=pc_modes.orbit; pc_modes.quantum=pc_modes.bring

    local pc_temporaryStorage = nil

    local function pc_clearAndStoreConstraints()
        if not pc_temporaryStorage then showNotification("Penyimpanan sementara tidak ditemukan!", Color3.fromRGB(200,50,50)) return 0 end
        
        local storedCount = 0
        for _, obj in pairs(Workspace:GetDescendants()) do
            if obj:IsA("RopeConstraint") or obj:IsA("WeldConstraint") or obj:IsA("Weld") or (obj:IsA("Attachment") and not obj.Parent:FindFirstChildOfClass("Humanoid")) then
                pcall(function()
                    local isStored = false
                    for _, entry in pairs(pc_state.removedItems) do if entry.item == obj then isStored = true break end end
                    
                    if not isStored then
                        table.insert(pc_state.removedItems, {item = obj, parent = obj.Parent})
                        obj.Parent = pc_temporaryStorage
                        storedCount = storedCount + 1
                    end
                end)
            end
        end
        return storedCount
    end

    local function pc_scan()
        pc_state.parts = {}
        pc_cleanBodyPositions()
        local p = pc_getPos()
        if not p then showNotification("Posisi pemain tidak ditemukan", Color3.fromRGB(200,50,50)) return {} end
        
        local scanned = 0
        for _, obj in pairs(Workspace:GetDescendants()) do
            if scanned >= pc_config.partLimit then break end
            if obj:IsA("BasePart") and not (LocalPlayer.Character and obj:IsDescendantOf(LocalPlayer.Character)) then
                if (obj.Position - p).Magnitude <= pc_config.radius then
                    pcall(function()
                        if not pc_state.originalProperties[obj] then
                            pc_state.originalProperties[obj] = {Anchored = obj.Anchored, CanCollide = obj.CanCollide}
                        end
                        
                        for _, c in pairs(obj:GetChildren()) do
                            if c:IsA("Constraint") or c:IsA("Weld") or c:IsA("Attachment") then
                                local isStored = false
                                for _, entry in pairs(pc_state.removedItems) do if entry.item == c then isStored = true break end end
                                if not isStored and pc_temporaryStorage then
                                    table.insert(pc_state.removedItems, {item = c, parent = c.Parent})
                                    c.Parent = pc_temporaryStorage
                                end
                            end
                        end
                        
                        obj.Anchored = false
                        obj.CanCollide = false
                        table.insert(pc_state.parts, obj)
                        scanned = scanned + 1
                    end)
                end
            end
        end
        return pc_state.parts
    end

    stopPartController = function()
        if pc_state.connection then pc_state.connection:Disconnect(); pc_state.connection=nil end
        pc_state.active = false
        pc_cleanBodyPositions()
        if PartControllerGUI then
             local toggleButton = PartControllerGUI:FindFirstChild("toggleButton", true)
             if toggleButton then
                toggleButton.Text = "▶️"
                toggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
             end
        end
    end

    startPartController = function()
        if pc_state.active then return end
        if #pc_state.parts == 0 then pc_scan() end
        if #pc_state.parts == 0 then showNotification("Tidak bisa mulai - tidak ada part!", Color3.fromRGB(200,50,50)); return end
        
        pc_state.active = true
        pc_state.timeOffset = 0
        pc_state.connection = RunService.Heartbeat:Connect(function()
            if not pc_state.active then return end
            pc_state.timeOffset = (pc_state.timeOffset + pc_config.batchSize) % #pc_state.parts
            local fn = pc_modes[pc_state.mode]
            if fn then pcall(fn) end
        end)
        if PartControllerGUI then
             local toggleButton = PartControllerGUI:FindFirstChild("toggleButton", true)
             if toggleButton then
                toggleButton.Text = "⏹️"
                toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
             end
        end
    end

    pc_fullRestore = function()
        stopPartController()

        for _, entry in pairs(pc_state.removedItems) do
            if entry.item and entry.parent and entry.parent.Parent then
                pcall(function() entry.item.Parent = entry.parent end)
            end
        end

        for part, properties in pairs(pc_state.originalProperties) do
            if part and part.Parent then
                pcall(function()
                    part.Anchored = properties.Anchored
                    part.CanCollide = properties.CanCollide
                end)
            end
        end

        pc_state.parts = {}
        pc_state.originalProperties = {}
        pc_state.removedItems = {}
        if PartControllerGUI then
            local statusLabel = PartControllerGUI:FindFirstChild("statusLabel", true)
            if statusLabel then statusLabel.Text = "Parts: 0" end
        end
    end

    createPartControllerGUI = function()
        if not hasPermission("VIP") then
            showNotification("Silahkan upgrade ke VIP terlebih dahulu, Terimakasih", Color3.fromRGB(255,100,0))
            return
        end
        if PartControllerGUI and PartControllerGUI.Parent then PartControllerGUI:Destroy() end
        PartControllerGUI = Instance.new("ScreenGui", CoreGui); PartControllerGUI.Name = "ArexansPartControllerGUI"; PartControllerGUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; PartControllerGUI.ResetOnSpawn = false
        
        pc_temporaryStorage = Instance.new("Folder", PartControllerGUI); pc_temporaryStorage.Name = "TemporaryStorage"

        local MainFrame = Instance.new("Frame", PartControllerGUI)
        MainFrame.Name = "MainFrame"
        MainFrame.Size = UDim2.new(0, 180, 0, 95)
        MainFrame.Position = UDim2.new(0.5, -90, 0.5, -47)
        MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        MainFrame.BackgroundTransparency = 0.5
        local MainUICorner = Instance.new("UICorner", MainFrame); MainUICorner.CornerRadius = UDim.new(0, 8)
        local UIStroke = Instance.new("UIStroke", MainFrame); UIStroke.Color = Color3.fromRGB(0, 150, 255); UIStroke.Thickness = 1.5

        local TitleBar = Instance.new("TextButton", MainFrame)
        TitleBar.Name = "TitleBar"; TitleBar.Size = UDim2.new(1, 0, 0, 25)
        TitleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25); TitleBar.Text = ""
        local TitleBarCorner = Instance.new("UICorner", TitleBar); TitleBarCorner.CornerRadius = UDim.new(0, 8)
        TitleBar.AutoButtonColor = false
        MakeDraggable(MainFrame, TitleBar, function() return true end, nil)

        local TitleLabel = Instance.new("TextLabel", TitleBar)
        TitleLabel.Size = UDim2.new(0.4, 0, 1, 0); TitleLabel.Position = UDim2.new(0, 8, 0, 0)
        TitleLabel.BackgroundTransparency = 1; TitleLabel.Text = "P-Controller"
        TitleLabel.TextColor3 = Color3.fromRGB(0, 200, 255); TitleLabel.TextSize = 12
        TitleLabel.Font = Enum.Font.SourceSansBold; TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

        local statusLabel = Instance.new("TextLabel", TitleBar)
        statusLabel.Name = "statusLabel"
        statusLabel.Size = UDim2.new(0.5, 0, 1, 0); statusLabel.Position = UDim2.new(0.3, 0, 0, 0)
        statusLabel.BackgroundTransparency = 1; statusLabel.Text = "Parts: " .. #pc_state.parts
        statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180); statusLabel.TextSize = 10
        statusLabel.Font = Enum.Font.SourceSans; statusLabel.TextXAlignment = Enum.TextXAlignment.Center
        
        local closeBtn = Instance.new("TextButton",TitleBar)
        closeBtn.Size = UDim2.new(0,18,0,18); closeBtn.Position = UDim2.new(1,-22,0.5,-9); closeBtn.BackgroundTransparency = 1; closeBtn.Font = Enum.Font.SourceSansBold; closeBtn.Text = "X"; closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); closeBtn.TextSize = 16

        local minimizeBtn = Instance.new("TextButton", TitleBar)
        minimizeBtn.Size = UDim2.new(0, 18, 0, 18); minimizeBtn.Position = UDim2.new(1, -42, 0.5, -9); minimizeBtn.BackgroundTransparency = 1; minimizeBtn.Font = Enum.Font.SourceSansBold; minimizeBtn.Text = "-"; minimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); minimizeBtn.TextSize = 20

        local ContentFrame = Instance.new("Frame", MainFrame)
        ContentFrame.Name = "ContentFrame"; ContentFrame.ClipsDescendants = true
        ContentFrame.Size = UDim2.new(1, -10, 1, -30)
        ContentFrame.Position = UDim2.new(0, 5, 0, 25)
        ContentFrame.BackgroundTransparency = 1
        local ContentLayout = Instance.new("UIListLayout", ContentFrame); ContentLayout.Padding = UDim.new(0, 4)

        local function createIconButton(parent, text, size, callback)
            local btn = Instance.new("TextButton", parent); btn.Size = UDim2.new(0, size, 0, 24); btn.Text = text
            btn.Font = Enum.Font.SourceSansBold; btn.TextSize = 16; btn.TextColor3 = Color3.new(1, 1, 1)
            local corner = Instance.new("UICorner", btn); corner.CornerRadius = UDim.new(0, 5)
            if callback then btn.MouseButton1Click:Connect(callback) end
            return btn
        end
        
        local function createCompactTextBox(parent, name, defaultValue, callback)
            local frame = Instance.new("Frame", parent); frame.BackgroundTransparency = 1; frame.Size = UDim2.new(0, 48, 0, 24)
            local label = Instance.new("TextLabel", frame); label.Size = UDim2.new(1, 0, 0, 12); label.BackgroundTransparency = 1; label.Font = Enum.Font.SourceSans
            label.Text = name; label.TextColor3 = Color3.fromRGB(200, 200, 200); label.TextSize = 10; label.TextXAlignment = Enum.TextXAlignment.Center
            local textBox = Instance.new("TextBox", frame); textBox.Size = UDim2.new(1, 0, 1, -12); textBox.Position = UDim2.new(0, 0, 0, 12)
            textBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35); textBox.TextColor3 = Color3.fromRGB(220, 220, 220); textBox.Text = tostring(defaultValue); textBox.Font = Enum.Font.SourceSans; textBox.TextSize = 11
            textBox.TextXAlignment = Enum.TextXAlignment.Center; textBox.ClearTextOnFocus = false
            local corner = Instance.new("UICorner", textBox); corner.CornerRadius = UDim.new(0, 4)
            textBox.FocusLost:Connect(function(enterPressed) local num = tonumber(textBox.Text) if num and callback then callback(num) else textBox.Text = tostring(defaultValue) end end)
            return frame, textBox 
        end

        local controlsRow = Instance.new("Frame", ContentFrame)
        controlsRow.BackgroundTransparency = 1; controlsRow.Size = UDim2.new(1, 0, 0, 28)
        local radiusFrame, radiusBox = createCompactTextBox(controlsRow, "Radius", pc_config.radius, function(v) pc_config.radius = v end); radiusFrame.Position = UDim2.new(0, 0, 0.5, -12)
        local speedFrame, speedBox = createCompactTextBox(controlsRow, "Speed", pc_config.speed, function(v) pc_config.speed = v; pc_config.launchSpeed = v * 20 end); speedFrame.Position = UDim2.new(0, 52, 0.5, -12)
        
        local destroyBtn = createIconButton(controlsRow, "🚯", 30, function()
            destroyBtn.Text = "..."
            task.spawn(function()
                local n = pc_clearAndStoreConstraints(); destroyBtn.Text = "🚯"; statusLabel.Text = "Stored "..n; statusLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
                task.wait(2); statusLabel.Text = "Parts: "..#pc_state.parts; statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
            end)
        end)
        destroyBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40); destroyBtn.Position = UDim2.new(0, 104, 0.5, -12) 
        
        local isScanning = false
        local scanButton = createIconButton(controlsRow, "🔍", 30, function()
            if isScanning then return end; isScanning = true; statusLabel.Text = "Scanning..."; statusLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
            task.spawn(function()
                task.wait(); local foundParts = pc_scan(); statusLabel.Text = "Parts: " .. #foundParts; statusLabel.TextColor3 = Color3.fromRGB(120, 255, 120); isScanning = false
            end)
        end)
        scanButton.BackgroundColor3 = Color3.fromRGB(50, 150, 255); scanButton.Position = UDim2.new(0, 138, 0.5, -12)

        local modeRow = Instance.new("Frame", ContentFrame); modeRow.BackgroundTransparency = 1; modeRow.Size = UDim2.new(1, 0, 0, 28)
        local prevBtn = createIconButton(modeRow, "<", 25); prevBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60); prevBtn.Position = UDim2.new(0, 0, 0.5, -12)
        local modeLabel = Instance.new("TextLabel", modeRow); modeLabel.Size = UDim2.new(0, 70, 1, 0); modeLabel.Position = UDim2.new(0, 29, 0, 0)
        modeLabel.BackgroundTransparency = 1; modeLabel.Font = Enum.Font.SourceSansBold; modeLabel.TextSize = 10; modeLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
        modeLabel.TextWrapped = true; modeLabel.TextXAlignment = Enum.TextXAlignment.Center
        local nextBtn = createIconButton(modeRow, ">", 25); nextBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60); nextBtn.Position = UDim2.new(0, 103, 0.5, -12)
        local toggleButton = createIconButton(modeRow, "▶️", 30); toggleButton.Position = UDim2.new(0, 138, 0.5, -12); toggleButton.Name = "toggleButton"
        
        local function updateModeDisplay() local currentModeData = PC_MODES[pc_state.currentModeIndex]; pc_state.mode = currentModeData.v; modeLabel.Text = currentModeData.n end
        prevBtn.MouseButton1Click:Connect(function() pc_state.currentModeIndex = pc_state.currentModeIndex - 1; if pc_state.currentModeIndex < 1 then pc_state.currentModeIndex = #PC_MODES end; updateModeDisplay() end)
        nextBtn.MouseButton1Click:Connect(function() pc_state.currentModeIndex = pc_state.currentModeIndex + 1; if pc_state.currentModeIndex > #PC_MODES then pc_state.currentModeIndex = 1 end; updateModeDisplay() end)
        updateModeDisplay()

        toggleButton.MouseButton1Click:Connect(function() if pc_state.active then stopPartController() else startPartController() end end)
        if pc_state.active then toggleButton.Text = "⏹️"; toggleButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50) else toggleButton.Text = "▶️"; toggleButton.BackgroundColor3 = Color3.fromRGB(0, 200, 100) end
        
        closeBtn.MouseButton1Click:Connect(function() pc_fullRestore(); PartControllerGUI:Destroy() end)
        
        local isMinimized = false; local originalSize = MainFrame.Size; local minimizedSize = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, TitleBar.Size.Y.Offset)
        minimizeBtn.MouseButton1Click:Connect(function()
            isMinimized = not isMinimized; ContentFrame.Visible = not isMinimized; local targetSize = isMinimized and minimizedSize or originalSize
            TweenService:Create(MainFrame, TweenInfo.new(0.2), {Size = targetSize}):Play()
        end)
    end
    -- [[ AKHIR INTEGRASI FUNGSI PARTCONTROLLER.LUA ]]

    local function ToggleAntiLag(enabled)
        IsAntiLagEnabled = enabled
        saveFeatureStates()
        if enabled then
            Lighting.GlobalShadows = false; Lighting.FogEnd = 999999
            if settings then pcall(function() settings().Rendering.QualityLevel = "Level01" end) end
            for _, v in pairs(Workspace:GetDescendants()) do if v:IsA("ParticleEmitter") or v:IsA("Explosion") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then v.Enabled = false end end
            for _, v in pairs(Lighting:GetChildren()) do if v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") then v.Enabled = false end end
            antiLagConnection = Workspace.DescendantAdded:Connect(function(descendant) if descendant:IsA("ParticleEmitter") or descendant:IsA("Explosion") or descendant:IsA("Fire") or descendant:IsA("Smoke") or descendant:IsA("Sparkles") then task.wait(); descendant.Enabled = false end end)
        else
            if antiLagConnection then antiLagConnection:Disconnect(); antiLagConnection = nil end
            Lighting.GlobalShadows = true
            if settings then pcall(function() settings().Rendering.QualityLevel = "Automatic" end) end
            for _, v in pairs(Workspace:GetDescendants()) do if v:IsA("ParticleEmitter") or v:IsA("Explosion") or v:IsA("Fire") or v:IsA("Smoke") or v:IsA("Sparkles") then v.Enabled = true end end
            for _, v in pairs(Lighting:GetChildren()) do if v:IsA("BlurEffect") or v:IsA("SunRaysEffect") or v:IsA("ColorCorrectionEffect") or v:IsA("BloomEffect") or v:IsA("DepthOfFieldEffect") then v.Enabled = true end end
        end
    end

    -- ====================================================================
    -- == BAGIAN FITUR BOOST FPS (INTEGRASI)                           ==
    -- ====================================================================

    local function storeBoostFpsOriginalSettings()
        if next(boostFpsOriginalSettings) then return end -- [[ PERBAIKAN BUG: Jangan simpan ulang jika sudah ada ]]
        boostFpsOriginalSettings = {}
        
        local terrain = workspace:FindFirstChildOfClass('Terrain')
        if terrain then
            boostFpsOriginalSettings.WaterWaveSize = terrain.WaterWaveSize
            boostFpsOriginalSettings.WaterWaveSpeed = terrain.WaterWaveSpeed
            boostFpsOriginalSettings.WaterReflectance = terrain.WaterReflectance
            boostFpsOriginalSettings.WaterTransparency = terrain.WaterTransparency
        end
        
        boostFpsOriginalSettings.GlobalShadows = Lighting.GlobalShadows
        boostFpsOriginalSettings.FogEnd = Lighting.FogEnd
        boostFpsOriginalSettings.FogStart = Lighting.FogStart
        
        if settings and settings() and settings().Rendering then
             boostFpsOriginalSettings.QualityLevel = settings().Rendering.QualityLevel
        end
        
        boostFpsOriginalSettings.PartProperties = {}
        for _, descendant in pairs(game:GetDescendants()) do
            pcall(function()
                if descendant:IsA("BasePart") then
                    boostFpsOriginalSettings.PartProperties[descendant] = {
                        Material = descendant.Material,
                        Reflectance = descendant.Reflectance
                    }
                elseif descendant:IsA("Decal") then
                    boostFpsOriginalSettings.PartProperties[descendant] = {
                        Transparency = descendant.Transparency
                    }
                elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") then
                     boostFpsOriginalSettings.PartProperties[descendant] = {
                        Lifetime = descendant.Lifetime
                    }
                end
            end)
        end
        
        boostFpsOriginalSettings.PostEffects = {}
        for _, effect in pairs(Lighting:GetDescendants()) do
            if effect:IsA("PostEffect") then
                boostFpsOriginalSettings.PostEffects[effect] = effect.Enabled
            end
        end
    end

    local function enableBoostFps()
        
        local terrain = workspace:FindFirstChildOfClass('Terrain')
        if terrain then
            terrain.WaterWaveSize = 0
            terrain.WaterWaveSpeed = 0
            terrain.WaterReflectance = 0
            terrain.WaterTransparency = 1
        end
        
        Lighting.GlobalShadows = false
        Lighting.FogEnd = 9e9
        Lighting.FogStart = 9e9
        
        if settings and settings() and settings().Rendering then
            settings().Rendering.QualityLevel = 1
        end
        
        for _, descendant in pairs(game:GetDescendants()) do
            pcall(function()
                if descendant:IsA("BasePart") then
                    descendant.Material = Enum.Material.Plastic
                    descendant.Reflectance = 0
                elseif descendant:IsA("Decal") then
                    descendant.Transparency = 1
                elseif descendant:IsA("ParticleEmitter") or descendant:IsA("Trail") then
                    descendant.Lifetime = NumberRange.new(0)
                elseif descendant:IsA("PostEffect") then
                    descendant.Enabled = false
                end
            end)
        end

        if boostFpsDescendantConnection then boostFpsDescendantConnection:Disconnect() end
        boostFpsDescendantConnection = workspace.DescendantAdded:Connect(function(child)
            if child:IsA('ForceField') or child:IsA('Sparkles') or child:IsA('Smoke') or child:IsA('Fire') or child:IsA('Beam') then
                task.defer(function() child:Destroy() end)
            end
        end)
    end

    local function disableBoostFps()
        if not next(boostFpsOriginalSettings) then return end
        
        local terrain = workspace:FindFirstChildOfClass('Terrain')
        if terrain and boostFpsOriginalSettings.WaterWaveSize then
            terrain.WaterWaveSize = boostFpsOriginalSettings.WaterWaveSize
            terrain.WaterWaveSpeed = boostFpsOriginalSettings.WaterWaveSpeed
            terrain.WaterReflectance = boostFpsOriginalSettings.WaterReflectance
            terrain.WaterTransparency = boostFpsOriginalSettings.WaterTransparency
        end
        
        Lighting.GlobalShadows = boostFpsOriginalSettings.GlobalShadows
        Lighting.FogEnd = boostFpsOriginalSettings.FogEnd
        Lighting.FogStart = boostFpsOriginalSettings.FogStart
        
        if settings and settings() and settings().Rendering and boostFpsOriginalSettings.QualityLevel then
             settings().Rendering.QualityLevel = boostFpsOriginalSettings.QualityLevel
        end
        
        for effect, wasEnabled in pairs(boostFpsOriginalSettings.PostEffects) do
            if effect and effect.Parent then
                effect.Enabled = wasEnabled
            end
        end
        
        if boostFpsOriginalSettings.PartProperties then
            for instance, properties in pairs(boostFpsOriginalSettings.PartProperties) do
                if instance and instance.Parent then
                    pcall(function()
                        for propName, propValue in pairs(properties) do
                            instance[propName] = propValue
                        end
                    end)
                end
            end
        end
        
        if boostFpsDescendantConnection then
            boostFpsDescendantConnection:Disconnect()
            boostFpsDescendantConnection = nil
        end
        
        -- boostFpsOriginalSettings = {} -- [[ PERBAIKAN BUG: Jangan hapus pengaturan asli ]]
    end

    local function ToggleBoostFPS(enabled)
        IsBoostFPSEnabled = enabled
        saveFeatureStates()
        if enabled then
            enableBoostFps()
        else
            disableBoostFps()
        end
    end
    
    -- ====================================================================
    -- == BAGIAN FITUR VIEW PLAYER (PERBAIKAN)                         ==
    -- ====================================================================
    
    local function createSpectatorGUI()
        if SpectatorGui and SpectatorGui.Parent then return end
    
        SpectatorGui = Instance.new("ScreenGui")
        SpectatorGui.Name = "ArexansSpectatorGUI"
        SpectatorGui.Parent = CoreGui
        SpectatorGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        SpectatorGui.ResetOnSpawn = false
        SpectatorGui.Enabled = false
        SpectatorGui.DisplayOrder = 5 -- [PERBAIKAN] Atur agar di bawah menu utama
    
		-- [PERBAIKAN] Frame untuk tombol aksi (hanya Teleport)
		local ActionButtonsBar = Instance.new("Frame")
		ActionButtonsBar.Name = "ActionButtonsBar"
		ActionButtonsBar.Size = UDim2.new(0, 170, 0, 30)
		ActionButtonsBar.Position = UDim2.new(0.5, -85, 1, -95)
		ActionButtonsBar.BackgroundTransparency = 1
		ActionButtonsBar.Parent = SpectatorGui
	
		local ActionButtonsLayout = Instance.new("UIListLayout")
		ActionButtonsLayout.FillDirection = Enum.FillDirection.Horizontal
		ActionButtonsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		ActionButtonsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		ActionButtonsLayout.SortOrder = Enum.SortOrder.LayoutOrder
		ActionButtonsLayout.Padding = UDim.new(0, 10)
		ActionButtonsLayout.Parent = ActionButtonsBar

		-- Tombol Teleport
		local TeleportButton = Instance.new("TextButton")
		TeleportButton.Name = "TeleportButton"
		TeleportButton.Size = UDim2.new(0, 80, 1, 0)
		TeleportButton.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
		TeleportButton.Font = Enum.Font.SourceSansBold
		TeleportButton.Text = "Teleport"
		TeleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
		TeleportButton.TextSize = 14
		TeleportButton.Parent = ActionButtonsBar
		local TPCorner = Instance.new("UICorner", TeleportButton); TPCorner.CornerRadius = UDim.new(0, 6)
	
		TeleportButton.MouseButton1Click:Connect(function()
			if not IsViewingPlayer or not currentlyViewedPlayer then return end

			local localChar = LocalPlayer.Character
			local targetPlayerToTeleportTo = currentlyViewedPlayer -- Save the player reference

			if not (targetPlayerToTeleportTo.Character and targetPlayerToTeleportTo.Character:FindFirstChild("HumanoidRootPart") and localChar and localChar:FindFirstChild("HumanoidRootPart")) then
				showNotification("Target atau karakter Anda tidak valid.", Color3.fromRGB(200, 50, 50))
				return
			end
			
			-- Stop spectating first (this will return the player to their original spot and clear currentlyViewedPlayer)
			stopSpectate()
			
			-- Now, teleport the player to the saved target's position
			task.wait(0.1) -- Brief wait to ensure camera is fully restored
			local teleportCFrame = targetPlayerToTeleportTo.Character.HumanoidRootPart.CFrame * CFrame.new(0, 3, 0)
			localChar:SetPrimaryPartCFrame(teleportCFrame)
			showNotification("Teleportasi ke " .. targetPlayerToTeleportTo.DisplayName, Color3.fromRGB(50, 150, 255))
		end)

		-- Tombol Rekam/Stop
        local RecordButton = Instance.new("TextButton")
        RecordButton.Name = "RecordButton"
        RecordButton.Size = UDim2.new(0, 80, 1, 0)
        RecordButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        RecordButton.Font = Enum.Font.SourceSansBold
        RecordButton.Text = "Rekam"
        RecordButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        RecordButton.TextSize = 14
        RecordButton.Parent = ActionButtonsBar
        local RecCorner = Instance.new("UICorner", RecordButton); RecCorner.CornerRadius = UDim.new(0, 6)

        RecordButton.MouseButton1Click:Connect(function()
            if not IsViewingPlayer or not currentlyViewedPlayer then return end

            if isRecording and currentRecordingTarget == currentlyViewedPlayer then
                stopRecording(false)
            elseif isRecording and currentRecordingTarget ~= currentlyViewedPlayer then
                showNotification("Harus menghentikan rekaman saat ini terlebih dahulu.", Color3.fromRGB(200, 150, 50))
            else
                switchTab("Rekaman")
                startRecording(currentlyViewedPlayer, false)
            end
        end)

        local MainBar = Instance.new("Frame")
        MainBar.Name = "MainBar"
        MainBar.Size = UDim2.new(0, 300, 0, 40)
        MainBar.Position = UDim2.new(0.5, -150, 1, -50)
        MainBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        MainBar.BackgroundTransparency = 0.3
        MainBar.BorderSizePixel = 0
        MainBar.Parent = SpectatorGui
    
        local UICorner = Instance.new("UICorner", MainBar)
        UICorner.CornerRadius = UDim.new(0, 8)
        local UIStroke = Instance.new("UIStroke", MainBar)
        UIStroke.Color = Color3.fromRGB(0, 150, 255)
        UIStroke.Thickness = 1
        UIStroke.Transparency = 0.5
    
        local NicknameLabel = Instance.new("TextButton")
        NicknameLabel.Name = "NicknameLabel"
        NicknameLabel.Size = UDim2.new(1, -80, 1, 0)
        NicknameLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
        NicknameLabel.AnchorPoint = Vector2.new(0.5, 0.5)
        NicknameLabel.BackgroundTransparency = 1
        NicknameLabel.Font = Enum.Font.SourceSansBold
        NicknameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        NicknameLabel.TextSize = 16
        NicknameLabel.Text = "Mengamati: Player"
        NicknameLabel.AutoButtonColor = false
        NicknameLabel.Parent = MainBar
        NicknameLabel.MouseButton1Click:Connect(function()
            stopSpectate()
        end)
    
        local LeftButton = Instance.new("TextButton")
        LeftButton.Name = "LeftButton"
        LeftButton.Size = UDim2.new(0, 30, 0, 30)
        LeftButton.Position = UDim2.new(0, 5, 0.5, -15)
        LeftButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        LeftButton.Font = Enum.Font.SourceSansBold
        LeftButton.Text = "<"
        LeftButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        LeftButton.TextSize = 20
        LeftButton.Parent = MainBar
        local LBCorner = Instance.new("UICorner", LeftButton); LBCorner.CornerRadius = UDim.new(0, 6)
    
        local RightButton = Instance.new("TextButton")
        RightButton.Name = "RightButton"
        RightButton.Size = UDim2.new(0, 30, 0, 30)
        RightButton.Position = UDim2.new(1, -35, 0.5, -15)
        RightButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        RightButton.Font = Enum.Font.SourceSansBold
        RightButton.Text = ">"
        RightButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        RightButton.TextSize = 20
        RightButton.Parent = MainBar
        local RBCorner = Instance.new("UICorner", RightButton); RBCorner.CornerRadius = UDim.new(0, 6)
    
        LeftButton.MouseButton1Click:Connect(function() cycleSpectate(-1) end)
        RightButton.MouseButton1Click:Connect(function() cycleSpectate(1) end)
    end
    
    local function updateSpectatorGUI()
        if not SpectatorGui or not SpectatorGui.Enabled or not IsViewingPlayer or not currentlyViewedPlayer then return end
    
        local recordButton = SpectatorGui:FindFirstChild("RecordButton", true)
        if not recordButton then return end
    
        if isRecording and currentRecordingTarget == currentlyViewedPlayer then
            recordButton.Text = "Stop"
            recordButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        else
            recordButton.Text = "Rekam"
            recordButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        end
    end
    
    stopSpectate = function()
        if not IsViewingPlayer then return end
        
        IsViewingPlayer = false
        if viewingPlayerConnection then
            viewingPlayerConnection:Disconnect()
            viewingPlayerConnection = nil
        end
        
        local localChar = LocalPlayer.Character
        
        pcall(function()
            if originalCameraSubject and originalCameraSubject.Parent then
                Workspace.CurrentCamera.CameraSubject = originalCameraSubject
            elseif localChar and localChar:FindFirstChildOfClass("Humanoid") then
                Workspace.CurrentCamera.CameraSubject = localChar.Humanoid
            end
        end)
        originalCameraSubject = nil
        
        if localChar and originalPlayerCFrame then
            localChar:SetPrimaryPartCFrame(originalPlayerCFrame)
            
            -- [PERBAIKAN] Reset velocity to prevent flinging after spectate
            for _, part in ipairs(localChar:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Velocity = Vector3.new()
                    part.RotVelocity = Vector3.new()
                end
            end
        end
        originalPlayerCFrame = nil
    
        if SpectatorGui then SpectatorGui.Enabled = false end
        
        currentlyViewedPlayer = nil
        if updatePlayerList then updatePlayerList() end 
    end
    
    startSpectate = function(targetPlayer)
        if IsViewingPlayer and currentlyViewedPlayer == targetPlayer then
            stopSpectate()
            return
        end
    
        if IsViewingPlayer then
            stopSpectate()
            task.wait(0.1) 
        end
    
        local localChar = LocalPlayer.Character
        local targetChar = targetPlayer.Character
    
        if not (localChar and localChar:FindFirstChild("HumanoidRootPart") and targetChar and targetChar:FindFirstChild("HumanoidRootPart")) then
            showNotification((targetPlayer and targetPlayer.Name or "Pemain") .. " tidak bisa diamati.", Color3.fromRGB(200, 150, 50))
            return
        end
    
        IsViewingPlayer = true
        currentlyViewedPlayer = targetPlayer
    
        originalPlayerCFrame = localChar.PrimaryPart.CFrame
        originalCameraSubject = Workspace.CurrentCamera.CameraSubject
        -- localPlayerIsHidden, Parent, and Animate script changes removed to keep player visible and animated.
    
        pcall(function() Workspace.CurrentCamera.CameraSubject = targetChar.Humanoid end)
    
        viewingPlayerConnection = targetPlayer.CharacterAdded:Connect(function(character)
            task.wait(0.1)
            if IsViewingPlayer and currentlyViewedPlayer == targetPlayer and character:FindFirstChildOfClass("Humanoid") then
                pcall(function() Workspace.CurrentCamera.CameraSubject = character.Humanoid end)
            end
        end)
    
        if not SpectatorGui or not SpectatorGui.Parent then createSpectatorGUI() end
        SpectatorGui.Enabled = true
        local NicknameLabel = SpectatorGui:FindFirstChild("MainBar", true):FindFirstChild("NicknameLabel", true)
        if NicknameLabel then
            NicknameLabel.Text = "Mengamati: " .. targetPlayer.DisplayName
        end
        
        if updatePlayerList then updatePlayerList() end
    end

    cycleSpectate = function(direction) 
        if not IsViewingPlayer then return end

        local playerList = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then
                table.insert(playerList, p)
            end
        end

        table.sort(playerList, function(a, b) return a.Name < b.Name end)

        if #playerList == 0 then
            stopSpectate()
            showNotification("Tidak ada pemain lain untuk diamati.", Color3.fromRGB(200, 150, 50))
            return
        end

        local currentIndex = 0
        if currentlyViewedPlayer then
            for i, p in ipairs(playerList) do
                if p == currentlyViewedPlayer then
                    currentIndex = i
                    break
                end
            end
        end
        
        if currentIndex == 0 and #playerList > 0 then
            currentIndex = direction > 0 and 0 or #playerList + 1
        end

        for _ = 1, #playerList do
            local newIndex = currentIndex + direction
            if newIndex > #playerList then
                newIndex = 1
            elseif newIndex < 1 then
                newIndex = #playerList
            end

            local nextPlayer = playerList[newIndex]
            if nextPlayer and nextPlayer.Character and nextPlayer.Character:FindFirstChildOfClass("Humanoid") then
                startSpectate(nextPlayer)
                return 
            else
                currentIndex = newIndex
            end
        end

        stopSpectate()
        showNotification("Tidak ada pemain yang bisa diamati saat ini.", Color3.fromRGB(200, 150, 50))
    end
    
    -- ====================================================================
    -- == AKHIR BAGIAN VIEW PLAYER                                     ==
    -- ====================================================================

    -- [[ PERUBAHAN BESAR DIMULAI: Fungsi Spectate Lokasi dirombak total untuk kontrol mobile ]]
    local stopLocationSpectate -- Deklarasi awal
    
    local function createSpectateLocationGUI()
        if spectateLocationGui and spectateLocationGui.Parent then return end
    
        spectateLocationGui = Instance.new("ScreenGui")
        spectateLocationGui.Name = "ArexansLocationSpectatorGUI"
        spectateLocationGui.Parent = CoreGui
        spectateLocationGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        spectateLocationGui.ResetOnSpawn = false
        spectateLocationGui.DisplayOrder = 6
    
        -- Tombol Stop
        local stopButton = Instance.new("TextButton")
        stopButton.Name = "StopSpectateButton"
        stopButton.Size = UDim2.new(0, 150, 0, 35)
        stopButton.Position = UDim2.new(0.5, -75, 1, -50)
        stopButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        stopButton.BackgroundTransparency = 0.2
        stopButton.Font = Enum.Font.SourceSansBold
        stopButton.Text = "Hentikan Pengamatan"
        stopButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        stopButton.TextSize = 14
        stopButton.ZIndex = 2
        stopButton.Parent = spectateLocationGui
        
        local corner = Instance.new("UICorner", stopButton); corner.CornerRadius = UDim.new(0, 8)
        local stroke = Instance.new("UIStroke", stopButton); stroke.Color = Color3.fromRGB(255, 100, 100); stroke.Thickness = 1
        stopButton.MouseButton1Click:Connect(stopLocationSpectate)
    
        -- GUI Joystick untuk gerakan
        local JoystickFrame = Instance.new("Frame")
        JoystickFrame.Name = "JoystickFrame"
        JoystickFrame.Size = UDim2.new(0, 120, 0, 120)
        JoystickFrame.Position = UDim2.new(0, 30, 1, -150)
        JoystickFrame.BackgroundTransparency = 1
        JoystickFrame.Parent = spectateLocationGui

        local JoystickBase = Instance.new("ImageLabel")
        JoystickBase.Name = "Base"
        JoystickBase.Size = UDim2.new(1, 0, 1, 0)
        JoystickBase.BackgroundTransparency = 1
        JoystickBase.Image = "rbxassetid://392630590" -- Gambar lingkaran default
        JoystickBase.ImageColor3 = Color3.fromRGB(0, 0, 0)
        JoystickBase.ImageTransparency = 0.5
        JoystickBase.ScaleType = Enum.ScaleType.Slice
        JoystickBase.SliceCenter = Rect.new(100, 100, 100, 100)
        JoystickBase.Parent = JoystickFrame
        
        local JoystickThumb = Instance.new("ImageLabel")
        JoystickThumb.Name = "Thumb"
        JoystickThumb.Size = UDim2.new(0.5, 0, 0.5, 0)
        JoystickThumb.Position = UDim2.new(0.25, 0, 0.25, 0)
        JoystickThumb.AnchorPoint = Vector2.new(0, 0)
        JoystickThumb.BackgroundTransparency = 1
        JoystickThumb.Image = "rbxassetid://392630590"
        JoystickThumb.ImageColor3 = Color3.fromRGB(150, 150, 150)
        JoystickThumb.ImageTransparency = 0.3
        JoystickThumb.ScaleType = Enum.ScaleType.Slice
        JoystickThumb.SliceCenter = Rect.new(100, 100, 100, 100)
        JoystickThumb.ZIndex = 2
        JoystickThumb.Parent = JoystickBase

        return JoystickFrame
    end
    
    stopLocationSpectate = function()
        if not isSpectatingLocation then return end
        isSpectatingLocation = false
        
        -- Hentikan semua koneksi input
        for _, conn in pairs(spectateCameraConnections) do conn:Disconnect() end
        spectateCameraConnections = {}
        
        -- Kembalikan properti kamera ke kondisi semula
        local camera = Workspace.CurrentCamera
        pcall(function()
            camera.CameraType = originalCameraProperties.Type
            camera.CameraSubject = originalCameraProperties.Subject
            camera.CFrame = originalCameraProperties.CFrame
            camera.FieldOfView = originalCameraProperties.FieldOfView
        end)
        
        -- Tampilkan kembali karakter pemain di posisi terakhirnya
        local localChar = LocalPlayer.Character
        if localPlayerIsHidden and localChar then
            if localChar.Parent ~= Workspace then
                localChar.Parent = Workspace
            end
            if originalPlayerCFrame then
                localChar:SetPrimaryPartCFrame(originalPlayerCFrame)
            end
        end
        localPlayerIsHidden = false
        originalPlayerCFrame = nil
    
        if spectateLocationGui then spectateLocationGui:Destroy(); spectateLocationGui = nil end
    end
    
    startLocationSpectate = function(targetCFrame)
        if isSpectatingLocation then stopLocationSpectate() end
        
        local localChar = LocalPlayer.Character
        if not localChar or not localChar:FindFirstChild("HumanoidRootPart") then
            showNotification("Karakter Anda tidak ditemukan.", Color3.fromRGB(200, 50, 50))
            return
        end
        
        isSpectatingLocation = true
        
        -- Simpan properti kamera saat ini
        local camera = Workspace.CurrentCamera
        originalCameraProperties = {
            Type = camera.CameraType,
            Subject = camera.CameraSubject,
            CFrame = camera.CFrame,
            FieldOfView = camera.FieldOfView
        }
        
        -- Simpan posisi karakter, pindahkan ke lokasi, lalu sembunyikan
        -- INI ADALAH KUNCI UNTUK MEMBUAT MAP TER-RENDER
        originalPlayerCFrame = localChar.PrimaryPart.CFrame
        localChar:SetPrimaryPartCFrame(targetCFrame)
        localPlayerIsHidden = true
        localChar.Parent = nil
        
        -- Atur kamera ke mode scriptable dan posisikan
        camera.CameraType = Enum.CameraType.Scriptable
        camera.CFrame = targetCFrame * CFrame.new(0, 10, 20)
        camera.FieldOfView = 80
        
        local JoystickFrame = createSpectateLocationGUI()
        local JoystickBase = JoystickFrame.Base
        local JoystickThumb = JoystickBase.Thumb
        
        -- Setup variabel untuk kontrol kamera
        local cameraRotationSensitivity = 0.004
        local cameraMoveSpeed = 50
        local moveVector = Vector2.new(0, 0)
        local isJoystickActive = false
        local rotationInput = nil
    
        -- Koneksi untuk Rotasi (Geser di mana saja selain joystick)
        -- [[ PERUBAHAN: Rotasi Kamera via Layar Dinonaktifkan ]]
        -- Kode di bawah ini dinonaktifkan sesuai permintaan untuk menghilangkan
        -- pergerakan kamera saat layar disentuh/digeser, namun tetap mempertahankan
        -- fungsi pergerakan dari analog/joystick.
                
        -- Inisialisasi kamera fly
        isSpectatingLocation = true
        camera = Workspace.CurrentCamera
        camera.CameraType = Enum.CameraType.Scriptable

        local camPos = targetCFrame.Position
        local camYaw, camPitch = 0, 0

        -- rotasi kamera dengan swipe
        local rotationInput = nil
        local swipeBeganConn = UserInputService.InputBegan:Connect(function(input,gpe)
            if gpe or not isSpectatingLocation then return end
            if input.UserInputType==Enum.UserInputType.Touch then
                local joyPos, joySize = JoystickFrame.AbsolutePosition, JoystickFrame.AbsoluteSize
                local isTouchingJoystick = (input.Position.X >= joyPos.X and input.Position.X <= joyPos.X + joySize.X and
                                            input.Position.Y >= joyPos.Y and input.Position.Y <= joyPos.Y + joySize.Y)
                if not isTouchingJoystick then
                    rotationInput=input
                end
            end
        end)
        local swipeChangedConn = UserInputService.InputChanged:Connect(function(input,gpe)
            if gpe or not isSpectatingLocation or not rotationInput or input~=rotationInput then return end
            local delta = input.Delta
            camYaw = camYaw - delta.X * cameraRotationSensitivity
            camPitch = math.clamp(camPitch - delta.Y * cameraRotationSensitivity,-1.4,1.4)
        end)
        local swipeEndedConn = UserInputService.InputEnded:Connect(function(input,gpe)
            if input==rotationInput then rotationInput=nil end
        end)

        -- Koneksi untuk Joystick
        local joystickInput = nil
        JoystickBase.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                isJoystickActive = true
                joystickInput = input
            end
        end)

        local joystickChangedConn = UserInputService.InputChanged:Connect(function(input)
            if isJoystickActive and joystickInput and input == joystickInput then
                local center = JoystickBase.AbsolutePosition + (JoystickBase.AbsoluteSize / 2)
                local pos = UserInputService:GetMouseLocation()
                
                local dir = (pos - center)
                local distance = math.min(dir.Magnitude, JoystickBase.AbsoluteSize.X / 2.5)
                
                if dir.Magnitude > 0 then
                    moveVector = dir.Unit * (distance / (JoystickBase.AbsoluteSize.X / 2.5))
                else
                    moveVector = Vector2.new(0,0)
                end

                JoystickThumb.Position = UDim2.fromOffset(
                    (JoystickBase.AbsoluteSize.X / 2 - JoystickThumb.AbsoluteSize.X / 2) + moveVector.X * (JoystickBase.AbsoluteSize.X / 2.5),
                    (JoystickBase.AbsoluteSize.Y / 2 - JoystickThumb.AbsoluteSize.Y / 2) + moveVector.Y * (JoystickBase.AbsoluteSize.Y / 2.5)
                )
            end
        end)
        
        local joystickEndedConn = UserInputService.InputEnded:Connect(function(input)
            if joystickInput and input == joystickInput then
                isJoystickActive = false
                joystickInput = nil
                moveVector = Vector2.new(0, 0)
                TweenService:Create(JoystickThumb, TweenInfo.new(0.1), {Position = UDim2.new(0.25, 0, 0.25, 0)}):Play()
            end
        end)

        -- Kontroler Kamera Terpadu (Gaya Terbang)
        local unifiedConn = RunService.RenderStepped:Connect(function(dt)
            if not isSpectatingLocation then
                unifiedConn:Disconnect()
                return
            end

            -- Dapatkan vektor arah 3D penuh dari kamera
            local lookVector = camera.CFrame.LookVector
            local rightVector = camera.CFrame.RightVector

            -- Hitung pergerakan berdasarkan input joystick dan arah kamera
            -- Sumbu Y joystick (-moveVector.Y) mengontrol maju/mundur di sepanjang lookVector
            -- Sumbu X joystick (moveVector.X) mengontrol gerakan ke samping di sepanjang rightVector
            local moveDirection = (lookVector * -moveVector.Y) + (rightVector * moveVector.X)

            -- Perbarui posisi kamera
            camPos = camPos + moveDirection * cameraMoveSpeed * dt

            -- Perbarui rotasi kamera dari input geser (swipe)
            local rotCFrame = CFrame.Angles(0, camYaw, 0) * CFrame.Angles(camPitch, 0, 0)
            camera.CFrame = CFrame.new(camPos) * rotCFrame
        end)

        spectateCameraConnections = {swipeBeganConn, swipeChangedConn, swipeEndedConn, joystickChangedConn, joystickEndedConn, unifiedConn}
    end
    -- [[ PERUBAHAN BESAR SELESAI ]]
    
    local function Rejoin()
        saveFeatureStates()
        saveGuiPositions()
        
        if queue_on_teleport and type(queue_on_teleport) == "function" then
            local loaderCode = "loadstring(game:HttpGet('" .. SCRIPT_URL .. "'))()"
            queue_on_teleport(loaderCode)
            showNotification("Re-eksekusi terjadwal, bergabung kembali...", Color3.fromRGB(50, 150, 255))
        else
            showNotification("Executor tidak mendukung 'queue_on_teleport'. Gunakan auto-exec.", Color3.fromRGB(255, 150, 0))
        end

        task.wait(0.1)
        
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)
    end

    local function HopServer()
        if SCRIPT_URL == "GANTI_DENGAN_URL_RAW_PASTEBIN_ATAU_GIST_ANDA" then
            showNotification("URL Skrip belum diatur! Lihat bagian atas skrip.", Color3.fromRGB(255, 100, 0))
            return
        end

        local servers = {}
        local success, response = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. tostring(game.PlaceId) .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)

        if not success or not response or not response.data then
            showNotification("Gagal mengambil daftar server.", Color3.fromRGB(200, 50, 50))
            warn("Server Hop Error:", response)
            return
        end
        
        for _, server in ipairs(response.data) do
            if type(server) == 'table' and server.id ~= game.JobId and server.playing < server.maxPlayers then
                table.insert(servers, server.id)
            end
        end

        if #servers > 0 then
            local randomServer = servers[math.random(1, #servers)]
            
            saveFeatureStates()
            saveGuiPositions()
            
            if queue_on_teleport and type(queue_on_teleport) == "function" then
                local loaderCode = "loadstring(game:HttpGet('" .. SCRIPT_URL .. "'))()"
                queue_on_teleport(loaderCode)
                showNotification("Re-eksekusi terjadwal, pindah server...", Color3.fromRGB(50, 150, 255))
            else
                showNotification("Executor tidak mendukung 'queue_on_teleport'. Gunakan auto-exec.", Color3.fromRGB(255, 150, 0))
            end

            task.wait(0.1) 
            
            pcall(function()
                TeleportService:TeleportToPlaceInstance(game.PlaceId, randomServer, LocalPlayer)
            end)
        else
            showNotification("Tidak ada server lain yang ditemukan.", Color3.fromRGB(200, 150, 50))
        end
    end
    
    local function DisableAllFeatures()
        if IsViewingPlayer then stopSpectate() end
		if isSpectatingLocation then stopLocationSpectate() end

        if isRecording or isPlaying then stopActions() end
        if IsFlying then if UserInputService.TouchEnabled then StopMobileFly() else StopFly() end end; if IsWalkSpeedEnabled then ToggleWalkSpeed(false) end; if IsNoclipEnabled then ToggleNoclip(false) end; if IsGodModeEnabled then ToggleGodMode(false) end; if IsInfinityJumpEnabled then IsInfinityJumpEnabled = false; if infinityJumpConnection then infinityJumpConnection:Disconnect(); infinityJumpConnection = nil end end; if antifling_enabled then ToggleAntiFling(false) end; if IsAntiLagEnabled then ToggleAntiLag(false) end
        if IsBoostFPSEnabled then ToggleBoostFPS(false) end
        if IsFEInvisibleEnabled then ToggleFEInvisible(false) end
        if isEmoteEnabled then destroyEmoteGUI(); EmoteToggleButton.Visible = false end
        if isAnimationEnabled then destroyAnimationGUI(); AnimationShowButton.Visible = false end 
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then LocalPlayer.Character.Humanoid.WalkSpeed = OriginalWalkSpeed end
        if currentFlingTarget then ToggleFlingOnPlayer(currentFlingTarget) end
        if isCopyingMovement then stopCopyMovement() end
        
        -- [[ PERUBAHAN DIMULAI: Matikan ESP baru saat skrip ditutup ]]
        if IsEspNameEnabled then ToggleESPName(false) end
        if IsEspBodyEnabled then ToggleESPBody(false) end
        if IsShiftLockEnabled then ToggleShiftLock(false) end
        -- [[ PERUBAHAN SELESAI ]]
    end

    local function CloseScript()
        -- Pertama, putuskan setiap koneksi yang telah dibuat oleh skrip.
        for _, conn in ipairs(AllConnections) do
            pcall(function() conn:Disconnect() end)
        end
        AllConnections = {} -- Kosongkan tabel untuk mencegah eksekusi ganda

        -- Nonaktifkan fitur apa pun yang memerlukan logika khusus (seperti reset kecepatan jalan)
        pcall(DisableAllFeatures)

        -- Terakhir, hancurkan semua GUI dengan aman
        pcall(function() if ScreenGui and ScreenGui.Parent then ScreenGui:Destroy() end end)
        pcall(function() if touchFlingGui and touchFlingGui.Parent then touchFlingGui:Destroy() end end)
        pcall(function() if SpectatorGui and SpectatorGui.Parent then SpectatorGui:Destroy() end end)
        pcall(function() if spectateLocationGui and spectateLocationGui.Parent then spectateLocationGui:Destroy() end end)
        pcall(function() if flingStatusGui and flingStatusGui.Parent then flingStatusGui:Destroy() end end)
        pcall(function() if EmoteScreenGui and EmoteScreenGui.Parent then EmoteScreenGui:Destroy() end end)
        pcall(function() if AnimationScreenGui and AnimationScreenGui.Parent then AnimationScreenGui:Destroy() end end)
    end
    
    local function HandleLogout()
        deleteSession()
        CloseScript()
    end

    -- ====================================================================
    -- == BAGIAN PEMBUATAN ELEMEN UI (SLIDER, TOGGLE, DLL)             ==
    -- ====================================================================
    
    local function createSlider(parent, name, min, max, current, suffix, increment, callback)
        local sliderFrame = Instance.new("Frame", parent); sliderFrame.Size = UDim2.new(1, 0, 0, 50); sliderFrame.BackgroundTransparency = 1; local titleLabel = Instance.new("TextLabel", sliderFrame); titleLabel.Size = UDim2.new(1, 0, 0, 15); titleLabel.BackgroundTransparency = 1; titleLabel.TextColor3 = Color3.fromRGB(200, 200, 200); titleLabel.TextSize = 12; titleLabel.TextXAlignment = Enum.TextXAlignment.Left; titleLabel.Text = name .. ": " .. tostring(math.floor(current * 10) / 10) .. " " .. suffix; titleLabel.Font = Enum.Font.SourceSans
        local sliderBase = Instance.new("Frame", sliderFrame); sliderBase.Name = "SliderBase"; sliderBase.Size = UDim2.new(1, 0, 0, 10); sliderBase.Position = UDim2.new(0, 0, 0, 25); sliderBase.BackgroundColor3 = Color3.fromRGB(35, 35, 35); sliderBase.BorderSizePixel = 0; local sbCorner = Instance.new("UICorner", sliderBase); sbCorner.CornerRadius = UDim.new(0, 5)
        local sliderFill = Instance.new("Frame", sliderBase); sliderFill.Name = "SliderFill"; local fillWidth = (current - min) / (max - min); sliderFill.Size = UDim2.new(fillWidth, 0, 1, 0); sliderFill.BackgroundColor3 = Color3.fromRGB(0, 150, 255); sliderFill.BorderSizePixel = 0; local sfCorner = Instance.new("UICorner", sliderFill); sfCorner.CornerRadius = UDim.new(0, 5)
        local sliderThumb = Instance.new("Frame", sliderBase); sliderThumb.Name = "SliderThumb"; sliderThumb.Size = UDim2.new(0, 15, 0, 25); sliderThumb.Position = UDim2.new(fillWidth, -7.5, 0.5, -12.5); sliderThumb.BackgroundColor3 = Color3.fromRGB(0, 200, 255); sliderThumb.BorderSizePixel = 0; local stCorner = Instance.new("UICorner", sliderThumb); stCorner.CornerRadius = UDim.new(0, 5); local stStroke = Instance.new("UIStroke", sliderThumb); stStroke.Color = Color3.fromRGB(255, 255, 255); stStroke.Thickness = 1; stStroke.Transparency = 0.8
        local isDraggingSlider = false; local function updateSlider(input) local pos = input.Position.X - sliderBase.AbsolutePosition.X; local newWidth = math.min(math.max(pos, 0), sliderBase.AbsoluteSize.X); local newValue = min + (newWidth / sliderBase.AbsoluteSize.X) * (max - min); newValue = math.floor(newValue / increment) * increment; local newFillWidth = (newValue - min) / (max - min); sliderFill.Size = UDim2.new(newFillWidth, 0, 1, 0); sliderThumb.Position = UDim2.new(newFillWidth, -7.5, 0.5, -12.5); titleLabel.Text = name .. ": " .. tostring(math.floor(newValue * 10) / 10) .. " " .. suffix; callback(newValue) end
        sliderBase.InputBegan:Connect(function(input, processed) if processed then return end; if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then isDraggingSlider = true; updateSlider(input) end end)
        sliderBase.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then isDraggingSlider = false; saveFeatureStates() end end)
        UserInputService.InputChanged:Connect(function(input) if isDraggingSlider then updateSlider(input) end end)
        return sliderFrame
    end
    
    local function createToggle(parent, name, initialState, callback)
        local toggleFrame = Instance.new("Frame", parent); toggleFrame.Size = UDim2.new(1, 0, 0, 25); toggleFrame.BackgroundTransparency = 1; local toggleLabel = Instance.new("TextLabel", toggleFrame); toggleLabel.Size = UDim2.new(0.8, -10, 1, 0); toggleLabel.Position = UDim2.new(0, 5, 0, 0); toggleLabel.BackgroundTransparency = 1; toggleLabel.Text = name; toggleLabel.TextColor3 = Color3.fromRGB(255, 255, 255); toggleLabel.TextSize = 12; toggleLabel.TextXAlignment = Enum.TextXAlignment.Left; toggleLabel.Font = Enum.Font.SourceSans
        local switch = Instance.new("TextButton", toggleFrame); switch.Name = "Switch"; switch.Size = UDim2.new(0, 40, 0, 20); switch.Position = UDim2.new(1, -50, 0.5, -10); switch.BackgroundColor3 = Color3.fromRGB(50, 50, 50); switch.BorderSizePixel = 0; switch.Text = ""; local switchCorner = Instance.new("UICorner", switch); switchCorner.CornerRadius = UDim.new(1, 0)
        local thumb = Instance.new("Frame", switch); thumb.Name = "Thumb"; thumb.Size = UDim2.new(0, 16, 0, 16); thumb.Position = UDim2.new(0, 2, 0.5, -8); thumb.BackgroundColor3 = Color3.fromRGB(220, 220, 220); thumb.BorderSizePixel = 0; local thumbCorner = Instance.new("UICorner", thumb); thumbCorner.CornerRadius = UDim.new(1, 0)
        local onColor, offColor = Color3.fromRGB(0, 150, 255), Color3.fromRGB(60, 60, 60); local onPosition, offPosition = UDim2.new(1, -18, 0.5, -8), UDim2.new(0, 2, 0.5, -8); local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out); local isToggled = initialState
        local function updateVisuals(isInstant) local goalPosition, goalColor = isToggled and onPosition or offPosition, isToggled and onColor or offColor; if isInstant then thumb.Position, switch.BackgroundColor3 = goalPosition, goalColor else TweenService:Create(thumb, tweenInfo, {Position = goalPosition}):Play(); TweenService:Create(switch, tweenInfo, {BackgroundColor3 = goalColor}):Play() end end
        switch.MouseButton1Click:Connect(function() isToggled = not isToggled; updateVisuals(false); callback(isToggled) end); updateVisuals(true)
        return toggleFrame, switch
    end
    
    local function createDropdown(parent, name, options, current, callback)
        local dropdownFrame = Instance.new("Frame", parent); dropdownFrame.Size = UDim2.new(1, 0, 0, 50); dropdownFrame.BackgroundTransparency = 1; local label = Instance.new("TextLabel", dropdownFrame); label.Size = UDim2.new(1, 0, 0, 20); label.BackgroundTransparency = 1; label.TextXAlignment = Enum.TextXAlignment.Left; label.Text = name .. ": " .. current; label.TextColor3 = Color3.fromRGB(255, 255, 255); label.TextSize = 12; label.Font = Enum.Font.SourceSans
        local optionButton = Instance.new("TextButton", dropdownFrame); optionButton.Size = UDim2.new(1, 0, 0, 25); optionButton.Position = UDim2.new(0, 0, 0, 25); optionButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255); optionButton.BorderSizePixel = 0; optionButton.Text = "Ubah Target"; optionButton.TextColor3 = Color3.fromRGB(255, 255, 255); optionButton.TextSize = 12; optionButton.Font = Enum.Font.SourceSans; local btnCorner = Instance.new("UICorner", optionButton); btnCorner.CornerRadius = UDim.new(0, 5)
        local currentIndex = 1; for i,v in pairs(options) do if v == current then currentIndex = i break end end
        optionButton.MouseButton1Click:Connect(function() currentIndex = currentIndex % #options + 1; local newOption = options[currentIndex]; label.Text = name .. ": " .. newOption; callback(newOption) end); return dropdownFrame
    end
    
    -- ====================================================================
    -- == BAGIAN PENGATURAN KONTEN TAB                                  ==
    -- ====================================================================
    
    local function setupPlayerTab()
        local playerHeaderFrame = Instance.new("Frame", PlayerTabContent); playerHeaderFrame.Size = UDim2.new(1, 0, 0, 55); playerHeaderFrame.BackgroundTransparency = 1
        local playerCountLabel = Instance.new("TextLabel", playerHeaderFrame); playerCountLabel.Name = "PlayerCountLabel"; playerCountLabel.Size = UDim2.new(1, -20, 0, 15); playerCountLabel.BackgroundTransparency = 1; playerCountLabel.Text = "Pemain Online: " .. #Players:GetPlayers(); playerCountLabel.TextColor3 = Color3.fromRGB(255, 255, 255); playerCountLabel.TextSize = 12; playerCountLabel.TextXAlignment = Enum.TextXAlignment.Left; playerCountLabel.Font = Enum.Font.SourceSansBold
        
        local refreshButton = Instance.new("TextButton", playerHeaderFrame)
        refreshButton.Name = "RefreshButton"
        refreshButton.Size = UDim2.new(0, 15, 0, 15); refreshButton.Position = UDim2.new(1, -15, 0, 0); refreshButton.BackgroundTransparency = 1
        refreshButton.Text = "🔄"; refreshButton.TextColor3 = Color3.fromRGB(0, 200, 255); refreshButton.TextSize = 14; refreshButton.Font = Enum.Font.SourceSansBold
        
        local isAnimatingRefresh = false
        refreshButton.MouseButton1Click:Connect(function() 
            if isAnimatingRefresh then return end; isAnimatingRefresh = true
            local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Linear); local tween = TweenService:Create(refreshButton, tweenInfo, { Rotation = refreshButton.Rotation + 360 }); tween:Play()
            if updatePlayerList then updatePlayerList() end 
            tween.Completed:Connect(function() isAnimatingRefresh = false end)
        end)
    
        local searchFrame = Instance.new("Frame", playerHeaderFrame); searchFrame.Size = UDim2.new(1, 0, 0, 25); searchFrame.Position = UDim2.new(0, 0, 0, 20); searchFrame.BackgroundTransparency = 1
        local searchTextBox = Instance.new("TextBox", searchFrame); searchTextBox.Text = ""; searchTextBox.Size = UDim2.new(0.7, -10, 1, 0); searchTextBox.Position = UDim2.new(0, 5, 0, 0); searchTextBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35); searchTextBox.TextColor3 = Color3.fromRGB(200, 200, 200); searchTextBox.PlaceholderText = "Cari Pemain..."; searchTextBox.TextSize = 12; searchTextBox.Font = Enum.Font.SourceSans; searchTextBox.ClearTextOnFocus = true; local sboxCorner = Instance.new("UICorner", searchTextBox); sboxCorner.CornerRadius = UDim.new(0, 5)
        local searchButton = Instance.new("TextButton", searchFrame); searchButton.Size = UDim2.new(0.3, 0, 1, 0); searchButton.Position = UDim2.new(0.7, 0, 0, 0); searchButton.BackgroundColor3 = Color3.fromRGB(0, 150,  255); searchButton.BorderSizePixel = 0; searchButton.Text = "Cari"; searchButton.TextColor3 = Color3.fromRGB(255, 255, 255); searchButton.TextSize = 12; searchButton.Font = Enum.Font.SourceSansBold; local sbtnCorner = Instance.new("UICorner", searchButton); sbtnCorner.CornerRadius = UDim.new(0, 5)
        
        local function createPlayerButton(player)
            local playerFrame = Instance.new("Frame", PlayerListContainer); playerFrame.Size = UDim2.new(1, 0, 0, 35); playerFrame.BackgroundTransparency = 1; playerFrame.Name = player.Name
            
            local avatarImage = Instance.new("ImageButton", playerFrame)
            avatarImage.Name = "AvatarImageButton"
            avatarImage.Size = UDim2.new(0, 25, 0, 25)
            avatarImage.Position = UDim2.new(0, 5, 0.5, -12.5)
            avatarImage.BackgroundTransparency = 1
            avatarImage.AutoButtonColor = false
            pcall(function() avatarImage.Image = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420) end)
            
            local avatarCorner = Instance.new("UICorner", avatarImage)
            avatarCorner.CornerRadius = UDim.new(1, 0)
            local avatarStroke = Instance.new("UIStroke", avatarImage)
            avatarStroke.Name = "SpectateStroke"
            avatarStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            avatarStroke.Color = Color3.fromRGB(40, 200, 40)
            avatarStroke.Thickness = 1.5
            avatarStroke.Transparency = 1 
            
            avatarImage.MouseButton1Click:Connect(function()
                startSpectate(player)
            end)
            
            local displaynameLabel = Instance.new("TextLabel", playerFrame); displaynameLabel.Size = UDim2.new(1, -100, 0, 15); displaynameLabel.Position = UDim2.new(0, 35, 0, 2); displaynameLabel.BackgroundTransparency = 1; displaynameLabel.TextXAlignment = Enum.TextXAlignment.Left; displaynameLabel.Text = player.DisplayName; displaynameLabel.TextColor3 = Color3.fromRGB(255, 255, 255); displaynameLabel.TextSize = 10; displaynameLabel.Font = Enum.Font.SourceSansSemibold
            local usernameLabel = Instance.new("TextLabel", playerFrame); usernameLabel.Size = UDim2.new(1, -100, 0, 12); usernameLabel.Position = UDim2.new(0, 35, 0, 18); usernameLabel.BackgroundTransparency = 1; usernameLabel.TextXAlignment = Enum.TextXAlignment.Left; usernameLabel.Text = "@" .. player.Name; usernameLabel.TextColor3 = Color3.fromRGB(150, 150, 150); usernameLabel.TextSize = 8; usernameLabel.Font = Enum.Font.SourceSans
            local distanceLabel = Instance.new("TextLabel", playerFrame); distanceLabel.Name = "DistanceLabel"; distanceLabel.Size = UDim2.new(1, -100, 0, 12); distanceLabel.Position = UDim2.new(0, 35, 0, 30); distanceLabel.BackgroundTransparency = 1; distanceLabel.TextXAlignment = Enum.TextXAlignment.Left; distanceLabel.TextColor3 = Color3.fromRGB(0, 255, 127); distanceLabel.TextSize = 9; distanceLabel.Font = Enum.Font.SourceSansSemibold
            
            local actionsFrame = Instance.new("Frame", playerFrame)
            actionsFrame.Name = "ActionsFrame"
            actionsFrame.Size = UDim2.new(0, 60, 0, 16)
            actionsFrame.Position = UDim2.new(1, -65, 0.5, -8)
            actionsFrame.BackgroundTransparency = 1

            local actionsLayout = Instance.new("UIListLayout", actionsFrame)
            actionsLayout.FillDirection = Enum.FillDirection.Horizontal
            actionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
            actionsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
            actionsLayout.Padding = UDim.new(0, 2)
            
            local flingButton = Instance.new("TextButton", actionsFrame)
            flingButton.Name = "FlingButton"
            flingButton.Size = UDim2.new(0, 16, 0, 16)
            flingButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            flingButton.BorderSizePixel = 0
            flingButton.Font = Enum.Font.SourceSansBold
            flingButton.Text = "☠️"
            flingButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            flingButton.TextSize = 10
            local flingCorner = Instance.new("UICorner", flingButton); flingCorner.CornerRadius = UDim.new(0, 4)
            flingButton.MouseButton1Click:Connect(function()
                ToggleFlingOnPlayer(player)
            end)
    
            local newTeleportButton = Instance.new("TextButton", actionsFrame)
            newTeleportButton.Name = "TeleportButton"
            newTeleportButton.Size = UDim2.new(0, 16, 0, 16)
            newTeleportButton.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
            newTeleportButton.BorderSizePixel = 0
            newTeleportButton.Font = Enum.Font.SourceSansBold
            newTeleportButton.Text = "🌀"
            newTeleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            newTeleportButton.TextSize = 10
            local tpCorner = Instance.new("UICorner", newTeleportButton); tpCorner.CornerRadius = UDim.new(0, 4)
            
            newTeleportButton.MouseButton1Click:Connect(function()
                local localChar = LocalPlayer.Character
                local targetChar = player.Character
    
                if not (targetChar and targetChar:FindFirstChild("HumanoidRootPart") and localChar and localChar:FindFirstChild("HumanoidRootPart")) then
                    showNotification("Target atau karakter Anda tidak ditemukan.", Color3.fromRGB(200, 50, 50))
                    return
                end
    
                local targetPosition = targetChar.HumanoidRootPart.Position
                local teleportCFrame = CFrame.new(targetPosition + Vector3.new(0, 3, 0))
    
                if IsViewingPlayer then
                    originalPlayerCFrame = teleportCFrame
                    if localPlayerIsHidden and localChar.Parent == nil then
                        localChar:SetPrimaryPartCFrame(teleportCFrame)
                    end
                    showNotification("Posisi kembali Anda diatur ke " .. player.DisplayName, Color3.fromRGB(50, 150, 255))
                else
                    localChar.HumanoidRootPart.CFrame = teleportCFrame
                end
            end)

            local copyMovementButton = Instance.new("TextButton", actionsFrame)
            copyMovementButton.Name = "CopyMovementButton"
            copyMovementButton.Size = UDim2.new(0, 16, 0, 16)
            copyMovementButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80) -- Default color
            copyMovementButton.BorderSizePixel = 0
            copyMovementButton.Font = Enum.Font.SourceSansBold
            copyMovementButton.Text = "👯"
            copyMovementButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            copyMovementButton.TextSize = 12
            local copyCorner = Instance.new("UICorner", copyMovementButton); copyCorner.CornerRadius = UDim.new(0, 5)
            copyMovementButton.MouseButton1Click:Connect(function()
                toggleCopyMovement(player)
            end)
            
            return playerFrame
        end
    
        searchTextBox.FocusLost:Connect(function() CurrentPlayerFilter = searchTextBox.Text; updatePlayerList() end)
        searchButton.MouseButton1Click:Connect(function() CurrentPlayerFilter = searchTextBox.Text; updatePlayerList() end)
    
        local function setupPlayer(player)
            if player == LocalPlayer then return end
            
            local button = createPlayerButton(player)
            PlayerButtons[player.UserId] = button
            updatePlayerList()
        end
    
        ConnectEvent(RunService.RenderStepped, function()
            if MainFrame.Visible and PlayerTabContent.Visible then
                for player, button in pairs(PlayerButtons) do
                    updateSinglePlayerButton(Players:GetPlayerByUserId(player))
                end
            end
        end)
        
        ConnectEvent(Players.PlayerRemoving, function(player)
            if PlayerButtons[player.UserId] then
                PlayerButtons[player.UserId]:Destroy()
                PlayerButtons[player.UserId] = nil
            end
            if espCache[player.UserId] then
                if espCache[player.UserId].billboard then espCache[player.UserId].billboard:Destroy() end
                if espCache[player.UserId].highlight and espCache[player.UserId].highlight.Parent then
                     espCache[player.UserId].highlight:Destroy()
                end
                espCache[player.UserId] = nil
            end
            if IsViewingPlayer and currentlyViewedPlayer == player then
                cycleSpectate(1) 
            end
            if currentFlingTarget == player then
                ToggleFlingOnPlayer(player) 
            end
            task.wait(0.1)
            updatePlayerList()
        end)
    
        ConnectEvent(Players.PlayerAdded, setupPlayer)
    
        for _, player in ipairs(Players:GetPlayers()) do
            setupPlayer(player)
        end

        ConnectEvent(RunService.RenderStepped, function()
            if SpectatorGui and SpectatorGui.Enabled then
                updateSpectatorGUI()
            end
        end)
    end

    local function setupGeneralTab()
        createToggle(GeneralTabContent, "ESP Nama", IsEspNameEnabled, ToggleESPName)
        createToggle(GeneralTabContent, "ESP Tubuh", IsEspBodyEnabled, ToggleESPBody)
        createSlider(GeneralTabContent, "Kecepatan Jalan", 0, Settings.MaxWalkSpeed, Settings.WalkSpeed, "", 1, function(v) Settings.WalkSpeed = v; if IsWalkSpeedEnabled and LocalPlayer.Character and LocalPlayer.Character.Humanoid then LocalPlayer.Character.Humanoid.WalkSpeed = v end end)
        createToggle(GeneralTabContent, "Jalan Cepat", IsWalkSpeedEnabled, function(v) IsWalkSpeedEnabled = v; ToggleWalkSpeed(v) end)
        
        -- [[ INTEGRASI KUNCI KECEPATAN UI ]] --
        createSlider(GeneralTabContent, "Kecepatan Terkunci", 0, 200, speedLock_currentSpeed, "", 1, function(v) 
            speedLock_currentSpeed = v
            if speedLock_isEnforced and speedLock_canEnforce() then
                speedLock_setWalkSpeed(speedLock_humanoid, speedLock_currentSpeed)
            end
        end)
        createToggle(GeneralTabContent, "Kunci Kecepatan", speedLock_isEnforced, function(state)
            speedLock_isEnforced = state
            local h = speedLock_humanoid
            if not h or not h.Parent then return end
            
            if state then
                if not next(speedLock_connections) then -- Re-bind if connections were lost
                    speedLock_bindHumanoid(h)
                end
                if not table.find(speedLock_connections, "heartbeat") then
                    speedLock_lastTick = 0
                    local conn = RunService.Heartbeat:Connect(speedLock_heartbeat)
                    table.insert(speedLock_connections, conn)
                end
                if speedLock_canEnforce() then speedLock_setWalkSpeed(h, speedLock_currentSpeed) end
                showNotification("Kunci Kecepatan diaktifkan", Color3.fromRGB(50, 200, 50))
            else
                speedLock_disconnectAll()
                speedLock_applyDisabledState()
                -- Re-bind essential listeners after disconnecting all
                task.wait(0.1)
                speedLock_bindHumanoid(h)
                showNotification("Kunci Kecepatan dinonaktifkan", Color3.fromRGB(200, 150, 50))
            end
        end)
        
        createSlider(GeneralTabContent, "Kecepatan Terbang", 0, Settings.MaxFlySpeed, Settings.FlySpeed, "", 0.1, function(v) Settings.FlySpeed = v end)
        createToggle(GeneralTabContent, "Terbang", IsFlying, function(v) if v then if UserInputService.TouchEnabled then StartMobileFly() else StartFly() end else if UserInputService.TouchEnabled then StopMobileFly() else StopFly() end end end)
        createToggle(GeneralTabContent, "Noclip", IsNoclipEnabled, function(v) ToggleNoclip(v) end)
        createToggle(GeneralTabContent, "Infinity Jump", IsInfinityJumpEnabled, function(v) IsInfinityJumpEnabled = v; saveFeatureStates(); if v then if LocalPlayer.Character and LocalPlayer.Character.Humanoid then infinityJumpConnection = ConnectEvent(UserInputService.JumpRequest, function() LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end) end elseif infinityJumpConnection then infinityJumpConnection:Disconnect(); infinityJumpConnection = nil end end)
        createToggle(GeneralTabContent, "Mode Kebal", IsGodModeEnabled, ToggleGodMode)
        createToggle(GeneralTabContent, "FE Invisible", IsFEInvisibleEnabled, ToggleFEInvisible)
        createSlider(GeneralTabContent, "Transparansi Invisible", 0, 100, Settings.FEInvisibleTransparency * 100, "%", 1, function(v)
            Settings.FEInvisibleTransparency = v / 100
            if IsFEInvisibleEnabled and LocalPlayer.Character then
                setCharacterTransparency(LocalPlayer.Character, Settings.FEInvisibleTransparency)
            end
            saveFeatureStates() -- Simpan perubahan transparansi
        end)
        createButton(GeneralTabContent, "Buka Touch Fling", CreateTouchFlingGUI)
        createToggle(GeneralTabContent, "Anti-Fling", antifling_enabled, ToggleAntiFling)
        createButton(GeneralTabContent, "Buka GUI Magnet", createMagnetGUI)
        createButton(GeneralTabContent, "Buka GUI Part Controller", createPartControllerGUI)
    end

    local function setupVipTab()
        createToggle(VipTabContent, "Emote VIP", isEmoteEnabled, function(v)
            if not hasPermission("VIP") then
                showNotification("Silahkan upgrade ke VIP terlebih dahulu, Terimakasih", Color3.fromRGB(255,100,0))
                setupVipTab() -- Redraw to reset toggle
                return
            end
            isEmoteEnabled = v
            EmoteToggleButton.Visible = v
            if not v then
                destroyEmoteGUI()
            end
            saveFeatureStates()
        end).LayoutOrder = 1
        createToggle(VipTabContent, "Animasi VIP", isAnimationEnabled, function(v) 
            if not hasPermission("VIP") then
                showNotification("Silahkan upgrade ke VIP terlebih dahulu, Terimakasih", Color3.fromRGB(255,100,0))
                setupVipTab() -- Redraw to reset toggle
                return
            end
            isAnimationEnabled = v; 
            if isAnimationEnabled then 
                initializeAnimationGUI() 
                AnimationShowButton.Visible = true
            else 
                destroyAnimationGUI() 
                AnimationShowButton.Visible = false
            end 
            saveFeatureStates()
        end).LayoutOrder = 2
        createToggle(VipTabContent, "Emote Transparan", isEmoteTransparent, function(v)
            isEmoteTransparent = v
            applyEmoteTransparency(v)
            saveFeatureStates()
        end).LayoutOrder = 3
        createToggle(VipTabContent, "Animasi transparan", isAnimationTransparent, function(v)
            isAnimationTransparent = v
            if isAnimationEnabled and applyAnimationTransparency then applyAnimationTransparency(v) end
            saveFeatureStates()
        end).LayoutOrder = 4
    end

    setupSettingsTab = function()
        createToggle(SettingsTabContent, "Kunci Bar Tombol", not isMiniToggleDraggable, function(v) isMiniToggleDraggable = not v end).LayoutOrder = 1
        createSlider(SettingsTabContent, "Ukuran Tombol Navigasi", 10, 50, 30, "px", 1, function(v)
            if MiniToggleButton then
                MiniToggleButton.Size = UDim2.new(0, v, 0, v)
                MiniToggleButton.TextSize = math.floor(v * 0.6)
            end
        end).LayoutOrder = 2
        createButton(SettingsTabContent, "Simpan Posisi UI", saveGuiPositions).LayoutOrder = 3
        createButton(SettingsTabContent, "Hop Server", function() HopServer() end).LayoutOrder = 4
        createToggle(SettingsTabContent, "Anti-Lag", IsAntiLagEnabled, ToggleAntiLag).LayoutOrder = 5
        createToggle(SettingsTabContent, "Boost FPS", IsBoostFPSEnabled, ToggleBoostFPS).LayoutOrder = 6
        createToggle(SettingsTabContent, "Shift Lock", IsShiftLockEnabled, ToggleShiftLock).LayoutOrder = 9
        createToggle(SettingsTabContent, "Anti AFK", IsAntiAFKEnabled, ToggleAntiAFK).LayoutOrder = 10
        createButton(SettingsTabContent, "Rejoin", Rejoin).LayoutOrder = 10
        createButton(SettingsTabContent, "Tutup", CloseScript).LayoutOrder = 11
    
        local logoutButton = createButton(SettingsTabContent, "Logout", HandleLogout)
        logoutButton.LayoutOrder = 11
        logoutButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    end

    setupPlayerTab = function()
        local playerHeaderFrame = Instance.new("Frame", PlayerTabContent); playerHeaderFrame.Size = UDim2.new(1, 0, 0, 55); playerHeaderFrame.BackgroundTransparency = 1
        local playerCountLabel = Instance.new("TextLabel", playerHeaderFrame); playerCountLabel.Name = "PlayerCountLabel"; playerCountLabel.Size = UDim2.new(1, -20, 0, 15); playerCountLabel.BackgroundTransparency = 1; playerCountLabel.Text = "Pemain Online: " .. #Players:GetPlayers(); playerCountLabel.TextColor3 = Color3.fromRGB(255, 255, 255); playerCountLabel.TextSize = 12; playerCountLabel.TextXAlignment = Enum.TextXAlignment.Left; playerCountLabel.Font = Enum.Font.SourceSansBold
        
        local refreshButton = Instance.new("TextButton", playerHeaderFrame)
        refreshButton.Name = "RefreshButton"
        refreshButton.Size = UDim2.new(0, 15, 0, 15); refreshButton.Position = UDim2.new(1, -15, 0, 0); refreshButton.BackgroundTransparency = 1
        refreshButton.Text = "🔄"; refreshButton.TextColor3 = Color3.fromRGB(0, 200, 255); refreshButton.TextSize = 14; refreshButton.Font = Enum.Font.SourceSansBold
        
        local isAnimatingRefresh = false
        refreshButton.MouseButton1Click:Connect(function() 
            if isAnimatingRefresh then return end; isAnimatingRefresh = true
            local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Linear); local tween = TweenService:Create(refreshButton, tweenInfo, { Rotation = refreshButton.Rotation + 360 }); tween:Play()
            if updatePlayerList then updatePlayerList() end 
            tween.Completed:Connect(function() isAnimatingRefresh = false end)
        end)
    
        local searchFrame = Instance.new("Frame", playerHeaderFrame); searchFrame.Size = UDim2.new(1, 0, 0, 25); searchFrame.Position = UDim2.new(0, 0, 0, 20); searchFrame.BackgroundTransparency = 1
        local searchTextBox = Instance.new("TextBox", searchFrame); searchTextBox.Text = ""; searchTextBox.Size = UDim2.new(0.7, -10, 1, 0); searchTextBox.Position = UDim2.new(0, 5, 0, 0); searchTextBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35); searchTextBox.TextColor3 = Color3.fromRGB(200, 200, 200); searchTextBox.PlaceholderText = "Cari Pemain..."; searchTextBox.TextSize = 12; searchTextBox.Font = Enum.Font.SourceSans; searchTextBox.ClearTextOnFocus = true; local sboxCorner = Instance.new("UICorner", searchTextBox); sboxCorner.CornerRadius = UDim.new(0, 5)
        local searchButton = Instance.new("TextButton", searchFrame); searchButton.Size = UDim2.new(0.3, 0, 1, 0); searchButton.Position = UDim2.new(0.7, 0, 0, 0); searchButton.BackgroundColor3 = Color3.fromRGB(0, 150,  255); searchButton.BorderSizePixel = 0; searchButton.Text = "Cari"; searchButton.TextColor3 = Color3.fromRGB(255, 255, 255); searchButton.TextSize = 12; searchButton.Font = Enum.Font.SourceSansBold; local sbtnCorner = Instance.new("UICorner", searchButton); sbtnCorner.CornerRadius = UDim.new(0, 5)
        
        local function createPlayerButton(player)
            local playerFrame = Instance.new("Frame", PlayerListContainer); playerFrame.Size = UDim2.new(1, 0, 0, 35); playerFrame.BackgroundTransparency = 1; playerFrame.Name = player.Name
            
            local avatarImage = Instance.new("ImageButton", playerFrame)
            avatarImage.Name = "AvatarImageButton"
            avatarImage.Size = UDim2.new(0, 25, 0, 25)
            avatarImage.Position = UDim2.new(0, 5, 0.5, -12.5)
            avatarImage.BackgroundTransparency = 1
            avatarImage.AutoButtonColor = false
            pcall(function() avatarImage.Image = Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420) end)
            
            local avatarCorner = Instance.new("UICorner", avatarImage)
            avatarCorner.CornerRadius = UDim.new(1, 0)
            local avatarStroke = Instance.new("UIStroke", avatarImage)
            avatarStroke.Name = "SpectateStroke"
            avatarStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            avatarStroke.Color = Color3.fromRGB(40, 200, 40)
            avatarStroke.Thickness = 1.5
            avatarStroke.Transparency = 1 
            
            avatarImage.MouseButton1Click:Connect(function()
                startSpectate(player)
            end)
            
            local displaynameLabel = Instance.new("TextLabel", playerFrame); displaynameLabel.Size = UDim2.new(1, -100, 0, 15); displaynameLabel.Position = UDim2.new(0, 35, 0, 2); displaynameLabel.BackgroundTransparency = 1; displaynameLabel.TextXAlignment = Enum.TextXAlignment.Left; displaynameLabel.Text = player.DisplayName; displaynameLabel.TextColor3 = Color3.fromRGB(255, 255, 255); displaynameLabel.TextSize = 10; displaynameLabel.Font = Enum.Font.SourceSansSemibold
            local usernameLabel = Instance.new("TextLabel", playerFrame); usernameLabel.Size = UDim2.new(1, -100, 0, 12); usernameLabel.Position = UDim2.new(0, 35, 0, 18); usernameLabel.BackgroundTransparency = 1; usernameLabel.TextXAlignment = Enum.TextXAlignment.Left; usernameLabel.Text = "@" .. player.Name; usernameLabel.TextColor3 = Color3.fromRGB(150, 150, 150); usernameLabel.TextSize = 8; usernameLabel.Font = Enum.Font.SourceSans
            local distanceLabel = Instance.new("TextLabel", playerFrame); distanceLabel.Name = "DistanceLabel"; distanceLabel.Size = UDim2.new(1, -100, 0, 12); distanceLabel.Position = UDim2.new(0, 35, 0, 30); distanceLabel.BackgroundTransparency = 1; distanceLabel.TextXAlignment = Enum.TextXAlignment.Left; distanceLabel.TextColor3 = Color3.fromRGB(0, 255, 127); distanceLabel.TextSize = 9; distanceLabel.Font = Enum.Font.SourceSansSemibold
            
            local actionsFrame = Instance.new("Frame", playerFrame)
            actionsFrame.Name = "ActionsFrame"
            actionsFrame.Size = UDim2.new(0, 60, 0, 16)
            actionsFrame.Position = UDim2.new(1, -65, 0.5, -8)
            actionsFrame.BackgroundTransparency = 1

            local actionsLayout = Instance.new("UIListLayout", actionsFrame)
            actionsLayout.FillDirection = Enum.FillDirection.Horizontal
            actionsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
            actionsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
            actionsLayout.Padding = UDim.new(0, 2)
            
            local flingButton = Instance.new("TextButton", actionsFrame)
            flingButton.Name = "FlingButton"
            flingButton.Size = UDim2.new(0, 16, 0, 16)
            flingButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            flingButton.BorderSizePixel = 0
            flingButton.Font = Enum.Font.SourceSansBold
            flingButton.Text = "☠️"
            flingButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            flingButton.TextSize = 10
            local flingCorner = Instance.new("UICorner", flingButton); flingCorner.CornerRadius = UDim.new(0, 4)
            flingButton.MouseButton1Click:Connect(function()
                ToggleFlingOnPlayer(player)
            end)
    
            local newTeleportButton = Instance.new("TextButton", actionsFrame)
            newTeleportButton.Name = "TeleportButton"
            newTeleportButton.Size = UDim2.new(0, 16, 0, 16)
            newTeleportButton.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
            newTeleportButton.BorderSizePixel = 0
            newTeleportButton.Font = Enum.Font.SourceSansBold
            newTeleportButton.Text = "🌀"
            newTeleportButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            newTeleportButton.TextSize = 10
            local tpCorner = Instance.new("UICorner", newTeleportButton); tpCorner.CornerRadius = UDim.new(0, 4)
            
            newTeleportButton.MouseButton1Click:Connect(function()
                local localChar = LocalPlayer.Character
                local targetChar = player.Character
    
                if not (targetChar and targetChar:FindFirstChild("HumanoidRootPart") and localChar and localChar:FindFirstChild("HumanoidRootPart")) then
                    showNotification("Target atau karakter Anda tidak ditemukan.", Color3.fromRGB(200, 50, 50))
                    return
                end
    
                local targetPosition = targetChar.HumanoidRootPart.Position
                local teleportCFrame = CFrame.new(targetPosition + Vector3.new(0, 3, 0))
    
                if IsViewingPlayer then
                    originalPlayerCFrame = teleportCFrame
                    if localPlayerIsHidden and localChar.Parent == nil then
                        localChar:SetPrimaryPartCFrame(teleportCFrame)
                    end
                    showNotification("Posisi kembali Anda diatur ke " .. player.DisplayName, Color3.fromRGB(50, 150, 255))
                else
                    localChar.HumanoidRootPart.CFrame = teleportCFrame
                end
            end)

            local copyMovementButton = Instance.new("TextButton", actionsFrame)
            copyMovementButton.Name = "CopyMovementButton"
            copyMovementButton.Size = UDim2.new(0, 16, 0, 16)
            copyMovementButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80) -- Default color
            copyMovementButton.BorderSizePixel = 0
            copyMovementButton.Font = Enum.Font.SourceSansBold
            copyMovementButton.Text = "👯"
            copyMovementButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            copyMovementButton.TextSize = 12
            local copyCorner = Instance.new("UICorner", copyMovementButton); copyCorner.CornerRadius = UDim.new(0, 5)
            copyMovementButton.MouseButton1Click:Connect(function()
                toggleCopyMovement(player)
            end)
            
            return playerFrame
        end
    
        searchTextBox.FocusLost:Connect(function() CurrentPlayerFilter = searchTextBox.Text; updatePlayerList() end)
        searchButton.MouseButton1Click:Connect(function() CurrentPlayerFilter = searchTextBox.Text; updatePlayerList() end)
    
        local function setupPlayer(player)
            if player == LocalPlayer then return end
            
            local button = createPlayerButton(player)
            PlayerButtons[player.UserId] = button
            updatePlayerList()
        end
    
        ConnectEvent(RunService.RenderStepped, function()
            if MainFrame.Visible and PlayerTabContent.Visible then
                for player, button in pairs(PlayerButtons) do
                    updateSinglePlayerButton(Players:GetPlayerByUserId(player))
                end
            end
        end)
        
        ConnectEvent(Players.PlayerRemoving, function(player)
            if PlayerButtons[player.UserId] then
                PlayerButtons[player.UserId]:Destroy()
                PlayerButtons[player.UserId] = nil
            end
            if espCache[player.UserId] then
                if espCache[player.UserId].billboard then espCache[player.UserId].billboard:Destroy() end
                if espCache[player.UserId].highlight and espCache[player.UserId].highlight.Parent then
                     espCache[player.UserId].highlight:Destroy()
                end
                espCache[player.UserId] = nil
            end
            if IsViewingPlayer and currentlyViewedPlayer == player then
                cycleSpectate(1) 
            end
            if currentFlingTarget == player then
                ToggleFlingOnPlayer(player) 
            end
            task.wait(0.1)
            updatePlayerList()
        end)
    
        ConnectEvent(Players.PlayerAdded, setupPlayer)
    
        for _, player in ipairs(Players:GetPlayers()) do
            setupPlayer(player)
        end

        ConnectEvent(RunService.RenderStepped, function()
            if SpectatorGui and SpectatorGui.Enabled then
                updateSpectatorGUI()
            end
        end)
    end
    
    
    setupTeleportTab = function()
        createButton(TeleportTabContent, "Pindai Ulang Map", function() for _, part in pairs(Workspace:GetDescendants()) do if part:IsA("BasePart") then local nameLower = part.Name:lower(); if (nameLower:find("checkpoint") or nameLower:find("pos") or nameLower:find("finish") or nameLower:find("start")) and not Players:GetPlayerFromCharacter(part.Parent) then addTeleportLocation(part.Name, part.CFrame) end end end end).LayoutOrder = 1
        createButton(TeleportTabContent, "Simpan Lokasi Saat Ini", function() if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then local newName = "Kustom " .. (#savedTeleportLocations + 1); addTeleportLocation(newName, LocalPlayer.Character.HumanoidRootPart.CFrame) end end).LayoutOrder = 2
        
        local importExportFrame = Instance.new("Frame", TeleportTabContent)
        importExportFrame.Size = UDim2.new(1, 0, 0, 25)
        importExportFrame.BackgroundTransparency = 1
        importExportFrame.LayoutOrder = 3
        local ieLayout = Instance.new("UIListLayout", importExportFrame)
        ieLayout.FillDirection = Enum.FillDirection.Horizontal
        ieLayout.Padding = UDim.new(0, 5)
        
        local exportButton = createButton(importExportFrame, "Ekspor", function() 
            if not setclipboard then showNotification("Executor tidak mendukung clipboard!", Color3.fromRGB(200, 50, 50)); return end
            local dataToExport = {}; for _, loc in ipairs(savedTeleportLocations) do table.insert(dataToExport, { Name = loc.Name, CFrameData = {loc.CFrame:GetComponents()} }) end
            local success, result = pcall(function() local jsonData = HttpService:JSONEncode(dataToExport); setclipboard(jsonData); showNotification("Data disalin ke clipboard!", Color3.fromRGB(50, 200, 50)) end)
            if not success then showNotification("Gagal mengekspor data!", Color3.fromRGB(200, 50, 50)) end 
        end)
        exportButton.Size = UDim2.new(0.5, -2.5, 1, 0)
        
        local importButton = createButton(importExportFrame, "Impor", function() 
            showImportPrompt(function(text) 
                if not text or text == "" then return end
                local success, decodedData = pcall(HttpService.JSONDecode, HttpService, text)
                if not success or type(decodedData) ~= "table" then showNotification("Data impor tidak valid!", Color3.fromRGB(200, 50, 50)); return end
                local existingNames = {}; for _, loc in ipairs(savedTeleportLocations) do existingNames[loc.Name] = true end
                local importedCount = 0
                for _, data in ipairs(decodedData) do 
                    if type(data) == "table" and data.Name and data.CFrameData and not existingNames[data.Name] then 
                        local cframe = CFrame.new(unpack(data.CFrameData))
                        table.insert(savedTeleportLocations, { Name = data.Name, CFrame = cframe })
                        existingNames[data.Name] = true
                        importedCount = importedCount + 1 
                    end 
                end
                if importedCount > 0 then 
                    table.sort(savedTeleportLocations, naturalCompare)
                    saveTeleportData()
                    updateTeleportList()
                    showNotification(importedCount .. " lokasi berhasil diimpor!", Color3.fromRGB(50, 200, 50)) 
                else 
                    showNotification("Tidak ada lokasi baru untuk diimpor.", Color3.fromRGB(200, 150, 50)) 
                end 
            end) 
        end)
        importButton.Size = UDim2.new(0.5, -2.5, 1, 0)
        
        createToggle(TeleportTabContent, "Tampilkan Ikon", areTeleportIconsVisible, function(v)
            areTeleportIconsVisible = v
            updateTeleportIconVisibility()
        end).LayoutOrder = 4

        -- FITUR BARU: AUTO LOOPING TELEPORT DENGAN UI KOMPAK
        local autoLoopSettingsFrame = Instance.new("Frame", TeleportTabContent)
        autoLoopSettingsFrame.Name, autoLoopSettingsFrame.Size, autoLoopSettingsFrame.BackgroundTransparency, autoLoopSettingsFrame.Visible, autoLoopSettingsFrame.LayoutOrder = "AutoLoopSettingsFrame", UDim2.new(1, 0, 0, 30), 1, false, 6
        local settingsLayout = Instance.new("UIListLayout", autoLoopSettingsFrame); settingsLayout.FillDirection, settingsLayout.VerticalAlignment, settingsLayout.Padding = Enum.FillDirection.Horizontal, Enum.VerticalAlignment.Center, UDim.new(0, 5)

        local function createCompactInput(parent, label, default)
            local frame = Instance.new("Frame", parent); frame.Size, frame.BackgroundTransparency = UDim2.new(0.4, -12, 1, 0), 1
            local layout = Instance.new("UIListLayout", frame); layout.FillDirection, layout.VerticalAlignment = Enum.FillDirection.Horizontal, Enum.VerticalAlignment.Center
            local textLabel = Instance.new("TextLabel", frame); textLabel.Size = UDim2.new(0, 15, 1, 0); textLabel.Text, textLabel.TextColor3, textLabel.TextSize, textLabel.Font, textLabel.BackgroundTransparency = label, Color3.fromRGB(200,200,200), 11, Enum.Font.SourceSans, 1
            local textBox = Instance.new("TextBox", frame); textBox.Size = UDim2.new(1, -15, 0, 20); textBox.Text, textBox.BackgroundColor3 = default, Color3.fromRGB(50, 50, 50); textBox.TextColor3, textBox.TextSize, textBox.Font = Color3.fromRGB(255,255,255), 12, Enum.Font.SourceSans; Instance.new("UICorner", textBox).CornerRadius = UDim.new(0, 4)
            return textBox
        end

        local repeatInput = createCompactInput(autoLoopSettingsFrame, "U:", "5")
        local delayInput = createCompactInput(autoLoopSettingsFrame, "D:", "2")
        local playStopButton = createButton(autoLoopSettingsFrame, "▶️", function() end)
        playStopButton.Size, playStopButton.BackgroundColor3 = UDim2.new(0.2, 0, 0, 22), Color3.fromRGB(50, 180, 50)

        createToggle(TeleportTabContent, "Auto Loop", false, function(isVisible) autoLoopSettingsFrame.Visible = isVisible end).LayoutOrder = 5

        playStopButton.MouseButton1Click:Connect(function()
            if not hasPermission("Normal") then
                showNotification("Tingkatkan ke Normal/VIP untuk menggunakan fitur ini.", Color3.fromRGB(255,100,0))
                return
            end
            if isAutoLooping then -- Tombol Stop ditekan
                isAutoLooping = false
                playStopButton.Text, playStopButton.BackgroundColor3 = "▶️", Color3.fromRGB(50, 180, 50)
            else -- Tombol Play ditekan
                local repetitions, delayTime = tonumber(repeatInput.Text), tonumber(delayInput.Text)
                if not repetitions or repetitions <= 0 or not delayTime or delayTime < 0 then showNotification("Input jumlah & delay tidak valid.", Color3.fromRGB(200, 50, 50)); return end
                if #savedTeleportLocations == 0 then showNotification("Tidak ada lokasi teleport.", Color3.fromRGB(200, 50, 50)); return end
                
                isAutoLooping = true
                playStopButton.Text, playStopButton.BackgroundColor3 = "⏹️", Color3.fromRGB(200, 50, 50)
                
                task.spawn(function()
                    for i = 1, repetitions do
                        if not isAutoLooping then break end
                        for _, locData in ipairs(savedTeleportLocations) do
                            if not isAutoLooping then break end
                            if LocalPlayer.Character and LocalPlayer.Character.HumanoidRootPart then LocalPlayer.Character.HumanoidRootPart.CFrame = locData.CFrame * CFrame.new(0, 3, 0) else isAutoLooping = false; break end
                            task.wait(delayTime)
                        end
                    end
                    isAutoLooping = false; playStopButton.Text, playStopButton.BackgroundColor3 = "▶️", Color3.fromRGB(50, 180, 50)
                end)
            end
        end)
    end
    
    setupVipTab = function()
        createToggle(VipTabContent, "Emote VIP", isEmoteEnabled, function(v)
            isEmoteEnabled = v
            EmoteToggleButton.Visible = v
            if not v then
                destroyEmoteGUI()
            end
            saveFeatureStates()
        end).LayoutOrder = 1
        createToggle(VipTabContent, "Animasi VIP", isAnimationEnabled, function(v) 
            isAnimationEnabled = v; 
            if isAnimationEnabled then 
                initializeAnimationGUI() 
                AnimationShowButton.Visible = true
            else 
                destroyAnimationGUI() 
                AnimationShowButton.Visible = false
            end 
            saveFeatureStates()
        end).LayoutOrder = 2
        createToggle(VipTabContent, "Emote Transparan", isEmoteTransparent, function(v)
            isEmoteTransparent = v
            applyEmoteTransparency(v)
            saveFeatureStates()
        end).LayoutOrder = 3
        createToggle(VipTabContent, "Animasi transparan", isAnimationTransparent, function(v)
            isAnimationTransparent = v
            if isAnimationEnabled and applyAnimationTransparency then applyAnimationTransparency(v) end
            saveFeatureStates()
        end).LayoutOrder = 4
    end
    
    setupRekamanTab = function()
        -- [[ PERBAIKAN: Tata letak dirombak untuk memperbaiki masalah scrolling ]]
        -- 1. Buat kontainer untuk semua kontrol statis (tombol, input, dll.)
        local controlsContainer = Instance.new("Frame")
        controlsContainer.Name = "ControlsContainer"
        controlsContainer.Size = UDim2.new(1, 0, 0, 155) -- Ukuran tetap untuk semua kontrol
        controlsContainer.Position = UDim2.new(0, 0, 0, 0)
        controlsContainer.BackgroundTransparency = 1
        controlsContainer.Parent = RekamanTabContent

        local controlsLayout = Instance.new("UIListLayout", controlsContainer)
        controlsLayout.Padding = UDim.new(0, 5)
        controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
        controlsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

        -- 2. Buat ScrollingFrame HANYA untuk daftar rekaman
        local recordingsListFrame = Instance.new("ScrollingFrame")
        recordingsListFrame.Name = "RecordingsListFrame"
        -- Posisikan di bawah controlsContainer dan isi sisa ruang
        recordingsListFrame.Position = UDim2.new(0, 0, 0, controlsContainer.Size.Y.Offset + 5)
        recordingsListFrame.Size = UDim2.new(1, 0, 1, -(controlsContainer.Size.Y.Offset + 10))
        recordingsListFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        recordingsListFrame.BackgroundTransparency = 0.5
        recordingsListFrame.BorderSizePixel = 0
        recordingsListFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
        recordingsListFrame.ScrollBarThickness = 6
        recordingsListFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255)
        recordingsListFrame.ScrollingDirection = Enum.ScrollingDirection.Y -- Batasi scrolling ke vertikal
        recordingsListFrame.Parent = RekamanTabContent

        local recListLayout = Instance.new("UIListLayout", recordingsListFrame)
        recListLayout.Padding = UDim.new(0, 5)
        recListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        recListLayout.SortOrder = Enum.SortOrder.Name
        local recListPadding = Instance.new("UIPadding", recordingsListFrame)
        recListPadding.PaddingTop = UDim.new(0, 5)
        recListPadding.PaddingBottom = UDim.new(0, 5)
        recListPadding.PaddingLeft = UDim.new(0,5)
        recListPadding.PaddingRight = UDim.new(0,5)
        recListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            -- Pastikan canvas size tidak pernah lebih kecil dari ukuran frame itu sendiri
            local newY = math.max(recordingsListFrame.AbsoluteSize.Y, recListLayout.AbsoluteContentSize.Y + 10)
            recordingsListFrame.CanvasSize = UDim2.new(0, 0, 0, newY)
        end)
        -- Hapus UIListLayout lama dari RekamanTabContent karena sekarang ada di dalam kontainer
        if RekamanTabContent:FindFirstChild("RekamanListLayout") then
            RekamanTabContent.RekamanListLayout:Destroy()
        end
        
        -- [[ Variabel dan fungsi inti ]]
        local recStatusLabel, recordButton, playButton
        local playSequence, playSingleRecording
        local selectedRecordings = {}
        local playbackConnection = nil
        local isPaused = false
        local pausedAtTime = 0 -- Waktu saat jeda
        local isAnimationBypassEnabled = false
        local originalPlaybackWalkSpeed = 16
        local playbackMovers = {}

        updateRecordingsList = function()
            if not recordingsListFrame then return end
            local scrollPos = recordingsListFrame.CanvasPosition
            for _, child in ipairs(recordingsListFrame:GetChildren()) do
                if child:IsA("Frame") then child:Destroy() end
            end
        
            local sortedNames = {}
            for name in pairs(savedRecordings) do table.insert(sortedNames, name) end
            table.sort(sortedNames)
        
            for _, recName in ipairs(sortedNames) do
                local isSelected = selectedRecordings[recName] or false

                local itemFrame = Instance.new("Frame")
                itemFrame.Name = recName; itemFrame.Size = UDim2.new(1, 0, 0, 22); itemFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35); itemFrame.BackgroundTransparency = isSelected and 0 or 0.3; itemFrame.BorderSizePixel = 0; itemFrame.Parent = recordingsListFrame
                local itemCorner = Instance.new("UICorner", itemFrame); itemCorner.CornerRadius = UDim.new(0, 4)
                local itemLayout = Instance.new("UIListLayout", itemFrame); itemLayout.FillDirection = Enum.FillDirection.Horizontal; itemLayout.VerticalAlignment = Enum.VerticalAlignment.Center; itemLayout.Padding = UDim.new(0, 5)
                local itemPadding = Instance.new("UIPadding", itemFrame); itemPadding.PaddingLeft = UDim.new(0, 5)

                local nameButton = Instance.new("TextButton"); nameButton.Size = UDim2.new(1, -30, 1, 0); nameButton.BackgroundTransparency = 1; nameButton.Font = isSelected and Enum.Font.SourceSansBold or Enum.Font.SourceSans; nameButton.Text = recName; nameButton.TextColor3 = isSelected and Color3.fromRGB(0, 200, 255) or Color3.fromRGB(220, 220, 220); nameButton.TextSize = 12; nameButton.TextXAlignment = Enum.TextXAlignment.Left; nameButton.Parent = itemFrame
                
                local renameButton = Instance.new("TextButton"); renameButton.Size = UDim2.new(0, 20, 0, 18); renameButton.BackgroundColor3 = Color3.fromRGB(50, 150, 200); renameButton.Font = Enum.Font.SourceSansBold; renameButton.Text = "✏️"; renameButton.TextColor3 = Color3.fromRGB(255, 255, 255); renameButton.TextSize = 12; renameButton.Parent = itemFrame
                local renameCorner = Instance.new("UICorner", renameButton); renameCorner.CornerRadius = UDim.new(0, 4)

                local function toggleSelection()
                    selectedRecordings[recName] = not selectedRecordings[recName]
                    updateRecordingsList()
                end

                nameButton.MouseButton1Click:Connect(toggleSelection)

                renameButton.MouseButton1Click:Connect(function()
                    showGenericRenamePrompt(recName, function(newName)
                        if newName and newName ~= "" and not savedRecordings[newName] then
                            savedRecordings[newName] = savedRecordings[recName]; savedRecordings[recName] = nil
                            if selectedRecordings[recName] then
                                selectedRecordings[recName] = nil
                                selectedRecordings[newName] = true
                            end
                            saveRecordingsData()
                            recStatusLabel.Text = "Nama diubah menjadi " .. newName; updateRecordingsList()
                        else
                            recStatusLabel.Text = "Nama tidak valid atau sudah ada."
                        end
                    end)
                end)
            end
            recordingsListFrame.CanvasPosition = scrollPos
        end
    
    
        local stopPlayback -- Deklarasi awal


        local cleanupSinglePlayback -- Deklarasi awal
        
        cleanupSinglePlayback = function(isSequence)
            isSequence = isSequence or false

            -- Disable movers before destroying to release control smoothly
            if playbackMovers.alignPos then pcall(function() playbackMovers.alignPos.Enabled = false end) end
            if playbackMovers.alignOrient then pcall(function() playbackMovers.alignOrient.Enabled = false end) end
            task.wait(0.05) -- Wait a couple frames for physics to settle

            -- Destroy all playback-related instances
            for _, mover in pairs(playbackMovers) do
                if mover and mover.Parent then pcall(function() mover:Destroy() end) end
            end
            playbackMovers = {}

            local char = LocalPlayer.Character
            if not char then return end

            local hrp = char:FindFirstChild("HumanoidRootPart")
            local humanoid = char:FindFirstChildOfClass("Humanoid")

            -- Clean up sound
            if hrp then
                local customSound = hrp:FindFirstChild("CustomRunningSound")
                if customSound then pcall(function() customSound:Destroy() end) end
            end

            if humanoid then
                humanoid.WalkSpeed = originalPlaybackWalkSpeed
                humanoid.PlatformStand = false
                humanoid.AutoRotate = true

                if not isSequence then
                    for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
                        pcall(function() track:Stop(0.1) end)
                    end
                end
            end

            -- Force physics state reset and return network ownership
            if hrp then
                pcall(function()
                    hrp.Velocity = Vector3.new(0, 0, 0)
                    hrp.RotVelocity = Vector3.new(0, 0, 0)
                    hrp.Anchored = false
                    hrp:SetNetworkOwner(nil) -- Return control explicitly
                end)
            end
            
            -- Force the humanoid into a controllable state
            if humanoid and humanoid:GetState() ~= Enum.HumanoidStateType.Dead then
                pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) end)
                task.wait()
                pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Running) end)
            end
        end

        stopPlayback = function(isSequence) -- [[ PERBAIKAN: Terima argumen isSequence ]]
            if not isPlaying and not isPaused then return end
            isPlaying = false
            isPaused = false -- Ensure pause state is also reset
            if playbackConnection then
                playbackConnection:Disconnect()
                playbackConnection = nil
            end
            
            cleanupSinglePlayback(isSequence) -- [[ PERBAIKAN: Teruskan argumen isSequence ]]

            playButton.Text = "▶️"
            playButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)

            if not isRecording then
                recStatusLabel.Text = "Pemutaran ulang dihentikan."
            end
        end

        stopActions = function()
            -- Force stop recording
            isRecording = false
            if recordingConnection then
                recordingConnection:Disconnect()
                recordingConnection = nil
            end
            local indicatorGui = CoreGui:FindFirstChild("RecordingIndicatorGUI")
            if indicatorGui then
                indicatorGui:Destroy()
            end
            if recordButton then
                recordButton.Text = "🔴"
                recordButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
            end
            
            -- Force stop playback
            isPlaying = false
            isPaused = false
            if playbackConnection then
                playbackConnection:Disconnect()
                playbackConnection = nil
            end
            cleanupSinglePlayback(false)
            if playButton then
                playButton.Text = "▶️"
                playButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
            end

            if recStatusLabel then
                recStatusLabel.Text = "Semua aksi dihentikan."
            end
        end


        playSequence = function(replayCountBox)
            if isPlaying then return end

            local sortedNames = {}
            for name in pairs(savedRecordings) do table.insert(sortedNames, name) end
            table.sort(sortedNames)

            local sequenceToPlay = {}
            for _, recName in ipairs(sortedNames) do
                if selectedRecordings[recName] then
                    table.insert(sequenceToPlay, {name=recName, data=savedRecordings[recName]})
                end
            end

            if #sequenceToPlay == 0 then
                recStatusLabel.Text = "Pilih rekaman untuk diputar."
                return
            end

            local countText = replayCountBox.Text
            local replayCount = tonumber(countText)
            if countText == "" or countText == "0" then replayCount = math.huge elseif not replayCount or replayCount < 1 then replayCount = 1 end
            
            isPlaying = true
            isPaused = false
            playButton.Text = "⏸️"
            playButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
            
            local currentPlayRun = 1
            local currentSequenceIndex = 1

            local function playNextInSequence()
                if not isPlaying then stopPlayback(); return end

                while isPaused do
                    if not isPlaying then stopPlayback(); return end
                    task.wait(0.1)
                end
                
                if currentSequenceIndex > #sequenceToPlay then
                    currentPlayRun = currentPlayRun + 1
                    if currentPlayRun > replayCount then
                        stopPlayback()
                        recStatusLabel.Text = "Pemutaran sekuens selesai."
                        return
                    end
                    
                    -- Reset state for smooth looping by performing a full cleanup
                    cleanupSinglePlayback(false) 
                    task.wait(0.2) -- Short delay to ensure full reset

                    currentSequenceIndex = 1
                    recStatusLabel.Text = string.format("Memutar sekuens: %d/%s", currentPlayRun, tostring(replayCount) == "inf" and "∞" or tostring(replayCount))
                end

                local item = sequenceToPlay[currentSequenceIndex]
                recStatusLabel.Text = string.format("Memutar: %s (%d/%d)", item.name, currentSequenceIndex, #sequenceToPlay)
                
                playSingleRecording(item.data, function()
                    currentSequenceIndex = currentSequenceIndex + 1
                    task.wait(0.1) -- Small delay between recordings
                    playNextInSequence()
                end)
            end
            
            recStatusLabel.Text = string.format("Memutar sekuens: %d/%s", currentPlayRun, tostring(replayCount) == "inf" and "∞" or tostring(replayCount))
            playNextInSequence()
        end
        
        local controlButtonsFrame = Instance.new("Frame", controlsContainer) -- [[ PERBAIKAN: Parent diubah ]]
        controlButtonsFrame.Name = "ControlButtonsFrame"
        controlButtonsFrame.Size = UDim2.new(1, 0, 0, 35)
        controlButtonsFrame.BackgroundTransparency = 1
        controlButtonsFrame.LayoutOrder = 1
        local controlLayout = Instance.new("UIListLayout", controlButtonsFrame)
        controlLayout.FillDirection = Enum.FillDirection.Horizontal
        controlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        controlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        controlLayout.Padding = UDim.new(0, 5)
        
        local function createIconButton(parent, iconText, color, size)
            local btn = Instance.new("TextButton", parent)
            btn.Size = UDim2.new(0, size, 0, size)
            btn.BackgroundColor3 = color
            btn.Font = Enum.Font.SourceSansBold
            btn.Text = iconText
            btn.TextColor3 = Color3.fromRGB(255, 255, 255)
            btn.TextSize = 12 -- Diperkecil
            local corner = Instance.new("UICorner", btn)
            corner.CornerRadius = UDim.new(0, 5)
            local stroke = Instance.new("UIStroke", btn)
            stroke.Color = Color3.fromRGB(255,255,255)
            stroke.Transparency = 0.8
            stroke.Thickness = 1
            return btn
        end
    
        -- Tombol bawah (Impor, Rekam, Ekspor)
        local importButton = createIconButton(controlButtonsFrame, "📥", Color3.fromRGB(50, 150, 200), 22)
        recordButton = createIconButton(controlButtonsFrame, "🔴", Color3.fromRGB(200, 50, 50), 22)
        local exportButton = createIconButton(controlButtonsFrame, "📤", Color3.fromRGB(50, 150, 200), 22)

        -- Frame baru untuk tombol atas (Putar, Pilih Semua)
        -- Frame baru untuk tombol atas (Putar, Pilih Semua)
        local topButtonsFrame = Instance.new("Frame", controlsContainer) -- [[ PERBAIKAN: Parent diubah ]]
        topButtonsFrame.Name = "TopButtonsFrame"
        topButtonsFrame.Size = UDim2.new(1, 0, 0, 28)
        topButtonsFrame.BackgroundTransparency = 1
        topButtonsFrame.LayoutOrder = 4
        local topButtonsLayout = Instance.new("UIListLayout", topButtonsFrame)
        topButtonsLayout.FillDirection = Enum.FillDirection.Horizontal
        topButtonsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        topButtonsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        topButtonsLayout.Padding = UDim.new(0, 8)

        local selectAllButton = createIconButton(topButtonsFrame, "☑️", Color3.fromRGB(120, 120, 120), 24)
        playButton = createIconButton(topButtonsFrame, "▶️", Color3.fromRGB(0, 150, 255), 24)
        local stopButton = createIconButton(topButtonsFrame, "⏹️", Color3.fromRGB(200, 80, 80), 24)
        local deleteSelectedButton = createIconButton(topButtonsFrame, "🗑️", Color3.fromRGB(200, 50, 50), 24)

        importButton.MouseButton1Click:Connect(function()
            showRecordingFilePicker(RECORDING_FOLDER, function(importName)
                if not importName or importName == "" then return end
                local RECORDING_IMPORT_FILE = RECORDING_FOLDER .. "/" .. importName .. ".json"

                if not isfile or not isfile(RECORDING_IMPORT_FILE) then
                    showNotification("File '" .. importName .. ".json' tidak ditemukan.", Color3.fromRGB(200, 150, 50))
                    return
                end

                local success, content = pcall(readfile, RECORDING_IMPORT_FILE)
                if not success or not content then
                    showNotification("Gagal membaca file impor.", Color3.fromRGB(200, 50, 50))
                    return
                end

                local success, decodedData = pcall(HttpService.JSONDecode, HttpService, content)
                if not success or type(decodedData) ~= "table" then
                    showNotification("Data impor rekaman tidak valid!", Color3.fromRGB(200, 50, 50))
                    return
                end

                local importedCount = 0
                for recName, recData in pairs(decodedData) do
                    if not savedRecordings[recName] and type(recData) == "table" then
                        savedRecordings[recName] = recData
                        importedCount = importedCount + 1
                    end
                end

                if importedCount > 0 then
                    saveRecordingsData()
                    updateRecordingsList()
                    showNotification(importedCount .. " rekaman berhasil diimpor!", Color3.fromRGB(50, 200, 50))
                    -- Optionally, rename the file after import to avoid re-importing
                    pcall(renamefile, RECORDING_IMPORT_FILE, RECORDING_IMPORT_FILE:gsub(".json", "_imported_" .. os.time() .. ".json"))
                else
                    showNotification("Tidak ada rekaman baru untuk diimpor.", Color3.fromRGB(200, 150, 50))
                end
            end)
        end)

        selectAllButton.MouseButton1Click:Connect(function()
            local totalRecordings = 0
            local selectedCount = 0
            for _ in pairs(savedRecordings) do totalRecordings = totalRecordings + 1 end
            for _, selected in pairs(selectedRecordings) do if selected then selectedCount = selectedCount + 1 end end

            if selectedCount < totalRecordings then
                -- Select all
                for recName in pairs(savedRecordings) do
                    selectedRecordings[recName] = true
                end
            else
                -- Deselect all
                selectedRecordings = {}
            end
            updateRecordingsList()
        end)

        exportButton.MouseButton1Click:Connect(function()
            if not writefile then
                showNotification("Executor tidak mendukung penyimpanan file!", Color3.fromRGB(200, 50, 50))
                return
            end

            local toExport = {}
            local selectionCount = 0
            for name, selected in pairs(selectedRecordings) do
                if selected then
                    toExport[name] = savedRecordings[name]
                    selectionCount = selectionCount + 1
                end
            end

            if selectionCount == 0 then
                showNotification("Pilih rekaman untuk diekspor.", Color3.fromRGB(200, 150, 50))
                return
            end

            local success, jsonData = pcall(HttpService.JSONEncode, HttpService, toExport)
            if not success then
                showNotification("Gagal meng-encode data rekaman!", Color3.fromRGB(200, 50, 50))
                return
            end
            
            local exportName = promptInput("Masukkan nama file export (tanpa .json):")
if not exportName or exportName == "" then showNotification("Nama file tidak boleh kosong.", Color3.fromRGB(200, 50, 50)) return end
local RECORDING_EXPORT_FILE = RECORDING_FOLDER .. "/" .. exportName .. ".json"
            local writeSuccess, writeError = pcall(writefile, RECORDING_EXPORT_FILE, jsonData)
            
            if writeSuccess then
                showNotification(selectionCount .. " rekaman diekspor ke folder Rekaman.", Color3.fromRGB(50, 200, 50))
            else
                showNotification("Gagal mengekspor data rekaman!", Color3.fromRGB(200, 50, 50))
                warn("Export Error:", writeError)
            end
        end)
        startRecording = function(targetPlayer, showNotificationFlag)
            if isRecording then return end
            
            targetPlayer = targetPlayer or LocalPlayer -- Default ke diri sendiri jika tidak ada target
            currentRecordingTarget = targetPlayer

            -- GUI Indikator Perekaman
            local recordingIndicatorGui = Instance.new("ScreenGui", CoreGui)
            recordingIndicatorGui.Name = "RecordingIndicatorGUI"
            recordingIndicatorGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
            recordingIndicatorGui.DisplayOrder = 99
            local indicatorFrame = Instance.new("Frame", recordingIndicatorGui)
            indicatorFrame.AnchorPoint = Vector2.new(1, 0)
            indicatorFrame.Position = UDim2.new(1, -10, 0, 10)
            indicatorFrame.Size = UDim2.new(0, 110, 0, 25)
            indicatorFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            indicatorFrame.BackgroundTransparency = 0.5
            local indicatorCorner = Instance.new("UICorner", indicatorFrame)
            indicatorCorner.CornerRadius = UDim.new(0, 8)
            local indicatorLabel = Instance.new("TextLabel", indicatorFrame)
            indicatorLabel.Size = UDim2.new(1, 0, 1, 0)
            indicatorLabel.BackgroundTransparency = 1
            indicatorLabel.Font = Enum.Font.SourceSansBold
            indicatorLabel.Text = "🔴 Recording..."
            indicatorLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
            indicatorLabel.TextSize = 14

            local char = targetPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")

            if not (hrp and humanoid) then
                recStatusLabel.Text = "Karakter target tidak ditemukan."
                currentRecordingTarget = nil
                return
            end
            
            isRecording = true
            currentRecordingData = {}
            local startTime = tick()
            recStatusLabel.Text = "Merekam: " .. targetPlayer.DisplayName .. " 🔴"
            if showNotificationFlag then
                showNotification("Recording started (Press C to stop)", Color3.fromRGB(50, 200, 50))
            end
            
            recordButton.Text = "⏹️"
            recordButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)

            local lastPosition = hrp.Position
            local TELEPORT_THRESHOLD = 50 

            recordingConnection = RunService.Heartbeat:Connect(function()
                if not isRecording then return end
                
                -- [[ PERUBAHAN PENTING: Pastikan target masih valid ]]
                char = currentRecordingTarget and currentRecordingTarget.Character
                hrp = char and char:FindFirstChild("HumanoidRootPart")
                humanoid = char and char:FindFirstChildOfClass("Humanoid")
                if not (hrp and humanoid and humanoid.Health > 0) then
                    recStatusLabel.Text = "Target hilang, perekaman dihentikan."
                    stopActions()
                    return
                end

                local currentCFrame = hrp.CFrame
                local currentPosition = currentCFrame.Position
                local distance = (currentPosition - lastPosition).Magnitude
                
                local frameData = {
                    time = tick() - startTime,
                    cframe = {currentCFrame:GetComponents()},
                    state = tostring(humanoid:GetState()),
                    anims = {}
                }

                if distance > TELEPORT_THRESHOLD then
                    frameData.isTeleport = true
                end

                for _, track in ipairs(humanoid:GetPlayingAnimationTracks()) do
                    table.insert(frameData.anims, {id = track.Animation.AnimationId, time = track.TimePosition})
                end
                
                table.insert(currentRecordingData, frameData)
                lastPosition = currentPosition
            end)
        end

        stopRecording = function(showNotificationFlag)
            if not isRecording then return end
            isRecording = false
            if showNotificationFlag then
                showNotification("Recording stopped.", Color3.fromRGB(200, 50, 50))
            end
            if recordingConnection then recordingConnection:Disconnect(); recordingConnection = nil end
            
            -- Hapus GUI Indikator Perekaman
            local indicatorGui = CoreGui:FindFirstChild("RecordingIndicatorGUI")
            if indicatorGui then
                indicatorGui:Destroy()
            end

            if #currentRecordingData > 1 then
                local baseName = (currentRecordingTarget and currentRecordingTarget.Name ~= LocalPlayer.Name) and "Rekaman " .. currentRecordingTarget.Name or "Rekaman Diri"
                local newName, i = baseName .. " 1", 1
                while savedRecordings[newName] do i += 1; newName = baseName .. " " .. i end
                
                local recordingObject = {
                    frames = currentRecordingData,
                    targetUserId = currentRecordingTarget.UserId
                }
                savedRecordings[newName] = recordingObject
                
                saveRecordingsData()
                recStatusLabel.Text = "Rekaman disimpan sebagai: " .. newName
                showNotification("Rekaman disimpan: " .. newName, Color3.fromRGB(50, 200, 50))
                updateRecordingsList()
            else
                recStatusLabel.Text = "Perekaman dibatalkan (terlalu singkat)."
                showNotification("Perekaman dibatalkan (terlalu singkat).", Color3.fromRGB(200, 150, 50))
            end
            currentRecordingData = {}
            currentRecordingTarget = nil -- Reset target
            
            recordButton.Text = "🔴"
            recordButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        end
        
        playSingleRecording = function(recordingObject, onComplete)
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if not (hrp and humanoid) then if onComplete then onComplete() end; return end
        
            originalPlaybackWalkSpeed = humanoid.WalkSpeed
            IsPlaybackActive = true
            local animateScript = char and char:FindFirstChild("Animate")
            if animateScript then
                savedAnimateDisabled = animateScript.Disabled
                pcall(function() animateScript.Disabled = false end)
            end
        
            local recordingData = recordingObject.frames or recordingObject
            if not recordingData or #recordingData < 1 then if onComplete then onComplete() end; return end
        
            local recordingDuration = recordingData[#recordingData].time
            if recordingDuration <= 0 then if onComplete then onComplete() end; return end
        
            local animationCache = {}
            playbackMovers = {}
        
            pcall(function()
                local responsivenessValue = isAnimationBypassEnabled and 35 or 200
                local attachment = Instance.new("Attachment", hrp); attachment.Name = "ReplayAttachment"
                local alignPos = Instance.new("AlignPosition", attachment); alignPos.Attachment0 = attachment; alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment; alignPos.Responsiveness = responsivenessValue; alignPos.MaxForce = 100000
                local alignOrient = Instance.new("AlignOrientation", attachment); alignOrient.Attachment0 = attachment; alignOrient.Mode = Enum.OrientationAlignmentMode.OneAttachment; alignOrient.Responsiveness = 200; alignOrient.MaxTorque = 100000
                playbackMovers.attachment = attachment
                playbackMovers.alignPos = alignPos
                playbackMovers.alignOrient = alignOrient
            end)
        
            if isAnimationBypassEnabled then
                pcall(function()
                    local guidePart = Instance.new("Part"); guidePart.Name = "PlaybackGuidePart"; guidePart.Size = Vector3.new(1,1,1); guidePart.Transparency = 1; guidePart.CanCollide = false; guidePart.Anchored = true; guidePart.Parent = workspace
                    playbackMovers.guidePart = guidePart
                end)
            end
        
            local soundJumping, soundLanding, customRunningSound
            pcall(function()
                soundJumping = hrp:FindFirstChild("Jumping")
                soundLanding = hrp:FindFirstChild("FreeFalling")
                customRunningSound = Instance.new("Sound", hrp); customRunningSound.Name = "CustomRunningSound"; customRunningSound.Looped = true
                local originalRunningSound = hrp:FindFirstChild("Running")
                if originalRunningSound and originalRunningSound:IsA("Sound") then
                    customRunningSound.SoundId = originalRunningSound.SoundId; customRunningSound.Volume = originalRunningSound.Volume; customRunningSound.Pitch = originalRunningSound.Pitch
                else
                    customRunningSound.SoundId = "rbxassetid://122226169"
                end
            end)
            
            local lastPlayerState = "Idle"
            local loopStartTime = tick()
            local lastFrameIndex = 1
            local wasPaused = false
            
            playbackConnection = RunService.RenderStepped:Connect(function(dt)
                if not isPlaying then
                    if playbackConnection then playbackConnection:Disconnect(); playbackConnection = nil end
                    return 
                end
        
                if isPaused then
                    if not wasPaused then
                        -- Saat pertama kali dijeda, simpan waktu saat ini
                        pausedAtTime = tick() - loopStartTime
                        wasPaused = true
                    end
                    -- Saat dijeda, jangan lakukan apa-apa. Pemain bebas bergerak.
                    return 
                end

                if wasPaused then
                    -- Saat melanjutkan, atur ulang waktu mulai untuk melanjutkan dari titik jeda
                    loopStartTime = tick() - pausedAtTime
                    wasPaused = false
                    
                    -- Buat ulang mover karena telah dihancurkan saat jeda
                    pcall(function()
                        local responsivenessValue = isAnimationBypassEnabled and 35 or 200
                        local attachment = Instance.new("Attachment", hrp); attachment.Name = "ReplayAttachment"
                        local alignPos = Instance.new("AlignPosition", attachment); alignPos.Attachment0 = attachment; alignPos.Mode = Enum.PositionAlignmentMode.OneAttachment; alignPos.Responsiveness = responsivenessValue; alignPos.MaxForce = 100000
                        local alignOrient = Instance.new("AlignOrientation", attachment); alignOrient.Attachment0 = attachment; alignOrient.Mode = Enum.OrientationAlignmentMode.OneAttachment; alignOrient.Responsiveness = 200; alignOrient.MaxTorque = 100000
                        playbackMovers.attachment = attachment
                        playbackMovers.alignPos = alignPos
                        playbackMovers.alignOrient = alignOrient
                    end)
                    -- [[ PERBAIKAN BUG STUCK ANIMASI ]]
                    -- Paksa Animate script untuk re-evaluasi state setelah jeda
                    pcall(function()
                        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                        task.wait()
                        humanoid:ChangeState(Enum.HumanoidStateType.Running)
                    end)
                end
        
                local elapsedTime = tick() - loopStartTime
                
                if elapsedTime >= recordingDuration then
                    if playbackConnection then playbackConnection:Disconnect(); playbackConnection = nil end
                    cleanupSinglePlayback(onComplete ~= nil)
                    if onComplete then onComplete() end
                    return
                end
                
                local frameToPlay, currentFrame
                for i = lastFrameIndex, #recordingData do
                    if recordingData[i].time >= elapsedTime then
                        frameToPlay = recordingData[i]
                        currentFrame = recordingData[i-1] or recordingData[1]
                        lastFrameIndex = i
                        break
                    end
                end
                
                if not frameToPlay then
                    frameToPlay = recordingData[#recordingData]
                    currentFrame = recordingData[#recordingData]
                end
        
                local cframeToPlay = CFrame.new(unpack(frameToPlay.cframe))
                local cframeCurrent = CFrame.new(unpack(currentFrame.cframe))
                
                local velocity = 0
                local timeDelta = frameToPlay.time - currentFrame.time
                if timeDelta > 0.001 then
                    velocity = (cframeToPlay.Position - cframeCurrent.Position).Magnitude / timeDelta
                end
                
                local interpolatedCFrame
                if frameToPlay.isTeleport then
                    interpolatedCFrame = cframeToPlay
                    loopStartTime = tick() - frameToPlay.time
                else
                    local alpha = math.clamp((elapsedTime - currentFrame.time) / timeDelta, 0, 1)
                    interpolatedCFrame = cframeCurrent:Lerp(cframeToPlay, alpha)
                end


                local currentState = currentFrame.state
                
                if not isAnimationBypassEnabled then
                    if playbackMovers.alignPos then
                        playbackMovers.alignPos.Position = interpolatedCFrame.Position
                        -- Shiftlock Fix v3: Toggle the mover's Enabled property for better replication
                        if playbackMovers.alignOrient then
                            local isShiftLockActive = (UserInputService and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter)
                            if isShiftLockActive then
                                playbackMovers.alignOrient.Enabled = false
                            else
                                playbackMovers.alignOrient.Enabled = true
                                playbackMovers.alignOrient.CFrame = interpolatedCFrame
                            end
                        end
                    end
                    humanoid.WalkSpeed = originalPlaybackWalkSpeed
        
                    local requiredAnims = {}
                    for _, animData in ipairs(currentFrame.anims) do
                        requiredAnims[animData.id] = animData.time
                        if not animationCache[animData.id] then
                            local anim = Instance.new("Animation"); anim.AnimationId = animData.id
                            animationCache[animData.id] = humanoid:LoadAnimation(anim)
                        end
                        local track = animationCache[animData.id]
                        if not track.IsPlaying then track:Play(0.1) end
                        track:AdjustSpeed(velocity / (originalPlaybackWalkSpeed > 0 and originalPlaybackWalkSpeed or 16))
                        track.TimePosition = animData.time
                    end
                    for id, track in pairs(animationCache) do
                        if not requiredAnims[id] and track.IsPlaying then track:Stop(0.1) end
                    end
                else -- Animation Bypass is ENABLED
                    -- Hapus animasi yang di-cache dari mode non-bypass
                    if next(animationCache) then
                        for id, track in pairs(animationCache) do
                            if track.IsPlaying then track:Stop(0) end
                        end
                        animationCache = {} -- Kosongkan cache
                    end

                    -- Set WalkSpeed dynamically to let the default Animate script handle walk/run transitions
                    humanoid.WalkSpeed = velocity

                    -- Gerakkan karakter menggunakan AlignPosition dan AlignOrientation untuk FE
                    if playbackMovers.alignPos and playbackMovers.alignOrient then
                        playbackMovers.alignPos.Position = interpolatedCFrame.Position
                        -- Shiftlock Fix v4: Explicitly check for the script's own shift lock feature
                        if IsShiftLockEnabled then
                            playbackMovers.alignOrient.Enabled = false
                        else
                            playbackMovers.alignOrient.Enabled = true
                            playbackMovers.alignOrient.CFrame = interpolatedCFrame
                        end
                    end
                    
                end
        
                pcall(function()
                    if currentState and currentState ~= lastPlayerState then
                        local stateName = currentState:match("Enum.HumanoidStateType%.(.*)")
                        if stateName and Enum.HumanoidStateType[stateName] then
                            humanoid:ChangeState(Enum.HumanoidStateType[stateName])
                        end
                        if currentState == "Enum.HumanoidStateType.Jumping" and soundJumping then soundJumping:Play() end
                        if lastPlayerState == "Enum.HumanoidStateType.Freefall" and currentState ~= "Enum.HumanoidStateType.Jumping" and soundLanding then soundLanding:Play() end
                    end
                    
                    if customRunningSound then
                        local isRunning = (currentState == "Enum.HumanoidStateType.Running" or currentState == "Enum.HumanoidStateType.RunningNoPhysics")
                        if isRunning and velocity > 1 and not customRunningSound.IsPlaying then
                            customRunningSound.PlaybackSpeed = velocity / (originalPlaybackWalkSpeed > 0 and originalPlaybackWalkSpeed or 16)
                            customRunningSound:Play()
                        elseif (not isRunning or velocity <= 1) and customRunningSound.IsPlaying then
                            customRunningSound:Stop()
                        end
                    end
                    lastPlayerState = currentState
                end)
            end)
        end
        
        local replayOptionsFrame = Instance.new("Frame", controlsContainer) -- [[ PERBAIKAN: Parent diubah ]]
        replayOptionsFrame.Name = "ReplayOptionsFrame"
        replayOptionsFrame.Size = UDim2.new(1, 0, 0, 25)
        replayOptionsFrame.BackgroundTransparency = 1
        replayOptionsFrame.LayoutOrder = 2
        local replayOptionsLayout = Instance.new("UIListLayout", replayOptionsFrame)
        replayOptionsLayout.FillDirection = Enum.FillDirection.Horizontal
        replayOptionsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        local replayLabel = Instance.new("TextLabel", replayOptionsFrame)
        replayLabel.Name = "ReplayLabel"
        replayLabel.Size = UDim2.new(0.7, -5, 1, 0)
        replayLabel.BackgroundTransparency = 1
        replayLabel.Font = Enum.Font.SourceSans
        replayLabel.Text = "Jumlah Ulang (0 = ∞):"
        replayLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        replayLabel.TextSize = 12
        replayLabel.TextXAlignment = Enum.TextXAlignment.Left
        local replayCountBox = Instance.new("TextBox", replayOptionsFrame)
        replayCountBox.Name = "ReplayCountBox"
        replayCountBox.Size = UDim2.new(0.3, 0, 1, 0)
        replayCountBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        replayCountBox.Font = Enum.Font.SourceSans
        replayCountBox.Text = "1"
        replayCountBox.PlaceholderText = "1"
        replayCountBox.TextColor3 = Color3.fromRGB(220, 220, 220)
        replayCountBox.TextSize = 12
        replayCountBox.ClearTextOnFocus = false
        local boxCorner = Instance.new("UICorner", replayCountBox)
        boxCorner.CornerRadius = UDim.new(0, 4)
        replayCountBox:GetPropertyChangedSignal("Text"):Connect(function() replayCountBox.Text = replayCountBox.Text:gsub("%D", "") end)
        
        local bypassAnimToggle, bypassAnimSwitch = createToggle(controlsContainer, "Bypass Animasi", isAnimationBypassEnabled, function(v) -- [[ PERBAIKAN: Parent diubah ]]
            isAnimationBypassEnabled = v
            if v and LocalPlayer.Character then
                applyAllAnimations(LocalPlayer.Character)
                showNotification("Bypass menggunakan set animasi kustom Anda.", Color3.fromRGB(50, 150, 255))
            end
        end)
        bypassAnimToggle.LayoutOrder = 3

        recStatusLabel = Instance.new("TextLabel", controlsContainer) -- [[ PERBAIKAN: Parent diubah ]]
        recStatusLabel.Name = "StatusLabel"
        recStatusLabel.Size = UDim2.new(1, 0, 0, 20)
        recStatusLabel.BackgroundTransparency = 1
        recStatusLabel.Font = Enum.Font.SourceSansItalic
        recStatusLabel.Text = "Siap."
        recStatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
        recStatusLabel.TextSize = 12
        recStatusLabel.LayoutOrder = 5
        
        -- [[ PERBAIKAN: Definisi ScrollingFrame lama dihapus karena sudah dibuat di atas ]]
        
        recordButton.MouseButton1Click:Connect(function()
            if isRecording then
                stopRecording(false)
            else
                if IsViewingPlayer and currentlyViewedPlayer then
                    startRecording(currentlyViewedPlayer, false)
                else
                    startRecording(LocalPlayer, false) -- Default to self if not spectating
                end
            end
        end)
        
        playButton.MouseButton1Click:Connect(function()
            if isPlaying then
                isPaused = not isPaused
                if isPaused then
                    -- Jeda: Hancurkan mover agar pemain bisa bergerak bebas
                    if playbackConnection then
                        -- Dapatkan waktu jeda dari koneksi yang sedang berjalan
                        -- Ini memerlukan sedikit trik karena elapsedTime bersifat lokal untuk koneksi
                        -- Kita akan menyimpannya di variabel upvalue saat jeda
                    end
                    cleanupSinglePlayback(true) -- Gunakan 'true' untuk menandakan ini bagian dari sekuens
                    playButton.Text = "▶️"
                    playButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
                    recStatusLabel.Text = "Pemutaran dijeda."
                else
                    -- Lanjutkan: Pemutaran akan dilanjutkan oleh loop playSequence
                    playButton.Text = "⏸️"
                    playButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                    recStatusLabel.Text = "Melanjutkan pemutaran..."
                end
            else
                playSequence(replayCountBox)
            end
        end)

        stopButton.MouseButton1Click:Connect(function()
            stopActions()
        end)

        deleteSelectedButton.MouseButton1Click:Connect(function()
            local deletedCount = 0
            for recName, isSelected in pairs(selectedRecordings) do
                if isSelected then
                    savedRecordings[recName] = nil
                    deletedCount = deletedCount + 1
                end
            end

            if deletedCount > 0 then
                selectedRecordings = {} -- Clear selection
                saveRecordingsData()
                updateRecordingsList()
                recStatusLabel.Text = "Berhasil menghapus " .. deletedCount .. " rekaman."
                showNotification("Berhasil menghapus " .. deletedCount .. " rekaman.", Color3.fromRGB(50, 200, 50))
            else
                recStatusLabel.Text = "Tidak ada rekaman yang dipilih untuk dihapus."
                showNotification("Tidak ada rekaman yang dipilih.", Color3.fromRGB(200, 150, 50))
            end
        end)
    end

    -- Fungsi untuk membuka/menutup jendela utama, dipisahkan agar bisa dipanggil oleh MakeDraggable
    local function toggleMainFrame()
        MainFrame.Visible = not MainFrame.Visible
        MiniToggleButton.Text = MainFrame.Visible and "◀" or "▶"
        MiniToggleButton.BackgroundTransparency = MainFrame.Visible and 0.5 or 1
        if MainFrame.Visible then
            if not (PlayerTabContent.Visible or GeneralTabContent.Visible or TeleportTabContent.Visible or VipTabContent.Visible or SettingsTabContent.Visible or RekamanTabContent.Visible) then
                switchTab("Player")
            else
                updatePlayerList()
            end
        end
    end
    
    -- =================================================================================
    -- == BAGIAN UTAMA DAN KONEKSI EVENT                                              ==
    -- =================================================================================
    
    setupPlayerTab()
    setupGeneralTab()
    setupTeleportTab()
    setupVipTab()
    setupSettingsTab()
    setupRekamanTab()

    MakeDraggable(MainFrame, TitleBar, function() return true end, nil)

    -- [[ PERUBAHAN BARU: Logika untuk mengubah ukuran MainFrame (Diperbaiki) ]]
    ConnectEvent(MainResizeHandle.InputBegan, function(input)
        if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then return end

        local isResizing = true
        local initialMousePosition = UserInputService:GetMouseLocation()
        local initialFrameSize = MainFrame.AbsoluteSize

        local inputChangedConnection
        local inputEndedConnection

        inputChangedConnection = UserInputService.InputChanged:Connect(function(changedInput)
            if isResizing and (changedInput.UserInputType == Enum.UserInputType.MouseMovement or changedInput.UserInputType == Enum.UserInputType.Touch) then
                local delta = UserInputService:GetMouseLocation() - initialMousePosition
                local newSizeX = math.max(200, initialFrameSize.X + delta.X) -- Ukuran minimum
                local newSizeY = math.max(150, initialFrameSize.Y + delta.Y) -- Ukuran minimum
                MainFrame.Size = UDim2.new(0, newSizeX, 0, newSizeY)
            end
        end)

        inputEndedConnection = UserInputService.InputEnded:Connect(function(endedInput)
            if endedInput.UserInputType == input.UserInputType then
                isResizing = false
                if inputChangedConnection then inputChangedConnection:Disconnect() end
                if inputEndedConnection then inputEndedConnection:Disconnect() end
                saveGuiPositions() -- Simpan ukuran baru setelah selesai
            end
        end)
    end)
    
    -- [PERBAIKAN] Sekarang, tombol ◀ (MiniToggleButton) menjadi satu-satunya handle untuk menggeser
    -- kontainernya (MiniToggleContainer). Ini meniru perilaku jendela utama di mana TitleBar
    -- digunakan untuk menggeser MainFrame. Logika klik dan geser kini disatukan.
    MakeDraggable(MiniToggleContainer, MiniToggleButton, function() return isMiniToggleDraggable end, toggleMainFrame)
    
    -- Koneksi MouseButton1Click yang lama untuk MiniToggleButton dihapus karena fungsinya
    -- sekarang sudah ditangani oleh argumen 'clickCallback' di dalam MakeDraggable.

    ConnectEvent(EmoteToggleButton.MouseButton1Click, function()
        pcall(initializeEmoteGUI)
    end)

    ConnectEvent(AnimationShowButton.MouseButton1Click, function()
        if AnimationScreenGui then
            local frame = AnimationScreenGui:FindFirstChild("GazeBro")
            if frame then
                frame.Visible = true
                AnimationShowButton.Visible = false
            end
        end
    end)
    
    ConnectEvent(UserInputService.InputBegan, function(input, processed)
        if processed or UserInputService:GetFocusedTextBox() then return end

        if input.KeyCode == Enum.KeyCode.F and not UserInputService.TouchEnabled then
            if not IsFlying then StartFly() else StopFly() end
        elseif input.KeyCode == Enum.KeyCode.C then
            -- Periksa apakah sedang merekam, utamakan untuk berhenti & simpan
            if isRecording then
                stopRecording(true) -- Selalu simpan rekaman
                
                -- Jika pemutaran juga berjalan, hentikan setelah rekaman disimpan
                if isPlaying then
                    stopPlayback()
                end
            -- Jika hanya pemutaran yang berjalan (tidak ada rekaman)
            elseif isPlaying then
                stopPlayback()
            -- Jika tidak ada yang aktif, mulai rekaman baru
            else
                if IsViewingPlayer and currentlyViewedPlayer then
                    startRecording(currentlyViewedPlayer, true)
                else
                    startRecording(LocalPlayer, true)
                end
            end
        end
    end)

    
    local function applyAllAnimations(character)
        if isGameAnimationOverrideActive then return end
        if not character or not next(lastAnimations) then return end

        local animateScript = character:WaitForChild("Animate", 10)
        if not animateScript then
            warn("ArexansTools: Gagal menerapkan animasi, script 'Animate' tidak ditemukan.")
            return
        end

        task.wait(0.2) -- A short wait to ensure the script is ready

        -- Helper function to safely destroy and replace an animation object.
        -- This is crucial for respawns as the old objects are destroyed.
        local function replaceAnimation(parent, animName, newId)
            if not parent then return end
            -- Destroy the old animation object if it exists
            local oldAnim = parent:FindFirstChild(animName)
            if oldAnim then
                oldAnim:Destroy()
            end
            -- Create a new animation instance
            local newAnim = Instance.new("Animation")
            newAnim.Name = animName
            newAnim.AnimationId = "http://www.roblox.com/asset/?id=" .. tostring(newId)
            newAnim.Parent = parent
        end

        pcall(function()
            if lastAnimations.Idle and #lastAnimations.Idle == 2 then
                replaceAnimation(animateScript.idle, "Animation1", lastAnimations.Idle[1])
                replaceAnimation(animateScript.idle, "Animation2", lastAnimations.Idle[2])
            end
            if lastAnimations.Walk then replaceAnimation(animateScript.walk, "WalkAnim", lastAnimations.Walk) end
            if lastAnimations.Run then replaceAnimation(animateScript.run, "RunAnim", lastAnimations.Run) end
            if lastAnimations.Jump then replaceAnimation(animateScript.jump, "JumpAnim", lastAnimations.Jump) end
            if lastAnimations.Fall then replaceAnimation(animateScript.fall, "FallAnim", lastAnimations.Fall) end
            if lastAnimations.Swim and animateScript.swim then replaceAnimation(animateScript.swim, "Swim", lastAnimations.Swim) end
            if lastAnimations.SwimIdle and animateScript.swimidle then replaceAnimation(animateScript.swimidle, "SwimIdle", lastAnimations.SwimIdle) end
            if lastAnimations.Climb then replaceAnimation(animateScript.climb, "ClimbAnim", lastAnimations.Climb) end
        end)
    end
    
    local function applyInitialStates()
        -- Panggil toggle untuk setiap fitur dengan status yang dimuat.
        -- Ini memastikan status 'off' juga diterapkan dengan benar.
        ToggleAntiLag(IsAntiLagEnabled)
        ToggleBoostFPS(IsBoostFPSEnabled)
        ToggleFEInvisible(IsFEInvisibleEnabled)
        ToggleESPName(IsEspNameEnabled)
        ToggleESPBody(IsEspBodyEnabled)
    end
    
    local function reapplyFeaturesOnRespawn(character)
        if not character then return end
    
        -- Tunggu sebentar agar karakter sepenuhnya dimuat
        task.wait(0.2) 
    
        -- Terapkan kembali status untuk setiap fitur
        -- Ini akan menangani status 'on' dan 'off'
        ToggleWalkSpeed(IsWalkSpeedEnabled)
        ToggleGodMode(IsGodModeEnabled)
        ToggleAntiFling(antifling_enabled)
        ToggleNoclip(IsNoclipEnabled)
        ToggleShiftLock(IsShiftLockEnabled)

        -- [[ INTEGRASI KUNCI KECEPATAN ]] --
        if character:FindFirstChildOfClass("Humanoid") then
            speedLock_bindHumanoid(character:FindFirstChildOfClass("Humanoid"))
        end

        -- Untuk fitur yang memerlukan logika khusus saat respawn
        if IsInvisibleGhostEnabled then
            -- Nonaktifkan saat respawn untuk mencegah bug, pengguna dapat mengaktifkannya kembali
            ToggleInvisibleGhost(false) 
        end
    
        if IsInfinityJumpEnabled then
            -- Sambungkan kembali event jika diaktifkan
            if infinityJumpConnection then infinityJumpConnection:Disconnect() end
            infinityJumpConnection = ConnectEvent(UserInputService.JumpRequest, function()
                if IsInfinityJumpEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
                    LocalPlayer.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end)
        end
    
        if IsFlying then
            -- Hentikan dan mulai ulang terbang untuk mendapatkan body movers baru
            IsFlying = false -- Setel ulang status untuk memulai ulang
            if UserInputService.TouchEnabled then
                StartMobileFly()
            else
                StartFly()
            end
        end

        -- [BARU] Deteksi animasi bawaan game (HANYA UNTUK R6)
        isGameAnimationOverrideActive = false -- Reset status saat respawn
        task.wait(0.5) -- Beri waktu agar script Animate memuat animasi
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if humanoid and humanoid.RigType == Enum.HumanoidRigType.R6 then
            local animateScript = character:FindFirstChild("Animate")
            if animateScript then
                local walkAnim = animateScript:FindFirstChild("walk", true) and animateScript:FindFirstChild("walk", true):FindFirstChild("WalkAnim")
                if walkAnim and walkAnim:IsA("Animation") then
                    local currentWalkAnimId = walkAnim.AnimationId:match("%d+")
                    if currentWalkAnimId and currentWalkAnimId ~= "10921269718" then
                        isGameAnimationOverrideActive = true
                        showNotification("Animasi game terdeteksi! Fitur animasi kustom dinonaktifkan.", Color3.fromRGB(255, 150, 0))
                    end
                end
            end
        end

        applyAllAnimations(character)
    end
    
    ConnectEvent(LocalPlayer.CharacterAdded, reapplyFeaturesOnRespawn)

    -- INISIALISASI
    storeBoostFpsOriginalSettings() -- [[ PERBAIKAN BUG: Simpan pengaturan asli saat startup ]]
    loadAnimations()
    loadTeleportData()
    loadGuiPositions()
    loadFeatureStates()
    loadRecordingsData() -- [[ PERUBAHAN BARU ]]
    loadFavorites() -- [[ PERUBAHAN BARU ]]
    applyInitialStates()
    switchTab("Player")
    
    if LocalPlayer.Character then
        reapplyFeaturesOnRespawn(LocalPlayer.Character)
    end

    -- Countdown Timer
    local countdownConn
    local logoutNotificationFrame = nil
    countdownConn = RunService.Heartbeat:Connect(function()
        if not ScreenGui or not ScreenGui.Parent then
            countdownConn:Disconnect()
            return
        end

        local remainingSeconds = expirationTimestamp - os.time()

        if remainingSeconds <= 10 and remainingSeconds > 0 then
            if not logoutNotificationFrame or not logoutNotificationFrame.Parent then
                logoutNotificationFrame = Instance.new("Frame", ScreenGui)
                logoutNotificationFrame.Name = "LogoutNotificationFrame"
                logoutNotificationFrame.Size = UDim2.new(0, 300, 0, 50)
                logoutNotificationFrame.Position = UDim2.new(0.5, -150, 0.1, 0)
                logoutNotificationFrame.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
                logoutNotificationFrame.BackgroundTransparency = 0.2
                logoutNotificationFrame.BorderSizePixel = 0
                local corner = Instance.new("UICorner", logoutNotificationFrame); corner.CornerRadius = UDim.new(0, 8)
                local stroke = Instance.new("UIStroke", logoutNotificationFrame); stroke.Color = Color3.fromRGB(255, 100, 100); stroke.Thickness = 1
                
                local label = Instance.new("TextLabel", logoutNotificationFrame)
                label.Name = "CountdownLabel"
                label.Size = UDim2.new(1, 0, 1, 0)
                label.BackgroundTransparency = 1
                label.Font = Enum.Font.SourceSansBold
                label.TextColor3 = Color3.fromRGB(255, 255, 255)
                label.TextSize = 16
                label.TextWrapped = true
            end
            local label = logoutNotificationFrame and logoutNotificationFrame:FindFirstChild("CountdownLabel")
            if label then
                label.Text = "Sesi akan berakhir & logout dalam " .. math.floor(remainingSeconds) .. " detik..."
            end
        end

        if remainingSeconds < 1 then
            countdownConn:Disconnect() -- Disconnect this timer itself
            HandleLogout() -- Perform total shutdown and logout
            return -- Stop the function
        end

        -- Update label text
        local days = math.floor(remainingSeconds / 86400)
        local rem = remainingSeconds % 86400
        local hours = math.floor(rem / 3600)
        rem = rem % 3600
        local minutes = math.floor(rem / 60)
        local seconds = rem % 60
        if ExpirationLabel and ExpirationLabel.Parent then
            ExpirationLabel.Text = string.format("Expires in: %dD %02dH %02dM %02dS", days, hours, minutes, seconds)
        end
    end)
    end -- End of InitializeMainGUI

    local function CreatePasswordPromptGUI(passwordData)
        -- ====================================================================
        -- == BAGIAN GUI PROMPT PASSWORD                                   ==
        -- ====================================================================
        local PasswordScreenGui = Instance.new("ScreenGui")
        PasswordScreenGui.Name = "PasswordPromptGUI"
        PasswordScreenGui.Parent = CoreGui
        PasswordScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        PasswordScreenGui.ResetOnSpawn = false

        local PromptFrame = Instance.new("Frame")
        PromptFrame.Name = "PromptFrame"
        PromptFrame.Size = UDim2.new(0, 250, 0, 150)
        PromptFrame.Position = UDim2.new(0.5, -125, 0.5, -75)
        PromptFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
        PromptFrame.BackgroundTransparency = 0.5
        PromptFrame.BorderSizePixel = 0
        PromptFrame.Parent = PasswordScreenGui

        local PromptCorner = Instance.new("UICorner", PromptFrame)
        PromptCorner.CornerRadius = UDim.new(0, 8)
        local PromptStroke = Instance.new("UIStroke", PromptFrame)
        PromptStroke.Color = Color3.fromRGB(0, 150, 255)
        PromptStroke.Thickness = 2
        PromptStroke.Transparency = 0.5

        -- [MODIFIKASI] Mengubah Title menjadi TextButton untuk handle drag
        local PromptTitle = Instance.new("TextButton")
        PromptTitle.Name = "Title"
        PromptTitle.Size = UDim2.new(1, 0, 0, 30)
        PromptTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        PromptTitle.Text = "" -- Teks judul akan diatur oleh label terpisah
        PromptTitle.AutoButtonColor = false
        PromptTitle.Parent = PromptFrame

        local PromptTitleLabel = Instance.new("TextLabel", PromptTitle)
        PromptTitleLabel.Name = "TitleLabel"
        PromptTitleLabel.Size = UDim2.new(1, 0, 1, 0) -- Isi seluruh parent
        PromptTitleLabel.Position = UDim2.new(0, 0, 0, 0)
        PromptTitleLabel.BackgroundTransparency = 1
        PromptTitleLabel.Text = "Password"
        PromptTitleLabel.Font = Enum.Font.SourceSansBold
        PromptTitleLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
        PromptTitleLabel.TextSize = 14
        PromptTitleLabel.TextXAlignment = Enum.TextXAlignment.Center -- Pusatkan teks

        -- [MODIFIKASI] Menambahkan Tombol Close (X)
        local CloseButton = Instance.new("TextButton")
        CloseButton.Name = "CloseButton"
        CloseButton.Size = UDim2.new(0, 20, 0, 20)
        CloseButton.Position = UDim2.new(1, -15, 0.5, 0) -- Posisi disesuaikan
        CloseButton.AnchorPoint = Vector2.new(0.5, 0.5)
        CloseButton.BackgroundTransparency = 1
        CloseButton.Font = Enum.Font.SourceSansBold
        CloseButton.Text = "X"
        CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        CloseButton.TextSize = 18
        CloseButton.Parent = PromptTitle
        CloseButton.MouseButton1Click:Connect(function()
            PasswordScreenGui:Destroy()
        end)

        -- [MODIFIKASI] Membuat jendela dapat digeser
        pcall(function()
            MakeDraggable(PromptFrame, PromptTitle, function() return true end, nil)
        end)

        local PasswordBox = Instance.new("TextBox", PromptFrame)
        PasswordBox.Name = "PasswordBox"
        PasswordBox.Size = UDim2.new(1, -20, 0, 30)
        PasswordBox.Position = UDim2.new(0, 10, 0, 40)
        PasswordBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        PasswordBox.TextColor3 = Color3.fromRGB(220, 220, 220)
        PasswordBox.PlaceholderText = "Enter Password..."
        PasswordBox.Text = ""
        PasswordBox.Font = Enum.Font.SourceSans
        PasswordBox.TextSize = 14
        PasswordBox.ClearTextOnFocus = false
        local PassCorner = Instance.new("UICorner", PasswordBox)
        PassCorner.CornerRadius = UDim.new(0, 5)

        local SubmitButton = Instance.new("TextButton", PromptFrame)
        SubmitButton.Name = "SubmitButton"
        SubmitButton.Size = UDim2.new(1, -20, 0, 30)
        SubmitButton.Position = UDim2.new(0, 10, 0, 80)
        SubmitButton.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
        SubmitButton.Text = "Login"
        SubmitButton.Font = Enum.Font.SourceSansBold
        SubmitButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        SubmitButton.TextSize = 14
        local SubmitCorner = Instance.new("UICorner", SubmitButton)
        SubmitCorner.CornerRadius = UDim.new(0, 5)

        local StatusLabel = Instance.new("TextLabel", PromptFrame)
        StatusLabel.Name = "StatusLabel"
        StatusLabel.Size = UDim2.new(1, -20, 0, 20)
        StatusLabel.Position = UDim2.new(0, 10, 1, -25)
        StatusLabel.BackgroundTransparency = 1
        StatusLabel.Text = ""
        StatusLabel.Font = Enum.Font.SourceSans
        StatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        StatusLabel.TextSize = 12

        SubmitButton.MouseButton1Click:Connect(function()
            local enteredPassword = PasswordBox.Text
            local valid = false
            local expiration
            local role = "Normal"

            for _, data in ipairs(passwordData) do
                if data.password == enteredPassword then
                    expiration = parseISO8601(data.expired)
                    if expiration and os.time() < expiration then
                        valid = true
                        role = data.role or "Normal"
                        break
                    end
                end
            end

            if valid then
                pcall(saveSession, expiration, role, enteredPassword) -- Simpan sesi setelah login berhasil
                PasswordScreenGui:Destroy()
                InitializeMainGUI(expiration, role)
                if role ~= "Developer" then
                    task.spawn(function()
                        local success, infoScript = pcall(function()
                            return game:HttpGet("https://raw.githubusercontent.com/AREXANS/emoteff/refs/heads/main/info.lua")
                        end)
                        if success and infoScript then
                            pcall(loadstring(infoScript))
                        else
                            warn("Gagal memuat atau menjalankan script info.")
                        end
                    end)
                end
            else
                StatusLabel.Text = "Password incorrect or expired."
            end
        end)
    end

    -- ====================================================================
    -- == LOGIKA EKSEKUSI UTAMA                                        ==
    -- ====================================================================
    local function validateRoleWithServer(password, currentExpiration, currentRole)
        local success, passwordData = pcall(function()
            local rawData = game:HttpGet("https://raw.githubusercontent.com/AREXANS/cupapi/refs/heads/main/keksoeldlkdkd.json" .. "?t=" .. os.time())
            return HttpService:JSONDecode(rawData)
        end)

        if not success or not passwordData then
            -- Jika server gagal merespons, percayai sesi lokal untuk sementara
            warn("Tidak dapat memvalidasi peran dengan server, menggunakan sesi lokal.", passwordData)
            return currentExpiration, currentRole
        end

        for _, data in ipairs(passwordData) do
            if data.password == password then
                local newExpiration = parseISO8601(data.expired)
                if newExpiration and os.time() < newExpiration then
                    local newRole = data.role or "Normal"
                    -- Selalu simpan sesi jika valid, untuk memperbarui tanggal kedaluwarsa jika berubah.
                    pcall(saveSession, newExpiration, newRole, password)
                    return newExpiration, newRole
                end
            end
        end

        -- Jika password tidak lagi ditemukan atau sudah kedaluwarsa di server
        deleteSession()
        return nil, nil
    end

    local savedExpiration, savedRole, savedPassword = loadSession()

    if savedPassword then
        -- Selalu coba validasi ulang kata sandi yang tersimpan dengan server
        local newExpiration, newRole = validateRoleWithServer(savedPassword, savedExpiration, savedRole)
        if newExpiration and newRole then
            -- Sukses! Server mengonfirmasi kata sandi dan sesi telah diperbarui.
            InitializeMainGUI(newExpiration, newRole)
        else
            -- Kata sandi yang tersimpan tidak lagi valid. Hapus sesi lama dan minta login.
            deleteSession()
            local success, passwordData = pcall(function()
                local rawData = game:HttpGet("https://raw.githubusercontent.com/AREXANS/cupapi/refs/heads/main/keksoeldlkdkd.json" .. "?t=" .. os.time())
                return HttpService:JSONDecode(rawData)
            end)
            if success and passwordData then
                CreatePasswordPromptGUI(passwordData)
            else
                warn("Tidak dapat mengambil file kata sandi untuk login baru.", passwordData)
            end
        end
    else
        -- Tidak ada kata sandi yang tersimpan, perlu login manual.
        local success, passwordData = pcall(function()
            local rawData = game:HttpGet("https://raw.githubusercontent.com/AREXANS/cupapi/refs/heads/main/keksoeldlkdkd.json" .. "?t=" .. os.time())
            return HttpService:JSONDecode(rawData)
        end)
        if success and passwordData then
            CreatePasswordPromptGUI(passwordData)
        else
            warn("Tidak dapat mengambil atau mengurai file kata sandi.", passwordData)
        end
    end
end)

-- =========================================================
-- ====== FITUR BARU: OPTIMIZED GAME ======
-- =========================================================
task.defer(function()
    local Lighting = game:GetService("Lighting")
    local Workspace = game:GetService("Workspace")
    local RunService = game:GetService("RunService")
    local CoreGui = game:GetService("CoreGui")
    local TweenService = game:GetService("TweenService")

    local IsOptimizedGameEnabled = false
    local storedProperties = {}

    local function scanAndDisableHeavyObjects()
        storedProperties = {}
        for _, obj in ipairs(Workspace:GetDescendants()) do
            pcall(function()
                if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Beam") or obj:IsA("Smoke")
                or obj:IsA("Fire") or obj:IsA("Explosion") or obj:IsA("Sparkles") then
                    storedProperties[obj] = {Enabled = obj.Enabled}
                    obj.Enabled = false
                elseif obj:IsA("BasePart") and (obj.Name:lower():find("tree") or obj.Name:lower():find("grass")
                    or obj.Name:lower():find("bush") or obj.Name:lower():find("aura") or obj.Name:lower():find("leaf")
                    or obj.Name:lower():find("cloud") or obj.Name:lower():find("fog") or obj.Name:lower():find("effect")) then
                    storedProperties[obj] = {Transparency = obj.Transparency}
                    obj.Transparency = 1
                    if obj:FindFirstChildOfClass("Decal") then
                        for _, d in ipairs(obj:GetDescendants()) do
                            if d:IsA("Decal") or d:IsA("Texture") then
                                storedProperties[d] = {Transparency = d.Transparency}
                                d.Transparency = 1
                            end
                        end
                    end
                end
            end)
        end

        -- Nonaktifkan efek Lighting berat
        for _, eff in ipairs(Lighting:GetChildren()) do
            pcall(function()
                if eff:IsA("Atmosphere") or eff:IsA("BloomEffect") or eff:IsA("ColorCorrectionEffect")
                or eff:IsA("SunRaysEffect") or eff:IsA("DepthOfFieldEffect") or eff:IsA("Sky") then
                    storedProperties[eff] = {Parent = eff.Parent}
                    eff.Parent = nil
                end
            end)
        end

        -- Simpan dan ubah properti ringan Lighting
        storedProperties["LightingProps"] = {
            GlobalShadows = Lighting.GlobalShadows,
            Brightness = Lighting.Brightness,
            FogEnd = Lighting.FogEnd,
            EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
            EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale
        }
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.Brightness = 1
            Lighting.FogEnd = 1e6
            Lighting.EnvironmentDiffuseScale = 0
            Lighting.EnvironmentSpecularScale = 0
        end)

        -- Terrain ringan
        if Workspace:FindFirstChildOfClass("Terrain") then
            local terrain = Workspace:FindFirstChildOfClass("Terrain")
            storedProperties["Terrain"] = {
                Decoration = terrain.Decoration,
                WaterReflectance = terrain.WaterReflectance,
                WaterTransparency = terrain.WaterTransparency,
                WaterWaveSize = terrain.WaterWaveSize,
                WaterWaveSpeed = terrain.WaterWaveSpeed
            }
            pcall(function()
                terrain.Decoration = false
                terrain.WaterReflectance = 0
                terrain.WaterTransparency = 1
                terrain.WaterWaveSize = 0
                terrain.WaterWaveSpeed = 0
            end)
        end
    end

    local function restoreHeavyObjects()
        for obj, props in pairs(storedProperties) do
            pcall(function()
                if typeof(obj) == "Instance" and obj.Parent then
                    for k, v in pairs(props) do
                        if typeof(v) == "Instance" and not obj.Parent then
                            v.Parent = obj
                        else
                            obj[k] = v
                        end
                    end
                elseif obj == "LightingProps" then
                    Lighting.GlobalShadows = props.GlobalShadows
                    Lighting.Brightness = props.Brightness
                    Lighting.FogEnd = props.FogEnd
                    Lighting.EnvironmentDiffuseScale = props.EnvironmentDiffuseScale
                    Lighting.EnvironmentSpecularScale = props.EnvironmentSpecularScale
                elseif obj == "Terrain" and Workspace:FindFirstChildOfClass("Terrain") then
                    local terrain = Workspace:FindFirstChildOfClass("Terrain")
                    terrain.Decoration = props.Decoration
                    terrain.WaterReflectance = props.WaterReflectance
                    terrain.WaterTransparency = props.WaterTransparency
                    terrain.WaterWaveSize = props.WaterWaveSize
                    terrain.WaterWaveSpeed = props.WaterWaveSpeed
                end
            end)
        end
        storedProperties = {}
    end

    local function createToggle(parent, name, initialState, callback)
        local toggleFrame = Instance.new("Frame", parent); toggleFrame.Size = UDim2.new(1, 0, 0, 25); toggleFrame.BackgroundTransparency = 1; local toggleLabel = Instance.new("TextLabel", toggleFrame); toggleLabel.Size = UDim2.new(0.8, -10, 1, 0); toggleLabel.Position = UDim2.new(0, 5, 0, 0); toggleLabel.BackgroundTransparency = 1; toggleLabel.Text = name; toggleLabel.TextColor3 = Color3.fromRGB(255, 255, 255); toggleLabel.TextSize = 12; toggleLabel.TextXAlignment = Enum.TextXAlignment.Left; toggleLabel.Font = Enum.Font.SourceSans
        local switch = Instance.new("TextButton", toggleFrame); switch.Name = "Switch"; switch.Size = UDim2.new(0, 40, 0, 20); switch.Position = UDim2.new(1, -50, 0.5, -10); switch.BackgroundColor3 = Color3.fromRGB(50, 50, 50); switch.BorderSizePixel = 0; switch.Text = ""; local switchCorner = Instance.new("UICorner", switch); switchCorner.CornerRadius = UDim.new(1, 0)
        local thumb = Instance.new("Frame", switch); thumb.Name = "Thumb"; thumb.Size = UDim2.new(0, 16, 0, 16); thumb.Position = UDim2.new(0, 2, 0.5, -8); thumb.BackgroundColor3 = Color3.fromRGB(220, 220, 220); thumb.BorderSizePixel = 0; local thumbCorner = Instance.new("UICorner", thumb); thumbCorner.CornerRadius = UDim.new(1, 0)
        local onColor, offColor = Color3.fromRGB(0, 150, 255), Color3.fromRGB(60, 60, 60); local onPosition, offPosition = UDim2.new(1, -18, 0.5, -8), UDim2.new(0, 2, 0.5, -8); local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out); local isToggled = initialState
        local function updateVisuals(isInstant) local goalPosition, goalColor = isToggled and onPosition or offPosition, isToggled and onColor or offColor; if isInstant then thumb.Position, switch.BackgroundColor3 = goalPosition, goalColor else TweenService:Create(thumb, tweenInfo, {Position = goalPosition}):Play(); TweenService:Create(switch, tweenInfo, {BackgroundColor3 = goalColor}):Play() end end
        switch.MouseButton1Click:Connect(function() isToggled = not isToggled; updateVisuals(false); callback(isToggled) end); updateVisuals(true)
        return toggleFrame, switch
    end

    local function setupOptimizedGameToggle()
        local mainGui = CoreGui:FindFirstChild("ArexanstoolsGUI")
        if not mainGui then return end
        local settingsTab = mainGui:FindFirstChild("SettingsTab", true)
        if not settingsTab then return end

        local toggleFrame, switch = createToggle(settingsTab, "Optimized Game", IsOptimizedGameEnabled, function(state)
            IsOptimizedGameEnabled = state
            if state then
                scanAndDisableHeavyObjects()
            else
                restoreHeavyObjects()
            end
        end)
        toggleFrame.LayoutOrder = 8 -- Place it after the default items
    end

    task.wait(1)
    setupOptimizedGameToggle()
end)

-- =========================================================
-- ========== AKHIR FITUR ANTI LAG MODE (VERSI B) ==========
-- =========================================================



-- =========================
-- Arexans Tools — Patch v2 (Safe template for Roblox Studio)
-- Adds:
-- 1) "Dark Texture" toggle in Settings tab placed below Boost FPS (best-effort)
-- NOTE: This script is intended as a Studio/local script template. It performs only in-game changes
-- under the authority of the place/server and is designed to be reversible and temporary.
-- =========================

task.spawn(function()
    local CoreGui = game:GetService("CoreGui")
    local Players = game:GetService("Players")
    local Lighting = game:GetService("Lighting")
    local RunService = game:GetService("RunService")
    local Workspace = game:GetService("Workspace")
    local Terrain = Workspace:FindFirstChildOfClass("Terrain")
    local CollectionService = game:GetService("CollectionService")
    local TweenService = game:GetService("TweenService")

    local function waitForMainGui(timeout)
        timeout = timeout or 10
        local elapsed = 0
        while elapsed < timeout do
            local gui = CoreGui:FindFirstChild("ArexanstoolsGUI")
            if gui then return gui end
            task.wait(0.1)
            elapsed = elapsed + 0.1
        end
        return CoreGui:FindFirstChild("ArexanstoolsGUI")
    end

    local gui = waitForMainGui(10)
    if not gui then
        warn("[ArexansPatchV2] ArexanstoolsGUI not found; aborting patch injection.")
        return
    end

    local settingsTab = nil
    pcall(function()
        settingsTab = gui.MainFrame and gui.MainFrame.ContentFrame and gui.MainFrame.ContentFrame:FindFirstChild("SettingsTab")
    end)
    if not settingsTab then
        -- fallback: find by name anywhere
        for _,v in pairs(gui:GetDescendants()) do
            if v.Name == "SettingsTab" then settingsTab = v; break end
        end
    end
    if not settingsTab then
        warn("[ArexansPatchV2] SettingsTab not found; toggles will not be injected.")
        return
    end

    -- Helper for creating a toggle switch
    local function createToggle(parent, name, initialState, callback)
        local toggleFrame = Instance.new("Frame", parent); toggleFrame.Size = UDim2.new(1, 0, 0, 25); toggleFrame.BackgroundTransparency = 1; local toggleLabel = Instance.new("TextLabel", toggleFrame); toggleLabel.Size = UDim2.new(0.8, -10, 1, 0); toggleLabel.Position = UDim2.new(0, 5, 0, 0); toggleLabel.BackgroundTransparency = 1; toggleLabel.Text = name; toggleLabel.TextColor3 = Color3.fromRGB(255, 255, 255); toggleLabel.TextSize = 12; toggleLabel.TextXAlignment = Enum.TextXAlignment.Left; toggleLabel.Font = Enum.Font.SourceSans
        local switch = Instance.new("TextButton", toggleFrame); switch.Name = "Switch"; switch.Size = UDim2.new(0, 40, 0, 20); switch.Position = UDim2.new(1, -50, 0.5, -10); switch.BackgroundColor3 = Color3.fromRGB(50, 50, 50); switch.BorderSizePixel = 0; switch.Text = ""; local switchCorner = Instance.new("UICorner", switch); switchCorner.CornerRadius = UDim.new(1, 0)
        local thumb = Instance.new("Frame", switch); thumb.Name = "Thumb"; thumb.Size = UDim2.new(0, 16, 0, 16); thumb.Position = UDim2.new(0, 2, 0.5, -8); thumb.BackgroundColor3 = Color3.fromRGB(220, 220, 220); thumb.BorderSizePixel = 0; local thumbCorner = Instance.new("UICorner", thumb); thumbCorner.CornerRadius = UDim.new(1, 0)
        local onColor, offColor = Color3.fromRGB(0, 150, 255), Color3.fromRGB(60, 60, 60); local onPosition, offPosition = UDim2.new(1, -18, 0.5, -8), UDim2.new(0, 2, 0.5, -8); local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out); local isToggled = initialState
        local function updateVisuals(isInstant) local goalPosition, goalColor = isToggled and onPosition or offPosition, isToggled and onColor or offColor; if isInstant then thumb.Position, switch.BackgroundColor3 = goalPosition, goalColor else TweenService:Create(thumb, tweenInfo, {Position = goalPosition}):Play(); TweenService:Create(switch, tweenInfo, {BackgroundColor3 = goalColor}):Play() end end
        switch.MouseButton1Click:Connect(function() isToggled = not isToggled; updateVisuals(false); callback(isToggled) end); updateVisuals(true)
        return toggleFrame, switch
    end

    -- Storage for originals to restore
    local originalLighting = {}
    local originalSky = nil
    local originalEffects = {}
    local partOriginals = setmetatable({}, {__mode = "k"}) -- weak keys
    local modifiedParts = {}

    -- Deep-save function for parts/instances
    local function saveInstanceOriginal(inst)
        if not inst or partOriginals[inst] then return end
        local ok, data = pcall(function()
            local d = {}
            if inst:IsA("BasePart") then
                d.Color = inst.Color
                d.Material = inst.Material
                d.Transparency = inst.Transparency
                d.Reflectance = inst.Reflectance
                d.LocalTransparencyModifier = inst.LocalTransparencyModifier and inst.LocalTransparencyModifier or nil
            end
            if inst:IsA("Decal") or inst:IsA("Texture") then
                d.Texture = inst.Texture
            end
            if inst:IsA("ParticleEmitter") then
                d.Enabled = inst.Enabled
            end
            if inst:IsA("MeshPart") then
                d.MeshId = inst.MeshId
                d.TextureID = inst.TextureID
            end
            return d
        end)
        if ok then partOriginals[inst] = data end
    end

    local function applyTotallyGray(inst)
        if not inst then return end
        pcall(function()
            if inst:IsA("BasePart") then
                saveInstanceOriginal(inst)
                inst.Color = Color3.fromRGB(128,128,128)
                inst.Material = Enum.Material.SmoothPlastic
                inst.Transparency = 0
                inst.Reflectance = 0
            elseif inst:IsA("MeshPart") then
                saveInstanceOriginal(inst)
                inst.Color = Color3.fromRGB(128,128,128)
                inst.Material = Enum.Material.SmoothPlastic
                inst.TextureID = ""
            elseif inst:IsA("Decal") or inst:IsA("Texture") then
                saveInstanceOriginal(inst)
                inst.Texture = ""
            elseif inst:IsA("ParticleEmitter") then
                saveInstanceOriginal(inst)
                inst.Enabled = false
            end
            modifiedParts[inst] = true
        end)
    end

    local function restoreInstance(inst)
        if not inst then return end
        local data = partOriginals[inst]
        if not data then return end
        pcall(function()
            if inst:IsA("BasePart") then
                if data.Color then inst.Color = data.Color end
                if data.Material then inst.Material = data.Material end
                if data.Transparency then inst.Transparency = data.Transparency end
                if data.Reflectance then inst.Reflectance = data.Reflectance end
            end
            if inst:IsA("MeshPart") then
                if data.MeshId then inst.MeshId = data.MeshId end
                if data.TextureID then inst.TextureID = data.TextureID end
            end
            if inst:IsA("Decal") or inst:IsA("Texture") then
                if data.Texture then inst.Texture = data.Texture end
            end
            if inst:IsA("ParticleEmitter") then
                if data.Enabled ~= nil then inst.Enabled = data.Enabled end
            end
        end)
        partOriginals[inst] = nil
        modifiedParts[inst] = nil
    end

    -- Apply total gray to workspace, players, terrain, sky, and effects
    local darkActive = false
    local function applyDarkTotal()
        if darkActive then return end
        darkActive = true
        -- Save lighting & effects
        pcall(function()
            originalLighting.Ambient = Lighting.Ambient
            originalLighting.OutdoorAmbient = Lighting.OutdoorAmbient
            originalLighting.Brightness = Lighting.Brightness
            originalLighting.GlobalShadows = Lighting.GlobalShadows
            -- Save post process effects
            for _, eff in ipairs(Lighting:GetChildren()) do
                if eff:IsA("Atmosphere") or eff:IsA("Sky") or eff:IsA("ColorCorrectionEffect") or eff:IsA("BloomEffect") or eff:IsA("SunRaysEffect") or eff:IsA("DepthOfFieldEffect") or eff:IsA("BlurEffect") then
                    originalEffects[eff] = eff:Clone()
                end
            end
            originalSky = Lighting:FindFirstChildOfClass("Sky")
            Lighting.Ambient = Color3.fromRGB(128,128,128)
            Lighting.OutdoorAmbient = Color3.fromRGB(128,128,128)
            Lighting.Brightness = 1
            Lighting.GlobalShadows = false
            -- Remove/neutralize post-processing to gray
            for _, eff in ipairs(Lighting:GetChildren()) do
                if eff:IsA("ColorCorrectionEffect") then
                    eff.Saturation = -1
                    eff.TintColor = Color3.fromRGB(128,128,128)
                elseif eff:IsA("BloomEffect") then
                    eff.Intensity = 0
                elseif eff:IsA("SunRaysEffect") then
                    eff.Intensity = 0
                elseif eff:IsA("DepthOfFieldEffect") then
                    eff.InFocusRadius = 10000
                elseif eff:IsA("BlurEffect") then
                    eff.Size = 0
                elseif eff:IsA("Atmosphere") then
                    eff.Density = 0
                elseif eff:IsA("Sky") then
                    -- optional: clear sky textures by replacing with neutral sky
                    -- clone a simple gray sky
                    pcall(function()
                        eff.SkyboxBk = ""
                        eff.SkyboxDn = ""
                        eff.SkyboxFt = ""
                        eff.SkyboxLf = ""
                        eff.SkyboxRt = ""
                        eff.SkyboxUp = ""
                    end)
                end
            end
        end)

        -- Terrain adjustments (water and materials)
        if Terrain then
            pcall(function()
                -- save some properties if exist
                originalLighting.TerrainWaterColor = Terrain.WaterColor
                originalLighting.TerrainWaterTransparency = Terrain.WaterTransparency
                Terrain.WaterColor = Color3.fromRGB(128,128,128)
                Terrain.WaterTransparency = 0.5
            end)
        end

        -- Iterate all descendants and apply gray
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("Decal") or obj:IsA("Texture") or obj:IsA("ParticleEmitter") then
                applyTotallyGray(obj)
            elseif obj:IsA("Model") then
                -- handle model children in descendants loop
            elseif obj:IsA("Accessory") then
                local handle = obj:FindFirstChild("Handle")
                if handle then applyTotallyGray(handle) end
            end
        end

        -- Characters
        for _, pl in ipairs(Players:GetPlayers()) do
            local char = pl.Character
            if char then
                for _, d in ipairs(char:GetDescendants()) do
                    if d:IsA("BasePart") or d:IsA("MeshPart") or d:IsA("Decal") or d:IsA("Texture") or d:IsA("ParticleEmitter") then
                        applyTotallyGray(d)
                    end
                end
            end
        end
    end

    local function restoreDarkTotal()
        if not darkActive then return end
        darkActive = false
        -- restore modified instances
        for inst, _ in pairs(modifiedParts) do
            if inst and inst.Parent then
                pcall(function() restoreInstance(inst) end)
            end
        end
        -- restore lighting/effects
        pcall(function()
            if originalLighting.Ambient then Lighting.Ambient = originalLighting.Ambient end
            if originalLighting.OutdoorAmbient then Lighting.OutdoorAmbient = originalLighting.OutdoorAmbient end
            if originalLighting.Brightness then Lighting.Brightness = originalLighting.Brightness end
            if originalLighting.GlobalShadows ~= nil then Lighting.GlobalShadows = originalLighting.GlobalShadows end
            if Terrain and originalLighting.TerrainWaterColor then
                Terrain.WaterColor = originalLighting.TerrainWaterColor
                Terrain.WaterTransparency = originalLighting.TerrainWaterTransparency or Terrain.WaterTransparency
            end
            -- restore cloned effects
            for origEff, cloneEff in pairs(originalEffects) do
                if origEff and origEff.Parent then
                    -- attempt to restore properties by copying fields from clone
                    local suc, _ = pcall(function()
                        for _, prop in ipairs({"Brightness","Intensity","Saturation","TintColor","Size","Density","InFocusRadius"}) do
                            if cloneEff[prop] ~= nil and origEff[prop] ~= nil then
                                origEff[prop] = cloneEff[prop]
                            end
                        end
                    end)
                end
            end
            originalEffects = {}
        end)
        partOriginals = setmetatable({}, {__mode = "k"})
        modifiedParts = {}
    end

    -- Find approximate position: try to place toggles below Boost FPS toggle if present
    local function findBoostFpsLayoutOrder(parent)
        for i, child in ipairs(parent:GetChildren()) do
            if child:IsA("Frame") then
                local label = child:FindFirstChildOfClass("TextLabel")
                if label and string.lower(label.Text or ""):find("boost fps") then
                    return child.LayoutOrder
                end
            end
        end
        return nil
    end

    -- Place Dark Texture under Boost FPS if possible
    local darkContainer, darkSwitch = createToggle(settingsTab, "Dark Texture", false, function(state)
        if state then applyDarkTotal() else restoreDarkTotal() end
    end)

    darkContainer.LayoutOrder = 7

    -- Cleanup on GUI removal or game close
    local function cleanup()
        restoreDarkTotal()
    end

    settingsTab.AncestryChanged:Connect(function(_, parent)
        if not parent then cleanup() end
    end)

end)




-- =========================


-- ======= APPENDED: emote.lua START =======
-- End of merged file


----------------------------------------------------
-- ⚡ PATCH: Toggleable Safe Touch Fling v3.0
-- Fitur fling hanya aktif saat ON dan tidak melempar karakter lokal.
----------------------------------------------------
do
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local IsTouchFlingEnabled = false
    local activeConns = {}

    local function cleanup()
        for _, conn in ipairs(activeConns) do
            if conn and typeof(conn.Disconnect) == "function" then
                pcall(function() conn:Disconnect() end)
            end
        end
        activeConns = {}
    end

    local function flingTarget(targetRoot)
        if not (targetRoot and targetRoot.Parent) then return end
        local BV = Instance.new("BodyVelocity")
        BV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        BV.P = 1e6
        BV.Velocity = Vector3.new(
            math.random(-7e5, 7e5),
            math.random(9e5, 1.2e6),
            math.random(-7e5, 7e5)
        )
        BV.Parent = targetRoot
        task.delay(0.12, function()
            if BV and BV.Parent then BV:Destroy() end
        end)
    end

    local function enableTouchFling(character)
        if not character then return end
        cleanup()
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                local conn = part.Touched:Connect(function(hit)
                    if not IsTouchFlingEnabled then return end
                    local hitParent = hit.Parent
                    if not hitParent or hitParent == character then return end
                    local targetHumanoid = hitParent:FindFirstChildOfClass("Humanoid")
                    local targetRoot = hitParent:FindFirstChild("HumanoidRootPart")
                    if targetHumanoid and targetRoot then
                        flingTarget(targetRoot)
                    end
                end)
                table.insert(activeConns, conn)
            end
        end
    end

    local function toggleTouchFling(state)
        IsTouchFlingEnabled = state
        if state then
            local char = LocalPlayer.Character
            if char then enableTouchFling(char) end
        else
            cleanup()
        end
    end

    Players.LocalPlayer.CharacterAdded:Connect(function(char)
        task.wait(1)
        if IsTouchFlingEnabled then enableTouchFling(char) end
    end)

    -- Integrasi ke GUI utama (opsional, tombol toggle)
    if _G.CreateArexansButton then
        _G.CreateArexansButton("Touch Fling", function(isOn)
            toggleTouchFling(isOn)
        end)
    end

    -- Untuk kompatibilitas manual (jika GUI belum ada)
    _G.ToggleTouchFling = toggleTouchFling
end
----------------------------------------------------




-- ✅ PATCH v4: Touch Fling Full Body Detection Fix (Robust)
-- Perbaikan tambahan:
-- 1) Menggunakan posisi part yang menyentuh (hit.Position) vs part lokal untuk arah yang lebih akurat (khusus telapak kaki R15).
-- 2) Meng-attach listener ke descendant yang baru ditambahkan saat respawn.
-- 3) Membersihkan koneksi dengan aman saat dimatikan atau karakter respawn.
-- 4) Memeriksa dan mengabaikan non-collidable parts (CanCollide=false) untuk mengurangi false positives.
do
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local RunService = game:GetService("RunService")

    local flingConnections = {}
    local characterConnections = {}
    local isTouchFlingEnabled = false

    local function disconnectAll(list)
        for _, conn in ipairs(list) do
            pcall(function() if conn and conn.Disconnect then conn:Disconnect() end end)
        end
        table.clear(list)
    end

    local function onPartTouched(part, hit)
        -- Validasi
        if not (part and hit) then return end
        -- Abaikan jika hit adalah bagian dari diri sendiri
        local hitModel = hit:FindFirstAncestorOfClass("Model")
        if hitModel and hitModel == LocalPlayer.Character then return end

        -- Cari humanoid target
        local targetModel = hit:FindFirstAncestorOfClass("Model")
        if not targetModel then return end
        local targetHum = targetModel:FindFirstChildOfClass("Humanoid")
        if not targetHum or targetHum.Health <= 0 then return end

        -- Abaikan parts yang tidak bisa bertabrakan
        if not hit.CanCollide and not hit:IsA("Terrain") then return end

        -- Dapatkan HumanoidRootPart target (fallback ke posisi hit jika tidak ditemukan)
        local tRoot = targetModel:FindFirstChild("HumanoidRootPart") or targetModel:FindFirstChild("Torso") or targetModel:FindFirstChild("UpperTorso") or nil
        -- Dapatkan root kita
        local myChar = LocalPlayer.Character
        if not myChar then return end
        local myRoot = myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Torso") or myChar:FindFirstChild("UpperTorso")
        if not myRoot then return end

        -- Hit position (lebih akurat untuk telapak kaki)
        local hitPos = hit.Position
        local sourcePos = part.Position

        -- Hitung arah berdasarkan posisi part yang menyentuh ke posisi hit (detail untuk kaki)
        local ok, dir = pcall(function() return ( (hitPos - sourcePos).Unit ) end)
        if not ok or not dir or dir.Magnitude == 0 then
            -- fallback ke root-to-root
            if tRoot and myRoot then
                dir = (tRoot.Position - myRoot.Position).Unit
            else
                return
            end
        end

        -- Tetap pakai gaya fling lama: set AssemblyLinearVelocity pada HumanoidRootPart target
        if tRoot and tRoot:IsA("BasePart") then
            pcall(function()
                -- gunakan kekuatan yang sama seperti implementasi sebelumnya
                local flingForce = dir * 200 + Vector3.new(0, 120, 0)
                tRoot.AssemblyLinearVelocity = flingForce
            end)
        end
    end

    local function attachToPart(part)
        if not (part and part:IsA("BasePart")) then return end
        -- Pastikan tidak duplicate: gunakan attribute untuk menandai sudah terpasang
        if part:GetAttribute("TouchFlingAttached") then return end
        part:SetAttribute("TouchFlingAttached", true)
        local conn = part.Touched:Connect(function(hit) 
            -- Only process when feature is enabled
            if isTouchFlingEnabled then
                onPartTouched(part, hit) 
            end
        end)
        table.insert(flingConnections, conn)
    end

    local function attachToCharacterParts(character)
        if not character then return end
        -- Attach to current BaseParts
        for _, child in ipairs(character:GetDescendants()) do
            if child:IsA("BasePart") then
                attachToPart(child)
            end
        end
        -- Listen for parts added later (accessories, respawned parts)
        local cconn = character.DescendantAdded:Connect(function(desc)
            if desc:IsA("BasePart") then
                -- Delay kecil agar properti seperti CanCollide sudah terset
                task.delay(0.02, function() attachToPart(desc) end)
            end
        end)
        table.insert(characterConnections, cconn)
    end

    local function onCharacterAdded(char)
        -- Bersihkan koneksi sebelumnya
        disconnectAll(flingConnections)
        disconnectAll(characterConnections)
        -- reset attributes agar bisa dipasang ulang
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then pcall(function() part:SetAttribute("TouchFlingAttached", false) end) end
        end
        attachToCharacterParts(char)
    end

    function EnableTouchFlingFullBody()
        isTouchFlingEnabled = true
        -- disconnect sebelumnya untuk mencegah duplikat
        disconnectAll(flingConnections)
        disconnectAll(characterConnections)
        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
        attachToCharacterParts(char)
        -- juga reconnect saat respawn
        local conn = LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
        table.insert(characterConnections, conn)
    end

    function DisableTouchFlingFullBody()
        isTouchFlingEnabled = false
        disconnectAll(flingConnections)
        disconnectAll(characterConnections)
    end
end
-- ✅ END PATCH v4
