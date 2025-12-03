local process = require("@lune/process")
local fs = require("@lune/fs")

local BIN_DIR = "bin"
local PROJECT_PATH = "build/rojo/build.project.json"

local function build(): ()
	fs.writeDir(BIN_DIR)

	local result = process.exec("rojo", {
		"build", PROJECT_PATH, "--output", `{BIN_DIR}/CHIP8.rbxl`
	})
	assert(result.ok, result.stderr)
end

local clock = os.clock()
build()

print(string.format("build completed in %.2fs", os.clock() - clock))
