-- ================================================================
--   ESP Part Name Script  [EXECUTOR EDITION]
--   Version : 3.0.0 (Highlight & Model-Based)
--   Scan    : workspace -> Game System -> Monster (live folder)
--
--   Kompatibel dengan: Synapse X, KRNL, Script-Ware, Fluxus, dll.
-- ================================================================

if _G.ESP_RUNNING then
    warn("[ESP] Script sudah berjalan, memuat ulang...")
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
--  KONFIGURASI
-- ════════════════════════════════════════
local CONFIG = {
    MonsterFolderPath = {"GameSystem", "Monsters"},

    -- Label ESP
    TextSize            = 14,
    TextColor           = Color3.fromRGB(255, 255, 255),
    OutlineColor        = Color3.fromRGB(0, 0, 0),
    LabelBgColor        = Color3.fromRGB(0, 0, 0),
    LabelBgTransparency = 0.5,

    -- Highlight ESP
    FillColor           = Color3.fromRGB(255, 0, 0),
    FillTransparency    = 0.5,
    OutlineColorHighlight = Color3.fromRGB(255, 0, 0),
    OutlineTransparency = 0,

    MaxDistance         = 200,  -- 0 = tak terbatas
    ShowLocalCharacter  = false,
    UpdateInterval      = 0.05,
}

-- ════════════════════════════════════════
--  STATE
-- ════════════════════════════════════════
local espObjects   = {}
local espEnabled   = true
local panelVisible = true
local connections  = {}

-- ════════════════════════════════════════
--  HELPERS
-- ════════════════════════════════════════
local function getGuiParent()
    local ok, result = pcall(function() return CoreGui end)
    return (ok and result) or LocalPlayer:WaitForChild("PlayerGui")
end

local function getMonsterFolder()
    local current = workspace
    for _, name in ipairs(CONFIG.MonsterFolderPath) do
        current = current:FindFirstChild(name)
        if not current then return nil end
    end
    return current
end

local function isLocalChar(model)
    local char = LocalPlayer.Character
    return char and model == char or false
end

local function getMainPart(model)
    if not model then return nil end
    return model:FindFirstChild("HumanoidRootPart") 
        or model:FindFirstChildWhichIsA("BasePart")
end

-- ════════════════════════════════════════
--  ESP CREATION & REMOVAL
-- ════════════════════════════════════════
local function createESP(model)
    local mainPart = getMainPart(model)
    if not mainPart then return nil end

    local data = {}

    -- 1. Buat Highlight untuk Model
    local okHighlight, hl = pcall(function()
        local h = Instance.new("Highlight")
        h.Name                = "ESP_Highlight"
        h.FillColor           = CONFIG.FillColor
        h.FillTransparency    = CONFIG.FillTransparency
        h.OutlineColor        = CONFIG.OutlineColorHighlight
        h.OutlineTransparency = CONFIG.OutlineTransparency
        h.Adornee             = model
        h.Enabled             = espEnabled
        h.Parent              = CoreGui
        return h
    end)
    if okHighlight then data.Highlight = hl end

    -- 2. Buat BillboardGui Label di Main Part
    local okLabel, bb = pcall(function()
        local b = Instance.new("BillboardGui")
        b.Name           = "ESP_Label"
        b.AlwaysOnTop    = true
        b.MaxDistance    = CONFIG.MaxDistance > 0 and CONFIG.MaxDistance or math.huge
        b.StudsOffset    = Vector3.new(0, 3, 0)
        b.Size           = UDim2.new(0, 130, 0, 34)
        b.LightInfluence = 0
        b.Enabled        = espEnabled

        local frame = Instance.new("Frame")
        frame.Size                   = UDim2.new(1, 0, 1, 0)
        frame.BackgroundColor3       = CONFIG.LabelBgColor
        frame.BackgroundTransparency = CONFIG.LabelBgTransparency
        frame.BorderSizePixel        = 0
        frame.Parent                 = b
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 4)

        local lbl = Instance.new("TextLabel")
        lbl.Name                   = "NameLabel"
        lbl.Size                   = UDim2.new(1, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3             = CONFIG.TextColor
        lbl.TextStrokeColor3       = CONFIG.OutlineColor
        lbl.TextStrokeTransparency = 0
        lbl.TextSize               = CONFIG.TextSize
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

local function removeESP(model)
    local data = espObjects[model]
    if data then
        pcall(function()
            if data.Highlight then data.Highlight:Destroy() end
            if data.Label then data.Label:Destroy() end
        end)
        espObjects[model] = nil
    end
end

local function scanAndLabel()
    local folder = getMonsterFolder()

    for model in pairs(espObjects) do
        if not model or not model.Parent then
            removeESP(model)
        end
    end

    if not folder then return end

    -- Scan direct children (tiap child = 1 monster)
    for _, obj in ipairs(folder:GetChildren()) do
        if not espObjects[obj] then
            if CONFIG.ShowLocalCharacter or not isLocalChar(obj) then
                local data = createESP(obj)
                if data then espObjects[obj] = data end
            end
        end
    end
end

local function updateLabels()
    local camPos = Camera.CFrame.Position
    for model, data in pairs(espObjects) do
        if not model or not model.Parent then
            removeESP(model)
        else
            pcall(function()
                local mainPart = getMainPart(model)
                if mainPart and data.Label and data.Highlight then
                    local dist = (mainPart.Position - camPos).Magnitude
                    local inRange = CONFIG.MaxDistance == 0 or dist <= CONFIG.MaxDistance

                    data.Label.Enabled = espEnabled and inRange
                    data.Highlight.Enabled = espEnabled and inRange

                    if data.Label.Adornee ~= mainPart then
                        data.Label.Adornee = mainPart
                    end
                else
                    if data.Label then data.Label.Enabled = false end
                    if data.Highlight then data.Highlight.Enabled = false end
                end
            end)
        end
    end
end

local function setESP(state)
    espEnabled = state
    for _, data in pairs(espObjects) do
        pcall(function()
            if data.Highlight then data.Highlight.Enabled = espEnabled end
            if data.Label then data.Label.Enabled = espEnabled end
        end)
    end
end

-- ════════════════════════════════════════
--  UI PANEL
-- ════════════════════════════════════════
local function buildUI()
    pcall(function()
        local old = getGuiParent():FindFirstChild("ESP_UI")
        if old then old:Destroy() end
    end)

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name           = "ESP_UI"
    ScreenGui.ResetOnSpawn   = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    local parentOk = pcall(function() ScreenGui.Parent = CoreGui end)
    if not parentOk then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    local Panel = Instance.new("Frame")
    Panel.Name             = "Panel"
    Panel.Size             = UDim2.new(0, 220, 0, 140)
    Panel.Position         = UDim2.new(0, 20, 0.5, -70)
    Panel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    Panel.BorderSizePixel  = 0
    Panel.Active           = true
    Panel.Parent           = ScreenGui
    Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 80, 80)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.4
    stroke.Parent = Panel

    local TitleBar = Instance.new("Frame")
    TitleBar.Name             = "TitleBar"
    TitleBar.Size             = UDim2.new(1, 0, 0, 32)
    TitleBar.BackgroundColor3 = Color3.fromRGB(40, 28, 28)
    TitleBar.BorderSizePixel  = 0
    TitleBar.Parent           = Panel
    Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

    local tbPatch = Instance.new("Frame")
    tbPatch.Size             = UDim2.new(1, 0, 0, 10)
    tbPatch.Position         = UDim2.new(0, 0, 1, -10)
    tbPatch.BackgroundColor3 = Color3.fromRGB(40, 28, 28)
    tbPatch.BorderSizePixel  = 0
    tbPatch.Parent           = TitleBar

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size                   = UDim2.new(1, -40, 1, 0)
    TitleLabel.Position               = UDim2.new(0, 12, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.TextColor3             = Color3.fromRGB(255, 200, 200)
    TitleLabel.TextSize               = 13
    TitleLabel.Font                   = Enum.Font.GothamBold
    TitleLabel.Text                   = "⬡  ESP Monster v3"
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

    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Size                   = UDim2.new(1, -20, 0, 20)
    StatusLabel.Position               = UDim2.new(0, 10, 0, 38)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.TextColor3             = Color3.fromRGB(100, 220, 130)
    StatusLabel.TextSize               = 12
    StatusLabel.Font                   = Enum.Font.Gotham
    StatusLabel.Text                   = "● Status: ACTIVE"
    StatusLabel.TextXAlignment         = Enum.TextXAlignment.Left
    StatusLabel.Parent                 = Panel

    local FolderLabel = Instance.new("TextLabel")
    FolderLabel.Size                   = UDim2.new(1, -20, 0, 16)
    FolderLabel.Position               = UDim2.new(0, 10, 0, 58)
    FolderLabel.BackgroundTransparency = 1
    FolderLabel.TextColor3             = Color3.fromRGB(160, 160, 190)
    FolderLabel.TextSize               = 10
    FolderLabel.Font                   = Enum.Font.Gotham
    FolderLabel.Text                   = "Folder: menunggu game..."
    FolderLabel.TextXAlignment         = Enum.TextXAlignment.Left
    FolderLabel.Parent                 = Panel

    local CountLabel = Instance.new("TextLabel")
    CountLabel.Size                   = UDim2.new(1, -20, 0, 16)
    CountLabel.Position               = UDim2.new(0, 10, 0, 74)
    CountLabel.BackgroundTransparency = 1
    CountLabel.TextColor3             = Color3.fromRGB(160, 160, 190)
    CountLabel.TextSize               = 11
    CountLabel.Font                   = Enum.Font.Gotham
    CountLabel.Text                   = "Monster terdeteksi: 0"
    CountLabel.TextXAlignment         = Enum.TextXAlignment.Left
    CountLabel.Parent                 = Panel

    local HintLabel = Instance.new("TextLabel")
    HintLabel.Size                   = UDim2.new(1, -20, 0, 14)
    HintLabel.Position               = UDim2.new(0, 10, 0, 90)
    HintLabel.BackgroundTransparency = 1
    HintLabel.TextColor3             = Color3.fromRGB(100, 100, 130)
    HintLabel.TextSize         = 10
    HintLabel.Font                   = Enum.Font.Gotham
    HintLabel.Text                   = "Toggle: F5  |  Hide panel: F6"
    HintLabel.TextXAlignment         = Enum.TextXAlignment.Left
    HintLabel.Parent                 = Panel

    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Name             = "ToggleBtn"
    ToggleBtn.Size             = UDim2.new(1, -20, 0, 28)
    ToggleBtn.Position         = UDim2.new(0, 10, 0, 106)
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    ToggleBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    ToggleBtn.TextSize         = 13
    ToggleBtn.Font             = Enum.Font.GothamBold
    ToggleBtn.Text             = "ESP  ON"
    ToggleBtn.BorderSizePixel  = 0
    ToggleBtn.AutoButtonColor  = false
    ToggleBtn.Parent           = Panel
    Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 7)

    table.insert(connections, RunService.RenderStepped:Connect(function()
        pcall(function()
            local count = 0
            for _ in pairs(espObjects) do count += 1 end
            CountLabel.Text = "Monster terdeteksi: " .. count

            local folder = getMonsterFolder()
            if folder then
                FolderLabel.Text      = "✔ Folder ditemukan"
                FolderLabel.TextColor3 = Color3.fromRGB(100, 220, 130)
            else
                FolderLabel.Text      = "⏳ Menunggu game dimulai..."
                FolderLabel.TextColor3 = Color3.fromRGB(200, 160, 60)
            end

            if espEnabled then
                StatusLabel.Text             = "● Status: ACTIVE"
                StatusLabel.TextColor3       = Color3.fromRGB(100, 220, 130)
                ToggleBtn.Text               = "ESP  ON"
                ToggleBtn.BackgroundColor3   = Color3.fromRGB(255, 50, 50)
            else
                StatusLabel.Text             = "● Status: OFF"
                StatusLabel.TextColor3       = Color3.fromRGB(200, 80, 80)
                ToggleBtn.Text               = "ESP  OFF"
                ToggleBtn.BackgroundColor3   = Color3.fromRGB(80, 80, 100)
            end
        end)
    end))

    ToggleBtn.MouseButton1Click:Connect(function()
        setESP(not espEnabled)
        local tweenIn = TweenService:Create(ToggleBtn, TweenInfo.new(0.08),
            {Size = UDim2.new(1, -28, 0, 24), Position = UDim2.new(0, 12, 0, 108)})
        local tweenOut = TweenService:Create(ToggleBtn, TweenInfo.new(0.1),
            {Size = UDim2.new(1, -20, 0, 28), Position = UDim2.new(0, 10, 0, 106)})
        tweenIn:Play()
        tweenIn.Completed:Once(function() tweenOut:Play() end)
    end)

    MinBtn.MouseButton1Click:Connect(function()
        panelVisible = not panelVisible
        Panel.Visible = panelVisible
    end)

    local dragging, dragStart, startPos = false, nil, nil
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = Panel.Position
        end
    end)
    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            Panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                       startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end))
    table.insert(connections, UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
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
        setESP(not espEnabled)
        print("[ESP] " .. (espEnabled and "ON ✔" or "OFF ✘"))
    elseif input.KeyCode == Enum.KeyCode.F6 then
        panelVisible = not panelVisible
        pcall(function()
            local ui = getGuiParent():FindFirstChild("ESP_UI")
            if ui then
                local p = ui:FindFirstChild("Panel")
                if p then p.Visible = panelVisible end
            end
        end)
    end
end))

-- ════════════════════════════════════════
--  MAIN LOOP
-- ════════════════════════════════════════
local lastScan, lastUpdate = 0, 0
table.insert(connections, RunService.RenderStepped:Connect(function()
    local now = tick()
    if now - lastScan >= 0.5 then
        pcall(scanAndLabel)
        lastScan = now
    end
    if now - lastUpdate >= CONFIG.UpdateInterval then
        pcall(updateLabels)
        lastUpdate = now
    end
end))

-- ════════════════════════════════════════
--  CLEANUP
-- ════════════════════════════════════════
_G.ESP_CLEANUP = function()
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections = {}
    for model in pairs(espObjects) do removeESP(model) end
    pcall(function()
        local ui = getGuiParent():FindFirstChild("ESP_UI")
        if ui then ui:Destroy() end
    end)
    _G.ESP_RUNNING = false
    print("[ESP] Dihentikan.")
end

table.insert(connections, LocalPlayer.CharacterRemoving:Connect(function()
    for model in pairs(espObjects) do removeESP(model) end
end))

-- ════════════════════════════════════════
--  DEBUG HELPER
-- ════════════════════════════════════════
_G.ESP_DEBUG = function()
    print("══════════ ESP DEBUG ══════════")
    local folder = getMonsterFolder()
    if not folder then
        print("  ✘ Folder tidak ditemukan.")
    else
        print("  ✔ Folder ditemukan: " .. folder:GetFullName())
        local count = 0
        for _, obj in ipairs(folder:GetChildren()) do
            print("    Monster Model → [" .. obj.Name .. "]")
            count += 1
        end
        print("  Total Model Monster: " .. count)
    end
    print("═══════════════════════════════")
end

-- ════════════════════════════════════════
--  INIT
-- ════════════════════════════════════════
buildUI()
print("[ESP Monster v3.0.0] Aktif!")
