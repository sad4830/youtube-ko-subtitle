--!strict
-- 화면 UI: 캐릭터 선택, 체력/각성/회피/가드 게이지, 기술 단축바(쿨타임), 회분 게이지,
-- 콤보, 킬 피드, 알림, 각성 타이틀, 사망 화면, 조작법, 모바일 버튼

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local CharacterDefs = require(Shared.CharacterDefs)
local RigBuilder = require(Shared.RigBuilder)
local Sounds = require(Shared.Sounds)

local Animator = require(script.Parent.Animator)
local CameraFX = require(script.Parent.CameraFX)

local UI = {}
UI.onSelect = nil :: ((charId: string) -> ())?
UI.onAction = nil :: ((action: string, payload: any) -> ())?

local player = Players.LocalPlayer

local FONT = Enum.Font.GothamBold
local FONT_HEAVY = Enum.Font.GothamBlack
local FONT_BODY = Enum.Font.Gotham
local WHITE = Color3.new(1, 1, 1)
local PANEL = Color3.fromRGB(16, 14, 18)
local MUTED = Color3.fromRGB(170, 164, 160)

local gui: ScreenGui
local selectFrame: Frame
local hud: Frame
local currentChar: string? = nil
local cooldownEnds: { [string]: number } = {}
local cooldownDur: { [string]: number } = {}

----------------------------------------------------------------------
-- 헬퍼
----------------------------------------------------------------------
local function corner(parent: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

local function frame(parent: Instance, name: string, size: UDim2, pos: UDim2, color: Color3?, transparency: number?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = color or PANEL
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function label(parent: Instance, name: string, text: string, size: UDim2, pos: UDim2, textSize: number, color: Color3?, font: Enum.Font?): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Text = text
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.TextColor3 = color or WHITE
	l.Font = font or FONT
	l.TextSize = textSize
	l.TextWrapped = true
	l.Parent = parent
	return l
end

local function button(parent: Instance, name: string, text: string, size: UDim2, pos: UDim2, color: Color3, textSize: number?): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.TextColor3 = WHITE
	b.Font = FONT
	b.TextSize = textSize or 15
	b.Parent = parent
	corner(b, 8)
	b.MouseEnter:Connect(function()
		Sounds.play("ui_hover", { volume = 0.5 })
	end)
	return b
end

local function action(name: string, payload: any)
	local cb = UI.onAction
	if cb then
		cb(name, payload)
	end
end

local function localChar(): Model?
	return player.Character
end

local function attr(model: Model?, name: string, default: any): any
	if not model then
		return default
	end
	local v = model:GetAttribute(name)
	if v == nil then
		return default
	end
	return v
end

----------------------------------------------------------------------
-- 캐릭터 선택 화면
----------------------------------------------------------------------
type Preview = { model: Model, vp: ViewportFrame, angle: number }
local previews: { Preview } = {}

local function statBar(parent: Instance, y: number, name: string, value: number, color: Color3)
	label(parent, "Stat" .. name, name, UDim2.new(0, 60, 0, 16), UDim2.new(0, 0, 0, y), 13, MUTED, FONT).TextXAlignment = Enum.TextXAlignment.Left
	local back = frame(parent, "Bar" .. name, UDim2.new(1, -70, 0, 8), UDim2.new(0, 66, 0, y + 4), Color3.fromRGB(40, 38, 44))
	corner(back, 4)
	local fill = frame(back, "Fill", UDim2.new(value / 5, 0, 1, 0), UDim2.new(0, 0, 0, 0), color)
	corner(fill, 4)
end

local function buildCard(parent: Instance, def: CharacterDefs.CharDef, xScale: number)
	local card = frame(parent, "Card_" .. def.id, UDim2.new(0.3, 0, 0.78, 0), UDim2.new(xScale, 0, 0.56, 0), PANEL, 0.12)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	corner(card, 14)
	local st = stroke(card, def.color, 2, 0.4)
	local scale = Instance.new("UIScale")
	scale.Parent = card
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(480, 860)
	sizeLimit.Parent = card

	local accent = frame(card, "Accent", UDim2.new(1, 0, 0, 6), UDim2.new(0, 0, 0, 0), def.color)
	corner(accent, 3)

	-- 3D 미리보기
	local vp = Instance.new("ViewportFrame")
	vp.Name = "Preview"
	vp.Size = UDim2.new(1, -24, 0.4, 0)
	vp.Position = UDim2.new(0, 12, 0, 14)
	vp.BackgroundColor3 = Color3.fromRGB(10, 9, 12)
	vp.BackgroundTransparency = 0.2
	vp.Ambient = Color3.fromRGB(150, 140, 130)
	vp.LightColor = Color3.fromRGB(255, 236, 210)
	vp.LightDirection = Vector3.new(-0.6, -1, -0.5)
	vp.Parent = card
	corner(vp, 10)
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(def.dark, Color3.fromRGB(10, 9, 12))
	grad.Rotation = 90
	grad.Parent = vp
	local world = Instance.new("WorldModel")
	world.Parent = vp
	local model = RigBuilder.build(def.id)
	local plate = model:FindFirstChild("Nameplate", true)
	if plate then
		plate:Destroy()
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	model:PivotTo(CFrame.new(0, 3, 0))
	model.Parent = world
	local cam = Instance.new("Camera")
	cam.FieldOfView = 32
	cam.CFrame = CFrame.lookAt(Vector3.new(0, 3.4, -13.5), Vector3.new(0, 2.7, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
	table.insert(previews, { model = model, vp = vp, angle = 0 })

	local y0 = 0.43
	local info = frame(card, "Info", UDim2.new(1, -28, 0.57, -70), UDim2.new(0, 14, y0, 6), PANEL, 1)
	local nameL = label(info, "Name", def.name, UDim2.new(1, 0, 0, 34), UDim2.new(0, 0, 0, 0), 30, WHITE, FONT_HEAVY)
	nameL.TextXAlignment = Enum.TextXAlignment.Left
	local code = label(info, "Code", def.nameEn .. "  ·  " .. def.code, UDim2.new(1, 0, 0, 16), UDim2.new(0, 0, 0, 34), 12, MUTED, FONT)
	code.TextXAlignment = Enum.TextXAlignment.Left
	local title = label(info, "Title", def.title, UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 52), 16, def.color, FONT)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local quote = label(info, "Quote", def.quote, UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 74), 13, def.accent, FONT_BODY)
	quote.TextXAlignment = Enum.TextXAlignment.Left
	local blurb = label(info, "Blurb", def.blurb, UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0, 96), 12, Color3.fromRGB(210, 204, 200), FONT_BODY)
	blurb.TextXAlignment = Enum.TextXAlignment.Left
	blurb.TextYAlignment = Enum.TextYAlignment.Top

	local stats = frame(info, "Stats", UDim2.new(1, 0, 0, 80), UDim2.new(0, 0, 0, 138), PANEL, 1)
	statBar(stats, 0, "파워", def.stats.power, def.color)
	statBar(stats, 18, "속도", def.stats.speed, def.color)
	statBar(stats, 36, "사거리", def.stats.range, def.color)
	statBar(stats, 54, "난이도", def.stats.difficulty, Color3.fromRGB(200, 200, 210))

	local moves = frame(info, "Moves", UDim2.new(1, 0, 0, 110), UDim2.new(0, 0, 0, 216), PANEL, 1)
	for i, mv in def.moves do
		local l = label(moves, "Move" .. i, tostring(i) .. "  " .. mv.name, UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, (i - 1) * 19), 13, WHITE, FONT)
		l.TextXAlignment = Enum.TextXAlignment.Left
	end
	local aw = label(moves, "Awaken", "G  " .. def.awakening.name .. "  —  " .. def.awakening.sub, UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 80), 13, def.color, FONT)
	aw.TextXAlignment = Enum.TextXAlignment.Left

	local pick = button(card, "Pick", "이 캐릭터로 싸운다", UDim2.new(1, -28, 0, 46), UDim2.new(0, 14, 1, -58), def.color, 18)
	pick.TextColor3 = if def.id == "LinYuan" then Color3.fromRGB(40, 24, 8) else WHITE
	pick.Font = FONT_HEAVY
	pick.Activated:Connect(function()
		Sounds.play("ui_confirm", {})
		local cb = UI.onSelect
		if cb then
			cb(def.id)
		end
	end)
	card.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 1.03 }):Play()
		TweenService:Create(st, TweenInfo.new(0.15), { Transparency = 0 }):Play()
	end)
	card.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 1 }):Play()
		TweenService:Create(st, TweenInfo.new(0.15), { Transparency = 0.4 }):Play()
	end)
end

local function buildSelect()
	selectFrame = frame(gui, "Select", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(8, 6, 10), 0.35)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 40, 10)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(8, 6, 10)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 10, 14)),
	})
	g.Transparency = NumberSequence.new(0.1)
	g.Parent = selectFrame
	local title = label(selectFrame, "Title", Config.GameTitle, UDim2.new(1, 0, 0, 64), UDim2.new(0, 0, 0.03, 0), 54, WHITE, FONT_HEAVY)
	local tg = Instance.new("UIGradient")
	tg.Color = ColorSequence.new(Color3.fromRGB(255, 210, 110), Color3.fromRGB(230, 60, 60))
	tg.Parent = title
	label(selectFrame, "Subtitle", Config.GameSubtitle .. "  ·  캐릭터를 고르세요", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0.03, 66), 18, MUTED, FONT)
	local order = CharacterDefs.Order
	for i, id in order do
		local def = CharacterDefs.get(id)
		if def then
			buildCard(selectFrame, def, if i == 1 then 0.32 else 0.68)
		end
	end
	local hint = label(selectFrame, "Hint", "노션 「WACA // 기밀 인물 도감」의 두 요원 · 혼자라면 선택 후 왼쪽 위에서 봇을 소환하세요", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 1, -30), 13, MUTED, FONT_BODY)
	hint.TextTransparency = 0.2
end

----------------------------------------------------------------------
-- HUD
----------------------------------------------------------------------
type Slot = { frame: Frame, name: TextLabel, cd: Frame, cdText: TextLabel, st: UIStroke, key: TextLabel }
local slots: { Slot } = {}
local hpFill: Frame
local hpGhost: Frame
local hpText: TextLabel
local awFill: Frame
local awText: TextLabel
local awStroke: UIStroke
local evFill: Frame
local guardFill: Frame
local ashRow: Frame
local ashSegs: { Frame } = {}
local ashText: TextLabel
local charName: TextLabel
local charTitle: TextLabel
local comboLabel: TextLabel
local notifyLabel: TextLabel
local feedList: Frame
local titleCard: Frame
local letterTop: Frame
local letterBottom: Frame
local deathFrame: Frame
local helpFrame: Frame
local veilFrame: Frame
local dashFront: TextLabel
local dashSide: TextLabel

local function buildHud()
	hud = frame(gui, "HUD", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), PANEL, 1)
	hud.Visible = false

	-- 아래 가운데
	local bottom = frame(hud, "Bottom", UDim2.new(0, 540, 0, 190), UDim2.new(0.5, 0, 1, -12), PANEL, 1)
	bottom.AnchorPoint = Vector2.new(0.5, 1)
	local bscale = Instance.new("UIScale")
	bscale.Parent = bottom

	-- 회분 (칸자키 렌)
	ashRow = frame(bottom, "Ash", UDim2.new(0, 360, 0, 18), UDim2.new(0.5, -180, 0, 0), PANEL, 1)
	local ashL = label(ashRow, "Label", "회분", UDim2.new(0, 40, 1, 0), UDim2.new(0, 0, 0, 0), 13, Color3.fromRGB(255, 120, 110), FONT)
	ashL.TextXAlignment = Enum.TextXAlignment.Left
	for i = 1, 10 do
		local seg = frame(ashRow, "Seg" .. i, UDim2.new(0, 22, 0, 12), UDim2.new(0, 44 + (i - 1) * 26, 0, 3), Color3.fromRGB(40, 36, 40))
		corner(seg, 3)
		stroke(seg, Color3.fromRGB(120, 30, 34), 1, 0.3)
		ashSegs[i] = seg
	end
	ashText = label(ashRow, "Timer", "", UDim2.new(0, 60, 1, 0), UDim2.new(1, 8, 0, 0), 12, MUTED, FONT)
	ashText.TextXAlignment = Enum.TextXAlignment.Left
	ashRow.Visible = false

	-- 체력
	local hpBack = frame(bottom, "HP", UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 24), Color3.fromRGB(28, 24, 30), 0.1)
	corner(hpBack, 6)
	stroke(hpBack, Color3.fromRGB(0, 0, 0), 1.5, 0.3)
	hpGhost = frame(hpBack, "Ghost", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(255, 240, 230), 0.2)
	corner(hpGhost, 6)
	hpFill = frame(hpBack, "Fill", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(90, 220, 110))
	corner(hpFill, 6)
	local hg = Instance.new("UIGradient")
	hg.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200))
	hg.Rotation = 90
	hg.Parent = hpFill
	hpText = label(hpBack, "Text", "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 14, WHITE, FONT_HEAVY)
	hpText.TextStrokeTransparency = 0.4

	-- 각성
	local awBack = frame(bottom, "Awaken", UDim2.new(1, 0, 0, 10), UDim2.new(0, 0, 0, 50), Color3.fromRGB(28, 24, 30), 0.1)
	corner(awBack, 5)
	awStroke = stroke(awBack, Color3.fromRGB(255, 220, 120), 1.5, 1)
	awFill = frame(awBack, "Fill", UDim2.fromScale(0, 1), UDim2.fromScale(0, 0), Color3.fromRGB(255, 196, 74))
	corner(awFill, 5)
	awText = label(bottom, "AwakenText", "각성 0%", UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, 61), 12, MUTED, FONT)
	awText.TextXAlignment = Enum.TextXAlignment.Right

	-- 기술 단축바
	for i = 1, 4 do
		local sf = frame(bottom, "Slot" .. i, UDim2.new(0, 126, 0, 70), UDim2.new(0, (i - 1) * 138, 0, 110), PANEL, 0.15)
		corner(sf, 10)
		local st = stroke(sf, Color3.fromRGB(80, 74, 80), 1.5, 0.2)
		local key = label(sf, "Key", tostring(i), UDim2.new(0, 22, 0, 22), UDim2.new(0, 6, 0, 5), 16, Color3.fromRGB(255, 220, 150), FONT_HEAVY)
		local nm = label(sf, "Name", "", UDim2.new(1, -12, 0, 36), UDim2.new(0, 6, 0, 26), 14, WHITE, FONT)
		nm.TextYAlignment = Enum.TextYAlignment.Top
		local cd = frame(sf, "CD", UDim2.fromScale(1, 0), UDim2.fromScale(0, 0), Color3.new(0, 0, 0), 0.35)
		corner(cd, 10)
		local cdText = label(sf, "CDText", "", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), 22, WHITE, FONT_HEAVY)
		cdText.TextStrokeTransparency = 0.3
		local tap = Instance.new("TextButton")
		tap.Name = "Tap"
		tap.BackgroundTransparency = 1
		tap.Text = ""
		tap.Size = UDim2.fromScale(1, 1)
		tap.Parent = sf
		tap.Activated:Connect(function()
			action("SkillTap", i)
		end)
		slots[i] = { frame = sf, name = nm, cd = cd, cdText = cdText, st = st, key = key }
	end

	-- 왼쪽 아래: 회피 / 가드 / 대시
	local left = frame(hud, "Left", UDim2.new(0, 200, 0, 92), UDim2.new(0, 16, 1, -16), PANEL, 0.3)
	left.AnchorPoint = Vector2.new(0, 1)
	corner(left, 10)
	local function smallBar(y: number, text: string, color: Color3): Frame
		local l = label(left, "L" .. text, text, UDim2.new(0, 70, 0, 14), UDim2.new(0, 10, 0, y), 12, MUTED, FONT)
		l.TextXAlignment = Enum.TextXAlignment.Left
		local back = frame(left, "B" .. text, UDim2.new(1, -90, 0, 8), UDim2.new(0, 80, 0, y + 3), Color3.fromRGB(40, 36, 44))
		corner(back, 4)
		local fill = frame(back, "Fill", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), color)
		corner(fill, 4)
		return fill
	end
	evFill = smallBar(10, "회피 [Q]", Color3.fromRGB(140, 220, 255))
	guardFill = smallBar(30, "가드 [F]", Color3.fromRGB(180, 200, 255))
	dashFront = label(left, "DashF", "앞 대시 ✓", UDim2.new(0.5, -10, 0, 16), UDim2.new(0, 10, 0, 54), 12, WHITE, FONT)
	dashFront.TextXAlignment = Enum.TextXAlignment.Left
	dashSide = label(left, "DashS", "옆 대시 ✓", UDim2.new(0.5, -10, 0, 16), UDim2.new(0.5, 0, 0, 54), 12, WHITE, FONT)
	dashSide.TextXAlignment = Enum.TextXAlignment.Left
	local tip = label(left, "Tip", "스턴 중 Q = 회피", UDim2.new(1, -20, 0, 14), UDim2.new(0, 10, 0, 72), 11, MUTED, FONT_BODY)
	tip.TextXAlignment = Enum.TextXAlignment.Left

	-- 왼쪽 위: 캐릭터 정보 + 메뉴
	local top = frame(hud, "TopLeft", UDim2.new(0, 230, 0, 200), UDim2.new(0, 16, 0, 60), PANEL, 0.3)
	corner(top, 10)
	charName = label(top, "Name", "", UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 0, 8), 22, WHITE, FONT_HEAVY)
	charName.TextXAlignment = Enum.TextXAlignment.Left
	charTitle = label(top, "Title", "", UDim2.new(1, -20, 0, 16), UDim2.new(0, 10, 0, 34), 13, MUTED, FONT)
	charTitle.TextXAlignment = Enum.TextXAlignment.Left
	local b1 = button(top, "Change", "캐릭터 변경", UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 0, 58), Color3.fromRGB(60, 56, 66), 13)
	b1.Activated:Connect(function()
		action("Unselect", nil)
	end)
	local b2 = button(top, "BotLin", "봇 소환 · 린 위안", UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 0, 88), Color3.fromRGB(150, 110, 30), 13)
	b2.Activated:Connect(function()
		action("SpawnBot", { charId = "LinYuan" })
	end)
	local b3 = button(top, "BotRen", "봇 소환 · 칸자키 렌", UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 0, 118), Color3.fromRGB(140, 30, 36), 13)
	b3.Activated:Connect(function()
		action("SpawnBot", { charId = "KanzakiRen" })
	end)
	local b4 = button(top, "ClearBots", "봇 모두 제거", UDim2.new(0.5, -14, 0, 26), UDim2.new(0, 10, 0, 148), Color3.fromRGB(50, 48, 54), 12)
	b4.Activated:Connect(function()
		action("ClearBots", nil)
	end)
	local b5 = button(top, "Help", "조작법 [H]", UDim2.new(0.5, -14, 0, 26), UDim2.new(0.5, 4, 0, 148), Color3.fromRGB(50, 48, 54), 12)
	b5.Activated:Connect(function()
		UI.toggleHelp()
	end)

	-- 콤보
	comboLabel = label(hud, "Combo", "", UDim2.new(0, 220, 0, 60), UDim2.new(1, -250, 0.42, 0), 42, WHITE, FONT_HEAVY)
	comboLabel.TextXAlignment = Enum.TextXAlignment.Right
	comboLabel.TextStrokeTransparency = 0.2
	comboLabel.TextTransparency = 1
	comboLabel.TextStrokeTransparency = 1
	local cs = Instance.new("UIScale")
	cs.Parent = comboLabel

	-- 알림
	notifyLabel = label(hud, "Notify", "", UDim2.new(0, 600, 0, 30), UDim2.new(0.5, -300, 0.2, 0), 20, WHITE, FONT_HEAVY)
	notifyLabel.TextStrokeTransparency = 0.3
	notifyLabel.TextTransparency = 1

	-- 킬 피드
	feedList = frame(hud, "Feed", UDim2.new(0, 360, 0, 200), UDim2.new(1, -376, 0, 60), PANEL, 1)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = feedList

	-- 분진막 안 시야 가림
	veilFrame = frame(gui, "Veil", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(6, 5, 6), 1)
	veilFrame.ZIndex = 0

	-- 각성 연출
	letterTop = frame(gui, "LetterTop", UDim2.new(1, 0, 0.12, 0), UDim2.new(0, 0, -0.12, 0), Color3.new(0, 0, 0))
	letterBottom = frame(gui, "LetterBottom", UDim2.new(1, 0, 0.12, 0), UDim2.new(0, 0, 1, 0), Color3.new(0, 0, 0))
	titleCard = frame(gui, "TitleCard", UDim2.new(1, 0, 0, 140), UDim2.new(0, 0, 0.26, 0), PANEL, 1)
	titleCard.Visible = false
	local tname = label(titleCard, "Name", "", UDim2.new(1, 0, 0, 70), UDim2.new(0, 0, 0, 0), 64, WHITE, FONT_HEAVY)
	tname.TextStrokeTransparency = 0.2
	local tgrad = Instance.new("UIGradient")
	tgrad.Name = "Grad"
	tgrad.Parent = tname
	label(titleCard, "Sub", "", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 70), 22, WHITE, FONT).TextStrokeTransparency = 0.4
	label(titleCard, "Quote", "", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 102), 18, MUTED, FONT_BODY).TextStrokeTransparency = 0.5

	-- 사망
	deathFrame = frame(gui, "Death", UDim2.fromScale(1, 1), UDim2.fromScale(0, 0), Color3.fromRGB(30, 0, 0), 0.6)
	deathFrame.Visible = false
	label(deathFrame, "Text", "쓰러졌다", UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 0.4, 0), 48, WHITE, FONT_HEAVY)
	label(deathFrame, "Sub", "잠시 후 다시 일어섭니다", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0.4, 62), 18, MUTED, FONT)

	-- 조작법
	helpFrame = frame(gui, "Help", UDim2.new(0, 440, 0, 360), UDim2.new(0.5, -220, 0.5, -180), PANEL, 0.08)
	corner(helpFrame, 12)
	stroke(helpFrame, Color3.fromRGB(255, 200, 120), 1.5, 0.3)
	helpFrame.Visible = false
	label(helpFrame, "Title", "조작법", UDim2.new(1, 0, 0, 36), UDim2.new(0, 0, 0, 10), 24, WHITE, FONT_HEAVY)
	local lines = {
		"좌클릭 (누르고 있기)  ·  M1 연타 (4타)",
		"4타에서 Space 누른 채  ·  띄우기 / 공중 4타  ·  내려찍기",
		"F (누르고 있기)  ·  막기  —  맞기 직전에 누르면 패리",
		"Q + 방향키  ·  대시 (앞/뒤/좌/우)",
		"스턴 중 Q  ·  회피 (회피 게이지 가득일 때)",
		"1 ~ 4  ·  기술",
		"G  ·  각성 (각성 게이지 100%)",
		"Shift  ·  시점 고정 (Shift Lock)",
		"H  ·  이 창 열기/닫기",
		"칸자키 렌: 칼로 적/소품을 베면 회분이 쌓인다",
		"린 위안: 2번 《유전》으로 공격·투사체를 되돌린다",
	}
	for i, t in lines do
		local l = label(helpFrame, "Line" .. i, t, UDim2.new(1, -40, 0, 24), UDim2.new(0, 20, 0, 48 + (i - 1) * 26), 14, Color3.fromRGB(230, 226, 222), FONT)
		l.TextXAlignment = Enum.TextXAlignment.Left
	end
	local close = button(helpFrame, "Close", "닫기", UDim2.new(0, 100, 0, 30), UDim2.new(0.5, -50, 1, -40), Color3.fromRGB(80, 70, 60), 14)
	close.Activated:Connect(function()
		helpFrame.Visible = false
	end)

	-- 모바일 버튼
	if UserInputService.TouchEnabled then
		local pad = frame(hud, "Mobile", UDim2.new(0, 230, 0, 230), UDim2.new(1, -250, 1, -420), PANEL, 1)
		local function mb(name: string, text: string, size: number, x: number, y: number, color: Color3): TextButton
			local b = button(pad, name, text, UDim2.new(0, size, 0, size), UDim2.new(0, x, 0, y), color, 16)
			corner(b, math.floor(size / 2))
			b.BackgroundTransparency = 0.2
			return b
		end
		local atk = mb("Attack", "공격", 96, 120, 120, Color3.fromRGB(180, 60, 60))
		atk.MouseButton1Down:Connect(function()
			action("M1Hold", true)
		end)
		atk.MouseButton1Up:Connect(function()
			action("M1Hold", false)
		end)
		local blk = mb("Block", "막기", 64, 30, 150, Color3.fromRGB(70, 90, 150))
		blk.MouseButton1Down:Connect(function()
			action("BlockHold", true)
		end)
		blk.MouseButton1Up:Connect(function()
			action("BlockHold", false)
		end)
		local dsh = mb("Dash", "대시", 64, 150, 40, Color3.fromRGB(70, 130, 110))
		dsh.Activated:Connect(function()
			action("DashTap", nil)
		end)
		local awk = mb("Awaken", "각성", 58, 60, 70, Color3.fromRGB(190, 140, 40))
		awk.Activated:Connect(function()
			action("AwakenTap", nil)
		end)
	end
end

----------------------------------------------------------------------
-- 공개 API
----------------------------------------------------------------------
function UI.showSelect(show: boolean)
	selectFrame.Visible = show
	hud.Visible = not show
	if show then
		deathFrame.Visible = false
	end
end

function UI.setCharacter(charId: string?)
	currentChar = charId
	table.clear(cooldownEnds)
	local def = if charId then CharacterDefs.get(charId) else nil
	if def then
		charName.Text = def.name
		charName.TextColor3 = def.color
		charTitle.Text = def.title
		hpFill.BackgroundColor3 = def.color
		awFill.BackgroundColor3 = def.color
		ashRow.Visible = def.id == "KanzakiRen"
	end
end

function UI.setCooldown(key: string, endsAt: number, duration: number)
	if key == "*" then
		table.clear(cooldownEnds)
		return
	end
	cooldownEnds[key] = endsAt
	cooldownDur[key] = duration
end

function UI.cooldownLeft(key: string): number
	local e = cooldownEnds[key]
	if not e then
		return 0
	end
	return math.max(0, e - workspace:GetServerTimeNow())
end

local notifyToken = 0
function UI.notify(text: string, kind: string?)
	notifyToken += 1
	local tok = notifyToken
	notifyLabel.Text = text
	notifyLabel.TextColor3 = if kind == "warn"
		then Color3.fromRGB(255, 170, 150)
		elseif kind == "good" then Color3.fromRGB(170, 255, 190)
		elseif kind == "awaken" then Color3.fromRGB(255, 220, 130)
		else WHITE
	notifyLabel.TextTransparency = 0
	notifyLabel.TextStrokeTransparency = 0.3
	task.delay(1.8, function()
		if tok == notifyToken then
			TweenService:Create(notifyLabel, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

function UI.feed(killer: string, victim: string)
	local row = frame(feedList, "Row", UDim2.new(0, 360, 0, 26), UDim2.fromScale(0, 0), PANEL, 0.25)
	corner(row, 6)
	row.LayoutOrder = -math.floor(os.clock() * 100)
	local l = label(row, "Text", killer .. "  ⚔  " .. victim, UDim2.new(1, -12, 1, 0), UDim2.new(0, 6, 0, 0), 13, WHITE, FONT)
	l.TextXAlignment = Enum.TextXAlignment.Right
	task.delay(6, function()
		TweenService:Create(row, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		TweenService:Create(l, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		task.wait(0.55)
		row:Destroy()
	end)
end

local comboToken = 0
function UI.combo(count: number)
	comboToken += 1
	local tok = comboToken
	comboLabel.Text = tostring(count) .. " HIT"
	comboLabel.TextTransparency = 0
	comboLabel.TextStrokeTransparency = 0.2
	local def = if currentChar then CharacterDefs.get(currentChar) else nil
	comboLabel.TextColor3 = if def then def.accent else WHITE
	local sc = comboLabel:FindFirstChildOfClass("UIScale")
	if sc then
		sc.Scale = 1.35
		TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	task.delay(1.6, function()
		if tok == comboToken then
			TweenService:Create(comboLabel, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

function UI.awakenTitle(model: Model, charId: string)
	local def = CharacterDefs.get(charId)
	if not def then
		return
	end
	local mine = model == player.Character
	local nameL = titleCard:FindFirstChild("Name") :: TextLabel
	local sub = titleCard:FindFirstChild("Sub") :: TextLabel
	local quote = titleCard:FindFirstChild("Quote") :: TextLabel
	nameL.Text = def.awakening.name
	sub.Text = def.name .. "  —  " .. def.awakening.sub
	quote.Text = def.awakening.quote
	local grad = nameL:FindFirstChild("Grad") :: UIGradient
	grad.Color = ColorSequence.new(def.accent, def.color)
	titleCard.Visible = true
	titleCard.Position = UDim2.new(0, 0, 0.26, 0)
	for _, l in { nameL, sub, quote } do
		l.TextTransparency = 1
		TweenService:Create(l, TweenInfo.new(0.35), { TextTransparency = 0 }):Play()
	end
	if mine then
		TweenService:Create(letterTop, TweenInfo.new(0.35), { Position = UDim2.new(0, 0, 0, 0) }):Play()
		TweenService:Create(letterBottom, TweenInfo.new(0.35), { Position = UDim2.new(0, 0, 0.88, 0) }):Play()
	end
	task.delay(2.4, function()
		for _, l in { nameL, sub, quote } do
			TweenService:Create(l, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
		TweenService:Create(letterTop, TweenInfo.new(0.4), { Position = UDim2.new(0, 0, -0.12, 0) }):Play()
		TweenService:Create(letterBottom, TweenInfo.new(0.4), { Position = UDim2.new(0, 0, 1, 0) }):Play()
		task.wait(0.45)
		titleCard.Visible = false
	end)
end

function UI.awakenReady()
	awStroke.Transparency = 0
end

function UI.toggleHelp()
	helpFrame.Visible = not helpFrame.Visible
end

function UI.setDead(dead: boolean)
	deathFrame.Visible = dead
end

----------------------------------------------------------------------
-- 매 프레임 갱신
----------------------------------------------------------------------
local lastHpFrac = 1
local ghostFrac = 1

local function fmt(n: number): string
	if n >= 10 then
		return tostring(math.floor(n))
	end
	return string.format("%.1f", n)
end

local function update(dt: number)
	for _, p in previews do
		if selectFrame.Visible then
			p.angle += dt * 0.5
			p.model:PivotTo(CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(200) + math.sin(p.angle) * 0.6, 0))
			Animator.stepModel(p.model, dt)
		end
	end
	if not hud.Visible then
		return
	end
	local char = localChar()
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum then
		return
	end
	-- 체력
	local frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
	hpFill.Size = UDim2.fromScale(frac, 1)
	if frac < lastHpFrac then
		ghostFrac = math.max(ghostFrac, lastHpFrac)
	end
	lastHpFrac = frac
	ghostFrac = math.max(frac, ghostFrac - dt * 0.35)
	hpGhost.Size = UDim2.fromScale(ghostFrac, 1)
	hpText.Text = string.format("%d / %d", math.ceil(hum.Health), math.floor(hum.MaxHealth))

	-- 각성
	local aw = attr(char, "Awakening", 0) :: number
	local awakened = attr(char, "Awakened", false) == true
	awFill.Size = UDim2.fromScale(math.clamp(aw / 100, 0, 1), 1)
	if awakened then
		local def = if currentChar then CharacterDefs.get(currentChar) else nil
		awText.Text = (if def then def.awakening.name else "각성") .. " 중"
		awStroke.Transparency = 0.2
	elseif aw >= 100 then
		awText.Text = "각성 가능! [G]"
		awStroke.Transparency = 0.2 + 0.6 * (0.5 + 0.5 * math.sin(os.clock() * 6))
	else
		awText.Text = "각성 " .. tostring(math.floor(aw)) .. "%"
		awStroke.Transparency = 1
	end

	evFill.Size = UDim2.fromScale(math.clamp((attr(char, "Evasive", 100) :: number) / 100, 0, 1), 1)
	guardFill.Size = UDim2.fromScale(math.clamp((attr(char, "Guard", 100) :: number) / 100, 0, 1), 1)
	local df = UI.cooldownLeft("DashFront")
	local ds = UI.cooldownLeft("DashSide")
	dashFront.Text = if df > 0 then "앞 대시 " .. fmt(df) else "앞 대시 ✓"
	dashSide.Text = if ds > 0 then "옆 대시 " .. fmt(ds) else "옆 대시 ✓"

	-- 회분
	if ashRow.Visible then
		local ash = attr(char, "Ash", 0) :: number
		for i, seg in ashSegs do
			seg.BackgroundColor3 = if i <= ash then Color3.fromRGB(20, 18, 20) else Color3.fromRGB(46, 42, 46)
			local s = seg:FindFirstChildOfClass("UIStroke")
			if s then
				s.Color = if i <= ash then Color3.fromRGB(255, 60, 60) else Color3.fromRGB(100, 30, 34)
				s.Transparency = if i <= ash then 0 else 0.4
			end
		end
		local exp = attr(char, "AshExpire", 0) :: number
		if awakened then
			ashText.Text = "∞"
		elseif ash > 0 and exp > 0 then
			ashText.Text = fmt(math.max(0, exp - workspace:GetServerTimeNow())) .. "s"
		else
			ashText.Text = ""
		end
	end

	-- 기술 슬롯
	local def = if currentChar then CharacterDefs.get(currentChar) else nil
	if def then
		local list = if awakened then def.awakenedMoves else def.moves
		local exhausted = attr(char, "Exhausted", false) == true
		for i, s in slots do
			local mv = list[i]
			s.name.Text = mv.name
			local left = UI.cooldownLeft(mv.id)
			local total = cooldownDur[mv.id] or mv.cooldown
			if left > 0 and total > 0 then
				s.cd.Size = UDim2.fromScale(1, math.clamp(left / total, 0, 1))
				s.cdText.Text = fmt(left)
			elseif exhausted then
				s.cd.Size = UDim2.fromScale(1, 1)
				s.cdText.Text = "탈진"
			else
				s.cd.Size = UDim2.fromScale(1, 0)
				s.cdText.Text = ""
			end
			s.st.Color = if awakened then def.color else Color3.fromRGB(80, 74, 80)
		end
	end

	-- 분진막
	local inVeil = attr(char, "InVeil", false) == true
	CameraFX.setVeil(inVeil)
	veilFrame.BackgroundTransparency = veilFrame.BackgroundTransparency + ((if inVeil then 0.45 else 1) - veilFrame.BackgroundTransparency) * math.min(1, dt * 5)
end

function UI.init()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	gui = Instance.new("ScreenGui")
	gui.Name = "BattlegroundsUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	buildSelect()
	buildHud()
	UI.showSelect(true)
	RunService.RenderStepped:Connect(update)
end

return UI
