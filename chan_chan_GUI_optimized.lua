--[[
	chan chan - Script by Nam HUB
	GUI phong cách Liquid Glass cho Roblox
	Đặt trong: StarterPlayer > StarterPlayerScripts (LocalScript)
]]

--========================= DỊCH VỤ =========================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera or workspace:GetPropertyChangedSignal("CurrentCamera"):Wait() and workspace.CurrentCamera

-- Xoá bản cũ nếu script chạy lại
do
	local old = playerGui:FindFirstChild("chan chan")
	if old then old:Destroy() end
end

--========================= HẰNG SỐ =========================
-- SourceSans hỗ trợ tốt tiếng Việt có dấu
local FONT_REG, FONT_MED, FONT_BOLD = Enum.Font.SourceSans, Enum.Font.SourceSansSemibold, Enum.Font.SourceSansBold
local WHITE = Color3.new(1, 1, 1)
local WIN_W, WIN_H, MIN_H = 800, 500, 66
local ISL_W_OPEN, ISL_W_CLOSED, ISL_H = 340, 250, 46
local SCRIPT_NAME, SCRIPT_VERSION, SCRIPT_AUTHOR = "chan chan", "v1.0.0", "Nam HUB"

-- Bảng màu giao diện Sáng / Tối
local THEMES = {
	["Sáng"] = {
		window = Color3.fromRGB(200, 226, 252), panel = Color3.fromRGB(240, 248, 255),
		field = Color3.fromRGB(252, 254, 255), sidebar = Color3.fromRGB(52, 112, 205),
		text = Color3.fromRGB(18, 68, 170), sub = Color3.fromRGB(88, 132, 196),
		track = Color3.fromRGB(190, 212, 240), off = Color3.fromRGB(170, 190, 216),
	},
	["Tối"] = {
		window = Color3.fromRGB(14, 24, 56), panel = Color3.fromRGB(32, 46, 94),
		field = Color3.fromRGB(24, 36, 78), sidebar = Color3.fromRGB(8, 14, 38),
		text = Color3.fromRGB(232, 242, 255), sub = Color3.fromRGB(150, 172, 216),
		track = Color3.fromRGB(52, 68, 118), off = Color3.fromRGB(82, 96, 138),
	},
}

-- Màu chủ đạo: c1 = màu đơn, seq = gradient
local ACCENTS = {
	{ c1 = Color3.fromRGB(38, 168, 255), seq = ColorSequence.new(Color3.fromRGB(38, 168, 255), Color3.fromRGB(170, 110, 250)) },
	{ c1 = Color3.fromRGB(140, 88, 250), seq = ColorSequence.new(Color3.fromRGB(140, 88, 250), Color3.fromRGB(235, 120, 230)) },
	{ c1 = Color3.fromRGB(255, 98, 178), seq = ColorSequence.new(Color3.fromRGB(255, 98, 178), Color3.fromRGB(190, 115, 255)) },
	{ c1 = Color3.fromRGB(22, 200, 190), seq = ColorSequence.new(Color3.fromRGB(22, 200, 190), Color3.fromRGB(60, 150, 255)) },
	{ c1 = Color3.fromRGB(255, 152, 24), seq = ColorSequence.new(Color3.fromRGB(255, 152, 24), Color3.fromRGB(255, 92, 120)) },
	{ c1 = Color3.fromRGB(255, 80, 120), seq = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
		ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 40)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(80, 220, 120)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(40, 190, 255)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(130, 90, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 200)),
	}) },
}

local DISPLAY = {
	["Sáng"] = "☀️  Sáng", ["Tối"] = "🌙  Tối",
	["Trong suốt"] = "Trong suốt", ["Bình thường"] = "Bình thường",
}

--========================= TRẠNG THÁI (lưu trong phiên) =========================
local state = {
	theme = "Sáng", accent = 1, mode = "Trong suốt",
	transp = 80,    -- độ trong suốt giao diện (0-100%)
	bright = 16,    -- độ sáng (0-40px): độ rực của viền phát sáng + lớp phản chiếu kính
	sysNotif = true, scriptNotif = true,
	open = false, minimized = false, maximized = false,
}

--========================= TIỆN ÍCH =========================
local connections, cleanups = {}, {}
local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(connections, c)
	return c
end

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function create(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

local function corner(obj, r) return create("UICorner", { CornerRadius = UDim.new(0, r) }, obj) end

local function label(parent, props)
	local p = { BackgroundTransparency = 1, Font = FONT_MED, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = WHITE, Text = "", BorderSizePixel = 0 }
	for k, v in props do p[k] = v end
	return create("TextLabel", p, parent)
end

-- Sổ đăng ký để cập nhật khi đổi theme / màu / độ trong suốt
local themed, hooks, glassList, accentGrads, accentColors = {}, {}, {}, {}, {}

local function reg(obj, prop, key)
	table.insert(themed, { obj = obj, prop = prop, key = key })
	obj[prop] = THEMES[state.theme][key]
end
local function regGlass(obj, kind) table.insert(glassList, { obj = obj, kind = kind }) end
local function regAccentGrad(parent, rotation)
	local g = create("UIGradient", { Color = ACCENTS[state.accent].seq, Rotation = rotation or 0 }, parent)
	table.insert(accentGrads, g)
	return g
end
local function regAccentColor(obj, prop)
	table.insert(accentColors, { obj = obj, prop = prop })
	obj[prop] = ACCENTS[state.accent].c1
end

--========================= SCREENGUI & TỶ LỆ =========================
local gui = create("ScreenGui", {
	Name = "chan chan", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100,
})
local uiScale = create("UIScale", { Scale = 1 }, gui)


--========================= HIỆU ỨNG KÍNH / ĐỘ SÁNG / BLUR =========================
local win, winStroke, shine -- khai báo trước

local function applyGlass(smooth)
	local t = state.transp / 100
	local k = state.mode == "Trong suốt" and 1 or 0.2
	local map = {
		window = 0.10 + 0.55 * t * k,
		sidebar = 0.10 + 0.40 * t * k,
		panel = 0.28 + 0.45 * t * k,
	}
	for _, e in glassList do
		if smooth then tween(e.obj, 0.25, { BackgroundTransparency = map[e.kind] }, Enum.EasingStyle.Quad)
		else e.obj.BackgroundTransparency = map[e.kind] end
	end
end

local function applyBright()
	local b = state.bright / 40
	if winStroke then
		winStroke.Thickness = 1.5 + b * 2.5
		winStroke.Transparency = 0.35 - b * 0.3
	end
	if shine then shine.BackgroundTransparency = 0.92 - b * 0.3 end
end

local function updateBlur(_instant)
	-- Không dùng BlurEffect toàn màn hình; kính chỉ được mô phỏng bên trong GUI.
end

local function applyTheme()
	local th = THEMES[state.theme]
	for _, e in themed do
		if e.obj.Parent then tween(e.obj, 0.3, { [e.prop] = th[e.key] }, Enum.EasingStyle.Quad) end
	end
	for _, h in hooks do h() end
end

local function applyAccent()
	local a = ACCENTS[state.accent]
	for _, g in accentGrads do g.Color = a.seq end
	for _, e in accentColors do tween(e.obj, 0.25, { [e.prop] = a.c1 }, Enum.EasingStyle.Quad) end
end

--========================= THÔNG BÁO =========================
local toast = create("CanvasGroup", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(300, 38),
	BackgroundColor3 = Color3.fromRGB(10, 22, 60), BackgroundTransparency = 0.05, GroupTransparency = 1, Visible = false,
}, gui)
corner(toast, 19)
do
	local st = create("UIStroke", { Color = WHITE, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, toast)
	regAccentGrad(st)
end
local toastLabel = label(toast, { Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(12, 0),
	TextXAlignment = Enum.TextXAlignment.Center, TextSize = 17, TextTruncate = Enum.TextTruncate.AtEnd })
local toastToken = 0

-- Thông báo của script (hiện trong GUI)
local function showToast(text)
	if not state.scriptNotif then return end
	toastToken += 1
	local tk = toastToken
	toastLabel.Text = text
	toast.Visible = true
	toast.Position = UDim2.new(0.5, 0, 0, 56)
	tween(toast, 0.3, { GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0, 64) })
	task.delay(2.4, function()
		if toastToken ~= tk then return end
		local t = tween(toast, 0.3, { GroupTransparency = 1 })
		t.Completed:Once(function()
			if toastToken == tk then toast.Visible = false end
		end)
	end)
end

-- Thông báo hệ thống (thông báo của Roblox)
local function notifySystem(title, text)
	if not state.sysNotif then return end
	pcall(function()
		StarterGui:SetCore("SendNotification", { Title = title, Text = text, Duration = 3 })
	end)
end

--========================= CỬA SỔ CHÍNH =========================
local normalPos = UDim2.new(0.5, 0, 0.5, -WIN_H / 2 + 30)

win = create("CanvasGroup", {
	Name = "Window", AnchorPoint = Vector2.new(0.5, 0), Position = normalPos, Size = UDim2.fromOffset(WIN_W, WIN_H),
	BorderSizePixel = 0, GroupTransparency = 1, Visible = false,
}, gui)
corner(win, 26)
reg(win, "BackgroundColor3", "window")
regGlass(win, "window")
local winScale = create("UIScale", { Scale = 0.92 }, win)

winStroke = create("UIStroke", { Color = WHITE, Thickness = 2, Transparency = 0.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, win)
regAccentGrad(winStroke)

-- Lớp phản chiếu kính phía trên
shine = create("Frame", { Size = UDim2.fromScale(1, 0.45), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 1 }, win)
create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 1) }, shine)

-- Thanh tiêu đề (vùng kéo cửa sổ)
local titleBar = create("Frame", { Name = "TitleBar", Size = UDim2.new(1, 0, 0, MIN_H), BackgroundTransparency = 1, ZIndex = 1 }, win)

--------------------------- Thanh bên ---------------------------
local sidebar = create("Frame", {
	Name = "Sidebar", Position = UDim2.fromOffset(10, 10), Size = UDim2.new(0, 196, 1, -20), BorderSizePixel = 0,
}, win)
corner(sidebar, 20)
reg(sidebar, "BackgroundColor3", "sidebar")
regGlass(sidebar, "sidebar")
create("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(175, 188, 222)) }, sidebar)

label(sidebar, { Text = "👑", Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(34, 34), TextSize = 26,
	TextXAlignment = Enum.TextXAlignment.Center })
label(sidebar, { Text = SCRIPT_NAME, Position = UDim2.fromOffset(54, 6), Size = UDim2.new(1, -60, 0, 24), Font = FONT_BOLD, TextSize = 22 })
label(sidebar, { Text = "Script by Nam HUB", Position = UDim2.fromOffset(54, 28), Size = UDim2.new(1, -60, 0, 16),
	TextSize = 14, Font = FONT_REG, TextTransparency = 0.15 })

local tabs = {}
local function createTab(name, icon, y)
	local b = create("TextButton", {
		Name = name, Position = UDim2.new(0, 10, 0, y), Size = UDim2.new(1, -20, 0, 48),
		BackgroundColor3 = WHITE, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
	}, sidebar)
	corner(b, 16)
	regAccentGrad(b)
	local st = create("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 1 }, b)
	label(b, { Text = icon, Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(30, 48), TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center })
	label(b, { Text = name, Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -56, 1, 0), TextSize = 21, Font = FONT_MED })
	tabs[name] = { btn = b, stroke = st }
	return b
end
local tabSettings = createTab("Cài đặt", "⚙️", 84)
local tabInfo = createTab("Thông tin", "ℹ️", 140)

-- Khối chân thanh bên
create("Frame", { Position = UDim2.new(0.1, 0, 1, -100), Size = UDim2.new(0.8, 0, 0, 1), BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.7, BorderSizePixel = 0 }, sidebar)
label(sidebar, { Text = "👑", Position = UDim2.new(0, 0, 1, -92), Size = UDim2.new(1, 0, 0, 28), TextSize = 22,
	TextXAlignment = Enum.TextXAlignment.Center })
label(sidebar, { Text = SCRIPT_NAME, Position = UDim2.new(0, 0, 1, -64), Size = UDim2.new(1, 0, 0, 22), Font = FONT_BOLD,
	TextSize = 19, TextXAlignment = Enum.TextXAlignment.Center })
label(sidebar, { Text = "Script by Nam HUB", Position = UDim2.new(0, 0, 1, -42), Size = UDim2.new(1, 0, 0, 18), Font = FONT_REG,
	TextSize = 14, TextTransparency = 0.2, TextXAlignment = Enum.TextXAlignment.Center })

--------------------------- Khu vực nội dung ---------------------------
local body = create("Frame", { Name = "Body", Position = UDim2.new(0, 216, 0, 56), Size = UDim2.new(1, -226, 1, -66), BackgroundTransparency = 1 }, win)

local function createPage(name)
	return create("Frame", { Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, body)
end
local pageSettings, pageInfo = createPage("PageSettings"), createPage("PageInfo")
tabs["Cài đặt"].page, tabs["Thông tin"].page = pageSettings, pageInfo

local function createPanelFrame(parent, pos, size)
	local p = create("Frame", { Position = pos, Size = size, BorderSizePixel = 0 }, parent)
	corner(p, 18)
	reg(p, "BackgroundColor3", "panel")
	regGlass(p, "panel")
	return p
end

local function createHead(page, icon, title, sub)
	local card = createPanelFrame(page, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 58))
	label(card, { Text = icon, Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(36, 58), TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Center })
	local t = label(card, { Text = title, Position = UDim2.fromOffset(58, 5), Size = UDim2.new(1, -66, 0, 26), Font = FONT_BOLD, TextSize = 26 })
	reg(t, "TextColor3", "text")
	local s = label(card, { Text = sub, Position = UDim2.fromOffset(58, 31), Size = UDim2.new(1, -66, 0, 20), Font = FONT_REG, TextSize = 16 })
	reg(s, "TextColor3", "sub")
end

-- Panel có tiêu đề + vùng cuộn chứa các hàng
local function createPanel(parent, pos, size, icon, title, subtitle)
	local p = createPanelFrame(parent, pos, size)
	label(p, { Text = icon, Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(32, 32), TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center })
	local t = label(p, { Text = title, Position = UDim2.fromOffset(50, 6), Size = UDim2.new(1, -56, 0, 24), Font = FONT_BOLD, TextSize = 22 })
	reg(t, "TextColor3", "text")
	local top = 46
	if subtitle then
		local s = label(p, { Text = subtitle, Position = UDim2.fromOffset(50, 29), Size = UDim2.new(1, -56, 0, 18), Font = FONT_REG, TextSize = 15 })
		reg(s, "TextColor3", "sub")
		top = 56
	end
	local sc = create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, top), Size = UDim2.new(1, 0, 1, -top), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, p)
	create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, sc)
	create("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 8) }, sc)
	return sc
end

local function row(parent, order, h)
	return create("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1 }, parent)
end

--------------------------- Dropdown dùng chung ---------------------------
local ddLayer = create("Frame", { Name = "DropdownLayer", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 40 }, win)
local ddCatcher = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 40 }, ddLayer)
local ddList = create("Frame", { BorderSizePixel = 0, ZIndex = 41 }, ddLayer)
corner(ddList, 12)
reg(ddList, "BackgroundColor3", "field")
do
	local st = create("UIStroke", { Thickness = 1, Transparency = 0.7 }, ddList)
	reg(st, "Color", "sub")
end
create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, ddList)
create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, ddList)
local ddOpenFor = nil

local function closeDropdown()
	ddLayer.Visible = false
	ddOpenFor = nil
end
connect(ddCatcher.Activated, closeDropdown)

local function openDropdown(btn, options, current, onPick)
	if ddOpenFor == btn then closeDropdown() return end
	for _, c in ddList:GetChildren() do
		if c:IsA("TextButton") then c:Destroy() end
	end
	local th = THEMES[state.theme]
	for i, opt in options do
		local b = create("TextButton", {
			LayoutOrder = i, Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = ACCENTS[state.accent].c1,
			BackgroundTransparency = (opt == current) and 0.8 or 1, Text = "  " .. (DISPLAY[opt] or opt),
			TextXAlignment = Enum.TextXAlignment.Left, Font = FONT_MED, TextSize = 18, TextColor3 = th.text,
			AutoButtonColor = false, ZIndex = 42, BorderSizePixel = 0,
		}, ddList)
		corner(b, 8)
		b.Activated:Connect(function()
			closeDropdown()
			onPick(opt)
		end)
	end
	local s = uiScale.Scale * winScale.Scale
	local rel = (btn.AbsolutePosition - win.AbsolutePosition) / s
	ddList.Position = UDim2.fromOffset(rel.X, rel.Y + btn.AbsoluteSize.Y / s + 4)
	ddList.Size = UDim2.fromOffset(btn.AbsoluteSize.X / s, #options * 34 + 10)
	ddLayer.Visible = true
	ddOpenFor = btn
end

local function createDropdown(parent, order, title, options, getCurrent, onPick)
	local r = row(parent, order, 40)
	local l = label(r, { Text = title, Size = UDim2.new(1, -178, 1, 0), TextSize = 19 })
	reg(l, "TextColor3", "text")
	local btn = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(170, 34),
		Text = "", AutoButtonColor = false, BorderSizePixel = 0,
	}, r)
	corner(btn, 12)
	reg(btn, "BackgroundColor3", "field")
	local st = create("UIStroke", { Thickness = 1, Transparency = 0.75 }, btn)
	reg(st, "Color", "sub")
	local txt = label(btn, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -34, 1, 0), TextSize = 18 })
	reg(txt, "TextColor3", "text")
	local arrow = label(btn, { Text = "▼", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(14, 14), TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center })
	reg(arrow, "TextColor3", "sub")
	local function refresh() txt.Text = DISPLAY[getCurrent()] or getCurrent() end
	refresh()
	connect(btn.Activated, function()
		openDropdown(btn, options, getCurrent(), function(opt)
			onPick(opt)
			refresh()
		end)
	end)
	return refresh
end

--------------------------- Thanh trượt ---------------------------
local function createSlider(parent, order, title, minV, maxV, default, fmt, onChange)
	local r = row(parent, order, 46)
	local l = label(r, { Text = title, Size = UDim2.new(0.7, 0, 0, 20), TextSize = 18 })
	reg(l, "TextColor3", "text")
	local val = label(r, { Position = UDim2.fromScale(0.7, 0), Size = UDim2.new(0.3, 0, 0, 20), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Right })
	reg(val, "TextColor3", "text")
	local track = create("Frame", { Position = UDim2.fromOffset(9, 32), Size = UDim2.new(1, -18, 0, 6), BorderSizePixel = 0 }, r)
	corner(track, 3)
	reg(track, "BackgroundColor3", "track")
	local fill = create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, track)
	corner(fill, 3)
	regAccentGrad(fill)
	local thumb = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(18, 18), Position = UDim2.fromScale(0, 0.5),
		BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 2 }, track)
	corner(thumb, 9)
	local ts = create("UIStroke", { Thickness = 3 }, thumb)
	regAccentColor(ts, "Color")
	local hit = create("TextButton", { BackgroundTransparency = 1, Text = "", Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 30), ZIndex = 3 }, r)

	local function setValue(v, silent)
		v = math.clamp(math.floor(v + 0.5), minV, maxV)
		local a = (v - minV) / (maxV - minV)
		fill.Size = UDim2.fromScale(a, 1)
		thumb.Position = UDim2.fromScale(a, 0.5)
		val.Text = fmt(v)
		if not silent then onChange(v) end
	end
	setValue(default, true)

	local moveConn, endConn
	local function stop()
		if moveConn then moveConn:Disconnect() moveConn = nil end
		if endConn then endConn:Disconnect() endConn = nil end
		parent.ScrollingEnabled = true
	end
	table.insert(cleanups, stop)
	local function fromX(x)
		local a = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		setValue(minV + (maxV - minV) * a)
	end
	connect(hit.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			stop()
			parent.ScrollingEnabled = false -- tránh cuộn nhầm khi kéo trên điện thoại
			fromX(input.Position.X)
			moveConn = UserInputService.InputChanged:Connect(function(i)
				if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
					fromX(i.Position.X)
				end
			end)
			endConn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then stop() end
			end)
		end
	end)
end

--------------------------- Công tắc ---------------------------
local function createToggle(parent, order, title, desc, default, onChange)
	local r = row(parent, order, 60)
	local t = label(r, { Text = title, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, -66, 0, 22), Font = FONT_MED, TextSize = 20 })
	reg(t, "TextColor3", "text")
	local d = label(r, { Text = desc, Position = UDim2.fromOffset(0, 31), Size = UDim2.new(1, -66, 0, 18), Font = FONT_REG, TextSize = 15 })
	reg(d, "TextColor3", "sub")
	local track = create("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(52, 28),
		Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundColor3 = WHITE }, r)
	corner(track, 14)
	local grad = regAccentGrad(track)
	local knob = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(22, 22), Position = UDim2.new(0, 3, 0.5, 0),
		BackgroundColor3 = WHITE, BorderSizePixel = 0 }, track)
	corner(knob, 11)
	create("UIStroke", { Thickness = 1, Color = Color3.new(0, 0, 0), Transparency = 0.85 }, knob)
	local value = default
	local function render(animate)
		grad.Enabled = value
		track.BackgroundColor3 = value and WHITE or THEMES[state.theme].off
		local p = UDim2.new(0, value and 27 or 3, 0.5, 0)
		if animate then tween(knob, 0.25, { Position = p }, Enum.EasingStyle.Back) else knob.Position = p end
	end
	render(false)
	table.insert(hooks, function() render(false) end)
	connect(track.Activated, function()
		value = not value
		render(true)
		onChange(value)
	end)
end

--========================= TRANG CÀI ĐẶT =========================
createHead(pageSettings, "⚙️", "Cài đặt", "Tùy chỉnh giao diện và trải nghiệm theo ý thích của bạn")

local cols = create("Frame", { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 1, -66), BackgroundTransparency = 1 }, pageSettings)
local scLeft = createPanel(cols, UDim2.fromOffset(0, 0), UDim2.new(0.58, -5, 1, 0), "🎨", "Giao diện")
local scRight = createPanel(cols, UDim2.new(0.58, 5, 0, 0), UDim2.new(0.42, -5, 1, 0), "🔔", "Cài đặt thông báo", "Nhận thông báo khi có sự kiện quan trọng")

-- Chủ đề Sáng / Tối
createDropdown(scLeft, 1, "Chủ đề", { "Sáng", "Tối" }, function() return state.theme end, function(opt)
	state.theme = opt
	applyTheme()
	showToast("Chế độ giao diện: " .. opt)
end)

-- Màu chủ đạo
do
	local lbl = row(scLeft, 2, 22)
	local l = label(lbl, { Text = "Màu chủ đạo", Size = UDim2.fromScale(1, 1), TextSize = 19 })
	reg(l, "TextColor3", "text")
	local r = row(scLeft, 3, 42)
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 14),
		VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, r)
	create("UIPadding", { PaddingLeft = UDim.new(0, 4) }, r)
	local names = { "xanh dương", "tím", "hồng", "xanh ngọc", "cam", "cầu vồng" }
	local rings, sizes = {}, {}
	local function refreshRings()
		for i, ring in rings do
			local sel = i == state.accent
			tween(ring.stroke, 0.2, { Transparency = sel and 0 or 1 })
			tween(ring.btn, 0.25, { Size = UDim2.fromOffset(sel and 34 or 30, sel and 34 or 30) }, Enum.EasingStyle.Back)
		end
	end
	for i, a in ACCENTS do
		local holder = create("Frame", { LayoutOrder = i, Size = UDim2.fromOffset(36, 36), BackgroundTransparency = 1 }, r)
		local b = create("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(30, 30), Text = "", AutoButtonColor = false, BorderSizePixel = 0,
			BackgroundColor3 = (i == #ACCENTS) and WHITE or a.c1 }, holder)
		corner(b, 17)
		if i == #ACCENTS then create("UIGradient", { Color = a.seq, Rotation = 45 }, b) end
		local st = create("UIStroke", { Thickness = 3, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
		reg(st, "Color", "text")
		rings[i] = { btn = b, stroke = st }
		connect(b.Activated, function()
			state.accent = i
			applyAccent()
			refreshRings()
			showToast("Màu chủ đạo: " .. names[i])
		end)
	end
	refreshRings()
end

-- Chế độ hiển thị
createDropdown(scLeft, 4, "🖥️  Chế độ hiển thị", { "Trong suốt", "Bình thường" }, function() return state.mode end, function(opt)
	state.mode = opt
	applyGlass(true)
	showToast("Chế độ hiển thị: " .. opt)
end)

-- Ba thanh trượt
createSlider(scLeft, 5, "Độ trong suốt giao diện", 0, 100, state.transp, function(v) return v .. "%" end, function(v)
	state.transp = v
	applyGlass(false)
end)
createSlider(scLeft, 6, "Độ sáng", 0, 40, state.bright, function(v) return v .. "px" end, function(v)
	state.bright = v
	applyBright()
end)

-- Thông báo
createToggle(scRight, 1, "Thông báo hệ thống", "Hiển thị thông báo chung", state.sysNotif, function(v)
	state.sysNotif = v
	if v then notifySystem(SCRIPT_NAME, "Đã bật thông báo hệ thống") end
	showToast(v and "Đã bật thông báo hệ thống" or "Đã tắt thông báo hệ thống")
end)
createToggle(scRight, 2, "Thông báo script", "Thông báo khi có cập nhật", state.scriptNotif, function(v)
	state.scriptNotif = v
	if v then showToast("Đã bật thông báo script") end
end)

--========================= TRANG THÔNG TIN =========================
createHead(pageInfo, "ℹ️", "Thông tin", "Thông tin chi tiết về script và bản phát hành")
do
	local card = createPanelFrame(pageInfo, UDim2.fromOffset(0, 66), UDim2.new(1, 0, 0, 3 * 76 + 16))
	local function infoRow(i, icon, name, value, last)
		local r = create("Frame", { Position = UDim2.fromOffset(18, 8 + (i - 1) * 76), Size = UDim2.new(1, -36, 0, 76), BackgroundTransparency = 1 }, card)
		local c = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(48, 48),
			BackgroundColor3 = WHITE, BorderSizePixel = 0 }, r)
		corner(c, 24)
		regAccentGrad(c, 45)
		label(c, { Text = icon, Size = UDim2.fromScale(1, 1), TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center })
		local n = label(r, { Text = name, Position = UDim2.fromOffset(64, 12), Size = UDim2.new(1, -64, 0, 20), Font = FONT_REG, TextSize = 17 })
		reg(n, "TextColor3", "sub")
		local v = label(r, { Text = value, Position = UDim2.fromOffset(64, 32), Size = UDim2.new(1, -64, 0, 28), Font = FONT_BOLD, TextSize = 25 })
		reg(v, "TextColor3", "text")
		if not last then
			local ln = create("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 1), BorderSizePixel = 0 }, r)
			reg(ln, "BackgroundColor3", "track")
		end
	end
	infoRow(1, "📄", "Tên script", SCRIPT_NAME)
	infoRow(2, "👑", "Phiên bản", SCRIPT_VERSION)
	infoRow(3, "👤", "Tác giả", SCRIPT_AUTHOR, true)
end

--========================= CHUYỂN TAB =========================
local function showTab(name, instant)
	if currentTab == name and not instant then return end
	currentTab = name
	refreshIslandStatus()
	closeDropdown()
	for n, t in tabs do
		local sel = n == name
		tween(t.btn, 0.3, { BackgroundTransparency = sel and 0 or 1 })
		tween(t.stroke, 0.3, { Transparency = sel and 0.4 or 1 })
		t.page.Visible = sel
		if sel and not instant then
			t.page.Position = UDim2.fromOffset(0, 10)
			tween(t.page, 0.35, { Position = UDim2.fromOffset(0, 0) })
		end
	end
end
connect(tabSettings.Activated, function() showTab("Cài đặt") end)
connect(tabInfo.Activated, function() showTab("Thông tin") end)

--========================= BỐ CỤC / THU NHỎ / PHÓNG TO =========================
local function layoutTarget()
	local s = uiScale.Scale
	local v = camera.ViewportSize
	local vx, vy = v.X / s, v.Y / s
	local w, h, pos
	if state.maximized then
		w, h, pos = vx - 24, vy - 76, UDim2.new(0.5, 0, 0, 64)
	else
		w, h, pos = WIN_W, WIN_H, normalPos
	end
	if state.minimized then h = MIN_H end
	return UDim2.fromOffset(w, h), pos
end

local function applyLayout(animate)
	local size, pos = layoutTarget()
	if animate then
		tween(win, 0.4, { Size = size, Position = pos })
	else
		win.Size, win.Position = size, pos
	end
end

local function updateScale()
	local v = camera.ViewportSize
	uiScale.Scale = math.clamp(math.min(v.X / 860, v.Y / 600), 0.4, 1.25)
	if state.maximized or state.open then applyLayout(false) end
end
connect(camera:GetPropertyChangedSignal("ViewportSize"), updateScale)

--========================= DYNAMIC ISLAND =========================
local island = create("TextButton", {
	Name = "DynamicIsland", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(ISL_W_CLOSED, ISL_H), BackgroundColor3 = Color3.fromRGB(10, 22, 60), BackgroundTransparency = 0.08,
	Text = "", AutoButtonColor = false, ClipsDescendants = true, BorderSizePixel = 0,
}, gui)
corner(island, 23)
create("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(70, 130, 230), Color3.fromRGB(40, 50, 120)), Rotation = 0 }, island)
do
	local st = create("UIStroke", { Color = WHITE, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, island)
	regAccentGrad(st)
end

local crownBg = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(32, 32),
	BackgroundColor3 = WHITE, BorderSizePixel = 0 }, island)
corner(crownBg, 16)
regAccentGrad(crownBg, 45)
label(crownBg, { Text = "👑", Size = UDim2.fromScale(1, 1), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center })

local nameLbl = label(island, { Text = SCRIPT_NAME, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 50, 0.5, 0),
	Size = UDim2.fromOffset(100, 24), Font = FONT_BOLD, TextSize = 22, TextTransparency = 1 })
local divider = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 156, 0.5, 0), Size = UDim2.fromOffset(1, 22),
	BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0 }, island)

-- Dynamic Island chỉ hiển thị tab/trạng thái, không có bộ đếm thời gian.
local statusLbl = label(island, {
	Text = "⚙️  Cài đặt", AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 50, 0.5, 0), Size = UDim2.new(1, -60, 0, 28),
	Font = FONT_BOLD, TextSize = 17, TextTransparency = 0,
})

local details = create("Frame", {
	Name = "IslandDetails", AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0, 12, 0, 64), Size = UDim2.fromOffset(280, 150),
	BackgroundColor3 = Color3.fromRGB(14, 28, 68), BackgroundTransparency = 0.08,
	Visible = false, BorderSizePixel = 0, ZIndex = 80,
}, gui)
corner(details, 18)
local detailsStroke = create("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 0.25 }, details)
regAccentGrad(detailsStroke)
local detailsTitle = label(details, {
	Text = "Trạng thái hiện tại", Position = UDim2.fromOffset(14, 10),
	Size = UDim2.new(1, -28, 0, 26), Font = FONT_BOLD, TextSize = 18, ZIndex = 81,
})
local detailsText = label(details, {
	Text = "", Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 1, -50),
	Font = FONT_REG, TextSize = 16, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 81,
})

local currentTab -- shared current tab state
local function refreshIslandStatus()
	local icon = currentTab == "Thông tin" and "ℹ️" or "⚙️"
	statusLbl.Text = icon .. "  " .. (currentTab or "Cài đặt")
	detailsTitle.Text = "Đang ở mục: " .. (currentTab or "Cài đặt")
	local enabled = {}
	if state.sysNotif then table.insert(enabled, "• Thông báo hệ thống: BẬT") else table.insert(enabled, "• Thông báo hệ thống: TẮT") end
	if state.scriptNotif then table.insert(enabled, "• Thông báo script: BẬT") else table.insert(enabled, "• Thông báo script: TẮT") end
	table.insert(enabled, "• Chủ đề: " .. state.theme)
	table.insert(enabled, "• Chế độ giao diện: " .. state.mode)
	detailsText.Text = table.concat(enabled, "\n")
end

local function setIsland(open)
	details.Visible = false
	if open then
		island.AnchorPoint = Vector2.new(0.5, 0)
		tween(island, 0.25, {
			Position = UDim2.new(0.5, 0, 0, 10),
			Size = UDim2.fromOffset(ISL_W_OPEN, ISL_H),
		}, Enum.EasingStyle.Quad)
		statusLbl.Visible = true
		statusLbl.TextTransparency = 0
		crownBg.Visible = true
	else
		island.AnchorPoint = Vector2.new(0, 0.5)
		tween(island, 0.25, {
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(52, 52),
		}, Enum.EasingStyle.Back)
		statusLbl.Visible = false
		crownBg.Visible = true
	end
	divider.Visible = false
	nameLbl.Visible = false
end

--========================= MỞ / ĐÓNG CỬA SỔ =========================
local visToken = 0
local function setOpen(open)
	if state.open == open then return end
	state.open = open
	visToken += 1
	local token = visToken
	setIsland(open)
	if open then
		applyLayout(false)
		win.Visible = true
		tween(win, 0.35, { GroupTransparency = 0 })
		tween(winScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	else
		closeDropdown()
		local t = tween(win, 0.25, { GroupTransparency = 1 })
		tween(winScale, 0.25, { Scale = 0.92 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		t.Completed:Once(function()
			if visToken == token then win.Visible = false end
		end)
	end
	updateBlur(false)
end

-- Nhấn một lần mở/đóng; nhấn giữ chỉ xem trạng thái chi tiết.
local pressToken = 0
local holdTriggered = false
local pressStartInput
connect(island.InputBegan, function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	pressToken += 1
	local token = pressToken
	holdTriggered = false
	pressStartInput = input
	task.delay(0.45, function()
		if token ~= pressToken or not pressStartInput then return end
		holdTriggered = true
		refreshIslandStatus()
		details.Visible = true
		details.Position = UDim2.new(0, 12, 0, 64)
		details.Size = UDim2.fromOffset(280, 150)
		tween(details, 0.18, { BackgroundTransparency = 0.04 }, Enum.EasingStyle.Quad)
	end)
end)
connect(UserInputService.InputEnded, function(input)
	if not pressStartInput then return end
	if input == pressStartInput or input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		pressToken += 1
		pressStartInput = nil
		if holdTriggered then
			details.Visible = false
		end
	end
end)
connect(island.Activated, function()
	if holdTriggered then
		holdTriggered = false
		return
	end
	setOpen(not state.open)
end)

--========================= NÚT ĐIỀU KHIỂN CỬA SỔ =========================
local function createCtrl(xOff, kind, onClick)
	local b = create("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, xOff, 0, 16), Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.85, Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 5 }, win)
	corner(b, 17)
	local function piece(props)
		local f = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BorderSizePixel = 0, ZIndex = 6 }, b)
		for k, v in props do f[k] = v end
		return f
	end
	if kind == "min" then
		reg(piece({ Size = UDim2.fromOffset(14, 2) }), "BackgroundColor3", "text")
	elseif kind == "max" then
		local f = piece({ Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1 })
		corner(f, 3)
		local st = create("UIStroke", { Thickness = 2 }, f)
		reg(st, "Color", "text")
	else
		reg(piece({ Size = UDim2.fromOffset(16, 2), Rotation = 45 }), "BackgroundColor3", "text")
		reg(piece({ Size = UDim2.fromOffset(16, 2), Rotation = -45 }), "BackgroundColor3", "text")
	end
	connect(b.MouseEnter, function() tween(b, 0.15, { BackgroundTransparency = 0.6 }) end)
	connect(b.MouseLeave, function() tween(b, 0.15, { BackgroundTransparency = 0.85 }) end)
	connect(b.Activated, onClick)
end

createCtrl(-14, "close", function() setOpen(false) end)
createCtrl(-54, "max", function()
	if state.minimized then state.minimized = false end
	state.maximized = not state.maximized
	closeDropdown()
	applyLayout(true)
end)
createCtrl(-94, "min", function()
	state.minimized = false
	closeDropdown()
	setOpen(false)
end)

--========================= KÉO CỬA SỔ BẰNG THANH TIÊU ĐỀ =========================
do
	local dragging, dragStart, startPos, moveConn, endConn
	local function stopDrag()
		dragging = false
		if moveConn then moveConn:Disconnect() moveConn = nil end
		if endConn then endConn:Disconnect() endConn = nil end
	end
	table.insert(cleanups, stopDrag)

	local function clampPos(p)
		local s = uiScale.Scale
		local v = camera.ViewportSize
		local vx, vy = v.X / s, v.Y / s
		return UDim2.new(p.X.Scale, math.clamp(p.X.Offset, -vx / 2 + 80, vx / 2 - 80), p.Y.Scale, math.clamp(p.Y.Offset, -vy / 2, vy / 2 - 60))
	end

	connect(titleBar.InputBegan, function(input)
		if state.maximized then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			stopDrag()
			dragging = true
			dragStart, startPos = input.Position, normalPos
			closeDropdown()
			moveConn = UserInputService.InputChanged:Connect(function(i)
				if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
					local d = (i.Position - dragStart) / uiScale.Scale
					normalPos = clampPos(UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y))
					win.Position = normalPos
				end
			end)
			endConn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then stopDrag() end
			end)
		end
	end)
end

--========================= DỌN DẸP =========================
gui.Destroying:Once(function()
	for _, c in connections do c:Disconnect() end
	table.clear(connections)
	for _, fn in cleanups do fn() end
end)

--========================= KHỞI ĐỘNG =========================
applyGlass(false)
applyBright()
updateScale()
showTab("Cài đặt", true)
gui.Parent = playerGui

task.delay(0.4, function()
	setOpen(true)
	showToast("chan chan đã sẵn sàng")
	notifySystem(SCRIPT_NAME, "Script đã khởi động")
end)
