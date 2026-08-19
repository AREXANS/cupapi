local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")

local Library = {}

Library.Theme = {
	Background = Color3.fromRGB(12, 12, 18),
	Element = Color3.fromRGB(22, 22, 28),
	ElementHover = Color3.fromRGB(32, 32, 40),
	Accent = Color3.fromRGB(0, 160, 255),
	Glow = Color3.fromRGB(0, 190, 255),
	Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(160, 160, 160),
	Outline = Color3.fromRGB(45, 45, 55),
	Font = Enum.Font.GothamMedium,
	Corner = UDim.new(0, 6)
}

function Library:Tween(obj, props, time)
	local tweenInfo = TweenInfo.new(time or 0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	local tween = TweenService:Create(obj, tweenInfo, props)
	tween:Play()
	return tween
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
			Library:Tween(main, {Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)}, 0.1)
		end
	end)
end

function Library:CreateWindow(options)
	options = options or {}
	local title = options.Name or "Glow UI"

	-- Destroy old instances
	for _, v in pairs(CoreGui:GetChildren()) do
		if v.Name == "GlowUILibrary" then v:Destroy() end
	end
	if Players.LocalPlayer then
		local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
		if pg then
			for _, v in pairs(pg:GetChildren()) do
				if v.Name == "GlowUILibrary" then v:Destroy() end
			end
		end
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "GlowUILibrary"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false

	local success = pcall(function() screenGui.Parent = CoreGui end)
	if not success then
		screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	end

	-- Main Frame
	local mainFrame = Instance.new("Frame")
	mainFrame.Name = "Main"
	mainFrame.Parent = screenGui
	mainFrame.BackgroundColor3 = Library.Theme.Background
	mainFrame.Size = UDim2.new(0, 560, 0, 360)
	mainFrame.Position = UDim2.new(0.5, -280, 0.5, -180)
	mainFrame.ClipsDescendants = false

	local mainCorner = Instance.new("UICorner")
	mainCorner.CornerRadius = Library.Theme.Corner
	mainCorner.Parent = mainFrame

	-- Subtle Glow & Border using UIStroke
	local mainStroke = Instance.new("UIStroke")
	mainStroke.Parent = mainFrame
	mainStroke.Color = Library.Theme.Accent
	mainStroke.Thickness = 1
	mainStroke.Transparency = 0.3

	-- Inner Shadow/Glow Image for acrylic effect
	local glow = Instance.new("ImageLabel")
	glow.Name = "Glow"
	glow.Parent = mainFrame
	glow.BackgroundTransparency = 1
	glow.Position = UDim2.new(0, -15, 0, -15)
	glow.Size = UDim2.new(1, 30, 1, 30)
	glow.ZIndex = 0
	glow.Image = "rbxassetid://5028857472"
	glow.ImageColor3 = Library.Theme.Glow
	glow.ImageTransparency = 0.6
	glow.ScaleType = Enum.ScaleType.Slice
	glow.SliceCenter = Rect.new(24, 24, 276, 276)

	-- Topbar
	local topbar = Instance.new("Frame")
	topbar.Name = "Topbar"
	topbar.Parent = mainFrame
	topbar.Size = UDim2.new(1, 0, 0, 40)
	topbar.BackgroundTransparency = 1

	Library:MakeDraggable(topbar, mainFrame)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Parent = topbar
	titleLabel.Size = UDim2.new(1, -20, 1, 0)
	titleLabel.Position = UDim2.new(0, 20, 0, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextColor3 = Library.Theme.Text
	titleLabel.TextSize = 15
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left

	local titleStroke = Instance.new("UIStroke")
	titleStroke.Parent = titleLabel
	titleStroke.Color = Library.Theme.Accent
	titleStroke.Transparency = 0.8
	titleStroke.Thickness = 0.5

	-- Divider
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.Parent = mainFrame
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.Position = UDim2.new(0, 0, 0, 40)
	divider.BackgroundColor3 = Library.Theme.Outline
	divider.BorderSizePixel = 0
	divider.BackgroundTransparency = 0.5

	-- Sidebar (Tabs)
	local sidebar = Instance.new("ScrollingFrame")
	sidebar.Name = "Sidebar"
	sidebar.Parent = mainFrame
	sidebar.Size = UDim2.new(0, 140, 1, -41)
	sidebar.Position = UDim2.new(0, 0, 0, 41)
	sidebar.BackgroundTransparency = 1
	sidebar.ScrollBarThickness = 0

	local sidebarLayout = Instance.new("UIListLayout")
	sidebarLayout.Parent = sidebar
	sidebarLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sidebarLayout.Padding = UDim.new(0, 6)

	local sidebarPadding = Instance.new("UIPadding")
	sidebarPadding.Parent = sidebar
	sidebarPadding.PaddingTop = UDim.new(0, 12)
	sidebarPadding.PaddingBottom = UDim.new(0, 12)
	sidebarPadding.PaddingLeft = UDim.new(0, 12)
	sidebarPadding.PaddingRight = UDim.new(0, 12)

	-- Content Area (Pages)
	local contentArea = Instance.new("Frame")
	contentArea.Name = "ContentArea"
	contentArea.Parent = mainFrame
	contentArea.Size = UDim2.new(1, -141, 1, -41)
	contentArea.Position = UDim2.new(0, 141, 0, 41)
	contentArea.BackgroundTransparency = 1

	local contentDivider = Instance.new("Frame")
	contentDivider.Name = "ContentDivider"
	contentDivider.Parent = mainFrame
	contentDivider.Size = UDim2.new(0, 1, 1, -41)
	contentDivider.Position = UDim2.new(0, 140, 0, 41)
	contentDivider.BackgroundColor3 = Library.Theme.Outline
	contentDivider.BorderSizePixel = 0
	contentDivider.BackgroundTransparency = 0.5

	local Window = {
		CurrentTab = nil,
		Tabs = {},
		FirstTab = nil
	}

	function Window:CreateTab(options)
		options = options or {}
		local tabName = options.Name or "Tab"

		local tabBtn = Instance.new("TextButton")
		tabBtn.Name = "Tab_" .. tabName
		tabBtn.Parent = sidebar
		tabBtn.Size = UDim2.new(1, 0, 0, 34)
		tabBtn.BackgroundColor3 = Library.Theme.Element
		tabBtn.BackgroundTransparency = 1
		tabBtn.Text = tabName
		tabBtn.TextColor3 = Library.Theme.TextDim
		tabBtn.TextSize = 13
		tabBtn.Font = Library.Theme.Font
		tabBtn.AutoButtonColor = false

		local tabCorner = Instance.new("UICorner")
		tabCorner.CornerRadius = Library.Theme.Corner
		tabCorner.Parent = tabBtn

		local page = Instance.new("ScrollingFrame")
		page.Name = "Page_" .. tabName
		page.Parent = contentArea
		page.Size = UDim2.new(1, 0, 1, 0)
		page.BackgroundTransparency = 1
		page.ScrollBarThickness = 2
		page.ScrollBarImageColor3 = Library.Theme.Accent
		page.Visible = false

		local pageLayout = Instance.new("UIListLayout")
		pageLayout.Parent = page
		pageLayout.SortOrder = Enum.SortOrder.LayoutOrder
		pageLayout.Padding = UDim.new(0, 10)

		local pagePadding = Instance.new("UIPadding")
		pagePadding.Parent = page
		pagePadding.PaddingTop = UDim.new(0, 12)
		pagePadding.PaddingBottom = UDim.new(0, 12)
		pagePadding.PaddingLeft = UDim.new(0, 12)
		pagePadding.PaddingRight = UDim.new(0, 16)

		pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			page.CanvasSize = UDim2.new(0, 0, 0, pageLayout.AbsoluteContentSize.Y + 24)
		end)

		sidebarLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			sidebar.CanvasSize = UDim2.new(0, 0, 0, sidebarLayout.AbsoluteContentSize.Y + 24)
		end)

		if not Window.FirstTab then
			Window.FirstTab = {Btn = tabBtn, Page = page}
		end

		tabBtn.MouseButton1Click:Connect(function()
			if Window.CurrentTab then
				Library:Tween(Window.CurrentTab.Btn, {BackgroundTransparency = 1, TextColor3 = Library.Theme.TextDim}, 0.2)
				Window.CurrentTab.Page.Visible = false
			end
			Window.CurrentTab = {Btn = tabBtn, Page = page}
			Library:Tween(tabBtn, {BackgroundTransparency = 0, TextColor3 = Library.Theme.Text}, 0.2)
			page.Visible = true
		end)

		local TabObj = { Page = page }

		function TabObj:CreateButton(options)
			options = options or {}
			local btnName = options.Name or "Button"
			local callback = options.Callback or function() end

			local btnFrame = Instance.new("TextButton")
			btnFrame.Name = "Button_" .. btnName
			btnFrame.Parent = self.Page
			btnFrame.Size = UDim2.new(1, 0, 0, 38)
			btnFrame.BackgroundColor3 = Library.Theme.Element
			btnFrame.Text = ""
			btnFrame.AutoButtonColor = false

			Instance.new("UICorner", btnFrame).CornerRadius = Library.Theme.Corner

			local btnStroke = Instance.new("UIStroke")
			btnStroke.Parent = btnFrame
			btnStroke.Color = Library.Theme.Accent
			btnStroke.Transparency = 1
			btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

			local btnLabel = Instance.new("TextLabel")
			btnLabel.Parent = btnFrame
			btnLabel.Size = UDim2.new(1, -20, 1, 0)
			btnLabel.Position = UDim2.new(0, 12, 0, 0)
			btnLabel.BackgroundTransparency = 1
			btnLabel.Text = btnName
			btnLabel.TextColor3 = Library.Theme.Text
			btnLabel.TextSize = 14
			btnLabel.Font = Library.Theme.Font
			btnLabel.TextXAlignment = Enum.TextXAlignment.Left

			local interactIcon = Instance.new("ImageLabel")
			interactIcon.Parent = btnFrame
			interactIcon.Size = UDim2.new(0, 18, 0, 18)
			interactIcon.Position = UDim2.new(1, -30, 0.5, -9)
			interactIcon.BackgroundTransparency = 1
			interactIcon.Image = "rbxassetid://6031094678" -- click icon
			interactIcon.ImageColor3 = Library.Theme.TextDim

			btnFrame.MouseEnter:Connect(function()
				Library:Tween(btnFrame, {BackgroundColor3 = Library.Theme.ElementHover}, 0.2)
				Library:Tween(btnStroke, {Transparency = 0.4}, 0.2)
				Library:Tween(interactIcon, {ImageColor3 = Library.Theme.Accent}, 0.2)
			end)

			btnFrame.MouseLeave:Connect(function()
				Library:Tween(btnFrame, {BackgroundColor3 = Library.Theme.Element}, 0.2)
				Library:Tween(btnStroke, {Transparency = 1}, 0.2)
				Library:Tween(interactIcon, {ImageColor3 = Library.Theme.TextDim}, 0.2)
			end)

			btnFrame.MouseButton1Down:Connect(function()
				Library:Tween(btnFrame, {Size = UDim2.new(1, -4, 0, 34)}, 0.1)
			end)

			btnFrame.MouseButton1Up:Connect(function()
				Library:Tween(btnFrame, {Size = UDim2.new(1, 0, 0, 38)}, 0.1)
				callback()
			end)
		end

		function TabObj:CreateToggle(options)
			options = options or {}
			local tglName = options.Name or "Toggle"
			local current = options.CurrentValue or false
			local callback = options.Callback or function() end

			local tglFrame = Instance.new("TextButton")
			tglFrame.Name = "Toggle_" .. tglName
			tglFrame.Parent = self.Page
			tglFrame.Size = UDim2.new(1, 0, 0, 38)
			tglFrame.BackgroundColor3 = Library.Theme.Element
			tglFrame.Text = ""
			tglFrame.AutoButtonColor = false

			Instance.new("UICorner", tglFrame).CornerRadius = Library.Theme.Corner

			local tglLabel = Instance.new("TextLabel")
			tglLabel.Parent = tglFrame
			tglLabel.Size = UDim2.new(1, -60, 1, 0)
			tglLabel.Position = UDim2.new(0, 12, 0, 0)
			tglLabel.BackgroundTransparency = 1
			tglLabel.Text = tglName
			tglLabel.TextColor3 = Library.Theme.Text
			tglLabel.TextSize = 14
			tglLabel.Font = Library.Theme.Font
			tglLabel.TextXAlignment = Enum.TextXAlignment.Left

			local switchArea = Instance.new("Frame")
			switchArea.Parent = tglFrame
			switchArea.Size = UDim2.new(0, 40, 0, 22)
			switchArea.Position = UDim2.new(1, -52, 0.5, -11)
			switchArea.BackgroundColor3 = current and Library.Theme.Accent or Library.Theme.Outline
			Instance.new("UICorner", switchArea).CornerRadius = UDim.new(1, 0)

			local switchKnob = Instance.new("Frame")
			switchKnob.Parent = switchArea
			switchKnob.Size = UDim2.new(0, 18, 0, 18)
			switchKnob.Position = UDim2.new(current and 1 or 0, current and -20 or 2, 0.5, -9)
			switchKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			Instance.new("UICorner", switchKnob).CornerRadius = UDim.new(1, 0)

			local knobStroke = Instance.new("UIStroke")
			knobStroke.Parent = switchArea
			knobStroke.Color = Library.Theme.Glow
			knobStroke.Thickness = 2
			knobStroke.Transparency = current and 0.2 or 1

			local function updateVisuals(state)
				Library:Tween(switchArea, {BackgroundColor3 = state and Library.Theme.Accent or Library.Theme.Outline}, 0.25)
				Library:Tween(switchKnob, {Position = UDim2.new(state and 1 or 0, state and -20 or 2, 0.5, -9)}, 0.25)
				Library:Tween(knobStroke, {Transparency = state and 0.4 or 1}, 0.25)
			end
			updateVisuals(current)

			tglFrame.MouseButton1Click:Connect(function()
				current = not current
				updateVisuals(current)
				callback(current)
			end)

			return {
				Set = function(val)
					current = val
					updateVisuals(current)
					callback(current)
				end
			}
		end

		function TabObj:CreateSlider(options)
			options = options or {}
			local slName = options.Name or "Slider"
			local min = options.Range[1] or 0
			local max = options.Range[2] or 100
			local current = options.CurrentValue or min
			local callback = options.Callback or function() end

			local slFrame = Instance.new("Frame")
			slFrame.Name = "Slider_" .. slName
			slFrame.Parent = self.Page
			slFrame.Size = UDim2.new(1, 0, 0, 56)
			slFrame.BackgroundColor3 = Library.Theme.Element
			Instance.new("UICorner", slFrame).CornerRadius = Library.Theme.Corner

			local slLabel = Instance.new("TextLabel")
			slLabel.Parent = slFrame
			slLabel.Size = UDim2.new(1, -20, 0, 20)
			slLabel.Position = UDim2.new(0, 12, 0, 8)
			slLabel.BackgroundTransparency = 1
			slLabel.Text = slName
			slLabel.TextColor3 = Library.Theme.Text
			slLabel.TextSize = 14
			slLabel.Font = Library.Theme.Font
			slLabel.TextXAlignment = Enum.TextXAlignment.Left

			local valLabel = Instance.new("TextLabel")
			valLabel.Parent = slFrame
			valLabel.Size = UDim2.new(0, 50, 0, 20)
			valLabel.Position = UDim2.new(1, -62, 0, 8)
			valLabel.BackgroundTransparency = 1
			valLabel.Text = tostring(current)
			valLabel.TextColor3 = Library.Theme.Accent
			valLabel.TextSize = 14
			valLabel.Font = Enum.Font.GothamBold
			valLabel.TextXAlignment = Enum.TextXAlignment.Right

			local sliderBg = Instance.new("TextButton")
			sliderBg.Parent = slFrame
			sliderBg.Size = UDim2.new(1, -24, 0, 6)
			sliderBg.Position = UDim2.new(0, 12, 0, 38)
			sliderBg.BackgroundColor3 = Library.Theme.Outline
			sliderBg.Text = ""
			sliderBg.AutoButtonColor = false
			Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(1, 0)

			local sliderFill = Instance.new("Frame")
			sliderFill.Parent = sliderBg
			local initialPct = math.clamp((current - min) / (max - min), 0, 1)
			sliderFill.Size = UDim2.new(initialPct, 0, 1, 0)
			sliderFill.BackgroundColor3 = Library.Theme.Accent
			Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)

			local fillStroke = Instance.new("UIStroke")
			fillStroke.Parent = sliderFill
			fillStroke.Color = Library.Theme.Glow
			fillStroke.Thickness = 2
			fillStroke.Transparency = 0.5

			local dragging = false

			local function updateSlider(input)
				local sizeX = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
				Library:Tween(sliderFill, {Size = UDim2.new(sizeX, 0, 1, 0)}, 0.1)
				local val = math.floor((sizeX * (max - min)) + min)
				valLabel.Text = tostring(val)
				callback(val)
			end

			sliderBg.InputBegan:Connect(function(input)
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
					local clamped = math.clamp(val, min, max)
					local pct = (clamped - min) / (max - min)
					Library:Tween(sliderFill, {Size = UDim2.new(pct, 0, 1, 0)}, 0.2)
					valLabel.Text = tostring(clamped)
					callback(clamped)
				end
			}
		end

		function TabObj:CreateDropdown(options)
			options = options or {}
			local dpName = options.Name or "Dropdown"
			local list = options.Options or {}
			local current = options.CurrentOption or list[1] or ""
			local callback = options.Callback or function() end

			local dpFrame = Instance.new("Frame")
			dpFrame.Name = "Dropdown_" .. dpName
			dpFrame.Parent = self.Page
			dpFrame.Size = UDim2.new(1, 0, 0, 38)
			dpFrame.BackgroundColor3 = Library.Theme.Element
			dpFrame.ClipsDescendants = true
			Instance.new("UICorner", dpFrame).CornerRadius = Library.Theme.Corner

			local dpStroke = Instance.new("UIStroke")
			dpStroke.Parent = dpFrame
			dpStroke.Color = Library.Theme.Accent
			dpStroke.Transparency = 1
			dpStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

			local dpBtn = Instance.new("TextButton")
			dpBtn.Parent = dpFrame
			dpBtn.Size = UDim2.new(1, 0, 0, 38)
			dpBtn.BackgroundTransparency = 1
			dpBtn.Text = ""

			local dpLabel = Instance.new("TextLabel")
			dpLabel.Parent = dpBtn
			dpLabel.Size = UDim2.new(1, -40, 1, 0)
			dpLabel.Position = UDim2.new(0, 12, 0, 0)
			dpLabel.BackgroundTransparency = 1
			dpLabel.Text = dpName .. " : " .. tostring(current)
			dpLabel.TextColor3 = Library.Theme.Text
			dpLabel.TextSize = 14
			dpLabel.Font = Library.Theme.Font
			dpLabel.TextXAlignment = Enum.TextXAlignment.Left

			local arrowIcon = Instance.new("ImageLabel")
			arrowIcon.Parent = dpBtn
			arrowIcon.Size = UDim2.new(0, 18, 0, 18)
			arrowIcon.Position = UDim2.new(1, -30, 0.5, -9)
			arrowIcon.BackgroundTransparency = 1
			arrowIcon.Image = "rbxassetid://6031091004" -- down arrow
			arrowIcon.ImageColor3 = Library.Theme.TextDim

			local listArea = Instance.new("ScrollingFrame")
			listArea.Parent = dpFrame
			listArea.Size = UDim2.new(1, -12, 1, -42)
			listArea.Position = UDim2.new(0, 6, 0, 38)
			listArea.BackgroundTransparency = 1
			listArea.ScrollBarThickness = 2
			listArea.ScrollBarImageColor3 = Library.Theme.Accent

			local listLayout = Instance.new("UIListLayout")
			listLayout.Parent = listArea
			listLayout.SortOrder = Enum.SortOrder.LayoutOrder
			listLayout.Padding = UDim.new(0, 4)

			local isOpen = false

			local function toggleOpen()
				isOpen = not isOpen
				if isOpen then
					local height = math.clamp(38 + (#list * 32) + 12, 38, 160)
					Library:Tween(dpFrame, {Size = UDim2.new(1, 0, 0, height)}, 0.25)
					Library:Tween(arrowIcon, {Rotation = 180, ImageColor3 = Library.Theme.Accent}, 0.25)
					Library:Tween(dpStroke, {Transparency = 0.4}, 0.25)
				else
					Library:Tween(dpFrame, {Size = UDim2.new(1, 0, 0, 38)}, 0.25)
					Library:Tween(arrowIcon, {Rotation = 0, ImageColor3 = Library.Theme.TextDim}, 0.25)
					Library:Tween(dpStroke, {Transparency = 1}, 0.25)
				end
			end

			dpBtn.MouseButton1Click:Connect(toggleOpen)

			local function populate(newList)
				list = newList
				for _, child in pairs(listArea:GetChildren()) do
					if child:IsA("TextButton") then child:Destroy() end
				end

				for _, option in pairs(list) do
					local optBtn = Instance.new("TextButton")
					optBtn.Parent = listArea
					optBtn.Size = UDim2.new(1, 0, 0, 28)
					optBtn.BackgroundColor3 = Library.Theme.Background
					optBtn.BackgroundTransparency = 1
					optBtn.Text = tostring(option)
					optBtn.TextColor3 = Library.Theme.TextDim
					optBtn.TextSize = 13
					optBtn.Font = Library.Theme.Font
					Instance.new("UICorner", optBtn).CornerRadius = UDim.new(0, 4)

					optBtn.MouseEnter:Connect(function()
						Library:Tween(optBtn, {BackgroundTransparency = 0.8, TextColor3 = Library.Theme.Accent}, 0.15)
					end)
					optBtn.MouseLeave:Connect(function()
						Library:Tween(optBtn, {BackgroundTransparency = 1, TextColor3 = Library.Theme.TextDim}, 0.15)
					end)
					optBtn.MouseButton1Click:Connect(function()
						current = option
						dpLabel.Text = dpName .. " : " .. tostring(current)
						toggleOpen()
						callback(current)
					end)
				end
				listArea.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
			end

			populate(list)

			return {
				Refresh = populate,
				Set = function(val)
					current = val
					dpLabel.Text = dpName .. " : " .. tostring(current)
					callback(current)
				end
			}
		end

		return TabObj
	end

	-- Open first tab correctly when loaded
	task.spawn(function()
		task.wait(0.1)
		if Window.FirstTab then
			Window.CurrentTab = Window.FirstTab
			Library:Tween(Window.FirstTab.Btn, {BackgroundTransparency = 0, TextColor3 = Library.Theme.Text}, 0)
			Window.FirstTab.Page.Visible = true
		end
	end)

	return Window
end

return Library