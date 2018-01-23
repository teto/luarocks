-- rockspec format available at
-- https://github.com/luarocks/luarocks/wiki/Rockspec-format
-- this should be converted to an addon
-- https://github.com/luarocks/luarocks/wiki/Addon-author's-guide
-- needs at least one json library, for instance luaPackages.cjson
local nix = {}
package.loaded["luarocks.nix"] = nix

local pack = require("luarocks.pack")
local path = require("luarocks.path")
local util = require("luarocks.util")
local repos = require("luarocks.repos")
local fetch = require("luarocks.fetch")
local search = require("luarocks.search")
local unpack = require("luarocks.cmd.unpack")
local download = require("luarocks.download")
local fs = require("luarocks.fs")
local dir = require("luarocks.dir")
local deps = require("luarocks.deps")
local manif = require("luarocks.manif")
local remove = require("luarocks.remove")
local cfg = require("luarocks.core.cfg")

-- for json prettyprinting
-- local pretty = require("pl.pretty")

nix.help_summary = "Build/compile a rock."
nix.help_arguments = " {<rockspec>|<rock>|<name> [<version>]}"
nix.help = [[
Just set the package name
]]..util.deps_mode_help()


-- attempts to convert spec.description.license
-- to nix lib/licenses.nix
local function convert2nixLicense(spec)
	-- should parse spec.description.license instead !
	-- local command = "nix-instantiate --eval -E 'with import <nixpkgs> { }; stdenv.lib.licenses."..(spec.description.license)..".shortName'"
	-- local r = io.popen(command)
	-- checksum = r:read()
	-- return "stdenv.lib.licenses.mit"

	-- 
    license = {
      fullName = spec.description.license;
      -- url = http://sales.teamspeakusa.com/licensing.php;
      -- free = false;
	};
end


function get_checksum(rock_file)
	-- TODO download the src.rock unpack it and get the hash around it ?
	local prefetch_url_program = "nix-prefetch-url"

	local command = prefetch_url_program.." "..(rock_file)
	local checksum = nil
	local fetch_method = nil
	local r = io.popen(command)
	checksum = r:read()
	-- local attrSet = {url=(url), sha256=(checksum)}

	return checksum
end

	-- flags = {
	-- 	source= 1
	-- }
    -- -- local rock_filename, msg = download.download("src", name, version, nil)
	-- -- if not rock_filename then
		-- -- print("failure while downloading ? src=", msg)
		-- -- return msg, "failure while downloading ?"
	-- -- end

	-- -- to speed up testing
	-- -- url = "https://luarocks.org/luabitop-1.0.2-1.src.rock"
	-- -- filename = "/home/teto/luarocks/src/luabitop-1.0.2-1.src.rock"
	-- -- local url = msg
	-- -- util.printout("downloading from url ", url)
	-- -- util.printout("got file ", rock_filename)

	-- -- local path, msg = download.command(flags, name, version)

	-- -- to overwrite folders
	-- flags["force"] = 1
	-- -- can get url from rockspec.url maybe ?

	-- -- should work for both
	-- local spec, msg = unpack.command(flags, rock_filename, version)
	-- if not spec then
		-- print("failure while unpacking ?")
		-- return nil, msg
	-- end


-- TODO fetch sources/pack it
local function convert_rockspec2nix(name)
	spec, err, ret = fetch.load_rockspec(name)
end

-- TODO take into account external_dependencies !!
-- @param spec table
-- @param rock_url
-- @param rock_file if nil, will be fetched from url
-- fetch.fetch_sources
-- fetch.fetch_and_unpack_rock(rock_file, dest)
-- @param name lua package name e.g.: 'lpeg', 'mpack' etc
local function convert_spec2nix(spec, rock_url, rock_file)
	assert ( spec )
	assert ( type(rock_url) == "string" )

	if not rock_file then
		--
		print("rock_url")
		return false, "TODO download rock_spec"
	end

	-- deps.parse_dep(dep) is called fetch.load_local_rockspec so 
	-- so we havebuildLuaPackage defined in
	local dependencies = ""
	for id, dep in ipairs(spec.dependencies)
	do
		-- todo can I use a "join" func ?
			-- deps.constraints is a table {op, version}
			dependencies = dependencies.." "..dep.name
		-- print("name; ", id, "dep:", dep.name)
	end

    -- the good thing is zat nix-prefetch-zip caches downloads in the store
	-- todo check constraints to choose the correct version of lua
	-- local src = get_src(spec, url)
	local checksum = get_checksum(rock_file)

   -- todo parse license too
   -- see https://stackoverflow.com/questions/1405583/concatenation-of-strings-in-lua for the best method to concat strings
   -- nixpkgs accept empty/inplace license see
   -- https://github.com/NixOS/nixpkgs/blob/master/pkgs/applications/networking/instant-messengers/teamspeak/client.nix#L104-L108
   -- we could try to map the luarocks licence to nixpkgs license
   -- see convert2nixLicense
	local header = spec.name..[[ = buildLuaPackage rec {
		pname   = ]]..util.LQ(spec.name)..[[;
		version = ]]..spec.version..[[;
		src     = fetchurl {
			url    = ]]..url..[[;
			sha256 = ]]..util.LQ(checksum)..[[;
		};

		propagatedBuildInputs = []]..dependencies..[[];

		meta = {
			homepage = ]]..(spec.description.homepage or spec.source.url)..[[;
			description=]]..util.LQ(spec.description.summary)..[[;
			license = {
				fullName = ]]..(spec.description.license)..[[;
			};
			buildType=]]..util.LQ(spec.build.type)..[[;
		};
	};
	]]
	print(header)
	-- str = str..
	-- print(pretty.write(attrs))
	-- ret, err = fd:write(str)
	local err = false

	-- that's where shit happens
	-- print(pretty.write(str))

	ret = true
	if not ret then
		util.printerr("Error happened: "..err)
		end

	return true
end

--
--
-- @return (spec, url, rock_file)
function load_rock_from_name (name, version)
	local search = require("luarocks.search")

	local query = search.make_query(name, version)
	-- arch can be "src" or "rockspec"
	-- query.arch = "rockspec"
	query.arch = "src"
	local url, search_err = search.find_suitable_rock(query)
	if not url then
		util.printerr("can't find suitable rock " )
		return false, search_err
	end

	print("url=", url)
	-- string or (nil, string, [string]): the directory containing the contents
	-- local archive, dir_name, ret = fetch.get_sources(rockspec, true, nil)

	local rock_file, tmp_dirname, errcode = fetch.fetch_url_at_temp_dir(url, "luarocks-rock-"..name)
	if not rock_file then
		return nil, "Could not fetch rock file: " .. tmp_dirname, errcode
	end

	-- print("tmp_dirname=", tmp_dirname)
	-- local dir_name = tmp_dirname
	local dir_name, err, errcode = fetch.fetch_and_unpack_rock(rock_file, dest)
	if not dir_name then
		return false, err, errcode
	end
	local rockspec_file = path.rockspec_name_from_rock(rock_file)
	return url, rock_file, rockspec_file
end

--- Driver function for "convert2nix" command.
-- we need to have both the rock and the rockspec
-- @param name string: A local or remote rockspec or rock file.
-- If a package name is given, forwards the request to "search" and,
-- if returned a result, installs the matching rock.
-- @param version string: When passing a package name, a version number may
-- also be given.
-- @return boolean or (nil, string, exitcode): True if build was successful; nil and an
-- error message otherwise. exitcode is optionally returned.
function nix.command(flags, name, version)
	if type(name) ~= "string" then
		return nil, "Expects package name as first argument. "..util.see_help("nix")
	end
	local spec, rock_url, rock_file
	local rockspeck_name
	-- assert(type(version) == "string" or not version)

	-- if name:match("%.rockspec$")
	-- 	-- table or (nil, string, [string])
	-- 	local res, err = convert_rockspec2nix(name, version)
	-- else if
	if name:match(".*%.rock")  then
		-- nil = dest
		-- should return path to the rockspec
		-- TODO I would need to find its url !
		local rock_file = name
		local spec, msg = fetch.fetch_and_unpack_rock(rock_file, nil)
		if not spec then
			return false, msg
		end
		rockspeck_name = spec.name
		rockspeck_version = spec.version
		-- unpack_rockspec
		-- return run_unpacker(name, flags["force"])
		-- return convert_spec2nix(spec, name)

	elseif name:match(".*%.rockspec") then
		local spec, err = fetch.load_rockspec(name, nil)
		if not spec then
			return false, err
		end
		print("Loaded locally")
		rockspeck_name = spec.name
		rockspeck_version = spec.version
		-- spec, rock_url, rock_file = load_rock_from_name (spec.name, spec.version)
	else
		-- copied from unpack_rock
		-- ok, err = fs.change_dir(dir_name)
		-- if not ok then return nil, err end
		rockspeck_name = name
		rockspeck_version = version
		-- print("rockspec", rockspec_file)
		-- rockspec_file = dir_name.."/"..rockspec_file
		-- print("rockspec", rockspec_file)

		-- copied from build_rock
		local rockspec_file = path.rockspec_name_from_rock(rock_file)

		spec, err = fetch.load_local_rockspec(rockspec_file, nil)
		if not spec then
			return false, err
		end

	end

	spec, rock_url, rock_file = load_rock_from_name (rockspeck_name, spec.version)

	if not spec
	local res, err = convert_spec2nix(spec, rock_file)
	return true

   -- print("hello world name=", name)
   -- todo should expect a spec + rock file ?
   -- local res, err = convert_rock2nix(name, version)
   return false, res, err

   -- if flags["pack-binary-rock"] then
   --    return pack.pack_binary_rock(name, version, do_build, name, version, deps.get_deps_mode(flags))
   -- else
end


return nix
