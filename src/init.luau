--!strict
--!native
--!optimize 2

export type Cycle = {
	error: string?,

	draw: buffer?
}

type State = {
	memory: buffer,    -- cpu memory
	screen: buffer,    -- screen pixels

	registry: buffer,  -- v registers
	stack: buffer,     -- call stack
	key: buffer,       -- key state

	index: number,     -- index register
	counter: number,   -- program counter
	pointer: number,   -- stack pointer

	delay: number,     -- delay timer
	sound: number,     -- sound timer
}

export type CPU = {
	state: State,
	cycle: (self: CPU) -> Cycle
}

local WIDTH, HEIGHT = 64, 32
local INSTRUCTIONS_PER_CYCLE = 10

local INSTRUCTIONS: {[number]: (state: State, opcode: number) -> number?}

local Chip8 = {}

local function cycle(self: CPU): Cycle
	local state = self.state
	local memory = state.memory

	for _ = 1, INSTRUCTIONS_PER_CYCLE do
		if state.counter >= 4096 then
			return {error = "program counter out of range"}
		end

		local opcode = buffer.readu8(memory, state.counter) * 2^8 + buffer.readu8(memory, state.counter + 1)
		local instruction = INSTRUCTIONS[bit32.band(opcode, 0xF000)]

		if instruction then
			state.counter += 2
			state.counter = instruction(state, opcode) or state.counter
		else
			return {error = string.format("unknown opcode: %04X", opcode)}
		end
	end

	if state.delay > 0 then
		state.delay -= 1
	end

	if state.sound > 0 then
		state.sound -= 1
	end

	return {}
end

function Chip8.load(program: buffer): CPU
	assert(buffer.len(program) < 4096 - 0x200, "program too large")

	local memory = buffer.create(4096)
	buffer.copy(memory, 0x200, program)

	return {
		state = {
			memory = memory,
			screen = buffer.create(WIDTH * HEIGHT),

			registry = buffer.create(16),
			stack = buffer.create(16 * 2),
			key = buffer.create(16),

			index = 0,
			counter = 0x200,
			pointer = 0,

			delay = 0,
			sound = 0
		},
		cycle = cycle
	}
end

INSTRUCTIONS = {
	[0x0000] = function(state, opcode)
		local address = bit32.band(opcode, 0x0FFF)

		if address == 0x00E0 then
			buffer.fill(state.screen, 0, 0)
		elseif address == 0x00EE then
			state.pointer -= 2
			return buffer.readu16(state.stack, state.pointer)
		end

		return nil
	end,
	[0x1000] = function(state, opcode)
		return bit32.band(opcode, 0x0FFF)
	end,
	[0x2000] = function(state, opcode)
		local address = bit32.band(opcode, 0x0FFF)
		buffer.writeu16(state.stack, state.pointer, state.counter)
		state.pointer += 2

		return address
	end,
	[0x3000] = function(state, opcode)
		local x = bit32.band(opcode, 0x0F00) // 2^8
		local y = bit32.band(opcode, 0x00FF)

		if buffer.readu8(state.registry, x) == y then
			return state.counter + 2
		end

		return nil
	end,
	[0x4000] = function(state, opcode)
		local x = bit32.band(opcode, 0x0F00) // 2^8
		local y = bit32.band(opcode, 0x00FF)

		if buffer.readu8(state.registry, x) ~= y then
			return state.counter + 2
		end

		return nil
	end,
	[0x5000] = function(state, opcode)
		local x = bit32.band(opcode, 0x0F00) // 2^8
		local y = bit32.band(opcode, 0x00F0) // 2^4

		if buffer.readu8(state.registry, x) == buffer.readu8(state.registry, y) then
			return state.counter + 2
		end

		return nil
	end,
	[0x6000] = function(state, opcode)


		return nil
	end,
	[0x7000] = function(state, opcode)


		return nil
	end,
	[0x8000] = function(state, opcode)


		return nil
	end,
	[0x9000] = function(state, opcode)
		local x = bit32.band(opcode, 0x0F00) // 2^8
		local y = bit32.band(opcode, 0x00F0) // 2^4

		if buffer.readu8(state.registry, x) ~= buffer.readu8(state.registry, y) then
			return state.counter + 2
		end

		return nil
	end,
	[0xA000] = function(state, opcode)


		return nil
	end,
	[0xB000] = function(state, opcode)


		return nil
	end,
	[0xC000] = function(state, opcode)


		return nil
	end,
	[0xD000] = function(state, opcode)


		return nil
	end,
	[0xE000] = function(state, opcode)


		return nil
	end,
	[0xF000] = function(state, opcode)


		return nil
	end,
}

return Chip8
