--[[
    🐾 BamHub v2.0 - Complete Multi-Page System
    Advanced Auto Elephant & Leveling System for Grow a Garden
    
    NEW: Multi-page navigation system
    NEW: Target Pets page with checkbox selection
    NEW: Separate Elephant/Leveling team pages
    
    Pages: Growth | Elephant | Leveling | Target Pets | Config
    
    Total Lines: ~2000+
    Version: 2.0
]]

-- ========================================
-- SERVICES
-- ========================================
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- ========================================
-- CONFIGURATION
-- ========================================
local Config = {
    Version = "2.0",
    Name = "BamHub",
    Logo = "🐾",
    
    Growth = {
        TargetBaseKG = 3.5,
        ElephantMode = "C",
        EnableAutoElephant = false,
        EnableAutoLeveling = false,
        EnableAutoMutation = false
    },
    
    Elephant = {
        Team = {}, -- Array of pet objects
        LevelBefore = 50,
        MaxTargetPets = 10
    },
    
    Leveling = {
        Phase1 = {
            Team = {}, -- Array of pet objects
            Target = 50,
            MaxPets = 10
        },
        Phase2 = {
            Team = {}, -- Array of pet objects  
            Target = 500,
            MaxPets = 10
        },
        WaveSize = 0
    },
    
    TargetPets = {
        Selected = {}, -- Array of selected non-fav pet IDs
        Filter = "All"
    },
    
    General = {
        BatchMode = false,
        GlobalWaveSize = 0
    },
    
    UI = {
        CurrentPage = "Growth",
        IsMinimized = false,
        IsRunning = false,
        Position = UDim2.new(0.5, -250, 0.5, -300),
        Size = UDim2.new(0, 500, 0, 650)
    }
}

-- ========================================
-- STATE MANAGEMENT
-- ========================================
local State = {
    CurrentPhase = "Idle",
    CurrentStep = "",
    StepNumber = 0,
    TotalSteps = 0,
    ProcessedPets = 0,
    TotalPets = 0,
    StatusMessage = "[⏹ IDLE] Ready to start",
    
    AllPets = {},
    FavoritePets = {},
    NonFavoritePets = {},
    SelectedTargets = {},
    
    PetLocation = nil,
    DetectionMethod = "unknown",
    UIElements = {},
    
    RemoteCache = {
        LevelUp = nil,
        ElephantReset = nil,
        EquipPet = nil
    },
    
    Pages = {"Growth", "Elephant", "Leveling", "Target Pets", "Config"}
}
-- ========================================
-- UTILITY FUNCTIONS
-- ========================================
local function Wait(seconds)
    task.wait(seconds or 0.5)
end

local function UpdateStatus(message, statusType)
    local icon = "[ℹ️ INFO]"
    if statusType == "running" then
        icon = "[▶ RUNNING]"
    elseif statusType == "error" then
        icon = "[❌ ERROR]"
    elseif statusType == "success" then
        icon = "[✅ SUCCESS]"
    elseif statusType == "idle" then
        icon = "[⏹ IDLE]"
    elseif statusType == "pause" then
        icon = "[⏸ PAUSED]"
    end
    
    State.StatusMessage = icon .. " " .. message
    
    if State.UIElements.StatusLabel then
        State.UIElements.StatusLabel.Text = State.StatusMessage
    end
end

local function CreateUICorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = parent
    return corner
end

local function CreateUIStroke(parent, color, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Color3.fromRGB(60, 60, 70)
    stroke.Thickness = thickness or 1
    stroke.Parent = parent
    return stroke
end

-- ========================================
-- PET DETECTION & MANAGEMENT
-- ========================================
local function AutoDetectPetLocation()
    if State.PetLocation then
        return State.PetLocation, State.DetectionMethod
    end
    
    UpdateStatus("Detecting pet location...", "info")
    
    local playerGui = LocalPlayer.PlayerGui
    for _, gui in pairs(playerGui:GetChildren()) do
        if gui:IsA("ScreenGui") then
            for _, frame in pairs(gui:GetDescendants()) do
                if (frame:IsA("Frame") or frame:IsA("ScrollingFrame")) and #frame:GetChildren() > 3 then
                    local name = string.lower(frame.Name)
                    if string.find(name, "pet") or string.find(name, "inventory") then
                        State.PetLocation = frame
                        State.DetectionMethod = "PlayerGui"
                        UpdateStatus("Pets found in PlayerGui", "success")
                        return frame, "PlayerGui"
                    end
                end
            end
        end
    end
    
    if LocalPlayer:FindFirstChild("PlayerData") then
        for _, child in pairs(LocalPlayer.PlayerData:GetDescendants()) do
            local name = string.lower(child.Name)
            if (string.find(name, "pet") or string.find(name, "animal")) and child:IsA("Folder") then
                State.PetLocation = child
                State.DetectionMethod = "PlayerData"
                UpdateStatus("Pets found in PlayerData", "success")
                return child, "PlayerData"
            end
        end
    end
    
    UpdateStatus("Pet location not detected", "error")
    return nil, "none"
end

local function GetAllPets()
    local pets = {}
    local location, method = AutoDetectPetLocation()
    
    if not location then
        return pets
    end
    
    State.AllPets = {}
    State.FavoritePets = {}
    State.NonFavoritePets = {}
    
    if method == "PlayerGui" then
        for _, petFrame in pairs(location:GetChildren()) do
            if petFrame:IsA("Frame") and petFrame.Visible then
                local petData = {
                    Instance = petFrame,
                    PetId = petFrame.Name,
                    Name = "Unknown",
                    Level = 0,
                    BaseKG = 0,
                    IsFavorite = false,
                    Rarity = "Common"
                }
                
                for _, child in pairs(petFrame:GetDescendants()) do
                    if child:IsA("TextLabel") or child:IsA("TextButton") then
                        local text = child.Text
                        local childName = string.lower(child.Name)
                        
                        if string.find(childName, "level") or string.find(childName, "lvl") then
                            petData.Level = tonumber(text:match("%d+")) or 0
                        elseif string.find(text, "kg") or string.find(text, "KG") then
                            petData.BaseKG = tonumber(text:match("%d+%.?%d*")) or 0
                        elseif string.find(childName, "name") or string.find(childName, "pet") then
                            if not string.find(text, "%d") and text ~= "" and #text > 2 then
                                petData.Name = text
                            end
                        end
                    end
                    
                    if child:IsA("ImageLabel") or child:IsA("ImageButton") then
                        local childName = string.lower(child.Name)
                        if string.find(childName, "fav") or string.find(childName, "star") then
                            petData.IsFavorite = child.Visible or (child.ImageTransparency < 1)
                        end
                    end
                end
                
                table.insert(pets, petData)
                table.insert(State.AllPets, petData)
                
                if petData.IsFavorite then
                    table.insert(State.FavoritePets, petData)
                else
                    table.insert(State.NonFavoritePets, petData)
                end
            end
        end
    end
    
    UpdateStatus(string.format("Found %d pets (%d favorites, %d non-favorites)", 
        #State.AllPets, #State.FavoritePets, #State.NonFavoritePets), "success")
    
    return pets
end
-- ========================================
-- REMOTE FUNCTIONS
-- ========================================
local function FindRemote(keywords)
    if not ReplicatedStorage then return nil end
    
    for _, obj in pairs(ReplicatedStorage:GetDescendants()) do
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            local name = string.lower(obj.Name)
            for _, keyword in pairs(keywords) do
                if string.find(name, string.lower(keyword)) then
                    return obj
                end
            end
        end
    end
    return nil
end

local function LevelUpPet(pet, targetLevel)
    if not State.RemoteCache.LevelUp then
        State.RemoteCache.LevelUp = FindRemote({"levelup", "level", "upgrade"})
    end
    
    if State.RemoteCache.LevelUp then
        local success = pcall(function()
            if State.RemoteCache.LevelUp:IsA("RemoteEvent") then
                State.RemoteCache.LevelUp:FireServer(pet.PetId, targetLevel)
            else
                State.RemoteCache.LevelUp:InvokeServer(pet.PetId, targetLevel)
            end
        end)
        if success then
            Wait(0.3)
            return true
        end
    end
    return false
end

local function ElephantReset(pet)
    if not State.RemoteCache.ElephantReset then
        State.RemoteCache.ElephantReset = FindRemote({"elephant", "reset", "rebirth"})
    end
    
    if State.RemoteCache.ElephantReset then
        local success = pcall(function()
            if State.RemoteCache.ElephantReset:IsA("RemoteEvent") then
                State.RemoteCache.ElephantReset:FireServer(pet.PetId)
            else
                State.RemoteCache.ElephantReset:InvokeServer(pet.PetId)
            end
        end)
        if success then
            Wait(0.5)
            return true
        end
    end
    return false
end

local function EquipTeam(teamPets)
    if not State.RemoteCache.EquipPet then
        State.RemoteCache.EquipPet = FindRemote({"equip", "equipet", "setpet"})
    end
    
    if State.RemoteCache.EquipPet and teamPets then
        for slot, pet in pairs(teamPets) do
            if pet then
                pcall(function()
                    if State.RemoteCache.EquipPet:IsA("RemoteEvent") then
                        State.RemoteCache.EquipPet:FireServer(slot, pet.PetId)
                    else
                        State.RemoteCache.EquipPet:InvokeServer(slot, pet.PetId)
                    end
                end)
                Wait(0.1)
            end
        end
        Wait(0.3)
        return true
    end
    return false
end

-- ========================================
-- AUTOMATION LOGIC
-- ========================================
local function GetSelectedTargets()
    local selected = {}
    for _, pet in pairs(State.NonFavoritePets) do
        if Config.TargetPets.Selected[pet.PetId] then
            table.insert(selected, pet)
        end
    end
    return selected
end

local function RunElephantMode()
    UpdateStatus("Starting Elephant Mode", "running")
    State.CurrentStep = "Elephant Mode"
    
    local targetPets = GetSelectedTargets()
    if #targetPets == 0 then
        UpdateStatus("No target pets selected!", "error")
        return false
    end
    
    State.TotalPets = #targetPets
    State.ProcessedPets = 0
    
    for _, pet in ipairs(targetPets) do
        if not Config.UI.IsRunning then break end
        
        if pet.BaseKG >= Config.Growth.TargetBaseKG then
            UpdateStatus(string.format("Skipping %s (already at target KG)", pet.Name), "info")
            continue
        end
        
        UpdateStatus(string.format("Processing %s (%.1fkg → %.1fkg)", pet.Name, pet.BaseKG, Config.Growth.TargetBaseKG), "running")
        
        -- Level with leveling team
        EquipTeam(Config.Leveling.Phase1.Team)
        LevelUpPet(pet, Config.Elephant.LevelBefore)
        
        -- Reset with elephant team  
        EquipTeam(Config.Elephant.Team)
        ElephantReset(pet)
        
        pet.BaseKG = pet.BaseKG + 0.1
        State.ProcessedPets = State.ProcessedPets + 1
    end
    
    UpdateStatus("Elephant Mode completed", "success")
    return true
end

local function RunLevelingMode()
    UpdateStatus("Starting Leveling Mode", "running")
    State.CurrentStep = "Leveling Mode"
    
    local targetPets = GetSelectedTargets()
    if #targetPets == 0 then
        UpdateStatus("No target pets selected!", "error")
        return false
    end
    
    -- Phase 1
    if Config.Leveling.Phase1.Team and #Config.Leveling.Phase1.Team > 0 then
        UpdateStatus("Leveling Phase 1", "running")
        EquipTeam(Config.Leveling.Phase1.Team)
        
        for _, pet in ipairs(targetPets) do
            if not Config.UI.IsRunning then break end
            UpdateStatus(string.format("Phase 1: Leveling %s to %d", pet.Name, Config.Leveling.Phase1.Target), "running")
            LevelUpPet(pet, Config.Leveling.Phase1.Target)
        end
    end
    
    -- Phase 2  
    if Config.Leveling.Phase2.Team and #Config.Leveling.Phase2.Team > 0 then
        UpdateStatus("Leveling Phase 2", "running")
        EquipTeam(Config.Leveling.Phase2.Team)
        
        for _, pet in ipairs(targetPets) do
            if not Config.UI.IsRunning then break end
            UpdateStatus(string.format("Phase 2: Leveling %s to %d", pet.Name, Config.Leveling.Phase2.Target), "running")
            LevelUpPet(pet, Config.Leveling.Phase2.Target)
        end
    end
    
    UpdateStatus("Leveling Mode completed", "success")
    return true
end
-- ========================================
-- UI COMPONENTS
-- ========================================
local function CreateLabel(parent, text, position, size)
    local label = Instance.new("TextLabel")
    label.Size = size or UDim2.new(0, 120, 0, 30)
    label.Position = position or UDim2.new(0, 10, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Color3.fromRGB(200, 200, 200)
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
    return label
end

local function CreateButton(parent, text, position, size, color, callback)
    local button = Instance.new("TextButton")
    button.Size = size or UDim2.new(0, 100, 0, 40)
    button.Position = position or UDim2.new(0, 10, 0, 0)
    button.BackgroundColor3 = color or Color3.fromRGB(60, 140, 220)
    button.Text = text
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 14
    button.Parent = parent
    CreateUICorner(button, 6)
    
    if callback then
        button.MouseButton1Click:Connect(callback)
    end
    
    return button
end

local function CreateToggle(parent, text, position, defaultValue, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 40)
    frame.Position = position
    frame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    CreateUICorner(frame, 6)
    
    local label = CreateLabel(frame, text, UDim2.new(0, 10, 0, 5), UDim2.new(0, 300, 1, 0))
    
    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 60, 0, 30)
    toggle.Position = UDim2.new(1, -70, 0, 5)
    toggle.BackgroundColor3 = defaultValue and Color3.fromRGB(60, 140, 220) or Color3.fromRGB(80, 80, 85)
    toggle.Text = defaultValue and "ON" or "OFF"
    toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 14
    toggle.Parent = frame
    CreateUICorner(toggle, 6)
    
    toggle.MouseButton1Click:Connect(function()
        defaultValue = not defaultValue
        toggle.BackgroundColor3 = defaultValue and Color3.fromRGB(60, 140, 220) or Color3.fromRGB(80, 80, 85)
        toggle.Text = defaultValue and "ON" or "OFF"
        if callback then callback(defaultValue) end
    end)
    
    return frame, toggle
end

local function CreateInputBox(parent, text, position, defaultValue, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 40)
    frame.Position = position
    frame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    CreateUICorner(frame, 6)
    
    CreateLabel(frame, text, UDim2.new(0, 10, 0, 5), UDim2.new(0, 200, 1, 0))
    
    local input = Instance.new("TextBox")
    input.Size = UDim2.new(0, 100, 0, 30)
    input.Position = UDim2.new(1, -110, 0, 5)
    input.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    input.Text = tostring(defaultValue)
    input.TextColor3 = Color3.fromRGB(255, 255, 255)
    input.Font = Enum.Font.Gotham
    input.TextSize = 13
    input.ClearTextOnFocus = false
    input.Parent = frame
    CreateUICorner(input, 6)
    
    input.FocusLost:Connect(function()
        if callback then
            local value = tonumber(input.Text) or defaultValue
            callback(value)
        end
    end)
    
    return frame, input
end

local function CreateDropdown(parent, text, position, options, defaultOption, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 40)
    frame.Position = position
    frame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    CreateUICorner(frame, 6)
    
    CreateLabel(frame, text, UDim2.new(0, 10, 0, 5), UDim2.new(0, 150, 1, 0))
    
    local dropdown = Instance.new("TextButton")
    dropdown.Size = UDim2.new(0, 150, 0, 30)
    dropdown.Position = UDim2.new(1, -160, 0, 5)
    dropdown.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    dropdown.Text = defaultOption .. " ▼"
    dropdown.TextColor3 = Color3.fromRGB(255, 255, 255)
    dropdown.Font = Enum.Font.Gotham
    dropdown.TextSize = 13
    dropdown.Parent = frame
    CreateUICorner(dropdown, 6)
    
    local isOpen = false
    local optionsFrame = Instance.new("ScrollingFrame")
    optionsFrame.Size = UDim2.new(0, 150, 0, math.min(#options * 35, 200))
    optionsFrame.Position = UDim2.new(1, -160, 0, 40)
    optionsFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    optionsFrame.BorderSizePixel = 0
    optionsFrame.Visible = false
    optionsFrame.ScrollBarThickness = 4
    optionsFrame.ZIndex = 10
    optionsFrame.Parent = frame
    CreateUICorner(optionsFrame, 6)
    
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 2)
    layout.Parent = optionsFrame
    
    for i, option in ipairs(options) do
        local optionBtn = Instance.new("TextButton")
        optionBtn.Size = UDim2.new(1, -5, 0, 30)
        optionBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
        optionBtn.Text = option
        optionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        optionBtn.Font = Enum.Font.Gotham
        optionBtn.TextSize = 13
        optionBtn.ZIndex = 11
        optionBtn.Parent = optionsFrame
        CreateUICorner(optionBtn, 4)
        
        optionBtn.MouseButton1Click:Connect(function()
            dropdown.Text = option .. " ▼"
            optionsFrame.Visible = false
            isOpen = false
            if callback then callback(option) end
        end)
    end
    
    optionsFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y)
    
    dropdown.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        optionsFrame.Visible = isOpen
    end)
    
    return frame, dropdown
end
-- ========================================
-- MAIN UI SYSTEM
-- ========================================
local function CreateMainUI()
    local existingUI = LocalPlayer.PlayerGui:FindFirstChild("BamHubUI")
    if existingUI then existingUI:Destroy() end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "BamHubUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = LocalPlayer.PlayerGui
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = Config.UI.Size
    MainFrame.Position = Config.UI.Position
    MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui
    CreateUICorner(MainFrame, 12)
    CreateUIStroke(MainFrame, Color3.fromRGB(60, 60, 70), 2)
    
    State.UIElements.MainFrame = MainFrame
    State.UIElements.ScreenGui = ScreenGui
    
    -- Header
    local Header = Instance.new("Frame")
    Header.Name = "Header"
    Header.Size = UDim2.new(1, 0, 0, 50)
    Header.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    Header.BorderSizePixel = 0
    Header.Parent = MainFrame
    CreateUICorner(Header, 12)
    
    local HeaderCover = Instance.new("Frame")
    HeaderCover.Size = UDim2.new(1, 0, 0, 10)
    HeaderCover.Position = UDim2.new(0, 0, 1, -10)
    HeaderCover.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    HeaderCover.BorderSizePixel = 0
    HeaderCover.Parent = Header
    
    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(0, 200, 1, 0)
    Title.Position = UDim2.new(0, 15, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = Config.Logo .. " " .. Config.Name .. " v" .. Config.Version
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 18
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Header
    
    local MinimizeBtn = Instance.new("TextButton")
    MinimizeBtn.Size = UDim2.new(0, 40, 0, 40)
    MinimizeBtn.Position = UDim2.new(1, -90, 0, 5)
    MinimizeBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    MinimizeBtn.Text = "—"
    MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinimizeBtn.TextSize = 18
    MinimizeBtn.Font = Enum.Font.GothamBold
    MinimizeBtn.Parent = Header
    CreateUICorner(MinimizeBtn, 8)
    
    local CloseBtn = Instance.new("TextButton")
    CloseBtn.Size = UDim2.new(0, 40, 0, 40)
    CloseBtn.Position = UDim2.new(1, -45, 0, 5)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    CloseBtn.Text = "X"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.TextSize = 18
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.Parent = Header
    CreateUICorner(CloseBtn, 8)
    
    CloseBtn.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
        Config.UI.IsRunning = false
    end)
    
    -- Minimized Bar
    local MinimizedBar = Instance.new("TextButton")
    MinimizedBar.Name = "MinimizedBar"
    MinimizedBar.Size = UDim2.new(0, 150, 0, 40)
    MinimizedBar.Position = UDim2.new(1, -160, 0, 10)
    MinimizedBar.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    MinimizedBar.Text = Config.Logo .. " " .. Config.Name .. " ▶"
    MinimizedBar.TextColor3 = Color3.fromRGB(255, 255, 255)
    MinimizedBar.TextSize = 16
    MinimizedBar.Font = Enum.Font.GothamBold
    MinimizedBar.Visible = false
    MinimizedBar.Parent = ScreenGui
    CreateUICorner(MinimizedBar, 10)
    
    MinimizeBtn.MouseButton1Click:Connect(function()
        Config.UI.IsMinimized = not Config.UI.IsMinimized
        MainFrame.Visible = not Config.UI.IsMinimized
        MinimizedBar.Visible = Config.UI.IsMinimized
    end)
    
    MinimizedBar.MouseButton1Click:Connect(function()
        Config.UI.IsMinimized = false
        MainFrame.Visible = true
        MinimizedBar.Visible = false
    end)
    
    return MainFrame
end

-- ========================================
-- PAGE NAVIGATION SYSTEM
-- ========================================
local function CreatePageNavigation(parent)
    local NavBar = Instance.new("Frame")
    NavBar.Size = UDim2.new(1, -20, 0, 50)
    NavBar.Position = UDim2.new(0, 10, 0, 60)
    NavBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    NavBar.BorderSizePixel = 0
    NavBar.Parent = parent
    CreateUICorner(NavBar, 8)
    
    local pageButtons = {}
    local pageFrames = {}
    
    -- Create page buttons
    for i, pageName in ipairs(State.Pages) do
        local PageButton = Instance.new("TextButton")
        PageButton.Size = UDim2.new(0.2, -4, 1, -10)
        PageButton.Position = UDim2.new((i-1) * 0.2, 2 + (i-1) * 2, 0, 5)
        PageButton.BackgroundColor3 = (i == 1) and Color3.fromRGB(60, 140, 220) or Color3.fromRGB(40, 40, 45)
        PageButton.Text = pageName
        PageButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        PageButton.Font = Enum.Font.GothamSemibold
        PageButton.TextSize = 12
        PageButton.Parent = NavBar
        CreateUICorner(PageButton, 6)
        
        -- Create page content frame
        local PageFrame = Instance.new("ScrollingFrame")
        PageFrame.Name = pageName .. "Page"
        PageFrame.Size = UDim2.new(1, -20, 1, -200)
        PageFrame.Position = UDim2.new(0, 10, 0, 120)
        PageFrame.BackgroundTransparency = 1
        PageFrame.BorderSizePixel = 0
        PageFrame.ScrollBarThickness = 6
        PageFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 140, 220)
        PageFrame.Visible = (i == 1)
        PageFrame.Parent = parent
        
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 8)
        layout.Parent = PageFrame
        
        task.spawn(function()
            while task.wait(0.1) do
                if PageFrame and PageFrame.Parent then
                    PageFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
                else
                    break
                end
            end
        end)
        
        pageButtons[pageName] = PageButton
        pageFrames[pageName] = PageFrame
        
        -- Page switching logic
        PageButton.MouseButton1Click:Connect(function()
            for name, button in pairs(pageButtons) do
                button.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
                pageFrames[name].Visible = false
            end
            PageButton.BackgroundColor3 = Color3.fromRGB(60, 140, 220)
            PageFrame.Visible = true
            Config.UI.CurrentPage = pageName
        end)
    end
    
    return pageButtons, pageFrames
end
-- ========================================
-- TARGET PETS PAGE
-- ========================================
local function PopulateTargetPetsPage(pageFrame)
    local yOffset = 10
    
    -- Header
    local headerFrame = Instance.new("Frame")
    headerFrame.Size = UDim2.new(1, -20, 0, 50)
    headerFrame.Position = UDim2.new(0, 10, 0, yOffset)
    headerFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    headerFrame.BorderSizePixel = 0
    headerFrame.Parent = pageFrame
    CreateUICorner(headerFrame, 8)
    
    CreateLabel(headerFrame, "🎯 Target Pets Selection", UDim2.new(0, 10, 0, 10), UDim2.new(0, 200, 0, 30)).Font = Enum.Font.GothamBold
    CreateLabel(headerFrame, "🎯 Target Pets Selection", UDim2.new(0, 10, 0, 10), UDim2.new(0, 200, 0, 30)).TextSize = 16
    
    -- Filter and Refresh
    local filterFrame = Instance.new("Frame")
    filterFrame.Size = UDim2.new(1, -20, 0, 40)
    filterFrame.Position = UDim2.new(0, 10, 0, 60)
    filterFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    filterFrame.BorderSizePixel = 0
    filterFrame.Parent = pageFrame
    CreateUICorner(filterFrame, 6)
    
    CreateLabel(filterFrame, "🔍 Filter:", UDim2.new(0, 10, 0, 5), UDim2.new(0, 60, 1, 0))
    
    local filterDropdown = CreateDropdown(filterFrame, "", UDim2.new(0, 70, 0, 0), 
        {"All", "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical"}, 
        Config.TargetPets.Filter, function(value)
            Config.TargetPets.Filter = value
            -- Refresh the list
            PopulateTargetPetsPage(pageFrame)
        end)
    
    local refreshBtn = CreateButton(filterFrame, "↺ Refresh", UDim2.new(1, -100, 0, 5), UDim2.new(0, 90, 0, 30), 
        Color3.fromRGB(60, 140, 220), function()
            GetAllPets()
            PopulateTargetPetsPage(pageFrame)
        end)
    
    -- Pet List Container
    local petListContainer = Instance.new("ScrollingFrame")
    petListContainer.Size = UDim2.new(1, -20, 0, 350)
    petListContainer.Position = UDim2.new(0, 10, 0, 110)
    petListContainer.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    petListContainer.BorderSizePixel = 0
    petListContainer.ScrollBarThickness = 6
    petListContainer.Parent = pageFrame
    CreateUICorner(petListContainer, 8)
    
    local petListLayout = Instance.new("UIListLayout")
    petListLayout.Padding = UDim.new(0, 2)
    petListLayout.Parent = petListContainer
    
    -- Populate pet list
    local displayPets = State.NonFavoritePets
    if Config.TargetPets.Filter ~= "All" then
        displayPets = {}
        for _, pet in pairs(State.NonFavoritePets) do
            if string.find(string.lower(pet.Name), string.lower(Config.TargetPets.Filter)) then
                table.insert(displayPets, pet)
            end
        end
    end
    
    for _, pet in pairs(displayPets) do
        local petFrame = Instance.new("Frame")
        petFrame.Size = UDim2.new(1, -10, 0, 35)
        petFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
        petFrame.BorderSizePixel = 0
        petFrame.Parent = petListContainer
        CreateUICorner(petFrame, 4)
        
        -- Checkbox
        local checkbox = Instance.new("TextButton")
        checkbox.Size = UDim2.new(0, 30, 0, 30)
        checkbox.Position = UDim2.new(0, 5, 0, 2.5)
        checkbox.BackgroundColor3 = Config.TargetPets.Selected[pet.PetId] and Color3.fromRGB(60, 180, 90) or Color3.fromRGB(80, 80, 85)
        checkbox.Text = Config.TargetPets.Selected[pet.PetId] and "✓" or " "
        checkbox.TextColor3 = Color3.fromRGB(255, 255, 255)
        checkbox.Font = Enum.Font.GothamBold
        checkbox.TextSize = 16
        checkbox.Parent = petFrame
        CreateUICorner(checkbox, 4)
        
        checkbox.MouseButton1Click:Connect(function()
            Config.TargetPets.Selected[pet.PetId] = not Config.TargetPets.Selected[pet.PetId]
            checkbox.BackgroundColor3 = Config.TargetPets.Selected[pet.PetId] and Color3.fromRGB(60, 180, 90) or Color3.fromRGB(80, 80, 85)
            checkbox.Text = Config.TargetPets.Selected[pet.PetId] and "✓" or " "
            
            -- Update selection count
            local selectedCount = 0
            for _, selected in pairs(Config.TargetPets.Selected) do
                if selected then selectedCount = selectedCount + 1 end
            end
            State.UIElements.SelectionCount.Text = string.format("Selected: %d / %d non-fav pets", selectedCount, #State.NonFavoritePets)
        end)
        
        -- Pet Name and KG
        local petLabel = CreateLabel(petFrame, pet.Name, UDim2.new(0, 45, 0, 2), UDim2.new(0, 300, 0, 30))
        petLabel.TextSize = 13
        
        if pet.BaseKG > 0 then
            local kgLabel = CreateLabel(petFrame, string.format("%.2f KG", pet.BaseKG), UDim2.new(1, -80, 0, 2), UDim2.new(0, 75, 0, 30))
            kgLabel.TextSize = 12
            kgLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        end
    end
    
    petListContainer.CanvasSize = UDim2.new(0, 0, 0, petListLayout.AbsoluteContentSize.Y)
    
    -- Selection Controls
    local controlFrame = Instance.new("Frame")
    controlFrame.Size = UDim2.new(1, -20, 0, 80)
    controlFrame.Position = UDim2.new(0, 10, 0, 470)
    controlFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    controlFrame.BorderSizePixel = 0
    controlFrame.Parent = pageFrame
    CreateUICorner(controlFrame, 8)
    
    -- Selection count
    local selectedCount = 0
    for _, selected in pairs(Config.TargetPets.Selected) do
        if selected then selectedCount = selectedCount + 1 end
    end
    
    State.UIElements.SelectionCount = CreateLabel(controlFrame, string.format("Selected: %d / %d non-fav pets", selectedCount, #State.NonFavoritePets), 
        UDim2.new(0, 10, 0, 10), UDim2.new(1, -20, 0, 30))
    State.UIElements.SelectionCount.Font = Enum.Font.GothamSemibold
    State.UIElements.SelectionCount.TextSize = 14
    
    -- Control buttons
    CreateButton(controlFrame, "Select All", UDim2.new(0, 10, 0, 45), UDim2.new(0, 120, 0, 30), 
        Color3.fromRGB(60, 180, 90), function()
            for _, pet in pairs(displayPets) do
                Config.TargetPets.Selected[pet.PetId] = true
            end
            PopulateTargetPetsPage(pageFrame)
        end)
    
    CreateButton(controlFrame, "Deselect All", UDim2.new(0, 140, 0, 45), UDim2.new(0, 120, 0, 30), 
        Color3.fromRGB(200, 80, 80), function()
            Config.TargetPets.Selected = {}
            PopulateTargetPetsPage(pageFrame)
        end)
end
-- ========================================
-- ELEPHANT TEAM PAGE
-- ========================================
local function PopulateElephantPage(pageFrame)
    local yOffset = 10
    
    CreateLabel(pageFrame, "═══ 🐘 Elephant Team Configuration ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).TextSize = 16
    CreateLabel(pageFrame, "═══ 🐘 Elephant Team Configuration ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).Font = Enum.Font.GothamBold
    yOffset = yOffset + 40
    
    -- Info label
    local infoLabel = CreateLabel(pageFrame, "Select favorite pets for elephant reset team:", 
        UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30))
    infoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    infoLabel.TextSize = 13
    yOffset = yOffset + 40
    
    -- Pet slots for elephant team
    for i = 1, 4 do
        local slotFrame = Instance.new("Frame")
        slotFrame.Size = UDim2.new(1, -20, 0, 50)
        slotFrame.Position = UDim2.new(0, 10, 0, yOffset)
        slotFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
        slotFrame.BorderSizePixel = 0
        slotFrame.Parent = pageFrame
        CreateUICorner(slotFrame, 6)
        
        CreateLabel(slotFrame, "Pet " .. i .. ":", UDim2.new(0, 10, 0, 10), UDim2.new(0, 60, 1, 0))
        
        -- Create dropdown with favorite pets
        local favOptions = {"(none)"}
        for _, pet in pairs(State.FavoritePets) do
            table.insert(favOptions, pet.Name)
        end
        
        local currentSelection = "(none)"
        if Config.Elephant.Team[i] then
            currentSelection = Config.Elephant.Team[i].Name
        end
        
        CreateDropdown(slotFrame, "", UDim2.new(0, 80, 0, 0), favOptions, currentSelection, 
            function(selected)
                if selected == "(none)" then
                    Config.Elephant.Team[i] = nil
                else
                    -- Find pet by name
                    for _, pet in pairs(State.FavoritePets) do
                        if pet.Name == selected then
                            Config.Elephant.Team[i] = pet
                            break
                        end
                    end
                end
            end)
        
        yOffset = yOffset + 58
    end
    
    -- Team summary
    local summaryFrame = Instance.new("Frame")
    summaryFrame.Size = UDim2.new(1, -20, 0, 80)
    summaryFrame.Position = UDim2.new(0, 10, 0, yOffset)
    summaryFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    summaryFrame.BorderSizePixel = 0
    summaryFrame.Parent = pageFrame
    CreateUICorner(summaryFrame, 8)
    
    local teamCount = 0
    for _, pet in pairs(Config.Elephant.Team) do
        if pet then teamCount = teamCount + 1 end
    end
    
    CreateLabel(summaryFrame, "Team Summary:", UDim2.new(0, 10, 0, 10), UDim2.new(0, 120, 0, 30)).Font = Enum.Font.GothamSemibold
    CreateLabel(summaryFrame, string.format("Total selected: %d pets", teamCount), UDim2.new(0, 10, 0, 35), UDim2.new(0, 200, 0, 30))
    CreateLabel(summaryFrame, string.format("Max target slots: %d", math.max(0, 8 - teamCount)), UDim2.new(0, 10, 0, 55), UDim2.new(0, 200, 0, 30))
end

-- ========================================
-- LEVELING TEAM PAGE  
-- ========================================
local function PopulateLevelingPage(pageFrame)
    local yOffset = 10
    
    CreateLabel(pageFrame, "═══ 📈 Leveling Teams Configuration ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).TextSize = 16
    CreateLabel(pageFrame, "═══ 📈 Leveling Teams Configuration ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).Font = Enum.Font.GothamBold
    yOffset = yOffset + 50
    
    -- Phase 1 Team
    CreateLabel(pageFrame, "PHASE 1 (Level 0 → 50)", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).Font = Enum.Font.GothamSemibold
    CreateLabel(pageFrame, "PHASE 1 (Level 0 → 50)", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).TextSize = 15
    yOffset = yOffset + 35
    
    for i = 1, 3 do
        local slotFrame = Instance.new("Frame")
        slotFrame.Size = UDim2.new(1, -20, 0, 50)
        slotFrame.Position = UDim2.new(0, 10, 0, yOffset)
        slotFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
        slotFrame.BorderSizePixel = 0
        slotFrame.Parent = pageFrame
        CreateUICorner(slotFrame, 6)
        
        CreateLabel(slotFrame, "Pet " .. i .. ":", UDim2.new(0, 10, 0, 10), UDim2.new(0, 60, 1, 0))
        
        local favOptions = {"(none)"}
        for _, pet in pairs(State.FavoritePets) do
            table.insert(favOptions, pet.Name)
        end
        
        local currentSelection = "(none)"
        if Config.Leveling.Phase1.Team[i] then
            currentSelection = Config.Leveling.Phase1.Team[i].Name
        end
        
        CreateDropdown(slotFrame, "", UDim2.new(0, 80, 0, 0), favOptions, currentSelection,
            function(selected)
                if selected == "(none)" then
                    Config.Leveling.Phase1.Team[i] = nil
                else
                    for _, pet in pairs(State.FavoritePets) do
                        if pet.Name == selected then
                            Config.Leveling.Phase1.Team[i] = pet
                            break
                        end
                    end
                end
            end)
        
        yOffset = yOffset + 58
    end
    
    yOffset = yOffset + 20
    
    -- Phase 2 Team
    CreateLabel(pageFrame, "PHASE 2 (Level 50 → 500)", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).Font = Enum.Font.GothamSemibold
    CreateLabel(pageFrame, "PHASE 2 (Level 50 → 500)", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).TextSize = 15
    yOffset = yOffset + 35
    
    for i = 1, 3 do
        local slotFrame = Instance.new("Frame")
        slotFrame.Size = UDim2.new(1, -20, 0, 50)
        slotFrame.Position = UDim2.new(0, 10, 0, yOffset)
        slotFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
        slotFrame.BorderSizePixel = 0
        slotFrame.Parent = pageFrame
        CreateUICorner(slotFrame, 6)
        
        CreateLabel(slotFrame, "Pet " .. i .. ":", UDim2.new(0, 10, 0, 10), UDim2.new(0, 60, 1, 0))
        
        local favOptions = {"(none)"}
        for _, pet in pairs(State.FavoritePets) do
            table.insert(favOptions, pet.Name)
        end
        
        local currentSelection = "(none)"
        if Config.Leveling.Phase2.Team[i] then
            currentSelection = Config.Leveling.Phase2.Team[i].Name
        end
        
        CreateDropdown(slotFrame, "", UDim2.new(0, 80, 0, 0), favOptions, currentSelection,
            function(selected)
                if selected == "(none)" then
                    Config.Leveling.Phase2.Team[i] = nil
                else
                    for _, pet in pairs(State.FavoritePets) do
                        if pet.Name == selected then
                            Config.Leveling.Phase2.Team[i] = pet
                            break
                        end
                    end
                end
            end)
        
        yOffset = yOffset + 58
    end
    
    -- Team summary
    local summaryFrame = Instance.new("Frame")
    summaryFrame.Size = UDim2.new(1, -20, 0, 100)
    summaryFrame.Position = UDim2.new(0, 10, 0, yOffset + 20)
    summaryFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    summaryFrame.BorderSizePixel = 0
    summaryFrame.Parent = pageFrame
    CreateUICorner(summaryFrame, 8)
    
    local phase1Count = 0
    local phase2Count = 0
    for _, pet in pairs(Config.Leveling.Phase1.Team) do
        if pet then phase1Count = phase1Count + 1 end
    end
    for _, pet in pairs(Config.Leveling.Phase2.Team) do
        if pet then phase2Count = phase2Count + 1 end
    end
    
    CreateLabel(summaryFrame, "Teams Summary:", UDim2.new(0, 10, 0, 10), UDim2.new(0, 150, 0, 30)).Font = Enum.Font.GothamSemibold
    CreateLabel(summaryFrame, string.format("Phase 1 team: %d pets", phase1Count), UDim2.new(0, 10, 0, 35), UDim2.new(0, 200, 0, 30))
    CreateLabel(summaryFrame, string.format("Phase 2 team: %d pets", phase2Count), UDim2.new(0, 10, 0, 55), UDim2.new(0, 200, 0, 30))
    CreateLabel(summaryFrame, string.format("Total team slots: %d", phase1Count + phase2Count), UDim2.new(0, 10, 0, 75), UDim2.new(0, 200, 0, 30))
end
-- ========================================
-- GROWTH PAGE (MAIN)
-- ========================================
local function PopulateGrowthPage(pageFrame)
    local yOffset = 10
    
    -- Target Base KG
    CreateInputBox(pageFrame, "Target Base KG:", UDim2.new(0, 10, 0, yOffset), Config.Growth.TargetBaseKG,
        function(value) Config.Growth.TargetBaseKG = value end)
    yOffset = yOffset + 48
    
    -- Elephant Mode
    CreateDropdown(pageFrame, "Elephant Mode:", UDim2.new(0, 10, 0, yOffset), {"Mode B", "Mode C"}, 
        "Mode " .. Config.Growth.ElephantMode, function(value) Config.Growth.ElephantMode = value:sub(-1) end)
    yOffset = yOffset + 48
    
    yOffset = yOffset + 20
    
    -- Enable toggles
    CreateToggle(pageFrame, "Enable Auto Elephant", UDim2.new(0, 10, 0, yOffset), Config.Growth.EnableAutoElephant, 
        function(value) Config.Growth.EnableAutoElephant = value end)
    yOffset = yOffset + 48
    
    CreateToggle(pageFrame, "Enable Auto Leveling", UDim2.new(0, 10, 0, yOffset), Config.Growth.EnableAutoLeveling,
        function(value) Config.Growth.EnableAutoLeveling = value end)
    yOffset = yOffset + 48
    
    CreateToggle(pageFrame, "Enable Auto Mutation", UDim2.new(0, 10, 0, yOffset), Config.Growth.EnableAutoMutation,
        function(value) Config.Growth.EnableAutoMutation = value end)
    yOffset = yOffset + 48
    
    yOffset = yOffset + 20
    
    -- Status display
    local statusFrame = Instance.new("Frame")
    statusFrame.Size = UDim2.new(1, -20, 0, 120)
    statusFrame.Position = UDim2.new(0, 10, 0, yOffset)
    statusFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    statusFrame.BorderSizePixel = 0
    statusFrame.Parent = pageFrame
    CreateUICorner(statusFrame, 8)
    
    CreateLabel(statusFrame, "Status:", UDim2.new(0, 10, 0, 10), UDim2.new(0, 80, 0, 30)).Font = Enum.Font.GothamSemibold
    
    State.UIElements.GrowthStatus = CreateLabel(statusFrame, State.StatusMessage, 
        UDim2.new(0, 10, 0, 35), UDim2.new(1, -20, 0, 80))
    State.UIElements.GrowthStatus.TextWrapped = true
    State.UIElements.GrowthStatus.TextYAlignment = Enum.TextYAlignment.Top
    State.UIElements.GrowthStatus.Font = Enum.Font.Code
    State.UIElements.GrowthStatus.TextSize = 12
    
    yOffset = yOffset + 130
    
    -- Control buttons
    local startBtn = CreateButton(pageFrame, "▶ START", UDim2.new(0, 10, 0, yOffset), UDim2.new(0, 200, 0, 50), 
        Color3.fromRGB(60, 180, 90), function()
            if Config.UI.IsRunning then
                Config.UI.IsRunning = false
                UpdateStatus("Automation stopped by user", "idle")
                startBtn.Text = "▶ START"
                startBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 90)
            else
                task.spawn(RunMainAutomation)
                startBtn.Text = "⏹ STOP"
                startBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
            end
        end)
    
    CreateButton(pageFrame, "🔄 Refresh Pets", UDim2.new(0, 220, 0, yOffset), UDim2.new(0, 150, 0, 50), 
        Color3.fromRGB(60, 140, 220), function()
            GetAllPets()
            UpdateStatus("Pet list refreshed", "success")
        end)
end

-- ========================================
-- CONFIG PAGE
-- ========================================
local function PopulateConfigPage(pageFrame)
    local yOffset = 10
    
    CreateLabel(pageFrame, "═══ General Configuration ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).TextSize = 16
    CreateLabel(pageFrame, "═══ General Configuration ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).Font = Enum.Font.GothamBold
    yOffset = yOffset + 40
    
    CreateToggle(pageFrame, "Batch Mode", UDim2.new(0, 10, 0, yOffset), Config.General.BatchMode,
        function(value) Config.General.BatchMode = value end)
    yOffset = yOffset + 48
    
    CreateInputBox(pageFrame, "Global Wave Size Override", UDim2.new(0, 10, 0, yOffset), Config.General.GlobalWaveSize,
        function(value) Config.General.GlobalWaveSize = value end)
    yOffset = yOffset + 48
    
    CreateInputBox(pageFrame, "Leveling Wave Size", UDim2.new(0, 10, 0, yOffset), Config.Leveling.WaveSize,
        function(value) Config.Leveling.WaveSize = value end)
    yOffset = yOffset + 48
    
    CreateInputBox(pageFrame, "Elephant Level Before Reset", UDim2.new(0, 10, 0, yOffset), Config.Elephant.LevelBefore,
        function(value) Config.Elephant.LevelBefore = value end)
    yOffset = yOffset + 48
    
    -- Script Info
    CreateLabel(pageFrame, "═══ Script Information ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).TextSize = 16
    CreateLabel(pageFrame, "═══ Script Information ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).Font = Enum.Font.GothamBold
    yOffset = yOffset + 40
    
    local infoFrame = Instance.new("Frame")
    infoFrame.Size = UDim2.new(1, -20, 0, 200)
    infoFrame.Position = UDim2.new(0, 10, 0, yOffset)
    infoFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    infoFrame.BorderSizePixel = 0
    infoFrame.Parent = pageFrame
    CreateUICorner(infoFrame, 8)
    
    local infoText = Instance.new("TextLabel")
    infoText.Size = UDim2.new(1, -20, 1, -20)
    infoText.Position = UDim2.new(0, 10, 0, 10)
    infoText.BackgroundTransparency = 1
    infoText.Text = string.format([[
%s BamHub v%s - Multi-Page System

Features:
• 5-Page Navigation System
• Target Pets Selection Page
• Separate Team Configuration Pages
• Elephant Mode C (Two-Stage)
• Advanced Pet Detection
• Checkbox Target Selection

Status: Ready
Pages: Growth | Elephant | Leveling | Target Pets | Config
Pets Loaded: %d
Favorite Pets: %d
Selected Targets: %d
    ]], Config.Logo, Config.Version, #State.AllPets, #State.FavoritePets, 
    (function() local count = 0; for _ in pairs(Config.TargetPets.Selected) do count = count + 1 end; return count end)())
    infoText.TextColor3 = Color3.fromRGB(200, 200, 200)
    infoText.Font = Enum.Font.Code
    infoText.TextSize = 12
    infoText.TextWrapped = true
    infoText.TextXAlignment = Enum.TextXAlignment.Left
    infoText.TextYAlignment = Enum.TextYAlignment.Top
    infoText.Parent = infoFrame
end

-- ========================================
-- MAIN AUTOMATION LOGIC
-- ========================================
local function RunMainAutomation()
    if Config.UI.IsRunning then
        UpdateStatus("Already running!", "error")
        return
    end
    
    Config.UI.IsRunning = true
    UpdateStatus("Starting automation...", "running")
    
    GetAllPets()
    
    local selectedTargets = GetSelectedTargets()
    if #selectedTargets == 0 then
        UpdateStatus("No target pets selected! Go to Target Pets page.", "error")
        Config.UI.IsRunning = false
        return
    end
    
    UpdateStatus(string.format("Found %d target pets to process", #selectedTargets), "info")
    
    -- Run enabled automations
    if Config.Growth.EnableAutoElephant then
        RunElephantMode()
    end
    
    if Config.Growth.EnableAutoLeveling then
        RunLevelingMode()
    end
    
    Config.UI.IsRunning = false
    UpdateStatus("Automation completed!", "success")
end
-- ========================================
-- STATUS BAR
-- ========================================
local function CreateStatusBar(parent)
    local StatusBar = Instance.new("Frame")
    StatusBar.Size = UDim2.new(1, 0, 0, 80)
    StatusBar.Position = UDim2.new(0, 0, 1, -80)
    StatusBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    StatusBar.BorderSizePixel = 0
    StatusBar.Parent = parent
    CreateUICorner(StatusBar, 12)
    
    local StatusCover = Instance.new("Frame")
    StatusCover.Size = UDim2.new(1, 0, 0, 12)
    StatusCover.Position = UDim2.new(0, 0, 0, 0)
    StatusCover.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    StatusCover.BorderSizePixel = 0
    StatusCover.Parent = StatusBar
    
    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Size = UDim2.new(1, -20, 1, -20)
    StatusLabel.Position = UDim2.new(0, 10, 0, 10)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = State.StatusMessage
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLabel.Font = Enum.Font.Code
    StatusLabel.TextSize = 11
    StatusLabel.TextWrapped = true
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.TextYAlignment = Enum.TextYAlignment.Top
    StatusLabel.Parent = StatusBar
    
    State.UIElements.StatusLabel = StatusLabel
    
    -- Status update loop
    task.spawn(function()
        while task.wait(0.2) do
            if StatusLabel and StatusLabel.Parent then
                local selectedCount = 0
                for _, selected in pairs(Config.TargetPets.Selected) do
                    if selected then selectedCount = selectedCount + 1 end
                end
                
                local displayText = string.format(
                    "Page: %s | Selected Targets: %d/%d | Teams: E:%d L1:%d L2:%d\n%s",
                    Config.UI.CurrentPage,
                    selectedCount, #State.NonFavoritePets,
                    (function() local c = 0; for _, p in pairs(Config.Elephant.Team) do if p then c = c + 1 end end; return c end)(),
                    (function() local c = 0; for _, p in pairs(Config.Leveling.Phase1.Team) do if p then c = c + 1 end end; return c end)(),
                    (function() local c = 0; for _, p in pairs(Config.Leveling.Phase2.Team) do if p then c = c + 1 end end; return c end)(),
                    State.StatusMessage
                )
                
                StatusLabel.Text = displayText
                
                -- Update growth status if on growth page
                if State.UIElements.GrowthStatus then
                    State.UIElements.GrowthStatus.Text = displayText
                end
            else
                break
            end
        end
    end)
    
    return StatusBar
end

-- ========================================
-- INITIALIZATION
-- ========================================
local function Initialize()
    UpdateStatus("Initializing BamHub v2.0...", "info")
    
    Wait(1)
    
    local mainFrame = CreateMainUI()
    if not mainFrame then
        warn("Failed to create UI")
        return
    end
    
    local pageButtons, pageFrames = CreatePageNavigation(mainFrame)
    CreateStatusBar(mainFrame)
    
    -- Initialize empty selections
    Config.TargetPets.Selected = {}
    
    -- Populate pages
    GetAllPets()
    
    PopulateGrowthPage(pageFrames["Growth"])
    PopulateElephantPage(pageFrames["Elephant"]) 
    PopulateLevelingPage(pageFrames["Leveling"])
    PopulateTargetPetsPage(pageFrames["Target Pets"])
    PopulateConfigPage(pageFrames["Config"])
    
    UpdateStatus("BamHub v2.0 initialized! Navigate between pages and configure settings.", "success")
end

-- Start initialization
task.spawn(function()
    local success, err = pcall(Initialize)
    if not success then
        warn("BamHub v2.0 initialization error:", err)
    end
end)

-- Global exports
_G.BamHubV2Config = Config
_G.BamHubV2State = State
_G.BamHubV2Reload = Initialize

return {
    Config = Config,
    State = State,
    Initialize = Initialize,
    RunMainAutomation = RunMainAutomation,
    GetAllPets = GetAllPets,
    Version = "2.0"
}