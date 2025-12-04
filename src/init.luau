--!strict
--!native
--!optimize 2

type State = {
	memory: buffer,     -- 4KB main memory
	screen: buffer,     -- 64x32 display, 1 byte per pixel (1 = on, 0 = off)

	registry: buffer,   -- 16-byte variable registry (V0-VF)
	stack: buffer,      -- 16-level call stack, 2-byte addresses
	key: buffer,        -- 16-byte keypad state buffer, 1 byte per key (1 = pressed, 0 = released)

	listener: number?,  -- if non-nil, cpu is waiting for key input (value = listening register index)

	index: number,      -- index register (I)
	counter: number,    -- program counter (PC)
	pointer: number,    -- stack pointer (SP)

	delay: number,      -- delay timer, decrements once per cycle when >0
	sound: number,      -- sound timer, ditto (beep when >0)
}

export type CPU = {
	state: State,
	cycle: (self: CPU, keys: {[number]: boolean}) -> string?
}

local WIDTH, HEIGHT = 64, 32
local INSTRUCTIONS_PER_CYCLE = 8

local HEX_FONT: {number}
local INSTRUCTIONS: {[number]: (state: State, opcode: number) -> number?}

local Chip8 = {}

local function cycle(self: CPU, keys: {[number]: boolean}): string?
	local state = self.state
	local memory = state.memory

	for i, down in keys do
		buffer.writeu8(state.key, i, down and 1 or 0)

		local listener = state.listener
		if down and listener then
			state.listener = nil
			buffer.writeu8(state.registry, listener, i)
		end
	end

	for _ = 1, INSTRUCTIONS_PER_CYCLE do
		if state.listener then return nil end
		if state.counter >= 4095 then
			return "program counter out of range"
		end

		local opcode = buffer.readu8(memory, state.counter) * 2^8 + buffer.readu8(memory, state.counter + 1)
		local instruction = INSTRUCTIONS[bit32.band(opcode, 0xF000)]

		if instruction then
			state.counter += 2
			state.counter = instruction(state, opcode) or state.counter
		else
			return string.format("unknown opcode: %04X", opcode)
		end
	end

	if state.delay > 0 then
		state.delay -= 1
	end
	if state.sound > 0 then
		state.sound -= 1
	end

	return nil
end

function Chip8.load(program: buffer): CPU
	assert(buffer.len(program) < 4096 - 0x200, "program too large")

	local memory = buffer.create(4096)
	for i, value in HEX_FONT do
		buffer.writeu8(memory, i - 1, value)
	end

	buffer.copy(memory, 0x200, program)

	return {
		state = {
			yield = false,

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

HEX_FONT = {
	0xF0, 0x90, 0x90, 0x90, 0xF0, -- 0
	0x20, 0x60, 0x20, 0x20, 0x70, -- 1
	0xF0, 0x10, 0xF0, 0x80, 0xF0, -- 2
	0xF0, 0x10, 0xF0, 0x10, 0xF0, -- 3
	0x90, 0x90, 0xF0, 0x10, 0x10, -- 4
	0xF0, 0x80, 0xF0, 0x10, 0xF0, -- 5
	0xF0, 0x80, 0xF0, 0x90, 0xF0, -- 6
	0xF0, 0x10, 0x20, 0x40, 0x40, -- 7
	0xF0, 0x90, 0xF0, 0x90, 0xF0, -- 8
	0xF0, 0x90, 0xF0, 0x10, 0xF0, -- 9
	0xF0, 0x90, 0xF0, 0x90, 0x90, -- A
	0xE0, 0x90, 0xE0, 0x90, 0xE0, -- B
	0xF0, 0x80, 0x80, 0x80, 0xF0, -- C
	0xE0, 0x90, 0x90, 0x90, 0xE0, -- D
	0xF0, 0x80, 0xF0, 0x80, 0xF0, -- E
	0xF0, 0x80, 0xF0, 0x80, 0x80  -- F
}

INSTRUCTIONS = {
	[0x0000] = function(state, opcode)
		-- 0NNN: system instructions
		local address = bit32.band(opcode, 0x0FFF)

		if address == 0x00E0 then
			-- 00E0: clear screen
			buffer.fill(state.screen, 0, 0)
		elseif address == 0x00EE then
			-- 00EE: return from subroutine
			state.pointer -= 2
			return buffer.readu16(state.stack, state.pointer)
		end

		return nil
	end,
	[0x1000] = function(state, opcode)
		-- 1NNN: jump to address NNN
		return bit32.band(opcode, 0x0FFF)
	end,
	[0x2000] = function(state, opcode)
		-- 2NNN: call subroutine at NNN
		local address = bit32.band(opcode, 0x0FFF)
		buffer.writeu16(state.stack, state.pointer, state.counter)
		state.pointer += 2

		return address
	end,
	[0x3000] = function(state, opcode)
		-- 3XNN: skip if VX == NN
		local ox = bit32.band(opcode, 0x0F00) // 2^8
		local value = bit32.band(opcode, 0x00FF)

		local vx = buffer.readu8(state.registry, ox)
		if vx == value then
			return state.counter + 2
		end

		return nil
	end,
	[0x4000] = function(state, opcode)
		-- 4XNN: skip if VX ~= NN
		local ox = bit32.band(opcode, 0x0F00) // 2^8
		local value = bit32.band(opcode, 0x00FF)

		local vx = buffer.readu8(state.registry, ox)
		if vx ~= value then
			return state.counter + 2
		end

		return nil
	end,
	[0x5000] = function(state, opcode)
		-- 5XY0: skip if VX == VY
		local ox = bit32.band(opcode, 0x0F00) // 2^8
		local oy = bit32.band(opcode, 0x00F0) // 2^4

		local vx = buffer.readu8(state.registry, ox)
		local vy = buffer.readu8(state.registry, oy)
		if vx == vy then
			return state.counter + 2
		end

		return nil
	end,
	[0x6000] = function(state, opcode)
		-- 6XNN: VX = NN
		local ox = bit32.band(opcode, 0x0F00) // 2^8
		local value = bit32.band(opcode, 0x00FF)
		buffer.writeu8(state.registry, ox, value)

		return nil
	end,
	[0x7000] = function(state, opcode)
		-- 7XNN: VX += NN
		local ox = bit32.band(opcode, 0x0F00) // 2^8
		local value = bit32.band(opcode, 0x00FF)

		local vx = buffer.readu8(state.registry, ox)
		buffer.writeu8(state.registry, ox, (vx + value) % 0x100)

		return nil
	end,
	[0x8000] = function(state, opcode)
		-- 8XYN: register operations
		local ox = bit32.band(opcode, 0x0F00) // 2^8
		local oy = bit32.band(opcode, 0x00F0) // 2^4
		local op = bit32.band(opcode, 0x000F)

		local vx = buffer.readu8(state.registry, ox)
		local vy = buffer.readu8(state.registry, oy)

		if op == 0x0 then
			-- SET
			buffer.writeu8(state.registry, ox, vy)
		elseif op == 0x1 then
			-- OR
			buffer.writeu8(state.registry, ox, bit32.bor(vx, vy))
		elseif op == 0x2 then
			-- AND
			buffer.writeu8(state.registry, ox, bit32.band(vx, vy))
		elseif op == 0x3 then
			-- XOR
			buffer.writeu8(state.registry, ox, bit32.bxor(vx, vy))
		elseif op == 0x4 then
			-- ADD
			buffer.writeu8(state.registry, 0xF, (vx + vy) > 0xFF and 1 or 0)
			buffer.writeu8(state.registry, ox, (vx + vy) % 0x100)
		elseif op == 0x5 then
			-- SUB
			buffer.writeu8(state.registry, 0xF, vx > vy and 1 or 0)
			buffer.writeu8(state.registry, ox, (vx - vy) % 0x100)
		elseif op == 0x6 then
			-- SHR
			buffer.writeu8(state.registry, 0xF, bit32.band(vx, 0x1))
			buffer.writeu8(state.registry, ox, (vx // 2) % 0x100)
		elseif op == 0x7 then
			-- SUBN
			buffer.writeu8(state.registry, 0xF, vy > vx and 1 or 0)
			buffer.writeu8(state.registry, ox, (vy - vx) % 0x100)
		elseif op == 0xE then
			-- SHL
			buffer.writeu8(state.registry, 0xF, (bit32.band(vx, 0x80) == 0x80) and 1 or 0)
			buffer.writeu8(state.registry, ox, (vx * 2) % 0x100)
		end

		return nil
	end,
	[0x9000] = function(state, opcode)
		-- 9XY0: skip if VX ~= VY
		local ox = bit32.band(opcode, 0x0F00) // 2^8
		local oy = bit32.band(opcode, 0x00F0) // 2^4

		local vx = buffer.readu8(state.registry, ox)
		local vy = buffer.readu8(state.registry, oy)
		if vx ~= vy then
			return state.counter + 2
		end

		return nil
	end,
	[0xA000] = function(state, opcode)
		-- ANNN: I = NNN
		state.index = bit32.band(opcode, 0x0FFF)

		return nil
	end,
	[0xB000] = function(state, opcode)
		-- BNNN: PC = NNN + V0
		return bit32.band(opcode, 0x0FFF) + buffer.readu8(state.registry, 0)
	end,
	[0xC000] = function(state, opcode)
		-- CXNN: VX = random() & NN
		local ox = bit32.band(opcode, 0x0F00) // 2^8
		local value = bit32.band(opcode, 0x00FF)
		buffer.writeu8(state.registry, ox, bit32.band(math.random(0x00, 0xFF), value))

		return nil
	end,
	[0xD000] = function(state, opcode)
		-- DXYN: draw sprite
		local ox = bit32.band(opcode, 0x0F00) // 2^8
		local oy = bit32.band(opcode, 0x00F0) // 2^4
		local height = bit32.band(opcode, 0x000F)

		local vx = buffer.readu8(state.registry, ox)
		local vy = buffer.readu8(state.registry, oy)
		buffer.writeu8(state.registry, 0xF, 0)

		for y = 0, height - 1 do
			local data = buffer.readu8(state.memory, state.index + y)

			for x = 0, 7 do
				if bit32.band(data, bit32.rshift(0x80, x)) ~= 0 then
					local position =
						((vx + x) % WIDTH) +
						((vy + y) % HEIGHT) * WIDTH

					local value = buffer.readu8(state.screen, position)
					if value == 1 then buffer.writeu8(state.registry, 0xF, 1) end

					buffer.writeu8(state.screen, position, bit32.bxor(value, 1))
				end
			end
		end

		return nil
	end,
	[0xE000] = function(state, opcode)
		-- EXNN: key operations
		local ox = bit32.band(opcode, 0x0F00) // 2^8
		local op = bit32.band(opcode, 0x00FF)

		local vx = buffer.readu8(state.registry, ox)
		local down = buffer.readu8(state.key, vx) == 1

		if (op == 0x9E and down) or (op == 0xA1 and not down) then
			return state.counter + 2
		end

		return nil
	end,
	[0xF000] = function(state, opcode)
		-- FXNN: all the damn operations
		local ox = bit32.band(opcode, 0x0F00) // 2^8
		local op = bit32.band(opcode, 0x00FF)

		if op == 0x07 then
			-- VX = delay timer
			buffer.writeu8(state.registry, ox, state.delay)
		elseif op == 0x0A then
			-- wait for key
			state.listener = ox
		elseif op == 0x15 then
			-- delay timer = VX
			state.delay = buffer.readu8(state.registry, ox)
		elseif op == 0x18 then
			-- sound timer = VX
			state.sound = buffer.readu8(state.registry, ox)
		elseif op == 0x1E then
			-- I += VX
			state.index += buffer.readu8(state.registry, ox)
		elseif op == 0x29 then
			-- I = sprite address VX
			state.index += buffer.readu8(state.registry, ox) * 5
		elseif op == 0x33 then
			-- BCD store
			local vx = buffer.readu8(state.registry, ox)

			local ones = (vx // 1) % 10
			local tens = (vx // 10) % 10
			local hundreds = (vx // 100) % 10

			buffer.writeu8(state.memory, state.index, hundreds)
			buffer.writeu8(state.memory, state.index + 1, tens)
			buffer.writeu8(state.memory, state.index + 2, ones)
		elseif op == 0x55 then
			-- store registers to memory
			for i = 0, ox do
				buffer.writeu8(state.memory, state.index + i, buffer.readu8(state.registry, i))
			end
		elseif op == 0x65 then
			-- load registers from memory
			for i = 0, ox do
				buffer.writeu8(state.registry, i, buffer.readu8(state.memory, state.index + i))
			end
		end

		return nil
	end,
}

return Chip8
