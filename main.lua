--- @since 26.1.22
--- vault.yazi: Manage gocryptfs encrypted vault directly from Yazi

local get_cwd = ya.sync(function()
	return tostring(cx.active.current.cwd)
end)

local function is_mounted(plain_dir)
	local status = Command("mountpoint"):arg("-q"):arg(plain_dir):status()
	return status and status.success or false
end

local function notify(title, content, level)
	ya.notify({
		title = title,
		content = content,
		level = level or "info",
		timeout = 3,
	})
end

local function entry(_, job)
	local home_dir = os.getenv("HOME")
	local cipher_dir = home_dir .. "/.Vault.encrypted"

	-- Backwards compatibility: fallback to Vault.encrypted if .Vault.encrypted doesn't exist
	local test_hidden = Command("test"):arg("-d"):arg(cipher_dir):status()
	if not (test_hidden and test_hidden.success) then
		local old_cipher = home_dir .. "/Vault.encrypted"
		local test_old = Command("test"):arg("-d"):arg(old_cipher):status()
		if test_old and test_old.success then
			cipher_dir = old_cipher
		end
	end

	local plain_dir = home_dir .. "/Vault"
	local mounted = is_mounted(plain_dir)
	local action = (job and job.args and job.args[1]) or "toggle"

	-- If user explicitly asked to "go" or "cd" (e.g. g, V) and it's already mounted:
	if action == "cd" and mounted then
		ya.emit("cd", { plain_dir })
		return
	end

	-- Toggle or Lock
	if mounted and action ~= "open" then
		-- If currently inside the vault, navigate to home first to release mount point
		local current_cwd = get_cwd()
		if current_cwd == plain_dir or current_cwd:sub(1, #plain_dir + 1) == (plain_dir .. "/") then
			ya.emit("cd", { home_dir })
			Command("sleep"):arg("0.1"):status()
		end

		-- Unmount cleanly
		local unmount_status = Command("fusermount"):arg("-u"):arg(plain_dir):status()
		if not unmount_status or not unmount_status.success then
			-- Fallback to lazy unmount if busy
			unmount_status = Command("fusermount"):arg("-u"):arg("-z"):arg(plain_dir):status()
		end

		if unmount_status and unmount_status.success then
			-- Remove the empty mountpoint directory so the vault is 100% invisible when locked
			Command("rmdir"):arg(plain_dir):status()
			notify("Vault", "🔒 Vault locked and unmounted.", "info")
		else
			notify("Vault", "⚠️ Failed to unmount: folder is busy.", "warn")
		end
		return
	end

	-- Unlock / Mount
	if not mounted then
		-- Prompt for password using Yazi's native obscured input
		local password, event = ya.input({
			title = "🔑 Enter Vault Password:",
			obscure = true,
			pos = { "top-center", y = 3, w = 45 },
		})

		if not password or event ~= 1 or password == "" then
			return
		end

		-- Create mountpoint directory before mounting
		Command("mkdir"):arg("-p"):arg(plain_dir):status()

		-- Spawn gocryptfs reading password from stdin via -passfile /dev/stdin
		local child, err = Command("gocryptfs")
			:arg("-passfile")
			:arg("/dev/stdin")
			:arg("-q")
			:arg(cipher_dir)
			:arg(plain_dir)
			:stdin(Command.PIPED)
			:stdout(Command.PIPED)
			:stderr(Command.PIPED)
			:spawn()

		if not child or err then
			notify("Vault", "❌ Failed to run gocryptfs: " .. tostring(err), "error")
			Command("rmdir"):arg(plain_dir):status()
			return
		end

		child:write_all(password .. "\n")
		child:flush()
		local output, wait_err = child:wait_with_output()

		if output and output.status.success then
			notify("Vault", "🔓 Vault unlocked!", "info")
			ya.emit("cd", { plain_dir })
		else
			-- If mount failed, remove empty mount directory so it stays invisible
			Command("rmdir"):arg(plain_dir):status()

			local err_msg = "❌ Incorrect password or mount failed."
			if output and output.stderr and #output.stderr > 0 then
				local err_raw = output.stderr:gsub("\n$", "")
				if err_raw:find("failed to unlock") or err_raw:lower():find("password") then
					err_msg = "❌ Incorrect password."
				else
					err_msg = "❌ " .. err_raw
				end
			elseif wait_err then
				err_msg = "❌ " .. tostring(wait_err)
			end
			notify("Vault", err_msg, "error")
		end
	end
end

return { entry = entry }
