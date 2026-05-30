-- ================================================================
--   ESP Part Name Script  [EXECUTOR EDITION]
--   Version : 2.0.0
--   Scan    : workspace -> Game System -> Monster (live folder)
--
--   Kompatibel dengan: Synapse X, KRNL, Script-Ware, Fluxus, dll.
-- ================================================================

-- ════════════════════════════════════════
--  GUARD: Cegah script berjalan dobel
-- ════════════════════════════════════════
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
    -- Path folder monster di workspace
    -- Ganti jika nama folder berbeda di game kamu
    MonsterFolderPath = {"GameSystem", "Monsters"},

    -- Filter nama part (kosong = ESP semua part di folder monster)
    -- Tidak perlu diisi karena semua isi folder = monster
    TargetNames = {},

    -- Label ESP
    TextSize            = 14,
    TextColor           = Color3.fromRGB(255, 255, 255),
    OutlineColor        = Color3.fromRGB(0, 0, 0),
    LabelBgColor        = Color3.fromRGB(0, 0, 0),
    LabelBgTransparency = 0.5,

    MaxDistance         = 200,  -- 0 = tak terbatas
    ShowDistance        = true,
    ShowLocalCharacter  = false,
    UpdateInterval      = 0.05,
}

-- ════════════════════════════════════════
--  STATE
-- ════════════════════════════════════════
local espLabels    = {}
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

-- Ambil folder monster secara dinamis dari path
local function getMonsterFolder()
    local current = workspace
    for _, name in ipairs(CONFIG.MonsterFolderPath) do
        current = current:FindFirstChild(name)
        if not current then return nil end
    end
    return current
end

local function tableIsEmpty(t)
    return next(t) == nil
end

local function isTarget(name)
    -- Jika TargetNames kosong, ESP semua part di folder monster
    if tableIsEmpty(CONFIG.TargetNames) then return true end
    for _, n in ipairs(CONFIG.TargetNames) do
        if name:lower() == n:lower() then return true end
    end
    return false
end

local function isLocalCharPart(part)
    local char = LocalPlayer.Character
    return char and part:IsDescendantOf(char) or false
end

-- ════════════════════════════════════════
--  ESP LABEL
-- ════════════════════════════════════════
local function createLabel(part)
    local ok, bb = pcall(function()
        local b = Instance.new("BillboardGui")
        b.Name           = "ESP_Label"
        b.AlwaysOnTop    = true
        b.MaxDistance    = CONFIG.MaxDistance > 0 and CONFIG.MaxDistance or math.huge
        b.StudsOffset    = Vector3.new(0, (part.Size.Y / 2) + 0.5, 0)
        b.Size           = UDim2.new(0, 130, 0, 34)
        b.LightInfluence = 0

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
        lbl.Text                   = part.Name
        lbl.Parent                 = frame

        b.Adornee = part
        b.Parent  = part
        return b
    end)
    if ok then return bb end
    warn("[ESP] Gagal buat label: " .. tostring(part.Name))
    return nil
end

local function removeLabel(part)
    local bb = espLabels[part]
    if bb then
        pcall(function() bb:Destroy() end)
        espLabels[part] = nil
    end
end

local function scanAndLabel()
    local folder = getMonsterFolder()

    -- Hapus label part yang sudah tidak ada
    for part in pairs(espLabels) do
        if not part or not part.Parent then
            removeLabel(part)
        end
    end

    -- Jika folder tidak ada (belum masuk game / di lobby), skip
    if not folder then return end

    -- Scan semua BasePart di folder monster
    for _, obj in ipairs(folder:GetDescendants()) do
        if obj:IsA("BasePart") and not espLabels[obj] and isTarget(obj.Name) then
            if CONFIG.ShowLocalCharacter or not isLocalCharPart(obj) then
                local lbl = createLabel(obj)
                if lbl then espLabels[obj] = lbl end
            end
        end
    end
end

local function updateLabels()
    local camPos = Camera.CFrame.Position
    for part, bb in pairs(espLabels) do
        if not part or not part.Parent then
            removeLabel(part)
        else
            pcall(function()
                local frameObj = bb:FindFirstChildWhichIsA("Frame")
                local lbl = frameObj and frameObj:FindFirstChild("NameLabel")
                if lbl then
                    if CONFIG.ShowDistance then
                        local dist = math.floor((part.Position - camPos).Magnitude)
                        if CONFIG.MaxDistance > 0 and dist > CONFIG.MaxDistance then
                            bb.Enabled = false
                        else
                            bb.Enabled = espEnabled
                            lbl.Text   = part.Name .. "\n[" .. dist .. " studs]"
                        end
                    else
                        bb.Enabled = espEnabled
                        lbl.Text   = part.Name
                    end
                end
            end)
        end
    end
end

local function setESP(state)
    espEnabled = state
    for _, bb in pairs(espLabels) do
        pcall(function() bb.Enabled = espEnabled end)
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
    stroke.Color = Color3.fromRGB(80, 130, 255)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.4
    stroke.Parent = Panel

    -- Title bar
    local TitleBar = Instance.new("Frame")
    TitleBar.Name             = "TitleBar"
    TitleBar.Size             = UDim2.new(1, 0, 0, 32)
    TitleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
    TitleBar.BorderSizePixel  = 0
    TitleBar.Parent           = Panel
    Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

    -- Patch rounded bottom title bar
    local tbPatch = Instance.new("Frame")
    tbPatch.Size             = UDim2.new(1, 0, 0, 10)
    tbPatch.Position         = UDim2.new(0, 0, 1, -10)
    tbPatch.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
    tbPatch.BorderSizePixel  = 0
    tbPatch.Parent           = TitleBar

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size                   = UDim2.new(1, -40, 1, 0)
    TitleLabel.Position               = UDim2.new(0, 12, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.TextColor3             = Color3.fromRGB(200, 210, 255)
    TitleLabel.TextSize               = 13
    TitleLabel.Font                   = Enum.Font.GothamBold
    TitleLabel.Text                   = "⬡  ESP Monster"
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

    -- Status
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

    -- Folder status
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

    -- Part count
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

    -- Hint
    local HintLabel = Instance.new("TextLabel")
    HintLabel.Size                   = UDim2.new(1, -20, 0, 14)
    HintLabel.Position               = UDim2.new(0, 10, 0, 90)
    HintLabel.BackgroundTransparency = 1
    HintLabel.TextColor3             = Color3.fromRGB(100, 100, 130)
    HintLabel.TextSize               = 10
    HintLabel.Font                   = Enum.Font.Gotham
    HintLabel.Text                   = "Toggle: F5  |  Hide panel: F6"
    HintLabel.TextXAlignment         = Enum.TextXAlignment.Left
    HintLabel.Parent                 = Panel

    -- Toggle button
    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Name             = "ToggleBtn"
    ToggleBtn.Size             = UDim2.new(1, -20, 0, 28)
    ToggleBtn.Position         = UDim2.new(0, 10, 0, 106)
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 255)
    ToggleBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    ToggleBtn.TextSize         = 13
    ToggleBtn.Font             = Enum.Font.GothamBold
    ToggleBtn.Text             = "ESP  ON"
    ToggleBtn.BorderSizePixel  = 0
    ToggleBtn.AutoButtonColor  = false
    ToggleBtn.Parent           = Panel
    Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 7)

    -- UI Logic
    table.insert(connections, RunService.RenderStepped:Connect(function()
        pcall(function()
            local count = 0
            for _ in pairs(espLabels) do count += 1 end
            CountLabel.Text = "Monster terdeteksi: " .. count

            -- Cek status folder
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
                ToggleBtn.BackgroundColor3   = Color3.fromRGB(50, 130, 255)
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

    -- Drag
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
    if now - lastScan >= 0.5 then   -- scan lebih cepat (0.5s) karena monster bisa muncul tiba-tiba
        pcall(scanAndLabel)
        lastScan = now
    end
    if espEnabled and now - lastUpdate >= CONFIG.UpdateInterval then
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
    for part in pairs(espLabels) do removeLabel(part) end
    pcall(function()
        local ui = getGuiParent():FindFirstChild("ESP_UI")
        if ui then ui:Destroy() end
    end)
    _G.ESP_RUNNING = false
    print("[ESP] Dihentikan.")
end

table.insert(connections, LocalPlayer.CharacterRemoving:Connect(function()
    for part in pairs(espLabels) do removeLabel(part) end
end))

-- ════════════════════════════════════════
--  DEBUG HELPER
-- ════════════════════════════════════════
_G.ESP_DEBUG = function()
    print("══════════ ESP DEBUG ══════════")
    local folder = getMonsterFolder()
    if not folder then
        print("  ✘ Folder 'Game System > Monster' tidak ditemukan di workspace.")
        print("  Cek apakah nama folder sudah benar di CONFIG.MonsterFolderPath")
        print("  Children workspace saat ini:")
        for _, c in ipairs(workspace:GetChildren()) do
            print("    → " .. c.Name)
        end
    else
        print("  ✔ Folder ditemukan: " .. folder:GetFullName())
        local count = 0
        for _, obj in ipairs(folder:GetDescendants()) do
            if obj:IsA("BasePart") then
                print("    Part → [" .. obj.Name .. "]  " .. obj:GetFullName())
                count += 1
            end
        end
        print("  Total BasePart: " .. count)
    end
    print("═══════════════════════════════")
end

-- ════════════════════════════════════════
--  INIT
-- ════════════════════════════════════════
buildUI()
print("[ESP Monster v2.0.0] Aktif!")
print("  Toggle ESP     : F5")
print("  Toggle Panel   : F6")
print("  Stop script    : _G.ESP_CLEANUP()")
print("  Debug folder   : _G.ESP_DEBUG()")
