-- ================================================================
--   ESP Framework Core
--   Version : 5.1.0 (Pool System Fix - Anti Limit)
-- ================================================================

if _G.ESP_RUNNING then
    if _G.ESP_CLEANUP then pcall(_G.ESP_CLEANUP) end
end
_G.ESP_RUNNING = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    Monster = { Paths = {{"GameSystem", "Monsters"}}, Color = Color3.fromRGB(255, 50, 50) },
    Loot = { Paths = {{"GameSystem", "Loots", "World"}, {"GameSystem", "InteractiveItem"}}, Color = Color3.fromRGB(50, 255, 50) },
    NPC = { Paths = {{"GameSystem", "NPCModels"}}, Color = Color3.fromRGB(50, 100, 255) }
}

local state = { Monster = true, Loot = true, NPC = true, UI = true }
local MAX_DISTANCE = 1500
local MAX_HIGHLIGHTS = 30
local pool = {}
local connections = {}

local function getGuiParent()
    local ok, res = pcall(function() return CoreGui end)
    return (ok and res) or LocalPlayer:WaitForChild("PlayerGui")
end

local guiParent = getGuiParent()

for i = 1, MAX_HIGHLIGHTS do
    local h = Instance.new("Highlight")
    h.Name = "ESP_HL_" .. i
    h.FillTransparency = 0.5
    h.OutlineTransparency = 0
    h.Enabled = false
    h.Parent = guiParent
    table.insert(pool, h)
end

local function getPath(p)
    local c = workspace
    for _, n in ipairs(p) do
        c = c:FindFirstChild(n)
        if not c then return nil end
    end
    return c
end

local function getPart(m)
    if not m then return nil end
    if m:IsA("BasePart") then return m end
    if m.PrimaryPart then return m.PrimaryPart end
    return m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart")
end

local function update()
    local targets = {}
    local camPos = Camera.CFrame.Position

    for k, v in pairs(CONFIG) do
        if state[k] then
            for _, p in ipairs(v.Paths) do
                local f = getPath(p)
                if f then
                    for _, obj in ipairs(f:GetChildren()) do
                        local part = getPart(obj)
                        if part then
                            local d = (part.Position - camPos).Magnitude
                            if d <= MAX_DISTANCE then
                                table.insert(targets, { obj = obj, dist = d, col = v.Color })
                            end
                        end
                    end
                end
            end
        end
    end

    table.sort(targets, function(a, b) return a.dist < b.dist end)

    for i, hl in ipairs(pool) do
        local t = targets[i]
        if t then
            if hl.Adornee ~= t.obj then hl.Adornee = t.obj end
            if hl.FillColor ~= t.col then
                hl.FillColor = t.col
                hl.OutlineColor = t.col
            end
            if not hl.Enabled then hl.Enabled = true end
        else
            if hl.Adornee then hl.Adornee = nil end
            if hl.Enabled then hl.Enabled = false end
        end
    end
end

local function createBtn(n, t, pos, p, c)
    local b = Instance.new("TextButton")
    b.Name, b.Size, b.Position, b.BackgroundColor3, b.TextColor3, b.TextSize, b.Font, b.Text, b.BorderSizePixel, b.Parent = n, UDim2.new(1, -20, 0, 28), pos, c, Color3.fromRGB(255,255,255), 12, Enum.Font.GothamBold, t, 0, p
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
    return b
end

local sg = Instance.new("ScreenGui")
sg.Name, sg.ResetOnSpawn, sg.ZIndexBehavior, sg.Parent = "ESP_UI", false, Enum.ZIndexBehavior.Sibling, guiParent

local pnl = Instance.new("Frame")
pnl.Name, pnl.Size, pnl.Position, pnl.BackgroundColor3, pnl.BorderSizePixel, pnl.Active, pnl.Parent = "Panel", UDim2.new(0, 240, 0, 190), UDim2.new(0, 20, 0.5, -95), Color3.fromRGB(18, 18, 24), 0, true, sg
Instance.new("UICorner", pnl).CornerRadius = UDim.new(0, 10)

local str = Instance.new("UIStroke")
str.Color, str.Thickness, str.Transparency, str.Parent = Color3.fromRGB(120, 120, 140), 1.5, 0.4, pnl

local tb = Instance.new("Frame")
tb.Name, tb.Size, tb.BackgroundColor3, tb.BorderSizePixel, tb.Parent = "TitleBar", UDim2.new(1, 0, 0, 32), Color3.fromRGB(28, 28, 35), 0, pnl
Instance.new("UICorner", tb).CornerRadius = UDim.new(0, 10)

local tbp = Instance.new("Frame")
tbp.Size, tbp.Position, tbp.BackgroundColor3, tbp.BorderSizePixel, tbp.Parent = UDim2.new(1, 0, 0, 10), UDim2.new(0, 0, 1, -10), Color3.fromRGB(28, 28, 35), 0, tb

local tl = Instance.new("TextLabel")
tl.Size, tl.Position, tl.BackgroundTransparency, tl.TextColor3, tl.TextSize, tl.Font, tl.Text, tl.TextXAlignment, tl.Parent = UDim2.new(1, -40, 1, 0), UDim2.new(0, 12, 0, 0), 1, Color3.fromRGB(220, 220, 230), 13, Enum.Font.GothamBold, "⬡  ESP Control Panel", Enum.TextXAlignment.Left, tb

local mb = Instance.new("TextButton")
mb.Size, mb.Position, mb.BackgroundColor3, mb.TextColor3, mb.TextSize, mb.Font, mb.Text, mb.BorderSizePixel, mb.Parent = UDim2.new(0, 26, 0, 26), UDim2.new(1, -30, 0, 3), Color3.fromRGB(220, 60, 60), Color3.fromRGB(255, 255, 255), 14, Enum.Font.GothamBold, "−", 0, tb
Instance.new("UICorner", mb).CornerRadius = UDim.new(0, 6)

local il = Instance.new("TextLabel")
il.Size, il.Position, il.BackgroundTransparency, il.TextColor3, il.TextSize, il.Font, il.Text, il.TextXAlignment, il.Parent = UDim2.new(1, -20, 0, 34), UDim2.new(0, 10, 0, 36), 1, Color3.fromRGB(150, 150, 160), 10, Enum.Font.Gotham, "F5: Monster | F6: Loot (Rampasan)\nF7: NPC | F8: Hide (Sembunyikan) UI", Enum.TextXAlignment.Left, pnl

local bm = createBtn("ToggleMonster", "MONSTER: ON", UDim2.new(0, 10, 0, 76), pnl, CONFIG.Monster.Color)
local bl = createBtn("ToggleLoot", "LOOT & ITEM: ON", UDim2.new(0, 10, 0, 110), pnl, CONFIG.Loot.Color)
local bn = createBtn("ToggleNPC", "NPC: ON", UDim2.new(0, 10, 0, 144), pnl, CONFIG.NPC.Color)

local function animBtn(b, sz, ps)
    TweenService:Create(b, TweenInfo.new(0.08), {Size = sz, Position = ps}):Play()
end

local function updUI()
    bm.Text = "MONSTER ESP: " .. (state.Monster and "ON" or "OFF")
    bm.BackgroundColor3 = state.Monster and CONFIG.Monster.Color or Color3.fromRGB(60, 60, 70)
    bl.Text = "LOOT & ITEM ESP: " .. (state.Loot and "ON" or "OFF")
    bl.BackgroundColor3 = state.Loot and CONFIG.Loot.Color or Color3.fromRGB(60, 60, 70)
    bn.Text = "NPC ESP: " .. (state.NPC and "ON" or "OFF")
    bn.BackgroundColor3 = state.NPC and CONFIG.NPC.Color or Color3.fromRGB(60, 60, 70)
    pnl.Visible = state.UI
end

bm.MouseButton1Click:Connect(function() state.Monster = not state.Monster; updUI(); animBtn(bm, UDim2.new(1, -28, 0, 24), UDim2.new(0, 14, 0, 78)); task.wait(0.08); animBtn(bm, UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 76)) end)
bl.MouseButton1Click:Connect(function() state.Loot = not state.Loot; updUI(); animBtn(bl, UDim2.new(1, -28, 0, 24), UDim2.new(0, 14, 0, 112)); task.wait(0.08); animBtn(bl, UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 110)) end)
bn.MouseButton1Click:Connect(function() state.NPC = not state.NPC; updUI(); animBtn(bn, UDim2.new(1, -28, 0, 24), UDim2.new(0, 14, 0, 146)); task.wait(0.08); animBtn(bn, UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 144)) end)
mb.MouseButton1Click:Connect(function() state.UI = not state.UI; updUI() end)

local drag, dragStart, startPos = false, nil, nil
tb.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag, dragStart, startPos = true, i.Position, pnl.Position end end)
table.insert(connections, UserInputService.InputChanged:Connect(function(i) if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then local d = i.Position - dragStart; pnl.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end end))
table.insert(connections, UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then drag = false end end))

table.insert(connections, UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.F5 then state.Monster = not state.Monster; updUI()
    elseif i.KeyCode == Enum.KeyCode.F6 then state.Loot = not state.Loot; updUI()
    elseif i.KeyCode == Enum.KeyCode.F7 then state.NPC = not state.NPC; updUI()
    elseif i.KeyCode == Enum.KeyCode.F8 then state.UI = not state.UI; updUI() end
end))

table.insert(connections, RunService.RenderStepped:Connect(update))

_G.ESP_CLEANUP = function()
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    connections = {}
    for _, h in ipairs(pool) do pcall(function() h:Destroy() end) end
    pool = {}
    if sg then pcall(function() sg:Destroy() end) end
    _G.ESP_RUNNING = false
end