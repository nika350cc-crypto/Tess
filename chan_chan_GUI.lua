--[[
    chan chan GUI — Liquid Glass (Roblox Luau) — v1.0.0
    Một file duy nhất, không tải mã ngoài, không thư viện ngoài.

    GIỚI HẠN (nói rõ, không giả vờ):
    * Roblox KHÔNG có cách làm mờ (blur) cục bộ thật chỉ trong một vùng GUI mà
      không dùng hiệu ứng toàn màn hình (Lighting.BlurEffect). Vì vậy "kính nhám"
      phía sau cửa sổ ở đây là lớp MÔ PHỎNG: một tấm phủ tối bán trong suốt, bo góc,
      có gradient nhẹ. Nó KHÔNG làm mờ hình ảnh game. Script không đụng tới Lighting.
    * Các công tắc Farm chỉ LƯU TRẠNG THÁI. Script không chứa logic tự động cho game nào.
      Muốn gắn chức năng thật (nếu hợp lệ), gán hàm vào bảng Handlers bên dưới.
      Khi đóng script, handler đang bật được gọi với false để bạn dừng tác vụ.
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
local BASE_W, BASE_H = 700, 420

-- Gắn chức năng thật tại đây. Ví dụ: Handlers.AutoFarm = function(enabled) ... end
local Handlers = {}

local FEATURES = {
	{ key = "AutoFarm", label = "Auto Farm" },
	{ key = "AutoQuest", label = "Auto Quest" },
	{ key = "AutoAttack", label = "Auto Attack" },
	{ key = "AutoCollect", label = "Auto Collect" },
	{ key = "FastMode", label = "Fast Mode" },
}

local NAV = {
	{ key = "home", label = "Trang chủ", icon = "home" },
	{ key = "farm", label = "Farm", icon = "farm" },
	{ key = "combat", label = "Combat", icon = "combat" },
	{ key = "quest", label = "Quest", icon = "quest" },
	{ key = "items", label = "Vật phẩm", icon = "items" },
	{ key = "settings", label = "Cài đặt", icon = "settings" },
}

local WHITE = Color3.fromRGB(255, 255, 255)
local SUBTEXT = Color3.fromRGB(170, 178, 192)
local BORDER = Color3.fromRGB(190, 225, 255)
local GLASS = Color3.fromRGB(12, 16, 24)
local GLASS2 = Color3.fromRGB(22, 30, 44)
local ON_COLOR = Color3.fromRGB(70, 195, 140)
local OFF_COLOR = Color3.fromRGB(78, 84, 96)
local ACCENT = Color3.fromRGB(150, 210, 255)

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
	sweep = true,
	islandY = 10,
}

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

-- khai báo trước (định nghĩa ở dưới)
local applyOptimize
local updateSweep
local state = "open" -- "open" | "minimized" | "hidden"

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

local gradients = {}

-- Vương miện đơn giản vẽ bằng Frame
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
	box(0.16, 0.46, 0.68, 0.3, 0.12)
	box(0.16, 0.8, 0.68, 0.1, 0.5)
	box(0.16, 0.3, 0.12, 0.3, 0.3)
	box(0.44, 0.2, 0.12, 0.4, 0.3)
	box(0.72, 0.3, 0.12, 0.3, 0.3)
	box(0.12, 0.2, 0.2, 0.2, 0.5)
	box(0.4, 0.08, 0.2, 0.2, 0.5)
	box(0.68, 0.2, 0.2, 0.2, 0.5)
	return f
end

-- Biểu tượng trắng vẽ bằng hình cơ bản (không phụ thuộc font/ảnh)
local function icon(kind, parent, pos)
	local f = new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(24, 24),
		Position = pos,
	}, parent)
	local function bar(cx, cy, w, h, rot, r)
		local b = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(cx, cy),
			Size = UDim2.fromScale(w, h),
			Rotation = rot or 0,
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
		}, f)
		if r then
			new("UICorner", { CornerRadius = UDim.new(r, 0) }, b)
		end
		return b
	end
	local function ring(cx, cy, d, th)
		local r = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(cx, cy),
			Size = UDim2.fromScale(d, d),
			BackgroundTransparency = 1,
		}, f)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, r)
		new("UIStroke", { Thickness = th, Color = WHITE }, r)
		return r
	end
	if kind == "home" then
		bar(0.5, 0.32, 0.46, 0.46, 45)
		bar(0.5, 0.66, 0.6, 0.4, 0, 0.1)
	elseif kind == "farm" then
		bar(0.55, 0.16, 0.5, 0.14, 0, 0.5)
		bar(0.5, 0.5, 0.14, 0.72, 30, 0.5)
		bar(0.45, 0.84, 0.5, 0.14, 0, 0.5)
	elseif kind == "combat" then
		bar(0.5, 0.5, 0.12, 0.92, 45, 0.5)
		bar(0.5, 0.5, 0.12, 0.92, -45, 0.5)
	elseif kind == "quest" then
		ring(0.5, 0.5, 0.86, 2)
		bar(0.5, 0.5, 0.16, 0.5, 45, 0.3)
	elseif kind == "items" then
		bar(0.5, 0.64, 0.64, 0.58, 0, 0.18)
		ring(0.5, 0.3, 0.4, 2)
	elseif kind == "settings" then
		ring(0.5, 0.5, 0.56, 3)
		for _, rot in ipairs({ 0, 45, 90, 135 }) do
			bar(0.5, 0.5, 0.14, 0.95, rot, 0.2)
		end
	end
	return f
end

local function platformName()
	local name
	pcall(function()
		name = identifyexecutor()
	end)
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if type(name) == "string" and name ~= "" then
		if string.find(string.lower(name), "delta", 1, true) and touch then
			return "Delta (Android)"
		end
		return name
	end
	return touch and "Di động" or "PC"
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

-- scaler: nhóm có animation thu/phóng (frost + body + vệt sáng)
local scaler = new("Frame", {
	Name = "Scaler",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
}, holder)
local animScale = new("UIScale", { Scale = 1 }, scaler)

-- Kính nhám MÔ PHỎNG phía sau cửa sổ (không phải blur thật), bo góc, hòa vào viền
local frost = new("Frame", {
	Name = "FrostBacking",
	Position = UDim2.fromOffset(-8, -8),
	Size = UDim2.new(1, 16, 1, 16),
	BackgroundColor3 = Color3.fromRGB(10, 14, 22),
	BackgroundTransparency = 0.55,
	BorderSizePixel = 0,
}, scaler)
corner(frost, 30)
gradients[#gradients + 1] = new("UIGradient", {
	Rotation = 90,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0.7),
	}),
}, frost)

local body = new("Frame", {
	Name = "Body",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = GLASS,
	BackgroundTransparency = 0.3,
	BorderSizePixel = 0,
	ClipsDescendants = true,
}, scaler)
corner(body, 24)
stroke(body, 1.2, BORDER, 0.5)
gradients[#gradients + 1] = new("UIGradient", {
	Rotation = 90,
	Color = ColorSequence.new(Color3.fromRGB(34, 44, 64), Color3.fromRGB(8, 10, 16)),
}, body)

-- Vệt sáng chạy dọc viền (MỘT tween duy nhất, lặp)
local sweepFrame = new("Frame", {
	Name = "Sweep",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 5,
}, scaler)
corner(sweepFrame, 24)
local sweepStroke = new("UIStroke", {
	Thickness = 1.8,
	Color = Color3.fromRGB(205, 238, 255),
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
}, sweepFrame)
local sweepGrad = new("UIGradient", {
	Rotation = 20,
	Offset = Vector2.new(-1, 0),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.38, 1),
		NumberSequenceKeypoint.new(0.5, 0.3),
		NumberSequenceKeypoint.new(0.62, 1),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, sweepStroke)

-- Tiêu đề
local header = new("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 60),
	BackgroundTransparency = 1,
}, body)

-- phản chiếu tĩnh chéo nhẹ qua tiêu đề
local shine = new("Frame", {
	Position = UDim2.new(0.42, 0, 0, 0),
	Size = UDim2.new(0, 110, 1, 0),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.95,
	BorderSizePixel = 0,
}, header)

local logoBadge = new("Frame", {
	Position = UDim2.fromOffset(14, 8),
	Size = UDim2.fromOffset(44, 44),
	BackgroundColor3 = GLASS2,
	BackgroundTransparency = 0.2,
}, header)
corner(logoBadge, 22)
stroke(logoBadge, 1, BORDER, 0.45)
crown(logoBadge, 30, WHITE, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))

label(header, "chan chan", 21, WHITE, Enum.Font.GothamBold, {
	Position = UDim2.fromOffset(70, 8),
	Size = UDim2.fromOffset(220, 26),
})
label(header, "Simple • Fast • Smooth", 12, SUBTEXT, Enum.Font.Gotham, {
	Position = UDim2.fromOffset(70, 34),
	Size = UDim2.fromOffset(220, 16),
})

local btnHolder = new("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0.5, 0),
	Size = UDim2.fromOffset(36 * 3 + 16, 36),
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
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = GLASS2,
		BackgroundTransparency = 0.25,
		AutoButtonColor = false,
		Text = text,
		TextColor3 = WHITE,
		TextSize = 17,
		Font = Enum.Font.GothamBold,
	}, btnHolder)
	corner(b, 18)
	stroke(b, 1, BORDER, 0.5)
	return b
end
local btnHide = headerButton("%", 1)
local btnMin = headerButton("-", 2)
local btnClose = headerButton("X", 3)

new("Frame", {
	Position = UDim2.fromOffset(12, 60),
	Size = UDim2.new(1, -24, 0, 1),
	BackgroundColor3 = BORDER,
	BackgroundTransparency = 0.82,
	BorderSizePixel = 0,
}, body)

-- Sidebar
local sidebar = new("Frame", {
	Position = UDim2.fromOffset(10, 70),
	Size = UDim2.fromOffset(166, 340),
	BackgroundColor3 = GLASS2,
	BackgroundTransparency = 0.55,
}, body)
corner(sidebar, 16)
stroke(sidebar, 1, BORDER, 0.82)

local navList = new("Frame", {
	Position = UDim2.fromOffset(8, 8),
	Size = UDim2.new(1, -16, 0, 276),
	BackgroundTransparency = 1,
}, sidebar)
new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, navList)

-- thẻ nhỏ cuối sidebar
do
	local card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -16, 0, 44),
		BackgroundColor3 = GLASS,
		BackgroundTransparency = 0.35,
	}, sidebar)
	corner(card, 22)
	stroke(card, 1, BORDER, 0.7)
	crown(card, 24, WHITE, UDim2.new(0, 10, 0.5, 0), Vector2.new(0, 0.5))
	label(card, "chan chan", 12, WHITE, Enum.Font.GothamMedium, {
		Position = UDim2.fromOffset(42, 6),
		Size = UDim2.fromOffset(80, 16),
	})
	label(card, VERSION, 10, SUBTEXT, Enum.Font.Gotham, {
		Position = UDim2.fromOffset(42, 22),
		Size = UDim2.fromOffset(80, 14),
	})
	local dot = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(9, 9),
		BackgroundColor3 = Color3.fromRGB(60, 220, 120),
		BorderSizePixel = 0,
	}, card)
	corner(dot, 5)
end

-- Vùng nội dung
local content = new("Frame", {
	Position = UDim2.fromOffset(186, 70),
	Size = UDim2.fromOffset(504, 340),
	BackgroundColor3 = GLASS2,
	BackgroundTransparency = 0.65,
	ClipsDescendants = true,
}, body)
corner(content, 16)
stroke(content, 1, BORDER, 0.82)

----------------------------------------------------------------------
-- THÀNH PHẦN DÙNG CHUNG
----------------------------------------------------------------------
local function card(parent, order, height)
	local c = new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = GLASS2,
		BackgroundTransparency = 0.5,
	}, parent)
	corner(c, 14)
	stroke(c, 1, BORDER, 0.82)
	return c
end

local function toggleRow(parent, order, title, sub, initial, onChange, flat)
	local h = sub and 44 or 42
	local row = new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, h),
		BackgroundColor3 = GLASS2,
		BackgroundTransparency = flat and 1 or 0.4,
	}, parent)
	if not flat then
		corner(row, 12)
		stroke(row, 1, BORDER, 0.85)
	end
	label(row, title, 14, WHITE, Enum.Font.Gotham, {
		Position = UDim2.fromOffset(14, sub and 5 or 0),
		Size = UDim2.new(1, -90, 0, sub and 18 or h),
	})
	if sub then
		label(row, sub, 11, SUBTEXT, Enum.Font.Gotham, {
			Position = UDim2.fromOffset(14, 24),
			Size = UDim2.new(1, -90, 0, 14),
		})
	end
	local track = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(48, 26),
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = OFF_COLOR,
	}, row)
	corner(track, 13)
	local knob = new("Frame", {
		Size = UDim2.fromOffset(20, 20),
		Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, track)
	corner(knob, 10)

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
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, p)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 12),
		PaddingLeft = UDim.new(0, 12),
		PaddingRight = UDim.new(0, 12),
		PaddingBottom = UDim.new(0, 12),
	}, p)
	return p
end

local function sectionTitle(parent, order, text)
	return label(parent, text, 14, WHITE, Enum.Font.GothamBold, {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 20),
	})
end

local pages = {}
local perfValue

----------------------------------------------------------------------
-- TRANG CHỦ
----------------------------------------------------------------------
do
	local p = makeListPage()
	label(p, "Trang chủ", 20, WHITE, Enum.Font.GothamBold, {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 26),
	})

	local welcome = card(p, 1, 74)
	local badge = new("Frame", {
		Position = UDim2.fromOffset(14, 11),
		Size = UDim2.fromOffset(52, 52),
		BackgroundColor3 = GLASS,
		BackgroundTransparency = 0.2,
	}, welcome)
	corner(badge, 26)
	stroke(badge, 1.2, BORDER, 0.45)
	crown(badge, 34, WHITE, UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
	label(welcome, "chan chan", 24, WHITE, Enum.Font.GothamBold, {
		Position = UDim2.fromOffset(80, 10),
		Size = UDim2.new(1, -90, 0, 30),
	})
	label(welcome, "Chào mừng bạn đến với menu!", 14, ACCENT, Enum.Font.Gotham, {
		Position = UDim2.fromOffset(80, 42),
		Size = UDim2.new(1, -90, 0, 20),
	})

	sectionTitle(p, 2, "Thông tin")
	local info = card(p, 3, 58)
	local cells = {
		{ "Phiên bản", VERSION },
		{ "Nền tảng", platformName() },
		{ "Hiệu suất", settings.optimize and "Tối ưu" or "Đầy đủ" },
	}
	for i, c in ipairs(cells) do
		label(info, c[1], 11, SUBTEXT, Enum.Font.Gotham, {
			Position = UDim2.new((i - 1) / 3, 14, 0, 10),
			Size = UDim2.new(1 / 3, -20, 0, 14),
		})
		local v = label(info, c[2], 13, WHITE, Enum.Font.GothamMedium, {
			Position = UDim2.new((i - 1) / 3, 14, 0, 28),
			Size = UDim2.new(1 / 3, -20, 0, 18),
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		if i == 3 then
			perfValue = v
		end
		if i > 1 then
			new("Frame", {
				Position = UDim2.new((i - 1) / 3, 0, 0.2, 0),
				Size = UDim2.new(0, 1, 0.6, 0),
				BackgroundColor3 = BORDER,
				BackgroundTransparency = 0.85,
				BorderSizePixel = 0,
			}, info)
		end
	end

	sectionTitle(p, 4, "Tùy chọn")
	local opts = card(p, 5, 92)
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, opts)
	new("UIPadding", { PaddingTop = UDim.new(0, 1) }, opts)
	toggleRow(opts, 1, "Tối ưu hiệu ứng", "Giảm hiệu ứng để mượt hơn", settings.optimize, function(v)
		settings.optimize = v
		applyOptimize()
	end, true)
	toggleRow(opts, 2, "Giảm chuyển động", "Giúp tiết kiệm FPS", settings.reduceMotion, function(v)
		settings.reduceMotion = v
		updateSweep()
	end, true)
	pages.home = p
end

----------------------------------------------------------------------
-- FARM
----------------------------------------------------------------------
local farmNote
local FeatureState = {}
do
	local p = makeListPage()
	label(p, "Farm", 20, WHITE, Enum.Font.GothamBold, {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 26),
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
		FeatureState[f.key] = false
		toggleRow(p, 1 + i, f.label, nil, false, function(v)
			applyFeature(f, v)
		end)
	end
	pages.farm = p
end

local function placeholderPage(key, title)
	local p = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, content)
	label(p, title, 20, WHITE, Enum.Font.GothamBold, {
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.new(1, -24, 0, 26),
	})
	label(p, "Chưa có chức năng nào được triển khai ở trang này.", 13, SUBTEXT, Enum.Font.Gotham, {
		Position = UDim2.fromOffset(12, 44),
		Size = UDim2.new(1, -24, 0, 20),
	})
	pages[key] = p
end
placeholderPage("combat", "Combat")
placeholderPage("quest", "Quest")
placeholderPage("items", "Vật phẩm")

----------------------------------------------------------------------
-- DYNAMIC ISLAND (mini)
----------------------------------------------------------------------
local island = new("Frame", {
	Name = "DynamicIsland",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, settings.islandY),
	Size = UDim2.fromOffset(170, 40),
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.12,
	ZIndex = 100,
}, gui)
local islandScale = new("UIScale", { Scale = 1 }, island)
corner(island, 20)
stroke(island, 1.2, BORDER, 0.45)
crown(island, 22, WHITE, UDim2.fromOffset(11, 9), Vector2.zero).ZIndex = 101
label(island, "chan chan", 13, WHITE, Enum.Font.GothamBold, {
	Position = UDim2.fromOffset(40, 4),
	Size = UDim2.fromOffset(95, 17),
	ZIndex = 101,
})
label(island, "Đang hoạt động", 10, SUBTEXT, Enum.Font.Gotham, {
	Position = UDim2.fromOffset(40, 21),
	Size = UDim2.fromOffset(95, 14),
	ZIndex = 101,
})
do
	local dot = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(9, 9),
		BackgroundColor3 = Color3.fromRGB(60, 220, 120),
		BorderSizePixel = 0,
		ZIndex = 101,
	}, island)
	corner(dot, 5)
end
-- vùng chạm hơi lớn hơn đảo để dễ bấm trên điện thoại
local islandBtn = new("TextButton", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, 16, 1, 12),
	BackgroundTransparency = 1,
	Text = "",
	ZIndex = 110,
}, island)

----------------------------------------------------------------------
-- CÀI ĐẶT
----------------------------------------------------------------------
do
	local p = makeListPage()
	label(p, "Cài đặt", 20, WHITE, Enum.Font.GothamBold, {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 26),
	})
	toggleRow(p, 1, "Hiệu ứng ánh sáng", "Vệt sáng chạy qua viền menu", settings.sweep, function(v)
		settings.sweep = v
		updateSweep()
	end)

	local row = new("Frame", {
		LayoutOrder = 2,
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = GLASS2,
		BackgroundTransparency = 0.4,
	}, p)
	corner(row, 12)
	stroke(row, 1, BORDER, 0.85)
	label(row, "Vị trí Dynamic Island", 14, WHITE, Enum.Font.Gotham, {
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -170, 1, 0),
	})
	local valueLabel = label(row, tostring(settings.islandY), 13, SUBTEXT, Enum.Font.Gotham, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -66, 0.5, 0),
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
	stepBtn("+", -14, 4)
	stepBtn("-", -100, -4)

	label(p, "Phiên bản: " .. VERSION, 12, SUBTEXT, Enum.Font.Gotham, {
		LayoutOrder = 3,
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
	tween(navButtons[key], 0.15, { BackgroundTransparency = selected and 0.4 or 1 })
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
		Size = UDim2.new(1, 0, 0, 42),
		BackgroundColor3 = Color3.fromRGB(120, 175, 235),
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = item.label,
		TextColor3 = WHITE,
		TextSize = 14,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, navList)
	corner(b, 12)
	new("UIPadding", { PaddingLeft = UDim.new(0, 46) }, b)
	icon(item.icon, b, UDim2.fromOffset(-36, 9))
	navButtons[item.key] = b
	connect(b.Activated, function()
		showPage(item.key)
	end)
end

----------------------------------------------------------------------
-- LOGO TRÒN (thu nhỏ bằng "-")
----------------------------------------------------------------------
local miniLogo = new("Frame", {
	Name = "MiniLogo",
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 10, 0.3, 0),
	Size = UDim2.fromOffset(52, 52),
	BackgroundColor3 = GLASS,
	BackgroundTransparency = 0.2,
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
-- VỆT SÁNG: một tween lặp duy nhất, chỉ chạy khi cần
----------------------------------------------------------------------
local sweepTween
updateSweep = function()
	local run = alive and settings.sweep and not settings.optimize and not settings.reduceMotion and state == "open"
	if run then
		sweepFrame.Visible = true
		if not sweepTween then
			sweepGrad.Offset = Vector2.new(-1, 0)
			sweepTween = TweenService:Create(
				sweepGrad,
				TweenInfo.new(3.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false, 1.2),
				{ Offset = Vector2.new(1, 0) }
			)
			sweepTween:Play()
		end
	else
		if sweepTween then
			sweepTween:Cancel()
			sweepTween = nil
		end
		sweepFrame.Visible = false
	end
end

----------------------------------------------------------------------
-- TRẠNG THÁI CỬA SỔ
----------------------------------------------------------------------
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
	updateSweep()
end

local function minimizeWindow()
	if state ~= "open" then
		return
	end
	closeDialog()
	state = "minimized"
	updateSweep()
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
	updateSweep()
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

	for _, f in ipairs(FEATURES) do
		if FeatureState[f.key] then
			local h = Handlers[f.key]
			if type(h) == "function" then
				pcall(h, false)
			end
			FeatureState[f.key] = false
		end
	end

	if sweepTween then
		pcall(function()
			sweepTween:Cancel()
		end)
		sweepTween = nil
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
	if perfValue then
		perfValue.Text = on and "Tối ưu" or "Đầy đủ"
	end
	updateSweep()
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
	local s = math.clamp(math.min(vp.X * 0.94 / BASE_W, availH * 0.97 / BASE_H), 0.4, 1.15)
	adaptScale.Scale = s
	islandScale.Scale = vp.X < 900 and 0.9 or 1
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
-- KÉO CỬA SỔ BẰNG THANH TIÊU ĐỀ
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
connect(btnHide.Activated, hideToIsland)
connect(btnMin.Activated, minimizeWindow)
connect(btnClose.Activated, openDialog)
connect(btnNo.Activated, closeDialog)
connect(btnYes.Activated, cleanup)
connect(miniBtn.Activated, openWindow)
connect(islandBtn.Activated, openWindow) -- không làm gì nếu cửa sổ đang mở

-- Phím tắt bổ sung (không bắt buộc): Shift + 5 = "%"
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
updateSweep()
