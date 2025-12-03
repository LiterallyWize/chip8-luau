--!strict
--!native
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Chip8 = require(ReplicatedStorage.Chip8)
local Base64 = require(ReplicatedStorage.Base64)

local ROM = (ReplicatedStorage.ROM["test_opcode"] :: StringValue).Value

local function init(): never
	local cpu = Chip8.load(Base64.decode(ROM))

	while true do
		local cycle = cpu:cycle()
		if cycle.draw then
			-- display draw buffer
		end
	end
end

return init()
