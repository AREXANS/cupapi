-- Initialize Library
local Library = require(script.Parent:WaitForChild("Library")) or loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_NAME/YOUR_REPO/main/Library.lua"))()

-- Create Window (Mini Layout)
local Window = Library:CreateWindow({
    Name = "Glow UI Mini",
    Size = UDim2.new(0, 480, 0, 300), -- Compact UI
    HideBind = Enum.KeyCode.RightControl
})

-- Create Tabs
local MainTab = Window:CreateTab({ Name = "Main", Icon = "rbxassetid://1" })
local VisTab = Window:CreateTab({ Name = "Visuals" })
local SetTab = Window:CreateTab({ Name = "Settings" })

-- == Main Tab ==
MainTab:CreateSection("Combat Info")

MainTab:CreateLabel("Welcome to the ultimate compact script UI. Below are your standard combat tools.")

MainTab:CreateButton({
    Name = "Kill Aura",
    Callback = function()
        Library:Notify({
            Title = "Combat Action",
            Content = "Kill aura activated!",
            Duration = 3
        })
    end
})

MainTab:CreateToggle({
    Name = "Auto Heal",
    CurrentValue = false,
    Flag = "AutoHeal",
    Callback = function(Value)
        print("Auto Heal:", Value)
    end
})

MainTab:CreateSlider({
    Name = "Hitbox Expander",
    Range = {1, 25},
    Increment = 1,
    CurrentValue = 5,
    Flag = "HitboxSize",
    Callback = function(Value)
        print("Hitbox Size set to:", Value)
    end
})

MainTab:CreateDropdown({
    Name = "Target Priority",
    Options = {"Distance", "Health", "Threat Level"},
    CurrentOption = "Distance",
    Flag = "TargetPriority",
    Callback = function(Option)
        print("Targeting by:", Option)
    end
})

-- == Visuals Tab ==
VisTab:CreateSection("ESP Settings")

VisTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = true,
    Flag = "ESPEnabled",
    Callback = function(Value)
        Library:Notify({
            Title = "Visuals",
            Content = "ESP Toggled: " .. tostring(Value),
            Duration = 2
        })
    end
})

VisTab:CreateDropdown({
    Name = "ESP Mode",
    Options = {"Boxes", "Skeletons", "Chams"},
    CurrentOption = "Boxes",
    Flag = "ESPMode",
    Callback = function(Option)
        print("ESP Mode:", Option)
    end
})

-- == Settings Tab ==
SetTab:CreateSection("UI Settings")

SetTab:CreateKeybind({
    Name = "Hide UI Keybind",
    CurrentKeybind = Enum.KeyCode.RightControl,
    Flag = "UIBind",
    Callback = function()
        print("Hide UI key pressed!")
    end
})

SetTab:CreateInput({
    Name = "Custom Webhook URL",
    Placeholder = "https://discord.com/api/webhooks/...",
    Flag = "DiscordWebhook",
    Callback = function(Text)
        print("Webhook updated to:", Text)
    end
})

SetTab:CreateButton({
    Name = "Unload UI",
    Callback = function()
        for _, v in pairs(game.CoreGui:GetChildren()) do
            if v.Name == "BlueGlowUI" or v.Name == "BlueGlowNotifs" then
                v:Destroy()
            end
        end
    end
})

-- Test Notifications automatically on load
Library:Notify({
    Title = "Successfully Loaded!",
    Content = "The Blue Glow UI script has been loaded properly.",
    Duration = 5
})
