--[[
    chan chan GUI — Liquid Glass UI
    Single-file Roblox Lua/Luau interface.

    IMPORTANT:
    - This file implements the interface and its local UI state only.
    - Farm/Combat/Quest/Item actions are NOT connected to gameplay automation.
      Their switches are explicitly UI-only and do not pretend to run tasks.
    - For Roblox Studio, run as a LocalScript (for example in StarterPlayerScripts).
      Executor compatibility depends on the executor's supported Roblox APIs.
    - Uses Roblox standard UI/TweenService APIs; no external libraries or URLs.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
if not player then
    warn("[chan chan] LocalPlayer is unavailable; run this from a client context.")
    return
end

local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui", 10)
if not playerGui then
    warn("[chan chan] PlayerGui is unavailable.")
    return
end

-- Avoid duplicate copies if the script is executed more than once.
local previous = playerGui:FindFirstChild("ChanChanLiquidGlass")
if previous then
    previous:Destroy()
end

local COLORS = {
    window = Color3.fromRGB(17, 19, 23),
    panel = Color3.fromRGB(25, 28, 33),
    panel2 = Color3.fromRGB(31, 35, 41),
    white = Color3.fromRGB(246, 249, 255),
    secondary = Color3.fromRGB(163, 172, 185),
    border = Color3.fromRGB(166, 211, 232),
    accent = Color3.fromRGB(112, 174, 226),
    accent2 = Color3.fromRGB(126, 151, 225),
    green = Color3.fromRGB(103, 203, 143),
    off = Color3.fromRGB(74, 81, 91),
    danger = Color3.fromRGB(216, 111, 120),
}

local state = {
    page = "Trang chủ",
    minimized = false,
    islandHidden = false,
    confirmOpen = false,
    closed = false,
    reduceMotion = false,
    optimizeEffects = true,
    switches = {
        ["Auto Farm"] = false,
        ["Auto Quest"] = false,
        ["Auto Attack"] = false,
        ["Auto Collect"] = false,
        ["Fast Mode"] = false,
    },
}

local connections = {}
local activeTweens = {}
local uiObjects = {}
local pageButtons = {}
local switchRefreshers = {}
local currentPageContent
local confirmOverlay
local mainWindow
local island
local miniButton
local screenGui
local viewportConnection
local dragging = false
local dragStart
local windowStart
local dragInput
local touchInput

local function trackConnection(connection)
    table.insert(connections, connection)
    return connection
end

local function safeDisconnect(connection)
    if connection then
        pcall(function() connection:Disconnect() end)
    end
end

local function make(className, props, parent)
    local object = Instance.new(className)
    for key, value in pairs(props or {}) do
        pcall(function() object[key] = value end)
    end
    if parent then object.Parent = parent end
    table.insert(uiObjects, object)
    return object
end

local function corner(parent, radius)
    return make("UICorner", {CornerRadius = UDim.new(0, radius or 14)}, parent)
end

local function stroke(parent, color, transparency, thickness)
    return make("UIStroke", {
        Color = color or COLORS.border,
        Transparency = transparency == nil and 0.72 or transparency,
        Thickness = thickness or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function gradient(parent, c1, c2, rotation)
    return make("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, c1 or COLORS.panel2),
            ColorSequenceKeypoint.new(1, c2 or COLORS.window),
        }),
        Rotation = rotation or 90,
    }, parent)
end

local function tween(object, duration, properties, style, direction)
    if state.closed or not object or not object.Parent then return nil end
    local old = activeTweens[object]
    if old then
        pcall(function() old:Cancel() end)
    end
    if state.reduceMotion then
        for property, value in pairs(properties) do
            pcall(function() object[property] = value end)
        end
        activeTweens[object] = nil
        return nil
    end
    local info = TweenInfo.new(
        duration or 0.18,
        style or Enum.EasingStyle.Quad,
        direction or Enum.EasingDirection.Out
    )
    local newTween
    local ok = pcall(function()
        newTween = TweenService:Create(object, info, properties)
    end)
    if ok and newTween then
        activeTweens[object] = newTween
        newTween.Completed:Connect(function()
            if activeTweens[object] == newTween then
                activeTweens[object] = nil
            end
        end)
        newTween:Play()
        return newTween
    end
    for property, value in pairs(properties) do
        pcall(function() object[property] = value end)
    end
    return nil
end

local function label(parent, text, size, color, font, xAlign)
    return make("TextLabel", {
        BackgroundTransparency = 1,
        Text = text or "",
        TextColor3 = color or COLORS.white,
        TextSize = size or 14,
        Font = font or Enum.Font.Gotham,
        TextXAlignment = xAlign or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = true,
        RichText = false,
    }, parent)
end

local function button(parent, text, size, position, bg)
    local b = make("TextButton", {
        AutoButtonColor = false,
        Text = text,
        TextSize = 14,
        Font = Enum.Font.GothamMedium,
        TextColor3 = COLORS.white,
        BackgroundColor3 = bg or COLORS.panel2,
        BackgroundTransparency = 0.08,
        Size = size,
        Position = position,
    }, parent)
    corner(b, 12)
    stroke(b, COLORS.border, 0.78, 1)
    trackConnection(b.Activated:Connect(function()
        if state.closed then return end
        tween(b, 0.12, {BackgroundTransparency = 0.02})
        task.delay(0.12, function()
            if b.Parent and not state.closed then
                tween(b, 0.16, {BackgroundTransparency = 0.08})
            end
        end)
    end))
    return b
end

screenGui = make("ScreenGui", {
    Name = "ChanChanLiquidGlass",
    ResetOnSpawn = false,
    IgnoreGuiInset = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 100,
}, playerGui)

local scale = make("UIScale", {Scale = 1}, screenGui)

local function viewport()
    local camera = workspace.CurrentCamera
    if camera then
        return camera.ViewportSize
    end
    return Vector2.new(800, 600)
end

local function updateScale()
    if state.closed then return end
    local size = viewport()
    local minDimension = math.min(size.X, size.Y)
    local target = 1
    if size.X < 520 then
        target = math.clamp(size.X / 420, 0.78, 1)
    elseif minDimension < 500 then
        target = 0.88
    elseif size.X >= 1100 then
        target = 1
    end
    scale.Scale = target
    if mainWindow then
        local width = math.clamp(size.X - 24, 300, 690)
        local height = math.clamp(size.Y - 100, 350, 470)
        mainWindow.Size = UDim2.fromOffset(width, height)
        mainWindow.Position = UDim2.new(0.5, 0, 0.53, 0)
    end
    if island then
        island.Position = UDim2.new(0.5, 0, 0, 8)
    end
    if miniButton then
        miniButton.Position = UDim2.new(0, 12, 0.48, 0)
    end
end

-- Dynamic Island is a single persistent component, independent of the main window.
island = make("TextButton", {
    Name = "DynamicIsland",
    AutoButtonColor = false,
    Text = "",
    BackgroundColor3 = Color3.fromRGB(4, 5, 7),
    BackgroundTransparency = 0.02,
    Size = UDim2.fromOffset(220, 48),
    Position = UDim2.new(0.5, 0, 0, 8),
    AnchorPoint = Vector2.new(0.5, 0),
    ZIndex = 20,
}, screenGui)
corner(island, 24)
stroke(island, COLORS.border, 0.48, 1)

local islandCrown = label(island, "♛", 21, COLORS.white, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
islandCrown.Size = UDim2.fromOffset(30, 36)
islandCrown.Position = UDim2.fromOffset(9, 6)
islandCrown.ZIndex = 21

local islandName = label(island, "chan chan", 13, COLORS.white, Enum.Font.GothamSemibold)
islandName.Position = UDim2.fromOffset(43, 5)
islandName.Size = UDim2.fromOffset(104, 20)
islandName.ZIndex = 21

local islandStatus = label(island, "Đang hoạt động", 10, COLORS.secondary, Enum.Font.Gotham)
islandStatus.Position = UDim2.fromOffset(43, 24)
islandStatus.Size = UDim2.fromOffset(120, 15)
islandStatus.ZIndex = 21

local statusDot = make("Frame", {
    BackgroundColor3 = COLORS.green,
    Size = UDim2.fromOffset(7, 7),
    Position = UDim2.new(1, -20, 0.5, -3),
    ZIndex = 21,
}, island)
corner(statusDot, 5)

-- Main window
mainWindow = make("Frame", {
    Name = "MainWindow",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.53, 0),
    Size = UDim2.fromOffset(610, 430),
    BackgroundColor3 = COLORS.window,
    BackgroundTransparency = 0.06,
    ClipsDescendants = true,
    ZIndex = 2,
}, screenGui)
corner(mainWindow, 18)
stroke(mainWindow, COLORS.border, 0.48, 1)
gradient(mainWindow, Color3.fromRGB(30, 34, 41), COLORS.window, 110)

local windowScale = make("UIScale", {Scale = 1}, mainWindow)

local topBar = make("Frame", {
    Name = "TopBar",
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, 70),
    ZIndex = 3,
}, mainWindow)

local crown = label(topBar, "♛", 29, COLORS.white, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
crown.Position = UDim2.fromOffset(14, 14)
crown.Size = UDim2.fromOffset(40, 40)

local title = label(topBar, "chan chan", 19, COLORS.white, Enum.Font.GothamBold)
title.Position = UDim2.fromOffset(59, 12)
title.Size = UDim2.fromOffset(170, 27)

local subtitle = label(topBar, "Simple • Fast • Smooth", 11, COLORS.secondary, Enum.Font.Gotham)
subtitle.Position = UDim2.fromOffset(60, 37)
subtitle.Size = UDim2.fromOffset(180, 18)

local closeButton = button(topBar, "X", UDim2.fromOffset(36, 34), UDim2.new(1, -48, 0, 17), Color3.fromRGB(59, 35, 40))
local islandButton = button(topBar, "%", UDim2.fromOffset(36, 34), UDim2.new(1, -91, 0, 17))
local minimizeButton = button(topBar, "−", UDim2.fromOffset(36, 34), UDim2.new(1, -134, 0, 17))

local divider = make("Frame", {
    BackgroundColor3 = COLORS.border,
    BackgroundTransparency = 0.82,
    BorderSizePixel = 0,
    Position = UDim2.fromOffset(14, 69),
    Size = UDim2.new(1, -28, 0, 1),
    ZIndex = 3,
}, mainWindow)

local sidebar = make("Frame", {
    Name = "Sidebar",
    BackgroundColor3 = COLORS.panel,
    BackgroundTransparency = 0.18,
    Position = UDim2.fromOffset(12, 82),
    Size = UDim2.new(0, 142, 1, -94),
    ZIndex = 3,
}, mainWindow)
corner(sidebar, 14)
stroke(sidebar, COLORS.border, 0.87, 1)

local sidePadding = make("UIPadding", {
    PaddingTop = UDim.new(0, 10),
    PaddingLeft = UDim.new(0, 8),
    PaddingRight = UDim.new(0, 8),
}, sidebar)

local sideLayout = make("UIListLayout", {
    Padding = UDim.new(0, 7),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, sidebar)

local content = make("Frame", {
    Name = "Content",
    BackgroundColor3 = COLORS.panel,
    BackgroundTransparency = 0.2,
    Position = UDim2.fromOffset(166, 82),
    Size = UDim2.new(1, -178, 1, -94),
    ClipsDescendants = true,
    ZIndex = 3,
}, mainWindow)
corner(content, 14)
stroke(content, COLORS.border, 0.87, 1)

local contentPadding = make("UIPadding", {
    PaddingTop = UDim.new(0, 14),
    PaddingLeft = UDim.new(0, 14),
    PaddingRight = UDim.new(0, 14),
    PaddingBottom = UDim.new(0, 12),
}, content)

local pages = {"Trang chủ", "Farm", "Combat", "Quest", "Vật phẩm", "Cài đặt"}

local function clearPage()
    if currentPageContent then
        currentPageContent:Destroy()
        currentPageContent = nil
    end
end

local function createPageRoot()
    clearPage()
    currentPageContent = make("Frame", {
        Name = "Page_" .. state.page,
        BackgroundTransparency = 1,
        Size = UDim2.fromScale(1, 1),
        Position = UDim2.fromOffset(0, 0),
        ZIndex = 4,
    }, content)
    return currentPageContent
end

local function pageHeading(parent, heading, subheading)
    local h = label(parent, heading, 20, COLORS.white, Enum.Font.GothamBold)
    h.Position = UDim2.fromOffset(0, 0)
    h.Size = UDim2.new(1, 0, 0, 30)
    local s = label(parent, subheading or "", 11, COLORS.secondary, Enum.Font.Gotham)
    s.Position = UDim2.fromOffset(0, 30)
    s.Size = UDim2.new(1, 0, 0, 30)
end

local function infoCard(parent, y, heading, body)
    local card = make("Frame", {
        BackgroundColor3 = COLORS.panel2,
        BackgroundTransparency = 0.14,
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.new(1, 0, 0, 76),
        ZIndex = 5,
    }, parent)
    corner(card, 12)
    stroke(card, COLORS.border, 0.9, 1)
    local h = label(card, heading, 13, COLORS.white, Enum.Font.GothamSemibold)
    h.Position = UDim2.fromOffset(12, 8)
    h.Size = UDim2.new(1, -24, 0, 22)
    local b = label(card, body, 11, COLORS.secondary, Enum.Font.Gotham)
    b.Position = UDim2.fromOffset(12, 31)
    b.Size = UDim2.new(1, -24, 0, 34)
    b.TextYAlignment = Enum.TextYAlignment.Top
    return card
end

local function makeSwitchRow(parent, name, y, description)
    local row = make("Frame", {
        BackgroundColor3 = COLORS.panel2,
        BackgroundTransparency = 0.12,
        Position = UDim2.fromOffset(0, y),
        Size = UDim2.new(1, 0, 0, 56),
        ZIndex = 5,
    }, parent)
    corner(row, 11)
    stroke(row, COLORS.border, 0.91, 1)

    local nameLabel = label(row, name, 12, COLORS.white, Enum.Font.GothamSemibold)
    nameLabel.Position = UDim2.fromOffset(11, 7)
    nameLabel.Size = UDim2.new(1, -88, 0, 21)

    local desc = label(row, description or "Chỉ lưu trạng thái giao diện", 9, COLORS.secondary, Enum.Font.Gotham)
    desc.Position = UDim2.fromOffset(11, 29)
    desc.Size = UDim2.new(1, -88, 0, 17)

    local track = make("TextButton", {
        AutoButtonColor = false,
        Text = "",
        BackgroundColor3 = state.switches[name] and COLORS.green or COLORS.off,
        Position = UDim2.new(1, -61, 0.5, -13),
        Size = UDim2.fromOffset(49, 26),
        ZIndex = 6,
    }, row)
    corner(track, 14)
    stroke(track, COLORS.border, 0.84, 1)

    local knob = make("Frame", {
        BackgroundColor3 = COLORS.white,
        Position = UDim2.fromOffset(state.switches[name] and 26 or 3, 3),
        Size = UDim2.fromOffset(20, 20),
        ZIndex = 7,
    }, track)
    corner(knob, 11)

    local function refresh(animate)
        local enabled = state.switches[name]
        local pos = UDim2.fromOffset(enabled and 26 or 3, 3)
        local color = enabled and COLORS.green or COLORS.off
        if animate then
            tween(knob, 0.16, {Position = pos})
            tween(track, 0.16, {BackgroundColor3 = color})
        else
            knob.Position = pos
            track.BackgroundColor3 = color
        end
    end
    switchRefreshers[name] = refresh

    trackConnection(track.Activated:Connect(function()
        if state.closed then return end
        state.switches[name] = not state.switches[name]
        refresh(true)
        -- Deliberately UI-only: no gameplay automation is attached to this switch.
        islandStatus.Text = "Trạng thái giao diện"
        task.delay(1.2, function()
            if islandStatus and islandStatus.Parent and not state.closed then
                islandStatus.Text = "Đang hoạt động"
            end
        end)
    end))
    return row
end

local function renderPage()
    if state.closed then return end
    local root = createPageRoot()

    if state.page == "Trang chủ" then
        local hero = make("Frame", {
            BackgroundColor3 = COLORS.panel2,
            BackgroundTransparency = 0.12,
            Position = UDim2.fromOffset(0, 0),
            Size = UDim2.new(1, 0, 0, 142),
            ZIndex = 5,
        }, root)
        corner(hero, 14)
        stroke(hero, COLORS.border, 0.8, 1)
        local heroCrown = label(hero, "♛", 38, COLORS.white, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
        heroCrown.Position = UDim2.new(0.5, -32, 0, 15)
        heroCrown.Size = UDim2.fromOffset(64, 48)
        local heroTitle = label(hero, "chan chan", 22, COLORS.white, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
        heroTitle.Position = UDim2.new(0, 0, 0, 65)
        heroTitle.Size = UDim2.new(1, 0, 0, 30)
        local welcome = label(hero, "Chào mừng bạn đến với menu!", 12, COLORS.secondary, Enum.Font.Gotham, Enum.TextXAlignment.Center)
        welcome.Position = UDim2.new(0, 8, 0, 99)
        welcome.Size = UDim2.new(1, -16, 0, 24)

        infoCard(root, 154, "Liquid Glass UI", "Giao diện nhẹ, không thay đổi Lighting, camera hoặc thế giới trò chơi.")
        infoCard(root, 240, "Lưu ý về chức năng", "Các công tắc Farm chỉ lưu trạng thái giao diện; chúng không tự động điều khiển trò chơi.")
    elseif state.page == "Farm" then
        pageHeading(root, "Farm", "Công tắc trạng thái giao diện — chưa kết nối gameplay.")
        makeSwitchRow(root, "Auto Farm", 66, "UI-only • Không tự động farm")
        makeSwitchRow(root, "Auto Quest", 128, "UI-only • Không tự nhận quest")
        makeSwitchRow(root, "Auto Attack", 190, "UI-only • Không tự tấn công")
        makeSwitchRow(root, "Auto Collect", 252, "UI-only • Không tự nhặt vật phẩm")
        makeSwitchRow(root, "Fast Mode", 314, "UI-only • Không thay đổi tốc độ trò chơi")
    elseif state.page == "Combat" then
        pageHeading(root, "Combat", "Công cụ giao diện")
        infoCard(root, 66, "Chưa kết nối", "Không có hành động chiến đấu được triển khai trong file này.")
    elseif state.page == "Quest" then
        pageHeading(root, "Quest", "Theo dõi giao diện")
        infoCard(root, 66, "Chưa kết nối", "Không có logic nhận hoặc hoàn thành nhiệm vụ giả lập.")
    elseif state.page == "Vật phẩm" then
        pageHeading(root, "Vật phẩm", "Thông tin")
        infoCard(root, 66, "Chưa kết nối", "Trang này chưa thao tác với kho đồ trong trò chơi.")
    elseif state.page == "Cài đặt" then
        pageHeading(root, "Cài đặt", "Chỉ gồm các tùy chọn giao diện cần thiết.")
        local opt = button(root, "Tối ưu hiệu ứng: ON", UDim2.new(1, 0, 0, 42), UDim2.fromOffset(0, 68))
        local motion = button(root, "Giảm chuyển động: OFF", UDim2.new(1, 0, 0, 42), UDim2.fromOffset(0, 120))
        local version = label(root, "Phiên bản 1.0 • UI-only", 11, COLORS.secondary, Enum.Font.Gotham)
        version.Position = UDim2.fromOffset(0, 176)
        version.Size = UDim2.new(1, 0, 0, 25)

        trackConnection(opt.Activated:Connect(function()
            state.optimizeEffects = not state.optimizeEffects
            opt.Text = "Tối ưu hiệu ứng: " .. (state.optimizeEffects and "ON" or "OFF")
            -- This UI is already intentionally lightweight; OFF only changes the setting label.
        end))
        trackConnection(motion.Activated:Connect(function()
            state.reduceMotion = not state.reduceMotion
            motion.Text = "Giảm chuyển động: " .. (state.reduceMotion and "ON" or "OFF")
        end))
    end

    -- Restore switch visuals if the Farm page is re-entered.
    if state.page == "Farm" then
        for name, refresh in pairs(switchRefreshers) do
            if refresh then refresh(false) end
        end
    end
end

local function selectPage(page)
    if state.closed or state.page == page then return end
    state.page = page
    for name, b in pairs(pageButtons) do
        local selected = name == page
        b.BackgroundColor3 = selected and Color3.fromRGB(45, 55, 68) or COLORS.panel2
        b.TextColor3 = selected and COLORS.white or COLORS.secondary
        local st = b:FindFirstChildOfClass("UIStroke")
        if st then st.Transparency = selected and 0.56 or 0.9 end
    end
    renderPage()
    if currentPageContent and not state.reduceMotion then
        currentPageContent.Position = UDim2.fromOffset(7, 0)
        currentPageContent.BackgroundTransparency = 1
        tween(currentPageContent, 0.16, {Position = UDim2.fromOffset(0, 0)})
    end
end

for index, page in ipairs(pages) do
    local b = button(sidebar, page, UDim2.new(1, 0, 0, 42), UDim2.new(), COLORS.panel2)
    b.LayoutOrder = index
    b.TextSize = 12
    b.TextXAlignment = Enum.TextXAlignment.Left
    b.TextColor3 = page == state.page and COLORS.white or COLORS.secondary
    local pad = make("UIPadding", {PaddingLeft = UDim.new(0, 11)}, b)
    local st = b:FindFirstChildOfClass("UIStroke")
    if st then st.Transparency = page == state.page and 0.56 or 0.9 end
    if page == state.page then b.BackgroundColor3 = Color3.fromRGB(45, 55, 68) end
    pageButtons[page] = b
    trackConnection(b.Activated:Connect(function()
        selectPage(page)
    end))
end

-- Confirmation overlay, created once and reused.
confirmOverlay = make("Frame", {
    Name = "ConfirmOverlay",
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BackgroundTransparency = 0.42,
    Size = UDim2.fromScale(1, 1),
    Visible = false,
    ZIndex = 40,
}, mainWindow)

local confirmCard = make("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(290, 155),
    BackgroundColor3 = COLORS.window,
    BackgroundTransparency = 0.02,
    ZIndex = 41,
}, confirmOverlay)
corner(confirmCard, 16)
stroke(confirmCard, COLORS.border, 0.42, 1)

local confirmTitle = label(confirmCard, "Bạn muốn đóng script không?", 14, COLORS.white, Enum.Font.GothamSemibold, Enum.TextXAlignment.Center)
confirmTitle.Position = UDim2.fromOffset(12, 20)
confirmTitle.Size = UDim2.new(1, -24, 0, 42)
confirmTitle.ZIndex = 42

local yesButton = button(confirmCard, "Có", UDim2.fromOffset(112, 38), UDim2.new(0, 22, 1, -55), Color3.fromRGB(69, 43, 48))
yesButton.ZIndex = 43
local noButton = button(confirmCard, "Không", UDim2.fromOffset(112, 38), UDim2.new(1, -134, 1, -55), COLORS.panel2)
noButton.ZIndex = 43

local function openConfirm()
    if state.closed or state.confirmOpen then return end
    state.confirmOpen = true
    confirmOverlay.Visible = true
    confirmOverlay.BackgroundTransparency = state.reduceMotion and 0.42 or 1
    confirmCard.Size = UDim2.fromOffset(270, 145)
    tween(confirmOverlay, 0.16, {BackgroundTransparency = 0.42})
    tween(confirmCard, 0.18, {Size = UDim2.fromOffset(290, 155)})
end

local function closeConfirm()
    state.confirmOpen = false
    confirmOverlay.Visible = false
end

local function cleanup()
    if state.closed then return end
    state.closed = true
    for _, t in pairs(activeTweens) do
        pcall(function() t:Cancel() end)
    end
    table.clear(activeTweens)
    for _, c in ipairs(connections) do
        safeDisconnect(c)
    end
    table.clear(connections)
    safeDisconnect(viewportConnection)
    viewportConnection = nil
    if screenGui then
        pcall(function() screenGui:Destroy() end)
    end
    table.clear(uiObjects)
end

local function showMain()
    if state.closed then return end
    state.minimized = false
    state.islandHidden = false
    if miniButton then miniButton.Visible = false end
    mainWindow.Visible = true
    mainWindow.BackgroundTransparency = state.reduceMotion and 0.06 or 1
    windowScale.Scale = state.reduceMotion and 1 or 0.94
    tween(mainWindow, 0.2, {BackgroundTransparency = 0.06})
    tween(windowScale, 0.2, {Scale = 1})
end

local function hideToIsland()
    if state.closed then return end
    state.islandHidden = true
    state.minimized = false
    if miniButton then miniButton.Visible = false end
    if state.reduceMotion then
        mainWindow.Visible = false
    else
        tween(windowScale, 0.16, {Scale = 0.88})
        tween(mainWindow, 0.16, {BackgroundTransparency = 1})
        task.delay(0.17, function()
            if not state.closed and state.islandHidden and mainWindow then
                mainWindow.Visible = false
            end
        end)
    end
end

local function minimizeToCircle()
    if state.closed then return end
    state.minimized = true
    state.islandHidden = false
    mainWindow.Visible = false
    if not miniButton then
        miniButton = make("TextButton", {
            Name = "MiniLogo",
            AutoButtonColor = false,
            Text = "♛",
            TextSize = 27,
            Font = Enum.Font.GothamBold,
            TextColor3 = COLORS.white,
            BackgroundColor3 = COLORS.window,
            BackgroundTransparency = 0.03,
            Size = UDim2.fromOffset(54, 54),
            Position = UDim2.new(0, 12, 0.48, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            ZIndex = 25,
        }, screenGui)
        corner(miniButton, 27)
        stroke(miniButton, COLORS.border, 0.42, 1)
        trackConnection(miniButton.Activated:Connect(showMain))
    end
    miniButton.Visible = true
    miniButton.Size = UDim2.fromOffset(46, 46)
    tween(miniButton, 0.18, {Size = UDim2.fromOffset(54, 54)})
end

trackConnection(closeButton.Activated:Connect(openConfirm))
trackConnection(noButton.Activated:Connect(closeConfirm))
trackConnection(yesButton.Activated:Connect(cleanup))
trackConnection(minimizeButton.Activated:Connect(minimizeToCircle))
trackConnection(islandButton.Activated:Connect(hideToIsland))
trackConnection(island.Activated:Connect(showMain))

-- Dragging via the title bar; does not change camera or game world.
local function updateDrag(input)
    if not dragging or not dragStart or not windowStart or state.closed then return end
    local delta = input.Position - dragStart
    local size = viewport()
    local halfW = mainWindow.AbsoluteSize.X * 0.5
    local halfH = mainWindow.AbsoluteSize.Y * 0.5
    -- Convert the original scale-based center into pixel coordinates, then apply drag delta.
    local originalCenterX = size.X * windowStart.X.Scale + windowStart.X.Offset
    local originalCenterY = size.Y * windowStart.Y.Scale + windowStart.Y.Offset
    local centerX = math.clamp(originalCenterX + delta.X, halfW + 4, size.X - halfW - 4)
    local centerY = math.clamp(originalCenterY + delta.Y, halfH + 4, size.Y - halfH - 4)
    mainWindow.Position = UDim2.fromOffset(centerX, centerY)
end

trackConnection(topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        windowStart = mainWindow.Position
        touchInput = input.UserInputType == Enum.UserInputType.Touch and input or nil
    end
end))

trackConnection(topBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end))

trackConnection(UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        updateDrag(input)
    end
end))

trackConnection(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or (touchInput and input == touchInput) then
        dragging = false
        dragStart = nil
        windowStart = nil
        touchInput = nil
    end
end))

-- Optional keyboard shortcut; touch controls remain available for every action.
trackConnection(UserInputService.InputBegan:Connect(function(input, processed)
    if processed or state.closed then return end
    if input.KeyCode == Enum.KeyCode.Percent or input.KeyCode == Enum.KeyCode.KeypadDivide then
        hideToIsland()
    elseif input.KeyCode == Enum.KeyCode.Escape and state.confirmOpen then
        closeConfirm()
    end
end))

-- Update only on viewport changes, not every frame.
local function bindViewport()
    safeDisconnect(viewportConnection)
    local camera = workspace.CurrentCamera
    if camera then
        viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
    end
    updateScale()
end

trackConnection(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindViewport))
bindViewport()
renderPage()

-- Initial gentle entrance.
mainWindow.Visible = true
if not state.reduceMotion then
    mainWindow.BackgroundTransparency = 1
    windowScale.Scale = 0.94
    tween(mainWindow, 0.22, {BackgroundTransparency = 0.06})
    tween(windowScale, 0.22, {Scale = 1})
end

-- Keep references only while alive; all GUI pieces are children of this ScreenGui.
print("[chan chan] Liquid Glass UI loaded. Gameplay switches are UI-only.")
