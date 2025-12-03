--!strict
--!optimize 2

export type Cycle = {
	draw: buffer?
}

export type Chip8 = {
	_program: buffer,

	cycle: (self: Chip8) -> Cycle
}

local Chip8 = {}

function Chip8.load(program: buffer): Chip8
	-- initialize
end

return Chip8
