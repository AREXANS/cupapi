local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Library = {
    Version = "2.0.0",
    Theme = {
        Background = Color3.fromRGB(12, 12, 16),
        Sidebar = Color3.fromRGB(16, 16, 22),
        Element = Color3.fromRGB(24, 24, 32),
        ElementHover = Color3.fromRGB(32, 32, 42),
        Accent = Color3.fromRGB(0, 170, 255),
        AccentGlow = Color3.fromRGB(0, 210, 255),
        Text = Color3.fromRGB(250, 250, 255),
        TextDim = Color3.fromRGB(150, 150, 160),
        Border = Color3.fromRGB(35, 35, 45),
        Font = Enum.Font.GothamSemibold,
        Corner = UDim.new(0, 6)
    },
    Connections = {},
    Flags = {},
    Toggled = true,
}

-- Utility Functions
function Library:Tween(obj, props, time, easingStyle, easingDir)
    if not obj then return end
    time = time or 0.25
    easingStyle = easingStyle or Enum.EasingStyle.Quart
    easingDir = easingDir or Enum.EasingDirection.Out
    local tween = TweenService:Create(obj, TweenInfo.new(time, easingStyle, easingDir), props)
    tween:Play()
    return tween
end

function Library:CreateRipple(Parent)
    task.spawn(function()
        local mousePos = UserInputService:GetMouseLocation()
        local ripple = Instance.new("Frame")
        ripple.Name = "Ripple"
        ripple.Parent = Parent
        ripple.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        ripple.BackgroundTransparency = 0.8
        ripple.ZIndex = Parent.ZIndex + 1
        ripple.ClipsDescendants = true

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = ripple

        local relativeX = mousePos.X - Parent.AbsolutePosition.X
        local relativeY = mousePos.Y - Parent.AbsolutePosition.Y - 36 -- Account for gui inset roughly

        ripple.Position = UDim2.new(0, relativeX, 0, relativeY)
        ripple.Size = UDim2.new(0, 0, 0, 0)
        ripple.AnchorPoint = Vector2.new(0.5, 0.5)

        local targetSize = math.max(Parent.AbsoluteSize.X, Parent.AbsoluteSize.Y) * 1.5
        local tween = Library:Tween(ripple, {Size = UDim2.new(0, targetSize, 0, targetSize), BackgroundTransparency = 1}, 0.5)

        tween.Completed:Wait()
        ripple:Destroy()
    end)
end

function Library:MakeDraggable(topbar, main)
    local dragging = false
    local dragInput, mousePos, framePos

    topbar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            mousePos = input.Position
            framePos = main.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    topbar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            Library:Tween(main, {Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)}, 0.1, Enum.EasingStyle.Linear)
        end
    end)
end

-- Notification System
local NotifGui = Instance.new("ScreenGui")
NotifGui.Name = "BlueGlowNotifs"
NotifGui.ResetOnSpawn = false
NotifGui.IgnoreGuiInset = true
pcall(function() NotifGui.Parent = CoreGui end)
if not NotifGui.Parent then NotifGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end

local NotifLayout = Instance.new("Frame")
NotifLayout.Name = "NotifContainer"
NotifLayout.Parent = NotifGui
NotifLayout.Size = UDim2.new(0, 250, 1, -20)
NotifLayout.Position = UDim2.new(1, -260, 0, 10)
NotifLayout.BackgroundTransparency = 1

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Parent = NotifLayout
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
UIListLayout.Padding = UDim.new(0, 10)

function Library:Notify(options, legacyDuration)
    if type(options) == "string" then
        options = { Title = "Pandu Hub", Content = options, Duration = legacyDuration or 3 }
    end
    options = options or {}
    local title = options.Title or "Notification"
    local text = options.Content or options.Description or options.Text or "This is a notification."
    local duration = options.Duration or options.Time or 3

    local NotifFrame = Instance.new("Frame")
    NotifFrame.Name = "NotifFrame"
    NotifFrame.Parent = NotifLayout
    NotifFrame.Size = UDim2.new(1, 0, 0, 70)
    NotifFrame.BackgroundColor3 = Library.Theme.Sidebar
    NotifFrame.BackgroundTransparency = 1

    local Stroke = Instance.new("UIStroke")
    Stroke.Parent = NotifFrame
    Stroke.Color = Library.Theme.Accent
    Stroke.Thickness = 1
    Stroke.Transparency = 1

    Instance.new("UICorner", NotifFrame).CornerRadius = Library.Theme.Corner

    local NTitle = Instance.new("TextLabel")
    NTitle.Parent = NotifFrame
    NTitle.Size = UDim2.new(1, -10, 0, 20)
    NTitle.Position = UDim2.new(0, 10, 0, 10)
    NTitle.BackgroundTransparency = 1
    NTitle.Text = title
    NTitle.TextColor3 = Library.Theme.AccentGlow
    NTitle.TextSize = 14
    NTitle.Font = Enum.Font.GothamBold
    NTitle.TextXAlignment = Enum.TextXAlignment.Left
    NTitle.TextTransparency = 1

    local NText = Instance.new("TextLabel")
    NText.Parent = NotifFrame
    NText.Size = UDim2.new(1, -20, 0, 30)
    NText.Position = UDim2.new(0, 10, 0, 30)
    NText.BackgroundTransparency = 1
    NText.Text = text
    NText.TextColor3 = Library.Theme.Text
    NText.TextSize = 12
    NText.Font = Library.Theme.Font
    NText.TextXAlignment = Enum.TextXAlignment.Left
    NText.TextWrapped = true
    NText.TextTransparency = 1

    local TimerBar = Instance.new("Frame")
    TimerBar.Parent = NotifFrame
    TimerBar.Size = UDim2.new(1, 0, 0, 2)
    TimerBar.Position = UDim2.new(0, 0, 1, -2)
    TimerBar.BackgroundColor3 = Library.Theme.Accent
    TimerBar.BackgroundTransparency = 1
    Instance.new("UICorner", TimerBar).CornerRadius = UDim.new(1, 0)

    -- Animate In
    Library:Tween(NotifFrame, {BackgroundTransparency = 0}, 0.3)
    Library:Tween(Stroke, {Transparency = 0.5}, 0.3)
    Library:Tween(NTitle, {TextTransparency = 0}, 0.3)
    Library:Tween(NText, {TextTransparency = 0}, 0.3)
    Library:Tween(TimerBar, {BackgroundTransparency = 0}, 0.3)

    Library:Tween(TimerBar, {Size = UDim2.new(0, 0, 0, 2)}, duration, Enum.EasingStyle.Linear)

    task.delay(duration, function()
        Library:Tween(NotifFrame, {BackgroundTransparency = 1}, 0.3)
        Library:Tween(Stroke, {Transparency = 1}, 0.3)
        Library:Tween(NTitle, {TextTransparency = 1}, 0.3)
        Library:Tween(NText, {TextTransparency = 1}, 0.3)
        Library:Tween(TimerBar, {BackgroundTransparency = 1}, 0.3)
        task.wait(0.3)
        NotifFrame:Destroy()
    end)
end

function Library:CreateWindow(options)
    options = options or {}
    local Title = options.Name or "Glow UI Mini"
    local CustomSize = options.Size or UDim2.new(0, 480, 0, 300) -- Mini Size Default
    local HideBind = options.HideBind or Enum.KeyCode.RightControl

    -- Cleanup old guis
    for _, v in pairs(CoreGui:GetChildren()) do
        if v.Name == "BlueGlowUI" then v:Destroy() end
    end
    if Players.LocalPlayer then
        local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
        if pg then
            for _, v in pairs(pg:GetChildren()) do
                if v.Name == "BlueGlowUI" then v:Destroy() end
            end
        end
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "BlueGlowUI"
    ScreenGui.IgnoreGuiInset = true
    ScreenGui.ResetOnSpawn = false
    pcall(function() ScreenGui.Parent = CoreGui end)
    if not ScreenGui.Parent then ScreenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end

    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Parent = ScreenGui
    Main.Size = CustomSize
    Main.Position = UDim2.new(0.5, -CustomSize.X.Offset/2, 0.5, -CustomSize.Y.Offset/2)
    Main.BackgroundColor3 = Library.Theme.Background
    Main.ClipsDescendants = false
    Instance.new("UICorner", Main).CornerRadius = Library.Theme.Corner

    -- Outer Glow Effect
    local Glow = Instance.new("ImageLabel")
    Glow.Name = "Glow"
    Glow.Parent = Main
    Glow.Size = UDim2.new(1, 40, 1, 40)
    Glow.Position = UDim2.new(0, -20, 0, -20)
    Glow.BackgroundTransparency = 1
    Glow.Image = "rbxassetid://5028857472"
    Glow.ImageColor3 = Library.Theme.AccentGlow
    Glow.ImageTransparency = 0.5
    Glow.ScaleType = Enum.ScaleType.Slice
    Glow.SliceCenter = Rect.new(24, 24, 276, 276)
    Glow.ZIndex = 0

    local MainStroke = Instance.new("UIStroke")
    MainStroke.Parent = Main
    MainStroke.Color = Library.Theme.Border
    MainStroke.Thickness = 1
    MainStroke.Transparency = 0.2

    -- Topbar
    local Topbar = Instance.new("Frame")
    Topbar.Name = "Topbar"
    Topbar.Parent = Main
    Topbar.Size = UDim2.new(1, 0, 0, 36)
    Topbar.BackgroundTransparency = 1
    Library:MakeDraggable(Topbar, Main)

    local TopbarTitle = Instance.new("TextLabel")
    TopbarTitle.Parent = Topbar
    TopbarTitle.Size = UDim2.new(1, -100, 1, 0)
    TopbarTitle.Position = UDim2.new(0, 15, 0, 0)
    TopbarTitle.BackgroundTransparency = 1
    TopbarTitle.Text = Title
    TopbarTitle.TextColor3 = Library.Theme.Accent
    TopbarTitle.TextSize = 14
    TopbarTitle.Font = Enum.Font.GothamBold
    TopbarTitle.TextXAlignment = Enum.TextXAlignment.Left

    local TopTitleStroke = Instance.new("UIStroke")
    TopTitleStroke.Parent = TopbarTitle
    TopTitleStroke.Color = Library.Theme.AccentGlow
    TopTitleStroke.Thickness = 0.4
    TopTitleStroke.Transparency = 0.8

    local CloseBtn = Instance.new("ImageButton")
    CloseBtn.Parent = Topbar
    CloseBtn.Size = UDim2.new(0, 16, 0, 16)
    CloseBtn.Position = UDim2.new(1, -25, 0.5, -8)
    CloseBtn.BackgroundTransparency = 1
    CloseBtn.Image = "rbxassetid://3926305904"
    CloseBtn.ImageRectOffset = Vector2.new(924, 724)
    CloseBtn.ImageRectSize = Vector2.new(36, 36)
    CloseBtn.ImageColor3 = Library.Theme.TextDim

    CloseBtn.MouseEnter:Connect(function() Library:Tween(CloseBtn, {ImageColor3 = Color3.fromRGB(255, 60, 60)}, 0.2) end)
    CloseBtn.MouseLeave:Connect(function() Library:Tween(CloseBtn, {ImageColor3 = Library.Theme.TextDim}, 0.2) end)
    CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

    local TopbarLine = Instance.new("Frame")
    TopbarLine.Parent = Main
    TopbarLine.Size = UDim2.new(1, 0, 0, 1)
    TopbarLine.Position = UDim2.new(0, 0, 0, 36)
    TopbarLine.BackgroundColor3 = Library.Theme.Border
    TopbarLine.BorderSizePixel = 0

    -- Main Container Layout
    local ContentContainer = Instance.new("Frame")
    ContentContainer.Name = "ContentContainer"
    ContentContainer.Parent = Main
    ContentContainer.Size = UDim2.new(1, 0, 1, -37)
    ContentContainer.Position = UDim2.new(0, 0, 0, 37)
    ContentContainer.BackgroundTransparency = 1

    local Sidebar = Instance.new("ScrollingFrame")
    Sidebar.Name = "Sidebar"
    Sidebar.Parent = ContentContainer
    Sidebar.Size = UDim2.new(0, 130, 1, 0)
    Sidebar.BackgroundColor3 = Library.Theme.Sidebar
    Sidebar.BorderSizePixel = 0
    Sidebar.ScrollBarThickness = 0

    local SidebarStroke = Instance.new("UIStroke")
    SidebarStroke.Parent = Sidebar
    SidebarStroke.Color = Library.Theme.Border
    SidebarStroke.Thickness = 1

    local SidebarLayout = Instance.new("UIListLayout")
    SidebarLayout.Parent = Sidebar
    SidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
    SidebarLayout.Padding = UDim.new(0, 4)

    local SidebarPadding = Instance.new("UIPadding")
    SidebarPadding.Parent = Sidebar
    SidebarPadding.PaddingTop = UDim.new(0, 8)
    SidebarPadding.PaddingLeft = UDim.new(0, 8)
    SidebarPadding.PaddingRight = UDim.new(0, 8)
    SidebarPadding.PaddingBottom = UDim.new(0, 8)

    local PagesContainer = Instance.new("Frame")
    PagesContainer.Name = "PagesContainer"
    PagesContainer.Parent = ContentContainer
    PagesContainer.Size = UDim2.new(1, -130, 1, 0)
    PagesContainer.Position = UDim2.new(0, 130, 0, 0)
    PagesContainer.BackgroundTransparency = 1

    -- Keybind for toggling UI
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if not gameProcessed and input.KeyCode == HideBind then
            Library.Toggled = not Library.Toggled
            Main.Visible = Library.Toggled
        end
    end)

    local WindowObj = {
        Tabs = {},
        CurrentTab = nil
    }

    function WindowObj:CreateTab(options)
        options = options or {}
        local TabName = options.Name or "Tab"
        local TabIcon = options.Icon or nil

        local TabBtn = Instance.new("TextButton")
        TabBtn.Name = "Tab_" .. TabName
        TabBtn.Parent = Sidebar
        TabBtn.Size = UDim2.new(1, 0, 0, 30)
        TabBtn.BackgroundColor3 = Library.Theme.Accent
        TabBtn.BackgroundTransparency = 1
        TabBtn.Text = ""
        TabBtn.AutoButtonColor = false
        Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 4)

        local TabTitle = Instance.new("TextLabel")
        TabTitle.Parent = TabBtn
        TabTitle.Size = UDim2.new(1, -10, 1, 0)
        TabTitle.Position = UDim2.new(0, 10, 0, 0)
        TabTitle.BackgroundTransparency = 1
        TabTitle.Text = TabName
        TabTitle.TextColor3 = Library.Theme.TextDim
        TabTitle.TextSize = 13
        TabTitle.Font = Library.Theme.Font
        TabTitle.TextXAlignment = Enum.TextXAlignment.Left

        local Page = Instance.new("ScrollingFrame")
        Page.Name = "Page_" .. TabName
        Page.Parent = PagesContainer
        Page.Size = UDim2.new(1, 0, 1, 0)
        Page.BackgroundTransparency = 1
        Page.ScrollBarThickness = 2
        Page.ScrollBarImageColor3 = Library.Theme.Accent
        Page.Visible = false

        local PageLayout = Instance.new("UIListLayout")
        PageLayout.Parent = Page
        PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
        PageLayout.Padding = UDim.new(0, 6)

        local PagePadding = Instance.new("UIPadding")
        PagePadding.Parent = Page
        PagePadding.PaddingTop = UDim.new(0, 10)
        PagePadding.PaddingBottom = UDim.new(0, 10)
        PagePadding.PaddingLeft = UDim.new(0, 12)
        PagePadding.PaddingRight = UDim.new(0, 14)

        PageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            Page.CanvasSize = UDim2.new(0, 0, 0, PageLayout.AbsoluteContentSize.Y + 20)
        end)

        if not WindowObj.CurrentTab then
            WindowObj.CurrentTab = {Btn = TabBtn, Title = TabTitle, Page = Page}
            TabBtn.BackgroundTransparency = 0.9
            TabTitle.TextColor3 = Library.Theme.Accent
            Page.Visible = true
        end

        TabBtn.MouseButton1Click:Connect(function()
            if WindowObj.CurrentTab.Btn ~= TabBtn then
                Library:Tween(WindowObj.CurrentTab.Btn, {BackgroundTransparency = 1}, 0.2)
                Library:Tween(WindowObj.CurrentTab.Title, {TextColor3 = Library.Theme.TextDim}, 0.2)
                WindowObj.CurrentTab.Page.Visible = false

                WindowObj.CurrentTab = {Btn = TabBtn, Title = TabTitle, Page = Page}
                Library:Tween(TabBtn, {BackgroundTransparency = 0.9}, 0.2)
                Library:Tween(TabTitle, {TextColor3 = Library.Theme.Accent}, 0.2)
                Page.Visible = true
            end
        end)

        local TabObj = { Page = Page }

        function TabObj:CreateSection(name)
            local SectionLabel = Instance.new("TextLabel")
            SectionLabel.Name = "Section_" .. name
            SectionLabel.Parent = self.Page
            SectionLabel.Size = UDim2.new(1, 0, 0, 20)
            SectionLabel.BackgroundTransparency = 1
            SectionLabel.Text = name
            SectionLabel.TextColor3 = Library.Theme.Accent
            SectionLabel.TextSize = 12
            SectionLabel.Font = Enum.Font.GothamBold
            SectionLabel.TextXAlignment = Enum.TextXAlignment.Left
        end

        function TabObj:CreateLabel(text)
            local LabelObj = {}
            local Label = Instance.new("TextLabel")
            Label.Parent = self.Page
            Label.Size = UDim2.new(1, 0, 0, 24)
            Label.BackgroundTransparency = 1
            Label.Text = text
            Label.TextColor3 = Library.Theme.Text
            Label.TextSize = 13
            Label.Font = Library.Theme.Font
            Label.TextXAlignment = Enum.TextXAlignment.Left
            Label.TextWrapped = true

            function LabelObj:Set(newText)
                Label.Text = newText
            end

            return LabelObj
        end

        function TabObj:CreateButton(options)
            options = options or {}
            local Name = options.Name or "Button"
            local Callback = options.Callback or function() end

            local BtnFrame = Instance.new("TextButton")
            BtnFrame.Parent = self.Page
            BtnFrame.Size = UDim2.new(1, 0, 0, 32)
            BtnFrame.BackgroundColor3 = Library.Theme.Element
            BtnFrame.Text = ""
            BtnFrame.AutoButtonColor = false
            BtnFrame.ClipsDescendants = true
            Instance.new("UICorner", BtnFrame).CornerRadius = UDim.new(0, 4)

            local BtnStroke = Instance.new("UIStroke")
            BtnStroke.Parent = BtnFrame
            BtnStroke.Color = Library.Theme.Accent
            BtnStroke.Transparency = 1

            local BtnText = Instance.new("TextLabel")
            BtnText.Parent = BtnFrame
            BtnText.Size = UDim2.new(1, -20, 1, 0)
            BtnText.Position = UDim2.new(0, 10, 0, 0)
            BtnText.BackgroundTransparency = 1
            BtnText.Text = Name
            BtnText.TextColor3 = Library.Theme.Text
            BtnText.TextSize = 13
            BtnText.Font = Library.Theme.Font
            BtnText.TextXAlignment = Enum.TextXAlignment.Left

            local ClickIcon = Instance.new("ImageLabel")
            ClickIcon.Parent = BtnFrame
            ClickIcon.Size = UDim2.new(0, 16, 0, 16)
            ClickIcon.Position = UDim2.new(1, -24, 0.5, -8)
            ClickIcon.BackgroundTransparency = 1
            ClickIcon.Image = "rbxassetid://6031094678"
            ClickIcon.ImageColor3 = Library.Theme.TextDim

            BtnFrame.MouseEnter:Connect(function()
                Library:Tween(BtnFrame, {BackgroundColor3 = Library.Theme.ElementHover}, 0.2)
                Library:Tween(BtnStroke, {Transparency = 0.5}, 0.2)
                Library:Tween(ClickIcon, {ImageColor3 = Library.Theme.Accent}, 0.2)
            end)
            BtnFrame.MouseLeave:Connect(function()
                Library:Tween(BtnFrame, {BackgroundColor3 = Library.Theme.Element}, 0.2)
                Library:Tween(BtnStroke, {Transparency = 1}, 0.2)
                Library:Tween(ClickIcon, {ImageColor3 = Library.Theme.TextDim}, 0.2)
            end)
            BtnFrame.MouseButton1Down:Connect(function() Library:CreateRipple(BtnFrame) end)
            BtnFrame.MouseButton1Click:Connect(function() Callback() end)
        end

        function TabObj:CreateToggle(options)
            options = options or {}
            local Name = options.Name or "Toggle"
            local Current = options.CurrentValue or false
            local Flag = options.Flag or Name
            local Callback = options.Callback or function() end

            Library.Flags[Flag] = Current

            local TglFrame = Instance.new("TextButton")
            TglFrame.Parent = self.Page
            TglFrame.Size = UDim2.new(1, 0, 0, 32)
            TglFrame.BackgroundColor3 = Library.Theme.Element
            TglFrame.Text = ""
            TglFrame.AutoButtonColor = false
            Instance.new("UICorner", TglFrame).CornerRadius = UDim.new(0, 4)

            local TglText = Instance.new("TextLabel")
            TglText.Parent = TglFrame
            TglText.Size = UDim2.new(1, -60, 1, 0)
            TglText.Position = UDim2.new(0, 10, 0, 0)
            TglText.BackgroundTransparency = 1
            TglText.Text = Name
            TglText.TextColor3 = Library.Theme.Text
            TglText.TextSize = 13
            TglText.Font = Library.Theme.Font
            TglText.TextXAlignment = Enum.TextXAlignment.Left

            local SwitchOuter = Instance.new("Frame")
            SwitchOuter.Parent = TglFrame
            SwitchOuter.Size = UDim2.new(0, 36, 0, 18)
            SwitchOuter.Position = UDim2.new(1, -44, 0.5, -9)
            SwitchOuter.BackgroundColor3 = Current and Library.Theme.Accent or Library.Theme.Border
            Instance.new("UICorner", SwitchOuter).CornerRadius = UDim.new(1, 0)

            local SwitchInner = Instance.new("Frame")
            SwitchInner.Parent = SwitchOuter
            SwitchInner.Size = UDim2.new(0, 14, 0, 14)
            SwitchInner.Position = UDim2.new(Current and 1 or 0, Current and -16 or 2, 0.5, -7)
            SwitchInner.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            Instance.new("UICorner", SwitchInner).CornerRadius = UDim.new(1, 0)

            local SwitchStroke = Instance.new("UIStroke")
            SwitchStroke.Parent = SwitchOuter
            SwitchStroke.Color = Library.Theme.AccentGlow
            SwitchStroke.Thickness = 2
            SwitchStroke.Transparency = Current and 0.4 or 1

            local function Update(state)
                Current = state
                Library.Flags[Flag] = Current
                Library:Tween(SwitchOuter, {BackgroundColor3 = Current and Library.Theme.Accent or Library.Theme.Border}, 0.25)
                Library:Tween(SwitchInner, {Position = UDim2.new(Current and 1 or 0, Current and -16 or 2, 0.5, -7)}, 0.25)
                Library:Tween(SwitchStroke, {Transparency = Current and 0.4 or 1}, 0.25)
                Callback(Current)
            end

            TglFrame.MouseButton1Click:Connect(function() Update(not Current) end)

            return { Set = function(v) Update(v) end }
        end

        function TabObj:CreateSlider(options)
            options = options or {}
            local Name = options.Name or "Slider"
            local Min = options.Range[1] or 0
            local Max = options.Range[2] or 100
            local Current = options.CurrentValue or Min
            local Flag = options.Flag or Name
            local Increment = options.Increment or 1
            local Callback = options.Callback or function() end

            Library.Flags[Flag] = Current

            local SlFrame = Instance.new("Frame")
            SlFrame.Parent = self.Page
            SlFrame.Size = UDim2.new(1, 0, 0, 48)
            SlFrame.BackgroundColor3 = Library.Theme.Element
            Instance.new("UICorner", SlFrame).CornerRadius = UDim.new(0, 4)

            local SlText = Instance.new("TextLabel")
            SlText.Parent = SlFrame
            SlText.Size = UDim2.new(1, -20, 0, 20)
            SlText.Position = UDim2.new(0, 10, 0, 6)
            SlText.BackgroundTransparency = 1
            SlText.Text = Name
            SlText.TextColor3 = Library.Theme.Text
            SlText.TextSize = 13
            SlText.Font = Library.Theme.Font
            SlText.TextXAlignment = Enum.TextXAlignment.Left

            local ValText = Instance.new("TextLabel")
            ValText.Parent = SlFrame
            ValText.Size = UDim2.new(0, 40, 0, 20)
            ValText.Position = UDim2.new(1, -50, 0, 6)
            ValText.BackgroundTransparency = 1
            ValText.Text = tostring(Current)
            ValText.TextColor3 = Library.Theme.Accent
            ValText.TextSize = 13
            ValText.Font = Enum.Font.GothamBold
            ValText.TextXAlignment = Enum.TextXAlignment.Right

            local Track = Instance.new("TextButton")
            Track.Parent = SlFrame
            Track.Size = UDim2.new(1, -20, 0, 6)
            Track.Position = UDim2.new(0, 10, 0, 32)
            Track.BackgroundColor3 = Library.Theme.Border
            Track.Text = ""
            Track.AutoButtonColor = false
            Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0)

            local Fill = Instance.new("Frame")
            Fill.Parent = Track
            local initialPct = math.clamp((Current - Min) / (Max - Min), 0, 1)
            Fill.Size = UDim2.new(initialPct, 0, 1, 0)
            Fill.BackgroundColor3 = Library.Theme.Accent
            Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

            local FillStroke = Instance.new("UIStroke")
            FillStroke.Parent = Fill
            FillStroke.Color = Library.Theme.AccentGlow
            FillStroke.Thickness = 2
            FillStroke.Transparency = 0.5

            local dragging = false
            local function updateSlider(input)
                local sizeX = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
                local val = Min + ((Max - Min) * sizeX)
                val = math.round(val / Increment) * Increment
                val = math.clamp(val, Min, Max)

                local pct = (val - Min) / (Max - Min)
                Library:Tween(Fill, {Size = UDim2.new(pct, 0, 1, 0)}, 0.1, Enum.EasingStyle.Linear)
                ValText.Text = tostring(val)
                Library.Flags[Flag] = val
                Callback(val)
            end

            Track.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = true
                    updateSlider(input)
                end
            end)
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)
            UserInputService.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    updateSlider(input)
                end
            end)

            return {
                Set = function(val)
                    val = math.clamp(val, Min, Max)
                    local pct = (val - Min) / (Max - Min)
                    Library:Tween(Fill, {Size = UDim2.new(pct, 0, 1, 0)}, 0.2)
                    ValText.Text = tostring(val)
                    Library.Flags[Flag] = val
                    Callback(val)
                end
            }
        end

        function TabObj:CreateDropdown(options)
            options = options or {}
            local Name = options.Name or "Dropdown"
            local List = options.Options or {}
            local Current = options.CurrentOption or List[1] or ""
            local Flag = options.Flag or Name
            local Callback = options.Callback or function() end

            Library.Flags[Flag] = Current

            local DropFrame = Instance.new("Frame")
            DropFrame.Parent = self.Page
            DropFrame.Size = UDim2.new(1, 0, 0, 32)
            DropFrame.BackgroundColor3 = Library.Theme.Element
            DropFrame.ClipsDescendants = true
            Instance.new("UICorner", DropFrame).CornerRadius = UDim.new(0, 4)

            local DropStroke = Instance.new("UIStroke")
            DropStroke.Parent = DropFrame
            DropStroke.Color = Library.Theme.Accent
            DropStroke.Transparency = 1

            local DropBtn = Instance.new("TextButton")
            DropBtn.Parent = DropFrame
            DropBtn.Size = UDim2.new(1, 0, 0, 32)
            DropBtn.BackgroundTransparency = 1
            DropBtn.Text = ""

            local DropText = Instance.new("TextLabel")
            DropText.Parent = DropBtn
            DropText.Size = UDim2.new(1, -40, 1, 0)
            DropText.Position = UDim2.new(0, 10, 0, 0)
            DropText.BackgroundTransparency = 1
            DropText.Text = Name .. " : " .. tostring(Current)
            DropText.TextColor3 = Library.Theme.Text
            DropText.TextSize = 13
            DropText.Font = Library.Theme.Font
            DropText.TextXAlignment = Enum.TextXAlignment.Left

            local Arrow = Instance.new("ImageLabel")
            Arrow.Parent = DropBtn
            Arrow.Size = UDim2.new(0, 16, 0, 16)
            Arrow.Position = UDim2.new(1, -24, 0.5, -8)
            Arrow.BackgroundTransparency = 1
            Arrow.Image = "rbxassetid://6031091004"
            Arrow.ImageColor3 = Library.Theme.TextDim

            local ScrollFrame = Instance.new("ScrollingFrame")
            ScrollFrame.Parent = DropFrame
            ScrollFrame.Size = UDim2.new(1, -12, 1, -36)
            ScrollFrame.Position = UDim2.new(0, 6, 0, 32)
            ScrollFrame.BackgroundTransparency = 1
            ScrollFrame.ScrollBarThickness = 2
            ScrollFrame.ScrollBarImageColor3 = Library.Theme.Accent

            local ScrollLayout = Instance.new("UIListLayout")
            ScrollLayout.Parent = ScrollFrame
            ScrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
            ScrollLayout.Padding = UDim.new(0, 4)

            local isOpen = false
            local function ToggleDrop()
                isOpen = not isOpen
                if isOpen then
                    local targetSize = math.clamp(32 + (#List * 26) + 12, 32, 130)
                    Library:Tween(DropFrame, {Size = UDim2.new(1, 0, 0, targetSize)}, 0.25)
                    Library:Tween(Arrow, {Rotation = 180, ImageColor3 = Library.Theme.Accent}, 0.25)
                    Library:Tween(DropStroke, {Transparency = 0.5}, 0.25)
                else
                    Library:Tween(DropFrame, {Size = UDim2.new(1, 0, 0, 32)}, 0.25)
                    Library:Tween(Arrow, {Rotation = 0, ImageColor3 = Library.Theme.TextDim}, 0.25)
                    Library:Tween(DropStroke, {Transparency = 1}, 0.25)
                end
            end
            DropBtn.MouseButton1Click:Connect(ToggleDrop)

            local function RefreshOptions(newList)
                List = newList
                for _, v in pairs(ScrollFrame:GetChildren()) do
                    if v:IsA("TextButton") then v:Destroy() end
                end
                for _, opt in pairs(List) do
                    local OptBtn = Instance.new("TextButton")
                    OptBtn.Parent = ScrollFrame
                    OptBtn.Size = UDim2.new(1, 0, 0, 24)
                    OptBtn.BackgroundColor3 = Library.Theme.Background
                    OptBtn.BackgroundTransparency = 1
                    OptBtn.Text = tostring(opt)
                    OptBtn.TextColor3 = Library.Theme.TextDim
                    OptBtn.TextSize = 12
                    OptBtn.Font = Library.Theme.Font
                    Instance.new("UICorner", OptBtn).CornerRadius = UDim.new(0, 4)

                    OptBtn.MouseEnter:Connect(function() Library:Tween(OptBtn, {BackgroundTransparency = 0.5, TextColor3 = Library.Theme.Accent}, 0.15) end)
                    OptBtn.MouseLeave:Connect(function() Library:Tween(OptBtn, {BackgroundTransparency = 1, TextColor3 = Library.Theme.TextDim}, 0.15) end)
                    OptBtn.MouseButton1Click:Connect(function()
                        Current = opt
                        Library.Flags[Flag] = Current
                        DropText.Text = Name .. " : " .. tostring(Current)
                        ToggleDrop()
                        Callback(Current)
                    end)
                end
                ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, ScrollLayout.AbsoluteContentSize.Y)
            end
            RefreshOptions(List)

            return {
                Refresh = RefreshOptions,
                Set = function(v)
                    Current = v
                    Library.Flags[Flag] = Current
                    DropText.Text = Name .. " : " .. tostring(Current)
                    Callback(Current)
                end
            }
        end

        function TabObj:CreateInput(options)
            options = options or {}
            local Name = options.Name or "Input"
            local Placeholder = options.Placeholder or "Enter text..."
            local Flag = options.Flag or Name
            local Callback = options.Callback or function() end

            local InpFrame = Instance.new("Frame")
            InpFrame.Parent = self.Page
            InpFrame.Size = UDim2.new(1, 0, 0, 40)
            InpFrame.BackgroundColor3 = Library.Theme.Element
            Instance.new("UICorner", InpFrame).CornerRadius = UDim.new(0, 4)

            local InpText = Instance.new("TextLabel")
            InpText.Parent = InpFrame
            InpText.Size = UDim2.new(0.4, 0, 1, 0)
            InpText.Position = UDim2.new(0, 10, 0, 0)
            InpText.BackgroundTransparency = 1
            InpText.Text = Name
            InpText.TextColor3 = Library.Theme.Text
            InpText.TextSize = 13
            InpText.Font = Library.Theme.Font
            InpText.TextXAlignment = Enum.TextXAlignment.Left

            local TextBoxBg = Instance.new("Frame")
            TextBoxBg.Parent = InpFrame
            TextBoxBg.Size = UDim2.new(0.6, -20, 0, 26)
            TextBoxBg.Position = UDim2.new(0.4, 10, 0.5, -13)
            TextBoxBg.BackgroundColor3 = Library.Theme.Background
            Instance.new("UICorner", TextBoxBg).CornerRadius = UDim.new(0, 4)

            local BoxStroke = Instance.new("UIStroke")
            BoxStroke.Parent = TextBoxBg
            BoxStroke.Color = Library.Theme.Border
            BoxStroke.Thickness = 1

            local TextBox = Instance.new("TextBox")
            TextBox.Parent = TextBoxBg
            TextBox.Size = UDim2.new(1, -10, 1, 0)
            TextBox.Position = UDim2.new(0, 5, 0, 0)
            TextBox.BackgroundTransparency = 1
            TextBox.Text = ""
            TextBox.PlaceholderText = Placeholder
            TextBox.TextColor3 = Library.Theme.Text
            TextBox.PlaceholderColor3 = Library.Theme.TextDim
            TextBox.TextSize = 12
            TextBox.Font = Library.Theme.Font
            TextBox.ClearTextOnFocus = false
            TextBox.TextXAlignment = Enum.TextXAlignment.Left

            TextBox.Focused:Connect(function()
                Library:Tween(BoxStroke, {Color = Library.Theme.Accent, Transparency = 0.5}, 0.2)
            end)
            TextBox.FocusLost:Connect(function()
                Library:Tween(BoxStroke, {Color = Library.Theme.Border, Transparency = 0}, 0.2)
                Library.Flags[Flag] = TextBox.Text
                Callback(TextBox.Text)
            end)

            return {
                Set = function(txt)
                    TextBox.Text = tostring(txt)
                    Library.Flags[Flag] = TextBox.Text
                    Callback(TextBox.Text)
                end
            }
        end

        function TabObj:CreateKeybind(options)
            options = options or {}
            local Name = options.Name or "Keybind"
            local Default = options.CurrentKeybind or Enum.KeyCode.E
            local Flag = options.Flag or Name
            local Callback = options.Callback or function() end

            Library.Flags[Flag] = Default

            local BindFrame = Instance.new("Frame")
            BindFrame.Parent = self.Page
            BindFrame.Size = UDim2.new(1, 0, 0, 32)
            BindFrame.BackgroundColor3 = Library.Theme.Element
            Instance.new("UICorner", BindFrame).CornerRadius = UDim.new(0, 4)

            local BindTitle = Instance.new("TextLabel")
            BindTitle.Parent = BindFrame
            BindTitle.Size = UDim2.new(1, -100, 1, 0)
            BindTitle.Position = UDim2.new(0, 10, 0, 0)
            BindTitle.BackgroundTransparency = 1
            BindTitle.Text = Name
            BindTitle.TextColor3 = Library.Theme.Text
            BindTitle.TextSize = 13
            BindTitle.Font = Library.Theme.Font
            BindTitle.TextXAlignment = Enum.TextXAlignment.Left

            local KeyBtn = Instance.new("TextButton")
            KeyBtn.Parent = BindFrame
            KeyBtn.Size = UDim2.new(0, 60, 0, 22)
            KeyBtn.Position = UDim2.new(1, -70, 0.5, -11)
            KeyBtn.BackgroundColor3 = Library.Theme.Background
            KeyBtn.Text = Default.Name
            KeyBtn.TextColor3 = Library.Theme.Accent
            KeyBtn.TextSize = 12
            KeyBtn.Font = Enum.Font.GothamBold
            Instance.new("UICorner", KeyBtn).CornerRadius = UDim.new(0, 4)
            Instance.new("UIStroke", KeyBtn).Color = Library.Theme.Border

            local binding = false
            KeyBtn.MouseButton1Click:Connect(function()
                binding = true
                KeyBtn.Text = "..."
                KeyBtn.TextColor3 = Library.Theme.Text
            end)

            UserInputService.InputBegan:Connect(function(input)
                if binding then
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        local key = input.KeyCode
                        if key ~= Enum.KeyCode.Unknown then
                            Default = key
                            Library.Flags[Flag] = Default
                            KeyBtn.Text = Default.Name
                            KeyBtn.TextColor3 = Library.Theme.Accent
                            binding = false
                        end
                    end
                else
                    if input.KeyCode == Default and not UserInputService:GetFocusedTextBox() then
                        Callback()
                    end
                end
            end)

            return {
                Set = function(key)
                    Default = key
                    Library.Flags[Flag] = Default
                    KeyBtn.Text = Default.Name
                end
            }
        end

        return TabObj
    end
    return WindowObj
end


-- =======================================================


-- =======================================================
-- OBSIDIAN WRAPPER (Preserving Animations & Components)
-- =======================================================
Library.Options = Library.Flags
Library.Toggles = {}

-- Save the original CreateWindow
local OriginalCreateWindow = Library.CreateWindow

function Library:CreateWindow(options)
    -- If it doesn't look like Obsidian (lacks SidebarCompacted, AutoShow, etc.), run normally
    if options.SidebarCompacted == nil and options.AutoShow == nil then
        return OriginalCreateWindow(self, options)
    end

    -- It's an Obsidian call. Create a native Glow Window.
    local glowOptions = {
        Name = options.Title or "Pandu Hub",
        Size = UDim2.new(0, 500, 0, 350),
        HideBind = Enum.KeyCode.RightControl
    }
    local NativeWindow = OriginalCreateWindow(self, glowOptions)

    local ObsidianWindow = {
        Native = NativeWindow
    }

    function ObsidianWindow:AddTab(tabName, icon)
        local NativeTab = NativeWindow:CreateTab({ Name = tabName, Icon = icon })
        local ObsidianTab = { Native = NativeTab }

        local function GetChainable(baseObj)
            baseObj.AddKeyPicker = function(self, id, opts) return baseObj end
            baseObj.AddColorPicker = function(self, id, opts) return baseObj end
            return baseObj
        end

        function ObsidianTab:AddLeftGroupbox(name)
            NativeTab:CreateSection(name)
            local ObsidianGroup = { Native = NativeTab }

            function ObsidianGroup:AddToggle(id, opts)
                local NativeToggle = NativeTab:CreateToggle({
                    Name = opts.Text or "Toggle",
                    CurrentValue = opts.Default or false,
                    Flag = id,
                    Callback = function(val)
                        Library.Options[id] = val
                        if opts.Callback then pcall(opts.Callback, val) end
                    end
                })
                local retObj = {
                    SetValue = function(self, val) NativeToggle.Set(val) end,
                    Value = opts.Default or false
                }
                Library.Toggles[id] = retObj
                return GetChainable(retObj)
            end
            ObsidianGroup.AddCheckbox = ObsidianGroup.AddToggle

            function ObsidianGroup:AddSlider(id, opts)
                local NativeSlider = NativeTab:CreateSlider({
                    Name = opts.Text or "Slider",
                    Range = {opts.Min or 0, opts.Max or 100},
                    Increment = 1,
                    CurrentValue = opts.Default or opts.Min or 0,
                    Flag = id,
                    Callback = function(val)
                        Library.Options[id] = val
                        if opts.Callback then pcall(opts.Callback, val) end
                    end
                })
                return GetChainable({
                    SetValue = function(self, val) NativeSlider.Set(val) end
                })
            end

            function ObsidianGroup:AddDropdown(id, opts)
                local NativeDropdown = NativeTab:CreateDropdown({
                    Name = opts.Text or "Dropdown",
                    Options = opts.Values or {},
                    CurrentOption = opts.Default or (opts.Values and opts.Values[1]) or "",
                    Flag = id,
                    Callback = function(val)
                        Library.Options[id] = val
                        if opts.Callback then pcall(opts.Callback, val) end
                    end
                })
                return GetChainable({
                    SetValue = function(self, val) NativeDropdown.Set(val) end,
                    SetValues = function(self, newList) NativeDropdown.Refresh(newList) end
                })
            end

            function ObsidianGroup:AddInput(id, opts)
                local NativeInput = NativeTab:CreateInput({
                    Name = opts.Text or "Input",
                    Placeholder = "Enter text...",
                    Flag = id,
                    Callback = function(val)
                        Library.Options[id] = val
                        if opts.Callback then pcall(opts.Callback, val) end
                    end
                })
                -- Initialize default value if provided
                if opts.Default then
                    NativeInput.Set(opts.Default)
                end
                return GetChainable({})
            end

            function ObsidianGroup:AddButton(opts)
                NativeTab:CreateButton({
                    Name = opts.Text or "Button",
                    Callback = function()
                        if opts.Callback then pcall(opts.Callback) end
                    end
                })
                return GetChainable({})
            end

            function ObsidianGroup:AddLabel(text)
                local NativeLabel = NativeTab:CreateLabel(text)
                return GetChainable({
                    SetText = function(self, txt) NativeLabel:Set(txt) end
                })
            end

            function ObsidianGroup:AddColorPicker(...) return GetChainable({}) end
            function ObsidianGroup:AddKeyPicker(...) return GetChainable({}) end

            return ObsidianGroup
        end
        ObsidianTab.AddRightGroupbox = ObsidianTab.AddLeftGroupbox

        return ObsidianTab
    end

    return ObsidianWindow
end

return Library
