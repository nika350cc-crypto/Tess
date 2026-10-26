--[[
    chan chan GUI — Liquid Glass (Roblox Luau)
    Một file duy nhất, không tải mã ngoài, không thư viện ngoài.

    LƯU Ý QUAN TRỌNG
    * Các công tắc Farm chỉ LƯU TRẠNG THÁI trong phiên chạy. Script này KHÔNG chứa
      logic tự động cho game nào cả, và giao diện sẽ không giả vờ là chức năng đang chạy.
    * Muốn gắn chức năng thật (nếu game/môi trường cho phép), gán hàm vào bảng Handlers
      bên dưới. Hàm nhận 1 tham số: true (bật) / false (tắt). Khi đóng script, mọi
      handler đang bật sẽ được gọi với false để bạn dừng tác vụ của mình.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

----------------------------------------------------------------------
-- CẤU HÌNH
----------------------------------------------------------------------
local VERSION = "v1.0.0"
local CLEANUP_KEY = "__chan_chan_cleanup"
local BASE_W, BASE_H = 640, 380

-- Gắn chức năng thật tại đây (để trống = chưa có logic).
-- Ví dụ: Handlers.AutoFarm = function(enabled) ... end
local Handlers = {}

local FEATURES = {
	{ key = "AutoFarm", label = "Auto Farm" },
	{ key = "AutoQuest", label = "Auto Quest" },
	{ key = "AutoAttack", label = "Auto Attack" },
	{ key = "AutoCollect", label = "Auto Collect" },
	{ key = "FastMode", label = "Fast Mode" },
}

local NAV = {
	{ key = "home", label = "Trang chủ" },
	{ key = "farm", label = "Farm" },
	{ key = "combat", label = "Combat" },
	{ key = "quest", label = "Quest" },
	{ key = "items", label = "Vật phẩm" },
	{ key = "settings", label = "Cài đặt" },
}

-- Màu sắc
local WHITE = Color3.fromRGB(255, 255, 255)
local SUBTEXT = Color3.fromRGB(165, 172, 184)
local BORDER = Color3.fromRGB(190, 225, 255)
local GLASS = Color3.fromRGB(16, 20, 28)
local GLASS2 = Color3.fromRGB(24, 30, 42)
local ON_COLOR = Color3.fromRGB(78, 190, 130)
local OFF_COLOR = Color3.fromRGB(78, 84, 96)
local ACCENT = Color3.fromRGB(150, 205, 255)

----------------------------------------------------------------------
-- MÔI TRƯỜNG / DỌN BẢN CŨ (tránh tạo trùng khi chạy lại)
----------------------------------------------------------------------
local function getEnv()
	local ok, e = pcall(function()
		return getgenv()
	end)
	if ok and type(e) == "table" then
		return e
	end
	return _G
end
local env = getEnv()
if type(env[CLEANUP_KEY]) == "function" then
	pcall(env[CLEANUP_KEY])
	env[CLEANUP_KEY] = nil
end

----------------------------------------------------------------------
-- QUẢN LÝ KẾT NỐI / TWEEN
----------------------------------------------------------------------
local alive = true
local conns = {}
local activeTweens = {}
local taskThreads = {}

local function connect(signal, fn)
	local c = signal:Connect(fn)
	conns[#conns + 1] = c
	return c
end

local settings = {
	optimize = false,
	reduceMotion = false,
	islandY = 10,
}

-- Phát hiện thiết bị yếu (an toàn nếu API không có)
pcall(function()
	local q = UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	if q > 0 and q <= 3 then
		settings.optimize = true
	end
end)

local function tween(obj, dur, props)
	local old = activeTweens[obj]
	if old then
		pcall(function()
			old:Cancel()
		end)
		activeTweens[obj] = nil
	end
	if settings.reduceMotion or dur <= 0 then
		for k, v in pairs(props) do
			obj[k] = v
		end
		return
	end
	local t = TweenService:Create(obj, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	activeTweens[obj] = t
	t:Play()
end

local function after(sec, fn)
	if settings.reduceMotion or sec <= 0 then
		fn()
		return
	end
	local th = task.delay(sec, function()
		if alive then
			fn()
		end
	end)
	taskThreads[#taskThreads + 1] = th
end

----------------------------------------------------------------------
-- HÀM TẠO GIAO DIỆN
----------------------------------------------------------------------
local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	inst.Parent = parent
	return inst
end

local function corner(p, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r) }, p)
end

local function stroke(p, th, color, transparency)
	return new("UIStroke", {
		Thickness = th,
		Color = color or BORDER,
		Transparency = transparency or 0.6,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, p)
end

local function label(parent, text, size, color, font, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1,
		Text = text,
		TextSize = size,
		TextColor3 = color or WHITE,
		Font = font or Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, nil)
	if props then
		for k, v in pairs(props) do
			l[k] = v
		end
	end
	l.Parent = parent
	return l
end

local gradients = {} -- để tắt khi bật "Tối ưu hiệu ứng"

-- Biểu tượng vương miện đơn giản vẽ bằng Frame (không dùng ảnh)
local function crown(parent, size, color, position, anchor)
	local f = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Position = position or UDim2.new(),
		AnchorPoint = anchor or Vector2.zero,
	}, parent)
	local function box(x, y, w, h, radius)
		local b = new("Frame", {
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
		}, f)
		new("UICorner", { CornerRadius = UDim.new(radius, 0) }, b)
		return b
	end
	box(0.16, 0.46, 0.68, 0.3, 0.12) -- thân
	box(0.16, 0.8, 0.68, 0.1, 0.5) -- đế
	box(0.16, 0.3, 0.12, 0.3, 0.3) -- chấu trái
	box(0.44, 0.2, 0.12, 0.4, 0.3) -- chấu giữa
	box(0.72, 0.3, 0.12, 0.3, 0.3) -- chấu phải
	box(0.12, 0.2, 0.2, 0.2, 0.5) -- bi trái
	box(0.4, 0.08, 0.2, 0.2, 0.5) -- bi giữa
	box(0.68, 0.2, 0.2, 0.2, 0.5) -- bi phải
	return f
end

----------------------------------------------------------------------
-- SCREENGUI
----------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "chan chan"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local function attach(g)
	local candidates = {}
	local ok, h = pcall(function()
		return gethui()
	end)
	if ok and typeof(h) == "Instance" then
		candidates[#candidates + 1] = h
	end
	candidates[#candidates + 1] = CoreGui
	local lp = Players.LocalPlayer
	if lp then
		local pg = lp:FindFirstChildOfClass("PlayerGui") or lp:WaitForChild("PlayerGui", 5)
		if pg then
			candidates[#candidates + 1] = pg
		end
	end
	for _, p in ipairs(candidates) do
		local okp = pcall(function()
			g.Parent = p
		end)
		if okp and g.Parent == p then
			return true
		end
	end
	return false
end

if not attach(gui) then
	warn("[chan chan] Không thể gắn giao diện vào màn hình.")
	return
end

----------------------------------------------------------------------
-- CỬA SỔ CHÍNH
----------------------------------------------------------------------
local holder = new("Frame", {
	Name = "Window",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(400, 240),
	Size = UDim2.fromOffset(BASE_W, BASE_H),
	BackgroundTransparency = 1,
}, gui)
local adaptScale = new("UIScale", { Scale = 1 }, holder)

local body = new("Frame", {
	Name = "Body",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = GLASS,
	BackgroundTransparency = 0.18,
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, holder)
corner(body, 22)
stroke(body, 1.2, BORDER, 0.5)
local animScale = new("UIScale", { Scale = 1 }, body)
do
	local g = new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.fromRGB(30, 38, 54), Color3.fromRGB(8, 10, 14)),
	}, body)
	gradients[#gradients + 1] = g
end

-- Tiêu đề
local header = new("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 56),
	BackgroundTransparency = 1,
}, body)

local shine = new("Frame", {
	Size = UDim2.new(0, 120, 1, 0),
	Position = UDim2.new(0.55, 0, 0, 0),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.94,
	BorderSizePixel = 0,
	Rotation = 0,
}, header)

local logoBadge = new("Frame", {
	Position = UDim2.fromOffset(14, 10),
	Size = UDim2.fromOffset(36, 36),
	BackgroundColor3 = GLASS2,
	BackgroundTransparency = 0.2,
}, header)
corner(logoBadge, 18)
stroke(logoBadge, 1, BORDER, 0.5)
crown(logoBadge, 24, WHITE, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))

label(header, "chan chan", 18, WHITE, Enum.Font.GothamBold, {
	Position = UDim2.fromOffset(60, 7),
	Size = UDim2.fromOffset(200, 22),
})
label(header, "Simple • Fast • Smooth", 11, SUBTEXT, Enum.Font.Gotham, {
	Position = UDim2.fromOffset(60, 29),
	Size = UDim2.fromOffset(200, 16),
})

local btnHolder = new("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0.5, 0),
	Size = UDim2.fromOffset(34 * 3 + 16, 34),
	BackgroundTransparency = 1,
}, header)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Right,
}, btnHolder)

local function headerButton(text, order)
	local b = new("TextButton", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = GLASS2,
		BackgroundTransparency = 0.25,
		AutoButtonColor = false,
		Text = text,
		TextColor3 = WHITE,
		TextSize = 17,
		Font = Enum.Font.GothamBold,
	}, btnHolder)
	corner(b, 17)
	stroke(b, 1, BORDER, 0.55)
	return b
end
local btnMin = headerButton("-", 1)
local btnHide = headerButton("%", 2)
local btnClose = headerButton("X", 3)

new("Frame", {
	Position = UDim2.fromOffset(12, 56),
	Size = UDim2.new(1, -24, 0, 1),
	BackgroundColor3 = BORDER,
	BackgroundTransparency = 0.8,
	BorderSizePixel = 0,
}, body)

-- Sidebar
local sidebar = new("Frame", {
	Position = UDim2.fromOffset(10, 66),
	Size = UDim2.fromOffset(150, 304),
	BackgroundColor3 = GLASS2,
	BackgroundTransparency = 0.5,
}, body)
corner(sidebar, 14)
stroke(sidebar, 1, BORDER, 0.8)
new("UIPadding", {
	PaddingTop = UDim.new(0, 8),
	PaddingLeft = UDim.new(0, 8),
	PaddingRight = UDim.new(0, 8),
}, sidebar)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, sidebar)

-- Vùng nội dung
local content = new("Frame", {
	Position = UDim2.fromOffset(170, 66),
	Size = UDim2.fromOffset(460, 304),
	BackgroundColor3 = GLASS2,
	BackgroundTransparency = 0.6,
	ClipsDescendants = true,
}, body)
corner(content, 14)
stroke(content, 1, BORDER, 0.8)

----------------------------------------------------------------------
-- CÔNG TẮC (dùng cho Farm và Cài đặt)
----------------------------------------------------------------------
local function toggleRow(parent, order, text, initial, onChange)
	local row = new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = GLASS2,
		BackgroundTransparency = 0.35,
	}, parent)
	corner(row, 10)
	stroke(row, 1, BORDER, 0.85)
	label(row, text, 14, WHITE, Enum.Font.Gotham, {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -80, 1, 0),
	})
	local track = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(46, 24),
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = OFF_COLOR,
	}, row)
	corner(track, 12)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, track)
	corner(knob, 9)

	local value = initial
	local function render(animated)
		local d = animated and 0.15 or 0
		tween(track, d, { BackgroundColor3 = value and ON_COLOR or OFF_COLOR })
		tween(knob, d, { Position = UDim2.fromOffset(value and 25 or 3, 3) })
	end
	render(false)

	connect(track.Activated, function()
		value = not value
		render(true)
		onChange(value)
	end)
end

local function makeListPage()
	local p = new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
	}, content)
	new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, p)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 10),
		PaddingLeft = UDim.new(0, 10),
		PaddingRight = UDim.new(0, 10),
		PaddingBottom = UDim.new(0, 10),
	}, p)
	return p
end

local pages = {}

-- Trang chủ
do
	local p = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, content)
	local center = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(360, 80),
		BackgroundTransparency = 1,
	}, p)
	local badge = new("Frame", {
		Size = UDim2.fromOffset(72, 72),
		Position = UDim2.fromOffset(0, 4),
		BackgroundColor3 = GLASS,
		BackgroundTransparency = 0.2,
	}, center)
	corner(badge, 36)
	stroke(badge, 1.2, BORDER, 0.45)
	crown(badge, 46, WHITE, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	label(center, "chan chan", 28, WHITE, Enum.Font.GothamBold, {
		Position = UDim2.fromOffset(92, 10),
		Size = UDim2.fromOffset(260, 32),
	})
	label(center, "Chào mừng bạn đến với menu!", 15, ACCENT, Enum.Font.Gotham, {
		Position = UDim2.fromOffset(92, 44),
		Size = UDim2.fromOffset(268, 22),
	})
	pages.home = p
end

-- Farm
local farmNote
local FeatureState = {}
do
	local p = makeListPage()
	label(p, "Farm", 18, WHITE, Enum.Font.GothamBold, {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 24),
	})
	farmNote = label(p, "Công tắc chỉ lưu trạng thái. Chưa có logic nào được gắn.", 12, SUBTEXT, Enum.Font.Gotham, {
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
	})

	local function applyFeature(f, value)
		FeatureState[f.key] = value
		local h = Handlers[f.key]
		if type(h) == "function" then
			local ok, err = pcall(h, value)
			if ok then
				farmNote.Text = f.label .. (value and ": đã bật (handler đang chạy)." or ": đã tắt.")
			else
				farmNote.Text = f.label .. ": lỗi handler — " .. tostring(err)
			end
		else
			farmNote.Text = f.label
				.. (value and ": đã bật" or ": đã tắt")
				.. " (chỉ lưu trạng thái, chưa có logic được gắn)."
		end
	end

	for i, f in ipairs(FEATURES) do
		FeatureState[f.key] = false -- mặc định: TẮT
		toggleRow(p, 1 + i, f.label, false, function(v)
			applyFeature(f, v)
		end)
	end
	pages.farm = p
end

-- Combat / Quest / Vật phẩm: chưa có chức năng thật
local function placeholderPage(key, title)
	local p = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, content)
	label(p, title, 18, WHITE, Enum.Font.GothamBold, {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.new(1, -20, 0, 24),
	})
	label(p, "Chưa có chức năng nào được triển khai ở trang này.", 13, SUBTEXT, Enum.Font.Gotham, {
		Position = UDim2.fromOffset(10, 40),
		Size = UDim2.new(1, -20, 0, 20),
	})
	pages[key] = p
end
placeholderPage("combat", "Combat")
placeholderPage("quest", "Quest")
placeholderPage("items", "Vật phẩm")

-- Island (khai báo trước để Cài đặt có thể chỉnh vị trí)
local island = new("Frame", {
	Name = "DynamicIsland",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, settings.islandY),
	Size = UDim2.fromOffset(200, 42),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0,
	ZIndex = 100,
}, gui)
local islandScale = new("UIScale", { Scale = 1 }, island)

-- Cài đặt
local applyOptimize
do
	local p = makeListPage()
	label(p, "Cài đặt", 18, WHITE, Enum.Font.GothamBold, {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 24),
	})
	toggleRow(p, 1, "Tối ưu hiệu ứng", settings.optimize, function(v)
		settings.optimize = v
		applyOptimize()
	end)
	toggleRow(p, 2, "Giảm hiệu ứng chuyển động", settings.reduceMotion, function(v)
		settings.reduceMotion = v
	end)

	-- Vị trí Dynamic Island (tránh camera/thanh trạng thái)
	local row = new("Frame", {
		LayoutOrder = 3,
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = GLASS2,
		BackgroundTransparency = 0.35,
	}, p)
	corner(row, 10)
	stroke(row, 1, BORDER, 0.85)
	label(row, "Vị trí Dynamic Island", 14, WHITE, Enum.Font.Gotham, {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -150, 1, 0),
	})
	local valueLabel = label(row, tostring(settings.islandY), 13, SUBTEXT, Enum.Font.Gotham, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -62, 0.5, 0),
		Size = UDim2.fromOffset(32, 20),
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local function stepBtn(text, xOff, delta)
		local b = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, xOff, 0.5, 0),
			Size = UDim2.fromOffset(30, 30),
			BackgroundColor3 = GLASS,
			BackgroundTransparency = 0.2,
			AutoButtonColor = false,
			Text = text,
			TextColor3 = WHITE,
			TextSize = 16,
			Font = Enum.Font.GothamBold,
		}, row)
		corner(b, 15)
		stroke(b, 1, BORDER, 0.6)
		connect(b.Activated, function()
			settings.islandY = math.clamp(settings.islandY + delta, 0, 80)
			valueLabel.Text = tostring(settings.islandY)
			island.Position = UDim2.new(0.5, 0, 0, settings.islandY)
		end)
	end
	stepBtn("+", -10, 4)
	stepBtn("-", -92, -4)

	label(p, "Phiên bản: " .. VERSION, 12, SUBTEXT, Enum.Font.Gotham, {
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 20),
	})
	pages.settings = p
end

----------------------------------------------------------------------
-- SIDEBAR (tạo một lần, tái sử dụng)
----------------------------------------------------------------------
local navButtons = {}
local currentPage

local function setNavVisual(key, selected)
	local b = navButtons[key]
	tween(b, 0.15, { BackgroundTransparency = selected and 0.45 or 1 })
	b.TextColor3 = selected and WHITE or SUBTEXT
end

local function showPage(key)
	if currentPage == key then
		return
	end
	if currentPage then
		pages[currentPage].Visible = false
		setNavVisual(currentPage, false)
	end
	currentPage = key
	local p = pages[key]
	p.Position = UDim2.fromOffset(0, 8)
	p.Visible = true
	tween(p, 0.15, { Position = UDim2.fromOffset(0, 0) })
	setNavVisual(key, true)
end

for i, item in ipairs(NAV) do
	local b = new("TextButton", {
		LayoutOrder = i,
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = Color3.fromRGB(110, 160, 220),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = item.label,
		TextColor3 = SUBTEXT,
		TextSize = 14,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, sidebar)
	corner(b, 10)
	new("UIPadding", { PaddingLeft = UDim.new(0, 14) }, b)
	navButtons[item.key] = b
	connect(b.Activated, function()
		showPage(item.key)
	end)
end

----------------------------------------------------------------------
-- DYNAMIC ISLAND (nội dung)
----------------------------------------------------------------------
corner(island, 21)
stroke(island, 1.2, BORDER, 0.45)
crown(island, 22, WHITE, UDim2.fromOffset(12, 10), Vector2.zero).ZIndex = 101
label(island, "chan chan", 13, WHITE, Enum.Font.GothamBold, {
	Position = UDim2.fromOffset(42, 4),
	Size = UDim2.fromOffset(110, 17),
	ZIndex = 101,
})
label(island, "Đang hoạt động", 10, SUBTEXT, Enum.Font.Gotham, {
	Position = UDim2.fromOffset(42, 21),
	Size = UDim2.fromOffset(110, 15),
	ZIndex = 101,
})
do
	local dot = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = Color3.fromRGB(60, 220, 120),
		BorderSizePixel = 0,
		ZIndex = 101,
	}, island)
	corner(dot, 5)
end
local islandBtn = new("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	ZIndex = 110,
}, island)

----------------------------------------------------------------------
-- LOGO TRÒN (thu nhỏ bằng "-")
----------------------------------------------------------------------
local miniLogo = new("Frame", {
	Name = "MiniLogo",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.4, 0),
	Size = UDim2.fromOffset(52, 52),
	BackgroundColor3 = GLASS,
	BackgroundTransparency = 0.15,
	Visible = false,
	ZIndex = 50,
}, gui)
corner(miniLogo, 26)
stroke(miniLogo, 1.2, BORDER, 0.45)
local miniScale = new("UIScale", { Scale = 1 }, miniLogo)
crown(miniLogo, 32, WHITE, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5)).ZIndex = 51
local miniBtn = new("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	ZIndex = 60,
}, miniLogo)

----------------------------------------------------------------------
-- HỘP THOẠI XÁC NHẬN ĐÓNG (tạo một lần, tái sử dụng)
----------------------------------------------------------------------
local blocker = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.5,
	BorderSizePixel = 0,
	Active = true,
	Visible = false,
	ZIndex = 50,
}, body)
local dialog = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(280, 130),
	BackgroundColor3 = GLASS,
	BackgroundTransparency = 0.08,
}, blocker)
corner(dialog, 18)
stroke(dialog, 1.2, BORDER, 0.45)
local dialogScale = new("UIScale", { Scale = 1 }, dialog)
label(dialog, "Bạn muốn đóng script không?", 15, WHITE, Enum.Font.GothamMedium, {
	Position = UDim2.fromOffset(10, 22),
	Size = UDim2.new(1, -20, 0, 24),
	TextXAlignment = Enum.TextXAlignment.Center,
})
local function dialogButton(text, xScale, color)
	local b = new("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(xScale, 0, 1, -16),
		Size = UDim2.fromOffset(110, 40),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.25,
		AutoButtonColor = false,
		Text = text,
		TextColor3 = WHITE,
		TextSize = 14,
		Font = Enum.Font.GothamBold,
	}, dialog)
	corner(b, 12)
	stroke(b, 1, BORDER, 0.6)
	return b
end
local btnYes = dialogButton("Có", 0.27, Color3.fromRGB(150, 60, 60))
local btnNo = dialogButton("Không", 0.73, GLASS2)

local function openDialog()
	if blocker.Visible then
		return
	end
	dialogScale.Scale = 0.9
	blocker.Visible = true
	tween(dialogScale, 0.15, { Scale = 1 })
end

local function closeDialog()
	blocker.Visible = false
end

----------------------------------------------------------------------
-- TRẠNG THÁI CỬA SỔ: "open" | "minimized" | "hidden"
----------------------------------------------------------------------
local state = "open"
local transitionId = 0

local function windowShow()
	transitionId = transitionId + 1
	holder.Visible = true
	animScale.Scale = 0.88
	tween(animScale, 0.2, { Scale = 1 })
end

local function windowHide()
	transitionId = transitionId + 1
	local id = transitionId
	tween(animScale, 0.15, { Scale = 0.88 })
	after(0.15, function()
		if transitionId == id then
			holder.Visible = false -- ẩn hẳn, không chặn cảm ứng
		end
	end)
end

local function openWindow()
	if state == "open" then
		return
	end
	state = "open"
	miniLogo.Visible = false
	windowShow()
end

local function minimizeWindow()
	if state ~= "open" then
		return
	end
	closeDialog()
	state = "minimized"
	windowHide()
	miniScale.Scale = 0.6
	miniLogo.Visible = true
	tween(miniScale, 0.2, { Scale = 1 })
end

local function hideToIsland()
	if state ~= "open" then
		return
	end
	closeDialog()
	state = "hidden"
	miniLogo.Visible = false
	windowHide()
end

----------------------------------------------------------------------
-- DỌN DẸP TOÀN BỘ
----------------------------------------------------------------------
local function cleanup()
	if not alive then
		return
	end
	alive = false

	-- Dừng tác vụ do người dùng gắn qua Handlers
	for _, f in ipairs(FEATURES) do
		if FeatureState[f.key] then
			local h = Handlers[f.key]
			if type(h) == "function" then
				pcall(h, false)
			end
			FeatureState[f.key] = false
		end
	end

	for _, t in pairs(activeTweens) do
		pcall(function()
			t:Cancel()
		end)
	end
	table.clear(activeTweens)

	for _, th in ipairs(taskThreads) do
		pcall(task.cancel, th)
	end
	table.clear(taskThreads)

	for _, c in ipairs(conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	table.clear(conns)

	pcall(function()
		gui:Destroy()
	end)

	if env[CLEANUP_KEY] == cleanup then
		env[CLEANUP_KEY] = nil
	end
end
env[CLEANUP_KEY] = cleanup

----------------------------------------------------------------------
-- TỐI ƯU HIỆU ỨNG
----------------------------------------------------------------------
applyOptimize = function()
	local on = settings.optimize
	for _, g in ipairs(gradients) do
		g.Enabled = not on
	end
	shine.Visible = not on
end

----------------------------------------------------------------------
-- BỐ CỤC THÍCH ỨNG MÀN HÌNH
----------------------------------------------------------------------
local cx, cy = 400, 240
local userMoved = false

local function viewport()
	local cam = Workspace.CurrentCamera
	if cam then
		return cam.ViewportSize
	end
	return Vector2.new(800, 450)
end

local function clampPos(vp, s)
	local halfW, halfH = BASE_W * s / 2, BASE_H * s / 2
	cx = math.clamp(cx, math.min(halfW, vp.X / 2), math.max(vp.X - halfW, vp.X / 2))
	cy = math.clamp(cy, math.min(halfH, vp.Y / 2), math.max(vp.Y - halfH, vp.Y / 2))
end

local function updateLayout()
	local vp = viewport()
	local availH = math.max(vp.Y - 64, 200)
	local s = math.clamp(math.min(vp.X * 0.94 / BASE_W, availH * 0.97 / BASE_H), 0.45, 1.15)
	adaptScale.Scale = s
	islandScale.Scale = vp.X < 700 and 0.9 or 1
	if not userMoved then
		cx = vp.X / 2
		cy = 56 + availH / 2
	end
	clampPos(vp, s)
	holder.Position = UDim2.fromOffset(cx, cy)
end

local camConn
local function bindCamera()
	if camConn then
		camConn:Disconnect()
		camConn = nil
	end
	local cam = Workspace.CurrentCamera
	if cam then
		camConn = connect(cam:GetPropertyChangedSignal("ViewportSize"), updateLayout)
	end
	updateLayout()
end
connect(Workspace:GetPropertyChangedSignal("CurrentCamera"), bindCamera)

----------------------------------------------------------------------
-- KÉO CỬA SỔ BẰNG THANH TIÊU ĐỀ (chuột + cảm ứng)
----------------------------------------------------------------------
local dragging = false
local dragStart, startC
local function isPointer(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

connect(header.InputBegan, function(input)
	if isPointer(input) and not blocker.Visible then
		dragging = true
		dragStart = input.Position
		startC = Vector2.new(cx, cy)
	end
end)
connect(UserInputService.InputChanged, function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		local d = input.Position - dragStart
		cx, cy = startC.X + d.X, startC.Y + d.Y
		userMoved = true
		clampPos(viewport(), adaptScale.Scale)
		holder.Position = UDim2.fromOffset(cx, cy)
	end
end)
connect(UserInputService.InputEnded, function(input)
	if isPointer(input) then
		dragging = false
	end
end)

----------------------------------------------------------------------
-- SỰ KIỆN NÚT
----------------------------------------------------------------------
connect(btnMin.Activated, minimizeWindow)
connect(btnHide.Activated, hideToIsland)
connect(btnClose.Activated, openDialog)
connect(btnNo.Activated, closeDialog)
connect(btnYes.Activated, cleanup)
connect(miniBtn.Activated, openWindow)
connect(islandBtn.Activated, openWindow) -- không làm gì nếu cửa sổ đang mở

-- Phím tắt bổ sung: Shift + 5 ("%") để ẩn/hiện. Cảm ứng đã có đủ chức năng thay thế.
connect(UserInputService.InputBegan, function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end
	if input.KeyCode == Enum.KeyCode.Five
		and (UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift))
	then
		if state == "open" then
			hideToIsland()
		else
			openWindow()
		end
	end
end)

----------------------------------------------------------------------
-- KHỞI ĐỘNG
----------------------------------------------------------------------
applyOptimize()
bindCamera()
showPage("home")
windowShow()
