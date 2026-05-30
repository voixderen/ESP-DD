-- ================================================================
--   ESP Framework Core  [EXECUTOR EDITION]
--   Version : 4.5.0 (Dual Feature & UI Integrated)
-- ================================================================

if _G.ESP_RUNNING then
    warn("[ESP] Framework sudah berjalan, memuat ulang...")
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
    Monster = {
        Path = {"GameSystem", "Monsters"},
        FillColor = Color3.fromRGB(255, 50, 50),
        OutlineColor = Color3.fromRGB(255, 50, 50),
        MaxDistance = 200,
    },
    Loot = {
        Path = {"GameSystem", "Loots", "World"},
        FillColor = Color3.fromRGB(50, 255, 50),
        OutlineColor = Color3.fromRGB(255, 255, 50),
        MaxDistance = 500,
    }
}

-- ════════════════════════════════════════
--  STATE
-- ════════════════════════════════════════
local espMonsterEnabled = true
local espLootEnabled    = true
local panelVisible      = true
local connections       = {}
local espRegistry       = {}

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
            if data.Label then data.Label:Destroy() end
        end)
        registryData.Objects[model] = nil
    end
end

local function createESP(model, config, category)
    local mainPart = getMainPart(model)
    if not mainPart then return nil end

    local data = {}
    local currentGlobalState = (category == "Monster" and espMonsterEnabled) or espLootEnabled

    local okHighlight, hl = pcall(function()
        local h = Instance.new("Highlight")
        h.Name                = "ESP_Highlight"
        h.FillColor           = config.FillColor
        h.FillTransparency    = 0.5
        h.OutlineColor        = config.OutlineColor
        h.OutlineTransparency = 0
        h.Adornee             = model
        h.Enabled             = currentGlobalState
        h.Parent              = CoreGui
        return h
    end)
    if okHighlight then data.Highlight = hl end

    local okLabel, bb = pcall(function()
        local b = Instance.new("BillboardGui")
        b.Name           = "ESP_Label"
        b.AlwaysOnTop    = true
        b.MaxDistance    = config.MaxDistance > 0 and config.MaxDistance or math.huge
        b.StudsOffset    = Vector3.new(0, 3, 0)
        b.Size           = UDim2.new(0, 130, 0, 34)
        b.LightInfluence = 0
        b.Enabled        = currentGlobalState

        local frame = Instance.new("Frame")
        frame.Size                   = UDim2.new(1, 0, 1, 0)
        frame.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
        frame.BackgroundTransparency = 0.5
        frame.BorderSizePixel        = 0
        frame.Parent                 = b
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 4)

        local lbl = Instance.new("TextLabel")
        lbl.Name                   = "NameLabel"
        lbl.Size                   = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3             = Color3.fromRGB(255, 255, 255)
        lbl.TextStrokeColor3       = Color3.fromRGB(0, 0, 0)
        lbl.TextStrokeTransparency = 0
        lbl.TextSize               = 14
        lbl.Font                   = Enum.Font.GothamBold
        lbl.Text                   = model.Name
        lbl.Parent                 = frame

        b.Adornee = mainPart
        b.Parent  = CoreGui
        return b
    end)
    if okLabel then data.Label = bb end

    return data
end

local function registerFolderESP(category, pathTable, config)
    local registryData = {
        Category = category,
        Path = pathTable,
        Config = config,
        Objects = {},
        ActiveFolder = nil
    }
    espRegistry[category] = registryData
end

local function scanRegistry()
    for category, registryData in pairs(espRegistry) do
        local currentFolder = resolvePath(registryData.Path)
        
        if currentFolder ~= registryData.ActiveFolder then
            for model in pairs(registryData.Objects) do
                removeESP(model, registryData)
            end
            registryData.ActiveFolder = currentFolder
        end

        for model in pairs(registryData.Objects) do
            if not model or not model.Parent then
                removeESP(model, registryData)
            end
        end

        if currentFolder then
            for _, child in ipairs(currentFolder:GetChildren()) do
                if not registryData.Objects[child] then
                    local data = createESP(child, registryData.Config, category)
                    if data then registryData.Objects[child] = data end
                end
            end
        end
    end
end

local function updateESPVisibility()
    for category, registryData in pairs(espRegistry) do
        local camPos = Camera.CFrame.Position
        local globalState = (category == "Monster" and espMonsterEnabled) or espLootEnabled
        
        for model, data in pairs(registryData.Objects) do
            if model and model.Parent then
                pcall(function()
                    local mainPart = getMainPart(model)
                    if mainPart and data.Label and data.Highlight then
                        local dist = (mainPart.Position - camPos).Magnitude
                        local maxDist = registryData.Config.MaxDistance
                        local inRange = maxDist == 0 or dist <= maxDist

                        data.Label.Enabled = globalState and inRange
                        data.Highlight.Enabled = globalState and inRange
                    end
                end)
            end
        end
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
    btn.TextSize         = 13
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
    Panel.Size             = UDim2.new(0, 220, 0, 160)
    Panel.Position         = UDim2.new(0, 20, 0.5, -80)
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
    TitleLabel.Text                   = "⬡  ESP Multi-Folder"
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
    InfoLabel.Text                   = "F5: Toggle Monster  |  F6: Toggle Loot\nF7: Sembunyikan Panel"
    InfoLabel.TextXAlignment         = Enum.TextXAlignment.Left
    InfoLabel.Parent                 = Panel

    local ToggleMonsterBtn = createButton("ToggleMonster", "MONSTER: ON", UDim2.new(0, 10, 0, 80), Panel, CONFIG.Monster.FillColor)
    local ToggleLootBtn    = createButton("ToggleLoot", "LOOT: ON", UDim2.new(0, 10, 0, 116), Panel, CONFIG.Loot.FillColor)

    local function animateButton(btn, targetSize, targetPos)
        TweenService:Create(btn, TweenInfo.new(0.08), {Size = targetSize, Position = targetPos}):Play()
    end

    table.insert(connections, RunService.RenderStepped:Connect(function()
        pcall(function()
            if espMonsterEnabled then
                ToggleMonsterBtn.Text = "MONSTER ESP: ON"
                ToggleMonsterBtn.BackgroundColor3 = CONFIG.Monster.FillColor
            else
                ToggleMonsterBtn.Text = "MONSTER ESP: OFF"
                ToggleMonsterBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            end

            if espLootEnabled then
                ToggleLootBtn.Text = "LOOT ESP: ON"
                ToggleLootBtn.BackgroundColor3 = CONFIG.Loot.FillColor
            else
                ToggleLootBtn.Text = "LOOT ESP: OFF"
                ToggleLootBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            end
        end)
    end))

    ToggleMonsterBtn.MouseButton1Click:Connect(function()
        espMonsterEnabled = not espMonsterEnabled
        updateESPVisibility()
        animateButton(ToggleMonsterBtn, UDim2.new(1, -28, 0, 24), UDim2.new(0, 14, 0, 82))
        task.wait(0.08)
        animateButton(ToggleMonsterBtn, UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 80))
    end)

    ToggleLootBtn.MouseButton1Click:Connect(function()
        espLootEnabled = not espLootEnabled
        updateESPVisibility()
        animateButton(ToggleLootBtn, UDim2.new(1, -28, 0, 24), UDim2.new(0, 14, 0, 118))
        task.wait(0.08)
        animateButton(ToggleLootBtn, UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 116))
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
        updateESPVisibility()
    elseif input.KeyCode == Enum.KeyCode.F6 then
        espLootEnabled = not espLootEnabled
        updateESPVisibility()
    elseif input.KeyCode == Enum.KeyCode.F7 then
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
    print("[ESP] Semua fitur dinonaktifkan dan dibersihkan.")
end

-- ════════════════════════════════════════
--  INIT & RUN
-- ════════════════════════════════════════
registerFolderESP("Monster", CONFIG.Monster.Path, CONFIG.Monster)
registerFolderESP("Loot", CONFIG.Loot.Path, CONFIG.Loot)

buildUI()
print("[ESP Dual Framework] Berhasil dijalankan!")
