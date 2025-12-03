--!strict
--!native
--!optimize 2

local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Chip8 = require(ReplicatedStorage.Chip8)
local Base64 = require(ReplicatedStorage.Base64)

local CYCLE_RATE = 1/60
local WIDTH, HEIGHT = 64, 32
local RESOLUTION_SCALE = 8

local KEY_MAP: {[Enum.KeyCode]: number} = {
	[Enum.KeyCode.One] = 0x1, [Enum.KeyCode.Two] = 0x2, [Enum.KeyCode.Three] = 0x3, [Enum.KeyCode.Four] = 0xC,
	[Enum.KeyCode.Q]   = 0x4, [Enum.KeyCode.W]   = 0x5, [Enum.KeyCode.E]     = 0x6, [Enum.KeyCode.R]    = 0xD,
	[Enum.KeyCode.A]   = 0x7, [Enum.KeyCode.S]   = 0x8, [Enum.KeyCode.D]     = 0x9, [Enum.KeyCode.F]    = 0xE,
	[Enum.KeyCode.Z]   = 0xA, [Enum.KeyCode.X]   = 0x0, [Enum.KeyCode.C]     = 0xB, [Enum.KeyCode.V]    = 0xF
}

local function getImage(): EditableImage
	local gui = Instance.new("ScreenGui")
	gui.Name = "Display"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer.PlayerGui

	local label = Instance.new("ImageLabel")
	label.Name = "Image"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromOffset(WIDTH * RESOLUTION_SCALE, HEIGHT * RESOLUTION_SCALE)
	label.BorderSizePixel = 0
	label.ResampleMode = Enum.ResamplerMode.Pixelated
	label.Parent = gui

	local image = AssetService:CreateEditableImage({Size = Vector2.new(WIDTH, HEIGHT)})
	label.ImageContent = Content.fromObject(image)
	return image
end

local function init(): never
	local ROM = ReplicatedStorage.ROM["test_opcode"].Value :: string
	local cpu = Chip8.load(Base64.decode(ROM))

	local image = getImage()
	local keys: {[number]: boolean} = {}

	UserInputService.InputBegan:Connect(function(input, processed)
		local index = KEY_MAP[input.KeyCode]
		if index then
			keys[index] = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input, processed)
		local index = KEY_MAP[input.KeyCode]
		if index then
			keys[index] = false
		end
	end)

	while true do
		local cycle = cpu:cycle(keys)
		assert(not cycle.error, cycle.error)

		local screen = cpu.state.screen
		local update = buffer.create(WIDTH * HEIGHT * 4)

		for y = 0, HEIGHT - 1 do
			for x = 0, WIDTH - 1 do
				local index = y * WIDTH + x
				local value = buffer.readu8(screen, index)
				buffer.writeu32(update, index * 4, value > 0 and 0xFFFFFFFF or 0xFF000000)
			end
		end

		image:WritePixelsBuffer(Vector2.zero, image.Size, update)
		task.wait(CYCLE_RATE)
	end
end

return init()
