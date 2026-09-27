--!strict
-- 캐릭터를 미는 공통 함수 (서버/클라이언트 공용)
--
-- 이전 방식(모든 축에 무한한 힘으로 속도를 고정)은 벽·경사·다른 캐릭터에 닿는 순간
-- 엄청난 힘이 생겨 캐릭터가 튕겨 날아갔다. 지금은:
--   · 수평 이동: LinearVelocity 를 "평면(Plane)" 모드 + 유한한 힘으로만 건다 → 중력이 살아 있고 벽에 막힌다
--   · 수직 성분: 한 번만 속도를 넣는다(발사) → 자연스러운 포물선

local Debris = game:GetService("Debris")

local Physics = {}

Physics.MaxForce = 90000

local function attachment(root: BasePart): Attachment
	local att = root:FindFirstChild("PushAttachment")
	if att and att:IsA("Attachment") then
		return att
	end
	local a = Instance.new("Attachment")
	a.Name = "PushAttachment"
	a.Parent = root
	return a
end

function Physics.stop(root: BasePart)
	for _, c in root:GetChildren() do
		if c.Name == "PushVelocity" then
			c:Destroy()
		end
	end
end

function Physics.push(root: BasePart, vel: Vector3, duration: number)
	Physics.stop(root)
	local horiz = Vector2.new(vel.X, vel.Z)
	if horiz.Magnitude > 0.1 and duration > 0 then
		local lv = Instance.new("LinearVelocity")
		lv.Name = "PushVelocity"
		lv.Attachment0 = attachment(root)
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		lv.PrimaryTangentAxis = Vector3.new(1, 0, 0)
		lv.SecondaryTangentAxis = Vector3.new(0, 0, 1)
		lv.PlaneVelocity = horiz
		lv.ForceLimitMode = Enum.ForceLimitMode.Magnitude
		lv.MaxForce = Physics.MaxForce
		lv.Parent = root
		Debris:AddItem(lv, duration)
	end
	if math.abs(vel.Y) > 0.5 then
		local cur = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(cur.X, vel.Y, cur.Z)
	end
end

return Physics
