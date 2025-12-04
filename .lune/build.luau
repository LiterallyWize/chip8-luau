local process = require("@lune/process")
local fs = require("@lune/fs")

local Base64 = require("../place/src/shared/Base64")

local BIN_DIR = "bin"
local ROM_DIR = "rom"
local ROM_TEMP_DIR = `{BIN_DIR}/rom`

local function writeROM(filename: string, name: string)
	local ok, data = pcall(fs.readFile, `{ROM_DIR}/{filename}`)
	if not ok then
		print(`- [WARN] failed to read: {filename}`)
	end

	local encoded = Base64.encodeString(data)
	if not pcall(fs.writeFile, `{ROM_TEMP_DIR}/{name}.txt`, encoded) then
		print(`- [WARN] failed to write: {filename}`)
	else
		print(`- build successful: {filename}`)
	end
end

local function buildTargetROM(target: string)
	local split = target:lower():split(".")
	if split[2] ~= "ch8" and not fs.isFile(`{ROM_DIR}/{target}`) then
		target = split[1] .. ".ch8"
	end

	writeROM(target, "TARGET")
end

local function buildAllROM()
	for _, filename in fs.readDir(ROM_DIR) do
		local stem = filename:lower():split(".")[1]
		writeROM(filename, stem)
	end
end

local function buildPlace(target: string?)
	if fs.isDir(ROM_TEMP_DIR) then
		fs.removeDir(ROM_TEMP_DIR)
	end
	fs.writeDir(ROM_TEMP_DIR)

	if target then
		buildTargetROM(target)
	else
		buildAllROM()
	end

	local result = process.exec("rojo", {
		"build", "--output", `{BIN_DIR}/CHIP8.rbxl`
	})
	assert(result.ok, result.stderr)

	fs.removeDir(ROM_TEMP_DIR)
end

local clock = os.clock()
buildPlace(process.args[1])

print(string.format("> build completed in %.2fs\n", os.clock() - clock))
