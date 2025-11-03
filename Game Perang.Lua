--[[
    Skrip Gabungan: lockaim.lua + cit.lua (Versi Mini & Scrollable)
    Deskripsi: Mengubah ukuran kepala, ESP, dan Aimbot dalam jendela mini yang dapat digulir.
    UI Theme terinspirasi dari Arexanstools.lua
    Aimbot & FOV logic oleh r5nd0m_us3r0 dan goofyahh_aleksandr
    
    PERUBAHAN (Oleh AI):
    - ... (Perubahan sebelumnya)
    - PERUBAHAN (v15): [PERBAIKAN] FOV (Lingkaran) sekarang hanya terlihat jika AimbotEnabled DAN ShowFOV keduanya true.
    - PERUBAHAN (v15): [DIKEMBALIKAN] Memanggil DrawCrosshair() sekali di dalam toggle callback
                        untuk membuatnya "langsung aktif" atau "langsung nonaktif" saat di-klik.
    - PERUBAHAN (v16): [PERBAIKAN] Menghapus panggilan DrawCrosshair() dari dalam toggle callback (perbaikan v15).
                        Loop RenderStepped utama adalah satu-satunya yang bertanggung jawab untuk menggambar
                        crosshair, memastikan tidak ada konflik.
]]

-- Services
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService") -- [DITAMBAHKAN v9] Diperlukan untuk menyimpan GUI
local Camera = workspace.CurrentCamera

-- Local Player
local LocalPlayer = Players.LocalPlayer

-- [BARU v9] Variabel path file untuk menyimpan posisi GUI
local SAVE_FOLDER = "GamePerang"
if isfolder and not isfolder(SAVE_FOLDER) then
    pcall(makefolder, SAVE_FOLDER)
end
local GUI_POSITIONS_SAVE_FILE = SAVE_FOLDER .. "/GuiPositions.json"
local loadedGuiPositions = nil -- Cache untuk posisi yang dimuat
local MainFrame -- Deklarasi awal untuk MainFrame agar bisa diakses oleh loadGuiPositions

--====================================================================--
--                           PENGATURAN FITUR                         --
--====================================================================--

-- Pengaturan Head Size (dari aimlock.lua)
local isHeadSizeActive = false
local originalHeadSizes = {} -- Store original props { [Player] = {Size, Massless, CanTouch, CanCollide} }
local currentTarget = "All"
local currentSize = 3
local headSizeLoopConnection = nil

-- Pengaturan ESP (DIIMPOR DARI esp.lua)
local IsEspNameEnabled = false
local IsEspBodyEnabled = false
local IsEspLineEnabled = false
local IsEspHealthBarEnabled = false -- TOGGLE BARU UNTUK HEALTH BAR
local isMasterEspEnabled = false -- <<<< [BARU] TOGGLE MASTER UNTUK SEMUA ESP
local EspRenderConnection = nil
local espCache = {} -- Cache untuk elemen GUI ESP
-- [BARU v8] Variabel warna yang dapat disesuaikan
local teamColor = Color3.fromRGB(0, 150, 255) -- BIRU (Kawan)
local enemyColor = Color3.fromRGB(255, 100, 100) -- MERAH (Musuh)


-- Pengaturan Aimbot (dari cit.lua)
local AimbotEnabled = false
local WallCheck = true
-- local TeamCheck = false -- <<< DIHAPUS (Sekarang otomatis)
local ShowFOV = true
local AimPart = "Head"
local FOV = 150
local Smoothness = 0.2
local AimbotRenderConnection = nil

-- [BARU v13] Pengaturan Crosshair
local isCrosshairEnabled = false
local currentCrosshairType = 1 -- 1=Dot, 2=Cross, 3=Dot+Cross, 4=Open, 5=X
local crosshairColor = Color3.fromRGB(0, 255, 0)
local crosshairSize = 15 -- Ukuran dasar untuk crosshair
local crosshairThickness = 2
local crosshairTransparency = 0 -- [PERBAIKAN v14] 0=Solid, 1=Transparan


--====================================================================--
--                          ELEMEN DRAWING (FOV & CROSSHAIR)          --
--====================================================================--
local FOVCircle = nil
local crosshairElements = {} -- Tabel untuk menyimpan semua elemen crosshair
local crosshairTypes = {"Titik", "Silang", "Silang + Titik", "Terbuka", "X"}

if Drawing then -- Memeriksa apakah pustaka 'Drawing' ada
    -- 1. LINGKARAN FOV (cit.lua)
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Thickness = 1
    FOVCircle.NumSides = 100
    FOVCircle.Radius = FOV
    FOVCircle.Filled = false
    FOVCircle.Transparency = 0.8
    FOVCircle.Color = Color3.fromRGB(0, 255, 0)
    FOVCircle.Visible = ShowFOV
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    -- 2. [BARU v13] ELEMEN CROSSHAIR
    -- Buat semua elemen yang mungkin diperlukan, lalu simpan di tabel
    
    -- Tipe 1 & 3: Titik
    local chDot = Drawing.new("Circle")
    chDot.Filled = true
    chDot.Radius = 3
    chDot.Visible = false
    table.insert(crosshairElements, chDot)

    -- Tipe 2 & 3: Silang Sederhana
    local chLineH = Drawing.new("Line") -- Horizontal
    chLineH.Visible = false
    table.insert(crosshairElements, chLineH)
    local chLineV = Drawing.new("Line") -- Vertikal
    chLineV.Visible = false
    table.insert(crosshairElements, chLineV)

    -- Tipe 4: Terbuka (4 Garis)
    local chLineT = Drawing.new("Line") -- Top
    chLineT.Visible = false
    table.insert(crosshairElements, chLineT)
    local chLineB = Drawing.new("Line") -- Bottom
    chLineB.Visible = false
    table.insert(crosshairElements, chLineB)
    local chLineL = Drawing.new("Line") -- Left
    chLineL.Visible = false
    table.insert(crosshairElements, chLineL)
    local chLineR = Drawing.new("Line") -- Right
    chLineR.Visible = false
    table.insert(crosshairElements, chLineR)

    -- Tipe 5: X (2 Garis Diagonal)
    local chLineD1 = Drawing.new("Line") -- Diagonal 1
    chLineD1.Visible = false
    table.insert(crosshairElements, chLineD1)
    local chLineD2 = Drawing.new("Line") -- Diagonal 2
    chLineD2.Visible = false
    table.insert(crosshairElements, chLineD2)

else
    print("Peringatan: Pustaka 'Drawing' tidak ditemukan. Lingkaran FOV dan Crosshair akan dinonaktifkan.")
    ShowFOV = false -- Paksa nonaktifkan jika tidak ada library
end

--====================================================================--
--                        FUNGSI LOGIKA AIMBOT (cit.lua)              --
--====================================================================--

--// GET CLOSEST TARGET
local function GetClosestPlayer()
    local closestPart = nil
    local shortestDistance = FOV

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(AimPart) then
            local part = player.Character[AimPart]
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                
                -- [PERUBAHAN v3] Logika TeamCheck otomatis diaktifkan. Hanya target musuh.
                -- Aimbot tetap menggunakan 'Player.Team' karena lebih aman untuk tidak mengunci tim
                if player.Team ~= LocalPlayer.Team then 
                    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)).Magnitude
                        if dist < shortestDistance then
                            if not WallCheck or #Camera:GetPartsObscuringTarget({part.Position}, {LocalPlayer.Character, player.Character}) == 0 then
                                closestPart = part
                                shortestDistance = dist
                            end
                        end
                    end
                end
            end
        end
    end

    return closestPart
end

--// SMOOTH AIM
local function SmoothLookAt(targetPos)
    local camCF = Camera.CFrame
    local newCF = CFrame.new(camCF.Position, targetPos)
    Camera.CFrame = camCF:Lerp(newCF, Smoothness)
end

--====================================================================--
--                           FUNGSI HELPER (aimlock.lua)              --
--====================================================================--

-- [BARU v9] Fungsi untuk menyimpan/memuat posisi/ukuran GUI
-- Diletakkan di sini agar bisa diakses oleh MakeDraggable
local function saveGuiPositions()
    if not writefile or not MainFrame or not MainFrame.Parent then
        return
    end

    local guiDataToSave = {
        MainFrame = {
            XScale = MainFrame.Position.X.Scale,
            XOffset = MainFrame.Position.X.Offset,
            YScale = MainFrame.Position.Y.Scale,
            YOffset = MainFrame.Position.Y.Offset,
            SizeX = MainFrame.Size.X.Offset,
            SizeY = MainFrame.Size.Y.Offset
        }
    }

    pcall(function()
        local jsonData = HttpService:JSONEncode(guiDataToSave)
        writefile(GUI_POSITIONS_SAVE_FILE, jsonData)
    end)
end

local function loadGuiPositions()
    if not readfile or not isfile or not isfile(GUI_POSITIONS_SAVE_FILE) then
        return
    end

    local success, result = pcall(function()
        local fileContent = readfile(GUI_POSITIONS_SAVE_FILE)
        loadedGuiPositions = HttpService:JSONDecode(fileContent)

        -- Terapkan data yang dimuat ke MainFrame
        if MainFrame and MainFrame.Parent and loadedGuiPositions and loadedGuiPositions.MainFrame then
            local data = loadedGuiPositions.MainFrame
            MainFrame.Position = UDim2.new(data.XScale, data.XOffset, data.YScale, data.YOffset)
            -- Terapkan ukuran HANYA jika disimpan (tambahkan min size clamp)
            if data.SizeX and data.SizeY then
                MainFrame.Size = UDim2.new(0, math.max(180, data.SizeX), 0, math.max(220, data.SizeY))
            end
        end
    end)
    
    if not success then
        warn("Gagal memuat posisi GUI:", result)
        loadedGuiPositions = nil
    end
end


-- Fungsi untuk mendapatkan pemain berdasarkan input
-- [PERUBAHAN v7] Fungsi ini tidak lagi digunakan oleh loop Heartbeat,
-- namun tetap dipertahankan jika 'applyHeadSize' dipanggil dari tempat lain (mis. UI)
local function getPlayer(targetName)
    local foundPlayers = {}
    if not targetName or targetName == "" then return {} end -- Handle empty input
    targetName = targetName:lower()

    if targetName == "all" then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                 table.insert(foundPlayers, player)
            end
        end
     elseif targetName == "others" then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                 table.insert(foundPlayers, player)
            end
        end
    elseif targetName == "me" then
         table.insert(foundPlayers, LocalPlayer) -- Specifically include local player if "me"
    else
        for _, player in ipairs(Players:GetPlayers()) do
            if player.Name:lower():find(targetName, 1, true) or player.DisplayName:lower():find(targetName, 1, true) then
                table.insert(foundPlayers, player)
            end
        end
    end
    return foundPlayers
end


-- Fungsi untuk membuat UI draggable (DISEDERHANAKAN & DIPERBAIKI)
local function MakeDraggable(guiObject, dragHandle)
    local dragging = false
    local dragStart = nil
    local startPos = nil

    local moveConnection = nil
    local releaseConnection = nil

    dragHandle.InputBegan:Connect(function(input)
        -- Hanya proses klik kiri mouse atau sentuhan
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = guiObject.Position
            guiObject.ZIndex = 99 -- Bawa ke depan saat di-drag

            -- Putuskan koneksi lama jika ada
            if moveConnection then moveConnection:Disconnect() end
            if releaseConnection then releaseConnection:Disconnect() end

            -- Koneksi untuk memantau pergerakan
            moveConnection = UserInputService.InputChanged:Connect(function(moveInput)
                if dragging and (moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch) then
                    local delta = moveInput.Position - dragStart
                    guiObject.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                end
            end)

            -- Koneksi untuk mendeteksi akhir drag (lepas klik atau lepas sentuhan)
            releaseConnection = UserInputService.InputEnded:Connect(function(endInput)
                -- Periksa apakah input yang berakhir adalah tipe yang sama dengan yang memulai
                if endInput.UserInputType == input.UserInputType then
                    dragging = false
                    guiObject.ZIndex = 10 -- Kembalikan ZIndex normal
                    
                    saveGuiPositions() -- [BARU v9] Simpan posisi setelah di-drag

                    -- Putuskan koneksi
                    if moveConnection then moveConnection:Disconnect(); moveConnection = nil end
                    if releaseConnection then releaseConnection:Disconnect(); releaseConnection = nil end
                end
            end)
        end
    end)
end

-- Fungsi untuk membuat Toggle Switch (Gaya ArexansTools)
local function createToggleSwitch(parent, labelText, initialState, callback)
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = labelText:gsub("%s+", "") .. "ToggleFrame"
    toggleFrame.Size = UDim2.new(1, 0, 0, 25)
    toggleFrame.BackgroundTransparency = 1
    toggleFrame.Parent = parent

    local featureLabel = Instance.new("TextLabel")
    featureLabel.Name = "FeatureLabel"
    featureLabel.Size = UDim2.new(0.7, -5, 1, 0) -- Adjust size to make space for switch
    featureLabel.Position = UDim2.new(0, 0, 0, 0)
    featureLabel.BackgroundTransparency = 1
    featureLabel.Text = labelText .. ":"
    featureLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
    featureLabel.TextSize = 11 -- <<< (MINI) Font diperkecil
    featureLabel.TextXAlignment = Enum.TextXAlignment.Left
    featureLabel.Font = Enum.Font.SourceSans
    featureLabel.Parent = toggleFrame

    local switchTrack = Instance.new("TextButton")
    switchTrack.Name = "SwitchTrack"
    switchTrack.Size = UDim2.new(0, 40, 0, 20)
    switchTrack.Position = UDim2.new(1, -45, 0.5, -10) -- Position to the right
    switchTrack.BackgroundColor3 = Color3.fromRGB(60, 60, 60) -- Off color
    switchTrack.BorderSizePixel = 0
    switchTrack.Text = ""
    switchTrack.AutoButtonColor = false
    switchTrack.Parent = toggleFrame
    local switchCorner = Instance.new("UICorner", switchTrack)
    switchCorner.CornerRadius = UDim.new(1, 0) -- Fully rounded

    local switchThumb = Instance.new("Frame")
    switchThumb.Name = "SwitchThumb"
    switchThumb.Size = UDim2.new(0, 16, 0, 16)
    switchThumb.Position = UDim2.new(0, 2, 0.5, -8) -- Initial off position
    switchThumb.BackgroundColor3 = Color3.fromRGB(220, 220, 220) -- Thumb color
    switchThumb.BorderSizePixel = 0
    switchThumb.Parent = switchTrack
    local thumbCorner = Instance.new("UICorner", switchThumb)
    thumbCorner.CornerRadius = UDim.new(1, 0) -- Fully rounded

    local onColor = Color3.fromRGB(0, 150, 255) -- Blue for ON
    local offColor = Color3.fromRGB(60, 60, 60) -- Dark gray for OFF
    local onPosition = UDim2.new(1, -18, 0.5, -8) -- Thumb position when ON
    local offPosition = UDim2.new(0, 2, 0.5, -8) -- Thumb position when OFF
    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
    local isToggled = initialState or false

    local function updateVisuals(isOn, isInstant)
        local goalPosition = isOn and onPosition or offPosition
        local goalColor = isOn and onColor or offColor
        if isInstant then
            switchThumb.Position = goalPosition
            switchTrack.BackgroundColor3 = goalColor
        else
            TweenService:Create(switchThumb, tweenInfo, {Position = goalPosition}):Play()
            TweenService:Create(switchTrack, tweenInfo, {BackgroundColor3 = goalColor}):Play()
        end
    end

    switchTrack.MouseButton1Click:Connect(function()
        isToggled = not isToggled
        updateVisuals(isToggled, false)
        if callback then
            callback(isToggled)
        end
    end)

    -- Set initial visual state
    updateVisuals(isToggled, true)

    -- Return the frame and a function to manually set state if needed
    return toggleFrame, function(newState)
        if isToggled ~= newState then
            isToggled = newState
            updateVisuals(isToggled, true)
            -- Note: This manual update does NOT call the callback
        end
    end
end

-- [BARU v8] Helper functions untuk Color Picker (diambil dari jsos-ksosis9eosjsos!1ks.lua)
local function createHueSlider(parent, label, initialVal, callback)
    local sliderHeight = 16
    local thumbSize = 16
    local minVal, maxVal = 0, 1
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, -10, 0, 30)
    frame.Position = UDim2.new(0, 5, 0, 0)
    frame.BackgroundTransparency = 1
    local textLabel = Instance.new("TextLabel", frame)
    textLabel.Size = UDim2.new(0, 20, 1, 0)
    textLabel.Position = UDim2.new(0, 0, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = label
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextSize = 12
    textLabel.Font = Enum.Font.SourceSans
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    local valueLabel = Instance.new("TextLabel", frame)
    valueLabel.Size = UDim2.new(0, 35, 1, 0)
    valueLabel.Position = UDim2.new(1, -35, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    valueLabel.TextSize = 12
    valueLabel.Font = Enum.Font.SourceSans
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    local track = Instance.new("TextButton", frame)
    track.Name = "Track"
    track.Size = UDim2.new(1, -65, 0, sliderHeight / 2)
    track.Position = UDim2.new(0, 25, 0.5, -(sliderHeight/4))
    track.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    track.BorderSizePixel = 0
    track.Text = ""
    track.AutoButtonColor = false
    local trackCorner = Instance.new("UICorner", track)
    trackCorner.CornerRadius = UDim.new(1, 0)
    local gradient = Instance.new("UIGradient", track)
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
        ColorSequenceKeypoint.new(0.166, Color3.fromRGB(255, 255, 0)),
        ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
        ColorSequenceKeypoint.new(0.666, Color3.fromRGB(0, 0, 255)),
        ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
    })
    local thumb = Instance.new("Frame", track)
    thumb.Name = "Thumb"
    thumb.Size = UDim2.new(0, thumbSize, 0, thumbSize)
    thumb.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
    thumb.BorderSizePixel = 0
    local thumbCorner = Instance.new("UICorner", thumb)
    thumbCorner.CornerRadius = UDim.new(1, 0)
    local currentValue = initialVal
    local function setValue(newValue, fireCallback)
        currentValue = math.clamp(newValue, minVal, maxVal)
        local percentage = (currentValue - minVal) / (maxVal - minVal)
        local trackWidth = track.AbsoluteSize.X
        local thumbWidth = thumb.AbsoluteSize.X
        if trackWidth == 0 then trackWidth = 100 end -- Fallback jika belum digambar
        local newThumbX = (trackWidth - thumbWidth) * percentage
        thumb.Position = UDim2.new(0, newThumbX, 0.5, -thumbSize/2)
        valueLabel.Text = tostring(math.floor(currentValue * 360))
        if fireCallback and callback then
            callback(currentValue)
        end
    end
    local function updateFromInput(input)
        local trackWidth = track.AbsoluteSize.X
        local thumbWidth = thumb.AbsoluteSize.X
        if trackWidth <= thumbWidth then return end
        local relativeX = input.Position.X - track.AbsolutePosition.X - (thumbWidth / 2)
        local percentage = math.clamp(relativeX / (trackWidth - thumbWidth), 0, 1)
        local newValue = minVal + (maxVal - minVal) * percentage
        setValue(newValue, true)
    end
    local isDragging = false
    track.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then isDragging = true; updateFromInput(input) end end)
    UserInputService.InputChanged:Connect(function(input) if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then updateFromInput(input) end end)
    UserInputService.InputEnded:Connect(function(input) if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then isDragging = false end end)
    frame.AncestryChanged:Connect(function(_, parent) if parent then RunService.Heartbeat:Wait(); setValue(currentValue, false) end end)
    if frame:IsDescendantOf(game) then RunService.Heartbeat:Wait(); setValue(currentValue, false) end
    return frame, setValue
end

local function createDynamicSlider(parent, label, initialVal, callback)
    local sliderHeight = 16
    local thumbSize = 16
    local minVal, maxVal = 0, 1
    local frame = Instance.new("Frame", parent)
    frame.Size = UDim2.new(1, -10, 0, 30)
    frame.Position = UDim2.new(0, 5, 0, 0)
    frame.BackgroundTransparency = 1
    local textLabel = Instance.new("TextLabel", frame)
    textLabel.Size = UDim2.new(0, 20, 1, 0)
    textLabel.Position = UDim2.new(0, 0, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = label
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextSize = 12
    textLabel.Font = Enum.Font.SourceSans
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    local valueLabel = Instance.new("TextLabel", frame)
    valueLabel.Size = UDim2.new(0, 35, 1, 0)
    valueLabel.Position = UDim2.new(1, -35, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    valueLabel.TextSize = 12
    valueLabel.Font = Enum.Font.SourceSans
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    local track = Instance.new("TextButton", frame)
    track.Name = "Track"
    track.Size = UDim2.new(1, -65, 0, sliderHeight / 2)
    track.Position = UDim2.new(0, 25, 0.5, -(sliderHeight/4))
    track.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    track.BorderSizePixel = 0
    track.Text = ""
    track.AutoButtonColor = false
    local trackCorner = Instance.new("UICorner", track)
    trackCorner.CornerRadius = UDim.new(1, 0)
    local gradient = Instance.new("UIGradient", track)
    gradient.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
    local thumb = Instance.new("Frame", track)
    thumb.Name = "Thumb"
    thumb.Size = UDim2.new(0, thumbSize, 0, thumbSize)
    thumb.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
    thumb.BorderSizePixel = 0
    local thumbCorner = Instance.new("UICorner", thumb)
    thumbCorner.CornerRadius = UDim.new(1, 0)
    local currentValue = initialVal
    local function setValue(newValue, fireCallback)
        currentValue = math.clamp(newValue, minVal, maxVal)
        local percentage = (currentValue - minVal) / (maxVal - minVal)
        local trackWidth = track.AbsoluteSize.X
        local thumbWidth = thumb.AbsoluteSize.X
        if trackWidth == 0 then trackWidth = 100 end -- Fallback jika belum digambar
        local newThumbX = (trackWidth - thumbWidth) * percentage
        thumb.Position = UDim2.new(0, newThumbX, 0.5, -thumbSize/2)
        valueLabel.Text = tostring(math.floor(currentValue * 100))
        if fireCallback and callback then
            callback(currentValue)
        end
    end
    local function updateFromInput(input)
        local trackWidth = track.AbsoluteSize.X
        local thumbWidth = thumb.AbsoluteSize.X
        if trackWidth <= thumbWidth then return end
        local relativeX = input.Position.X - track.AbsolutePosition.X - (thumbWidth / 2)
        local percentage = math.clamp(relativeX / (trackWidth - thumbWidth), 0, 1)
        local newValue = minVal + (maxVal - minVal) * percentage
        setValue(newValue, true)
    end
    local isDragging = false
    track.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then isDragging = true; updateFromInput(input) end end)
    UserInputService.InputChanged:Connect(function(input) if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then updateFromInput(input) end end)
    UserInputService.InputEnded:Connect(function(input) if (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then isDragging = false end end)
    frame.AncestryChanged:Connect(function(_, parent) if parent then RunService.Heartbeat:Wait(); setValue(currentValue, false) end end)
    if frame:IsDescendantOf(game) then RunService.Heartbeat:Wait(); setValue(currentValue, false) end
    local function updateGradient(colorSeq)
        gradient.Color = colorSeq
    end
    return frame, setValue, updateGradient
end

local function createHSVColorPickerGroup(parent, title, initialColor, colorChangedCallback)
    local groupFrame = Instance.new("Frame", parent)
    groupFrame.Size = UDim2.new(1, 0, 0, 120)
    groupFrame.BackgroundTransparency = 1
    local groupLayout = Instance.new("UIListLayout", groupFrame)
    groupLayout.Padding = UDim.new(0, 0)
    local titleFrame = Instance.new("Frame", groupFrame)
    titleFrame.Size = UDim2.new(1, 0, 0, 30)
    titleFrame.BackgroundTransparency = 1
    local titleLabel = Instance.new("TextLabel", titleFrame)
    titleLabel.Size = UDim2.new(0.7, -5, 1, 0)
    titleLabel.Position = UDim2.new(0, 5, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = title
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 14
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    local preview = Instance.new("Frame", titleFrame)
    preview.Size = UDim2.new(0, 50, 0, 20)
    preview.Position = UDim2.new(1, -55, 0.5, -10)
    preview.BackgroundColor3 = initialColor
    preview.BorderSizePixel = 1
    preview.BorderColor3 = Color3.fromRGB(150, 150, 150)
    local previewCorner = Instance.new("UICorner", preview)
    previewCorner.CornerRadius = UDim.new(0, 4)
    local initialH, initialS, initialV = initialColor:ToHSV()
    local currentH, currentS, currentV = initialH, initialS, initialV
    local setSGradient, setVGradient
    local function updateColor()
        local newColor = Color3.fromHSV(currentH, currentS, currentV)
        preview.BackgroundColor3 = newColor
        if colorChangedCallback then
            colorChangedCallback(newColor)
        end
    end
    local function updateSaturationGradient()
        if setSGradient then
            local startColor = Color3.fromHSV(currentH, 0, currentV)
            local endColor = Color3.fromHSV(currentH, 1, currentV)
            setSGradient(ColorSequence.new(startColor, endColor))
        end
    end
    local function updateValueGradient()
        if setVGradient then
            local startColor = Color3.fromHSV(currentH, currentS, 0)
            local endColor = Color3.fromHSV(currentH, currentS, 1)
            setVGradient(ColorSequence.new(startColor, endColor))
        end
    end
    createHueSlider(groupFrame, "H", currentH, function(h)
        currentH = h
        updateColor()
        updateSaturationGradient()
        updateValueGradient()
    end)
    local sFrame, sSetValue, sSetGradient = createDynamicSlider(groupFrame, "S", currentS, function(s)
        currentS = s
        updateColor()
        updateValueGradient()
    end)
    setSGradient = sSetGradient
    local vFrame, vSetValue, vSetGradient = createDynamicSlider(groupFrame, "V", currentV, function(v)
        currentV = v
        updateColor()
        updateSaturationGradient()
    end)
    setVGradient = vSetGradient
    updateSaturationGradient()
    updateValueGradient()
    return groupFrame
end
-- [AKHIR v8] Akhir dari helper functions


--====================================================================--
--                        LOGIKA HEAD SIZE (aimlock.lua)              --
--====================================================================--

-- [PERUBAHAN v7] Fungsi baru untuk mengembalikan headsize 1 pemain
local function revertHeadSizeForPlayer(player)
    local originalProps = originalHeadSizes[player]
    if not originalProps then return end -- Tidak ada yang perlu dikembalikan

    local character = player.Character
    local head = character and character:FindFirstChild("Head")
    
    if head and head:IsA("BasePart") then
        -- Hanya kembalikan jika properti asli tersimpan sebagai tabel
        if type(originalProps) == "table" then
            head.Size = originalProps.Size
            head.CanCollide = originalProps.CanCollide
            head.Massless = originalProps.Massless
            head.CanTouch = originalProps.CanTouch
        end
    end
    
    -- Hapus dari pelacakan
    originalHeadSizes[player] = nil
end


-- Fungsi utama untuk mengubah ukuran kepala
local function applyHeadSizeToPlayer(targetPlayer, size)
    -- *** Exclude LocalPlayer ***
    if targetPlayer == LocalPlayer then return false end

    -- [PERUBAHAN v4] Jika target adalah "all" or "others", jangan terapkan ke rekan satu tim.
    -- Loop utama di v7 sudah menangani ini, tapi ini adalah pengaman kedua.
    if (currentTarget:lower() == "all" or currentTarget:lower() == "others") and targetPlayer.Team == LocalPlayer.Team then
        revertHeadSizeForPlayer(targetPlayer) -- Pastikan dikembalikan jika terlanjur diubah
        return false -- Jangan terapkan ke rekan satu tim
    end

    local character = targetPlayer.Character
    local head = character and character:FindFirstChild("Head")

    if head and head:IsA("BasePart") then
        -- Store original size/properties if not already stored
        if not originalHeadSizes[targetPlayer] then
            originalHeadSizes[targetPlayer] = {
                Size = head.Size,
                Massless = head.Massless,
                CanTouch = head.CanTouch,
                CanCollide = head.CanCollide
            }
        end

        -- Apply new size
        local newSizeVector = Vector3.new(size, size, size)
        
        -- [PERUBAHAN v7] Hanya terapkan jika BERBEDA untuk efisiensi
        if head.Size ~= newSizeVector then
            head.Size = newSizeVector
        end
        if head.Massless ~= true then
            head.Massless = true  -- <<< PERBAIKAN: Buat tidak bermassa agar tidak 'freeze'
        end
        
        -- <<< PERBAIKAN HITBOX: Kembalikan properti asli agar bisa di-raycast (ditembak)
        local originalProps = originalHeadSizes[targetPlayer]
        if head.CanCollide ~= originalProps.CanCollide then
            head.CanCollide = originalProps.CanCollide
        end
        if head.CanTouch ~= originalProps.CanTouch then
            head.CanTouch = originalProps.CanTouch
        end
        
        return true -- Applied successfully
    end
    return false -- Failed to apply
end

-- [PERUBAHAN v7] Loop Heartbeat yang dirombak total
local function startHeadSizeLoop()
    if headSizeLoopConnection then
        headSizeLoopConnection:Disconnect()
        headSizeLoopConnection = nil
    end

    headSizeLoopConnection = RunService.Heartbeat:Connect(function()
        if not isHeadSizeActive then return end -- Stop if feature is off

        local targetNameLower = currentTarget:lower()
        local localPlayerTeam = LocalPlayer.Team -- Ambil sekali per frame

        for _, player in ipairs(Players:GetPlayers()) do
            if player == LocalPlayer then continue end

            -- 1. Tentukan apakah pemain ini adalah target
            local isTarget = false
            if targetNameLower == "all" or targetNameLower == "others" then
                isTarget = true
            elseif targetNameLower == "me" then
                -- Sudah dilewati oleh 'player == LocalPlayer'
                isTarget = false
            else
                -- Cek nama spesifik
                if player.Name:lower():find(targetNameLower, 1, true) or player.DisplayName:lower():find(targetNameLower, 1, true) then
                    isTarget = true
                end
            end

            -- 2. Cek status pemain (hidup/mati)
            local character = player.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local isAlive = humanoid and humanoid.Health > 0

            -- 3. Terapkan atau Kembalikan berdasarkan logika
            if isTarget and isAlive then
                -- Pemain adalah target dan hidup
                local isTeam = (player.Team == localPlayerTeam)
                
                if (targetNameLower == "all" or targetNameLower == "others") and isTeam then
                    -- Target adalah "all" tapi pemain ini kawan. Kembalikan!
                    revertHeadSizeForPlayer(player)
                else
                    -- Target adalah musuh di mode "all" ATAU target nama spesifik. Terapkan!
                    applyHeadSizeToPlayer(player, currentSize)
                end
            else
                -- Pemain BUKAN target, ATAU pemain mati/tidak valid. Kembalikan!
                revertHeadSizeForPlayer(player)
            end
        end
    end)
end


-- Fungsi untuk mengembalikan ukuran kepala ke semula (saat toggle dimatikan)
local function revertHeadSize()
    if headSizeLoopConnection then -- Stop the loop first
        headSizeLoopConnection:Disconnect()
        headSizeLoopConnection = nil
    end

    local revertedCount = 0
    local playersToClear = {} -- Kumpulkan pemain untuk dihapus dari originalHeadSizes setelah iterasi

    -- [PERUBAHAN v7] Disederhanakan untuk menggunakan revertHeadSizeForPlayer
    for player, _ in pairs(originalHeadSizes) do
        table.insert(playersToClear, player)
    end
    
    for _, player in ipairs(playersToClear) do
        if player and player.Parent then -- Pastikan pemain masih ada
            revertHeadSizeForPlayer(player)
            revertedCount = revertedCount + 1
        else
            -- Pemain sudah keluar, hapus saja dari cache
            originalHeadSizes[player] = nil
        end
    end

    if revertedCount > 0 then
        print("Reverted head size for " .. revertedCount .. " players.")
    end
end


-- Fungsi toggle utama
local function toggleHeadSizeFeature(activate)
    isHeadSizeActive = activate
    if isHeadSizeActive then
        -- [PERUBAHAN v7] Cukup mulai loop. Loop akan menangani penerapan awal.
        startHeadSizeLoop()
        print("Head size loop started.")
    else
        revertHeadSize() -- Revert sizes and stops the loop
        print("Head size loop stopped and reverted all.")
    end
end


--====================================================================--
--                    LOGIKA ESP (DIIMPOR DARI esp.lua)               --
--====================================================================--
-- [INFO] Loop ESP sudah menggunakan RenderStepped, ini adalah yang tercepat
-- untuk pembaruan visual. Tidak perlu diubah.

-- Fungsi BARU untuk membersihkan semua elemen ESP UNTUK SATU PEMAIN
local function cleanupPlayerESP(userId)
    local elements = espCache[userId]
    if elements then
        -- Hancurkan semua elemen Billboard (yang berisi nama dan health bar)
        if elements.billboard then pcall(function() elements.billboard:Destroy() end) end
        if elements.highlight then pcall(function() elements.highlight:Destroy() end) end
        if elements.beam then pcall(function() elements.beam:Destroy() end) end
        if elements.attachment0 then pcall(function() elements.attachment0:Destroy() end) end
        if elements.attachment1 then pcall(function() elements.attachment1:Destroy() end) end
        espCache[userId] = nil -- Hapus dari cache setelah dihancurkan
    end
end

-- Fungsi untuk membersihkan SEMUA elemen ESP
local function cleanupAllESP()
    if EspRenderConnection then
        EspRenderConnection:Disconnect()
        EspRenderConnection = nil
    end
    
    -- Gunakan fungsi cleanupPlayerESP untuk setiap entri di cache
    for userId, _ in pairs(espCache) do
        cleanupPlayerESP(userId)
    end
end

-- Fungsi utama yang di-loop untuk menggambar ESP (di RenderStepped)
local function UpdateESP()
    -- Cek apakah ada fitur ESP yang aktif
    local isAnyEspActive = IsEspNameEnabled or IsEspBodyEnabled or IsEspLineEnabled or IsEspHealthBarEnabled
    if not isAnyEspActive then return end
    
    -- [PERUBAHAN v6] Menggunakan TeamColor untuk perbandingan
    local localPlayerTeamColor = LocalPlayer.TeamColor
    
    local localCharacter = LocalPlayer.Character
    local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    local camera = workspace.CurrentCamera

    -- Jika pemain lokal (kita) tidak memiliki root part (mati atau respawn), hentikan sementara.
    if not localRoot or not camera then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local head = char and char:FindFirstChild("Head")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")

            -- Cek: Apakah target player hidup (memiliki semua bagian penting dan Health > 0)?
            if head and hrp and humanoid and humanoid.Health > 0 then
                
                local espElements = espCache[player.UserId]
                if not espElements then
                    espElements = {}
                    espCache[player.UserId] = espElements
                end

                -- [PERUBAHAN v6] Logika TeamCheck otomatis diaktifkan menggunakan TeamColor
                local isTeam = false -- Default ke musuh
                
                -- Cek jika kita punya TeamColor, warnanya BUKAN abu-abu (default), dan sama dgn pemain lain
                if localPlayerTeamColor and localPlayerTeamColor.Name ~= "Medium stone grey" and player.TeamColor then
                    isTeam = (player.TeamColor == localPlayerTeamColor)
                end
                
                local espColor
                if isTeam then
                    espColor = teamColor -- [PERUBAHAN v8] Menggunakan variabel
                else
                    espColor = enemyColor -- [PERUBAHAN v8] Menggunakan variabel
                end


                local distance = (localRoot.Position - head.Position).Magnitude
                
                -- Cek apakah Billboard GUI (Nama, Jarak, Health Bar) diperlukan
                local isBillboardNeeded = IsEspNameEnabled or IsEspHealthBarEnabled

                if isBillboardNeeded then
                    if not espElements.billboard then
                        local billboardGui = Instance.new("BillboardGui")
                        billboardGui.Name = "PlayerESP_Billboard"
                        billboardGui.AlwaysOnTop = true
                        billboardGui.Size = UDim2.new(0, 150, 0, 45) -- Ukuran tetap
                        billboardGui.StudsOffset = Vector3.new(0, 2.5, 0)

                        -- Name Label
                        local nameLabel = Instance.new("TextLabel", billboardGui)
                        nameLabel.Name = "NameLabel"
                        nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
                        nameLabel.Position = UDim2.new(0, 0, 0, 0)
                        nameLabel.BackgroundTransparency = 1
                        nameLabel.Font = Enum.Font.SourceSansBold
                        nameLabel.TextSize = 14
                        nameLabel.Text = player.DisplayName
                        nameLabel.TextXAlignment = Enum.TextXAlignment.Center

                        -- Distance Label
                        local distLabel = Instance.new("TextLabel", billboardGui)
                        distLabel.Name = "DistanceLabel"
                        distLabel.Size = UDim2.new(1, 0, 0.3, 0)
                        distLabel.Position = UDim2.new(0, 0, 0.4, 0)
                        distLabel.BackgroundTransparency = 1
                        distLabel.Font = Enum.Font.SourceSans
                        distLabel.TextSize = 12
                        distLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
                        distLabel.TextXAlignment = Enum.TextXAlignment.Center
                        
                        -- HEALTH BAR CONTAINER
                        local healthFrame = Instance.new("Frame", billboardGui)
                        healthFrame.Name = "HealthBackground"
                        healthFrame.Size = UDim2.new(1, -10, 0, 8) -- Ukuran awal
                        healthFrame.Position = UDim2.new(0.5, -70, 0.7, 0)
                        healthFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
                        healthFrame.BorderSizePixel = 1
                        healthFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
                        
                        local healthFill = Instance.new("Frame", healthFrame)
                        healthFill.Name = "HealthFill"
                        healthFill.Size = UDim2.new(1, 0, 1, 0)
                        healthFill.Position = UDim2.new(0, 0, 0, 0)
                        healthFill.BackgroundColor3 = espColor 
                        healthFill.BorderSizePixel = 0
                        
                        espElements.billboard = billboardGui
                    end

                    espElements.billboard.Adornee = head
                    espElements.billboard.Parent = CoreGui
                    
                    -- A. Update Visibility Nama/Jarak (Tergantung Toggle)
                    espElements.billboard.NameLabel.Visible = IsEspNameEnabled
                    espElements.billboard.NameLabel.TextColor3 = espColor
                    
                    espElements.billboard.DistanceLabel.Visible = IsEspNameEnabled
                    
                    -- Update jarak dan teks
                    local distanceText = "[" .. tostring(math.floor(distance)) .. "m]"
                    espElements.billboard.DistanceLabel.Text = distanceText

                    -- B. Update Health Bar
                    local healthBackground = espElements.billboard:FindFirstChild("HealthBackground")
                    
                    if healthBackground then
                        healthBackground.Visible = IsEspHealthBarEnabled -- Visibilitas berdasarkan toggle baru
                        
                        if IsEspHealthBarEnabled then
                            -- === LOGIKA SCALING DINAMIS ===
                            local MaxDistance = 150 -- Jarak maks untuk scaling (150 stud)
                            local MinScaleFactor = 0.3 -- Skala minimum (30% dari ukuran penuh)
                            local BaseBarWidth = 140 -- Lebar bar dasar (150 - 10)

                            -- Hitung skala: 1.0 (dekat) hingga MinScaleFactor (jauh)
                            local scaleFactor = math.max(MinScaleFactor, 1 - (distance / MaxDistance))

                            local scaledWidth = BaseBarWidth * scaleFactor

                            -- Terapkan ukuran dan posisi yang diskalakan
                            healthBackground.Size = UDim2.new(0, scaledWidth, 0, 8)
                            -- Penempatan di tengah (0.5 - (scaledWidth / 2) / 150)
                            local centerOffset = (150 - scaledWidth) / 2
                            healthBackground.Position = UDim2.new(0, centerOffset, 0.7, 0)
                            
                            -- Update fill bar
                            local healthPercentage = humanoid.Health / humanoid.MaxHealth
                            local healthFillFrame = healthBackground.HealthFill
                            
                            healthFillFrame.Size = UDim2.new(healthPercentage, 0, 1, 0)
                            healthFillFrame.BackgroundColor3 = espColor -- Warna tim/musuh
                        end
                    end
                
                elseif espElements.billboard then
                    -- Hancurkan Billboard jika tidak ada fitur yang memerlukannya
                    espElements.billboard:Destroy()
                    espElements.billboard = nil
                end

                -- 2. Logika ESP Tubuh (Highlight)
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

                    espElements.highlight.FillColor = espColor 
                    espElements.highlight.OutlineColor = espColor 

                elseif espElements.highlight then
                    espElements.highlight:Destroy()
                    espElements.highlight = nil
                end

                -- 3. Logika ESP Garis (Line)
                if IsEspLineEnabled then
                    if not espElements.attachment0 then
                        local att0 = Instance.new("Attachment")
                        att0.Name = "ESPGarisAtt0_Origin"
                        att0.Parent = camera 
                        espElements.attachment0 = att0
                    end
                    
                    if not espElements.attachment1 then
                        local att1 = Instance.new("Attachment")
                        att1.Name = "ESPGarisAtt1_Target"
                        att1.Parent = hrp
                        espElements.attachment1 = att1
                    end

                    if not espElements.beam then
                        local beam = Instance.new("Beam")
                        beam.Name = "ESPBeam"
                        beam.Attachment0 = espElements.attachment0
                        beam.Attachment1 = espElements.attachment1
                        beam.Width0 = 0.01 
                        beam.Width1 = 0.01
                        beam.FaceCamera = true
                        beam.Transparency = NumberSequence.new(0.5)
                        beam.Parent = espElements.attachment0 
                        espElements.beam = beam
                    end

                    local viewportSize = camera.ViewportSize
                    local screenBottom = Vector2.new(viewportSize.X / 2, viewportSize.Y * 0.95) 
                    
                    local ray = camera:ViewportPointToRay(screenBottom.X, screenBottom.Y)
                    espElements.attachment0.WorldPosition = ray.Origin + ray.Direction 

                    if espElements.attachment1.Parent ~= hrp then
                        espElements.attachment1.Parent = hrp
                    end

                    espElements.beam.Color = ColorSequence.new(espColor) 
                    espElements.beam.Enabled = true

                elseif espElements.beam then
                    if espElements.beam then espElements.beam:Destroy(); espElements.beam = nil end
                    if espElements.attachment0 then espElements.attachment0:Destroy(); espElements.attachment0 = nil end
                    if espElements.attachment1 then espElements.attachment1:Destroy(); espElements.attachment1 = nil end
                end

            else
                -- Pemain tidak punya karakter atau mati (Health <= 0), bersihkan ESP mereka.
                -- Ini memastikan ESP hilang saat pemain target mati dan muncul kembali saat mereka respawn.
                if espCache[player.UserId] then
                    cleanupPlayerESP(player.UserId) -- Panggil fungsi bersih yang benar
                end
            end
        end
    end
end

-- Fungsi untuk mengelola koneksi loop ESP
local function manageEspConnection()
    local isAnyEspActive = IsEspNameEnabled or IsEspBodyEnabled or IsEspLineEnabled or IsEspHealthBarEnabled
    if isAnyEspActive and not EspRenderConnection then
        -- [INFO] Terhubung ke RenderStepped (Sangat Cepat)
        EspRenderConnection = RunService.RenderStepped:Connect(UpdateESP)
    elseif not isAnyEspActive and EspRenderConnection then
        cleanupAllESP() -- Fungsi ini juga Disconnect
    end
end

-- Fungsi Toggle untuk setiap fitur
local function ToggleESPName(enabled)
    IsEspNameEnabled = enabled
    manageEspConnection()
end

local function ToggleESPBody(enabled)
    IsEspBodyEnabled = enabled
    manageEspConnection()
end

local function ToggleESPLine(enabled)
    IsEspLineEnabled = enabled
    manageEspConnection()
end

-- Fungsi Toggle Baru untuk Health Bar
local function ToggleESPHealthBar(enabled)
    IsEspHealthBarEnabled = enabled
    manageEspConnection()
end

--====================================================================--
--                          LOOP AIMBOT/FOV/CROSSHAIR (cit.lua)       --
--====================================================================--

-- [BARU v13] Fungsi untuk menggambar crosshair
local function DrawCrosshair()
    if not Drawing or not isCrosshairEnabled then
        -- Sembunyikan semua jika nonaktif atau 'Drawing' tidak ada
        if crosshairElements and #crosshairElements > 0 then
            for _, obj in ipairs(crosshairElements) do
                obj.Visible = false
            end
        end
        return
    end
    
    local centerX = Camera.ViewportSize.X / 2
    local centerY = Camera.ViewportSize.Y / 2
    local size = crosshairSize
    local gap = 5 -- Jarak untuk Tipe 4 (Terbuka)
    local color = crosshairColor
    local thickness = crosshairThickness
    local transparency = crosshairTransparency
    
    -- Ambil elemen dari tabel (indeks sesuai urutan pembuatan)
    local chDot = crosshairElements[1]
    local chLineH = crosshairElements[2]
    local chLineV = crosshairElements[3]
    local chLineT = crosshairElements[4]
    local chLineB = crosshairElements[5]
    local chLineL = crosshairElements[6]
    local chLineR = crosshairElements[7]
    local chLineD1 = crosshairElements[8]
    local chLineD2 = crosshairElements[9]

    -- Sembunyikan semua terlebih dahulu
    for _, obj in ipairs(crosshairElements) do
        obj.Visible = false
    end

    -- Tipe 1: Titik
    if currentCrosshairType == 1 then
        chDot.Visible = true
        chDot.Color = color
        chDot.Transparency = transparency
        chDot.Position = Vector2.new(centerX, centerY)

    -- Tipe 2: Silang
    elseif currentCrosshairType == 2 then
        chLineH.Visible = true
        chLineV.Visible = true
        
        chLineH.Color = color
        chLineH.Thickness = thickness
        chLineH.Transparency = transparency
        chLineH.From = Vector2.new(centerX - size, centerY)
        chLineH.To = Vector2.new(centerX + size, centerY)
        
        chLineV.Color = color
        chLineV.Thickness = thickness
        chLineV.Transparency = transparency
        chLineV.From = Vector2.new(centerX, centerY - size)
        chLineV.To = Vector2.new(centerX, centerY + size)

    -- Tipe 3: Silang + Titik
    elseif currentCrosshairType == 3 then
        chDot.Visible = true
        chDot.Color = color
        chDot.Transparency = transparency
        chDot.Position = Vector2.new(centerX, centerY)
        
        chLineH.Visible = true
        chLineV.Visible = true
        
        chLineH.Color = color
        chLineH.Thickness = thickness
        chLineH.Transparency = transparency
        chLineH.From = Vector2.new(centerX - size, centerY)
        chLineH.To = Vector2.new(centerX + size, centerY)
        
        chLineV.Color = color
        chLineV.Thickness = thickness
        chLineV.Transparency = transparency
        chLineV.From = Vector2.new(centerX, centerY - size)
        chLineV.To = Vector2.new(centerX, centerY + size)

    -- Tipe 4: Terbuka
    elseif currentCrosshairType == 4 then
        chLineT.Visible = true
        chLineB.Visible = true
        chLineL.Visible = true
        chLineR.Visible = true
        
        -- Top
        chLineT.Color = color; chLineT.Thickness = thickness; chLineT.Transparency = transparency
        chLineT.From = Vector2.new(centerX, centerY - gap)
        chLineT.To = Vector2.new(centerX, centerY - gap - size)
        
        -- Bottom
        chLineB.Color = color; chLineB.Thickness = thickness; chLineB.Transparency = transparency
        chLineB.From = Vector2.new(centerX, centerY + gap)
        chLineB.To = Vector2.new(centerX, centerY + gap + size)
        
        -- Left
        chLineL.Color = color; chLineL.Thickness = thickness; chLineL.Transparency = transparency
        chLineL.From = Vector2.new(centerX - gap, centerY)
        chLineL.To = Vector2.new(centerX - gap - size, centerY)
        
        -- Right
        chLineR.Color = color; chLineR.Thickness = thickness; chLineR.Transparency = transparency
        chLineR.From = Vector2.new(centerX + gap, centerY)
        chLineR.To = Vector2.new(centerX + gap + size, centerY)

    -- Tipe 5: X
    elseif currentCrosshairType == 5 then
        chLineD1.Visible = true
        chLineD2.Visible = true

        -- Diag 1 (Top-Left to Bottom-Right)
        chLineD1.Color = color; chLineD1.Thickness = thickness; chLineD1.Transparency = transparency
        chLineD1.From = Vector2.new(centerX - size, centerY - size)
        chLineD1.To = Vector2.new(centerX + size, centerY + size)
        
        -- Diag 2 (Top-Right to Bottom-Left)
        chLineD2.Color = color; chLineD2.Thickness = thickness; chLineD2.Transparency = transparency
        chLineD2.From = Vector2.new(centerX + size, centerY - size)
        chLineD2.To = Vector2.new(centerX - size, centerY + size)
    end
end


-- [INFO] Loop Aimbot juga di RenderStepped (Sangat Cepat)
AimbotRenderConnection = RunService.RenderStepped:Connect(function()
    -- Update FOV Circle
    if FOVCircle then
        FOVCircle.Visible = ShowFOV and AimbotEnabled -- [PERBAIKAN v15] FOV hanya terlihat jika Aimbot aktif
        FOVCircle.Radius = FOV
        FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end

    -- [BARU v13] Update Crosshair
    DrawCrosshair()

    -- Update Aimbot
    if AimbotEnabled then
        local target = GetClosestPlayer()
        if target then
            SmoothLookAt(target.Position)
        end
    end
end)


--====================================================================--
--                               GUI GABUNGAN                         --
--====================================================================--
-- Hapus GUI lama jika ada
local oldGui = CoreGui:FindFirstChild("CombinedFeaturesGUI")
if oldGui then
    oldGui:Destroy()
end

-- Main ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CombinedFeaturesGUI"
ScreenGui.Parent = CoreGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false
ScreenGui.DisplayOrder = 11 -- Ensure it's above default UI

-- Main Frame (Window)
MainFrame = Instance.new("Frame") -- [DIUBAH v9] Dihapus 'local' agar bisa diakses global
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 180, 0, 220) -- <<< (MINI) UKURAN DIPERKECIL
MainFrame.Position = UDim2.new(0.5, -90, 0.5, -110) -- <<< (MINI) Posisi disesuaikan
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 40) -- Dark blue-ish
MainFrame.BackgroundTransparency = 0.3
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true -- Clip content if window is minimized
MainFrame.Parent = ScreenGui
MainFrame.Visible = true
MainFrame.ZIndex = 10

-- Corner and Stroke for MainFrame
local MainUICorner = Instance.new("UICorner")
MainUICorner.CornerRadius = UDim.new(0, 8)
MainUICorner.Parent = MainFrame

local UIStroke = Instance.new("UIStroke")
UIStroke.Color = Color3.fromRGB(0, 150, 255) -- Blue stroke
UIStroke.Thickness = 1.5
UIStroke.Transparency = 0.5
UIStroke.Parent = MainFrame

-- [BARU v9] Pegangan untuk mengubah ukuran jendela
local MainResizeHandle = Instance.new("TextButton")
MainResizeHandle.Name = "MainResizeHandle"
MainResizeHandle.Text = "◢" -- Karakter opsional, bisa juga ""
MainResizeHandle.Size = UDim2.new(0, 15, 0, 15)
MainResizeHandle.Position = UDim2.new(1, -15, 1, -15)
MainResizeHandle.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
MainResizeHandle.BackgroundTransparency = 0.5
MainResizeHandle.BorderSizePixel = 0
MainResizeHandle.TextColor3 = Color3.fromRGB(255, 255, 255)
MainResizeHandle.TextSize = 12
MainResizeHandle.TextXAlignment = Enum.TextXAlignment.Right
MainResizeHandle.TextYAlignment = Enum.TextYAlignment.Bottom
MainResizeHandle.ZIndex = 12 -- Pastikan di atas konten lain
MainResizeHandle.Parent = MainFrame

-- [BARU v9] Logika untuk mengubah ukuran
MainResizeHandle.InputBegan:Connect(function(input)
    if not (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then return end

    local isResizing = true
    local initialMousePosition = UserInputService:GetMouseLocation()
    local initialFrameSize = MainFrame.AbsoluteSize

    local inputChangedConnection
    local inputEndedConnection

    inputChangedConnection = UserInputService.InputChanged:Connect(function(changedInput)
        if isResizing and (changedInput.UserInputType == Enum.UserInputType.MouseMovement or changedInput.UserInputType == Enum.UserInputType.Touch) then
            local delta = UserInputService:GetMouseLocation() - initialMousePosition
            local newSizeX = math.max(180, initialFrameSize.X + delta.X) -- Ukuran min
            local newSizeY = math.max(220, initialFrameSize.Y + delta.Y) -- Ukuran min
            MainFrame.Size = UDim2.new(0, newSizeX, 0, newSizeY)
        end
    end)

    inputEndedConnection = UserInputService.InputEnded:Connect(function(endedInput)
        if endedInput.UserInputType == input.UserInputType then
            isResizing = false
            if inputChangedConnection then inputChangedConnection:Disconnect() end
            if inputEndedConnection then inputEndedConnection:Disconnect() end
            saveGuiPositions() -- Simpan ukuran baru
        end
    end)
end)


-- Title Bar (Draggable Handle)
local TitleBar = Instance.new("TextButton")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 25)
TitleBar.Position = UDim2.new(0, 0, 0, 0)
TitleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 45)
TitleBar.BorderSizePixel = 0
TitleBar.Text = ""
TitleBar.AutoButtonColor = false
TitleBar.Parent = MainFrame
MakeDraggable(MainFrame, TitleBar) -- Make the window draggable

-- Title Label
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Name = "TitleLabel"
TitleLabel.Size = UDim2.new(1, -50, 1, 0) -- <<< (MINI) Disesuaikan (Tombol 45px)
TitleLabel.Position = UDim2.new(0, 8, 0, 0) -- 8px Left padding
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Enum.Font.SourceSansBold
TitleLabel.TextSize = 14
TitleLabel.Text = "Game Perang By Arexans" -- <<< (MINI) Judul Diperbarui
TitleLabel.TextColor3 = Color3.fromRGB(0, 200, 255)
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left -- Rata Kiri
TitleLabel.Parent = TitleBar
TitleLabel.Active = false -- <<< PERBAIKAN: Agar tidak memblokir input drag

-- Minimize Button
local MinimizeButton = Instance.new("TextButton")
MinimizeButton.Name = "MinimizeButton"
MinimizeButton.Size = UDim2.new(0, 20, 0, 20)
MinimizeButton.Position = UDim2.new(1, -45, 0.5, -10) -- Position left of close
MinimizeButton.BackgroundTransparency = 1
MinimizeButton.Font = Enum.Font.SourceSansBold
MinimizeButton.Text = "-"
MinimizeButton.TextColor3 = Color3.fromRGB(200, 200, 200) -- Gray minimize
MinimizeButton.TextSize = 20
MinimizeButton.Parent = TitleBar

-- Close Button
local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.Size = UDim2.new(0, 20, 0, 20)
CloseButton.Position = UDim2.new(1, -22.5, 0.5, -10)
CloseButton.BackgroundTransparency = 1
CloseButton.Font = Enum.Font.SourceSansBold
CloseButton.Text = "X"
CloseButton.TextColor3 = Color3.fromRGB(255, 100, 100)
CloseButton.TextSize = 16
CloseButton.Parent = TitleBar

-- Content Area Frame (DIUBAH MENJADI SCROLLINGFRAME)
local ContentFrame = Instance.new("ScrollingFrame")
ContentFrame.Name = "ContentFrame"
ContentFrame.Size = UDim2.new(1, -10, 1, -30) -- Padding
ContentFrame.Position = UDim2.new(0, 5, 0, 25)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame
ContentFrame.ScrollingDirection = Enum.ScrollingDirection.Y -- <<< HANYA BISA SCROLL VERTIKAL
-- ContentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y -- <<< [DIHAPUS v9] Diganti dengan pembaruan manual
ContentFrame.VerticalScrollBarInset = Enum.ScrollBarInset.Always -- [BARU v9] Mencegah scrollbar tumpang tindih
ContentFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255) -- <<< WARNA SCROLLBAR
ContentFrame.ScrollBarThickness = 6 -- <<< KETEBALAN SCROLLBAR

-- UIListLayout for Content (Parentnya adalah ContentFrame yang baru)
local ContentLayout = Instance.new("UIListLayout")
ContentLayout.Padding = UDim.new(0, 3) -- <<< (MINI) Mengurangi padding
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Parent = ContentFrame

-- [BARU v9] Memperbarui CanvasSize secara manual untuk ScrollingFrame
ContentLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    ContentFrame.CanvasSize = UDim2.new(0, 0, 0, ContentLayout.AbsoluteContentSize.Y + 5)
end)


-- == [BARU v8] Frame untuk Pengaturan ESP ==
local EspSettingsFrame = Instance.new("ScrollingFrame")
EspSettingsFrame.Name = "EspSettingsFrame"
EspSettingsFrame.Size = UDim2.new(1, -10, 1, -30) -- Ukuran sama dgn ContentFrame
EspSettingsFrame.Position = UDim2.new(0, 5, 0, 25) -- Posisi sama dgn ContentFrame
EspSettingsFrame.BackgroundTransparency = 1
EspSettingsFrame.Parent = MainFrame
EspSettingsFrame.Visible = false -- << Mulai tersembunyi
EspSettingsFrame.ScrollingDirection = Enum.ScrollingDirection.Y
-- EspSettingsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y -- [DIHAPUS v9]
EspSettingsFrame.VerticalScrollBarInset = Enum.ScrollBarInset.Always -- [BARU v9]
EspSettingsFrame.ScrollBarImageColor3 = Color3.fromRGB(0, 150, 255)
EspSettingsFrame.ScrollBarThickness = 6

local SettingsLayout = Instance.new("UIListLayout")
SettingsLayout.Padding = UDim.new(0, 3)
SettingsLayout.SortOrder = Enum.SortOrder.LayoutOrder
SettingsLayout.Parent = EspSettingsFrame

-- [BARU v9] Memperbarui CanvasSize secara manual untuk ScrollingFrame
SettingsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    EspSettingsFrame.CanvasSize = UDim2.new(0, 0, 0, SettingsLayout.AbsoluteContentSize.Y + 5)
end)


-- == [BARU v8] Tombol Kembali untuk Settings Frame ==
local BackButtonFrame = Instance.new("Frame")
BackButtonFrame.Name = "BackButtonFrame"
BackButtonFrame.Size = UDim2.new(1, 0, 0, 25)
BackButtonFrame.BackgroundTransparency = 1
BackButtonFrame.LayoutOrder = 0 -- Paling atas
BackButtonFrame.Parent = EspSettingsFrame

local BackButton = Instance.new("TextButton")
BackButton.Name = "BackButton"
BackButton.Size = UDim2.new(1, 0, 1, 0)
BackButton.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
BackButton.Font = Enum.Font.SourceSansBold
BackButton.TextSize = 12
BackButton.TextColor3 = Color3.new(1,1,1)
BackButton.Text = "◀ Kembali"
BackButton.Parent = BackButtonFrame
local bbCorner = Instance.new("UICorner", BackButton); bbCorner.CornerRadius = UDim.new(0, 4)

BackButton.MouseButton1Click:Connect(function()
    EspSettingsFrame.Visible = false
    ContentFrame.Visible = true
end)

-- == [BARU v8] Isi Frame Pengaturan ESP ==
local teamColorGroup = createHSVColorPickerGroup(EspSettingsFrame, "Warna Tim", teamColor, function(newColor)
    teamColor = newColor
end)
teamColorGroup.LayoutOrder = 1

local enemyColorGroup = createHSVColorPickerGroup(EspSettingsFrame, "Warna Musuh", enemyColor, function(newColor)
    enemyColor = newColor
end)
enemyColorGroup.LayoutOrder = 2


-- == Head Size Feature UI (Toggle Switch) ==
local HeadSizeToggleFrame, setHeadSizeSwitchState
local headSizeOptionsContainer -- [BARU v14] Deklarasi

HeadSizeToggleFrame, setHeadSizeSwitchState = createToggleSwitch(ContentFrame, "Head Size", isHeadSizeActive, function(state) -- <<< (MINI) Teks diringkas
    toggleHeadSizeFeature(state)
    if headSizeOptionsContainer then headSizeOptionsContainer.Visible = state end -- [BARU v14]
end)
HeadSizeToggleFrame.LayoutOrder = 1

-- == [BARU v14] Kontainer untuk Opsi Head Size ==
headSizeOptionsContainer = Instance.new("Frame", ContentFrame)
headSizeOptionsContainer.Name = "HeadSizeOptionsContainer"
headSizeOptionsContainer.Size = UDim2.new(1, 0, 0, 0) -- Ukuran Y Otomatis
headSizeOptionsContainer.AutomaticSize = Enum.AutomaticSize.Y
headSizeOptionsContainer.BackgroundTransparency = 1
headSizeOptionsContainer.LayoutOrder = 2 -- Tepat di bawah toggle
headSizeOptionsContainer.Visible = isHeadSizeActive -- Set visibilitas awal
headSizeOptionsContainer.ClipsDescendants = true

local headSizeOptionsLayout = Instance.new("UIListLayout", headSizeOptionsContainer)
headSizeOptionsLayout.Padding = UDim.new(0, 2)
headSizeOptionsLayout.SortOrder = Enum.SortOrder.LayoutOrder

local headSizeOptionsPadding = Instance.new("UIPadding", headSizeOptionsContainer)
headSizeOptionsPadding.PaddingLeft = UDim.new(0, 10) -- Indent opsi


-- == Head Size Input Frame ==
local InputFrame = Instance.new("Frame")
InputFrame.Name = "InputFrame"
InputFrame.Size = UDim2.new(1, 0, 0, 25)
InputFrame.BackgroundTransparency = 1
InputFrame.LayoutOrder = 1 -- [DIUBAH v14]
InputFrame.Parent = headSizeOptionsContainer -- [DIUBAH v14]

local InputLayout = Instance.new("UIListLayout")
InputLayout.FillDirection = Enum.FillDirection.Horizontal
InputLayout.VerticalAlignment = Enum.VerticalAlignment.Center
InputLayout.Padding = UDim.new(0, 5)
InputLayout.Parent = InputFrame

local TargetTextBox = Instance.new("TextBox")
TargetTextBox.Name = "TargetTextBox"
TargetTextBox.Size = UDim2.new(0.6, -2.5, 1, 0)
TargetTextBox.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
TargetTextBox.PlaceholderText = "Nickname / All / Others"
TargetTextBox.Text = currentTarget
TargetTextBox.ClearTextOnFocus = false
TargetTextBox.Font = Enum.Font.SourceSans
TargetTextBox.TextSize = 11 -- <<< (MINI) Font diperkecil
TargetTextBox.TextColor3 = Color3.new(1,1,1)
TargetTextBox.Parent = InputFrame
local ttCorner = Instance.new("UICorner", TargetTextBox); ttCorner.CornerRadius = UDim.new(0, 4)

local SizeTextBox = Instance.new("TextBox")
SizeTextBox.Name = "SizeTextBox"
SizeTextBox.Size = UDim2.new(0.4, -2.5, 1, 0)
SizeTextBox.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
SizeTextBox.PlaceholderText = "Size (e.g., 3)"
SizeTextBox.Text = tostring(currentSize)
SizeTextBox.ClearTextOnFocus = false
SizeTextBox.Font = Enum.Font.SourceSans
SizeTextBox.TextSize = 11 -- <<< (MINI) Font diperkecil
SizeTextBox.TextColor3 = Color3.new(1,1,1)
SizeTextBox.Parent = InputFrame
local stCorner = Instance.new("UICorner", SizeTextBox); stCorner.CornerRadius = UDim.new(0, 4)

-- == Info Label ==
local InfoLabel = Instance.new("TextLabel")
InfoLabel.Name = "InfoLabel"
InfoLabel.Size = UDim2.new(1, 0, 0, 20)
InfoLabel.BackgroundTransparency = 1
InfoLabel.Font = Enum.Font.SourceSansItalic
InfoLabel.TextSize = 10
InfoLabel.Text = "Target: All, Others, Me, Nick" -- <<< (MINI) Teks diringkas
InfoLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
InfoLabel.TextXAlignment = Enum.TextXAlignment.Left
InfoLabel.TextWrapped = true
InfoLabel.LayoutOrder = 2 -- [DIUBAH v14]
InfoLabel.Parent = headSizeOptionsContainer -- [DIUBAH v14]


-- == [BARU v8] Master ESP Toggle (Gaya ArexansTools) ==
local headerContainer = Instance.new("Frame")
headerContainer.Name = "MasterHeaderContainer"
headerContainer.Size = UDim2.new(1, 0, 0, 25)
headerContainer.BackgroundTransparency = 1
headerContainer.LayoutOrder = 3 -- Urutan Tampil
headerContainer.Parent = ContentFrame

local collapseButton = Instance.new("TextButton", headerContainer)
collapseButton.Size = UDim2.new(1, 0, 1, 0)
collapseButton.Position = UDim2.new(0, 0, 0, 0)
collapseButton.BackgroundTransparency = 1
collapseButton.Text = ""
collapseButton.AutoButtonColor = false

local titleLabel = Instance.new("TextLabel", collapseButton)
titleLabel.Size = UDim2.new(1, -45, 1, 0) -- Beri ruang untuk 2 ikon
titleLabel.Position = UDim2.new(0, 25, 0, 0) -- Indent untuk ikon gear
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.SourceSans
titleLabel.TextSize = 11 -- <<< (MINI) Font diperkecil
titleLabel.Text = "Tampilkan ESP"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Active = false -- [BARU v10] Agar tidak memblokir klik pada collapseButton

local triangleIcon = Instance.new("TextLabel", collapseButton)
triangleIcon.Size = UDim2.new(0, 20, 1, 0)
triangleIcon.Position = UDim2.new(1, -20, 0, 0)
triangleIcon.BackgroundTransparency = 1
triangleIcon.Font = Enum.Font.SourceSansBold
triangleIcon.TextSize = 16
triangleIcon.Text = isMasterEspEnabled and "▲" or "▼" -- Set status awal
triangleIcon.TextColor3 = Color3.fromRGB(255, 255, 255)
triangleIcon.TextXAlignment = Enum.TextXAlignment.Right
triangleIcon.Active = false -- [BARU v10] Agar tidak memblokir klik pada collapseButton

local settingsButton = Instance.new("TextButton", headerContainer)
settingsButton.Name = "SettingsButton"
settingsButton.Size = UDim2.new(0, 20, 0, 20)
settingsButton.Position = UDim2.new(0, 0, 0.5, -10)
settingsButton.BackgroundTransparency = 1
settingsButton.Text = "⚙️"
settingsButton.TextColor3 = Color3.fromRGB(200, 200, 200)
settingsButton.TextSize = 16
settingsButton.Font = Enum.Font.SourceSansBold
settingsButton.TextXAlignment = Enum.TextXAlignment.Left

-- == [BARU v8] Kontainer untuk Opsi ESP ==
local espOptionsContainer = Instance.new("Frame", ContentFrame)
espOptionsContainer.Name = "EspOptionsContainer"
espOptionsContainer.Size = UDim2.new(1, 0, 0, 0) -- Ukuran Y Otomatis
espOptionsContainer.AutomaticSize = Enum.AutomaticSize.Y
espOptionsContainer.BackgroundTransparency = 1
espOptionsContainer.LayoutOrder = 4 -- Tepat di bawah master toggle
espOptionsContainer.Visible = isMasterEspEnabled -- Set visibilitas awal
espOptionsContainer.ClipsDescendants = true

local espOptionsLayout = Instance.new("UIListLayout", espOptionsContainer)
espOptionsLayout.Padding = UDim.new(0, 2)
espOptionsLayout.SortOrder = Enum.SortOrder.LayoutOrder

local espOptionsPadding = Instance.new("UIPadding", espOptionsContainer)
espOptionsPadding.PaddingLeft = UDim.new(0, 10) -- Indent opsi


-- == ESP Toggles (DIPINDAHKAN ke espOptionsContainer) ==
local EspNameToggleFrame, setEspNameSwitchState = createToggleSwitch(espOptionsContainer, "ESP Nama/Jarak", IsEspNameEnabled, function(state) -- << PARENT DIUBAH
    ToggleESPName(state)
end)
EspNameToggleFrame.LayoutOrder = 1 -- << URUTAN DIUBAH
-- [PERBAIKAN v11] Dihapus: EspNameToggleFrame.Visible = isMasterEspEnabled

local EspHealthToggleFrame, setEspHealthSwitchState = createToggleSwitch(espOptionsContainer, "ESP Health", IsEspHealthBarEnabled, function(state) -- << PARENT DIUBAH
    ToggleESPHealthBar(state)
end)
EspHealthToggleFrame.LayoutOrder = 2 -- << URUTAN DIUBAH
-- [PERBAIKAN v11] Dihapus: EspHealthToggleFrame.Visible = isMasterEspEnabled

local EspBodyToggleFrame, setEspBodySwitchState = createToggleSwitch(espOptionsContainer, "ESP Tubuh", IsEspBodyEnabled, function(state) -- << PARENT DIUBAH
    ToggleESPBody(state)
end)
EspBodyToggleFrame.LayoutOrder = 3 -- << URUTAN DIUBAH
-- [PERBAIKAN v11] Dihapus: EspBodyToggleFrame.Visible = isMasterEspEnabled

local EspLineToggleFrame, setEspLineSwitchState = createToggleSwitch(espOptionsContainer, "ESP Garis", IsEspLineEnabled, function(state) -- << PARENT DIUBAH
    ToggleESPLine(state)
end)
EspLineToggleFrame.LayoutOrder = 4 -- << URUTAN DIUBAH
-- [PERBAIKAN v11] Dihapus: EspLineToggleFrame.Visible = isMasterEspEnabled

-- == [BARU v8] Logika untuk Master ESP Toggle baru ==
collapseButton.MouseButton1Click:Connect(function()
    isMasterEspEnabled = not isMasterEspEnabled
    triangleIcon.Text = isMasterEspEnabled and "▲" or "▼"
    espOptionsContainer.Visible = isMasterEspEnabled

    -- Sinkronkan semua toggle anak saat master di-klik
    -- Hanya ubah status fitur jika master di-toggle
    ToggleESPName(isMasterEspEnabled)
    ToggleESPHealthBar(isMasterEspEnabled)
    ToggleESPBody(isMasterEspEnabled)
    ToggleESPLine(isMasterEspEnabled)
    
    setEspNameSwitchState(isMasterEspEnabled)
    setEspHealthSwitchState(isMasterEspEnabled)
    setEspBodySwitchState(isMasterEspEnabled)
    setEspLineSwitchState(isMasterEspEnabled)
end)

settingsButton.MouseButton1Click:Connect(function()
    -- Tampilkan frame pengaturan, sembunyikan frame konten
    EspSettingsFrame.Visible = true
    ContentFrame.Visible = false
end)


-- == Aimbot Toggles (BARU dari cit.lua) ==
local AimbotToggleFrame, setAimbotSwitchState
local aimbotOptionsContainer -- [BARU v14] Deklarasi

AimbotToggleFrame, setAimbotSwitchState = createToggleSwitch(ContentFrame, "Aimbot", AimbotEnabled, function(state) -- <<< (MINI) Teks diringkas
    AimbotEnabled = state
    if aimbotOptionsContainer then aimbotOptionsContainer.Visible = state end -- [BARU v14]
end)
AimbotToggleFrame.LayoutOrder = 5

-- == [BARU v14] Kontainer untuk Opsi Aimbot ==
aimbotOptionsContainer = Instance.new("Frame", ContentFrame)
aimbotOptionsContainer.Name = "AimbotOptionsContainer"
aimbotOptionsContainer.Size = UDim2.new(1, 0, 0, 0) -- Ukuran Y Otomatis
aimbotOptionsContainer.AutomaticSize = Enum.AutomaticSize.Y
aimbotOptionsContainer.BackgroundTransparency = 1
aimbotOptionsContainer.LayoutOrder = 6 -- Tepat di bawah toggle
aimbotOptionsContainer.Visible = AimbotEnabled -- Set visibilitas awal
aimbotOptionsContainer.ClipsDescendants = true

local aimbotOptionsLayout = Instance.new("UIListLayout", aimbotOptionsContainer)
aimbotOptionsLayout.Padding = UDim.new(0, 2)
aimbotOptionsLayout.SortOrder = Enum.SortOrder.LayoutOrder

local aimbotOptionsPadding = Instance.new("UIPadding", aimbotOptionsContainer)
aimbotOptionsPadding.PaddingLeft = UDim.new(0, 10) -- Indent opsi


local WallCheckToggleFrame, setWallCheckSwitchState = createToggleSwitch(aimbotOptionsContainer, "WallCheck", WallCheck, function(state) -- [DIUBAH v14] Parent
    WallCheck = state
end)
WallCheckToggleFrame.LayoutOrder = 1 -- [DIUBAH v14]

local ShowFovToggleFrame, setShowFovSwitchState = createToggleSwitch(aimbotOptionsContainer, "Show FOV", ShowFOV, function(state) -- [DIUBAH v14] Parent
    ShowFOV = state
end)
ShowFovToggleFrame.LayoutOrder = 2 -- [DIUBAH v14]
if not FOVCircle then
    ShowFovToggleFrame.Visible = false -- Sembunyikan toggle jika Drawing lib tidak ada
end

-- == AimPart Button (BARU dari cit.lua) ==
local aimPartButton = Instance.new("TextButton")
aimPartButton.Name = "AimPartButton"
aimPartButton.Size = UDim2.new(1, 0, 0, 25)
aimPartButton.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
aimPartButton.Font = Enum.Font.SourceSans
aimPartButton.TextSize = 11 -- <<< (MINI) Font diperkecil
aimPartButton.TextColor3 = Color3.new(1,1,1)
aimPartButton.LayoutOrder = 3 -- [DIUBAH v14]
aimPartButton.Parent = aimbotOptionsContainer -- [DIUBAH v14]
local apCorner = Instance.new("UICorner", aimPartButton); apCorner.CornerRadius = UDim.new(0, 4)
local parts = {"Head", "Torso", "UpperTorso", "LowerTorso"}
aimPartButton.Text = "Part: " .. AimPart -- <<< (MINI) Teks diringkas
aimPartButton.MouseButton1Click:Connect(function()
    local i = table.find(parts, AimPart) or 1
    i = i % #parts + 1
    AimPart = parts[i]
    aimPartButton.Text = "Part: " .. AimPart -- <<< (MINI) Teks diringkas
end)

-- == FOV Adjust (BARU dari cit.lua) ==
local FovFrame = Instance.new("Frame")
FovFrame.Name = "FovFrame"
FovFrame.Size = UDim2.new(1, 0, 0, 25)
FovFrame.BackgroundTransparency = 1
FovFrame.LayoutOrder = 4 -- [DIUBAH v14]
FovFrame.Parent = aimbotOptionsContainer -- [DIUBAH v14]
local FovLayout = Instance.new("UIListLayout")
FovLayout.FillDirection = Enum.FillDirection.Horizontal
FovLayout.VerticalAlignment = Enum.VerticalAlignment.Center
FovLayout.Padding = UDim.new(0, 5)
FovLayout.Parent = FovFrame

local FovLabel = Instance.new("TextLabel")
FovLabel.Size = UDim2.new(0.5, -5, 1, 0)
FovLabel.BackgroundTransparency = 1
FovLabel.Font = Enum.Font.SourceSans
FovLabel.TextSize = 11 -- <<< (MINI) Font diperkecil
FovLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
FovLabel.Text = "FOV: " .. FOV
FovLabel.TextXAlignment = Enum.TextXAlignment.Left
FovLabel.Parent = FovFrame

local FovPlusBtn = Instance.new("TextButton")
FovPlusBtn.Size = UDim2.new(0.25, -2.5, 1, 0)
FovPlusBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
FovPlusBtn.Text = "+"
FovPlusBtn.Font = Enum.Font.SourceSansBold
FovPlusBtn.TextSize = 12 -- <<< (MINI) Font diperkecil
FovPlusBtn.TextColor3 = Color3.new(1,1,1)
FovPlusBtn.Parent = FovFrame
local fpCorner = Instance.new("UICorner", FovPlusBtn); fpCorner.CornerRadius = UDim.new(0, 4)

local FovMinusBtn = Instance.new("TextButton")
FovMinusBtn.Size = UDim2.new(0.25, -2.5, 1, 0)
FovMinusBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
FovMinusBtn.Text = "-"
FovMinusBtn.Font = Enum.Font.SourceSansBold
FovMinusBtn.TextSize = 12 -- <<< (MINI) Font diperkecil
FovMinusBtn.TextColor3 = Color3.new(1,1,1)
FovMinusBtn.Parent = FovFrame
local fmCorner = Instance.new("UICorner", FovMinusBtn); fmCorner.CornerRadius = UDim.new(0, 4)

FovPlusBtn.MouseButton1Click:Connect(function()
    FOV = math.clamp(FOV + 10, 50, 500)
    FovLabel.Text = "FOV: " .. FOV
end)
FovMinusBtn.MouseButton1Click:Connect(function()
    FOV = math.clamp(FOV - 10, 50, 500)
    FovLabel.Text = "FOV: " .. FOV
end)

-- == Smoothness Adjust (BARU dari cit.lua) ==
local SmoothFrame = Instance.new("Frame")
SmoothFrame.Name = "SmoothFrame"
SmoothFrame.Size = UDim2.new(1, 0, 0, 25)
SmoothFrame.BackgroundTransparency = 1
SmoothFrame.LayoutOrder = 5 -- [DIUBAH v14]
SmoothFrame.Parent = aimbotOptionsContainer -- [DIUBAH v14]
local SmoothLayout = Instance.new("UIListLayout")
SmoothLayout.FillDirection = Enum.FillDirection.Horizontal
SmoothLayout.VerticalAlignment = Enum.VerticalAlignment.Center
SmoothLayout.Padding = UDim.new(0, 5)
SmoothLayout.Parent = SmoothFrame

local SmoothLabel = Instance.new("TextLabel")
SmoothLabel.Size = UDim2.new(0.5, -5, 1, 0)
SmoothLabel.BackgroundTransparency = 1
SmoothLabel.Font = Enum.Font.SourceSans
SmoothLabel.TextSize = 11 -- <<< (MINI) Font diperkecil
SmoothLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
SmoothLabel.Text = "Smooth: " .. Smoothness
SmoothLabel.TextXAlignment = Enum.TextXAlignment.Left
SmoothLabel.Parent = SmoothFrame

local SmoothPlusBtn = Instance.new("TextButton")
SmoothPlusBtn.Size = UDim2.new(0.25, -2.5, 1, 0)
SmoothPlusBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
SmoothPlusBtn.Text = "+"
SmoothPlusBtn.Font = Enum.Font.SourceSansBold
SmoothPlusBtn.TextSize = 12 -- <<< (MINI) Font diperkecil
SmoothPlusBtn.TextColor3 = Color3.new(1,1,1)
SmoothPlusBtn.Parent = SmoothFrame
local spCorner = Instance.new("UICorner", SmoothPlusBtn); spCorner.CornerRadius = UDim.new(0, 4)

local SmoothMinusBtn = Instance.new("TextButton")
SmoothMinusBtn.Size = UDim2.new(0.25, -2.5, 1, 0)
SmoothMinusBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
SmoothMinusBtn.Text = "-"
SmoothMinusBtn.Font = Enum.Font.SourceSansBold
SmoothMinusBtn.TextSize = 12 -- <<< (MINI) Font diperkecil
SmoothMinusBtn.TextColor3 = Color3.new(1,1,1)
SmoothMinusBtn.Parent = SmoothFrame
local smCorner = Instance.new("UICorner", SmoothMinusBtn); smCorner.CornerRadius = UDim.new(0, 4)

SmoothPlusBtn.MouseButton1Click:Connect(function()
    Smoothness = math.clamp(Smoothness + 0.05, 0.01, 1)
    SmoothLabel.Text = "Smooth: " .. string.format("%.2f", Smoothness)
end)
SmoothMinusBtn.MouseButton1Click:Connect(function()
    Smoothness = math.clamp(Smoothness - 0.05, 0.01, 1)
    SmoothLabel.Text = "Smooth: " .. string.format("%.2f", Smoothness)
end)

-- == [BARU v13] UI FITUR CROSSHAIR ==
if Drawing then -- Hanya tambahkan UI jika 'Drawing' ada
    local CrosshairToggleFrame, setCrosshairSwitchState
    local crosshairOptionsContainer -- [BARU v14] Deklarasi

    -- 1. Toggle Crosshair
    CrosshairToggleFrame, setCrosshairSwitchState = createToggleSwitch(ContentFrame, "Crosshair", isCrosshairEnabled, function(state)
        isCrosshairEnabled = state
        if crosshairOptionsContainer then crosshairOptionsContainer.Visible = state end -- [BARU v14]
        -- [PERBAIKAN v16] Menghapus panggilan DrawCrosshair() dari sini.
        -- Loop RenderStepped akan menanganinya.
    end)
    CrosshairToggleFrame.LayoutOrder = 7 -- [DIUBAH v14]
    
    -- == [BARU v14] Kontainer untuk Opsi Crosshair ==
    crosshairOptionsContainer = Instance.new("Frame", ContentFrame)
    crosshairOptionsContainer.Name = "CrosshairOptionsContainer"
    crosshairOptionsContainer.Size = UDim2.new(1, 0, 0, 0) -- Ukuran Y Otomatis
    crosshairOptionsContainer.AutomaticSize = Enum.AutomaticSize.Y
    crosshairOptionsContainer.BackgroundTransparency = 1
    crosshairOptionsContainer.LayoutOrder = 8 -- Tepat di bawah toggle
    crosshairOptionsContainer.Visible = isCrosshairEnabled -- Set visibilitas awal
    crosshairOptionsContainer.ClipsDescendants = true
    
    local crosshairOptionsLayout = Instance.new("UIListLayout", crosshairOptionsContainer)
    crosshairOptionsLayout.Padding = UDim.new(0, 2)
    crosshairOptionsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local crosshairOptionsPadding = Instance.new("UIPadding", crosshairOptionsContainer)
    crosshairOptionsPadding.PaddingLeft = UDim.new(0, 10) -- Indent opsi

    
    -- 2. Tombol Tipe Crosshair
    local crosshairTypeButton = Instance.new("TextButton")
    crosshairTypeButton.Name = "CrosshairTypeButton"
    crosshairTypeButton.Size = UDim2.new(1, 0, 0, 25)
    crosshairTypeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    crosshairTypeButton.Font = Enum.Font.SourceSans
    crosshairTypeButton.TextSize = 11
    crosshairTypeButton.TextColor3 = Color3.new(1,1,1)
    crosshairTypeButton.LayoutOrder = 1 -- [DIUBAH v14]
    crosshairTypeButton.Parent = crosshairOptionsContainer -- [DIUBAH v14]
    local ctCorner = Instance.new("UICorner", crosshairTypeButton); ctCorner.CornerRadius = UDim.new(0, 4)
    
    crosshairTypeButton.Text = "Tipe: " .. crosshairTypes[currentCrosshairType]
    crosshairTypeButton.MouseButton1Click:Connect(function()
        currentCrosshairType = currentCrosshairType % #crosshairTypes + 1
        crosshairTypeButton.Text = "Tipe: " .. crosshairTypes[currentCrosshairType]
    end)
    
    -- 3. Pengatur Warna HSV Crosshair
    local crosshairColorGroup = createHSVColorPickerGroup(crosshairOptionsContainer, "Warna Crosshair", crosshairColor, function(newColor) -- [DIUBAH v14] Parent
        crosshairColor = newColor
    end)
    crosshairColorGroup.LayoutOrder = 2 -- [DIUBAH v14]

end -- Akhir dari 'if Drawing'


--====================================================================--
--                           KONEKSI EVENT                          --
--====================================================================--

-- Minimize Button Logic
local isMinimized = false
local originalSize = MainFrame.Size -- <-- Mengambil ukuran 'mini' (180x220) sebagai ukuran asli
local minimizedSize = UDim2.new(originalSize.X.Scale, originalSize.X.Offset, 0, TitleBar.Size.Y.Offset)
local minimizeTweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)

MinimizeButton.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    local targetSize
    if isMinimized then
        originalSize = MainFrame.Size -- [BARU v9] Simpan ukuran saat ini sebelum minimize
        targetSize = minimizedSize
    else
        targetSize = originalSize
    end
    
    ContentFrame.Visible = not isMinimized -- Hide/show content instantly
    EspSettingsFrame.Visible = false -- [BARU v8] Selalu sembunyikan pengaturan saat minimize
    
    -- [[ PERBAIKAN v12 DIMULAI DI SINI ]]
    -- Sembunyikan pegangan pengubah ukuran saat diminimalkan agar tidak tumpang tindih dengan tombol X
    MainResizeHandle.Visible = not isMinimized 
    -- [[ PERBAIKAN v12 SELESAI ]]

    TweenService:Create(MainFrame, minimizeTweenInfo, {Size = targetSize}):Play()
    MinimizeButton.Text = isMinimized and "+" or "-" -- Change button text
end)

-- Close Button Logic
CloseButton.MouseButton1Click:Connect(function()
    saveGuiPositions() -- [BARU v9] Simpan posisi/ukuran saat ditutup
    if isHeadSizeActive then toggleHeadSizeFeature(false) end
    if IsEspNameEnabled then ToggleESPName(false) end -- Turn off ESP on close
    if IsEspBodyEnabled then ToggleESPBody(false) end
    if IsEspLineEnabled then ToggleESPLine(false) end
    if IsEspHealthBarEnabled then ToggleESPHealthBar(false) end
    AimbotEnabled = false -- Turn off Aimbot on close
    isCrosshairEnabled = false -- [BARU v13] Matikan crosshair saat ditutup
    if FOVCircle then FOVCircle.Visible = false end
    ScreenGui:Destroy()
end)

-- Target TextBox Logic (Head Size)
TargetTextBox.FocusLost:Connect(function(enterPressed)
    local newTarget = TargetTextBox.Text
    if newTarget ~= currentTarget then
        -- [PERUBAHAN v7] Tidak perlu meng-apply manual, cukup set variabel.
        -- Loop Heartbeat akan menangani sisanya secara otomatis.
        currentTarget = newTarget
        print("Target set to:", currentTarget)
    end
end)

-- Size TextBox Logic (Head Size)
SizeTextBox.FocusLost:Connect(function(enterPressed)
    local newSize = tonumber(SizeTextBox.Text)
    if newSize and newSize > 0 then
        if newSize ~= currentSize then
            -- [PERUBAHAN v7] Tidak perlu meng-apply manual, cukup set variabel.
            -- Loop Heartbeat akan menangani sisanya secara otomatis.
            currentSize = newSize
            print("Size set to:", currentSize)
        end
    else
        SizeTextBox.Text = tostring(currentSize)
        print("Invalid size input, reverting text to:", currentSize)
    end
end)

-- Cleanup on character removal or player leaving
local function playerRemoving(player)
    if player == LocalPlayer then return end
    
    -- [PERUBAHAN v7] Panggil fungsi revert spesifik
    revertHeadSizeForPlayer(player)
    
    -- Clean up ESP cache for the leaving player (dari esp.lua)
    cleanupPlayerESP(player.UserId)
end
local playerRemovingConn = Players.PlayerRemoving:Connect(playerRemoving)

-- Handle character respawns
local function characterAdded(character)
    -- [PERUBAHAN v7] Logika Headsize dihapus dari sini.
    -- Loop Heartbeat (startHeadSizeLoop) sekarang menangani pemain baru/respawn secara instan.
    
    -- Logika ESP akan ditangani secara otomatis oleh loop UpdateESP (RenderStepped)
    
    -- ( task.wait(0.5) dan applyHeadSizeToPlayer() DIHAPUS DARI SINI )
end

local characterAddedConnections = {}
local function setupCharacterAdded(player)
	if characterAddedConnections[player] then characterAddedConnections[player]:Disconnect() end
	if player.Character then characterAdded(player.Character) end
	characterAddedConnections[player] = player.CharacterAdded:Connect(characterAdded)
end
local playerAddedConn = Players.PlayerAdded:Connect(setupCharacterAdded)
for _, player in ipairs(Players:GetPlayers()) do setupCharacterAdded(player) end

-- Cleanup when script stops
ScreenGui.Destroying:Connect(function()
    -- Matikan semua fitur
    if isHeadSizeActive then toggleHeadSizeFeature(false) end
    if IsEspNameEnabled then ToggleESPName(false) end
    if IsEspBodyEnabled then ToggleESPBody(false) end
    if IsEspLineEnabled then ToggleESPLine(false) end
    if IsEspHealthBarEnabled then ToggleESPHealthBar(false) end
    AimbotEnabled = false
    isCrosshairEnabled = false -- [BARU v13]
    
    -- Hancurkan elemen Drawing
    if FOVCircle then FOVCircle:Destroy() end
    if crosshairElements and #crosshairElements > 0 then -- [BARU v13]
        for _, obj in ipairs(crosshairElements) do
            pcall(obj.Destroy, obj) -- Gunakan pcall untuk keamanan
        end
    end
    
    -- Hentikan semua koneksi
    if EspRenderConnection then EspRenderConnection:Disconnect() end -- (dari esp.lua)
    if AimbotRenderConnection then AimbotRenderConnection:Disconnect() end
    if headSizeLoopConnection then headSizeLoopConnection:Disconnect() end
    
    if playerRemovingConn then playerRemovingConn:Disconnect() end
    if playerAddedConn then playerAddedConn:Disconnect() end
    for player, conn in pairs(characterAddedConnections) do if conn then conn:Disconnect() end end
    characterAddedConnections = {}

    -- Hapus semua cache ESP
    cleanupAllESP() -- (dari esp.lua)
    
    print("Skrip Gabungan dibersihkan.")
end)

-- Initial State Updates
setHeadSizeSwitchState(isHeadSizeActive) -- Set initial visual state for switches
-- [DIHAPUS v8] setMasterEspSwitchState(isMasterEspEnabled) -- (Sudah diatur oleh UI baru)
setEspNameSwitchState(IsEspNameEnabled) -- (dari esp.lua)
setEspHealthSwitchState(IsEspHealthBarEnabled) -- (dari esp.lua)
setEspBodySwitchState(IsEspBodyEnabled) -- (dari esp.lua)
setEspLineSwitchState(IsEspLineEnabled) -- (dari esp.lua)
setAimbotSwitchState(AimbotEnabled)
setWallCheckSwitchState(WallCheck)
-- setTeamCheckSwitchState(TeamCheck) -- <<< DIHAPUS (Sekarang Otomatis)
setShowFovSwitchState(ShowFOV)

-- [BARU v13] Tidak perlu set state awal untuk crosshair, karena UI dibuat di atas
-- dan fungsi createToggleSwitch sudah menangani state awalnya (isCrosshairEnabled = false)

manageEspConnection() -- Start ESP loop if needed on load (dari esp.lua)
toggleHeadSizeFeature(isHeadSizeActive) -- [PERUBAHAN v7] Panggil fungsi toggle utama untuk memulai loop jika 'true'

loadGuiPositions() -- [BARU v9] Terapkan posisi/ukuran yang disimpan
print("GUI Gabungan (Super Mini) dimuat dengan ESP baru, Headsize Instan, dan Crosshair Kustom.")


