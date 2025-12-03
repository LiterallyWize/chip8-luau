--!strict
--!native
--!optimize 2

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local Base64 = {}

function Base64.encode(input: buffer): string
	local length = buffer.len(input)
	local output: {string} = {}
	local offset = 0

	while offset < length do
		local count = math.min(3, length - offset)
		local groups = math.ceil(count * 8 / 6)

		local value = 0
		for index = 0, count - 1 do
			value = value * 2^8 + buffer.readu8(input, offset + index)
		end

		local width = count * 8
		local text = ""

		for index = 1, groups do
			local shift = width - 6 * index
			local code = 1 + (value // 2^shift) % 2^6
			text ..= ALPHABET:sub(code, code)
		end

		table.insert(output, text)
		offset += count
	end

	return table.concat(output)
end

function Base64.decode(text: string): buffer
	local output = buffer.create(#text * 6 // 8)

	local value = 0
	local bits = 0
	local position = 0

	for index = 1, #text do
		local character = text:sub(index, index)
		local code = ALPHABET:find(character, 1, true)
		if not code then continue end

		code -= 1
		value = value * 2^6 + code
		bits += 6

		while bits >= 8 do
			bits -= 8
			local byte = (value // 2^bits) % 2^8
			value %= 2^bits

			buffer.writeu8(output, position, byte)
			position += 1
		end
	end

	return output
end

return Base64
