--[[
    chan chan - Liquid Glass GUI
    Tác giả: Nam HUB
    Đặt LocalScript này trong StarterPlayer > StarterPlayerScripts.

    Lưu ý:
    - GUI chỉ chạy phía client.
    - Tuỳ chọn được giữ trong phiên chạy hiện tại (không lưu qua lần vào game khác).
    - Roblox không hỗ trợ blur riêng bên trong một Frame; hiệu ứng kính được mô phỏng
      bằng nền bán trong suốt, gradient, viền sáng và bóng đổ.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Dọn bản cũ nếu LocalScript được chạy lại
local oldGui = playerGui:FindFirstChild("ChanChanLiquidGlass")
if oldGui then
    oldGui:Destroy()
end

local CONFIG = {
    Name = "chan chan",
    Version = "v1.0.0",
    Author = "Nam HUB",
    Accent = Color3.fromRGB(37, 164, 255),
    BackgroundOpacity = 0.60,
    InterfaceTransparency = 0.80,
    Brightness = 16,
    Theme = "Sáng",
    DisplayMode = "Trong suốt",
    SystemNotifications = true,
    ScriptNotifications = true,
}

local palette = {
    ["xanh dương"] = Color3.fromRGB(40, 174, 255),
    ["tím"] = Color3.fromRGB(139, 83, 255),
    ["hồng"] = Color3.fromRGB(255, 75, 177),
    ["xanh ngọc"] = Color3.fromRGB(0, 207, 193),
    ["cam"] = Color3.fromRGB(255, 151, 37),
}
local rainbow = false
local connections = {}
local function track(connection)
    table.insert(connections, connection)
    return connection
end

local function make(className, properties, parent)
    local object = Instance.new(className)
    for key, value in pairs(properties or {}) do
        object[key] = value
    end
    object.Parent = parent
    return object
end

local function corner(parent, radius)
    return make("UICorner", {CornerRadius = UDim.new(0, radius or 16)}, parent)
end

local function stroke(parent, color, thickness, transparency)
    return make("UIStroke", {
        Color = color or Color3.new(1, 1, 1),
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, parent)
end

local function gradient(parent, colors, rotation)
    return make("UIGradient", {
        Color = ColorSequence.new(colors),
        Rotation = rotation or 0,
    }, parent)
end

local function tween(object, duration, properties, style, direction)
    if not object or not object.Parent then return nil end
    local info = TweenInfo.new(duration or 0.22, style or Enum.EasingStyle.Quint,
        direction or Enum.EasingDirection.Out)
    local animation = TweenService:Create(object, info, properties)
    animation:Play()
    return animation
end

local function newLabel(parent, text, size, position, fontSize, color, bold)
    return make("TextLabel", {
        BackgroundTransparency = 1,
        Text = text,
        Size = size,
        Position = position,
        Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        TextSize = fontSize or 16,
        TextColor3 = color or Color3.fromRGB(18, 82, 153),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        TextWrapped = true,
    }, parent)
end

local function newButton(parent, text, size, position, fontSize)
    local button = make("TextButton", {
        AutoButtonColor = false,
        Text = text,
        Size = size,
        Position = position,
        BackgroundColor3 = Color3.fromRGB(230, 246, 255),
        BackgroundTransparency = 0.18,
        Font = Enum.Font.GothamSemibold,
        TextSize = fontSize or 15,
        TextColor3 = Color3.fromRGB(22, 91, 160),
    }, parent)
    corner(button, 12)
    stroke(button, Color3.fromRGB(255, 255, 255), 1, 0.40)
    track(button.Activated:Connect(function()
        if button.Parent then
            tween(button, 0.08, {BackgroundTransparency = 0.02})
            task.delay(0.09, function()
                if button.Parent then tween(button, 0.16, {BackgroundTransparency = 0.18}) end
            end)
        end
    end))
    return button
end

local gui = make("ScreenGui", {
    Name = "ChanChanLiquidGlass",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 50,
}, playerGui)

-- Lớp nền trong suốt phủ màn hình, không chặn thao tác ở ngoài cửa sổ
local island = make("Frame", {
    Name = "DynamicIsland",
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 14),
    Size = UDim2.new(0, 330, 0, 54),
    BackgroundColor3 = Color3.fromRGB(12, 43, 104),
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
    ZIndex = 20,
}, gui)
corner(island, 28)
gradient(island, {
    ColorSequenceKeypoint.new(0, Color3.fromRGB(5, 52, 125)),
    ColorSequenceKeypoint.new(0.55, Color3.fromRGB(30, 62, 150)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(112, 47, 177)),
}, 0)
local islandStroke = stroke(island, CONFIG.Accent, 2, 0.05)
local islandGlow = make("Frame", {
    BackgroundColor3 = CONFIG.Accent,
    BackgroundTransparency = 0.88,
    Size = UDim2.new(1, 10, 1, 10),
    Position = UDim2.new(0, -5, 0, -5),
    ZIndex = 19,
}, island)
corner(islandGlow, 34)

local crown = newLabel(island, "♛", UDim2.new(0, 34, 1, 0), UDim2.new(0, 12, 0, 0), 27,
    Color3.fromRGB(145, 225, 255), true)
crown.TextXAlignment = Enum.TextXAlignment.Center
local islandName = newLabel(island, "chan chan", UDim2.new(0, 100, 1, 0), UDim2.new(0, 54, 0, 0), 15,
    Color3.new(1, 1, 1), true)
local separator = make("Frame", {
    Size = UDim2.new(0, 1, 0, 25),
    Position = UDim2.new(0, 160, 0.5, -12),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BackgroundTransparency = 0.55,
    BorderSizePixel = 0,
    ZIndex = 21,
}, island)
local timerLabel = newLabel(island, "00:00:00", UDim2.new(0, 84, 1, 0), UDim2.new(0, 172, 0, 0), 15,
    Color3.new(1, 1, 1), false)
local pauseButton = newButton(island, "Ⅱ", UDim2.new(0, 38, 0, 38), UDim2.new(1, -82, 0.5, -19), 20)
pauseButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
pauseButton.BackgroundTransparency = 0.82
pauseButton.TextColor3 = Color3.new(1, 1, 1)
pauseButton.ZIndex = 22
local islandSettings = newButton(island, "⚙", UDim2.new(0, 38, 0, 38), UDim2.new(1, -38, 0.5, -19), 20)
islandSettings.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
islandSettings.BackgroundTransparency = 0.82
islandSettings.TextColor3 = Color3.new(1, 1, 1)
islandSettings.ZIndex = 22

-- Cửa sổ chính: kích thước theo viewport, có giới hạn cho điện thoại và PC
local shadow = make("Frame", {
    Name = "WindowShadow",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.56, 0),
    Size = UDim2.new(0.88, 0, 0.78, 0),
    BackgroundColor3 = Color3.fromRGB(17, 104, 210),
    BackgroundTransparency = 0.78,
    BorderSizePixel = 0,
    ZIndex = 1,
}, gui)
corner(shadow, 28)

local window = make("Frame", {
    Name = "MainWindow",
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.56, 0),
    Size = UDim2.new(0.88, 0, 0.78, 0),
    BackgroundColor3 = Color3.fromRGB(209, 239, 255),
    BackgroundTransparency = 0.12,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    ZIndex = 2,
}, gui)
corner(window, 26)
local windowStroke = stroke(window, Color3.fromRGB(255, 255, 255), 2, 0.08)
gradient(window, {
    ColorSequenceKeypoint.new(0, Color3.fromRGB(223, 246, 255)),
    ColorSequenceKeypoint.new(0.52, Color3.fromRGB(184, 225, 255)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(223, 213, 255)),
}, 25)

local scale = make("UIScale", {Scale = 1}, window)
local sidebar = make("Frame", {
    Name = "Sidebar",
    Size = UDim2.new(0.225, 0, 1, 0),
    BackgroundColor3 = Color3.fromRGB(30, 108, 193),
    BackgroundTransparency = 0.14,
    BorderSizePixel = 0,
    ZIndex = 3,
}, window)
corner(sidebar, 24)
gradient(sidebar, {
    ColorSequenceKeypoint.new(0, Color3.fromRGB(48, 139, 220)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(37, 87, 177)),
}, 90)
-- Che mép bo góc phía phải của sidebar để tạo cạnh thẳng sát vùng nội dung
make("Frame", {
    Size = UDim2.new(0, 24, 1, 0),
    Position = UDim2.new(1, -24, 0, 0),
    BackgroundColor3 = Color3.fromRGB(37, 103, 190),
    BackgroundTransparency = 0.15,
    BorderSizePixel = 0,
    ZIndex = 3,
}, sidebar)

local sideCrown = newLabel(sidebar, "♛", UDim2.new(0, 46, 0, 46), UDim2.new(0, 18, 0, 18), 34,
    Color3.fromRGB(173, 241, 255), true)
sideCrown.TextXAlignment = Enum.TextXAlignment.Center
local sideTitle = newLabel(sidebar, "chan chan", UDim2.new(1, -78, 0, 30), UDim2.new(0, 68, 0, 18), 20,
    Color3.new(1, 1, 1), true)
local sideSubtitle = newLabel(sidebar, "Script by Nam HUB", UDim2.new(1, -24, 0, 22), UDim2.new(0, 68, 0, 46), 12,
    Color3.fromRGB(236, 247, 255), false)

local minimizeButton = newButton(window, "−", UDim2.new(0, 34, 0, 30), UDim2.new(1, -152, 0, 12), 24)
local maximizeButton = newButton(window, "□", UDim2.new(0, 34, 0, 30), UDim2.new(1, -108, 0, 12), 20)
local closeButton = newButton(window, "×", UDim2.new(0, 34, 0, 30), UDim2.new(1, -64, 0, 12), 25)
for _, b in ipairs({minimizeButton, maximizeButton, closeButton}) do
    b.BackgroundTransparency = 1
    b.TextColor3 = Color3.fromRGB(255, 255, 255)
    b.ZIndex = 10
end

local tabSettings = newButton(sidebar, "⚙   Cài đặt", UDim2.new(1, -26, 0, 52), UDim2.new(0, 13, 0, 94), 16)
tabSettings.TextXAlignment = Enum.TextXAlignment.Left
tabSettings.TextColor3 = Color3.new(1, 1, 1)
tabSettings.BackgroundColor3 = CONFIG.Accent
tabSettings.BackgroundTransparency = 0.05
tabSettings.ZIndex = 5
local tabInfo = newButton(sidebar, "●   Thông tin", UDim2.new(1, -26, 0, 52), UDim2.new(0, 13, 0, 156), 16)
tabInfo.TextXAlignment = Enum.TextXAlignment.Left
tabInfo.TextColor3 = Color3.new(1, 1, 1)
tabInfo.BackgroundTransparency = 1
tabInfo.ZIndex = 5

local footerLine = make("Frame", {
    Size = UDim2.new(1, -34, 0, 1),
    Position = UDim2.new(0, 17, 1, -91),
    BackgroundColor3 = Color3.fromRGB(220, 245, 255),
    BackgroundTransparency = 0.55,
    BorderSizePixel = 0,
    ZIndex = 5,
}, sidebar)
local footerCrown = newLabel(sidebar, "♛", UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 1, -84), 23,
    Color3.fromRGB(173, 241, 255), true)
footerCrown.TextXAlignment = Enum.TextXAlignment.Center
local footerName = newLabel(sidebar, "chan chan", UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 1, -58), 14,
    Color3.new(1, 1, 1), true)
footerName.TextXAlignment = Enum.TextXAlignment.Center
local footerBy = newLabel(sidebar, "Script by Nam HUB", UDim2.new(1, -20, 0, 20), UDim2.new(0, 10, 1, -34), 11,
    Color3.fromRGB(230, 246, 255), false)
footerBy.TextXAlignment = Enum.TextXAlignment.Center

local content = make("Frame", {
    Name = "Content",
    Position = UDim2.new(0.225, 0, 0, 0),
    Size = UDim2.new(0.775, 0, 1, 0),
    BackgroundTransparency = 1,
    ZIndex = 4,
}, window)

local pageTitle = newLabel(content, "⚙  Cài đặt", UDim2.new(1, -180, 0, 36), UDim2.new(0, 22, 0, 48), 25,
    Color3.fromRGB(17, 82, 155), true)
local pageSubtitle = newLabel(content, "Tùy chỉnh giao diện và trải nghiệm theo ý thích của bạn",
    UDim2.new(1, -32, 0, 24), UDim2.new(0, 24, 0, 78), 13, Color3.fromRGB(75, 130, 184), false)

local function panel(parent, name, position, size)
    local p = make("Frame", {
        Name = name,
        Position = position,
        Size = size,
        BackgroundColor3 = Color3.fromRGB(241, 250, 255),
        BackgroundTransparency = 0.26,
        BorderSizePixel = 0,
        ZIndex = 5,
    }, parent)
    corner(p, 20)
    stroke(p, Color3.new(1, 1, 1), 1, 0.48)
    return p
end

local settingsPage = make("Frame", {
    Name = "SettingsPage",
    Position = UDim2.new(0, 12, 0, 110),
    Size = UDim2.new(1, -24, 1, -122),
    BackgroundTransparency = 1,
    ZIndex = 5,
}, content)

local appearancePanel = panel(settingsPage, "GiaoDien", UDim2.new(0, 0, 0, 0), UDim2.new(0.535, -7, 0.72, -6))
local notifyPanel = panel(settingsPage, "ThongBao", UDim2.new(0.535, 7, 0, 0), UDim2.new(0.465, -7, 0.72, -6))
local infoPanel = panel(settingsPage, "ThongTinTomTat", UDim2.new(0, 0, 0.74, 6), UDim2.new(1, 0, 0.26, -6))

newLabel(appearancePanel, "●  Giao diện", UDim2.new(1, -24, 0, 30), UDim2.new(0, 16, 0, 10), 18,
    Color3.fromRGB(23, 99, 174), true)
newLabel(appearancePanel, "Chủ đề", UDim2.new(0.42, 0, 0, 25), UDim2.new(0, 18, 0, 48), 14)
local themeButton = newButton(appearancePanel, "☀  Sáng     ▾", UDim2.new(0.55, -14, 0, 36), UDim2.new(0.42, 0, 0, 46), 14)
newLabel(appearancePanel, "Màu chủ đạo", UDim2.new(1, -36, 0, 24), UDim2.new(0, 18, 0, 88), 14)

local colorNames = {"xanh dương", "tím", "hồng", "xanh ngọc", "cam", "cầu vồng"}
local colorButtons = {}
for i, colorName in ipairs(colorNames) do
    local x = 18 + (i - 1) * 43
    local button = make("TextButton", {
        Name = "Mau_" .. i,
        Text = "",
        AutoButtonColor = false,
        Size = UDim2.new(0, 29, 0, 29),
        Position = UDim2.new(0, x, 0, 120),
        BackgroundColor3 = palette[colorName] or Color3.fromRGB(255, 80, 150),
        BorderSizePixel = 0,
        ZIndex = 7,
    }, appearancePanel)
    corner(button, 20)
    if colorName == "cầu vồng" then
        gradient(button, {
            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 70)),
            ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 180, 30)),
            ColorSequenceKeypoint.new(0.4, Color3.fromRGB(55, 220, 100)),
            ColorSequenceKeypoint.new(0.6, Color3.fromRGB(20, 190, 255)),
            ColorSequenceKeypoint.new(0.8, Color3.fromRGB(125, 80, 255)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 70, 180)),
        }, 25)
    end
    local ring = stroke(button, Color3.new(1, 1, 1), 2, 1)
    colorButtons[colorName] = {Button = button, Ring = ring}
end

newLabel(appearancePanel, "▣  Chế độ hiển thị", UDim2.new(0.48, 0, 0, 28), UDim2.new(0, 18, 0, 158), 14)
local displayButton = newButton(appearancePanel, "Trong suốt   ▾", UDim2.new(0.52, -14, 0, 36), UDim2.new(0.48, 0, 0, 154), 13)

local function makeSlider(parent, title, y, initial, suffix, callback)
    local label = newLabel(parent, title, UDim2.new(1, -34, 0, 22), UDim2.new(0, 18, 0, y), 14)
    local valueLabel = newLabel(parent, tostring(initial) .. suffix, UDim2.new(0, 48, 0, 22),
        UDim2.new(1, -58, 0, y), 13, Color3.fromRGB(20, 92, 163), false)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    local bar = make("Frame", {
        Size = UDim2.new(1, -72, 0, 7),
        Position = UDim2.new(0, 18, 0, y + 28),
        BackgroundColor3 = Color3.fromRGB(185, 218, 244),
        BorderSizePixel = 0,
        ZIndex = 7,
    }, parent)
    corner(bar, 8)
    local fill = make("Frame", {
        Size = UDim2.new(math.clamp(initial / 100, 0, 1), 0, 1, 0),
        BackgroundColor3 = CONFIG.Accent,
        BorderSizePixel = 0,
        ZIndex = 8,
    }, bar)
    corner(fill, 8)
    local knob = make("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(math.clamp(initial / 100, 0, 1), 0, 0.5, 0),
        Size = UDim2.new(0, 16, 0, 16),
        BackgroundColor3 = CONFIG.Accent,
        BorderSizePixel = 0,
        ZIndex = 9,
    }, bar)
    corner(knob, 12)
    stroke(knob, Color3.new(1, 1, 1), 1, 0.2)
    local hit = make("TextButton", {
        Text = "",
        AutoButtonColor = false,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 28),
        Position = UDim2.new(0, 0, 0.5, -14),
        ZIndex = 10,
    }, bar)
    local dragging = false
    local function setFromX(x)
        local width = math.max(bar.AbsoluteSize.X, 1)
        local alpha = math.clamp((x - bar.AbsolutePosition.X) / width, 0, 1)
        local value = math.floor(alpha * 100 + 0.5)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        knob.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = tostring(value) .. suffix
        callback(value)
    end
    track(hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            setFromX(input.Position.X)
        end
    end))
    track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            setFromX(input.Position.X)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end))
    return {Label = label, Value = valueLabel, Bar = bar, Fill = fill, Knob = knob}
end

local function updateAccent(color)
    CONFIG.Accent = color
    islandStroke.Color = color
    islandGlow.BackgroundColor3 = color
    windowStroke.Color = Color3.fromRGB(255, 255, 255)
    for _, object in ipairs({tabSettings, appearancePanel}) do
        if object and object.Parent then
            if object == tabSettings then
                object.BackgroundColor3 = color
            end
        end
    end
end

local function setRainbow()
    rainbow = true
    for _, item in pairs(colorButtons) do
        item.Ring.Transparency = 1
    end
    colorButtons["cầu vồng"].Ring.Transparency = 0
    updateAccent(Color3.fromRGB(80, 160, 255))
end

local sliders = {}
sliders.background = makeSlider(appearancePanel, "Độ mờ nền", 204, 60, "%", function(value)
    CONFIG.BackgroundOpacity = value / 100
    window.BackgroundTransparency = math.clamp(1 - CONFIG.BackgroundOpacity * 0.35, 0.15, 0.85)
    sidebar.BackgroundTransparency = math.clamp(0.32 - CONFIG.BackgroundOpacity * 0.25, 0.05, 0.4)
end)
sliders.transparency = makeSlider(appearancePanel, "Độ trong suốt giao diện", 258, 80, "%", function(value)
    CONFIG.InterfaceTransparency = value / 100
    if CONFIG.DisplayMode == "Trong suốt" then
        window.BackgroundTransparency = math.clamp(1 - value / 125, 0.12, 0.8)
        appearancePanel.BackgroundTransparency = math.clamp(0.52 - value / 250, 0.12, 0.55)
        notifyPanel.BackgroundTransparency = appearancePanel.BackgroundTransparency
        infoPanel.BackgroundTransparency = appearancePanel.BackgroundTransparency
    else
        window.BackgroundTransparency = 0.02
        appearancePanel.BackgroundTransparency = 0.03
        notifyPanel.BackgroundTransparency = 0.03
        infoPanel.BackgroundTransparency = 0.03
    end
end)
sliders.brightness = makeSlider(appearancePanel, "Độ sáng", 312, 40, "%", function(value)
    CONFIG.Brightness = value
    -- Điều chỉnh độ sáng màu giao diện, không thay đổi Lighting của cả trò chơi.
    local amount = value / 100
    local base = CONFIG.Accent
    local bright = base:Lerp(Color3.new(1, 1, 1), math.clamp(amount * 0.35, 0, 0.35))
    for _, item in pairs(colorButtons) do
        if item.Button.BackgroundColor3 == base then item.Button.BackgroundColor3 = bright end
    end
end)

-- Bảng thông báo
newLabel(notifyPanel, "♟  Cài đặt thông báo", UDim2.new(1, -24, 0, 30), UDim2.new(0, 18, 0, 10), 18,
    Color3.fromRGB(23, 99, 174), true)
newLabel(notifyPanel, "Nhận thông báo khi có sự kiện quan trọng", UDim2.new(1, -34, 0, 34),
    UDim2.new(0, 18, 0, 39), 12, Color3.fromRGB(89, 142, 190), false)

local function makeToggle(parent, title, subtitle, y, initial, callback)
    newLabel(parent, title, UDim2.new(1, -94, 0, 25), UDim2.new(0, 18, 0, y), 15)
    newLabel(parent, subtitle, UDim2.new(1, -94, 0, 22), UDim2.new(0, 18, 0, y + 22), 12,
        Color3.fromRGB(93, 143, 188), false)
    local button = make("TextButton", {
        AutoButtonColor = false,
        Text = "",
        Size = UDim2.new(0, 52, 0, 30),
        Position = UDim2.new(1, -70, 0, y + 3),
        BackgroundColor3 = initial and CONFIG.Accent or Color3.fromRGB(171, 192, 211),
        BorderSizePixel = 0,
        ZIndex = 8,
    }, parent)
    corner(button, 18)
    local knob = make("Frame", {
        Size = UDim2.new(0, 24, 0, 24),
        Position = initial and UDim2.new(1, -27, 0, 3) or UDim2.new(0, 3, 0, 3),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        ZIndex = 9,
    }, button)
    corner(knob, 16)
    local state = initial
    track(button.Activated:Connect(function()
        state = not state
        tween(button, 0.18, {BackgroundColor3 = state and CONFIG.Accent or Color3.fromRGB(171, 192, 211)})
        tween(knob, 0.18, {Position = state and UDim2.new(1, -27, 0, 3) or UDim2.new(0, 3, 0, 3)})
        callback(state)
    end))
    return button
end

makeToggle(notifyPanel, "Thông báo hệ thống", "Hiển thị thông báo chung", 88, CONFIG.SystemNotifications, function(value)
    CONFIG.SystemNotifications = value
end)
makeToggle(notifyPanel, "Thông báo script", "Thông báo khi có cập nhật", 162, CONFIG.ScriptNotifications, function(value)
    CONFIG.ScriptNotifications = value
end)

-- Khối thông tin nhanh ở cuối trang Cài đặt
newLabel(infoPanel, "●  Thông tin", UDim2.new(1, -24, 0, 28), UDim2.new(0, 18, 0, 8), 17,
    Color3.fromRGB(23, 99, 174), true)
local summary1 = newLabel(infoPanel, "▤   Tên script\n      chan chan", UDim2.new(0.34, -12, 0.65, 0),
    UDim2.new(0, 20, 0.32, 0), 14, Color3.fromRGB(25, 100, 173), false)
local summary2 = newLabel(infoPanel, "♛   Phiên bản\n      v1.0.0", UDim2.new(0.30, -12, 0.65, 0),
    UDim2.new(0.36, 0, 0.32, 0), 14, Color3.fromRGB(25, 100, 173), false)
local summary3 = newLabel(infoPanel, "▦   Tác giả\n      Nam HUB", UDim2.new(0.30, -12, 0.65, 0),
    UDim2.new(0.68, 0, 0.32, 0), 14, Color3.fromRGB(25, 100, 173), false)

-- Trang Thông tin riêng
local infoPage = make("Frame", {
    Name = "InfoPage",
    Position = UDim2.new(0, 12, 0, 110),
    Size = UDim2.new(1, -24, 1, -122),
    BackgroundTransparency = 1,
    Visible = false,
    ZIndex = 5,
}, content)
local infoCard = panel(infoPage, "InfoCard", UDim2.new(0, 0, 0, 0), UDim2.new(1, 0, 1, 0))
newLabel(infoCard, "●  Thông tin", UDim2.new(1, -36, 0, 38), UDim2.new(0, 24, 0, 22), 25,
    Color3.fromRGB(17, 82, 155), true)
newLabel(infoCard, "Thông tin chi tiết về script và bản phát hành", UDim2.new(1, -40, 0, 26),
    UDim2.new(0, 24, 0, 60), 14, Color3.fromRGB(75, 130, 184), false)
local details = {
    {"Tên script", "chan chan"},
    {"Phiên bản", "v1.0.0"},
    {"Tác giả", "Nam HUB"},
}
for i, pair in ipairs(details) do
    local y = 110 + (i - 1) * 78
    local card = panel(infoCard, "Detail" .. i, UDim2.new(0, 20, 0, y), UDim2.new(1, -40, 0, 62))
    newLabel(card, pair[1], UDim2.new(1, -24, 0, 24), UDim2.new(0, 16, 0, 5), 13,
        Color3.fromRGB(91, 142, 187), false)
    newLabel(card, pair[2], UDim2.new(1, -24, 0, 27), UDim2.new(0, 16, 0, 29), 16,
        Color3.fromRGB(20, 92, 163), true)
end

-- Thay đổi chủ đề và chế độ hiển thị
local function applyTheme()
    local dark = CONFIG.Theme == "Tối"
    if dark then
        window.BackgroundColor3 = Color3.fromRGB(20, 34, 62)
        sidebar.BackgroundColor3 = Color3.fromRGB(13, 31, 67)
        pageTitle.TextColor3 = Color3.fromRGB(220, 239, 255)
        pageSubtitle.TextColor3 = Color3.fromRGB(155, 191, 228)
        for _, p in ipairs({appearancePanel, notifyPanel, infoPanel, infoCard}) do
            p.BackgroundColor3 = Color3.fromRGB(35, 55, 88)
        end
        for _, obj in ipairs({themeButton, displayButton}) do
            obj.BackgroundColor3 = Color3.fromRGB(49, 70, 105)
            obj.TextColor3 = Color3.fromRGB(234, 245, 255)
        end
    else
        window.BackgroundColor3 = Color3.fromRGB(209, 239, 255)
        sidebar.BackgroundColor3 = Color3.fromRGB(30, 108, 193)
        pageTitle.TextColor3 = Color3.fromRGB(17, 82, 155)
        pageSubtitle.TextColor3 = Color3.fromRGB(75, 130, 184)
        for _, p in ipairs({appearancePanel, notifyPanel, infoPanel, infoCard}) do
            p.BackgroundColor3 = Color3.fromRGB(241, 250, 255)
        end
        for _, obj in ipairs({themeButton, displayButton}) do
            obj.BackgroundColor3 = Color3.fromRGB(230, 246, 255)
            obj.TextColor3 = Color3.fromRGB(22, 91, 160)
        end
    end
end

themeButton.Activated:Connect(function()
    CONFIG.Theme = CONFIG.Theme == "Sáng" and "Tối" or "Sáng"
    themeButton.Text = (CONFIG.Theme == "Sáng" and "☀  Sáng     ▾" or "☾  Tối       ▾")
    applyTheme()
end)
displayButton.Activated:Connect(function()
    CONFIG.DisplayMode = CONFIG.DisplayMode == "Trong suốt" and "Bình thường" or "Trong suốt"
    displayButton.Text = (CONFIG.DisplayMode == "Trong suốt" and "Trong suốt   ▾" or "Bình thường   ▾")
    sliders.transparency.Label.Text = "Độ trong suốt giao diện"
    sliders.transparency.Value.Text = tostring(math.floor(CONFIG.InterfaceTransparency * 100 + 0.5)) .. "%"
    sliders.transparency.Fill.Size = UDim2.new(CONFIG.InterfaceTransparency, 0, 1, 0)
    sliders.transparency.Knob.Position = UDim2.new(CONFIG.InterfaceTransparency, 0, 0.5, 0)
    sliders.transparency.Knob.Parent.BackgroundTransparency = 0
    sliders.transparency.Bar.BackgroundTransparency = 0
    if CONFIG.DisplayMode == "Bình thường" then
        window.BackgroundTransparency = 0.02
        appearancePanel.BackgroundTransparency = 0.03
        notifyPanel.BackgroundTransparency = 0.03
        infoPanel.BackgroundTransparency = 0.03
    else
        window.BackgroundTransparency = math.clamp(1 - CONFIG.InterfaceTransparency / 1.25, 0.12, 0.8)
        appearancePanel.BackgroundTransparency = 0.26
        notifyPanel.BackgroundTransparency = 0.26
        infoPanel.BackgroundTransparency = 0.26
    end
end)

for colorName, item in pairs(colorButtons) do
    track(item.Button.Activated:Connect(function()
        rainbow = colorName == "cầu vồng"
        for _, entry in pairs(colorButtons) do entry.Ring.Transparency = 1 end
        item.Ring.Transparency = 0
        if rainbow then
            setRainbow()
        else
            updateAccent(palette[colorName])
        end
    end))
end

local selectedTab = "Cài đặt"
local function showTab(tab)
    selectedTab = tab
    local settings = tab == "Cài đặt"
    settingsPage.Visible = settings
    infoPage.Visible = not settings
    pageTitle.Text = settings and "⚙  Cài đặt" or "●  Thông tin"
    pageSubtitle.Text = settings and "Tùy chỉnh giao diện và trải nghiệm theo ý thích của bạn"
        or "Thông tin chi tiết về script và bản phát hành"
    tabSettings.BackgroundTransparency = settings and 0.05 or 1
    tabInfo.BackgroundTransparency = settings and 1 or 0.05
    tabSettings.BackgroundColor3 = CONFIG.Accent
    tabInfo.BackgroundColor3 = CONFIG.Accent
end
track(tabSettings.Activated:Connect(function() showTab("Cài đặt") end))
track(tabInfo.Activated:Connect(function() showTab("Thông tin") end))

-- Mở/đóng, thu nhỏ và phóng to cửa sổ
local isOpen = true
local isMinimized = false
local isMaximized = false
local normalSize = UDim2.new(0.88, 0, 0.78, 0)
local normalPosition = UDim2.new(0.5, 0, 0.56, 0)
local function setWindowVisible(visible)
    isOpen = visible
    if visible then
        window.Visible = true
        shadow.Visible = true
        window.Size = UDim2.new(normalSize.X.Scale * 0.94, 0, normalSize.Y.Scale * 0.94, 0)
        window.BackgroundTransparency = math.max(window.BackgroundTransparency, 0.25)
        tween(window, 0.24, {Size = normalSize, BackgroundTransparency = CONFIG.DisplayMode == "Bình thường" and 0.02 or 0.16},
            Enum.EasingStyle.Back)
        tween(shadow, 0.24, {Size = normalSize, BackgroundTransparency = 0.78})
    else
        tween(window, 0.18, {Size = UDim2.new(normalSize.X.Scale * 0.92, 0, normalSize.Y.Scale * 0.92, 0),
            BackgroundTransparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        tween(shadow, 0.18, {BackgroundTransparency = 1}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        task.delay(0.19, function()
            if not isOpen and window.Parent then
                window.Visible = false
                shadow.Visible = false
            end
        end)
    end
end

track(island.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        -- Chỉ nhấn vùng trống của thanh mới đổi trạng thái; nút con tự xử lý riêng.
        local localX = input.Position.X - island.AbsolutePosition.X
        if localX < island.AbsoluteSize.X - 88 then
            setWindowVisible(not isOpen)
        end
    end
end))
track(islandSettings.Activated:Connect(function()
    showTab("Cài đặt")
    setWindowVisible(true)
end))
local timerPaused = false
local elapsed = 0
local lastClock = os.clock()
track(pauseButton.Activated:Connect(function()
    timerPaused = not timerPaused
    pauseButton.Text = timerPaused and "▶" or "Ⅱ"
end))

track(minimizeButton.Activated:Connect(function()
    isMinimized = not isMinimized
    if isMinimized then
        tween(window, 0.22, {Size = UDim2.new(normalSize.X.Scale, 0, 0, 62)})
        tween(shadow, 0.22, {Size = UDim2.new(normalSize.X.Scale, 0, 0, 62)})
        content.Visible = false
        sidebar.Visible = false
        maximizeButton.Text = "□"
    else
        sidebar.Visible = true
        content.Visible = true
        tween(window, 0.22, {Size = isMaximized and UDim2.new(0.96, 0, 0.9, 0) or normalSize})
        tween(shadow, 0.22, {Size = isMaximized and UDim2.new(0.96, 0, 0.9, 0) or normalSize})
    end
end))
track(maximizeButton.Activated:Connect(function()
    isMaximized = not isMaximized
    isMinimized = false
    sidebar.Visible = true
    content.Visible = true
    local target = isMaximized and UDim2.new(0.96, 0, 0.9, 0) or normalSize
    tween(window, 0.22, {Size = target, Position = isMaximized and UDim2.new(0.5, 0, 0.54, 0) or normalPosition})
    tween(shadow, 0.22, {Size = target, Position = isMaximized and UDim2.new(0.5, 0, 0.54, 0) or normalPosition})
end))
track(closeButton.Activated:Connect(function()
    setWindowVisible(false)
end))

-- Kéo cửa sổ bằng vùng tiêu đề phía trên, hỗ trợ chuột và cảm ứng
local dragActive = false
local dragStart, startPosition
local dragHandle = make("TextButton", {
    Name = "DragHandle",
    Text = "",
    AutoButtonColor = false,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(1, -170, 0, 44),
    ZIndex = 9,
}, window)
track(dragHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragActive = true
        dragStart = input.Position
        startPosition = window.Position
    end
end))
track(UserInputService.InputChanged:Connect(function(input)
    if dragActive and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        local target = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X,
            startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
        window.Position = target
        shadow.Position = target
    end
end))
track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragActive = false
    end
end))

-- Tự điều chỉnh tỷ lệ theo kích thước màn hình
local function resizeForViewport()
    local camera = workspace.CurrentCamera
    if not camera then return end
    local viewport = camera.ViewportSize
    local shortSide = math.min(viewport.X, viewport.Y)
    if viewport.X < 700 then
        normalSize = UDim2.new(0.94, 0, 0.72, 0)
        scale.Scale = math.clamp(shortSide / 430, 0.72, 1)
        sidebar.Size = UDim2.new(0.27, 0, 1, 0)
        content.Position = UDim2.new(0.27, 0, 0, 0)
        content.Size = UDim2.new(0.73, 0, 1, 0)
        sideTitle.Position = UDim2.new(0, 12, 0, 57)
        sideTitle.Size = UDim2.new(1, -24, 0, 25)
        sideTitle.TextSize = 15
        sideSubtitle.Position = UDim2.new(0, 12, 0, 80)
        sideSubtitle.Size = UDim2.new(1, -20, 0, 18)
        sideSubtitle.TextSize = 9
        sideCrown.Position = UDim2.new(0, 12, 0, 10)
        sideCrown.Size = UDim2.new(1, -24, 0, 42)
        sideCrown.TextSize = 28
        tabSettings.Size = UDim2.new(1, -14, 0, 44)
        tabSettings.Position = UDim2.new(0, 7, 0, 112)
        tabSettings.TextSize = 12
        tabInfo.Size = UDim2.new(1, -14, 0, 44)
        tabInfo.Position = UDim2.new(0, 7, 0, 164)
        tabInfo.TextSize = 12
        pageTitle.TextSize = 19
        pageTitle.Position = UDim2.new(0, 12, 0, 43)
        pageSubtitle.TextSize = 10
        pageSubtitle.Position = UDim2.new(0, 14, 0, 73)
        settingsPage.Position = UDim2.new(0, 8, 0, 102)
        settingsPage.Size = UDim2.new(1, -16, 1, -110)
        appearancePanel.Size = UDim2.new(1, 0, 0.56, -5)
        notifyPanel.Position = UDim2.new(0, 0, 0.58, 5)
        notifyPanel.Size = UDim2.new(1, 0, 0.25, -5)
        infoPanel.Position = UDim2.new(0, 0, 0.85, 5)
        infoPanel.Size = UDim2.new(1, 0, 0.15, -5)
        themeButton.Size = UDim2.new(0.55, -8, 0, 30)
        themeButton.Position = UDim2.new(0.42, 0, 0, 46)
        themeButton.TextSize = 11
        displayButton.Size = UDim2.new(0.52, -8, 0, 30)
        displayButton.Position = UDim2.new(0.48, 0, 0, 154)
        displayButton.TextSize = 10
        for _, slider in pairs(sliders) do
            slider.Label.TextSize = 11
            slider.Value.TextSize = 10
        end
        island.Size = UDim2.new(0, 300, 0, 48)
        island.Position = UDim2.new(0.5, 0, 0, 8)
    else
        normalSize = UDim2.new(0.88, 0, 0.78, 0)
        scale.Scale = math.clamp(shortSide / 800, 0.82, 1.08)
        sidebar.Size = UDim2.new(0.225, 0, 1, 0)
        content.Position = UDim2.new(0.225, 0, 0, 0)
        content.Size = UDim2.new(0.775, 0, 1, 0)
        sideTitle.Position = UDim2.new(0, 68, 0, 18)
        sideTitle.Size = UDim2.new(1, -78, 0, 30)
        sideTitle.TextSize = 20
        sideSubtitle.Position = UDim2.new(0, 68, 0, 46)
        sideSubtitle.Size = UDim2.new(1, -24, 0, 22)
        sideSubtitle.TextSize = 12
        sideCrown.Position = UDim2.new(0, 18, 0, 18)
        sideCrown.Size = UDim2.new(0, 46, 0, 46)
        sideCrown.TextSize = 34
        tabSettings.Size = UDim2.new(1, -26, 0, 52)
        tabSettings.Position = UDim2.new(0, 13, 0, 94)
        tabSettings.TextSize = 16
        tabInfo.Size = UDim2.new(1, -26, 0, 52)
        tabInfo.Position = UDim2.new(0, 13, 0, 156)
        tabInfo.TextSize = 16
        pageTitle.TextSize = 25
        pageTitle.Position = UDim2.new(0, 22, 0, 48)
        pageSubtitle.TextSize = 13
        pageSubtitle.Position = UDim2.new(0, 24, 0, 78)
        settingsPage.Position = UDim2.new(0, 12, 0, 110)
        settingsPage.Size = UDim2.new(1, -24, 1, -122)
        appearancePanel.Size = UDim2.new(0.535, -7, 0.72, -6)
        notifyPanel.Position = UDim2.new(0.535, 7, 0, 0)
        notifyPanel.Size = UDim2.new(0.465, -7, 0.72, -6)
        infoPanel.Position = UDim2.new(0, 0, 0.74, 6)
        infoPanel.Size = UDim2.new(1, 0, 0.26, -6)
        themeButton.Size = UDim2.new(0.55, -14, 0, 36)
        themeButton.Position = UDim2.new(0.42, 0, 0, 46)
        themeButton.TextSize = 14
        displayButton.Size = UDim2.new(0.52, -14, 0, 36)
        displayButton.Position = UDim2.new(0.48, 0, 0, 154)
        displayButton.TextSize = 13
        for _, slider in pairs(sliders) do
            slider.Label.TextSize = 14
            slider.Value.TextSize = 13
        end
        island.Size = UDim2.new(0, 330, 0, 54)
        island.Position = UDim2.new(0.5, 0, 0, 14)
    end
    window.Size = isMinimized and UDim2.new(normalSize.X.Scale, 0, 0, 62) or (isMaximized and UDim2.new(0.96, 0, 0.9, 0) or normalSize)
    shadow.Size = window.Size
end

track(RunService.RenderStepped:Connect(function()
    local now = os.clock()
    local delta = now - lastClock
    lastClock = now
    if not timerPaused then elapsed = elapsed + delta end
    local total = math.floor(elapsed)
    local hours = math.floor(total / 3600)
    local minutes = math.floor((total % 3600) / 60)
    local seconds = total % 60
    timerLabel.Text = string.format("%02d:%02d:%02d", hours, minutes, seconds)
    if rainbow then
        local hue = (now * 0.12) % 1
        CONFIG.Accent = Color3.fromHSV(hue, 0.72, 1)
        islandStroke.Color = CONFIG.Accent
        islandGlow.BackgroundColor3 = CONFIG.Accent
        tabSettings.BackgroundColor3 = CONFIG.Accent
        sliders.background.Fill.BackgroundColor3 = CONFIG.Accent
        sliders.background.Knob.BackgroundColor3 = CONFIG.Accent
        sliders.transparency.Fill.BackgroundColor3 = CONFIG.Accent
        sliders.transparency.Knob.BackgroundColor3 = CONFIG.Accent
        sliders.brightness.Fill.BackgroundColor3 = CONFIG.Accent
        sliders.brightness.Knob.BackgroundColor3 = CONFIG.Accent
    end
end))

local camera = workspace.CurrentCamera
if camera then
    track(camera:GetPropertyChangedSignal("ViewportSize"):Connect(resizeForViewport))
end
track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    local newCamera = workspace.CurrentCamera
    if newCamera then
        track(newCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resizeForViewport))
        resizeForViewport()
    end
end))

-- Khởi tạo trạng thái và hiệu ứng xuất hiện
showTab("Cài đặt")
resizeForViewport()
window.BackgroundTransparency = 1
window.Size = UDim2.new(normalSize.X.Scale * 0.94, 0, normalSize.Y.Scale * 0.94, 0)
tween(window, 0.35, {BackgroundTransparency = 0.16, Size = normalSize}, Enum.EasingStyle.Back)
tween(shadow, 0.35, {BackgroundTransparency = 0.78, Size = normalSize}, Enum.EasingStyle.Back)

-- Dọn kết nối khi GUI bị xoá
track(gui.Destroying:Connect(function()
    for _, connection in ipairs(connections) do
        if connection and connection.Connected then
            connection:Disconnect()
        end
    end
end))
