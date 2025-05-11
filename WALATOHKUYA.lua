--// SERVICES
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

--// SETTINGS
local AimbotEnabled = false
local RightClickHeld = false
local AimbotMode = "Instant" -- "Instant" or "Smooth"
local Smoothness = 0
local MaxDistance = 1000
local FOVRadius = 120 -- slightly bigger

local CurrentTarget = nil

--// VISIBILITY CHECK INCLUDING FAKE HEADS
local function isVisible(part)
	if not part or not part:IsA("BasePart") then return false end

	local origin = Camera.CFrame.Position
	local direction = (part.Position - origin)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
	rayParams.IgnoreWater = true

	local result = workspace:Raycast(origin, direction.Unit * direction.Magnitude, rayParams)
	if not result then return false end
	if result.Instance == part or result.Instance:IsDescendantOf(part.Parent) then
		return true
	end

	return false
end

--// GET HEAD OR CREATE FAKE HEAD
local function getHeadTarget(character)
	local head = character:FindFirstChild("Head")
	if head then return head end

	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local name = "FakeHead_" .. character.Name
	local existing = workspace:FindFirstChild(name)
	local offsetY = 1.70

	if existing then
		existing.CFrame = root.CFrame * CFrame.new(0, offsetY, 0)
		return existing
	end

	local fakeHead = Instance.new("Part")
	fakeHead.Name = name
	fakeHead.Size = Vector3.new(1, 1, 1)
	fakeHead.Transparency = 1
	fakeHead.Anchored = true
	fakeHead.CanCollide = false
	fakeHead.CFrame = root.CFrame * CFrame.new(0, offsetY, 0)
	fakeHead.Parent = workspace
	Debris:AddItem(fakeHead, 0.1)

	return fakeHead
end

--// GET VALID TARGET
local function getValidTarget()
	local originChar = LocalPlayer.Character
	if not originChar or not originChar:FindFirstChild("HumanoidRootPart") then return nil end
	local origin = originChar.HumanoidRootPart.Position

	local closest, minDist = nil, MaxDistance
	local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
	local radius = FOVRadius -- already adjusted

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				local head = getHeadTarget(player.Character)
				if head and isVisible(head) then
					local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
					if onScreen then
						local head2D = Vector2.new(screenPos.X, screenPos.Y)
						local distanceFromCenter = (head2D - screenCenter).Magnitude

						local worldDistance = (head.Position - origin).Magnitude
						if distanceFromCenter <= radius and worldDistance < minDist then
							closest = head
							minDist = worldDistance
						end
					end
				end
			end
		end
	end

	return closest
end

--// AIMBOT
RunService.RenderStepped:Connect(function()
	if RightClickHeld then
		CurrentTarget = getValidTarget()
		AimbotEnabled = CurrentTarget ~= nil
	else
		AimbotEnabled = false
		CurrentTarget = nil
	end

	if AimbotEnabled and CurrentTarget and CurrentTarget.Parent then
		local desired = CFrame.new(Camera.CFrame.Position, CurrentTarget.Position)
		Camera.CFrame = (AimbotMode == "Instant" or Smoothness <= 0)
			and desired
			or Camera.CFrame:Lerp(desired, math.clamp(Smoothness, 0, 1))
	end
end)

--// INPUT
UserInputService.InputBegan:Connect(function(input, gp)
	if not gp and input.UserInputType == Enum.UserInputType.MouseButton2 then
		RightClickHeld = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		RightClickHeld = false
	end
end)

--// ESP
local ESP = {}

local function createESP(player)
	if ESP[player] then return end
	local box = Drawing.new("Square")
	box.Thickness = 2
	box.Filled = false
	box.Transparency = 1
	box.Visible = true
	ESP[player] = {Box = box}
end

local function removeESP(player)
	if ESP[player] then
		ESP[player].Box:Remove()
		ESP[player] = nil
	end
end

Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(removeESP)

for _, player in ipairs(Players:GetPlayers()) do
	if player ~= LocalPlayer then createESP(player) end
end

RunService.RenderStepped:Connect(function()
	local hue = (tick() * 0.2) % 1
	for player, data in pairs(ESP) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local human = char and char:FindFirstChildOfClass("Humanoid")
		local box = data.Box

		if root and human and human.Health > 0 then
			local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
			if onScreen then
				local dist = (Camera.CFrame.Position - root.Position).Magnitude
				local size = math.clamp(2000 / dist, 50, 250)
				box.Size = Vector2.new(size, size)
				box.Position = Vector2.new(screenPos.X - size / 2, screenPos.Y - size / 2)
				box.Color = Color3.fromHSV(hue, 1, 1)
				box.Visible = true
			else
				box.Visible = false
			end
		else
			box.Visible = false
		end
	end
end)

--// FOV GUI
local FOVGui = Instance.new("ScreenGui")
FOVGui.Name = "FOVGui"
FOVGui.IgnoreGuiInset = true
FOVGui.ResetOnSpawn = false
FOVGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local FOVCircle = Instance.new("Frame")
FOVCircle.Size = UDim2.new(0, FOVRadius * 2, 0, FOVRadius * 2)
FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FOVCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
FOVCircle.BackgroundTransparency = 0.6
FOVCircle.BorderSizePixel = 0
FOVCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
FOVCircle.Parent = FOVGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = FOVCircle
