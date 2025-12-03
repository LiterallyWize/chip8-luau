--!strict
--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Chip8 = require(ReplicatedStorage.Chip8)

local function init(): nil
	local program: buffer
	local chip8 = Chip8.load(program)

	while true do
		local cycle = chip8:cycle()
		if cycle.draw then
			-- display draw buffer
		end
	end

	return nil
end

return init()
