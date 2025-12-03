local process = require("@lune/process")
local fs = require("@lune/fs")

local Base64 = require("../place/src/shared/Base64")

local BIN_DIR = "bin"
local ROM_DIR = "rom"
local ROM_TEMP_DIR = `{BIN_DIR}/rom`

local function buildROM()
	for _, filename in fs.readDir(ROM_DIR) do
		local split = filename:split(".")
		if split[2] == "ch8" then
			local data = fs.readFile(`{ROM_DIR}/{filename}`)
			local encoded = Base64.encode(buffer.fromstring(data))
			fs.writeFile(`{ROM_TEMP_DIR}/{split[1]}.txt`, encoded)
		end
	end
end

local function buildPlace()
	fs.writeDir(ROM_TEMP_DIR)
	buildROM()

	local result = process.exec("rojo", {
		"build", "--output", `{BIN_DIR}/CHIP8.rbxl`
	})
	assert(result.ok, result.stderr)

	fs.removeDir(ROM_TEMP_DIR)
end

local clock = os.clock()
buildPlace()

print(string.format("build completed in %.2fs", os.clock() - clock))
