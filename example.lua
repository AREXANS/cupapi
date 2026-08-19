-- Ensure you place Library.lua appropriately if not loading remotely
local Library = require(script.Parent:WaitForChild("Library")) or loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_NAME/YOUR_REPO/main/Library.lua"))()

-- Create the Main Window
local Window = Library:CreateWindow({
    Name = "Blue Glow UI"
})

-- Create Tabs
local MainTab = Window:CreateTab({Name = "Main Features"})
local SettingsTab = Window:CreateTab({Name = "Settings"})

-- Populate Main Tab
MainTab:CreateButton({
    Name = "Kill All Enemies",
    Callback = function()
        print("Killed all enemies!")
    end
})

MainTab:CreateToggle({
    Name = "Auto Farm",
    CurrentValue = false,
    Callback = function(Value)
        print("Auto Farm is now: ", Value)
    end
})

MainTab:CreateSlider({
    Name = "WalkSpeed",
    Range = {16, 100},
    CurrentValue = 16,
    Callback = function(Value)
        if game.Players.LocalPlayer and game.Players.LocalPlayer.Character and game.Players.LocalPlayer.Character:FindFirstChild("Humanoid") then
            game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = Value
        end
        print("WalkSpeed set to: ", Value)
    end
})

MainTab:CreateDropdown({
    Name = "Select Weapon",
    Options = {"Sword", "Bow", "Magic Staff"},
    CurrentOption = "Sword",
    Callback = function(Option)
        print("Equipped: ", Option)
    end
})

-- Populate Settings Tab
SettingsTab:CreateToggle({
    Name = "ESP",
    CurrentValue = true,
    Callback = function(Value)
        print("ESP is now: ", Value)
    end
})