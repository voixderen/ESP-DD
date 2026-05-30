-- ================================================================
--   ESP Framework Core & Auto-Collect
--   Version : 7.0.0
--   Game    : Deadly Delivery
--
--   Auto Collect Flow:
--     1. Cek folder World → ada loot?
--     2. Teleport ke tiap loot → tekan E → ambil semua
--     3. Cek folder Player → ada item?
--     4. Teleport ke 电梯→FoodGathering
--     5. Tunggu folder Player kosong (deposit selesai)
--     6. Loop ke step 1
-- ================================================================

if _G.ESP_RUNNING then
    if _G.ESP_CLEANUP then pcall(_G.ESP_CLEANUP) end
end
_G.ESP_RUNNING = true

-- ════════════════════════════════════════
--  SERVICES
-- ════════════════════════════════════════
local Players             = game:GetService("Players")
local UserInputService    = game:GetService("UserInputService")
local TweenService        = game:GetService("TweenService")
local CoreGui             = game:GetService("CoreGui")
local RunService          = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer         = Players.LocalPlayer

-- ════════════════════════════════════════
--  CONFIG
-- ════════════════════════════════════════
local CONFIG = {
    Monster = {
        Paths = {{"GameSystem", "Monsters"}},
        Color = Color3.fromRGB(255, 50, 50)
    },
    Loot = {
        Paths = {
            {"GameSystem", "Loots", "World"},
            {"GameSystem", "InteractiveItem"}
        },
        Color = Color3.fromRGB(50, 255, 50)
    },
    NPC = {
        Paths = {{"GameSystem", "NPCModels"}},
        Color = Color3.fromRGB(50, 100, 255)
    },

    -- Auto Collect paths
    AC_WorldPath    = {"GameSystem", "Loots", "World"},
    AC_PlayerPath   = {"GameSystem", "Loots", "Player"},
    AC_ElevatorName = "电梯",          -- nama folder elevator di workspace
    AC_GatherPart   = "FoodGathering", -- nama part/folder di dalam elevator

    -- Timeout tunggu deposit (detik)
    AC_DepositTimeout = 20,

    -- Jeda antar teleport (detik)
    AC_TeleportDelay  = 0.35,
    AC_InteractDelay  = 0.25,
}

-- ════════════════════════════════════════
--  STATE
-- ════════════════════════════════════════
local State = {
    Monster     = true,
    Loot        = true,
    NPC         = true,
    AutoCollect = false,
    UI          = true,
}
local acStatus     = "Idle"  -- status teks untuk UI
local MAX_DISTANCE = 1500
local MAX_HIGHLIGHTS = 30
local highlightPool = {}
local connections   = {}

-- ════════════════════════════════════════
--  HELPERS
-- ════════════════════════════════════════
local function getGuiParent()
    local ok, res = pcall(function() return CoreGui end)
    return (ok and res) or LocalPlayer:WaitForChild("PlayerGui")
end

local guiParent = getGuiParent()

-- Traversal path dari workspace
local function getPath(pathTable)
    local current = workspace
    for _, name in ipairs(pathTable) do
        current = current:FindFirstChild(name)
        if not current then return nil end
    end
    return current
end

local function getPart(model)
    if not model then return nil end
    if model:IsA("BasePart") then return model end
    if model.PrimaryPart then return model.PrimaryPart end
    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChildWhichIsA("BasePart")
end

-- ════════════════════════════════════════
--  AUTO COLLECT HELPERS
-- ════════════════════════════════════════
local function getWorldFolder()
    return getPath(CONFIG.AC_WorldPath)
end

local function getPlayerFolder()
    return getPath(CONFIG.AC_PlayerPath)
end

local function getFoodGathering()
    local elevator = workspace:FindFirstChild(CONFIG.AC_ElevatorName)
    if not elevator then return nil end
    return elevator:FindFirstChild(CONFIG.AC_GatherPart)
end

-- Dapatkan CFrame dari suatu instance (Model atau BasePart)
local function getInstanceCFrame(inst)
    if not inst then return nil end
    local ok, cf = pcall(function()
        if inst:IsA("BasePart") then return inst.CFrame end
        return inst:GetPivot()
    end)
    return ok and cf or nil
end

-- Hitung jumlah item di folder (cepat)
local function folderCount(folder)
    if not folder then return 0 end
    return #folder:GetChildren()
end

-- ════════════════════════════════════════
--  HIGHLIGHT POOL (ESP)
-- ════════════════════════════════════════
for i = 1, MAX_HIGHLIGHTS do
    local hl = Instance.new("Highlight")
    hl.Name = "ESP_HL_" .. i
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.Enabled = false
    hl.Parent = guiParent
    table.insert(highlightPool, hl)
end

local function updateESP()
    local cam = workspace.CurrentCamera
    if not cam then return end
    local camPos = cam.CFrame.Position
    local targets = {}

    for key, cfg in pairs(CONFIG) do
        if State[key] and type(cfg) == "table" and cfg.Paths then
            for _, path in ipairs(cfg.Paths) do
                local folder = getPath(path)
                if folder then
                    for _, obj in ipairs(folder:GetChildren()) do
                        pcall(function()
                            local part = getPart(obj)
                            if part then
                                local dist = (part.Position - camPos).Magnitude
                                if dist <= MAX_DISTANCE then
                                    table.insert(targets, {
                                        obj   = obj,
                                        dist  = dist,
                                        color = cfg.Color
                                    })
                                end
                            end
                        end)
                    end
                end
            end
        end
    end

    table.sort(targets, function(a, b) return a.dist < b.dist end)

    for i, hl in ipairs(highlightPool) do
        local target = targets[i]
        pcall(function()
            if target then
                if hl.Adornee ~= target.obj then hl.Adornee = target.obj end
                if hl.FillColor ~= target.color then
                    hl.FillColor    = target.color
                    hl.OutlineColor = target.color
                end
                if not hl.Enabled then hl.Enabled = true end
            else
                if hl.Adornee   then hl.Adornee = nil end
                if hl.Enabled   then hl.Enabled = false end
            end
        end)
    end
end

-- ════════════════════════════════════════
--  AUTO COLLECT CORE
-- ════════════════════════════════════════
local function triggerAutoCollect()
    local char = LocalPlayer.Character
    local hrp  = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then
        State.AutoCollect = false
        return
    end

    local initialCFrame = hrp.CFrame
    local totalCollected = 0
    local totalDeposited = 0
    local round = 0

    print("[AutoCollect] Dimulai.")

    -- ── LOOP UTAMA ────────────────────────────────
    while State.AutoCollect do
        round += 1

        -- ─── STEP 1: Cek folder World ──────────────
        acStatus = "Mengecek loot World..."
        local worldFolder = getWorldFolder()

        if not worldFolder then
            acStatus = "Folder World tidak ditemukan"
            warn("[AutoCollect] Folder World tidak ditemukan. Cek CONFIG.AC_WorldPath.")
            break
        end

        local loots = worldFolder:GetChildren()
        if #loots == 0 then
            acStatus = "Selesai — tidak ada loot tersisa"
            print("[AutoCollect] Tidak ada loot di World. Selesai. Total: " .. totalCollected .. " diambil, " .. totalDeposited .. " deposit.")
            break
        end

        print(string.format("[AutoCollect] Round %d — %d loot di World", round, #loots))

        -- ─── STEP 2: Kumpulkan SEMUA loot di World ──
        local collectedThisRound = 0
        for _, loot in ipairs(loots) do
            if not State.AutoCollect then break end

            -- Teleport ke pivot loot
            acStatus = "Mengambil: " .. loot.Name
            local cf = getInstanceCFrame(loot)
            if cf then
                hrp.CFrame = cf
                task.wait(CONFIG.AC_TeleportDelay)
            end

            -- Coba fire ProximityPrompt dulu
            local prompted = false
            for _, desc in ipairs(loot:GetDescendants()) do
                if desc:IsA("ProximityPrompt") then
                    pcall(function() fireproximityprompt(desc) end)
                    prompted = true
                    task.wait(CONFIG.AC_InteractDelay)
                    break
                end
            end

            -- Fallback: tekan E
            if not prompted then
                VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
                task.wait(0.1)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                task.wait(CONFIG.AC_InteractDelay)
            end

            collectedThisRound += 1
        end

        totalCollected += collectedThisRound

        if not State.AutoCollect then break end

        -- ─── STEP 3: Cek folder Player ──────────────
        task.wait(0.4)  -- beri waktu server update
        acStatus = "Mengecek folder Player..."

        local playerFolder = getPlayerFolder()
        local playerCount  = folderCount(playerFolder)

        if playerCount == 0 then
            -- Tidak ada yang masuk ke Player (mungkin gagal ambil / sudah kosong)
            print("[AutoCollect] Tidak ada item di folder Player, lanjut scan World.")
            task.wait(0.5)
            continue
        end

        print(string.format("[AutoCollect] %d item di folder Player, menuju deposit...", playerCount))

        -- ─── STEP 4: Teleport ke FoodGathering ──────
        acStatus = "Menuju elevator deposit..."
        local fgObj = getFoodGathering()

        if not fgObj then
            warn("[AutoCollect] FoodGathering tidak ditemukan di '" .. CONFIG.AC_ElevatorName .. "'.")
            warn("[AutoCollect] Cek CONFIG.AC_ElevatorName / CONFIG.AC_GatherPart.")
            break
        end

        local fgCF = getInstanceCFrame(fgObj)
        if fgCF then
            hrp.CFrame = fgCF
            task.wait(CONFIG.AC_TeleportDelay)
        end

        -- ─── STEP 5: Tunggu folder Player kosong ────
        acStatus = "Menunggu deposit selesai..."
        local elapsed   = 0
        local deposited = false

        while elapsed < CONFIG.AC_DepositTimeout and State.AutoCollect do
            task.wait(0.5)
            elapsed += 0.5

            playerFolder = getPlayerFolder()
            if folderCount(playerFolder) == 0 then
                deposited = true
                break
            end

            -- Update status dengan timer
            acStatus = string.format("Deposit... (%ds)", math.floor(CONFIG.AC_DepositTimeout - elapsed))
        end

        if not State.AutoCollect then break end

        if not deposited then
            warn("[AutoCollect] Timeout! Folder Player tidak kosong setelah " .. CONFIG.AC_DepositTimeout .. "s.")
            acStatus = "Timeout deposit!"
            break
        end

        totalDeposited += playerCount
        print(string.format("[AutoCollect] Deposit selesai. +%d item (total deposit: %d)", playerCount, totalDeposited))

        -- ─── STEP 6: Loop kembali ke scan World ─────
        task.wait(0.3)
        acStatus = "Kembali ke scan World..."
    end

    -- Kembali ke posisi semula
    pcall(function()
        if hrp and hrp.Parent then
            hrp.CFrame = initialCFrame
        end
    end)

    if acStatus ~= "Selesai — tidak ada loot tersisa" and acStatus ~= "Idle" then
        acStatus = "Selesai"
    end
    State.AutoCollect = false
    print("[AutoCollect] Berhenti. Diambil: " .. totalCollected .. " | Deposit: " .. totalDeposited)
end

-- ════════════════════════════════════════
--  UI BUILDER
-- ════════════════════════════════════════
local function createBtn(name, text, posY, parent, color)
    local btn = Instance.new("TextButton")
    btn.Name             = name
    btn.Size             = UDim2.new(1, -20, 0, 28)
    btn.Position         = UDim2.new(0, 10, 0, posY)
    btn.BackgroundColor3 = color
    btn.TextColor3       = Color3.fromRGB(255, 255, 255)
    btn.TextSize         = 12
    btn.Font             = Enum.Font.GothamBold
    btn.Text             = text
    btn.BorderSizePixel  = 0
    btn.Parent           = parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
    return btn
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "ESP_UI"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = guiParent

local panel = Instance.new("Frame")
panel.Name             = "Panel"
panel.Size             = UDim2.new(0, 240, 0, 285)
panel.Position         = UDim2.new(0, 20, 0.5, -142)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
panel.BorderSizePixel  = 0
panel.Active           = true
panel.Parent           = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(120, 120, 140)
stroke.Thickness = 1.5; stroke.Transparency = 0.4
stroke.Parent = panel

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Name             = "TitleBar"
titleBar.Size             = UDim2.new(1, 0, 0, 32)
titleBar.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
titleBar.BorderSizePixel  = 0
titleBar.Parent           = panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local tbPatch = Instance.new("Frame")
tbPatch.Size = UDim2.new(1, 0, 0, 10); tbPatch.Position = UDim2.new(0, 0, 1, -10)
tbPatch.BackgroundColor3 = Color3.fromRGB(28, 28, 35)
tbPatch.BorderSizePixel = 0; tbPatch.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -40, 1, 0); titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
titleLabel.TextSize = 13; titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "⬡  ESP Control Panel"
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 26, 0, 26); minBtn.Position = UDim2.new(1, -30, 0, 3)
minBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
minBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
minBtn.TextSize = 14; minBtn.Font = Enum.Font.GothamBold
minBtn.Text = "−"; minBtn.BorderSizePixel = 0
minBtn.Parent = titleBar
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

-- Shortcut hint
local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -20, 0, 42)
infoLabel.Position = UDim2.new(0, 10, 0, 36)
infoLabel.BackgroundTransparency = 1
infoLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
infoLabel.TextSize = 10; infoLabel.Font = Enum.Font.Gotham
infoLabel.Text = "F5: Monster  F6: Loot & Item\nF7: NPC  F8: Hide UI  F9: Auto Collect"
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.Parent = panel

-- Buttons
local btnMonster = createBtn("BtnMonster", "MONSTER ESP: ON",    82, panel, CONFIG.Monster.Color)
local btnLoot    = createBtn("BtnLoot",    "LOOT & ITEM ESP: ON",116, panel, CONFIG.Loot.Color)
local btnNPC     = createBtn("BtnNPC",     "NPC ESP: ON",        150, panel, CONFIG.NPC.Color)
local btnCollect = createBtn("BtnCollect", "AUTO COLLECT: OFF",  184, panel, Color3.fromRGB(60, 60, 70))
local acOnColor  = Color3.fromRGB(255, 150, 50)

-- Auto collect status label
local acStatusLabel = Instance.new("TextLabel")
acStatusLabel.Size = UDim2.new(1, -20, 0, 30)
acStatusLabel.Position = UDim2.new(0, 10, 0, 218)
acStatusLabel.BackgroundTransparency = 1
acStatusLabel.TextColor3 = Color3.fromRGB(120, 120, 140)
acStatusLabel.TextSize = 10
acStatusLabel.Font = Enum.Font.Gotham
acStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
acStatusLabel.TextYAlignment = Enum.TextYAlignment.Top
acStatusLabel.TextWrapped = true
acStatusLabel.Text = "● Idle"
acStatusLabel.Parent = panel

-- Divider
local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -20, 0, 1)
divider.Position = UDim2.new(0, 10, 0, 214)
divider.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
divider.BorderSizePixel = 0
divider.Parent = panel

-- ════════════════════════════════════════
--  UI LOGIC
-- ════════════════════════════════════════
local function animBtn(btn, posY)
    TweenService:Create(btn, TweenInfo.new(0.08),
        {Size = UDim2.new(1, -28, 0, 24), Position = UDim2.new(0, 14, 0, posY + 2)}):Play()
    task.wait(0.08)
    TweenService:Create(btn, TweenInfo.new(0.1),
        {Size = UDim2.new(1, -20, 0, 28), Position = UDim2.new(0, 10, 0, posY)}):Play()
end

local function updateUI()
    btnMonster.Text             = "MONSTER ESP: "    .. (State.Monster and "ON" or "OFF")
    btnMonster.BackgroundColor3 = State.Monster and CONFIG.Monster.Color or Color3.fromRGB(60,60,70)
    btnLoot.Text                = "LOOT & ITEM ESP: " .. (State.Loot and "ON" or "OFF")
    btnLoot.BackgroundColor3    = State.Loot    and CONFIG.Loot.Color    or Color3.fromRGB(60,60,70)
    btnNPC.Text                 = "NPC ESP: "        .. (State.NPC and "ON" or "OFF")
    btnNPC.BackgroundColor3     = State.NPC     and CONFIG.NPC.Color     or Color3.fromRGB(60,60,70)
    btnCollect.Text             = "AUTO COLLECT: "   .. (State.AutoCollect and "ON" or "OFF")
    btnCollect.BackgroundColor3 = State.AutoCollect and acOnColor or Color3.fromRGB(60,60,70)
    panel.Visible               = State.UI

    -- Update status AC
    if State.AutoCollect then
        acStatusLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
        acStatusLabel.Text = "⟳ " .. acStatus
    else
        acStatusLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
        acStatusLabel.Text = "● " .. acStatus
    end
end

local function toggleAutoCollect()
    State.AutoCollect = not State.AutoCollect
    updateUI()
    if State.AutoCollect then
        acStatus = "Memulai..."
        task.spawn(function()
            triggerAutoCollect()
            updateUI()
        end)
    else
        acStatus = "Dibatalkan"
    end
end

-- Button events
btnMonster.MouseButton1Click:Connect(function()
    State.Monster = not State.Monster; updateUI(); animBtn(btnMonster, 82) end)
btnLoot.MouseButton1Click:Connect(function()
    State.Loot = not State.Loot; updateUI(); animBtn(btnLoot, 116) end)
btnNPC.MouseButton1Click:Connect(function()
    State.NPC = not State.NPC; updateUI(); animBtn(btnNPC, 150) end)
btnCollect.MouseButton1Click:Connect(function()
    toggleAutoCollect(); animBtn(btnCollect, 184) end)
minBtn.MouseButton1Click:Connect(function()
    State.UI = not State.UI; updateUI() end)

-- Drag
local drag, dragStart, startPos = false, nil, nil
titleBar.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then
        drag = true; dragStart = inp.Position; startPos = panel.Position
    end
end)
table.insert(connections, UserInputService.InputChanged:Connect(function(inp)
    if drag and (inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch) then
        local d = inp.Position - dragStart
        panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                   startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end))
table.insert(connections, UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
    or inp.UserInputType == Enum.UserInputType.Touch then drag = false end
end))

-- Keyboard shortcuts
table.insert(connections, UserInputService.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if     inp.KeyCode == Enum.KeyCode.F5 then State.Monster = not State.Monster; updateUI()
    elseif inp.KeyCode == Enum.KeyCode.F6 then State.Loot    = not State.Loot;    updateUI()
    elseif inp.KeyCode == Enum.KeyCode.F7 then State.NPC     = not State.NPC;     updateUI()
    elseif inp.KeyCode == Enum.KeyCode.F8 then State.UI      = not State.UI;      updateUI()
    elseif inp.KeyCode == Enum.KeyCode.F9 then toggleAutoCollect()
    end
end))

-- ════════════════════════════════════════
--  MAIN LOOPS
-- ════════════════════════════════════════
table.insert(connections, RunService.Heartbeat:Connect(function()
    pcall(updateESP)
end))

-- UI status update (0.2s)
local lastUIUpdate = 0
table.insert(connections, RunService.RenderStepped:Connect(function()
    local now = tick()
    if now - lastUIUpdate >= 0.2 then
        pcall(updateUI)
        lastUIUpdate = now
    end
end))

-- ════════════════════════════════════════
--  CLEANUP
-- ════════════════════════════════════════
_G.ESP_CLEANUP = function()
    State.AutoCollect = false
    for _, conn in ipairs(connections) do
        pcall(function() conn:Disconnect() end)
    end
    connections = {}
    for _, hl in ipairs(highlightPool) do
        pcall(function() hl:Destroy() end)
    end
    highlightPool = {}
    if screenGui then pcall(function() screenGui:Destroy() end) end
    _G.ESP_RUNNING = false
    print("[ESP] Dihentikan dan dibersihkan.")
end

-- ════════════════════════════════════════
--  DEBUG
-- ════════════════════════════════════════
_G.ESP_DEBUG = function()
    print("══════════ ESP DEBUG v7 ══════════")
    local wf = getWorldFolder()
    print("World folder  : " .. (wf and wf:GetFullName() .. " (" .. folderCount(wf) .. " loots)" or "TIDAK DITEMUKAN"))
    local pf = getPlayerFolder()
    print("Player folder : " .. (pf and pf:GetFullName() .. " (" .. folderCount(pf) .. " items)" or "TIDAK DITEMUKAN"))
    local fg = getFoodGathering()
    print("FoodGathering : " .. (fg and fg:GetFullName() or "TIDAK DITEMUKAN (cek AC_ElevatorName & AC_GatherPart)"))
    print("AC Status     : " .. acStatus)
    print("══════════════════════════════════")
end

-- ════════════════════════════════════════
--  INIT
-- ════════════════════════════════════════
updateUI()
print("[ESP v7.0.0 - Deadly Delivery] Aktif!")
print("  F5/F6/F7 = ESP Toggle | F8 = UI | F9 = Auto Collect")
print("  _G.ESP_CLEANUP()  _G.ESP_DEBUG()")
