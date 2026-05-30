-- ================================================================
--   ESP Part Name Script  [EXECUTOR EDITION]
--   Version : 1.1.0
--   Repo    : https://github.com/(your-username)/esp-partname-roblox
--
--   Kompatibel dengan: Synapse X, KRNL, Script-Ware, Fluxus, dll.
--
--   Perubahan vs versi Studio:
--     [1] GUI di-parent ke game.CoreGui (tidak ter-reset saat respawn)
--     [2] Fallback ke PlayerGui jika CoreGui tidak bisa diakses
--     [3] Semua blok kritis dibungkus pcall
--     [4] Cleanup koneksi via tabel agar tidak memory leak
--     [5] Guard jika script dijalankan lebih dari sekali
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
    TargetNames = {
        "120001",
        "120001-1",
        "120002",
        "120003",
        "120004",
        "120005",
        "120006",
        "120011",
        "120012",
        "120013",
        "1200014",
        "120015",
        "120016",
        "120017",
        "120017-1",
        "120017-2",
        "120018",
        "120019",
        "120020",
        "120021",
        "120022",
        "120023",
        "120024",
        "120025",
        "120026",
        "120027",
        "120028",
    },

    TextSize            = 14,
    TextColor           = Color3.fromRGB(255, 255, 255),
    OutlineColor        = Color3.fromRGB(0, 0, 0),
    LabelBgColor        = Color3.fromRGB(0, 0, 0),
    LabelBgTransparency = 0.5,
    MaxDistance         = 200,   -- 0 = tak terbatas
    ShowDistance        = true,
    ShowLocalCharacter  = false,
    -- Scan seluruh workspace (monster di-clone ke sini saat game berjalan)
    -- ReplicatedStorage hanya tempat template, BUKAN objek aktif di dunia
    ScanTargets         = {workspace},
    UpdateInterval      = 0.05,
}

-- ════════════════════════════════════════
--  STATE
-- ════════════════════════════════════════
local espLabels    = {}
local espEnabled   = true
local panelVisible = true
local connections  = {}   -- simpan semua koneksi untuk cleanup

-- ════════════════════════════════════════
--  HELPER: parent GUI ke CoreGui / fallback PlayerGui
-- ════════════════════════════════════════
local function getGuiParent()
    -- Executor biasanya punya akses CoreGui
    local ok, result = pcall(function()
        return CoreGui
    end)
    if ok and result then return result end
    -- Fallback
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- ════════════════════════════════════════
--  HELPERS
-- ════════════════════════════════════════
local function tableIsEmpty(t)
    return next(t) == nil
end

local function isTarget(name)
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

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = frame

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
    warn("[ESP] Gagal membuat label untuk: " .. tostring(part.Name))
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
    local found = {}
    for _, target in ipairs(CONFIG.ScanTargets) do
        pcall(function()
            for _, obj in ipairs(target:GetDescendants()) do
                if obj:IsA("BasePart") then
                    found[obj] = true
                end
            end
        end)
    end

    for part in pairs(found) do
        if not espLabels[part] and isTarget(part.Name) then
            if CONFIG.ShowLocalCharacter or not isLocalCharPart(part) then
                local lbl = createLabel(part)
                if lbl then espLabels[part] = lbl end
            end
        end
    end

    for part in pairs(espLabels) do
        if not part or not part.Parent then
            removeLabel(part)
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
    -- Hapus instance lama
    pcall(function()
        local old = getGuiParent():FindFirstChild("ESP_UI")
        if old then old:Destroy() end
    end)

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name           = "ESP_UI"
    ScreenGui.ResetOnSpawn   = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- ★ Parent ke CoreGui agar tidak hilang saat respawn
    local parentOk = pcall(function()
        ScreenGui.Parent = CoreGui
    end)
    if not parentOk then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        warn("[ESP] CoreGui tidak bisa diakses, fallback ke PlayerGui")
    end

    -- Panel utama
    local Panel = Instance.new("Frame")
    Panel.Name             = "Panel"
    Panel.Size             = UDim2.new(0, 220, 0, 130)
    Panel.Position         = UDim2.new(0, 20, 0.5, -65)
    Panel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    Panel.BorderSizePixel  = 0
    Panel.Active           = true
    Panel.Parent           = ScreenGui

    Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color        = Color3.fromRGB(80, 130, 255)
    stroke.Thickness    = 1.5
    stroke.Transparency = 0.4
    stroke.Parent       = Panel

    -- Title bar
    local TitleBar = Instance.new("Frame")
    TitleBar.Name             = "TitleBar"
    TitleBar.Size             = UDim2.new(1, 0, 0, 32)
    TitleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
    TitleBar.BorderSizePixel  = 0
    TitleBar.Parent           = Panel

    Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)

    local tbPatch = Instance.new("Frame")
    tbPatch.Size             = UDim2.new(1, 0, 0, 10)
    tbPatch.Position         = UDim2.new(0, 0, 1, -10)
    tbPatch.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
    tbPatch.BorderSizePixel  = 0
    tbPatch.Parent           = TitleBar

    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Size                  = UDim2.new(1, -40, 1, 0)
    TitleLabel.Position              = UDim2.new(0, 12, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.TextColor3            = Color3.fromRGB(200, 210, 255)
    TitleLabel.TextSize              = 13
    TitleLabel.Font                  = Enum.Font.GothamBold
    TitleLabel.Text                  = "⬡  ESP Part Name"
    TitleLabel.TextXAlignment        = Enum.TextXAlignment.Left
    TitleLabel.Parent                = TitleBar

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
    StatusLabel.Size                  = UDim2.new(1, -20, 0, 20)
    StatusLabel.Position              = UDim2.new(0, 10, 0, 38)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.TextColor3            = Color3.fromRGB(100, 220, 130)
    StatusLabel.TextSize              = 12
    StatusLabel.Font                  = Enum.Font.Gotham
    StatusLabel.Text                  = "● Status: ACTIVE"
    StatusLabel.TextXAlignment        = Enum.TextXAlignment.Left
    StatusLabel.Parent                = Panel

    -- Count
    local CountLabel = Instance.new("TextLabel")
    CountLabel.Size                  = UDim2.new(1, -20, 0, 18)
    CountLabel.Position              = UDim2.new(0, 10, 0, 58)
    CountLabel.BackgroundTransparency = 1
    CountLabel.TextColor3            = Color3.fromRGB(160, 160, 190)
    CountLabel.TextSize              = 11
    CountLabel.Font                  = Enum.Font.Gotham
    CountLabel.Text                  = "Parts terdeteksi: 0"
    CountLabel.TextXAlignment        = Enum.TextXAlignment.Left
    CountLabel.Parent                = Panel

    -- Hint
    local HintLabel = Instance.new("TextLabel")
    HintLabel.Size                  = UDim2.new(1, -20, 0, 16)
    HintLabel.Position              = UDim2.new(0, 10, 0, 78)
    HintLabel.BackgroundTransparency = 1
    HintLabel.TextColor3            = Color3.fromRGB(100, 100, 130)
    HintLabel.TextSize              = 10
    HintLabel.Font                  = Enum.Font.Gotham
    HintLabel.Text                  = "Toggle: F5  |  Hide panel: F6"
    HintLabel.TextXAlignment        = Enum.TextXAlignment.Left
    HintLabel.Parent                = Panel

    -- Toggle button
    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Name             = "ToggleBtn"
    ToggleBtn.Size             = UDim2.new(1, -20, 0, 28)
    ToggleBtn.Position         = UDim2.new(0, 10, 0, 96)
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 120, 255)
    ToggleBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
    ToggleBtn.TextSize         = 13
    ToggleBtn.Font             = Enum.Font.GothamBold
    ToggleBtn.Text             = "ESP  ON"
    ToggleBtn.BorderSizePixel  = 0
    ToggleBtn.AutoButtonColor  = false
    ToggleBtn.Parent           = Panel
    Instance.new("UICorner", ToggleBtn).CornerRadius = UDim.new(0, 7)

    -- ── UI Logic ──
    table.insert(connections, RunService.RenderStepped:Connect(function()
        pcall(function()
            local count = 0
            for _ in pairs(espLabels) do count += 1 end
            CountLabel.Text = "Parts terdeteksi: " .. count

            if espEnabled then
                StatusLabel.Text            = "● Status: ACTIVE"
                StatusLabel.TextColor3      = Color3.fromRGB(100, 220, 130)
                ToggleBtn.Text              = "ESP  ON"
                ToggleBtn.BackgroundColor3  = Color3.fromRGB(50, 130, 255)
            else
                StatusLabel.Text            = "● Status: OFF"
                StatusLabel.TextColor3      = Color3.fromRGB(200, 80, 80)
                ToggleBtn.Text              = "ESP  OFF"
                ToggleBtn.BackgroundColor3  = Color3.fromRGB(80, 80, 100)
            end
        end)
    end))

    ToggleBtn.MouseButton1Click:Connect(function()
        setESP(not espEnabled)
        local tweenIn = TweenService:Create(
            ToggleBtn, TweenInfo.new(0.08),
            {Size = UDim2.new(1, -28, 0, 24), Position = UDim2.new(0, 12, 0, 98)}
        )
        local tweenOut = TweenService:Create(
            ToggleBtn, TweenInfo.new(0.1),
            {Size = UDim2.new(1, -20, 0, 28), Position = UDim2.new(0, 10, 0, 96)}
        )
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
            dragging  = true
            dragStart = input.Position
            startPos  = Panel.Position
        end
    end)

    table.insert(connections, UserInputService.InputChanged:Connect(function(input)
        if dragging and (
            input.UserInputType == Enum.UserInputType.MouseMovement or
            input.UserInputType == Enum.UserInputType.Touch
        ) then
            local delta = input.Position - dragStart
            Panel.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
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
table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F5 then
        setESP(not espEnabled)
        print("[ESP] " .. (espEnabled and "ON ✔" or "OFF ✘"))
    elseif input.KeyCode == Enum.KeyCode.F6 then
        panelVisible = not panelVisible
        pcall(function()
            local ui = getGuiParent():FindFirstChild("ESP_UI")
            if ui then
                local panel = ui:FindFirstChild("Panel")
                if panel then panel.Visible = panelVisible end
            end
        end)
        print("[ESP] Panel " .. (panelVisible and "ditampilkan" or "disembunyikan"))
    end
end))

-- ════════════════════════════════════════
--  MAIN LOOP
-- ════════════════════════════════════════
local lastScan   = 0
local lastUpdate = 0

table.insert(connections, RunService.RenderStepped:Connect(function()
    local now = tick()
    if now - lastScan >= 1 then
        pcall(scanAndLabel)
        lastScan = now
    end
    if espEnabled and now - lastUpdate >= CONFIG.UpdateInterval then
        pcall(updateLabels)
        lastUpdate = now
    end
end))

-- ════════════════════════════════════════
--  CLEANUP FUNCTION (bisa dipanggil manual)
-- ════════════════════════════════════════
_G.ESP_CLEANUP = function()
    -- Putus semua koneksi
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections = {}

    -- Hapus semua label
    for part in pairs(espLabels) do
        removeLabel(part)
    end

    -- Hapus GUI
    pcall(function()
        local ui = getGuiParent():FindFirstChild("ESP_UI")
        if ui then ui:Destroy() end
    end)

    _G.ESP_RUNNING = false
    print("[ESP] Script dihentikan dan dibersihkan.")
end

-- Cleanup otomatis saat karakter respawn
table.insert(connections, LocalPlayer.CharacterRemoving:Connect(function()
    for part in pairs(espLabels) do
        removeLabel(part)
    end
end))

-- ════════════════════════════════════════
--  INIT
-- ════════════════════════════════════════
buildUI()
print("[ESP Part Name v1.1.0 - Executor Edition] Aktif!")
print("  Toggle ESP        : F5")
print("  Toggle Panel      : F6")
print("  Stop & Cleanup    : _G.ESP_CLEANUP()")
print("  Target Parts      : " .. #CONFIG.TargetNames .. " nama terdaftar")

-- ════════════════════════════════════════
--  DEBUG HELPER
--  Jalankan _G.ESP_DEBUG() di console
--  executor untuk cek apakah part target
--  sudah spawn di workspace
-- ════════════════════════════════════════
_G.ESP_DEBUG = function()
    print("══════════ ESP DEBUG ══════════")
    local found = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and isTarget(obj.Name) then
            found += 1
            print("  ✔ KETEMU → " .. obj.Name .. " | " .. obj:GetFullName())
        end
    end
    if found == 0 then
        print("  ✘ Tidak ada part target ditemukan di workspace.")
        print("  Kemungkinan: monster belum spawn / nama tidak cocok.")
        print("  50 BasePart pertama di workspace:")
        local c = 0
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("BasePart") then
                print("    → [" .. obj.Name .. "]  " .. obj:GetFullName())
                c += 1
                if c >= 50 then print("    ... (truncated)") break end
            end
        end
    else
        print("  Total ditemukan: " .. found .. " part")
    end
    print("═══════════════════════════════")
end
print("  Debug cek part    : _G.ESP_DEBUG()")
