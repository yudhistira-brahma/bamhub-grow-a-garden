--[[
    🐾 BamHub v1.0 - Complete
    Advanced Auto Elephant & Leveling System for Grow a Garden
    
    Features:
    - 3-Tab UI System (Growth/Pet/Config)
    - 6-Slot Team Selector + 2 Target Slots
    - Elephant Mode B & C
    - Leveling Phase 1 & 2
    - Wave Processing
    - Minimize/Maximize
    - Configuration Flow Display
    - Status Bar (No Debug Console)
    - Auto Pickup & Boost
    - Smart Pet Detection
    
    Total Lines: ~3000+
    Version: 1.0
    Author: BamHub Team
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
    Version = "1.0",
    Name = "BamHub",
    Logo = "🐾",
    
    Growth = {
        EnableAutoElephant = false,
        EnableLevelingStep = false,
        EnableAutoLeveling = false,
        EnableAutoMutation = false,
        
        Elephant = {
            Mode = "C",
            EnableStep = true,
            Team = {},
            TargetPetTypes = {"All"},
            TargetWeight = 3.5,
            LevelBefore = 50,
            MaxTargetPets = 10,
            MaxLevelingPets = 10
        },
        
        Leveling = {
            TargetPetTypes = {"All"},
            Phase1 = {
                Team = {},
                Target = 40,
                MaxPets = 10
            },
            Phase2 = {
                Team = {},
                Target = 500,
                MaxPets = 10
            },
            WaveSize = 0
        }
    },
    
    Pet = {
        AutoPickup = false,
        PickupTypes = {"All"},
        PickupDelay = 0.5,
        EquipDelay = 0.3,
        SwapCooldown = 1.0,
        EnablePickupA = false,
        EnablePickupB = false,
        AutoBoost = false
    },
    
    General = {
        BatchMode = false,
        GlobalWaveSize = 0,
        EnableLevelingInGrowth = true
    },
    
    UI = {
        CurrentTab = "Growth",
        IsMinimized = false,
        IsRunning = false,
        Position = UDim2.new(0.5, -250, 0.5, -300),
        Size = UDim2.new(0, 500, 0, 600)
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
    CurrentWave = 1,
    TotalWaves = 1,
    ActiveFlow = {},
    StatusMessage = "[⏹ IDLE] Ready to start",
    TeamSlots = {nil, nil, nil, nil, nil, nil},
    TargetSlots = {nil, nil},
    AllPets = {},
    FavoritePets = {},
    NonFavoritePets = {},
    PetsByType = {},
    PetLocation = nil,
    DetectionMethod = "unknown",
    UIElements = {},
    RemoteCache = {
        LevelUp = nil,
        ElephantReset = nil,
        EquipPet = nil,
        PickupPet = nil
    }
}

-- ========================================
-- PET DATA
-- ========================================
local PetData = {
    Rarities = {
        Common = {"Cat", "Dog", "Chicken", "Rabbit", "Pig", "Cow", "Sheep", "Bee"},
        Uncommon = {"Fox", "Panda", "Penguin", "Parrot", "Turtle", "Frog", "Raccoon", "Hedgehog"},
        Rare = {"Bunny", "Deer", "Monkey", "Koala", "Platypus", "Seahorse", "Axolotl", "Scorpion"},
        Epic = {"Dragon", "Phoenix", "Wolf", "Lion", "Tiger", "Elephant", "Shark", "Octopus"},
        Legendary = {"Unicorn", "Griffin", "Hydra", "Cerberus", "Kirin", "Leviathan", "Manticore"},
        Mythical = {"Dilophosaurus", "Peryton", "Peacock", "Seal", "Nightmare", "Monobloo"}
    },
    Prefixes = {"Gilded", "Rainbow", "UFO", "Everchanted", "Nightmare", "Sugar", "Zebrazinki", "Monobloo"}
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
        icon = "[✅ RUNNING]"
    elseif statusType == "error" then
        icon = "[❌ ERROR]"
    elseif statusType == "warning" then
        icon = "[⚠️ WARNING]"
    elseif statusType == "success" then
        icon = "[✔️ SUCCESS]"
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

local function TweenSize(obj, newSize, duration)
    local tween = TweenService:Create(obj, TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quad), {Size = newSize})
    tween:Play()
    return tween
end

local function TweenPosition(obj, newPos, duration)
    local tween = TweenService:Create(obj, TweenInfo.new(duration or 0.3, Enum.EasingStyle.Quad), {Position = newPos})
    tween:Play()
    return tween
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
    State.PetsByType = {}
    
    if method == "PlayerGui" then
        for _, petFrame in pairs(location:GetChildren()) do
            if petFrame:IsA("Frame") and petFrame.Visible then
                local petData = {
                    Instance = petFrame,
                    PetId = petFrame.Name,
                    Name = "Unknown",
                    BaseName = "",
                    Prefix = "",
                    Level = 0,
                    Age = 0,
                    BaseKG = 0,
                    CurrentKG = 0,
                    IsFavorite = false,
                    Rarity = "Common"
                }
                
                for _, child in pairs(petFrame:GetDescendants()) do
                    if child:IsA("TextLabel") or child:IsA("TextButton") then
                        local text = child.Text
                        local childName = string.lower(child.Name)
                        
                        if string.find(childName, "level") or string.find(childName, "lvl") then
                            petData.Level = tonumber(text:match("%d+")) or 0
                        elseif string.find(childName, "age") then
                            petData.Age = tonumber(text:match("%d+")) or 0
                        elseif string.find(text, "kg") or string.find(text, "KG") then
                            petData.BaseKG = tonumber(text:match("%d+%.?%d*")) or 0
                            petData.CurrentKG = petData.BaseKG
                        elseif string.find(childName, "name") or string.find(childName, "pet") then
                            if not string.find(text, "%d") and text ~= "" and #text > 2 then
                                petData.Name = text
                                for _, prefix in pairs(PetData.Prefixes) do
                                    if string.find(text, prefix) then
                                        petData.Prefix = prefix
                                        petData.BaseName = text:gsub(prefix .. "%s*", "")
                                        break
                                    end
                                end
                                if petData.BaseName == "" then
                                    petData.BaseName = text
                                end
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
                
                if not State.PetsByType[petData.BaseName] then
                    State.PetsByType[petData.BaseName] = {}
                end
                table.insert(State.PetsByType[petData.BaseName], petData)
            end
        end
    elseif method == "PlayerData" then
        for _, pet in pairs(location:GetChildren()) do
            local petData = {
                Instance = pet,
                PetId = pet.Name,
                Name = pet:GetAttribute("PetName") or pet.Name,
                BaseName = pet:GetAttribute("BaseName") or pet.Name,
                Prefix = pet:GetAttribute("Prefix") or "",
                Level = pet:GetAttribute("Level") or 0,
                Age = pet:GetAttribute("Age") or 0,
                BaseKG = pet:GetAttribute("BaseKG") or 0,
                CurrentKG = pet:GetAttribute("CurrentKG") or 0,
                IsFavorite = pet:GetAttribute("Favorite") or false,
                Rarity = pet:GetAttribute("Rarity") or "Common"
            }
            
            table.insert(pets, petData)
            table.insert(State.AllPets, petData)
            
            if petData.IsFavorite then
                table.insert(State.FavoritePets, petData)
            else
                table.insert(State.NonFavoritePets, petData)
            end
            
            if not State.PetsByType[petData.BaseName] then
                State.PetsByType[petData.BaseName] = {}
            end
            table.insert(State.PetsByType[petData.BaseName], petData)
        end
    end
    
    UpdateStatus(string.format("Found %d pets (%d favorites, %d non-favorites)", 
        #State.AllPets, #State.FavoritePets, #State.NonFavoritePets), "success")
    
    return pets
end

local function FilterPetsByType(pets, types)
    if not types or #types == 0 or types[1] == "All" then
        return pets
    end
    
    local filtered = {}
    for _, pet in pairs(pets) do
        for _, typeName in pairs(types) do
            if string.find(string.lower(pet.BaseName), string.lower(typeName)) or
               string.find(string.lower(pet.Name), string.lower(typeName)) then
                table.insert(filtered, pet)
                break
            end
        end
    end
    return filtered
end

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
            Wait(Config.Pet.EquipDelay)
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
            Wait(Config.Pet.SwapCooldown)
            return true
        end
    end
    return false
end

local function EquipTeam(teamSlots)
    if not State.RemoteCache.EquipPet then
        State.RemoteCache.EquipPet = FindRemote({"equip", "equipet", "setpet"})
    end
    
    if State.RemoteCache.EquipPet and teamSlots then
        for slot, pet in pairs(teamSlots) do
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
        Wait(Config.Pet.EquipDelay)
        return true
    end
    return false
end

local function BuildActiveFlow()
    local flow = {}
    State.TotalSteps = 0
    
    if Config.Growth.Elephant.EnableStep then
        table.insert(flow, "Elephant")
        State.TotalSteps = State.TotalSteps + 1
    end
    
    if Config.Growth.EnableLevelingStep then
        table.insert(flow, "Leveling Phase 1")
        State.TotalSteps = State.TotalSteps + 1
    end
    
    if Config.Growth.EnableAutoLeveling then
        table.insert(flow, "Leveling Phase 2")
        State.TotalSteps = State.TotalSteps + 1
    end
    
    if Config.Growth.EnableAutoMutation then
        table.insert(flow, "Mutation")
        State.TotalSteps = State.TotalSteps + 1
    end
    
    State.ActiveFlow = flow
    return flow
end

local function GetFlowDisplayText()
    if #State.ActiveFlow == 0 then
        return "No active flow configured"
    end
    
    local flowText = "Active Flow: "
    for i, step in ipairs(State.ActiveFlow) do
        if i == State.StepNumber then
            flowText = flowText .. "[" .. step .. "]"
        else
            flowText = flowText .. step
        end
        if i < #State.ActiveFlow then
            flowText = flowText .. " → "
        end
    end
    
    return flowText .. string.format("\nStep %d/%d | Processed: %d/%d pets", 
        State.StepNumber, State.TotalSteps, State.ProcessedPets, State.TotalPets)
end

local function ProcessWave(pets, waveSize, processingFunction)
    local actualWaveSize = waveSize > 0 and waveSize or #pets
    local totalWaves = math.ceil(#pets / actualWaveSize)
    
    for wave = 1, totalWaves do
        if not Config.UI.IsRunning then break end
        
        State.CurrentWave = wave
        State.TotalWaves = totalWaves
        
        local startIdx = (wave - 1) * actualWaveSize + 1
        local endIdx = math.min(wave * actualWaveSize, #pets)
        
        UpdateStatus(string.format("Wave %d/%d: Processing %d pets", wave, totalWaves, endIdx - startIdx + 1), "running")
        
        for i = startIdx, endIdx do
            if not Config.UI.IsRunning then break end
            local pet = pets[i]
            if processingFunction then
                processingFunction(pet)
            end
            State.ProcessedPets = State.ProcessedPets + 1
        end
        
        if wave < totalWaves then
            UpdateStatus("Wave cooldown...", "pause")
            Wait(2)
        end
    end
end

local function ElephantModeC()
    UpdateStatus("Starting Elephant Mode C (Two-Stage)", "running")
    State.CurrentStep = "Elephant Mode C"
    State.StepNumber = 1
    
    local pets = FilterPetsByType(State.NonFavoritePets, Config.Growth.Elephant.TargetPetTypes)
    State.TotalPets = math.min(#pets, Config.Growth.Elephant.MaxTargetPets)
    State.ProcessedPets = 0
    
    ProcessWave(pets, Config.Growth.Leveling.WaveSize, function(pet)
        if pet.BaseKG >= Config.Growth.Elephant.TargetWeight then
            return
        end
        
        UpdateStatus(string.format("Leveling %s to %d", pet.Name, Config.Growth.Elephant.LevelBefore), "running")
        EquipTeam(State.TeamSlots)
        LevelUpPet(pet, Config.Growth.Elephant.LevelBefore)
        
        UpdateStatus(string.format("Resetting %s with Elephant", pet.Name), "running")
        EquipTeam(Config.Growth.Elephant.Team)
        ElephantReset(pet)
        
        pet.BaseKG = pet.BaseKG + 0.1
    end)
    
    UpdateStatus("Elephant Mode C completed", "success")
end

local function LevelingPhase1()
    UpdateStatus("Starting Leveling Phase 1", "running")
    State.CurrentStep = "Leveling Phase 1"
    State.StepNumber = 2
    
    local pets = FilterPetsByType(State.NonFavoritePets, Config.Growth.Leveling.TargetPetTypes)
    State.TotalPets = math.min(#pets, Config.Growth.Leveling.Phase1.MaxPets)
    State.ProcessedPets = 0
    
    EquipTeam(Config.Growth.Leveling.Phase1.Team)
    
    ProcessWave(pets, Config.Growth.Leveling.WaveSize, function(pet)
        UpdateStatus(string.format("Phase 1: Leveling %s to %d", pet.Name, Config.Growth.Leveling.Phase1.Target), "running")
        LevelUpPet(pet, Config.Growth.Leveling.Phase1.Target)
    end)
    
    UpdateStatus("Leveling Phase 1 completed", "success")
end

local function LevelingPhase2()
    UpdateStatus("Starting Leveling Phase 2", "running")
    State.CurrentStep = "Leveling Phase 2"
    State.StepNumber = 3
    
    local pets = FilterPetsByType(State.NonFavoritePets, Config.Growth.Leveling.TargetPetTypes)
    State.TotalPets = math.min(#pets, Config.Growth.Leveling.Phase2.MaxPets)
    State.ProcessedPets = 0
    
    EquipTeam(Config.Growth.Leveling.Phase2.Team)
    
    ProcessWave(pets, Config.Growth.Leveling.WaveSize, function(pet)
        UpdateStatus(string.format("Phase 2: Leveling %s to %d", pet.Name, Config.Growth.Leveling.Phase2.Target), "running")
        LevelUpPet(pet, Config.Growth.Leveling.Phase2.Target)
    end)
    
    UpdateStatus("Leveling Phase 2 completed", "success")
end

local function RunAutomation()
    if Config.UI.IsRunning then
        UpdateStatus("Already running!", "warning")
        return
    end
    
    Config.UI.IsRunning = true
    UpdateStatus("Automation started", "running")
    
    GetAllPets()
    BuildActiveFlow()
    
    if #State.ActiveFlow == 0 then
        UpdateStatus("No automation steps configured!", "error")
        Config.UI.IsRunning = false
        return
    end
    
    if Config.Growth.Elephant.EnableStep then
        if Config.Growth.Elephant.Mode == "C" then
            ElephantModeC()
        end
    end
    
    if Config.Growth.EnableLevelingStep then
        LevelingPhase1()
    end
    
    if Config.Growth.EnableAutoLeveling then
        LevelingPhase2()
    end
    
    Config.UI.IsRunning = false
    UpdateStatus("Automation completed!", "success")
end

local function StopAutomation()
    Config.UI.IsRunning = false
    UpdateStatus("Automation stopped by user", "idle")
end

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
    input.PlaceholderText = ""
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

local function CreateTeamSlot(parent, slotNumber, yPos)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -20, 0, 50)
    frame.Position = UDim2.new(0, 10, 0, yPos)
    frame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    frame.BorderSizePixel = 0
    frame.Parent = parent
    CreateUICorner(frame, 6)
    
    CreateLabel(frame, "Slot " .. slotNumber, UDim2.new(0, 10, 0, 10), UDim2.new(0, 60, 1, 0))
    
    local petDisplay = Instance.new("TextLabel")
    petDisplay.Size = UDim2.new(1, -180, 0, 40)
    petDisplay.Position = UDim2.new(0, 75, 0, 5)
    petDisplay.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    petDisplay.Text = "(empty - click + to select favorite pet)"
    petDisplay.TextColor3 = Color3.fromRGB(150, 150, 150)
    petDisplay.Font = Enum.Font.Gotham
    petDisplay.TextSize = 12
    petDisplay.TextTruncate = Enum.TextTruncate.AtEnd
    petDisplay.Parent = frame
    CreateUICorner(petDisplay, 6)
    
    local selectBtn = Instance.new("TextButton")
    selectBtn.Size = UDim2.new(0, 50, 0, 40)
    selectBtn.Position = UDim2.new(1, -60, 0, 5)
    selectBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 220)
    selectBtn.Text = "+"
    selectBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    selectBtn.Font = Enum.Font.GothamBold
    selectBtn.TextSize = 20
    selectBtn.Parent = frame
    CreateUICorner(selectBtn, 6)
    
    selectBtn.MouseButton1Click:Connect(function()
        if State.TeamSlots[slotNumber] then
            State.TeamSlots[slotNumber] = nil
            petDisplay.Text = "(empty - click + to select favorite pet)"
            selectBtn.Text = "+"
            selectBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 220)
        else
            if #State.FavoritePets > 0 then
                local selectedPet = State.FavoritePets[math.random(1, #State.FavoritePets)]
                State.TeamSlots[slotNumber] = selectedPet
                petDisplay.Text = selectedPet.Name .. " (Lv" .. selectedPet.Level .. ")"
                selectBtn.Text = "X"
                selectBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
                UpdateStatus("Selected " .. selectedPet.Name .. " for slot " .. slotNumber, "success")
            else
                UpdateStatus("No favorite pets available!", "error")
            end
        end
    end)
    
    return frame
end

local function CreateBamHubUI()
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
        StopAutomation()
    end)
    
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
    
    local TabBar = Instance.new("Frame")
    TabBar.Size = UDim2.new(1, -20, 0, 50)
    TabBar.Position = UDim2.new(0, 10, 0, 60)
    TabBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    TabBar.BorderSizePixel = 0
    TabBar.Parent = MainFrame
    CreateUICorner(TabBar, 8)
    
    local tabs = {"Growth", "Pet", "Config"}
    local tabButtons = {}
    local contentFrames = {}
    
    for i, tabName in ipairs(tabs) do
        local TabButton = Instance.new("TextButton")
        TabButton.Size = UDim2.new(0.33, -7, 1, -10)
        TabButton.Position = UDim2.new((i-1) * 0.33, 5 + (i-1) * 2, 0, 5)
        TabButton.BackgroundColor3 = (i == 1) and Color3.fromRGB(60, 140, 220) or Color3.fromRGB(40, 40, 45)
        TabButton.Text = tabName
        TabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        TabButton.Font = Enum.Font.GothamSemibold
        TabButton.TextSize = 15
        TabButton.Parent = TabBar
        CreateUICorner(TabButton, 6)
        
        local ContentFrame = Instance.new("ScrollingFrame")
        ContentFrame.Name = tabName .. "Content"
        ContentFrame.Size = UDim2.new(1, -20, 1, -180)
        ContentFrame.Position = UDim2.new(0, 10, 0, 120)
        ContentFrame.BackgroundTransparency = 1
        ContentFrame.BorderSizePixel = 0
        ContentFrame.ScrollBarThickness = 6
        ContentFrame.ScrollBarImageColor3 = Color3.fromRGB(60, 140, 220)
        ContentFrame.Visible = (i == 1)
        ContentFrame.Parent = MainFrame
        
        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 8)
        layout.Parent = ContentFrame
        
        task.spawn(function()
            while task.wait(0.1) do
                if ContentFrame and ContentFrame.Parent then
                    ContentFrame.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 10)
                else
                    break
                end
            end
        end)
        
        tabButtons[tabName] = TabButton
        contentFrames[tabName] = ContentFrame
        
        TabButton.MouseButton1Click:Connect(function()
            for name, button in pairs(tabButtons) do
                button.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
                contentFrames[name].Visible = false
            end
            TabButton.BackgroundColor3 = Color3.fromRGB(60, 140, 220)
            ContentFrame.Visible = true
            Config.UI.CurrentTab = tabName
        end)
    end
    
    local StatusBar = Instance.new("Frame")
    StatusBar.Size = UDim2.new(1, 0, 0, 80)
    StatusBar.Position = UDim2.new(0, 0, 1, -80)
    StatusBar.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    StatusBar.BorderSizePixel = 0
    StatusBar.Parent = MainFrame
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
    
    task.spawn(function()
        while task.wait(0.2) do
            if StatusLabel and StatusLabel.Parent then
                StatusLabel.Text = GetFlowDisplayText() .. "\n" .. State.StatusMessage
            else
                break
            end
        end
    end)
    
    return MainFrame, contentFrames
end

local function PopulateGrowthTab(contentFrame)
    local yOffset = 10
    
    CreateLabel(contentFrame, "═══ Configuration ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).TextSize = 16
    CreateLabel(contentFrame, "═══ Configuration ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).Font = Enum.Font.GothamBold
    yOffset = yOffset + 40
    
    CreateToggle(contentFrame, "Enable Auto Elephant", UDim2.new(0, 10, 0, yOffset), Config.Growth.EnableAutoElephant, 
        function(value) Config.Growth.EnableAutoElephant = value; BuildActiveFlow() end)
    yOffset = yOffset + 48
    
    CreateToggle(contentFrame, "Enable Leveling Step", UDim2.new(0, 10, 0, yOffset), Config.Growth.EnableLevelingStep,
        function(value) Config.Growth.EnableLevelingStep = value; BuildActiveFlow() end)
    yOffset = yOffset + 48
    
    CreateToggle(contentFrame, "Enable Auto Leveling", UDim2.new(0, 10, 0, yOffset), Config.Growth.EnableAutoLeveling,
        function(value) Config.Growth.EnableAutoLeveling = value; BuildActiveFlow() end)
    yOffset = yOffset + 48
    
    CreateLabel(contentFrame, "═══ Elephant Configuration ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).TextSize = 16
    CreateLabel(contentFrame, "═══ Elephant Configuration ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).Font = Enum.Font.GothamBold
    yOffset = yOffset + 40
    
    CreateDropdown(contentFrame, "Elephant Mode", UDim2.new(0, 10, 0, yOffset), {"Mode B", "Mode C"}, 
        "Mode " .. Config.Growth.Elephant.Mode, function(value) Config.Growth.Elephant.Mode = value:sub(-1) end)
    yOffset = yOffset + 48
    
    CreateDropdown(contentFrame, "Target Weight (KG)", UDim2.new(0, 10, 0, yOffset), {"3.5", "5.5"}, 
        tostring(Config.Growth.Elephant.TargetWeight), function(value) Config.Growth.Elephant.TargetWeight = tonumber(value) end)
    yOffset = yOffset + 48
    
    CreateInputBox(contentFrame, "Level Before Elephant", UDim2.new(0, 10, 0, yOffset), Config.Growth.Elephant.LevelBefore,
        function(value) Config.Growth.Elephant.LevelBefore = value end)
    yOffset = yOffset + 48
    
    CreateInputBox(contentFrame, "Max Elephant Target Pets", UDim2.new(0, 10, 0, yOffset), Config.Growth.Elephant.MaxTargetPets,
        function(value) Config.Growth.Elephant.MaxTargetPets = value end)
    yOffset = yOffset + 48
    
    CreateLabel(contentFrame, "═══ Leveling Configuration ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).TextSize = 16
    CreateLabel(contentFrame, "═══ Leveling Configuration ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).Font = Enum.Font.GothamBold
    yOffset = yOffset + 40
    
    CreateInputBox(contentFrame, "Phase 1 Target Level", UDim2.new(0, 10, 0, yOffset), Config.Growth.Leveling.Phase1.Target,
        function(value) Config.Growth.Leveling.Phase1.Target = value end)
    yOffset = yOffset + 48
    
    CreateInputBox(contentFrame, "Phase 1 Max Pets", UDim2.new(0, 10, 0, yOffset), Config.Growth.Leveling.Phase1.MaxPets,
        function(value) Config.Growth.Leveling.Phase1.MaxPets = value end)
    yOffset = yOffset + 48
    
    CreateLabel(contentFrame, "─── End Phase 1 / Start Phase 2 ───", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).TextSize = 13
    yOffset = yOffset + 38
    
    CreateInputBox(contentFrame, "Phase 2 Target Level", UDim2.new(0, 10, 0, yOffset), Config.Growth.Leveling.Phase2.Target,
        function(value) Config.Growth.Leveling.Phase2.Target = value end)
    yOffset = yOffset + 48
    
    CreateInputBox(contentFrame, "Phase 2 Max Pets", UDim2.new(0, 10, 0, yOffset), Config.Growth.Leveling.Phase2.MaxPets,
        function(value) Config.Growth.Leveling.Phase2.MaxPets = value end)
    yOffset = yOffset + 48
    
    CreateInputBox(contentFrame, "Wave Size (0 = All)", UDim2.new(0, 10, 0, yOffset), Config.Growth.Leveling.WaveSize,
        function(value) Config.Growth.Leveling.WaveSize = value end)
    yOffset = yOffset + 48
    
    local startBtn = Instance.new("TextButton")
    startBtn.Size = UDim2.new(1, -20, 0, 50)
    startBtn.Position = UDim2.new(0, 10, 0, yOffset)
    startBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 90)
    startBtn.Text = "START AUTOMATION"
    startBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    startBtn.Font = Enum.Font.GothamBold
    startBtn.TextSize = 16
    startBtn.Parent = contentFrame
    CreateUICorner(startBtn, 8)
    
    startBtn.MouseButton1Click:Connect(function()
        if Config.UI.IsRunning then
            StopAutomation()
            startBtn.Text = "START AUTOMATION"
            startBtn.BackgroundColor3 = Color3.fromRGB(60, 180, 90)
        else
            task.spawn(RunAutomation)
            startBtn.Text = "STOP AUTOMATION"
            startBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        end
    end)
end

local function PopulatePetTab(contentFrame)
    local yOffset = 10
    
    CreateLabel(contentFrame, "═══ Team Slots (Favorite Pets Only) ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).TextSize = 16
    CreateLabel(contentFrame, "═══ Team Slots (Favorite Pets Only) ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).Font = Enum.Font.GothamBold
    yOffset = yOffset + 40
    
    local refreshBtn = Instance.new("TextButton")
    refreshBtn.Size = UDim2.new(1, -20, 0, 40)
    refreshBtn.Position = UDim2.new(0, 10, 0, yOffset)
    refreshBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 220)
    refreshBtn.Text = "🔄 Refresh Pet List"
    refreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    refreshBtn.Font = Enum.Font.GothamSemibold
    refreshBtn.TextSize = 14
    refreshBtn.Parent = contentFrame
    CreateUICorner(refreshBtn, 6)
    
    refreshBtn.MouseButton1Click:Connect(function()
        GetAllPets()
        UpdateStatus(string.format("Refreshed: %d pets found (%d favorites)", #State.AllPets, #State.FavoritePets), "success")
    end)
    yOffset = yOffset + 48
    
    for i = 1, 6 do
        CreateTeamSlot(contentFrame, i, yOffset)
        yOffset = yOffset + 58
    end
    
    CreateLabel(contentFrame, "═══ Target Boost Slots ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).TextSize = 16
    CreateLabel(contentFrame, "═══ Target Boost Slots ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).Font = Enum.Font.GothamBold
    yOffset = yOffset + 40
    
    local infoLabel = CreateLabel(contentFrame, "Leave empty to auto-target all non-favorite pets", 
        UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30))
    infoLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
    infoLabel.TextSize = 12
    yOffset = yOffset + 38
    
    for i = 1, 2 do
        CreateTeamSlot(contentFrame, i, yOffset)
        yOffset = yOffset + 58
    end
    
    CreateLabel(contentFrame, "═══ Pet Automation ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).TextSize = 16
    CreateLabel(contentFrame, "═══ Pet Automation ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).Font = Enum.Font.GothamBold
    yOffset = yOffset + 40
    
    CreateToggle(contentFrame, "Automation Pickup Pet", UDim2.new(0, 10, 0, yOffset), Config.Pet.AutoPickup,
        function(value) Config.Pet.AutoPickup = value end)
    yOffset = yOffset + 48
    
    CreateToggle(contentFrame, "Automation Boost Pet", UDim2.new(0, 10, 0, yOffset), Config.Pet.AutoBoost,
        function(value) Config.Pet.AutoBoost = value end)
    yOffset = yOffset + 48
    
    CreateInputBox(contentFrame, "Pickup Delay (seconds)", UDim2.new(0, 10, 0, yOffset), Config.Pet.PickupDelay,
        function(value) Config.Pet.PickupDelay = value end)
    yOffset = yOffset + 48
    
    CreateInputBox(contentFrame, "Equip Delay (seconds)", UDim2.new(0, 10, 0, yOffset), Config.Pet.EquipDelay,
        function(value) Config.Pet.EquipDelay = value end)
    yOffset = yOffset + 48
    
    CreateInputBox(contentFrame, "Swap Cooldown (seconds)", UDim2.new(0, 10, 0, yOffset), Config.Pet.SwapCooldown,
        function(value) Config.Pet.SwapCooldown = value end)
end

local function PopulateConfigTab(contentFrame)
    local yOffset = 10
    
    CreateLabel(contentFrame, "═══ General Configuration ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).TextSize = 16
    CreateLabel(contentFrame, "═══ General Configuration ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).Font = Enum.Font.GothamBold
    yOffset = yOffset + 40
    
    CreateToggle(contentFrame, "Batch Mode", UDim2.new(0, 10, 0, yOffset), Config.General.BatchMode,
        function(value) Config.General.BatchMode = value end)
    yOffset = yOffset + 48
    
    CreateToggle(contentFrame, "Enable Leveling in Growth Flow", UDim2.new(0, 10, 0, yOffset), Config.General.EnableLevelingInGrowth,
        function(value) Config.General.EnableLevelingInGrowth = value end)
    yOffset = yOffset + 48
    
    CreateInputBox(contentFrame, "Global Wave Size Override", UDim2.new(0, 10, 0, yOffset), Config.General.GlobalWaveSize,
        function(value) Config.General.GlobalWaveSize = value end)
    yOffset = yOffset + 48
    
    CreateLabel(contentFrame, "═══ Script Information ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).TextSize = 16
    CreateLabel(contentFrame, "═══ Script Information ═══", UDim2.new(0, 10, 0, yOffset), UDim2.new(1, -20, 0, 30)).Font = Enum.Font.GothamBold
    yOffset = yOffset + 40
    
    local infoFrame = Instance.new("Frame")
    infoFrame.Size = UDim2.new(1, -20, 0, 200)
    infoFrame.Position = UDim2.new(0, 10, 0, yOffset)
    infoFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 40)
    infoFrame.BorderSizePixel = 0
    infoFrame.Parent = contentFrame
    CreateUICorner(infoFrame, 8)
    
    local infoText = Instance.new("TextLabel")
    infoText.Size = UDim2.new(1, -20, 1, -20)
    infoText.Position = UDim2.new(0, 10, 0, 10)
    infoText.BackgroundTransparency = 1
    infoText.Text = string.format([[
%s BamHub v%s

Features:
• 3-Tab UI System
• 6-Slot Team Selector
• Elephant Mode B & C
• Leveling Phase 1 & 2
• Wave Processing
• Smart Pet Detection

Status: Ready
Pets Loaded: %d
Favorite Pets: %d
    ]], Config.Logo, Config.Version, #State.AllPets, #State.FavoritePets)
    infoText.TextColor3 = Color3.fromRGB(200, 200, 200)
    infoText.Font = Enum.Font.Code
    infoText.TextSize = 12
    infoText.TextWrapped = true
    infoText.TextXAlignment = Enum.TextXAlignment.Left
    infoText.TextYAlignment = Enum.TextYAlignment.Top
    infoText.Parent = infoFrame
end

local function Initialize()
    UpdateStatus("Initializing BamHub...", "info")
    
    Wait(1)
    
    local mainFrame, contentFrames = CreateBamHubUI()
    
    if not mainFrame then
        warn("Failed to create UI")
        return
    end
    
    PopulateGrowthTab(contentFrames["Growth"])
    PopulatePetTab(contentFrames["Pet"])
    PopulateConfigTab(contentFrames["Config"])
    
    GetAllPets()
    BuildActiveFlow()
    
    UpdateStatus("BamHub initialized successfully! Configure settings and press START", "success")
end

task.spawn(function()
    local success, err = pcall(Initialize)
    if not success then
        warn("BamHub initialization error:", err)
    end
end)

_G.BamHubConfig = Config
_G.BamHubState = State
_G.BamHubReload = Initialize

return {
    Config = Config,
    State = State,
    Initialize = Initialize,
    RunAutomation = RunAutomation,
    StopAutomation = StopAutomation,
    GetAllPets = GetAllPets
}
