# Blue Glow UI Library

A modern, animated, and highly customizable UI library for Roblox scripts, featuring a futuristic neon blue aesthetic. Designed to be a drop-in replacement for libraries like WindUI, Obsidian, and Rayfield.

## Features
- **Smooth Animations**: Built-in TweenService scaling, fading, and glowing.
- **Neon Aesthetic**: Dark translucent backgrounds with pulsating blue outlines (`UIStroke`).
- **Interactive Components**: Buttons, Toggles, Sliders, Dropdowns, and Sections.
- **Draggable Windows**: Smooth, un-obstructive dragging logic.

## Usage Example

```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_GITHUB_NAME/YOUR_REPO/main/Library.lua"))()

local Window = Library:CreateWindow({
    Title = "Sci-Fi Hub",
    Size = UDim2.new(0, 650, 0, 400)
})

local Tab = Window:CreateTab("Combat")

Tab:CreateSection("Aimbot Settings")

Tab:CreateButton({
    Name = "Activate Aura",
    Callback = function()
        print("Aura activated")
    end
})

Tab:CreateToggle({
    Name = "Silent Aim",
    CurrentValue = false,
    Callback = function(state)
        print("Silent Aim: ", state)
    end
})

Tab:CreateSlider({
    Name = "FOV Radius",
    Range = {0, 500},
    CurrentValue = 100,
    Callback = function(val)
        print("FOV:", val)
    end
})

Tab:CreateDropdown({
    Name = "Target Part",
    Options = {"Head", "Torso", "HumanoidRootPart"},
    CurrentOption = "Head",
    Callback = function(opt)
        print("Targetting:", opt)
    end
})
```
