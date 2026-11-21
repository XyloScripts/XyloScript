-- XYLO SCRIPTS - MINIMALIST KEY SYSTEM AND MAIN MENU
local API_URL, GET_KEY_URL, DISCORD_URL = "https://xylo-efhi.vercel.app/api/validate", "https://xylo-efhi.vercel.app", "https://discord.gg/bSe3Ht89Ef"
local SCRIPT_URL = "https://raw.githubusercontent.com/XyloScripts/XyloScript/main/main.lua"
local TweenService, HttpService, CoreGui, Players, UserInputService, RbxAnalyticsService, Lighting, RunService, VirtualUser = 
    game:GetService("TweenService"), game:GetService("HttpService"), game:GetService("CoreGui"), game:GetService("Players"), game:GetService("UserInputService"), game:GetService("RbxAnalyticsService"), game:GetService("Lighting"), game:GetService("RunService"), game:GetService("VirtualUser")
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
local copyToClipboard = setclipboard or toclipboard or function() end
local hwid = (RbxAnalyticsService and RbxAnalyticsService:GetClientId()) or tostring(Players.LocalPlayer.UserId)
local localPlayer = Players.LocalPlayer
-- Queue reload on teleport only (naturally does not fire on homepage joins)
if queue_on_teleport then
    queue_on_teleport('loadstring(game:HttpGet("' .. SCRIPT_URL .. '"))()')
end
-- Persist key and expiry across teleports via getgenv
if getgenv and not getgenv().XyloSessionStart then
    getgenv().XyloSessionStart = tick()
end
local SCRIPT_START_TIME = (getgenv and getgenv().XyloSessionStart) or tick()
-- Detect teleport reload
local isTeleportReload = false
local savedExpiryTime = nil
local savedKeyValue = nil
if getgenv and getgenv().XyloSavedKey and getgenv().XyloExpiry then
    isTeleportReload = true
    savedKeyValue = getgenv().XyloSavedKey
    savedExpiryTime = getgenv().XyloExpiry
end
-- Cleanup previous instances
for _, name in ipairs({"XyloKeySystemUI", "XyloMainMenuUI", "XyloExpiredPopup", "XyloCloseBlur"}) do
    local found = CoreGui:FindFirstChild(name) or Lighting:FindFirstChild(name)
    if found then found:Destroy() end
end
local function create(class, props)
    local inst = Instance.new(class)
    for k, v in pairs(props) do inst[k] = v end
    return inst
end
local function clearTeleportState()
    if getgenv then
        getgenv().XyloSavedKey = nil
        getgenv().XyloExpiry = nil
        getgenv().XyloSessionStart = nil
    end
end
local function deleteSavedKey()
    pcall(function()
        if delfile and isfile and isfile("xylo_key.txt") then delfile("xylo_key.txt")
        elseif writefile then writefile("xylo_key.txt", "") end
    end)
end
local function requestKeyDeletion(keyToDelete)
    if not keyToDelete or keyToDelete == "" then return end
    task.spawn(function()
        pcall(function()
            httpRequest({Url = API_URL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({key = keyToDelete, action = "delete_expired", hwid = hwid})})
        end)
    end)
end

-- TIMESTAMP AND SUPABASE EXPIRY PARSER

local function parseTimestamp(val)
    if not val then return nil end
    if type(val) == "number" then
        if val > 1e11 then return math.floor(val / 1000) end
        return math.floor(val)
    end
    if type(val) == "string" then
        local num = tonumber(val)
        if num then
            if num > 1e11 then return math.floor(num / 1000) end
            return math.floor(num)
        end
        local y, m, d, h, min, s = val:match("(%d+)-(%d+)-(%d+)[T ](%d+):(%d+):?(%d*)")
        if y and m and d and h and min then
            s = tonumber(s) or 0
            local epoch = os.time({year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = tonumber(h), min = tonumber(min), sec = s, isdst = false})
            local nowUtc = os.time(os.date("!*t"))
            local nowLocal = os.time()
            return epoch + (nowLocal - nowUtc)
        end
    end
    return nil
end
local activeSession = true

-- DRAGGING SYSTEM

local function makeDraggable(dragHandle, targetFrame)
    local moveConn, endConn
    dragHandle.InputBegan:Connect(function(input)
        if not activeSession then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if moveConn then moveConn:Disconnect() end
            if endConn then endConn:Disconnect() end
            local dragStart = input.Position
            local startPos = targetFrame.Position
            moveConn = UserInputService.InputChanged:Connect(function(moveInput)
                if not activeSession then return end
                if moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch then
                    local delta = moveInput.Position - dragStart
                    targetFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
                end
            end)
            endConn = UserInputService.InputEnded:Connect(function(endInput)
                if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
                    if moveConn then moveConn:Disconnect(); moveConn = nil end
                    if endConn then endConn:Disconnect(); endConn = nil end
                end
            end)
        end
    end)
end

-- XYLO X LOGO

local function createXLogo(size, parent, slitGapOverride)
    local container = create("Frame", {Name = "XyloLogo", Size = UDim2.new(0, size, 0, size), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = parent})
    local xHeight = math.round(size * 0.84)
    local clipFrame = create("CanvasGroup", {Name = "ClipFrame", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, math.round(size * 1.6), 0, xHeight), BackgroundTransparency = 1, BorderSizePixel = 0, GroupTransparency = 0, Parent = container})
    local barThickness = math.clamp(math.round(size * 0.22), 2, 80)
    local slitGap = slitGapOverride or math.clamp(math.round(size * 0.18), 3, 24)
    local totalDiag = math.round(size * 1.6)
    create("Frame", {Name = "MainSlash", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, barThickness, 0, totalDiag), Rotation = -45, BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, Parent = clipFrame})
    local armBottomLen = math.round(size * 0.82)
    local rBottom = -math.round(armBottomLen * 0.36)
    create("Frame", {Name = "ArmBottomLeft", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.round(rBottom * 0.7071), 0.5, -math.round(rBottom * 0.7071)), Size = UDim2.new(0, barThickness, 0, armBottomLen), Rotation = 45, BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, Parent = clipFrame})
    local rStart = (barThickness * 0.5) + slitGap
    local rEnd = math.round(size * 0.80)
    local armTopLen = math.max(2, rEnd - rStart)
    local rTop = (rStart + rEnd) * 0.5
    create("Frame", {Name = "ArmTopRight", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.round(rTop * 0.7071), 0.5, -math.round(rTop * 0.7071)), Size = UDim2.new(0, barThickness, 0, armTopLen), Rotation = 45, BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, Parent = clipFrame})
    return container, clipFrame
end
local function createHouseIcon(size, parent, initialColor)
    local color = initialColor or Color3.fromRGB(240, 240, 245)
    local container = create("CanvasGroup", {Name = "HouseIcon", Size = UDim2.new(0, size, 0, size), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = parent})
    local roof = create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.36, 0), Size = UDim2.new(0, math.round(size * 0.65), 0, math.round(size * 0.65)), Rotation = 45, BackgroundColor3 = color, BorderSizePixel = 0, Parent = container})
    create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = roof})
    local body = create("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.9, 0), Size = UDim2.new(0, math.round(size * 0.62), 0, math.round(size * 0.5)), BackgroundColor3 = color, BorderSizePixel = 0, Parent = container})
    create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = body})
    local door = create("Frame", {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(0, math.round(size * 0.22), 0, math.round(size * 0.28)), BackgroundColor3 = Color3.fromRGB(13, 13, 16), BorderSizePixel = 0, Parent = body})
    create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = door})
    return container, {roof, body}
end
local function createSettingsIcon(size, parent, initialColor)
    local color = initialColor or Color3.fromRGB(130, 130, 140)
    local container = create("Frame", {Name = "SettingsLinesIcon", Size = UDim2.new(0, size, 0, size), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = parent})
    local parts = {}
    local lineData = {{y = 0.22, knobX = 0.30}, {y = 0.50, knobX = 0.70}, {y = 0.78, knobX = 0.40}}
    for _, d in ipairs(lineData) do
        local line = create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, d.y, 0), Size = UDim2.new(0, math.round(size * 0.88), 0, 2), BackgroundColor3 = color, BorderSizePixel = 0, Parent = container})
        create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = line})
        table.insert(parts, line)
        local pip = create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(d.knobX, 0, d.y, 0), Size = UDim2.new(0, 4, 0, 6), BackgroundColor3 = color, BorderSizePixel = 0, Parent = container})
        create("UICorner", {CornerRadius = UDim.new(0, 2), Parent = pip})
        table.insert(parts, pip)
    end
    return container, parts
end
local function createClockIcon(size, parent, color)
    local clr = color or Color3.fromRGB(150, 150, 165)
    local c = create("Frame", {Name = "ClockIcon", Size = UDim2.new(0, size, 0, size), BackgroundTransparency = 1, BorderSizePixel = 0, Parent = parent})
    local ring = create("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Parent = c})
    create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = ring})
    create("UIStroke", {Thickness = 1.4, Color = clr, Parent = ring})
    local pin = create("Frame", {Name = "Pin", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 3, 0, 3), BackgroundColor3 = clr, BorderSizePixel = 0, ZIndex = 5, Parent = c})
    create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = pin})
    local minPivot = create("Frame", {Name = "MinPivot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, 0, 1, 0), Rotation = 0, BackgroundTransparency = 1, ZIndex = 4, Parent = c})
    local minHand = create("Frame", {Name = "MinHand", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 2, 0, math.round(size * 0.38)), BackgroundColor3 = clr, BorderSizePixel = 0, Parent = minPivot})
    create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = minHand})
    local hrPivot = create("Frame", {Name = "HrPivot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, 0, 1, 0), Rotation = 150, BackgroundTransparency = 1, ZIndex = 4, Parent = c})
    local hrHand = create("Frame", {Name = "HrHand", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 2, 0, math.round(size * 0.26)), BackgroundColor3 = clr, BorderSizePixel = 0, Parent = hrPivot})
    create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = hrHand})
    return c
end
local openMainMenu, showExpiredPopup

-- KEY EXPIRED OVERLAY MODAL

showExpiredPopup = function(expiredKey)
    if not activeSession then return end
    activeSession = false
    clearTeleportState()
    deleteSavedKey()
    if expiredKey then requestKeyDeletion(expiredKey) end
    if CoreGui:FindFirstChild("XyloKeySystemUI") then CoreGui.XyloKeySystemUI:Destroy() end
    local popGui = create("ScreenGui", {Name = "XyloExpiredPopup", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = CoreGui})
    local blocker = create("Frame", {Name = "BlockerOverlay", Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0, 0, 0, 0), BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 1, Active = true, ZIndex = 500, Parent = popGui})
    local popFrame = create("Frame", {Name = "ExpiredCard", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 310, 0, 154), BackgroundColor3 = Color3.fromRGB(15, 15, 19), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 501, Parent = blocker})
    create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = popFrame})
    create("UIStroke", {Thickness = 1, Color = Color3.fromRGB(36, 36, 44), Parent = popFrame})
    local popScale = create("UIScale", {Scale = 0, Parent = popFrame})
    create("TextLabel", {Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 0, 20), BackgroundTransparency = 1, Text = "Key Expired", TextColor3 = Color3.fromRGB(245, 92, 92), Font = Enum.Font.GothamBold, TextSize = 18, ZIndex = 502, Parent = popFrame})
    create("TextLabel", {Size = UDim2.new(1, -32, 0, 32), Position = UDim2.new(0, 16, 0, 48), BackgroundTransparency = 1, Text = "Your access key has expired.\nPlease renew your key to continue.", TextColor3 = Color3.fromRGB(160, 160, 172), Font = Enum.Font.Gotham, TextSize = 12, TextWrapped = true, ZIndex = 502, Parent = popFrame})
    local getKeyBtn = create("TextButton", {Name = "ExpiredGetKeyBtn", Size = UDim2.new(0.5, -22, 0, 36), Position = UDim2.new(0, 18, 0, 96), BackgroundColor3 = Color3.fromRGB(245, 245, 248), TextColor3 = Color3.fromRGB(15, 15, 19), Text = "Get Key", Font = Enum.Font.GothamBold, TextSize = 13, AutoButtonColor = true, ZIndex = 502, Parent = popFrame})
    create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = getKeyBtn})
    local closeBtn = create("TextButton", {Name = "ExpiredCloseBtn", Size = UDim2.new(0.5, -22, 0, 36), Position = UDim2.new(0.5, 4, 0, 96), BackgroundColor3 = Color3.fromRGB(245, 245, 248), TextColor3 = Color3.fromRGB(15, 15, 19), Text = "Close", Font = Enum.Font.GothamBold, TextSize = 13, AutoButtonColor = true, ZIndex = 502, Parent = popFrame})
    create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = closeBtn})
    getKeyBtn.MouseButton1Click:Connect(function()
        copyToClipboard(GET_KEY_URL)
        local orig = getKeyBtn.Text
        getKeyBtn.Text = "Copied!"
        task.wait(1.5)
        getKeyBtn.Text = orig
    end)
    closeBtn.MouseButton1Click:Connect(function()
        if CoreGui:FindFirstChild("XyloMainMenuUI") then CoreGui.XyloMainMenuUI:Destroy() end
        popGui:Destroy()
    end)
    TweenService:Create(blocker, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.55}):Play()
    TweenService:Create(popScale, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
end
local function startKeyWatcher(activeKey)
    task.spawn(function()
        while activeSession do
            task.wait(60)
            if not activeSession then break end
            local success, response = pcall(function()
                return httpRequest({Url = API_URL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({key = activeKey, hwid = hwid})})
            end)
            if success and response and response.Body then
                local ok, data = pcall(function() return HttpService:JSONDecode(response.Body) end)
                if ok and type(data) == "table" then
                    local msg = tostring(data.message or data.error or ""):lower()
                    if data.valid == false or data.expired == true or msg:find("expire") then
                        showExpiredPopup(activeKey)
                        break
                    end
                end
            end
        end
    end)
end

-- CLOSE CONFIRMATION MODAL

local function attachConfirmModal(parentFrame, onConfirmClose)
    local Overlay = create("CanvasGroup", {Name = "ConfirmOverlay", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.fromRGB(5, 5, 8), BackgroundTransparency = 0.45, BorderSizePixel = 0, GroupTransparency = 1, Visible = false, ZIndex = 40, Parent = parentFrame})
    create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = Overlay})
    local ModalCard = create("Frame", {Name = "ModalCard", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 276, 0, 136), BackgroundColor3 = Color3.fromRGB(15, 15, 19), BorderSizePixel = 0, Parent = Overlay})
    create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = ModalCard})
    create("UIStroke", {Thickness = 1, Color = Color3.fromRGB(36, 36, 44), Parent = ModalCard})
    create("TextLabel", {Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 0, 18), BackgroundTransparency = 1, Text = "Are you sure?", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextSize = 18, Parent = ModalCard})
    create("TextLabel", {Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 0, 44), BackgroundTransparency = 1, Text = "Do you want to close this window?", TextColor3 = Color3.fromRGB(140, 140, 150), Font = Enum.Font.GothamMedium, TextSize = 11, Parent = ModalCard})
    local CancelBtn = create("TextButton", {Size = UDim2.new(0, 110, 0, 34), Position = UDim2.new(0.5, -118, 0, 78), BackgroundColor3 = Color3.fromRGB(24, 24, 30), TextColor3 = Color3.fromRGB(180, 180, 190), Text = "Cancel", Font = Enum.Font.GothamMedium, TextSize = 12, AutoButtonColor = false, Parent = ModalCard})
    create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = CancelBtn})
    local CancelStroke = create("UIStroke", {Thickness = 1, Color = Color3.fromRGB(45, 45, 55), Parent = CancelBtn})
    local ConfirmBtn = create("TextButton", {Size = UDim2.new(0, 110, 0, 34), Position = UDim2.new(0.5, 8, 0, 78), BackgroundColor3 = Color3.fromRGB(225, 60, 60), TextColor3 = Color3.fromRGB(255, 255, 255), Text = "Close", Font = Enum.Font.GothamBold, TextSize = 12, AutoButtonColor = false, Parent = ModalCard})
    create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = ConfirmBtn})
    CancelBtn.MouseEnter:Connect(function() TweenService:Create(CancelStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(75, 75, 90)}):Play() end)
    CancelBtn.MouseLeave:Connect(function() TweenService:Create(CancelStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(45, 45, 55)}):Play() end)
    ConfirmBtn.MouseEnter:Connect(function() TweenService:Create(ConfirmBtn, TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(245, 75, 75)}):Play() end)
    ConfirmBtn.MouseLeave:Connect(function() TweenService:Create(ConfirmBtn, TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(225, 60, 60)}):Play() end)
    local isTransitioning = false
    local function show()
        if not activeSession or isTransitioning then return end
        isTransitioning = true
        Overlay.Visible = true
        Overlay.GroupTransparency = 1
        local t = TweenService:Create(Overlay, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {GroupTransparency = 0})
        t:Play()
        t.Completed:Connect(function() isTransitioning = false end)
    end
    local function hide()
        if isTransitioning then return end
        isTransitioning = true
        local t = TweenService:Create(Overlay, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {GroupTransparency = 1})
        t:Play()
        t.Completed:Connect(function()
            Overlay.Visible = false
            isTransitioning = false
        end)
    end
    CancelBtn.MouseButton1Click:Connect(hide)
    ConfirmBtn.MouseButton1Click:Connect(function() onConfirmClose() end)
    return show
end

-- AUTO CLOSE POPUPS

local autoClosePopupsEnabled = false
local function autoClosePaycheque()
    if not autoClosePopupsEnabled then return end
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return end
    local subMenus = playerGui:FindFirstChild("SubMenus")
    if not subMenus then return end
    local paycheque = subMenus:FindFirstChild("Paycheque")
    if not paycheque then return end
    local isVisible = false
    if paycheque:IsA("ScreenGui") then
        isVisible = paycheque.Enabled
    else
        isVisible = paycheque.Visible
    end
    if isVisible then
        if paycheque:IsA("ScreenGui") then
            paycheque.Enabled = false
        else
            paycheque.Visible = false
        end
        local closeBtn = paycheque:FindFirstChild("CloseMenu")
        if closeBtn and closeBtn:IsA("GuiButton") then
            if typeof(getconnections) == "function" then
                for _, connection in pairs(getconnections(closeBtn.MouseButton1Click)) do
                    connection:Fire()
                end
            end
        end
    end
end
task.spawn(function()
    while task.wait(0.5) do
        pcall(autoClosePaycheque)
    end
end)

-- MAIN MENU

openMainMenu = function(expiryTimestamp, verifiedKey)
    local expiryTime = expiryTimestamp or (os.time() + 86400)
    if getgenv then
        getgenv().XyloSavedKey = verifiedKey
        getgenv().XyloExpiry = expiryTime
    end
    local MenuGui = create("ScreenGui", {Name = "XyloMainMenuUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = CoreGui})
    local MainMenuFrame = create("Frame", {Name = "MainMenuFrame", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 620, 0, 420), BackgroundColor3 = Color3.fromRGB(11, 11, 13), BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 2, Parent = MenuGui})
    create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = MainMenuFrame})
    create("UIStroke", {Thickness = 1, Color = Color3.fromRGB(32, 32, 38), Parent = MainMenuFrame})
    local MenuScale = create("UIScale", {Scale = 0, Parent = MainMenuFrame})
    local MainContent = create("CanvasGroup", {Name = "MainContent", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true, Parent = MainMenuFrame})
    create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = MainContent})
    create("Frame", {Name = "GlobalHorizontalDivider", Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0, 38), BackgroundColor3 = Color3.fromRGB(26, 26, 32), BorderSizePixel = 0, ZIndex = 5, Parent = MainContent})
    create("Frame", {Name = "GlobalVerticalDivider", Size = UDim2.new(0, 1, 1, -62), Position = UDim2.new(0, 52, 0, 38), BackgroundColor3 = Color3.fromRGB(26, 26, 32), BorderSizePixel = 0, ZIndex = 5, Parent = MainContent})
    local TopBar = create("Frame", {Name = "TopBar", Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Color3.fromRGB(15, 15, 18), BorderSizePixel = 0, Parent = MainContent})
    local TopLogo = createXLogo(20, TopBar)
    TopLogo.AnchorPoint = Vector2.new(0.5, 0.5)
    TopLogo.Position = UDim2.new(0, 26, 0.5, 0)
    create("Frame", {Name = "TopBarVerticalDivider", Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(0, 52, 0, 0), BackgroundColor3 = Color3.fromRGB(26, 26, 32), BorderSizePixel = 0, ZIndex = 6, Parent = TopBar})
    create("TextLabel", {Name = "TopXyloBrand", Size = UDim2.new(0, 120, 1, 0), Position = UDim2.new(0, 64, 0, 0), BackgroundTransparency = 1, Text = "XyloScripts", TextColor3 = Color3.fromRGB(240, 240, 245), Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left, Parent = TopBar})
    create("TextLabel", {Size = UDim2.new(1, 0, 1, 0), Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1, Text = "Wild Horse Islands", TextColor3 = Color3.fromRGB(150, 150, 160), Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, Parent = TopBar})
    local MinBtn = create("TextButton", {Size = UDim2.new(0, 36, 0, 38), Position = UDim2.new(1, -74, 0, 0), BackgroundTransparency = 1, Text = "-", TextColor3 = Color3.fromRGB(130, 130, 140), Font = Enum.Font.GothamBold, TextSize = 14, Parent = TopBar})
    local CloseBtn = create("TextButton", {Size = UDim2.new(0, 38, 0, 38), Position = UDim2.new(1, -38, 0, 0), BackgroundTransparency = 1, Text = "X", TextColor3 = Color3.fromRGB(130, 130, 140), Font = Enum.Font.GothamBold, TextSize = 12, Parent = TopBar})
    MinBtn.MouseEnter:Connect(function() if activeSession then TweenService:Create(MinBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play() end end)
    MinBtn.MouseLeave:Connect(function() if activeSession then TweenService:Create(MinBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(130, 130, 140)}):Play() end end)
    CloseBtn.MouseEnter:Connect(function() if activeSession then TweenService:Create(CloseBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 90, 90)}):Play() end end)
    CloseBtn.MouseLeave:Connect(function() if activeSession then TweenService:Create(CloseBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(130, 130, 140)}):Play() end end)
    makeDraggable(TopBar, MainMenuFrame)
    local FloatBtn = create("TextButton", {Name = "XyloFloatingBtn", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 18), Size = UDim2.new(0, 58, 0, 58), BackgroundColor3 = Color3.fromRGB(14, 14, 17), BorderSizePixel = 0, AutoButtonColor = false, Text = "", Visible = false, Parent = MenuGui})
    create("UICorner", {CornerRadius = UDim.new(0, 14), Parent = FloatBtn})
    create("UIStroke", {Thickness = 1, Color = Color3.fromRGB(38, 38, 46), Parent = FloatBtn})
    local FloatScale = create("UIScale", {Scale = 0, Parent = FloatBtn})
    local FloatLogo = createXLogo(28, FloatBtn)
    FloatLogo.AnchorPoint, FloatLogo.Position = Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0.5, 0)
    local function restoreMenu()
        if not activeSession then return end
        local t = TweenService:Create(FloatScale, TweenInfo.new(0.25, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Scale = 0})
        t:Play()
        t.Completed:Wait()
        FloatBtn.Visible = false
        MainMenuFrame.Visible = true
        TweenService:Create(MenuScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
    end
    local fMoveConn, fEndConn
    FloatBtn.InputBegan:Connect(function(input)
        if not activeSession then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if fMoveConn then fMoveConn:Disconnect() end
            if fEndConn then fEndConn:Disconnect() end
            local fStart = input.Position
            local fPos = FloatBtn.Position
            local movedDist = 0
            fMoveConn = UserInputService.InputChanged:Connect(function(moveInput)
                if not activeSession then return end
                if moveInput.UserInputType == Enum.UserInputType.MouseMovement or moveInput.UserInputType == Enum.UserInputType.Touch then
                    local delta = moveInput.Position - fStart
                    movedDist = delta.Magnitude
                    FloatBtn.Position = UDim2.new(fPos.X.Scale, fPos.X.Offset + delta.X, fPos.Y.Scale, fPos.Y.Offset + delta.Y)
                end
            end)
            fEndConn = UserInputService.InputEnded:Connect(function(endInput)
                if endInput.UserInputType == Enum.UserInputType.MouseButton1 or endInput.UserInputType == Enum.UserInputType.Touch then
                    if fMoveConn then fMoveConn:Disconnect(); fMoveConn = nil end
                    if fEndConn then fEndConn:Disconnect(); fEndConn = nil end
                    if movedDist < 8 then restoreMenu() end
                end
            end)
        end
    end)
    MinBtn.MouseButton1Click:Connect(function()
        if not activeSession then return end
        local t = TweenService:Create(MenuScale, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Scale = 0})
        t:Play()
        t.Completed:Wait()
        MainMenuFrame.Visible = false
        FloatBtn.Visible = true
        TweenService:Create(FloatScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
    end)
    local Sidebar = create("Frame", {Name = "Sidebar", Size = UDim2.new(0, 52, 1, -62), Position = UDim2.new(0, 0, 0, 38), BackgroundColor3 = Color3.fromRGB(13, 13, 16), BorderSizePixel = 0, Parent = MainContent})
    local ActiveMarker = create("Frame", {Name = "ActiveMarker", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0, 28), Size = UDim2.new(0, 3, 0, 22), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, Parent = Sidebar})
    create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = ActiveMarker})
    local HomeBtn = create("TextButton", {Name = "HomeBtn", Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 0, 8), BackgroundTransparency = 1, Text = "", Parent = Sidebar})
    local House, houseParts = createHouseIcon(18, HomeBtn, Color3.fromRGB(255, 255, 255))
    House.AnchorPoint, House.Position = Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0.5, 0)
    local SettingsBtn = create("TextButton", {Name = "SettingsBtn", Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 1, -44), BackgroundTransparency = 1, Text = "", Parent = Sidebar})
    local SettingsLines, settingsParts = createSettingsIcon(18, SettingsBtn, Color3.fromRGB(130, 130, 140))
    SettingsLines.AnchorPoint, SettingsLines.Position = Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0.5, 0)
    local function createTabTooltip(text, yPosScale, yOffset)
        local tipFrame = create("Frame", {Name = text .. "Tooltip", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 60, yPosScale, yOffset), Size = UDim2.new(0, 68, 0, 26), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0, BackgroundTransparency = 1, Visible = false, ZIndex = 60, Parent = MainMenuFrame})
        create("UICorner", {CornerRadius = UDim.new(0, 6), Parent = tipFrame})
        local tipText = create("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = text, TextColor3 = Color3.fromRGB(15, 15, 18), Font = Enum.Font.GothamBold, TextSize = 11, TextTransparency = 1, ZIndex = 61, Parent = tipFrame})
        return tipFrame, tipText
    end
    local HomeTooltip, HomeTooltipText = createTabTooltip("Home", 0, 38 + 28)
    local SettingsTooltip, SettingsTooltipText = createTabTooltip("Settings", 1, -48)
    local function bindHover(btn, tip, textObj)
        btn.MouseEnter:Connect(function()
            if not activeSession then return end
            tip.Visible = true
            TweenService:Create(tip, TweenInfo.new(0.18), {BackgroundTransparency = 0}):Play()
            TweenService:Create(textObj, TweenInfo.new(0.18), {TextTransparency = 0}):Play()
        end)
        btn.MouseLeave:Connect(function()
            local t = TweenService:Create(tip, TweenInfo.new(0.15), {BackgroundTransparency = 1})
            TweenService:Create(textObj, TweenInfo.new(0.15), {TextTransparency = 1}):Play()
            t:Play()
            task.spawn(function() t.Completed:Wait(); tip.Visible = false end)
        end)
    end
    bindHover(HomeBtn, HomeTooltip, HomeTooltipText)
    bindHover(SettingsBtn, SettingsTooltip, SettingsTooltipText)
    local ContentArea = create("Frame", {Name = "ContentArea", Size = UDim2.new(1, -52, 1, -62), Position = UDim2.new(0, 52, 0, 38), BackgroundTransparency = 1, Parent = MainContent})
    -- HOME VIEW
    local HomePage = create("Frame", {Name = "HomePage", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = true, Parent = ContentArea})
    create("TextLabel", {Name = "HomeTitle", Size = UDim2.new(0, 200, 0, 24), Position = UDim2.new(0, 24, 0, 14), BackgroundTransparency = 1, Text = "Home", TextColor3 = Color3.fromRGB(200, 200, 210), Font = Enum.Font.GothamBold, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Parent = HomePage})
    local playerUsername = localPlayer and (localPlayer.DisplayName or localPlayer.Name) or "User"
    create("TextLabel", {Name = "WelcomeLabel", Size = UDim2.new(0, 260, 0, 32), Position = UDim2.new(0, 24, 0, 38), BackgroundTransparency = 1, Text = "Welcome, " .. playerUsername .. "!", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left, Parent = HomePage})
    local HomeDiscordBtn = create("TextButton", {Name = "HomeDiscordBtn", Size = UDim2.new(0, 84, 0, 34), Position = UDim2.new(1, -104, 0, 12), BackgroundColor3 = Color3.fromRGB(16, 16, 21), TextColor3 = Color3.fromRGB(170, 170, 180), Text = "Discord", Font = Enum.Font.GothamMedium, TextSize = 12, BorderSizePixel = 0, AutoButtonColor = false, Parent = HomePage})
    create("UICorner", {CornerRadius = UDim.new(0, 9), Parent = HomeDiscordBtn})
    local homeDiscordStroke = create("UIStroke", {Thickness = 1, Color = Color3.fromRGB(36, 36, 46), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = HomeDiscordBtn})
    local isDiscordHovered = false
    HomeDiscordBtn.MouseEnter:Connect(function()
        if not activeSession then return end
        isDiscordHovered = true
        TweenService:Create(homeDiscordStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(75, 75, 95)}):Play()
        TweenService:Create(HomeDiscordBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
    end)
    HomeDiscordBtn.MouseLeave:Connect(function()
        if not activeSession then return end
        isDiscordHovered = false
        TweenService:Create(homeDiscordStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(36, 36, 46)}):Play()
        if HomeDiscordBtn.Text == "Discord" then
            TweenService:Create(HomeDiscordBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(170, 170, 180)}):Play()
        end
    end)
    HomeDiscordBtn.MouseButton1Click:Connect(function()
        if not activeSession then return end
        copyToClipboard(DISCORD_URL)
        HomeDiscordBtn.Text = "Copied!"
        HomeDiscordBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        task.delay(1.5, function()
            if HomeDiscordBtn and HomeDiscordBtn.Parent then
                HomeDiscordBtn.Text = "Discord"
                HomeDiscordBtn.TextColor3 = isDiscordHovered and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(170, 170, 180)
            end
        end)
    end)
    local ExpiryBadge = create("Frame", {Name = "KeyExpiryBadge", AnchorPoint = Vector2.new(1, 0), Size = UDim2.new(0, 240, 0, 130), Position = UDim2.new(1, -24, 0, 88), BackgroundColor3 = Color3.fromRGB(16, 16, 21), BorderSizePixel = 0, Parent = HomePage})
    create("UICorner", {CornerRadius = UDim.new(0, 12), Parent = ExpiryBadge})
    create("UIStroke", {Thickness = 1, Color = Color3.fromRGB(36, 36, 46), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = ExpiryBadge})
    local BadgeClockBox = create("Frame", {Name = "ClockIconContainer", Size = UDim2.new(0, 20, 0, 20), Position = UDim2.new(0, 20, 0, 24), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Parent = ExpiryBadge})
    createClockIcon(20, BadgeClockBox, Color3.fromRGB(145, 145, 165))
    create("TextLabel", {Name = "BadgeTag", Size = UDim2.new(1, -54, 0, 16), Position = UDim2.new(0, 48, 0, 24), AnchorPoint = Vector2.new(0, 0.5), BackgroundTransparency = 1, Text = "KEY EXPIRY", TextColor3 = Color3.fromRGB(130, 130, 145), Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = ExpiryBadge})
    local ExpiryCountdownText = create("TextLabel", {Name = "ExpiryCountdownText", Size = UDim2.new(1, -40, 0, 28), Position = UDim2.new(0, 20, 0, 48), BackgroundTransparency = 1, Text = "0d 00h 00m left", TextColor3 = Color3.fromRGB(245, 245, 252), Font = Enum.Font.GothamBold, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Parent = ExpiryBadge})
    local DateRow = create("Frame", {Name = "DateRow", Size = UDim2.new(1, -40, 0, 18), Position = UDim2.new(0, 20, 0, 82), BackgroundTransparency = 1, Parent = ExpiryBadge})
    create("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = DateRow})
    local expiryDateStr = os.date("%d/%m/%Y %H:%M", expiryTime)
    create("TextLabel", {Name = "DateText", Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Text = expiryDateStr, TextColor3 = Color3.fromRGB(155, 155, 170), Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = DateRow})
    create("TextLabel", {Name = "DateHint", Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Text = "(DD/MM/YYYY)", TextColor3 = Color3.fromRGB(95, 95, 110), Font = Enum.Font.Gotham, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2, Parent = DateRow})
    local BottomStatusBar = create("Frame", {Name = "BottomStatusBar", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, -24), BackgroundColor3 = Color3.fromRGB(13, 13, 16), BorderSizePixel = 0, ZIndex = 8, Parent = MainContent})
    create("Frame", {Name = "BottomDivider", Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0, 0), BackgroundColor3 = Color3.fromRGB(26, 26, 32), BorderSizePixel = 0, Parent = BottomStatusBar})
    local SessionTimerLabel = create("TextLabel", {Name = "SessionTimerLabel", Size = UDim2.new(0, 250, 1, 0), Position = UDim2.new(0, 16, 0, 0), BackgroundTransparency = 1, Text = "Session: 00h 00m 00s", TextColor3 = Color3.fromRGB(145, 145, 160), Font = Enum.Font.GothamMedium, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = BottomStatusBar})
    task.spawn(function()
        while MenuGui and MenuGui.Parent do
            local remaining = math.max(0, expiryTime - os.time())
            if remaining <= 0 and activeSession then
                ExpiryCountdownText.Text = "Expired"
                ExpiryCountdownText.TextColor3 = Color3.fromRGB(245, 92, 92)
                showExpiredPopup(verifiedKey)
                break
            end
            local days = math.floor(remaining / 86400)
            local hours = math.floor((remaining % 86400) / 3600)
            local mins = math.floor((remaining % 3600) / 60)
            local secs = remaining % 60
            ExpiryCountdownText.Text = string.format("%dd %dh %dm %02ds left", days, hours, mins, secs)
            local elapsed = math.floor(tick() - SCRIPT_START_TIME)
            local sH = math.floor(elapsed / 3600)
            local sM = math.floor((elapsed % 3600) / 60)
            local sS = elapsed % 60
            SessionTimerLabel.Text = string.format("Session: %02dh %02dm %02ds", sH, sM, sS)
            task.wait(1)
        end
    end)
    -- SETTINGS PAGE
    local SettingsPage = create("Frame", {Name = "SettingsPage", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false, Parent = ContentArea})
    create("TextLabel", {Name = "SettingsTitle", Size = UDim2.new(0, 200, 0, 24), Position = UDim2.new(0, 24, 0, 14), BackgroundTransparency = 1, Text = "Settings", TextColor3 = Color3.fromRGB(200, 200, 210), Font = Enum.Font.GothamBold, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Parent = SettingsPage})
    local ToggleCard = create("Frame", {Name = "AutoCloseToggleCard", Size = UDim2.new(1, -48, 0, 64), Position = UDim2.new(0, 24, 0, 56), BackgroundColor3 = Color3.fromRGB(16, 16, 21), BorderSizePixel = 0, Parent = SettingsPage})
    create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = ToggleCard})
    create("UIStroke", {Thickness = 1, Color = Color3.fromRGB(36, 36, 46), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = ToggleCard})
    create("TextLabel", {Name = "ToggleTitle", Size = UDim2.new(1, -100, 0, 20), Position = UDim2.new(0, 16, 0, 12), BackgroundTransparency = 1, Text = "Auto Close Popups", TextColor3 = Color3.fromRGB(225, 225, 235), Font = Enum.Font.GothamBold, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left, Parent = ToggleCard})
    create("TextLabel", {Name = "ToggleDesc", Size = UDim2.new(1, -100, 0, 16), Position = UDim2.new(0, 16, 0, 34), BackgroundTransparency = 1, Text = "Automatically closes popups. (e.g. Paycheque)", TextColor3 = Color3.fromRGB(115, 115, 130), Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = ToggleCard})
    local ToggleHolder = create("Frame", {Name = "ToggleHolder", Size = UDim2.new(0, 42, 0, 22), Position = UDim2.new(1, -58, 0.5, -11), BackgroundColor3 = Color3.fromRGB(40, 40, 48), BorderSizePixel = 0, Parent = ToggleCard})
    create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = ToggleHolder})
    local ToggleKnob = create("Frame", {Name = "ToggleKnob", Size = UDim2.new(0, 18, 0, 18), Position = UDim2.new(0, 2, 0.5, -9), BackgroundColor3 = Color3.fromRGB(170, 170, 180), BorderSizePixel = 0, Parent = ToggleHolder})
    create("UICorner", {CornerRadius = UDim.new(1, 0), Parent = ToggleKnob})
    local ToggleClickTarget = create("TextButton", {Name = "ToggleClickTarget", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "", Parent = ToggleHolder})
    local function setToggleVisual(on)
        if on then
            TweenService:Create(ToggleHolder, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(245, 245, 245)}):Play()
            TweenService:Create(ToggleKnob, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(1, -20, 0.5, -9), BackgroundColor3 = Color3.fromRGB(15, 15, 18)}):Play()
        else
            TweenService:Create(ToggleHolder, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(40, 40, 48)}):Play()
            TweenService:Create(ToggleKnob, TweenInfo.new(0.22, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = UDim2.new(0, 2, 0.5, -9), BackgroundColor3 = Color3.fromRGB(170, 170, 180)}):Play()
        end
    end
    ToggleClickTarget.MouseButton1Click:Connect(function()
        if not activeSession then return end
        autoClosePopupsEnabled = not autoClosePopupsEnabled
        setToggleVisual(autoClosePopupsEnabled)
    end)
    local currentTab = "Home"
    local function setTab(tabName)
        if not activeSession or currentTab == tabName then return end
        currentTab = tabName
        local targetY
        if tabName == "Home" then targetY = UDim2.new(0, 0, 0, 28)
        elseif tabName == "Settings" then targetY = UDim2.new(0, 0, 1, -24) end
        TweenService:Create(ActiveMarker, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Position = targetY}):Play()
        local activeColor = Color3.fromRGB(255, 255, 255)
        local inactiveColor = Color3.fromRGB(130, 130, 140)
        local function updateParts(parts, isActive)
            local color = isActive and activeColor or inactiveColor
            for _, part in ipairs(parts) do
                if part:IsA("UIStroke") then TweenService:Create(part, TweenInfo.new(0.2), {Color = color}):Play()
                else TweenService:Create(part, TweenInfo.new(0.2), {BackgroundColor3 = color}):Play() end
            end
        end
        updateParts(houseParts, tabName == "Home")
        updateParts(settingsParts, tabName == "Settings")
        HomePage.Visible = (tabName == "Home")
        SettingsPage.Visible = (tabName == "Settings")
    end
    HomeBtn.MouseButton1Click:Connect(function() setTab("Home") end)
    SettingsBtn.MouseButton1Click:Connect(function() setTab("Settings") end)
    local promptMenuClose = attachConfirmModal(MainMenuFrame, function()
        activeSession = false
        clearTeleportState()
        local t = TweenService:Create(MenuScale, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Scale = 0})
        t:Play()
        t.Completed:Wait()
        MenuGui:Destroy()
    end)
    CloseBtn.MouseButton1Click:Connect(promptMenuClose)
    TweenService:Create(MenuScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
end

-- KEY SYSTEM UI SETUP

local KeyGui = create("ScreenGui", {Name = "XyloKeySystemUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = CoreGui})
local MainFrame = create("Frame", {Name = "MainFrame", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 370, 0, 295), BackgroundColor3 = Color3.fromRGB(11, 11, 13), BorderSizePixel = 0, ClipsDescendants = true, Parent = KeyGui})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = MainFrame})
create("UIStroke", {Thickness = 1, Color = Color3.fromRGB(32, 32, 38), Parent = MainFrame})
local MainScale = create("UIScale", {Scale = 0, Parent = MainFrame})
local LoadingContainer = create("CanvasGroup", {Name = "LoadingContainer", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, GroupTransparency = 0, Parent = MainFrame})
local BigLogo, BigClip = createXLogo(110, LoadingContainer, 6)
BigLogo.AnchorPoint, BigLogo.Position = Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0.38, 0)
local LogoShineGradient = create("UIGradient", {Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 45, 48)), ColorSequenceKeypoint.new(0.4, Color3.fromRGB(45, 45, 48)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(45, 45, 48)), ColorSequenceKeypoint.new(1, Color3.fromRGB(45, 45, 48))}), Offset = Vector2.new(-1.2, 0), Parent = BigClip})
local LoadingBrandText = create("TextLabel", {Name = "LoadingBrandText", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.74, 0), Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Text = "XyloScripts", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center, Parent = LoadingContainer})
local LoadingTextShineGradient = create("UIGradient", {Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(45, 45, 48)), ColorSequenceKeypoint.new(0.4, Color3.fromRGB(45, 45, 48)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(45, 45, 48)), ColorSequenceKeypoint.new(1, Color3.fromRGB(45, 45, 48))}), Offset = Vector2.new(-1.2, 0), Parent = LoadingBrandText})
local ContentContainer = create("CanvasGroup", {Name = "ContentContainer", Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, GroupTransparency = 1, Visible = false, Parent = MainFrame})
create("UICorner", {CornerRadius = UDim.new(0, 10), Parent = ContentContainer})
local KeyTopBar = create("Frame", {Name = "KeyTopBar", Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Color3.fromRGB(15, 15, 18), BorderSizePixel = 0, Parent = ContentContainer})
create("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = Color3.fromRGB(26, 26, 32), BorderSizePixel = 0, Parent = KeyTopBar})
local MiniKeyLogo = createXLogo(20, KeyTopBar)
MiniKeyLogo.AnchorPoint, MiniKeyLogo.Position = Vector2.new(0, 0.5), UDim2.new(0, 14, 0.5, 0)
create("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "Key System", TextColor3 = Color3.fromRGB(150, 150, 160), Font = Enum.Font.GothamMedium, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, Parent = KeyTopBar})
local KeyCloseBtn = create("TextButton", {Size = UDim2.new(0, 38, 0, 38), Position = UDim2.new(1, -38, 0, 0), BackgroundTransparency = 1, Text = "X", TextColor3 = Color3.fromRGB(130, 130, 140), Font = Enum.Font.GothamBold, TextSize = 12, Parent = KeyTopBar})
KeyCloseBtn.MouseEnter:Connect(function() TweenService:Create(KeyCloseBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 90, 90)}):Play() end)
KeyCloseBtn.MouseLeave:Connect(function() TweenService:Create(KeyCloseBtn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(130, 130, 140)}):Play() end)
makeDraggable(KeyTopBar, MainFrame)
local promptKeyClose = attachConfirmModal(MainFrame, function()
    clearTeleportState()
    local t = TweenService:Create(MainScale, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Scale = 0})
    t:Play()
    t.Completed:Wait()
    KeyGui:Destroy()
end)
KeyCloseBtn.MouseButton1Click:Connect(promptKeyClose)
local BrandTitle = create("TextLabel", {Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 0, 48), BackgroundTransparency = 1, Text = "XyloScripts", TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.GothamBold, TextSize = 25, Parent = ContentContainer})
local TextShineGradient = create("UIGradient", {Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 80, 90)), ColorSequenceKeypoint.new(0.4, Color3.fromRGB(80, 80, 90)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 80, 90)), ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 80, 90))}), Offset = Vector2.new(-1.2, 0), Parent = BrandTitle})
create("TextLabel", {Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 0, 74), BackgroundTransparency = 1, Text = "The #1 Wild Horse Islands Script", TextColor3 = Color3.fromRGB(130, 130, 142), Font = Enum.Font.GothamMedium, TextSize = 11, Parent = ContentContainer})
local InputContainer = create("Frame", {Size = UDim2.new(0, 300, 0, 36), Position = UDim2.new(0.5, -150, 0, 98), BackgroundColor3 = Color3.fromRGB(16, 16, 20), BorderSizePixel = 0, Parent = ContentContainer})
create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = InputContainer})
local InputStroke = create("UIStroke", {Thickness = 1, Color = Color3.fromRGB(42, 42, 52), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = InputContainer})
local InputBox = create("TextBox", {Size = UDim2.new(1, -20, 1, 0), Position = UDim2.new(0, 12, 0, 0), BackgroundTransparency = 1, Text = "", PlaceholderText = "Paste your key here...", PlaceholderColor3 = Color3.fromRGB(85, 85, 95), TextColor3 = Color3.fromRGB(255, 255, 255), Font = Enum.Font.Gotham, TextSize = 12, ClearTextOnFocus = false, Parent = InputContainer})
InputBox.Focused:Connect(function() TweenService:Create(InputStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(120, 120, 140)}):Play() end)
InputBox.FocusLost:Connect(function() TweenService:Create(InputStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(42, 42, 52)}):Play() end)
local rememberKey = false
local CheckboxRow = create("TextButton", {Size = UDim2.new(0, 300, 0, 20), Position = UDim2.new(0.5, -150, 0, 142), BackgroundTransparency = 1, Text = "", Parent = ContentContainer})
local CheckBoxFrame = create("Frame", {Size = UDim2.new(0, 14, 0, 14), Position = UDim2.new(0, 4, 0.5, -7), BackgroundColor3 = Color3.fromRGB(16, 16, 20), BorderSizePixel = 0, Parent = CheckboxRow})
create("UICorner", {CornerRadius = UDim.new(0, 4), Parent = CheckBoxFrame})
local CheckBoxStroke = create("UIStroke", {Thickness = 1, Color = Color3.fromRGB(45, 45, 55), Parent = CheckBoxFrame})
local CheckMark = create("TextLabel", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Text = "✓", TextColor3 = Color3.fromRGB(10, 10, 10), Font = Enum.Font.GothamBold, TextSize = 10, TextTransparency = 1, Parent = CheckBoxFrame})
local CheckboxLabel = create("TextLabel", {Size = UDim2.new(1, -30, 1, 0), Position = UDim2.new(0, 26, 0, 0), BackgroundTransparency = 1, Text = "Remember Key", TextColor3 = Color3.fromRGB(140, 140, 150), Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Parent = CheckboxRow})
local function updateCheckboxVisual()
    TweenService:Create(CheckBoxFrame, TweenInfo.new(0.15), {BackgroundColor3 = rememberKey and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(16, 16, 20)}):Play()
    TweenService:Create(CheckBoxStroke, TweenInfo.new(0.15), {Color = rememberKey and Color3.fromRGB(245, 245, 245) or Color3.fromRGB(45, 45, 55)}):Play()
    TweenService:Create(CheckMark, TweenInfo.new(0.15), {TextTransparency = rememberKey and 0 or 1}):Play()
    TweenService:Create(CheckboxLabel, TweenInfo.new(0.15), {TextColor3 = rememberKey and Color3.fromRGB(220, 220, 230) or Color3.fromRGB(140, 140, 150)}):Play()
end
CheckboxRow.MouseButton1Click:Connect(function() rememberKey = not rememberKey; updateCheckboxVisual() end)
pcall(function()
    if isfile and readfile and isfile("xylo_key.txt") then
        local raw = readfile("xylo_key.txt")
        if raw and #raw > 0 then InputBox.Text = raw; rememberKey = true; updateCheckboxVisual() end
    end
end)
local SubmitBtn = create("TextButton", {Size = UDim2.new(0, 300, 0, 36), Position = UDim2.new(0.5, -150, 0, 170), BackgroundColor3 = Color3.fromRGB(245, 245, 245), TextColor3 = Color3.fromRGB(10, 10, 10), Text = "Submit Key", Font = Enum.Font.GothamBold, TextSize = 13, BorderSizePixel = 0, AutoButtonColor = false, Parent = ContentContainer})
create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = SubmitBtn})
SubmitBtn.MouseEnter:Connect(function() TweenService:Create(SubmitBtn, TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(215, 215, 220)}):Play() end)
SubmitBtn.MouseLeave:Connect(function() TweenService:Create(SubmitBtn, TweenInfo.new(0.18), {BackgroundColor3 = Color3.fromRGB(245, 245, 245)}):Play() end)
local function createSecondaryBtn(name, text, xPos)
    local btn = create("TextButton", {Name = name, Size = UDim2.new(0, 144, 0, 32), Position = UDim2.new(0.5, xPos, 0, 214), BackgroundColor3 = Color3.fromRGB(16, 16, 20), TextColor3 = Color3.fromRGB(170, 170, 180), Text = text, Font = Enum.Font.GothamMedium, TextSize = 12, BorderSizePixel = 0, AutoButtonColor = false, Parent = ContentContainer})
    create("UICorner", {CornerRadius = UDim.new(0, 8), Parent = btn})
    local stroke = create("UIStroke", {Thickness = 1, Color = Color3.fromRGB(42, 42, 52), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = btn})
    btn.MouseEnter:Connect(function()
        TweenService:Create(stroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(75, 75, 95)}):Play()
        TweenService:Create(btn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(255, 255, 255)}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(stroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(42, 42, 52)}):Play()
        TweenService:Create(btn, TweenInfo.new(0.2), {TextColor3 = Color3.fromRGB(170, 170, 180)}):Play()
    end)
    return btn
end
local GetKeyBtn = createSecondaryBtn("GetKeyBtn", "Get Key", -150)
local DiscordBtn = createSecondaryBtn("DiscordBtn", "Discord", 6)
local StatusLabel = create("TextLabel", {Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 0, 258), BackgroundTransparency = 1, Text = "", TextColor3 = Color3.fromRGB(140, 140, 150), Font = Enum.Font.Gotham, TextSize = 11, Parent = ContentContainer})
GetKeyBtn.MouseButton1Click:Connect(function()
    copyToClipboard(GET_KEY_URL)
    StatusLabel.TextColor3, StatusLabel.Text = Color3.fromRGB(100, 200, 255), "Key URL copied to clipboard!"
    task.delay(3, function() if StatusLabel.Text == "Key URL copied to clipboard!" then StatusLabel.Text = "" end end)
end)
DiscordBtn.MouseButton1Click:Connect(function()
    copyToClipboard(DISCORD_URL)
    StatusLabel.TextColor3, StatusLabel.Text = Color3.fromRGB(140, 160, 255), "Discord invite copied to clipboard!"
    task.delay(3, function() if StatusLabel.Text == "Discord invite copied to clipboard!" then StatusLabel.Text = "" end end)
end)
local function validateKey()
    local enteredKey = InputBox.Text:gsub("%s+", "")
    if enteredKey == "" then StatusLabel.TextColor3, StatusLabel.Text = Color3.fromRGB(255, 90, 90), "Invalid Key." return end
    StatusLabel.TextColor3, StatusLabel.Text = Color3.fromRGB(170, 170, 180), "Validating..."
    task.spawn(function()
        local success, response = pcall(function()
            return httpRequest({Url = API_URL, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = HttpService:JSONEncode({key = enteredKey, hwid = hwid})})
        end)
        local isAccepted, isExpired = false, false
        local computedExpiryTime = nil
        if success and response and response.Body then
            local ok, data = pcall(function() return HttpService:JSONDecode(response.Body) end)
            if ok and type(data) == "table" then
                if data.valid == true or data.success == true then
                    local expRaw = data.expires_at or data.expiresAt or data.expiry or data.expiration
                    local parsedExp = parseTimestamp(expRaw)
                    local actRaw = data.activated_at or data.activatedAt or data.first_activated or data.first_used or data.created_at
                    local parsedAct = parseTimestamp(actRaw)
                    local duration = tonumber(data.duration) or 86400
                    if parsedExp then computedExpiryTime = parsedExp
                    elseif parsedAct then computedExpiryTime = parsedAct + duration
                    elseif data.timeLeft or data.time_left then computedExpiryTime = os.time() + (tonumber(data.timeLeft or data.time_left) or 86400) end
                    if computedExpiryTime and computedExpiryTime <= os.time() then isExpired = true
                    else isAccepted = true end
                else
                    local msg = tostring(data.message or data.error or ""):lower()
                    if data.expired == true or msg:find("expire") then isExpired = true end
                end
            end
        end
        if isAccepted then
            StatusLabel.TextColor3, StatusLabel.Text = Color3.fromRGB(75, 220, 130), "Key Accepted!"
            if rememberKey and writefile then pcall(function() writefile("xylo_key.txt", enteredKey) end)
            else deleteSavedKey() end
            task.wait(1.1)
            local closeTween = TweenService:Create(MainScale, TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.In), {Scale = 0})
            closeTween:Play()
            closeTween.Completed:Wait()
            KeyGui:Destroy()
            startKeyWatcher(enteredKey)
            openMainMenu(computedExpiryTime, enteredKey)
        elseif isExpired then
            deleteSavedKey()
            requestKeyDeletion(enteredKey)
            rememberKey = false
            updateCheckboxVisual()
            InputBox.Text = ""
            StatusLabel.TextColor3, StatusLabel.Text = Color3.fromRGB(255, 90, 90), "Key Expired."
        else
            StatusLabel.TextColor3, StatusLabel.Text = Color3.fromRGB(255, 90, 90), "Invalid Key."
        end
    end)
end
SubmitBtn.MouseButton1Click:Connect(validateKey)
InputBox.FocusLost:Connect(function(enterPressed) if enterPressed then validateKey() end end)
-- Loading Animation Flow
task.spawn(function()
    TweenService:Create(MainScale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
    task.wait(0.5)
    for i = 1, 2 do
        LogoShineGradient.Offset = Vector2.new(-1.2, 0)
        LoadingTextShineGradient.Offset = Vector2.new(-1.2, 0)
        local shineLogo = TweenService:Create(LogoShineGradient, TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Offset = Vector2.new(1.2, 0)})
        local shineText = TweenService:Create(LoadingTextShineGradient, TweenInfo.new(0.85, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Offset = Vector2.new(1.2, 0)})
        shineLogo:Play()
        shineText:Play()
        shineLogo.Completed:Wait()
        if i < 2 then task.wait(0.12) end
    end
    -- Teleport reload: skip key system, open menu directly
    if isTeleportReload and savedKeyValue and savedExpiryTime then
        KeyGui:Destroy()
        startKeyWatcher(savedKeyValue)
        openMainMenu(savedExpiryTime, savedKeyValue)
        return
    end
    -- Fresh execution: show key system
    TweenService:Create(LoadingContainer, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {GroupTransparency = 1}):Play()
    task.wait(0.35)
    LoadingContainer.Visible = false
    ContentContainer.Visible = true
    TweenService:Create(ContentContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {GroupTransparency = 0}):Play()
    task.spawn(function()
        while KeyGui and KeyGui.Parent do
            TextShineGradient.Offset = Vector2.new(-1.2, 0)
            local titleShine = TweenService:Create(TextShineGradient, TweenInfo.new(1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Offset = Vector2.new(1.2, 0)})
            titleShine:Play()
            titleShine.Completed:Wait()
            task.wait(1.6)
        end
    end)
end)
