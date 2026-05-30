-- ================================================================
--   ESP Framework Core & Auto-Collect
--   Version : 6.1.0 (Auto-Collect FoodGathering Path Update)
-- ================================================================

if _G.ESP_RUNNING then
    if _G.ESP_CLEANUP then pcall(_G.ESP_CLEANUP) end
end
_G.ESP_RUNNING = true

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    Monster = { Paths = {{"GameSystem", "Monsters"}}, Color = Color3.fromRGB(255, 50, 50) },
    Loot = { Paths = {{"GameSystem", "Loots", "World"}, {"GameSystem", "InteractiveItem"}}, Color = Color3.fromRGB(50, 255, 50) },
    NPC = { Paths = {{"GameSystem", "NPCModels"}}, Color = Color3.fromRGB(50, 100, 255) },
    MaxBackpackItems = 50
}

local State = { Monster = true, Loot = true, NPC = true, AutoCollect = false, UI = true }
local MAX_DISTANCE = 1500
local MAX_HIGHLIGHTS = 30
local highlightPool = {}
local connections = {}

local function getGuiParent()
    local ok, res = pcall(function() return CoreGui end)
    return (ok and res) or LocalPlayer:WaitForChild("PlayerGui")
end

local guiParent = getGuiParent()

for i = 1, MAX_HIGHLIGHTS do
    local hl = Instance.new("Highlight")
    hl.Name = "ESP_Highlight_" .. i
    hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0
    hl.Enabled = false
    hl.Parent = guiParent
    table.insert(highlightPool, hl)
end

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
    return model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart")
end

local function isBackpackFull()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        return #backpack:GetChildren() >= CONFIG.MaxBackpackItems
    end
    return false
end

local function triggerAutoCollect()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then 
        State.AutoCollect = false
        return 
    end

    local initialCFrame = hrp.CFrame
    local elevatorFolder = workspace:FindFirstChild("电梯")

    if elevatorFolder then
        for _, loot in ipairs(elevatorFolder:GetChildren()) do
            if not State.AutoCollect then break end
            
            if loot.Name == "FoodGathering" or loot:FindFirstChild("FoodGathering") then
                local pivot = loot:GetPivot()
                
                hrp.CFrame = pivot
                task.wait(0.3) 
                
                for _, prompt in ipairs(loot:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") then
                        fireproximityprompt(prompt)
                        task.wait(0.2)
                    end
                end

                task.wait(0.2)

                if isBackpackFull() then
                    break
                end
            end
        end
    end

    if hrp then
        hrp.CFrame = initialCFrame
    end
    State.AutoCollect = false
end

local function updateESP()
    local cam = workspace.CurrentCamera
    if not cam then return end
    
    local camPos = cam.CFrame.Position
    local targets = {}

    for key, configData in pairs(CONFIG) do
        if State[key] and type(configData) == "table" and configData.Paths then
            for _, path in ipairs(configData.Paths) do
                local folder = getPath(path)
                if folder then
                    for _, obj in ipairs(folder:GetChildren()) do
                        pcall(function()
                            local part = getPart(obj)
                            if part then
                                local dist = (part.Position - camPos).Magnitude
                                if dist <= MAX_DISTANCE then
                                    table.insert(targets, { obj = obj, dist = dist, color = configData.Color })
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
                    hl.FillColor = target.color
                    hl.OutlineColor = target.color
                end
                if not hl.Enabled then hl.Enabled = true end
            else
                if hl.Adornee then hl.Adornee = nil end
                if hl.Enabled then hl.Enabled = false end
            end
        end)
    end
end

local function createButton(name, text, pos, parent, color)
    local btn = Instance.new("TextButton")
    btn.Name, btn.Size, btn.Position, btn.BackgroundColor3, btn.TextColor3, btn.TextSize, btn.Font, btn.Text, btn.BorderSizePixel, btn.Parent = name, UDim2.new(1, -20, 0, 28), pos, color, Color3.fromRGB(255,255,255), 12, Enum.Font.GothamBold, text, 0, parent
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 7)
    return btn
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name, screenGui.ResetOnSpawn, screenGui.ZIndexBehavior, screenGui.Parent = "ESP_UI", false, Enum.ZIndexBehavior.Sibling, guiParent

local panel = Instance.new("Frame")
panel.Name, panel.Size, panel.Position, panel.BackgroundColor3, panel.BorderSizePixel, panel.Active, panel.Parent = "Panel", UDim2.new(0, 240, 0, 255), UDim2.new(0, 20, 0.5, -127), Color3.fromRGB(18, 18, 24), 0, true, screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local stroke = Instance.new("UIStroke")
stroke.Color, stroke.Thickness, stroke.Transparency, stroke.Parent = Color3.fromRGB(120, 120, 140), 1.5, 0.4, panel

local titleBar = Instance.new("Frame")
titleBar.Name, titleBar.Size, titleBar.BackgroundColor3, titleBar.BorderSizePixel, titleBar.Parent = "TitleBar", UDim2.new(1, 0, 0, 32), Color3.fromRGB(28, 28, 35), 0, panel
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)

local patch = Instance.new("Frame")
patch.Size, patch.Position, patch.BackgroundColor3, patch.BorderSizePixel, patch.Parent = UDim2.new(1, 0, 0, 10), UDim2.new(0, 0, 1, -10), Color3.fromRGB(28, 28, 35), 0, titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size, titleLabel.Position, titleLabel.BackgroundTransparency, titleLabel.TextColor3, titleLabel.TextSize, titleLabel.Font, titleLabel.Text, titleLabel.TextXAlignment, titleLabel.Parent = UDim2.new(1, -40, 1, 0), UDim2.new(0, 12, 0, 0), 1, Color3.fromRGB(220, 220, 230), 13, Enum.Font.GothamBold, "⬡  ESP Control Panel", Enum.TextXAlignment.Left, titleBar

local minBtn = Instance.new("TextButton")
minBtn.Size, minBtn.Position, minBtn.BackgroundColor3, minBtn.TextColor3, minBtn.TextSize, minBtn.Font, minBtn.Text, minBtn.BorderSizePixel, minBtn.Parent = UDim2.new(0, 26, 0, 26), UDim2.new(1, -30, 0, 3), Color3.fromRGB(220, 60, 60), Color3.fromRGB(255, 255, 255), 14, Enum.Font.GothamBold, "−", 0, titleBar
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

local infoLabel = Instance.new("TextLabel")
infoLabel.Size, infoLabel.Position, infoLabel.BackgroundTransparency, infoLabel.TextColor3, infoLabel.TextSize, infoLabel.Font, infoLabel.Text, infoLabel.TextXAlignment, infoLabel.Parent = UDim2.new(1, -20, 0, 48), UDim2.new(0, 10, 0, 36), 1, Color3.fromRGB(150, 150, 160), 10, Enum.Font.Gotham, "F5: Monster | F6: Loot / Item\nF7: NPC | F8: Hide UI\nF9: Auto Collect", Enum.TextXAlignment.Left, panel

local btnMonster = createButton("ToggleMonster", "MONSTER: ON", UDim2.new(0, 10, 0, 88), panel, CONFIG.Monster.Color)
local btnLoot = createButton("ToggleLoot", "LOOT & ITEM: ON", UDim2.new(0, 10, 0, 122), panel, CONFIG.Loot.Color)
local btnNPC = createButton("ToggleNPC", "NPC: ON", UDim2.new(0, 10, 0, 156), panel, CONFIG.NPC.Color)
local btnCollect = createButton("ToggleCollect", "AUTO COLLECT: OFF", UDim2.new(0, 10, 0, 190), panel, Color3.fromRGB(60, 60, 70))
local btnCollectColor = Color3.fromRGB(255, 150, 50)

local function animateButton(btn, size, pos)
    TweenService:Create(btn, TweenInfo.new(0.08), {Size = size, Position = pos}):Play()
end

local function updateUI()
    btnMonster.Text = "MONSTER ESP: " .. (State.Monster and "ON" or "OFF")
    btnMonster.BackgroundColor3 = State.Monster and CONFIG.Monster.Color or Color3.fromRGB(60, 60, 70)
    btnLoot.Text = "LOOT & ITEM ESP: " .. (State.Loot and "ON" or "OFF")
    btnLoot.BackgroundColor3 = State.Loot and CONFIG.Loot.Color or Color3.fromRGB(60, 60, 70)
    btnNPC.Text = "NPC ESP: " .. (State.NPC and "ON" or "OFF")
    btnNPC.BackgroundColor3 = State.NPC and CONFIG.NPC.Color or Color3.fromRGB(60, 60, 70)
    
    btnCollect.Text = "AUTO COLLECT: " .. (State.AutoCollect and "ON" or "OFF")
    btnCollect.BackgroundColor3 = State.AutoCollect and btnCollectColor or Color3.fromRGB(60, 60, 70)
    
    panel.Visible = State.UI
end

local function toggleAutoCollect()
    State.AutoCollect = not State.AutoCollect
    updateUI()
    if State.AutoCollect then
        task.spawn(function()
            triggerAutoCollect()
            updateUI() 
        end)
    end
end

btnMonster.MouseButton1Click:Connect(function() State.Monster = not State.Monster; updateUI(); animateButton(btnMonster, UDim2.new(1, -28, 0, 24), UDim2.new(0, 14, 0, 90)); task.wait(0.08); animateButton(btnMonster, UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 88)) end)
btnLoot.MouseButton1Click:Connect(function() State.Loot = not State.Loot; updateUI(); animateButton(btnLoot, UDim2.new(1, -28, 0, 24), UDim2.new(0, 14, 0, 124)); task.wait(0.08); animateButton(btnLoot, UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 122)) end)
btnNPC.MouseButton1Click:Connect(function() State.NPC = not State.NPC; updateUI(); animateButton(btnNPC, UDim2.new(1, -28, 0, 24), UDim2.new(0, 14, 0, 158)); task.wait(0.08); animateButton(btnNPC, UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 156)) end)
btnCollect.MouseButton1Click:Connect(function() toggleAutoCollect(); animateButton(btnCollect, UDim2.new(1, -28, 0, 24), UDim2.new(0, 14, 0, 192)); task.wait(0.08); animateButton(btnCollect, UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 190)) end)
minBtn.MouseButton1Click:Connect(function() State.UI = not State.UI; updateUI() end)

local drag, dragStart, startPos = false, nil, nil
titleBar.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then drag, dragStart, startPos = true, input.Position, panel.Position end end)
table.insert(connections, UserInputService.InputChanged:Connect(function(input) if drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then local d = input.Position - dragStart; panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end end))
table.insert(connections, UserInputService.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then drag = false end end))

table.insert(connections, UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.F5 then State.Monster = not State.Monster; updateUI()
    elseif input.KeyCode == Enum.KeyCode.F6 then State.Loot = not State.Loot; updateUI()
    elseif input.KeyCode == Enum.KeyCode.F7 then State.NPC = not State.NPC; updateUI()
    elseif input.KeyCode == Enum.KeyCode.F8 then State.UI = not State.UI; updateUI()
    elseif input.KeyCode == Enum.KeyCode.F9 then toggleAutoCollect() end
end))

table.insert(connections, RunService.Heartbeat:Connect(function()
    updateESP()
end))

_G.ESP_CLEANUP = function()
    for _, conn in ipairs(connections) do pcall(function() conn:Disconnect() end) end
    connections = {}
    for _, hl in ipairs(highlightPool) do pcall(function() hl:Destroy() end) end
    highlightPool = {}
    if screenGui then pcall(function() screenGui:Destroy() end) end
    _G.ESP_RUNNING = false
end
