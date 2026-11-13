local Sunset = loadstring(game:HttpGet("https://raw.githubusercontent.com/ammiaa/SunsetUI/refs/heads/main/src/source.luau"))()
local Notification = Sunset:CreateNotifier()

Sunset:Loader({
	Name = "Sunset",
	Duration = 4,
})

Notification:Notify({
	Title = "Sunset",
	Content = "¡Hola, " .. game.Players.LocalPlayer.DisplayName .. "! Bienvenido de nuevo.",
	Icon = "clipboard",
})

local Window = Sunset.new({
	Name = "Sunset",
	Expire = "never",
})

local Main   = Window:AddMenu({ Name = "MAIN",   Icon = "settings" })
local Look   = Window:AddMenu({ Name = "VISUAL", Icon = "palette" })
local Config = Window:AddMenu({ Name = "CONFIG", Icon = "code" })

do -- MAIN
	local Geral = Main:AddSection({ Position = "left",  Name = "GENERAL" })
	local Extra = Main:AddSection({ Position = "right", Name = "EXTRA" })

	Geral:AddToggle({ Name = "Notificaciones" })
	Geral:AddSlider({ Name = "Volumen", Default = 50, Type = "%" })
	Geral:AddDropdown({
		Name = "Idioma",
		Values = { "Español", "English", "Português" },
		Default = "Español",
	})

	Extra:AddToggle({ Name = "Modo compacto" })
	Extra:AddKeybind({ Name = "Abrir menú" })
	Extra:AddButton({
		Name = "Probar aviso",
		Callback = function()
			Notification:Notify({
				Title = "Prueba",
				Content = "La notificación funcionó.",
				Duration = math.random(3, 7),
				Icon = "info",
			})
		end,
	})
end

do -- VISUAL
	local Cores = Look:AddSection({ Position = "left", Name = "COLORES" })

	Cores:AddToggle({
		Name = "Tema personalizado",
		Option = true,
	}).Option:AddColorPicker({
		Name = "Color principal",
		Default = Color3.fromRGB(255, 122, 61),
	})

	Cores:AddSlider({ Name = "Opacidad", Default = 90, Type = "%" })
	Cores:AddDropdown({
		Name = "Fuente",
		Values = { "Estándar", "Mono", "Redondeada" },
		Default = "Estándar",
	})
end

do -- CONFIG
	local Perfil = Config:AddSection({ Position = "left", Name = "PERFIL" })

	Perfil:AddDropdown({
		Name = "Perfil",
		Values = { "Estándar", "Ligero", "Completo" },
		Default = "Estándar",
	})
	Perfil:AddButton({
		Name = "Guardar perfil",
		Callback = function()
			Notification:Notify({ Title = "Perfil", Content = "Guardado.", Icon = "info" })
		end,
	})
end
