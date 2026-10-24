--[[
	chan chan - Script by Nam HUB
	GUI phong cách Liquid Glass cho Roblox
	Đặt trong: StarterPlayer > StarterPlayerScripts (LocalScript)

	Bản tối ưu:
	- Liquid Glass chỉ nằm BÊN TRONG cửa sổ GUI (không còn BlurEffect toàn màn hình)
	- Bỏ bộ đếm thời gian; Dynamic Island hiển thị tab + trạng thái chức năng thực tế
	- Thu nhỏ -> hình tròn bên trái; nhấn một lần để mở; nhấn giữ để xem chức năng đang bật
]]

--========================= DỊCH VỤ =========================
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting") -- chỉ dùng để dọn BlurEffect của bản cũ; bản này KHÔNG tạo blur toàn màn hình
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera or workspace:GetPropertyChangedSignal("CurrentCamera"):Wait() and workspace.CurrentCamera

-- Xoá bản cũ nếu script chạy lại
do
	local old = playerGui:FindFirstChild("chan chan")
	if old then old:Destroy() end
	local oldBlur = Lighting:FindFirstChild("chanchan_Blur")
	if oldBlur then oldBlur:Destroy() end
end

--========================= HẰNG SỐ =========================
-- SourceSans hỗ trợ tốt tiếng Việt có dấu
local FONT_REG, FONT_MED, FONT_BOLD = Enum.Font.SourceSans, Enum.Font.SourceSansSemibold, Enum.Font.SourceSansBold
local WHITE = Color3.new(1, 1, 1)
local WIN_W, WIN_H, MIN_H = 800, 500, 66
local ISL_W_PILL, ISL_H, INFO_W = 280, 48, 260     -- Dynamic Island: dạng viên thuốc / chiều cao / bảng chi tiết
local ORB_TARGET_PX, ORB_MIN, ORB_MAX = 50, 40, 90 -- nút tròn khi thu nhỏ (đủ lớn để chạm trên điện thoại)
local ISL_ROW_H, ISL_MAX_ROWS = 40, 6               -- hàng trong bảng chi tiết
local HOLD_TIME, MOVE_TOL = 0.45, 20                -- ngưỡng nhấn giữ (giây) / dung sai di chuyển (px)
local SCRIPT_NAME, SCRIPT_VERSION, SCRIPT_AUTHOR = "chan chan", "v1.0.0", "Nam HUB"

-- Bảng màu giao diện Sáng / Tối
local THEMES = {
	["Dark Black"] = {
		window = Color3.fromRGB(12, 12, 16), panel = Color3.fromRGB(24, 24, 30),
		field = Color3.fromRGB(34, 34, 42), sidebar = Color3.fromRGB(7, 7, 10),
		text = Color3.fromRGB(255, 255, 255), sub = Color3.fromRGB(168, 170, 184),
		track = Color3.fromRGB(52, 52, 62), off = Color3.fromRGB(70, 70, 82),
		frost = Color3.fromRGB(40, 42, 70),
	},
	["Liquid Glass White"] = {
		window = Color3.fromRGB(255, 255, 255), panel = Color3.fromRGB(255, 255, 255),
		field = Color3.fromRGB(244, 246, 251), sidebar = Color3.fromRGB(246, 248, 253),
		text = Color3.fromRGB(22, 24, 32), sub = Color3.fromRGB(102, 108, 124),
		track = Color3.fromRGB(214, 220, 232), off = Color3.fromRGB(198, 204, 218),
		frost = Color3.fromRGB(255, 255, 255),
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
	["Dark Black"] = "Dark Black", ["Liquid Glass White"] = "Liquid Glass White",
	["Trong suốt"] = "Trong suốt", ["Bình thường"] = "Bình thường",
}

--========================= TRẠNG THÁI (lưu trong phiên) =========================
local state = {
	theme = "Dark Black", accent = 1, mode = "Trong suốt",
	blur = 60,      -- độ mờ nền (0-100%)
	transp = 45,    -- độ trong suốt giao diện (0-100%)
	bright = 16,    -- độ sáng (0-40px): độ rực của viền phát sáng + lớp phản chiếu kính
	sysNotif = true, scriptNotif = true,
	reduce = false, -- chế độ giảm hiệu ứng
	open = false, minimized = false, maximized = false, -- minimized = đã thu nhỏ thành hình tròn bên trái
	info = false,      -- bảng chi tiết của Dynamic Island đang mở (nhấn giữ)
	tab = "Cài đặt",  -- tab đang chọn
}

-- Giá trị mặc định dùng cho nút "Khôi phục giao diện"
local DEFAULTS = { theme = "Dark Black", accent = 1, mode = "Trong suốt", blur = 60, transp = 45, bright = 16, reduce = false }

--========================= TIỆN ÍCH =========================
local connections, cleanups = {}, {}
local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(connections, c)
	return c
end

local function tween(obj, t, props, style, dir)
	if state.reduce then t = math.min(t, 0.08) end
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- Nhóm tween: huỷ các tween cũ của nhóm trước khi chạy chuyển trạng thái mới (tránh tween chồng chéo)
local winGroup, islGroup, logoGroup = {}, {}, {}
local function groupCancel(g)
	for i = #g, 1, -1 do
		g[i]:Cancel()
		g[i] = nil
	end
end
local function groupTween(g, obj, t, props, style, dir)
	local tw = tween(obj, t, props, style, dir)
	table.insert(g, tw)
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

-- Hiệu ứng nhấn nhẹ cho nút
local function pressFx(btn)
	local sc = create("UIScale", { Scale = 1 }, btn)
	local function rel() tween(sc, 0.12, { Scale = 1 }, Enum.EasingStyle.Quad) end
	connect(btn.MouseButton1Down, function() tween(sc, 0.08, { Scale = 0.94 }, Enum.EasingStyle.Quad) end)
	connect(btn.MouseButton1Up, rel)
	connect(btn.MouseLeave, rel)
end

-- Sổ đăng ký để cập nhật khi đổi theme / màu / độ trong suốt
local themed, hooks, glassList, accentGrads, accentColors = {}, {}, {}, {}, {}
local applyIsland, refreshIsland, applyLogo, applyLayout -- khai báo trước, gán ở phần Dynamic Island

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

--========================= HIỆU ỨNG KÍNH / ĐỘ SÁNG =========================
-- Toàn bộ hiệu ứng kính nằm BÊN TRONG cửa sổ (CanvasGroup): nền trong suốt + gradient + lớp kính mờ + viền sáng.
-- Không dùng BlurEffect/Lighting nên thế giới game không bao giờ bị làm mờ.
local win, winStroke, shine, frost, frostGrad -- khai báo trước

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
		winStroke.Thickness = state.reduce and 1 or (1 + b * 1.5)
		winStroke.Transparency = state.reduce and 0.6 or (0.5 - b * 0.3)
	end
	if shine then
		shine.Visible = not state.reduce
		shine.BackgroundTransparency = 0.94 - b * 0.2
	end
end

-- "Độ mờ nền": độ dày của lớp kính mờ (frost) nằm trong cửa sổ
local function applyFrost(smooth)
	if not frost then return end
	local t = 1 - (state.blur / 100) * 0.5
	if smooth then tween(frost, 0.25, { BackgroundTransparency = t }, Enum.EasingStyle.Quad)
	else frost.BackgroundTransparency = t end
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
	local seq = state.reduce and ColorSequence.new(a.c1) or a.seq
	for _, g in accentGrads do g.Color = seq end
	for _, e in accentColors do tween(e.obj, 0.25, { [e.prop] = a.c1 }, Enum.EasingStyle.Quad) end
end

-- Chế độ giảm hiệu ứng: tween gần như tức thì, gradient -> màu đơn, tắt lớp phản chiếu
local function applyReduce()
	if frostGrad then frostGrad.Enabled = not state.reduce end
	applyAccent()
	applyBright()
end

--========================= THÔNG BÁO =========================
local toast = create("CanvasGroup", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(300, 38),
	BackgroundColor3 = WHITE, BackgroundTransparency = 0.05, GroupTransparency = 1, Visible = false,
}, gui)
corner(toast, 19)
reg(toast, "BackgroundColor3", "panel")
do
	local st = create("UIStroke", { Color = WHITE, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, toast)
	regAccentGrad(st)
end
local toastLabel = label(toast, { Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(12, 0),
	TextXAlignment = Enum.TextXAlignment.Center, TextSize = 17, TextTruncate = Enum.TextTruncate.AtEnd })
reg(toastLabel, "TextColor3", "text")
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
local DEFAULT_POS = UDim2.new(0.5, 0, 0.5, -WIN_H / 2 + 30)
local normalPos = DEFAULT_POS

win = create("CanvasGroup", {
	Name = "Window", AnchorPoint = Vector2.new(0.5, 0), Position = normalPos, Size = UDim2.fromOffset(WIN_W, WIN_H),
	BorderSizePixel = 0, GroupTransparency = 1, Visible = false,
}, gui)
corner(win, 26)
reg(win, "BackgroundColor3", "window")
regGlass(win, "window")
local winScale = create("UIScale", { Scale = 0.92 }, win)

-- Lớp kính mờ (frost) bên trong cửa sổ, nằm dưới mọi thành phần khác
frost = create("Frame", { Name = "Frost", Size = UDim2.fromScale(1, 1), BorderSizePixel = 0, ZIndex = 0 }, win)
reg(frost, "BackgroundColor3", "frost")
frostGrad = create("UIGradient", { Rotation = 35, Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.55),
}) }, frost)
applyFrost(false)

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
create("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, Color3.fromRGB(228, 232, 246)) }, sidebar)

label(sidebar, { Text = "👑", Position = UDim2.fromOffset(14, 8), Size = UDim2.fromOffset(34, 34), TextSize = 26,
	TextXAlignment = Enum.TextXAlignment.Center })
reg(label(sidebar, { Text = SCRIPT_NAME, Position = UDim2.fromOffset(54, 6), Size = UDim2.new(1, -60, 0, 24), Font = FONT_BOLD, TextSize = 22 }), "TextColor3", "text")
reg(label(sidebar, { Text = "Script by Nam HUB", Position = UDim2.fromOffset(54, 28), Size = UDim2.new(1, -60, 0, 16),
	TextSize = 14, Font = FONT_REG }), "TextColor3", "sub")

local tabs = {}
local function createTab(name, icon, y)
	local b = create("TextButton", {
		Name = name, Position = UDim2.new(0, 10, 0, y), Size = UDim2.new(1, -20, 0, 42),
		BackgroundColor3 = WHITE, BackgroundTransparency = 1, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
	}, sidebar)
	corner(b, 14)
	pressFx(b)
	regAccentGrad(b)
	local st = create("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 1 }, b)
	label(b, { Text = icon, Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(30, 42), TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center })
	local txt = label(b, { Text = name, Position = UDim2.fromOffset(52, 0), Size = UDim2.new(1, -56, 1, 0), TextSize = 19, Font = FONT_MED })
	tabs[name] = { btn = b, stroke = st, icon = icon, txt = txt }
	return b
end
local tabSettings = createTab("Cài đặt", "⚙️", 80)
local tabInfo = createTab("Thông tin", "ℹ️", 130)

-- Chữ tab: trắng khi đang chọn (nền màu nhấn), màu chữ của theme khi không chọn
local function updateTabColors()
	local th = THEMES[state.theme]
	for n, t in tabs do
		t.txt.TextColor3 = (n == state.tab) and WHITE or th.text
	end
end
table.insert(hooks, updateTabColors)
updateTabColors()

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
	local ps = create("UIStroke", { Thickness = 1, Transparency = 0.82, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
	reg(ps, "Color", "sub")
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
local ddScale = create("UIScale", { Scale = 1 }, ddList)
local ddToken = 0
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
	ddOpenFor = nil
	if not ddLayer.Visible then return end
	ddToken += 1
	local tk = ddToken
	ddCatcher.Visible = false
	local tw = tween(ddScale, 0.1, { Scale = 0.94 }, Enum.EasingStyle.Quad)
	tw.Completed:Once(function()
		if ddToken == tk then
			ddLayer.Visible = false
			ddCatcher.Visible = true
		end
	end)
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
	ddToken += 1
	ddCatcher.Visible = true
	ddScale.Scale = 0.92
	ddLayer.Visible = true
	ddOpenFor = btn
	tween(ddScale, 0.15, { Scale = 1 }, Enum.EasingStyle.Quad)
end

local function createDropdown(parent, order, title, options, getCurrent, onPick)
	local r = row(parent, order, 40)
	local l = label(r, { Text = title, Size = UDim2.new(1, -196, 1, 0), TextSize = 18 })
	reg(l, "TextColor3", "text")
	local btn = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(188, 34),
		Text = "", AutoButtonColor = false, BorderSizePixel = 0,
	}, r)
	corner(btn, 12)
	reg(btn, "BackgroundColor3", "field")
	local st = create("UIStroke", { Thickness = 1, Transparency = 0.75 }, btn)
	reg(st, "Color", "sub")
	local txt = label(btn, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -34, 1, 0), TextSize = 17, TextTruncate = Enum.TextTruncate.AtEnd })
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
	return setValue
end

--------------------------- Công tắc ---------------------------
local function createToggle(parent, order, title, desc, default, onChange)
	local r = row(parent, order, 54)
	local t = label(r, { Text = title, Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, -66, 0, 22), Font = FONT_MED, TextSize = 18 })
	reg(t, "TextColor3", "text")
	local d = label(r, { Text = desc, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, -66, 0, 18), Font = FONT_REG, TextSize = 14 })
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
	return function(v)
		value = v
		render(false)
	end
end

--========================= TRANG CÀI ĐẶT =========================
createHead(pageSettings, "⚙️", "Cài đặt", "Tùy chỉnh giao diện và trải nghiệm theo ý thích của bạn")

local cols = create("Frame", { Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 1, -66), BackgroundTransparency = 1 }, pageSettings)
local scLeft = createPanel(cols, UDim2.fromOffset(0, 0), UDim2.new(0.58, -5, 1, 0), "🎨", "Giao diện")
local scRight = createPanel(cols, UDim2.new(0.58, 5, 0, 0), UDim2.new(0.42, -5, 1, 0), "🔔", "Thông báo & hệ thống", "Thông báo và hiệu năng")

-- Chủ đề Sáng / Tối
local refreshThemeDD = createDropdown(scLeft, 1, "Chủ đề", { "Dark Black", "Liquid Glass White" }, function() return state.theme end, function(opt)
	state.theme = opt
	applyTheme()
	showToast("Giao diện: " .. opt)
end)

-- Màu chủ đạo
local refreshAccentRings
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
	refreshAccentRings = refreshRings
end

-- Chế độ hiển thị
local refreshModeDD = createDropdown(scLeft, 4, "Chế độ hiển thị", { "Trong suốt", "Bình thường" }, function() return state.mode end, function(opt)
	state.mode = opt
	applyGlass(true)
	refreshIsland()
	showToast("Chế độ hiển thị: " .. opt)
end)

-- Ba thanh trượt
local setBlurSlider = createSlider(scLeft, 5, "Độ mờ nền", 0, 100, state.blur, function(v) return v .. "%" end, function(v)
	state.blur = v
	applyFrost(false)
end)
local setTranspSlider = createSlider(scLeft, 6, "Độ trong suốt", 0, 100, state.transp, function(v) return v .. "%" end, function(v)
	state.transp = v
	applyGlass(false)
end)
local setBrightSlider = createSlider(scLeft, 7, "Độ sáng", 0, 40, state.bright, function(v) return v .. "px" end, function(v)
	state.bright = v
	applyBright()
end)

-- Thông báo
createToggle(scRight, 1, "Thông báo hệ thống", "Thông báo của Roblox", state.sysNotif, function(v)
	state.sysNotif = v
	refreshIsland()
	if v then notifySystem(SCRIPT_NAME, "Đã bật thông báo hệ thống") end
	showToast(v and "Đã bật thông báo hệ thống" or "Đã tắt thông báo hệ thống")
end)
createToggle(scRight, 2, "Thông báo script", "Thông báo trong GUI", state.scriptNotif, function(v)
	state.scriptNotif = v
	refreshIsland()
	if v then showToast("Đã bật thông báo script") end
end)

-- Giảm hiệu ứng
local setReduceToggle = createToggle(scRight, 3, "Giảm hiệu ứng", "Bớt chuyển động, phát sáng, gradient", state.reduce, function(v)
	state.reduce = v
	applyReduce()
	refreshIsland()
	showToast(v and "Đã bật giảm hiệu ứng" or "Đã tắt giảm hiệu ứng")
end)

-- Nút bấm dùng chung
local function createButton(parent, order, text, onClick)
	local r = row(parent, order, 46)
	local b = create("TextButton", { Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 36), Text = text,
		Font = FONT_MED, TextSize = 17, AutoButtonColor = false, BorderSizePixel = 0 }, r)
	corner(b, 12)
	reg(b, "BackgroundColor3", "field")
	reg(b, "TextColor3", "text")
	local st = create("UIStroke", { Thickness = 1, Transparency = 0.75 }, b)
	reg(st, "Color", "sub")
	pressFx(b)
	connect(b.Activated, onClick)
	return b
end

-- Khôi phục giao diện (nhấn hai lần để xác nhận)
local RESET_TEXT = "Khôi phục giao diện mặc định"
local resetBtn, resetArmed, resetToken
resetToken = 0
local function disarmReset()
	resetArmed = false
	resetBtn.Text = RESET_TEXT
	resetBtn.TextColor3 = THEMES[state.theme].text
end
resetBtn = createButton(scRight, 4, RESET_TEXT, function()
	resetToken += 1
	local tk = resetToken
	if not resetArmed then
		resetArmed = true
		resetBtn.Text = "Nhấn lại để xác nhận"
		resetBtn.TextColor3 = Color3.fromRGB(255, 96, 96)
		task.delay(3, function()
			if resetToken == tk and resetArmed then disarmReset() end
		end)
		return
	end
	disarmReset()
	closeDropdown()
	state.theme, state.accent, state.mode = DEFAULTS.theme, DEFAULTS.accent, DEFAULTS.mode
	state.blur, state.transp, state.bright, state.reduce = DEFAULTS.blur, DEFAULTS.transp, DEFAULTS.bright, DEFAULTS.reduce
	state.maximized = false
	normalPos = DEFAULT_POS
	applyTheme()
	applyGlass(true)
	applyFrost(true)
	applyReduce() -- gồm applyAccent + applyBright
	applyLayout(true)
	refreshThemeDD()
	refreshModeDD()
	refreshAccentRings()
	setBlurSlider(state.blur, true)
	setTranspSlider(state.transp, true)
	setBrightSlider(state.bright, true)
	setReduceToggle(state.reduce)
	refreshIsland()
	showToast("Đã khôi phục giao diện mặc định")
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
	if state.tab == name and not instant then return end
	state.tab = name
	updateTabColors()
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
	if refreshIsland then refreshIsland() end -- Dynamic Island cập nhật ngay khi đổi tab
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
	return UDim2.fromOffset(w, h), pos
end

applyLayout = function(animate)
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
	if applyIsland then applyIsland(false) end -- island tự co theo màn hình
	if applyLogo then applyLogo(false) end -- logo tròn giữ kích thước chạm ổn định
end
connect(camera:GetPropertyChangedSignal("ViewportSize"), updateScale)

--========================= DYNAMIC ISLAND =========================
-- Island luôn nằm giữa phía trên, nền ĐEN + chữ trắng ở mọi theme. Tạo một lần, không bao giờ bị ẩn/xoá khi thu nhỏ GUI.
-- Logo tròn bên trái (CCLogo) là một đối tượng RIÊNG, chỉ hiện khi GUI được thu nhỏ bằng nút "-".
--   • viên thuốc : "chan chan" + tab đang chọn + trạng thái ngắn gọn
--   • bảng chi tiết (nhấn giữ): liệt kê chức năng Bật/Tắt, chỉ để xem

local GREEN, GRAY = Color3.fromRGB(130, 240, 175), Color3.fromRGB(150, 150, 164)

-- Danh sách chức năng Dynamic Island theo dõi (đọc từ state thật, không có dữ liệu giả)
local FEATURES = {
	{ name = "Thông báo hệ thống", on = function() return state.sysNotif end,
		detail = function() return "Thông báo của Roblox" end },
	{ name = "Thông báo script", on = function() return state.scriptNotif end,
		detail = function() return "Hiển thị ngay trong GUI" end },
	{ name = "Chế độ trong suốt", on = function() return state.mode == "Trong suốt" end,
		detail = function()
			if state.mode == "Trong suốt" then
				return string.format("Trong suốt %d%% · Mờ kính %d%%", state.transp, state.blur)
			end
			return "Chế độ bình thường"
		end },
	{ name = "Giảm hiệu ứng", on = function() return state.reduce end,
		detail = function() return state.reduce and "Ít chuyển động, không gradient" or "Hiệu ứng đầy đủ" end },
}

local function countEnabled()
	local n = 0
	for _, f in FEATURES do
		if f.on() then n += 1 end
	end
	return n
end

-- Kích thước tự co theo màn hình
local function islandWidths()
	local vx = camera.ViewportSize.X / uiScale.Scale
	return math.clamp(vx - 150, 190, ISL_W_PILL), math.clamp(vx - 40, 200, INFO_W)
end

local island = create("TextButton", {
	Name = "DynamicIsland", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10),
	Size = UDim2.fromOffset(ISL_W_PILL, ISL_H), BackgroundColor3 = Color3.fromRGB(6, 6, 8), BackgroundTransparency = 0.04,
	Text = "", AutoButtonColor = false, ClipsDescendants = true, BorderSizePixel = 0, ZIndex = 50,
}, gui)
local islandCorner = corner(island, ISL_H / 2)
do
	local st = create("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, island)
	regAccentGrad(st)
end

local islandIcon = create("Frame", { Name = "Icon", Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(32, 32),
	BackgroundColor3 = WHITE, BorderSizePixel = 0 }, island)
create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, islandIcon)
regAccentGrad(islandIcon, 45)
local islandIconLbl = label(islandIcon, { Text = "👑", Size = UDim2.fromScale(1, 1), TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Center })

local islandTitle = label(island, { Text = SCRIPT_NAME, Position = UDim2.fromOffset(50, 5), Size = UDim2.new(1, -100, 0, 22),
	Font = FONT_BOLD, TextSize = 18, TextTruncate = Enum.TextTruncate.AtEnd })
local islandStatus = label(island, { Position = UDim2.fromOffset(50, 26), Size = UDim2.new(1, -100, 0, 17),
	Font = FONT_REG, TextSize = 13, TextColor3 = Color3.fromRGB(190, 192, 204), TextTruncate = Enum.TextTruncate.AtEnd })

-- Nút cài đặt (giữ nguyên chức năng cũ: mở tab Cài đặt)
local gearBtn = create("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0, ISL_H / 2), Size = UDim2.fromOffset(34, 34),
	BackgroundColor3 = WHITE, BackgroundTransparency = 0.88, Text = "⚙️", TextSize = 18, AutoButtonColor = false, BorderSizePixel = 0 }, island)
corner(gearBtn, 17)
pressFx(gearBtn)

-- Bảng chi tiết (tạo sẵn một lần, chỉ đổi nội dung/hiển thị)
local infoList = create("Frame", { Name = "InfoList", Position = UDim2.fromOffset(10, 52), Size = UDim2.new(1, -20, 1, -62),
	BackgroundTransparency = 1, Visible = false }, island)
local infoRows = {}
for i = 1, ISL_MAX_ROWS do
	local r = create("Frame", { Position = UDim2.fromOffset(0, (i - 1) * ISL_ROW_H), Size = UDim2.new(1, 0, 0, ISL_ROW_H - 4),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.93, BorderSizePixel = 0, Visible = false }, infoList)
	corner(r, 10)
	local dot = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.fromOffset(8, 8),
		BackgroundColor3 = WHITE, BorderSizePixel = 0 }, r)
	corner(dot, 4)
	local dg = regAccentGrad(dot, 45)
	local nm = label(r, { Position = UDim2.fromOffset(24, 1), Size = UDim2.new(1, -72, 0, 18), Font = FONT_BOLD, TextSize = 15,
		TextTruncate = Enum.TextTruncate.AtEnd })
	local st = label(r, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 1), Size = UDim2.fromOffset(40, 18),
		Font = FONT_BOLD, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right })
	local dt = label(r, { Position = UDim2.fromOffset(24, 18), Size = UDim2.new(1, -32, 0, 16), Font = FONT_REG, TextSize = 12,
		TextColor3 = Color3.fromRGB(190, 192, 204), TextTruncate = Enum.TextTruncate.AtEnd })
	infoRows[i] = { frame = r, name = nm, detail = dt, state = st, dot = dot, dotGrad = dg }
end
local infoMore = label(infoList, { Size = UDim2.new(1, 0, 0, 20), Font = FONT_REG, TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.fromRGB(190, 192, 204), Visible = false })

local infoH = ISL_ROW_H -- chiều cao phần danh sách khi bảng chi tiết mở

-- Điền bảng chi tiết từ trạng thái thực tế; trả về chiều cao phần danh sách
local function fillInfoRows()
	local total = #FEATURES
	local shown = math.min(total, ISL_MAX_ROWS)
	for i, r in infoRows do
		local f = FEATURES[i]
		if i <= shown and f then
			local on = f.on()
			r.frame.Visible = true
			r.name.Text = f.name
			r.detail.Text = f.detail()
			r.state.Text = on and "Bật" or "Tắt"
			r.state.TextColor3 = on and GREEN or GRAY
			r.dotGrad.Enabled = on
			r.dot.BackgroundColor3 = on and WHITE or Color3.fromRGB(96, 96, 108)
		else
			r.frame.Visible = false
		end
	end
	local more = total - shown
	infoMore.Visible = more > 0
	if more > 0 then
		infoMore.Text = "+" .. more .. " chức năng khác"
		infoMore.Position = UDim2.fromOffset(0, shown * ISL_ROW_H)
	end
	return shown * ISL_ROW_H + (more > 0 and 22 or 0)
end

-- Hình dạng island: chỉ có viên thuốc hoặc bảng chi tiết (luôn ở giữa phía trên)
local wasInfoShape = false
applyIsland = function(animate)
	local pillW, infoW = islandWidths()
	local info = state.info
	local collapsing = wasInfoShape and not info
	wasInfoShape = info

	local size, radius
	if info then
		size, radius = UDim2.fromOffset(infoW, 52 + infoH + 10), 22
	else
		size, radius = UDim2.fromOffset(pillW, ISL_H), ISL_H / 2
	end
	gearBtn.Visible = not info
	if info then infoList.Visible = true end

	groupCancel(islGroup) -- huỷ tween cũ trước khi chuyển trạng thái mới
	if animate then
		local style, t = Enum.EasingStyle.Quint, 0.35
		if info then
			t = 0.3
		elseif collapsing then
			style, t = Enum.EasingStyle.Back, 0.45 -- thu gọn: đàn hồi nhẹ
		end
		local tw = groupTween(islGroup, island, t, { Size = size }, style)
		groupTween(islGroup, islandCorner, t, { CornerRadius = UDim.new(0, radius) }, style)
		tw.Completed:Once(function(ps)
			if ps == Enum.PlaybackState.Completed and not state.info then infoList.Visible = false end
		end)
	else
		island.Size = size
		islandCorner.CornerRadius = UDim.new(0, radius)
		infoList.Visible = info
	end
end

-- Cập nhật tên tab/trạng thái ngay cả khi cửa sổ đang ẩn (chỉ gán khi dữ liệu thay đổi)
local lastStatus, lastIcon
refreshIsland = function()
	local n = countEnabled()
	local short = n > 0 and (n .. " chức năng bật") or "chưa bật chức năng"
	local status
	if state.tab == "Thông tin" then
		status = state.tab .. " · " .. SCRIPT_VERSION
	else
		status = state.tab .. " · " .. short
	end
	if status ~= lastStatus then
		lastStatus = status
		islandStatus.Text = status
	end
	local t = tabs[state.tab]
	local ic = t and t.icon or "👑"
	if ic ~= lastIcon then
		lastIcon = ic
		islandIconLbl.Text = ic
	end
end

local function showInfo()
	if state.info then return end
	refreshIsland()
	infoH = fillInfoRows()
	state.info = true
	applyIsland(true)
end

local function hideInfo()
	if not state.info then return end
	state.info = false
	applyIsland(true)
end

--========================= LOGO TRÒN BÊN TRÁI (khi thu nhỏ) =========================
-- Đối tượng riêng, tạo một lần: chỉ đổi Visible/Scale nên không bao giờ bị nhân bản.
local logo = create("TextButton", { Name = "CCLogo", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0),
	Size = UDim2.fromOffset(52, 52), BackgroundColor3 = Color3.fromRGB(6, 6, 8), BackgroundTransparency = 0.04,
	Text = "", AutoButtonColor = false, BorderSizePixel = 0, Visible = false, ZIndex = 45 }, gui)
create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, logo)
create("UIAspectRatioConstraint", { AspectRatio = 1 }, logo) -- luôn tròn, không méo
do
	local st = create("UIStroke", { Color = WHITE, Thickness = 1.5, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, logo)
	regAccentGrad(st)
end
do
	local inner = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.7, 0.7), BackgroundColor3 = WHITE, BorderSizePixel = 0 }, logo)
	create("UICorner", { CornerRadius = UDim.new(0.5, 0) }, inner)
	regAccentGrad(inner, 45)
	label(inner, { Text = "👑", Size = UDim2.fromScale(1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center })
end
local logoScale = create("UIScale", { Scale = 0 }, logo)
local logoToken = 0

-- Lề an toàn bên trái (tai thỏ/camera trên điện thoại)
local function safeLeft()
	local ok, z = pcall(function() return GuiService:GetSafeZoneOffsets() end)
	if ok and type(z) == "table" and tonumber(z.left) then return z.left end
	return 0
end

applyLogo = function(animate)
	local ui = uiScale.Scale
	local o = math.clamp(math.floor(ORB_TARGET_PX / ui + 0.5), ORB_MIN, ORB_MAX)
	logo.Size = UDim2.fromOffset(o, o)
	logo.Position = UDim2.new(0, math.floor((10 + safeLeft()) / ui + 0.5), 0.5, 0)
	groupCancel(logoGroup)
	logoToken += 1
	local tk = logoToken
	if state.minimized then
		logo.Visible = true
		if animate then groupTween(logoGroup, logoScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		else logoScale.Scale = 1 end
	elseif animate and logo.Visible then
		local tw = groupTween(logoGroup, logoScale, 0.2, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tw.Completed:Once(function(ps)
			if logoToken == tk and ps == Enum.PlaybackState.Completed then logo.Visible = false end
		end)
	else
		logoScale.Scale = 0
		logo.Visible = false
	end
end

--========================= MỞ / ĐÓNG / THU NHỎ =========================
-- open = cửa sổ đang hiện; minimized = (khi ẩn) hiện logo tròn bên trái. Island KHÔNG bị tác động.
-- Chỉ ẩn/hiện giao diện: không tắt script, không huỷ GUI, giữ nguyên tab và trạng thái các nút.
local visToken = 0
local function setView(open, minimized)
	minimized = minimized and not open
	if state.open == open and state.minimized == minimized then return end
	local openChanged = state.open ~= open
	state.open, state.minimized = open, minimized

	if openChanged then
		visToken += 1
		local token = visToken
		groupCancel(winGroup)
		if open then
			applyLayout(false)
			win.Visible = true
			groupTween(winGroup, win, 0.35, { GroupTransparency = 0 })
			groupTween(winGroup, winScale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		else
			closeDropdown()
			local t = groupTween(winGroup, win, 0.25, { GroupTransparency = 1 })
			groupTween(winGroup, winScale, 0.25, { Scale = minimized and 0.75 or 0.92 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			t.Completed:Once(function(ps)
				-- ẩn hẳn cửa sổ khi hoạt ảnh xong: không còn khung vô hình chặn thao tác
				if visToken == token and ps == Enum.PlaybackState.Completed then win.Visible = false end
			end)
		end
	end
	applyLogo(true)
end

--========================= NHẤN MỘT LẦN / NHẤN GIỮ TRÊN ISLAND =========================
-- Island KHÔNG dùng Activated: dùng sự kiện đầu vào + ngưỡng thời gian để phân biệt chính xác.
--   nhấn nhanh rồi thả      -> chuyển đổi đóng/mở GUI
--   giữ quá HOLD_TIME       -> mở bảng chi tiết; thả tay -> thu gọn, KHÔNG mở GUI, KHÔNG đổi chức năng
--   kéo ra xa / bị huỷ      -> huỷ thao tác, không kích hoạt gì
local press -- thao tác nhấn đang diễn ra (mỗi lúc chỉ một thao tác)

local function endPress()
	local rec = press
	press = nil
	if rec then
		if rec.moveConn then rec.moveConn:Disconnect() end
		if rec.endConn then rec.endConn:Disconnect() end
	end
end
table.insert(cleanups, endPress)

local function releasePress(rec, cancelled)
	if press ~= rec then return end
	local wasHeld = rec.held
	endPress()
	if wasHeld then hideInfo() return end
	if cancelled then return end
	setView(not state.open, false)
end

local function pointerPos(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	return UserInputService:GetMouseLocation()
end

connect(island.InputBegan, function(input)
	if press then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
	-- chạm vào nút cài đặt thì để nút đó tự xử lý
	if gearBtn.Visible and input.Position.X >= gearBtn.AbsolutePosition.X - 2 then return end

	local rec = { input = input, origin = pointerPos(input), held = false }
	press = rec
	rec.endConn = input.Changed:Connect(function()
		local s = input.UserInputState
		if s == Enum.UserInputState.End then releasePress(rec, false)
		elseif s == Enum.UserInputState.Cancel then releasePress(rec, true) end
	end)
	rec.moveConn = UserInputService.InputChanged:Connect(function(i)
		if press ~= rec then return end
		if i.UserInputType == Enum.UserInputType.MouseMovement or i == rec.input then
			if (pointerPos(rec.input) - rec.origin).Magnitude > MOVE_TOL then releasePress(rec, true) end
		end
	end)
	task.delay(HOLD_TIME, function()
		if press == rec and not rec.held then
			rec.held = true
			showInfo()
		end
	end)
end)

-- Mất focus cửa sổ giữa lúc đang nhấn: huỷ để không bị kẹt bảng chi tiết
connect(UserInputService.WindowFocusReleased, function()
	if press then releasePress(press, true) end
end)

connect(gearBtn.Activated, function()
	showTab("Cài đặt")
	setView(true, false)
end)

-- Nhấn logo tròn: mở lại GUI (island không bị ảnh hưởng)
connect(logo.Activated, function() setView(true, false) end)

--========================= NÚT ĐIỀU KHIỂN CỬA SỔ =========================
local function createCtrl(xOff, kind, onClick)
	local b = create("TextButton", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, xOff, 0, 16), Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.9, Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 5 }, win)
	corner(b, 17)
	reg(b, "BackgroundColor3", "text")
	pressFx(b)
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
	connect(b.MouseEnter, function() tween(b, 0.15, { BackgroundTransparency = 0.78 }) end)
	connect(b.MouseLeave, function() tween(b, 0.15, { BackgroundTransparency = 0.9 }) end)
	connect(b.Activated, onClick)
end

createCtrl(-14, "close", function() setView(false, false) end) -- chỉ ẩn cửa sổ, script vẫn chạy
createCtrl(-54, "max", function()
	state.maximized = not state.maximized
	closeDropdown()
	applyLayout(true)
end)
createCtrl(-94, "min", function() setView(false, true) end) -- thu nhỏ thành hình tròn bên trái

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
	groupCancel(winGroup)
	groupCancel(islGroup)
	groupCancel(logoGroup)
end)

--========================= KHỞI ĐỘNG =========================
applyGlass(false)
applyBright()
updateScale()
showTab("Cài đặt", true)
applyIsland(false)
applyLogo(false)
gui.Parent = playerGui

task.delay(0.4, function()
	setView(true, false)
	showToast("chan chan đã sẵn sàng")
	notifySystem(SCRIPT_NAME, "Script đã khởi động")
end)
