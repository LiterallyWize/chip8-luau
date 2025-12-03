--!strict
--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local AssetService = game:GetService("AssetService")
local SoundService = game:GetService("SoundService")
local Players = game:GetService("Players")

local Chip8 = require(ReplicatedStorage.Chip8)
local Base64 = require(ReplicatedStorage.Base64)

local PROGRAM = "animal_race"

local CYCLE_RATE = 1/60
local WIDTH, HEIGHT = 64, 32

local KEY_RESET = Enum.KeyCode.H
local KEY_MAP: {[Enum.KeyCode]: number} = {
	[Enum.KeyCode.One] = 0x1, [Enum.KeyCode.Two] = 0x2, [Enum.KeyCode.Three] = 0x3, [Enum.KeyCode.Four] = 0xC,
	[Enum.KeyCode.Q]   = 0x4, [Enum.KeyCode.W]   = 0x5, [Enum.KeyCode.E]     = 0x6, [Enum.KeyCode.R]    = 0xD,
	[Enum.KeyCode.A]   = 0x7, [Enum.KeyCode.S]   = 0x8, [Enum.KeyCode.D]     = 0x9, [Enum.KeyCode.F]    = 0xE,
	[Enum.KeyCode.Z]   = 0xA, [Enum.KeyCode.X]   = 0x0, [Enum.KeyCode.C]     = 0xB, [Enum.KeyCode.V]    = 0xF
}

local SOUND_ID = "rbxassetid://5229833733"
local COLOR_ON = Color3.fromHSV(0.01, 0.35, 0.8)
local COLOR_OFF = Color3.fromHSV(0.59, 0.33, 0.35)
local RESOLUTION_SCALE = 8

local function createImage(): EditableImage
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

local function createSound(): Sound
	local sound = Instance.new("Sound")
	sound.SoundId = SOUND_ID
	sound.Looped = true
	sound.Volume = 1
	sound.Parent = SoundService
	return sound
end

local function createCPU(): Chip8.CPU
	local program = Base64.decode(ReplicatedStorage.ROM[PROGRAM].Value)
	return Chip8.load(program)
end

local function init(): never
	local cpu = createCPU()

	local image = createImage()
	local sound = createSound()

	local keys: {[number]: boolean} = {}

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode == KEY_RESET then
			cpu = createCPU()
		end

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

	local function channel(v: number): number
		return (v * 0xFF) // 1
	end

	local on = channel(COLOR_ON.R) + channel(COLOR_ON.G) * 2^8 + channel(COLOR_ON.B) * 2^16 + 0xFF * 2^24
	local off = channel(COLOR_OFF.R) + channel(COLOR_OFF.G) * 2^8 + channel(COLOR_OFF.B) * 2^16 + 0xFF * 2^24

	local pixels = buffer.create(WIDTH * HEIGHT * 4)

	while true do
		local err = cpu:cycle(keys)
		assert(not err, err)

		local screen = cpu.state.screen

		for y = 0, HEIGHT - 1 do
			for x = 0, WIDTH - 1 do
				local index = y * WIDTH + x
				local value = buffer.readu8(screen, index)
				buffer.writeu32(pixels, index * 4, value > 0 and on or off)
			end
		end

		image:WritePixelsBuffer(Vector2.zero, image.Size, pixels)
		sound.Playing = cpu.state.sound == 1

		task.wait(CYCLE_RATE)
	end
end

return init()
