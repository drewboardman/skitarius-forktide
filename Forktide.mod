return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Forktide` encountered an error loading the Darktide Mod Framework.")

		new_mod("Forktide", {
			mod_script       = "Forktide/scripts/mods/Forktide/Forktide",
			mod_data         = "Forktide/scripts/mods/Forktide/Forktide_data",
			mod_localization = "Forktide/scripts/mods/Forktide/Forktide_localization",
		})
	end,
	load_after = { "Mark9" },
	packages = {},
}
