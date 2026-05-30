-- ================================================================
--   ESP Framework Core  [EXECUTOR EDITION]
--   Version : 5.0.0 (No Label, Optimized Highlight, Multi-Path)
-- ================================================================

if _G.ESP_RUNNING then
    if _G.ESP_CLEANUP then _G.ESP_CLEANUP() end
end
_G.ESP_RUNNING = true

-- ════════════════════════════════════════
--  SERVICES
-- ════════════════════════════════════════
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local CoreGui          = game:GetService("CoreGui")
local Camera           = workspace.CurrentCamera
local LocalPlayer      = Players.LocalPlayer

-- ════════════════════════════════════════
--  KONFIGURASI DATA & FOLDER
-- ════════════════════════════════════════
local CONFIG = {
    Categories = {
        Monster = {
            Paths = { 
                {"GameSystem", "Monsters"} 
            },
            FillColor = Color3.fromRGB(255, 50, 50),
            OutlineColor = Color3.fromRGB(255, 50, 50),
            MaxDistance = 1500,
        },
        LootAndInteractive = {
            Paths = { 
                {"GameSystem", "Loots", "World"},
                {"GameSystem", "InteractiveItem"}
            },
            FillColor = Color3.fromRGB(50, 255, 50),
            OutlineColor = Color3.fromRGB(255, 255, 50),
            MaxDistance = 1500,
        },
        NPC = {
            Paths = { 
                {"GameSystem", "NPCModels"} 
            },
            FillColor = Color3.fromRGB(50, 100, 255),
            OutlineColor = Color3.fromRGB(50, 100, 255),
            MaxDistance = 1500,
        }
    }
}

-- ════════════════════════════════════════
--  STATE
-- ════════════════════════════════════════
local espMonsterEnabled          = true
local espLootInteractiveEnabled  = true
local espNPCEnabled              = true
local panelVisible               = true
local connections                = {}
local espRegistry                = {}

-- ════════════════════════════════════════
--  HELPERS
-- ════════════════════════════════════════
local function getGuiParent()
    local ok, result = pcall(function() return CoreGui end)
    return (ok and result) or LocalPlayer:WaitForChild("PlayerGui")
end

local function resolvePath(pathTable)
    local current = workspace
    for _, name in ipairs(pathTable) do
        current = current:FindFirstChild(name)
        if not current then return nil end
    end
    return current
end

local function getMainPart(model)
    if not model then return nil end
    if model:IsA("BasePart") then return model end
    if model.PrimaryPart then return model.PrimaryPart end
    return model:FindFirstChild("HumanoidRootPart") 
        or model:FindFirstChildWhichIsA("BasePart")
end

-- ════════════════════════════════════════
--  ESP MANAGEMENT
-- ════════════════════════════════════════
local function removeESP(model, registryData)
    local data = registryData.Objects[model]
    if data then
        pcall(function()
            if data.Highlight then data.Highlight:Destroy() end
        end)
        registryData.Objects[model] = nil
    end
end

local function createESP(model, config)
    local mainPart = getMainPart(model)
    if not mainPart then return nil end

    local data = {}

    local okHighlight, hl = pcall(function()
        local h = Instance.new("Highlight")
        h.Name                = "ESP_Highlight"
        h.FillColor           = config.FillColor
        h.FillTransparency    = 0.5
        h.OutlineColor        = config.OutlineColor
        h.OutlineTransparency = 0
        h.Adornee             = model
        h.Enabled             = false -- Akan diurus oleh updater
        h.Parent              = CoreGui
        return h
    end)
    if okHighlight then data.Highlight = hl end

    return data
end

local function registerFolderESP(category, paths, config)
    local registryData = {
        Category = category,
        Paths = paths,
        Config = config,
        Objects = {},
        ActiveFolders = {}
    }
    espRegistry[category] = registryData
end

local function scanRegistry()
    for category, registryData in pairs(espRegistry) do
        local validFolders = {}
        for _, path in ipairs(registryData.Paths) do
            local folder = resolvePath(path)
            if folder then validFolders[folder] = true end
        end

        for folder, _ in pairs(registryData.ActiveFolders) do
            if not validFolders[folder] then
                for model in pairs(registryData.Objects) do
                    if model:IsDescendantOf(folder) then
                        removeESP(model, registryData)
                    end
                end
            end
        end
        registryData.ActiveFolders = validFolders

        for model in pairs(registryData.Objects) do
            if not model or not model.Parent then
                removeESP(model, registryData)
            end
        end

        for folder, _ in pairs(validFolders) do
            for _, child in ipairs(folder:GetChildren()) do
                if not registryData.Objects[child] then
                    local data = createESP(child, registryData.Config)
                    if data then registryData.Objects[child] = data end
                end
            end
        end
    end
end

-- Update jarak & batasan 31 Highlight (penyorot) bawaan Roblox
local function updateESPVisibility()
    local camPos = Camera.CFrame.Position
    local activeHighlights = {}

    for category, registryData in pairs(espRegistry) do
        local globalState = false
        if category == "Monster" then globalState = espMonsterEnabled
        elseif category == "LootAndInteractive" then globalState = espLootInteractiveEnabled
        elseif category == "NPC" then globalState = espNPCEnabled
        end

        for model, data in pairs(registryData.Objects) do
            if model and model.Parent then
                local mainPart = getMainPart(model)
                if mainPart and data.Highlight then
                    local dist = (mainPart.Position - camPos).Magnitude
                    if globalState and dist <= registryData.Config.MaxDistance then
                        table.insert(activeHighlights, {Highlight = data.Highlight, Distance = dist})
                    else
                        data.Highlight.Enabled = false
                    end
                end
            else
                if data.Highlight then data.Highlight.Enabled = false end
            end
        end
    end

    -- Urutkan berdasarkan jarak terdekat (mencegah bug highlight menghilang saat dekat)
    table.sort(activeHighlights, function(a, b) return a.Distance < b.Distance end)

    for i, item in ipairs(activeHighlights) do
        item.Highlight.Enabled = (i <= 30) -- Batas maksimal mesin Roblox adalah 31
    end
end

-- ════════════════════════════════════════
--  UI PANEL SETUP
-- ════════════════════════════════════════
local function createButton(name, text, pos, parent, color)
    local btn = Instance.new("TextButton")
    btn.Name             = name
    btn.Size             = UDim2.new(1, -20, 0, 28)
    btn.Position         = pos
    btn.BackgroundColor3 = color
    btn.TextColor3       = Color3.fromRGB(255, 255, 255)
    btn.TextSize         = 12
    btn.Font             = Enum.Font.GothamBold
    btn.Text             = text
    btn.BorderSizePixel  = 0
    btn.AutoButtonColor  = false
    btn.Parent           = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
    return btn
end

local function buildUI()
    pcall(function()
        local old = getGuiParent():FindFirstChild("ESP_UI")
        if old then old:Destroy() end
    end)

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name           = "ESP_UI"
    ScreenGui.ResetOnSpawn   = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent         = getGuiParent()

    local Panel = Instance.new("Frame")
    Panel.Name             = "Panel"
    Panel.Size             = UDim2.new(0, 240, 0, 190)
    Panel.Position         = UDim2.new(0, 20, 0.5, -95)
    Panel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    Panel.BorderSizePixel  = 0
    Panel.Active           = true
    Panel.Parent           = ScreenGui
    Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(120, 120, 140)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.4
    stroke.Parent = Panel

    local TitleBar = Instance.new("Frame")
    TitleBar.Name             = "TitleBar"
    TitleBar.Size             = UDim2.new(1, 0, 0, 32)
    TitleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
    TitleBar.BorderSizePixel  = 0
    TitleBar.Parent           = Panel
    Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

    local tbPatch = Instance.new("Frame")
    tbPatch.Size             = UDim2.new(1, 0, 0, 10)
    tbPatch.Position         = UDim2.new(0, 0, 1, -10)
    tbPatch.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
    tbPatch.BorderSizePixel  = 0
    tbPatch.Parent           = TitleBar

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size                   = UDim2.new(1, -40, 1, 0)
    TitleLabel.Position               = UDim2.new(0, 12, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.TextColor3             = Color3.fromRGB(220, 220, 230)
    TitleLabel.TextSize               = 13
    TitleLabel.Font                   = Enum.Font.GothamBold
    TitleLabel.Text                   = "⬡  ESP Control Panel"
    TitleLabel.TextXAlignment         = Enum.TextXAlignment.Left
    TitleLabel.Parent                 = TitleBar

    local MinBtn = Instance.new("TextButton")
    MinBtn.Size             = UDim2.new(0, 26, 0, 26)
    MinBtn.Position         = UDim2.new(1, -30, 0, 3)
    MinBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
    MinBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    MinBtn.TextSize         = 14
    MinBtn.Font             = Enum.Font.GothamBold
    MinBtn.Text             = "−"
    MinBtn.BorderSizePixel  = 0
    MinBtn.Parent           = TitleBar
    Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

    local InfoLabel = Instance.new("TextLabel")
    InfoLabel.Size                   = UDim2.new(1, -20, 0, 34)
    InfoLabel.Position               = UDim2.new(0, 10, 0, 36)
    InfoLabel.BackgroundTransparency = 1
    InfoLabel.TextColor3             = Color3.fromRGB(150, 150, 160)
    InfoLabel.TextSize               = 10
    InfoLabel.Font                   = Enum.Font.Gotham
    InfoLabel.Text                   = "F5: Monster | F6: Loot (Rampasan)\nF7: NPC | F8: Hide (Sembunyikan) UI"
    InfoLabel.TextXAlignment         = Enum.TextXAlignment.Left
    InfoLabel.Parent                 = Panel

    local btnColorOff = Color3.fromRGB(60, 60, 70)

    local ToggleMonsterBtn = createButton("ToggleMonster", "MONSTER: ON", UDim2.new(0, 10, 0, 76), Panel, CONFIG.Categories.Monster.FillColor)
    local ToggleLootBtn    = createButton("ToggleLoot", "LOOT & ITEM: ON", UDim2.new(0, 10, 0, 110), Panel, CONFIG.Categories.LootAndInteractive.FillColor)
    local ToggleNPCBtn     = createButton("ToggleNPC", "NPC: ON", UDim2.new(0, 10, 0, 144), Panel, CONFIG.Categories.NPC.FillColor)

    local function animateButton(btn, targetSize, targetPos)
        TweenService:Create(btn, TweenInfo.new(0.08), {Size = targetSize, Position = targetPos}):Play()
    end

    table.insert(connections, RunService.RenderStepped:Connect(function()
        pcall(function()
            ToggleMonsterBtn.Text = "MONSTER ESP: " .. (espMonsterEnabled and "ON" or "OFF")
            ToggleMonsterBtn.BackgroundColor3 = espMonsterEnabled and CONFIG.Categories.Monster.FillColor or btnColorOff

            ToggleLootBtn.Text = "LOOT & ITEM ESP: " .. (espLootInteractiveEnabled and "ON" or "OFF")
            ToggleLootBtn.BackgroundColor3 = espLootInteractiveEnabled and CONFIG.Categories.LootAndInteractive.FillColor or btnColorOff

            ToggleNPCBtn.Text = "NPC ESP: " .. (espNPCEnabled and "ON" or "OFF")
            ToggleNPCBtn.BackgroundColor3 = espNPCEnabled and CONFIG.Categories.NPC.FillColor or btnColorOff
        end)
    end))

    ToggleMonsterBtn.MouseButton1Click:Connect(function()
        espMonsterEnabled = not espMonsterEnabled
        animateButton(ToggleMonsterBtn, UDim2.new(1, -28, 0, 24), UDim2.new(0, 14, 0, 78))
        task.wait(0.08)
        animateButton(ToggleMonsterBtn, UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 76))
    end)

    ToggleLootBtn.MouseButton1Click:Connect(function()
        espLootInteractiveEnabled = not espLootInteractiveEnabled
        animateButton(ToggleLootBtn, UDim2.new(1, -28, 0, 24), UDim2.new(0, 14, 0, 112))
        task.wait(0.08)
        animateButton(ToggleLootBtn, UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 110))
    end)

    ToggleNPCBtn.MouseButton1Click:Connect(function()
        espNPCEnabled = not espNPCEnabled
        animateButton(ToggleNPCBtn, UDim2.new(1, -28, 0, 24), UDim2.new(0, 14, 0, 146))
        task.wait(0.08)
        animateButton(ToggleNPCBtn, UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 144))
    end)

    MinBtn.MouseButton1Click:Connect(function()
        panelVisible = not panelVisible
        Panel.Visible = panelVisible
    end)

    local dragging, dragStart, startPos = false, nil, nil
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = Panel.Position
        end
    end)
    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            Panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
    table.insert(connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))

    return ScreenGui
end

-- ════════════════════════════════════════
--  KEYBOARD SHORTCUTS
-- ════════════════════════════════════════
table.insert(connections, UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.F5 then
        espMonsterEnabled = not espMonsterEnabled
    elseif input.KeyCode == Enum.KeyCode.F6 then
        espLootInteractiveEnabled = not espLootInteractiveEnabled
    elseif input.KeyCode == Enum.KeyCode.F7 then
        espNPCEnabled = not espNPCEnabled
    elseif input.KeyCode == Enum.KeyCode.F8 then
        panelVisible = not panelVisible
        pcall(function()
            local ui = getGuiParent():FindFirstChild("ESP_UI")
            if ui then ui.Panel.Visible = panelVisible end
        end)
    end
end))

-- ════════════════════════════════════════
--  MAIN LOOP
-- ════════════════════════════════════════
local lastScan = 0
table.insert(connections, RunService.RenderStepped:Connect(function()
    local now = tick()
    if now - lastScan >= 0.5 then
        scanRegistry()
        lastScan = now
    end
    updateESPVisibility()
end))

-- ════════════════════════════════════════
--  CLEANUP
-- ════════════════════════════════════════
_G.ESP_CLEANUP = function()
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections = {}
    
    for _, registryData in pairs(espRegistry) do
        for model in pairs(registryData.Objects) do 
            removeESP(model, registryData) 
        end
    end
    espRegistry = {}
    
    pcall(function()
        local ui = getGuiParent():FindFirstChild("ESP_UI")
        if ui then ui:Destroy() end
    end)
    
    _G.ESP_RUNNING = false
end

-- ════════════════════════════════════════
--  INIT & RUN
-- ════════════════════════════════════════
for category, cfg in pairs(CONFIG.Categories) do
    registerFolderESP(category, cfg.Paths, cfg)
end

buildUI()
