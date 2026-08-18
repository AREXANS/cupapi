-- Core UI Library
-- Core UI Library for Roblox (Sci-Fi / Blue Glow Theme)
local Library = {}

-- Services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

-- Configuration / Theme
Library.Theme = {
	MainBackground = Color3.fromRGB(15, 20, 30),
	SidebarBackground = Color3.fromRGB(10, 15, 25),
	Accent = Color3.fromRGB(0, 170, 255),
	AccentGlow = Color3.fromRGB(50, 200, 255),
	Text = Color3.fromRGB(240, 240, 240),
	TextDim = Color3.fromRGB(150, 150, 160),
	ElementBackground = Color3.fromRGB(20, 25, 35),
	HoverAccent = Color3.fromRGB(0, 200, 255),
	StrokeColor = Color3.fromRGB(0, 100, 200),
	Font = Enum.Font.GothamSemibold,
	CornerRadius = UDim.new(0, 6)
}

-- Utility Functions
function Library:Tween(object, properties, duration, style, direction)
	duration = duration or 0.3
	style = style or Enum.EasingStyle.Quint
	direction = direction or Enum.EasingDirection.Out
	local tweenInfo = TweenInfo.new(duration, style, direction)
	local tween = TweenService:Create(object, tweenInfo, properties)
	tween:Play()
	return tween
end

function Library:Create(className, properties)
	local instance = Instance.new(className)
	for k, v in pairs(properties or {}) do
		instance[k] = v
	end
	return instance
end

function Library:MakeDraggable(topbar, window)
	local dragging = false
	local dragInput, mousePos, framePos

	topbar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			mousePos = input.Position
			framePos = window.Position

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
			window.Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)
		end
	end)
end

-- Window Creation
function Library:CreateWindow(options)
	options = options or {}
	local titleText = options.Title or "Blue Glow Library"
	local windowSize = options.Size or UDim2.new(0, 650, 0, 400)

	-- Parent GUI
	local screenGui = self:Create("ScreenGui", {
		Name = "BlueGlowUI",
		Parent = RunService:IsStudio() and game.Players.LocalPlayer:WaitForChild("PlayerGui") or CoreGui,
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	})

	-- Main Window Frame
	local mainFrame = self:Create("Frame", {
		Name = "MainFrame",
		Parent = screenGui,
		Size = windowSize,
		Position = UDim2.new(0.5, -windowSize.X.Offset/2, 0.5, -windowSize.Y.Offset/2),
		BackgroundColor3 = self.Theme.MainBackground,
		BorderSizePixel = 0,
		ClipsDescendants = false
	})

	self:Create("UICorner", {
		Parent = mainFrame,
		CornerRadius = self.Theme.CornerRadius
	})

	-- Glow/Stroke
	local uiStroke = self:Create("UIStroke", {
		Parent = mainFrame,
		Color = self.Theme.StrokeColor,
		Thickness = 2,
		Transparency = 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	})

	-- Animate Glow Pulse
	task.spawn(function()
		while mainFrame.Parent do
			self:Tween(uiStroke, {Color = self.Theme.AccentGlow}, 1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(1.5)
			self:Tween(uiStroke, {Color = self.Theme.StrokeColor}, 1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.wait(1.5)
		end
	end)

	-- Topbar
	local topbar = self:Create("Frame", {
		Name = "Topbar",
		Parent = mainFrame,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		ZIndex = 2
	})
	self:MakeDraggable(topbar, mainFrame)

	local titleLabel = self:Create("TextLabel", {
		Name = "Title",
		Parent = topbar,
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.new(0, 20, 0, 0),
		BackgroundTransparency = 1,
		Text = titleText,
		TextColor3 = self.Theme.Accent,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left
	})

	-- Close Button
	local closeBtn = self:Create("TextButton", {
		Name = "CloseButton",
		Parent = topbar,
		Size = UDim2.new(0, 40, 0, 40),
		Position = UDim2.new(1, -40, 0, 0),
		BackgroundTransparency = 1,
		Text = "X",
		TextColor3 = self.Theme.TextDim,
		Font = Enum.Font.GothamBold,
		TextSize = 18
	})
	closeBtn.MouseButton1Click:Connect(function()
		self:Tween(mainFrame, {Size = UDim2.new(0, 0, 0, 0)}, 0.3)
		task.wait(0.3)
		screenGui:Destroy()
	end)
	closeBtn.MouseEnter:Connect(function() self:Tween(closeBtn, {TextColor3 = Color3.fromRGB(255, 50, 50)}, 0.2) end)
	closeBtn.MouseLeave:Connect(function() self:Tween(closeBtn, {TextColor3 = self.Theme.TextDim}, 0.2) end)

	-- Sidebar
	local sidebar = self:Create("Frame", {
		Name = "Sidebar",
		Parent = mainFrame,
		Size = UDim2.new(0, 160, 1, -40),
		Position = UDim2.new(0, 0, 0, 40),
		BackgroundColor3 = self.Theme.SidebarBackground,
		BorderSizePixel = 0
	})
	self:Create("UICorner", {
		Parent = sidebar,
		CornerRadius = self.Theme.CornerRadius
	})

	local tabContainer = self:Create("ScrollingFrame", {
		Name = "TabContainer",
		Parent = sidebar,
		Size = UDim2.new(1, 0, 1, -10),
		Position = UDim2.new(0, 0, 0, 10),
		BackgroundTransparency = 1,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0)
	})
	local tabListLayout = self:Create("UIListLayout", {
		Parent = tabContainer,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 5),
		HorizontalAlignment = Enum.HorizontalAlignment.Center
	})
	tabListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		tabContainer.CanvasSize = UDim2.new(0, 0, 0, tabListLayout.AbsoluteContentSize.Y + 20)
	end)

	-- Content Area (where tabs are shown)
	local contentArea = self:Create("Frame", {
		Name = "ContentArea",
		Parent = mainFrame,
		Size = UDim2.new(1, -170, 1, -50),
		Position = UDim2.new(0, 165, 0, 45),
		BackgroundTransparency = 1
	})

	local Window = {
		MainFrame = mainFrame,
		ContentArea = contentArea,
		TabContainer = tabContainer,
		Tabs = {},
		CurrentTab = nil
	}

	function Window:CreateTab(tabName)
		local TabObj = {
			Name = tabName
		}

		-- Tab Button in Sidebar
		local tabBtn = Library:Create("TextButton", {
			Name = tabName .. "Tab",
			Parent = self.TabContainer,
			Size = UDim2.new(1, -20, 0, 35),
			BackgroundColor3 = Library.Theme.ElementBackground,
			Text = tabName,
			TextColor3 = Library.Theme.TextDim,
			Font = Library.Theme.Font,
			TextSize = 14,
			AutoButtonColor = false
		})
		Library:Create("UICorner", { Parent = tabBtn, CornerRadius = Library.Theme.CornerRadius })
		local tabBtnStroke = Library:Create("UIStroke", {
			Parent = tabBtn,
			Color = Library.Theme.StrokeColor,
			Thickness = 1,
			Transparency = 1,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		})

		-- Content Page for Tab
		local tabFrame = Library:Create("ScrollingFrame", {
			Name = tabName .. "Page",
			Parent = self.ContentArea,
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Library.Theme.Accent,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			Visible = false
		})
		local pageListLayout = Library:Create("UIListLayout", {
			Parent = tabFrame,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8)
		})
		pageListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			tabFrame.CanvasSize = UDim2.new(0, 0, 0, pageListLayout.AbsoluteContentSize.Y + 20)
		end)

		-- Switching Logic
		tabBtn.MouseButton1Click:Connect(function()
			if self.CurrentTab == TabObj then return end

			-- Reset all tabs
			for _, t in pairs(self.Tabs) do
				Library:Tween(t.Button, {BackgroundColor3 = Library.Theme.ElementBackground, TextColor3 = Library.Theme.TextDim}, 0.2)
				Library:Tween(t.Stroke, {Transparency = 1}, 0.2)
				t.Page.Visible = false
			end

			-- Set new active tab
			self.CurrentTab = TabObj
			Library:Tween(tabBtn, {BackgroundColor3 = Library.Theme.MainBackground, TextColor3 = Library.Theme.Accent}, 0.2)
			Library:Tween(tabBtnStroke, {Transparency = 0}, 0.2)

			tabFrame.Visible = true
			tabFrame.Position = UDim2.new(0, 20, 0, 0)
			Library:Tween(tabFrame, {Position = UDim2.new(0, 0, 0, 0)}, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		end)

		-- Hover effect
		tabBtn.MouseEnter:Connect(function()
			if self.CurrentTab ~= TabObj then
				Library:Tween(tabBtn, {TextColor3 = Library.Theme.Text}, 0.2)
			end
		end)
		tabBtn.MouseLeave:Connect(function()
			if self.CurrentTab ~= TabObj then
				Library:Tween(tabBtn, {TextColor3 = Library.Theme.TextDim}, 0.2)
			end
		end)

		TabObj.Button = tabBtn
		TabObj.Stroke = tabBtnStroke
		TabObj.Page = tabFrame

		table.insert(self.Tabs, TabObj)

		-- Auto-select first tab
		if #self.Tabs == 1 then
			tabBtnStroke.Transparency = 0
			tabBtn.BackgroundColor3 = Library.Theme.MainBackground
			tabBtn.TextColor3 = Library.Theme.Accent
			tabFrame.Visible = true
			self.CurrentTab = TabObj
		end

		-- Element: Section
		function TabObj:CreateSection(title)
			local sectionFrame = Library:Create("Frame", {
				Parent = self.Page,
				Size = UDim2.new(1, -10, 0, 25),
				BackgroundTransparency = 1
			})
			Library:Create("TextLabel", {
				Parent = sectionFrame,
				Size = UDim2.new(1, -10, 1, 0),
				Position = UDim2.new(0, 5, 0, 0),
				BackgroundTransparency = 1,
				Text = title,
				TextColor3 = Library.Theme.Accent,
				Font = Enum.Font.GothamBold,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left
			})
		end

		-- Element: Button
		function TabObj:CreateButton(options)
			options = options or {}
			local btnText = options.Name or "Button"
			local callback = options.Callback or function() end

			local btnFrame = Library:Create("TextButton", {
				Name = "Button_" .. btnText,
				Parent = self.Page,
				Size = UDim2.new(1, -10, 0, 35),
				BackgroundColor3 = Library.Theme.ElementBackground,
				Text = btnText,
				TextColor3 = Library.Theme.Text,
				Font = Library.Theme.Font,
				TextSize = 14,
				AutoButtonColor = false
			})
			Library:Create("UICorner", { Parent = btnFrame, CornerRadius = Library.Theme.CornerRadius })
			local stroke = Library:Create("UIStroke", {
				Parent = btnFrame,
				Color = Library.Theme.StrokeColor,
				Thickness = 1,
				Transparency = 1,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			})

			btnFrame.MouseEnter:Connect(function()
				Library:Tween(btnFrame, {BackgroundColor3 = Library.Theme.HoverAccent, TextColor3 = Color3.fromRGB(255,255,255)}, 0.2)
				Library:Tween(stroke, {Transparency = 0}, 0.2)
			end)

			btnFrame.MouseLeave:Connect(function()
				Library:Tween(btnFrame, {BackgroundColor3 = Library.Theme.ElementBackground, TextColor3 = Library.Theme.Text}, 0.2)
				Library:Tween(stroke, {Transparency = 1}, 0.2)
			end)

			btnFrame.MouseButton1Down:Connect(function()
				Library:Tween(btnFrame, {Size = UDim2.new(1, -14, 0, 31)}, 0.1)
			end)

			btnFrame.MouseButton1Up:Connect(function()
				Library:Tween(btnFrame, {Size = UDim2.new(1, -10, 0, 35)}, 0.1)
				callback()
			end)
		end

		-- Element: Toggle
		function TabObj:CreateToggle(options)
			options = options or {}
			local tglText = options.Name or "Toggle"
			local default = options.CurrentValue or false
			local callback = options.Callback or function() end
			local toggled = default

			local tglFrame = Library:Create("TextButton", {
				Name = "Toggle_" .. tglText,
				Parent = self.Page,
				Size = UDim2.new(1, -10, 0, 35),
				BackgroundColor3 = Library.Theme.ElementBackground,
				Text = "",
				AutoButtonColor = false
			})
			Library:Create("UICorner", { Parent = tglFrame, CornerRadius = Library.Theme.CornerRadius })

			Library:Create("TextLabel", {
				Parent = tglFrame,
				Size = UDim2.new(1, -50, 1, 0),
				Position = UDim2.new(0, 10, 0, 0),
				BackgroundTransparency = 1,
				Text = tglText,
				TextColor3 = Library.Theme.Text,
				Font = Library.Theme.Font,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left
			})

			local switchArea = Library:Create("Frame", {
				Parent = tglFrame,
				Size = UDim2.new(0, 40, 0, 20),
				Position = UDim2.new(1, -50, 0.5, -10),
				BackgroundColor3 = toggled and Library.Theme.Accent or Library.Theme.MainBackground
			})
			Library:Create("UICorner", { Parent = switchArea, CornerRadius = UDim.new(1, 0) })

			local switchKnob = Library:Create("Frame", {
				Parent = switchArea,
				Size = UDim2.new(0, 16, 0, 16),
				Position = UDim2.new(toggled and 1 or 0, toggled and -18 or 2, 0.5, -8),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			})
			Library:Create("UICorner", { Parent = switchKnob, CornerRadius = UDim.new(1, 0) })

			local function UpdateToggle(state)
				toggled = state
				Library:Tween(switchArea, {BackgroundColor3 = toggled and Library.Theme.Accent or Library.Theme.MainBackground}, 0.2)
				Library:Tween(switchKnob, {Position = UDim2.new(toggled and 1 or 0, toggled and -18 or 2, 0.5, -8)}, 0.2)
				callback(toggled)
			end

			tglFrame.MouseButton1Click:Connect(function()
				UpdateToggle(not toggled)
			end)

			return {
				Set = function(state) UpdateToggle(state) end
			}
		end

		-- Element: Slider
		function TabObj:CreateSlider(options)
			options = options or {}
			local slText = options.Name or "Slider"
			local min = options.Range[1] or 0
			local max = options.Range[2] or 100
			local default = options.CurrentValue or min
			local callback = options.Callback or function() end

			local slFrame = Library:Create("Frame", {
				Name = "Slider_" .. slText,
				Parent = self.Page,
				Size = UDim2.new(1, -10, 0, 50),
				BackgroundColor3 = Library.Theme.ElementBackground
			})
			Library:Create("UICorner", { Parent = slFrame, CornerRadius = Library.Theme.CornerRadius })

			Library:Create("TextLabel", {
				Parent = slFrame,
				Size = UDim2.new(1, -20, 0, 20),
				Position = UDim2.new(0, 10, 0, 5),
				BackgroundTransparency = 1,
				Text = slText,
				TextColor3 = Library.Theme.Text,
				Font = Library.Theme.Font,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left
			})

			local valLabel = Library:Create("TextLabel", {
				Parent = slFrame,
				Size = UDim2.new(0, 50, 0, 20),
				Position = UDim2.new(1, -60, 0, 5),
				BackgroundTransparency = 1,
				Text = tostring(default),
				TextColor3 = Library.Theme.Accent,
				Font = Library.Theme.Font,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Right
			})

			local sliderBg = Library:Create("TextButton", {
				Parent = slFrame,
				Size = UDim2.new(1, -20, 0, 6),
				Position = UDim2.new(0, 10, 0, 32),
				BackgroundColor3 = Library.Theme.MainBackground,
				Text = "",
				AutoButtonColor = false
			})
			Library:Create("UICorner", { Parent = sliderBg, CornerRadius = UDim.new(1, 0) })

			local sliderFill = Library:Create("Frame", {
				Parent = sliderBg,
				Size = UDim2.new(math.clamp((default - min) / (max - min), 0, 1), 0, 1, 0),
				BackgroundColor3 = Library.Theme.Accent
			})
			Library:Create("UICorner", { Parent = sliderFill, CornerRadius = UDim.new(1, 0) })

			local dragging = false
			local function updateSlider(input)
				local sizeX = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
				Library:Tween(sliderFill, {Size = UDim2.new(sizeX, 0, 1, 0)}, 0.1)
				local value = math.floor((sizeX * (max - min)) + min)
				valLabel.Text = tostring(value)
				callback(value)
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

		-- Element: Dropdown
		function TabObj:CreateDropdown(options)
			options = options or {}
			local dpName = options.Name or "Dropdown"
			local list = options.Options or {}
			local current = options.CurrentOption or ""
			local callback = options.Callback or function() end

			local dropdownFrame = Library:Create("Frame", {
				Name = "Dropdown_" .. dpName,
				Parent = self.Page,
				Size = UDim2.new(1, -10, 0, 35),
				BackgroundColor3 = Library.Theme.ElementBackground,
				ClipsDescendants = true
			})
			Library:Create("UICorner", { Parent = dropdownFrame, CornerRadius = Library.Theme.CornerRadius })

			local dropdownBtn = Library:Create("TextButton", {
				Parent = dropdownFrame,
				Size = UDim2.new(1, 0, 0, 35),
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false
			})

			Library:Create("TextLabel", {
				Parent = dropdownBtn,
				Size = UDim2.new(1, -40, 1, 0),
				Position = UDim2.new(0, 10, 0, 0),
				BackgroundTransparency = 1,
				Text = dpName .. " : " .. tostring(current),
				TextColor3 = Library.Theme.Text,
				Font = Library.Theme.Font,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left
			})

			local arrow = Library:Create("TextLabel", {
				Parent = dropdownBtn,
				Size = UDim2.new(0, 35, 0, 35),
				Position = UDim2.new(1, -35, 0, 0),
				BackgroundTransparency = 1,
				Text = "v",
				TextColor3 = Library.Theme.Accent,
				Font = Enum.Font.GothamBold,
				TextSize = 16
			})

			local listContainer = Library:Create("ScrollingFrame", {
				Parent = dropdownFrame,
				Size = UDim2.new(1, 0, 1, -35),
				Position = UDim2.new(0, 0, 0, 35),
				BackgroundTransparency = 1,
				ScrollBarThickness = 2,
				ScrollBarImageColor3 = Library.Theme.Accent,
				CanvasSize = UDim2.new(0, 0, 0, 0)
			})
			local listLayout = Library:Create("UIListLayout", {
				Parent = listContainer,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 2)
			})

			local isOpen = false
			local function toggleDropdown()
				isOpen = not isOpen
				if isOpen then
					local targetHeight = math.clamp(35 + (#list * 30) + (#list * 2), 35, 150)
					Library:Tween(dropdownFrame, {Size = UDim2.new(1, -10, 0, targetHeight)}, 0.2)
					Library:Tween(arrow, {Rotation = 180}, 0.2)
				else
					Library:Tween(dropdownFrame, {Size = UDim2.new(1, -10, 0, 35)}, 0.2)
					Library:Tween(arrow, {Rotation = 0}, 0.2)
				end
			end

			dropdownBtn.MouseButton1Click:Connect(toggleDropdown)

			local function refreshList(newOptions)
				list = newOptions
				for _, child in pairs(listContainer:GetChildren()) do
					if child:IsA("TextButton") then child:Destroy() end
				end

				for _, option in pairs(list) do
					local optBtn = Library:Create("TextButton", {
						Parent = listContainer,
						Size = UDim2.new(1, 0, 0, 30),
						BackgroundTransparency = 1,
						Text = option,
						TextColor3 = Library.Theme.TextDim,
						Font = Library.Theme.Font,
						TextSize = 13
					})
					optBtn.MouseEnter:Connect(function() Library:Tween(optBtn, {TextColor3 = Library.Theme.Accent}, 0.1) end)
					optBtn.MouseLeave:Connect(function() Library:Tween(optBtn, {TextColor3 = Library.Theme.TextDim}, 0.1) end)
					optBtn.MouseButton1Click:Connect(function()
						current = option
						dropdownBtn.TextLabel.Text = dpName .. " : " .. tostring(current)
						toggleDropdown()
						callback(current)
					end)
				end
				listContainer.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
			end

			refreshList(list)

			return {
				Refresh = refreshList,
				Set = function(val)
					current = val
					dropdownBtn.TextLabel.Text = dpName .. " : " .. tostring(current)
					callback(current)
				end
			}
		end

		return TabObj
	end

	return Window
end

return Library
