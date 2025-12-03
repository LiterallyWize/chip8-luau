--!strict
--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Chip8 = require(ReplicatedStorage.Chip8)
local Base64 = require(ReplicatedStorage.Base64)

local CYCLE_RATE_HZ = 60

local function init(): never
	local ROM = ReplicatedStorage.ROM["test_opcode"].Value :: string
	local cpu = Chip8.load(Base64.decode(ROM))

	while true do
		local cycle = cpu:cycle()
		if cycle.draw then
			-- display draw buffer
		end

		task.wait(1 / CYCLE_RATE_HZ)
	end
end

return init()
