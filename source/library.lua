--[[
    SunsetUI  -  UI library free and new)

    O que mudou em relação à original:
      * sem DepthOfField / Part de blur  -> zero custo por frame
      * sem centenas de frames de "pixel de canto" e sem fade recursivo de descendentes
      * nenhum RenderStepped permanente (conexões só existem enquanto você arrasta algo)
      * 1 popup por vez (dropdown / colorpicker), criados só quando usados
      * fonte nativa (GothamSSm) -> sem download de fonte nem asset customizado
      * visual: cantos arredondados, sombra suave, gradiente de destaque, tipografia limpa
]]

local cloneref = cloneref or function(o) return o end
local function Svc(n) return cloneref(game:GetService(n)) end

local UIS          = Svc("UserInputService")
local TweenService = Svc("TweenService")
local Players      = Svc("Players")
local HttpService  = Svc("HttpService")

local LocalPlayer = Players.LocalPlayer
local IsMobile    = UIS.TouchEnabled and not UIS.KeyboardEnabled

--------------------------------------------------------------------------------
-- Estado / tema
--------------------------------------------------------------------------------
local Library = {
    Flags = {}, SetFlags = {}, Connections = {}, Bound = {}, Gradients = {}, Edges = {}, Keybinds = {},
    Folders = { Directory = "NovaUI", Configs = "NovaUI/Configs" },
    Theme = {
        Background     = Color3.fromRGB(12, 12, 16),
        Panel          = Color3.fromRGB(18, 18, 24),
        Element        = Color3.fromRGB(27, 27, 36),
        Outline        = Color3.fromRGB(40, 40, 54),
        Text           = Color3.fromRGB(238, 238, 246),
        SubText        = Color3.fromRGB(148, 148, 168),
        Accent         = Color3.fromRGB(99, 132, 255),
        AccentGradient = Color3.fromRGB(176, 108, 255),
    },
    MenuKey = Enum.KeyCode.Insert,
    UnnamedFlags = 0,
}

local FontPath = "rbxasset://fonts/families/GothamSSm.json"
local Fonts = {
    Regular  = Font.new(FontPath, Enum.FontWeight.Regular),
    Medium   = Font.new(FontPath, Enum.FontWeight.Medium),
    SemiBold = Font.new(FontPath, Enum.FontWeight.SemiBold),
    Bold     = Font.new(FontPath, Enum.FontWeight.Bold),
}
Library.Fonts = Fonts

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function G(t, ...)
    for _, k in ipairs({ ... }) do
        local v = t[k]
        if v ~= nil then return v end
    end
end

local function Bind(o, prop, key)
    o[prop] = Library.Theme[key]
    table.insert(Library.Bound, { o, prop, key })
end

local TEXT = { TextLabel = true, TextButton = true, TextBox = true }

local function New(class, props, children)
    local o = Instance.new(class)
    if o:IsA("GuiObject") then o.BorderSizePixel = 0 end
    if TEXT[class] then
        o.FontFace = Fonts.Medium
        o.TextSize = 13
        o.BackgroundTransparency = 1
        o.TextColor3 = Library.Theme.Text
        if class == "TextButton" then o.AutoButtonColor = false; o.Text = "" end
    elseif class == "ImageLabel" or class == "ImageButton" then
        o.BackgroundTransparency = 1
    elseif class == "ScrollingFrame" then
        o.BackgroundTransparency = 1
        o.ScrollBarThickness = 2
        o.ScrollBarImageColor3 = Library.Theme.Accent
        o.CanvasSize = UDim2.new()
        o.AutomaticCanvasSize = Enum.AutomaticSize.Y
    end
    local parent, theme
    for k, v in pairs(props or {}) do
        if k == "Parent" then parent = v
        elseif k == "Theme" then theme = v
        else o[k] = v end
    end
    if theme then for p, key in pairs(theme) do Bind(o, p, key) end end
    if children then for _, c in ipairs(children) do c.Parent = o end end
    if parent then o.Parent = parent end
    return o
end

local function Corner(p, r)
    return New("UICorner", { CornerRadius = UDim.new(0, r or 6), Parent = p })
end

local function Stroke(p, key, th)
    local s = New("UIStroke", { Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = p })
    Bind(s, "Color", key or "Outline")
    return s
end

local function Pad(p, l, t, r, b)
    return New("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0), PaddingTop = UDim.new(0, t or 0),
        PaddingRight = UDim.new(0, r or l or 0), PaddingBottom = UDim.new(0, b or t or 0),
        Parent = p,
    })
end

local function List(p, pad, dir)
    return New("UIListLayout", {
        Padding = UDim.new(0, pad or 0), SortOrder = Enum.SortOrder.LayoutOrder,
        FillDirection = dir or Enum.FillDirection.Vertical, Parent = p,
    })
end

local function Grad(p, rot)
    local g = New("UIGradient", {
        Rotation = rot or 0,
        Color = ColorSequence.new(Library.Theme.Accent, Library.Theme.AccentGradient),
        Parent = p,
    })
    table.insert(Library.Gradients, g)
    return g
end

-- brilho suave (usa a mesma imagem de sombra, tingida com a cor do tema)
local function Glow(parent, key, extra, transp)
    local g = New("ImageLabel", {
        Image = "rbxassetid://6014261993", ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49, 49, 450, 450),
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, extra or 16, 1, extra or 16),
        ImageTransparency = transp or 0.7, ZIndex = 0, Parent = parent,
    })
    Bind(g, "ImageColor3", key or "Accent")
    return g
end

-- borda com gradiente (acento -> contorno -> acento 2)
local function EdgeSeq()
    local t = Library.Theme
    return ColorSequence.new({
        ColorSequenceKeypoint.new(0, t.Accent), ColorSequenceKeypoint.new(0.4, t.Outline),
        ColorSequenceKeypoint.new(0.65, t.Outline), ColorSequenceKeypoint.new(1, t.AccentGradient),
    })
end

local function EdgeGrad(stroke, rot)
    local g = New("UIGradient", { Rotation = rot or 45, Color = EdgeSeq(), Parent = stroke })
    table.insert(Library.Edges, g)
    return g
end

local function Tw(o, t, goal, style, dir)
    local tw = TweenService:Create(o, TweenInfo.new(t or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
    tw:Play()
    return tw
end

local function Inside(gui, pos)
    local p, s = gui.AbsolutePosition, gui.AbsoluteSize
    return pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
end

-- arrasto: conexões só existem enquanto o botão está pressionado
local function Drag(handle, onMove, onStart, onEnd)
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            if onStart then onStart(i) end
            onMove(i)
            local mv, en
            mv = UIS.InputChanged:Connect(function(m)
                if m.UserInputType == Enum.UserInputType.MouseMovement or m.UserInputType == Enum.UserInputType.Touch then
                    onMove(m)
                end
            end)
            en = UIS.InputEnded:Connect(function(e)
                if e.UserInputType == i.UserInputType then
                    mv:Disconnect(); en:Disconnect()
                    if onEnd then onEnd() end
                end
            end)
        end
    end)
end

local function Chevron(parent, color)
    local c = New("Frame", { Size = UDim2.fromOffset(12, 8), BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Parent = parent })
    for i = 1, 2 do
        local b = New("Frame", {
            Size = UDim2.fromOffset(7, 2), AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0, i == 1 and 3.5 or 8.5, 0.5, 0), Rotation = i == 1 and 45 or -45,
            BackgroundColor3 = color, Parent = c,
        })
        Corner(b, 1)
    end
    return c
end

--------------------------------------------------------------------------------
-- Núcleo
--------------------------------------------------------------------------------
function Library:NextFlag()
    self.UnnamedFlags += 1
    return "flag_" .. self.UnnamedFlags
end

function Library:Connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(self.Connections, c)
    return c
end

function Library:SafeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then warn("[NovaUI] " .. tostring(err)) end
    return ok
end

function Library:ChangeTheme(key, color)
    self.Theme[key] = color
    for _, b in ipairs(self.Bound) do
        if b[3] == key then b[1][b[2]] = color end
    end
    if key == "Accent" or key == "AccentGradient" then
        local seq = ColorSequence.new(self.Theme.Accent, self.Theme.AccentGradient)
        for _, g in ipairs(self.Gradients) do g.Color = seq end
    end
    if key == "Accent" or key == "AccentGradient" or key == "Outline" then
        local es = EdgeSeq()
        for _, g in ipairs(self.Edges) do g.Color = es end
    end
end

Library.Presets = {
    Nova    = { Color3.fromRGB(99, 132, 255),  Color3.fromRGB(176, 108, 255) },
    Sunset  = { Color3.fromRGB(255, 125, 90),  Color3.fromRGB(255, 70, 150) },
    Emerald = { Color3.fromRGB(52, 211, 153),  Color3.fromRGB(56, 189, 248) },
    Amber   = { Color3.fromRGB(251, 191, 36),  Color3.fromRGB(249, 115, 22) },
    Rose    = { Color3.fromRGB(244, 114, 182), Color3.fromRGB(167, 139, 250) },
    Ice     = { Color3.fromRGB(125, 211, 252), Color3.fromRGB(165, 180, 252) },
}
Library.PresetNames = { "Nova", "Sunset", "Emerald", "Amber", "Rose", "Ice" }

function Library:ApplyPreset(name)
    local p = self.Presets[name]
    if not p then return end
    self:ChangeTheme("Accent", p[1])
    self:ChangeTheme("AccentGradient", p[2])
    local a, b = self.SetFlags["AccentColor"], self.SetFlags["AccentGradientColor"]
    if a then a(p[1]) end
    if b then b(p[2]) end
end

-- GUI raiz -------------------------------------------------------------------
local Gui = New("ScreenGui", {
    Name = HttpService:GenerateGUID(false), ResetOnSpawn = false, IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 100,
})
do
    if syn and syn.protect_gui then pcall(syn.protect_gui, Gui) end
    local ok, h = pcall(function() return gethui and gethui() end)
    Gui.Parent = (ok and h) or cloneref(game:GetService("CoreGui"))
end
Library.Gui = Gui

local NotifHolder = New("Frame", {
    Size = UDim2.new(0, 300, 1, -32), Position = UDim2.new(1, -16, 0, 16), AnchorPoint = Vector2.new(1, 0),
    BackgroundTransparency = 1, ZIndex = 90, Parent = Gui,
})
New("UIListLayout", {
    Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right,
    Parent = NotifHolder,
})

local Overlay = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 100, Parent = Gui })
Library.Overlay = Overlay

-- popup com sombra (dropdown / colorpicker)
local function MakePopup(w, h)
    local outer = New("Frame", { Visible = false, Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, Parent = Overlay })
    New("UIScale", { Name = "S", Parent = outer })
    New("ImageLabel", {
        Image = "rbxassetid://6014261993", ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 0.45,
        ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49, 49, 450, 450),
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 4), Size = UDim2.new(1, 36, 1, 36), Parent = outer,
    })
    local panel = New("Frame", { Size = UDim2.fromScale(1, 1), Theme = { BackgroundColor3 = "Panel" }, Parent = outer })
    Corner(panel, 8); Stroke(panel)
    return outer, panel
end

-- popups (um por vez) ----------------------------------------------------------
function Library:ShowPopup(frame, owner, alignRight, onClose)
    self:HidePopup()
    local fw, fh = frame.Size.X.Offset, frame.Size.Y.Offset
    local op, os = owner.AbsolutePosition, owner.AbsoluteSize
    local ov = Overlay.AbsoluteSize
    local x = alignRight and (op.X + os.X - fw) or op.X
    local y = op.Y + os.Y + 6
    x = math.clamp(x, 4, math.max(4, ov.X - fw - 4))
    if y + fh > ov.Y - 4 then y = math.max(4, op.Y - fh - 6) end
    frame.Position = UDim2.fromOffset(x, y)
    frame.Visible = true
    local s = frame:FindFirstChild("S")
    if s then s.Scale = 0.94; Tw(s, 0.15, { Scale = 1 }) end
    self.ActivePopup = { Frame = frame, Owner = owner, OnClose = onClose }
end

function Library:HidePopup()
    local p = self.ActivePopup
    if p then
        self.ActivePopup = nil
        p.Frame.Visible = false
        if p.OnClose then p.OnClose() end
    end
end

-- notificações ---------------------------------------------------------------
local NotifCount = 0
function Library:Notification(Data)
    Data = Data or {}
    local dur = Data.Duration or 4
    NotifCount += 1
    local wrap = New("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = NotifCount, Parent = NotifHolder })
    local card = New("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.new(1.15, 0, 0, 0),
        Theme = { BackgroundColor3 = "Panel" }, Parent = wrap,
    })
    Corner(card, 8); Stroke(card)
    local accent = New("Frame", { Size = UDim2.new(0, 3, 1, -18), Position = UDim2.fromOffset(7, 9), BackgroundColor3 = Color3.new(1, 1, 1), Parent = card })
    Corner(accent, 2); Grad(accent, 90)
    local content = New("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = card })
    Pad(content, 18, 10, 12, 10); List(content, 4)
    New("TextLabel", { Text = Data.Title or "Notification", FontFace = Fonts.SemiBold, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1, Parent = content })
    if (Data.Description or "") ~= "" then
        New("TextLabel", {
            Text = Data.Description, Theme = { TextColor3 = "SubText" }, TextSize = 12, TextWrapped = true,
            Size = UDim2.new(1, 0, 0, 14), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Top, LayoutOrder = 2, Parent = content,
        })
    end
    local bar = New("Frame", { Size = UDim2.new(1, 0, 0, 3), Theme = { BackgroundColor3 = "Element" }, LayoutOrder = 3, Parent = content })
    Corner(bar, 2)
    local fill = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = bar })
    Corner(fill, 2); Grad(fill)
    Tw(card, 0.35, { Position = UDim2.new(0, 0, 0, 0) }, Enum.EasingStyle.Quint)
    Tw(fill, dur, { Size = UDim2.new(0, 0, 1, 0) }, Enum.EasingStyle.Linear)
    task.delay(dur, function()
        Tw(card, 0.3, { Position = UDim2.new(1.15, 0, 0, 0) }, Enum.EasingStyle.Quint)
        task.wait(0.32)
        wrap:Destroy()
    end)
end

-- watermark ------------------------------------------------------------------
function Library:Watermark(items)
    if not self.WatermarkFrame then
        local f = New("Frame", {
            Position = UDim2.fromOffset(16, 16), Size = UDim2.new(0, 0, 0, 28), AutomaticSize = Enum.AutomaticSize.X,
            Visible = false, Theme = { BackgroundColor3 = "Panel" }, Parent = Gui,
        })
        Corner(f, 7); Stroke(f); Pad(f, 12, 0, 12, 0)
        local line = New("Frame", { Size = UDim2.new(1, -14, 0, 2), Position = UDim2.fromOffset(7, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = f })
        Corner(line, 1); Grad(line)
        New("TextLabel", { Name = "L", RichText = true, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextSize = 12, Parent = f })
        local start, spos
        Drag(f, function(i)
            local d = i.Position - start
            f.Position = UDim2.fromOffset(spos.X + d.X, spos.Y + d.Y)
        end, function(i) start = i.Position; spos = Vector2.new(f.Position.X.Offset, f.Position.Y.Offset) end)
        self.WatermarkFrame = f
    end
    if items then
        local sep = '  <font color="rgb(90,90,110)">|</font>  '
        local parts = {}
        for _, v in ipairs(items) do table.insert(parts, tostring(v)) end
        self.WatermarkFrame.L.Text = table.concat(parts, sep)
    end
    return self.WatermarkFrame
end

-- lista de keybinds ------------------------------------------------------------
function Library:KeybindList(Title)
    local KL = {}
    local f = New("Frame", {
        Position = UDim2.new(0, 16, 0.4, 0), Size = UDim2.new(0, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.XY,
        Visible = false, Theme = { BackgroundColor3 = "Panel" }, Parent = Gui,
    })
    Corner(f, 8); Stroke(f); Pad(f, 12, 10, 12, 10); List(f, 4)
    New("UISizeConstraint", { MinSize = Vector2.new(140, 0), Parent = f })
    New("TextLabel", { Text = Title or "Keybinds", FontFace = Fonts.SemiBold, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 0, Parent = f })
    local start, spos
    Drag(f, function(i)
        local d = i.Position - start
        f.Position = UDim2.fromOffset(spos.X + d.X, spos.Y + d.Y)
    end, function(i) start = i.Position; spos = f.AbsolutePosition end)
    local rows = {}
    function KL:SetVisibility(b) f.Visible = b end
    function KL:Refresh()
        for _, r in ipairs(rows) do r:Destroy() end
        rows = {}
        for n, kb in ipairs(Library.Keybinds) do
            if kb.Key and kb.Toggled and kb.ShowInList then
                local k = Library.KeyName(kb.Key)
                local r = New("TextLabel", {
                    Text = kb.Name .. "  [" .. k .. "]", Theme = { TextColor3 = "SubText" }, TextSize = 12,
                    Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = n, Parent = f,
                })
                table.insert(rows, r)
            end
        end
    end
    self.KeyList = KL
    return KL
end

function Library:RefreshKeybindList()
    if self.KeyList then self.KeyList:Refresh() end
end

--------------------------------------------------------------------------------
-- Configs
--------------------------------------------------------------------------------
local function FS() return isfolder and makefolder and writefile and readfile and isfile and listfiles end

if FS() then
    pcall(function()
        for _, p in pairs(Library.Folders) do
            if not isfolder(p) then makefolder(p) end
        end
    end)
end

function Library:GetConfig()
    local cfg = {}
    for flag, v in pairs(self.Flags) do
        if type(v) == "table" then
            if typeof(v.Color) == "Color3" then
                cfg[flag] = { Color = v.Hex, Alpha = v.Alpha }
            elseif v.Type then
                cfg[flag] = { Key = v.Key, Type = v.Type, Mode = v.Mode }
            else
                cfg[flag] = v
            end
        else
            cfg[flag] = v
        end
    end
    return HttpService:JSONEncode(cfg)
end

function Library:LoadConfig(json)
    local ok, data = pcall(HttpService.JSONDecode, HttpService, json)
    if not ok then return false, data end
    for flag, v in pairs(data) do
        local set = self.SetFlags[flag]
        if set then self:SafeCall(set, v) end
    end
    return true
end

function Library:RefreshConfigsList(listbox)
    local list = {}
    if FS() and isfolder(self.Folders.Configs) then
        for _, p in ipairs(listfiles(self.Folders.Configs)) do
            local n = p:match("[^/\\]+$")
            if n and n:sub(-5) == ".json" then table.insert(list, n) end
        end
    end
    if listbox then listbox:Refresh(list) end
end

function Library:Unload()
    for _, c in ipairs(self.Connections) do pcall(function() c:Disconnect() end) end
    self.Connections = {}
    Gui:Destroy()
    self.Unloaded = true
    if getgenv then getgenv().NovaLib = nil end
end

--------------------------------------------------------------------------------
-- Teclas
--------------------------------------------------------------------------------
local KeyAlias = {
    LeftShift = "LShift", RightShift = "RShift", LeftControl = "LCtrl", RightControl = "RCtrl",
    LeftAlt = "LAlt", RightAlt = "RAlt", MouseButton1 = "MB1", MouseButton2 = "MB2", MouseButton3 = "MB3",
    Return = "Enter", Backspace = "Back",
}
function Library.KeyName(k)
    if not k then return "None" end
    return KeyAlias[k.Name] or k.Name
end

local function ResolveKey(v)
    if typeof(v) == "EnumItem" then return v end
    if type(v) == "table" and v.Key and v.Key ~= "None" then
        local enum = v.Type == "UserInputType" and Enum.UserInputType or Enum.KeyCode
        local ok, r = pcall(function() return enum[v.Key] end)
        if ok then return r end
    elseif type(v) == "string" and v ~= "None" then
        local ok, r = pcall(function() return Enum.KeyCode[v] end)
        if ok then return r end
    end
    return nil
end

-- handlers globais (um de cada, para a lib toda)
Library:Connect(UIS.InputBegan, function(input, gp)
    local t = input.UserInputType
    -- fechar popup ao clicar fora
    local p = Library.ActivePopup
    if p and (t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch) then
        if not Inside(p.Frame, input.Position) and not Inside(p.Owner, input.Position) then
            Library:HidePopup()
        end
    end
    if gp or Library.Listening then return end
    if Library.MenuKey and input.KeyCode == Library.MenuKey and Library.CurrentWindow then
        Library.CurrentWindow:SetOpen(not Library.CurrentWindow.IsOpen)
    end
    for _, kb in ipairs(Library.Keybinds) do
        local k = kb.Key
        if k and (input.KeyCode == k or t == k) then
            if kb.Mode == "Toggle" then kb.Toggled = not kb.Toggled
            elseif kb.Mode == "Hold" then kb.Toggled = true
            else kb.Toggled = true end
            kb:Fire()
        end
    end
end)

Library:Connect(UIS.InputEnded, function(input)
    for _, kb in ipairs(Library.Keybinds) do
        local k = kb.Key
        if kb.Mode == "Hold" and k and (input.KeyCode == k or input.UserInputType == k) then
            kb.Toggled = false
            kb:Fire()
        end
    end
end)

Library:Connect(UIS.InputChanged, function(input)
    if input.UserInputType == Enum.UserInputType.MouseWheel then
        local p = Library.ActivePopup
        if p and not Inside(p.Frame, input.Position) then Library:HidePopup() end
    end
end)

--------------------------------------------------------------------------------
-- Componentes reutilizáveis
--------------------------------------------------------------------------------
local function RightBox(row)
    local rb = New("Frame", {
        AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0, 0, 1, 0),
        AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Parent = row,
    })
    New("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = rb,
    })
    return rb
end

local function CreateKeybind(rb, Data)
    local KB = {
        Name = G(Data, "Name", "name") or "Keybind",
        Flag = G(Data, "Flag", "flag") or Library:NextFlag(),
        Mode = G(Data, "Mode", "mode") or "Toggle",
        Callback = G(Data, "Callback", "callback"),
        Changed = G(Data, "Changed", "changed"),
        ShowInList = G(Data, "ShowInList", "showinlist") ~= false,
        Toggled = false,
    }
    local chip = New("TextButton", {
        AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 20), TextSize = 12,
        Theme = { BackgroundColor3 = "Element", TextColor3 = "SubText" }, LayoutOrder = 2, BackgroundTransparency = 0, Parent = rb,
    })
    Corner(chip, 5); Stroke(chip); Pad(chip, 8, 0, 8, 0)

    function KB:Refresh()
        chip.Text = Library.KeyName(self.Key) .. (self.Mode ~= "Toggle" and (" / " .. self.Mode) or "")
    end
    function KB:Sync()
        Library.Flags[self.Flag] = {
            Key = self.Key and self.Key.Name or "None",
            Type = self.Key and (self.Key.EnumType == Enum.KeyCode and "KeyCode" or "UserInputType") or "KeyCode",
            Mode = self.Mode, Toggled = self.Toggled,
        }
    end
    function KB:Fire()
        self:Sync()
        if self.Callback then Library:SafeCall(self.Callback, self.Toggled) end
        Library:RefreshKeybindList()
    end
    function KB:SetMode(m)
        self.Mode = m
        self.Toggled = (m == "Always")
        self:Refresh()
        if m == "Always" then self:Fire() else self:Sync(); Library:RefreshKeybindList() end
    end
    function KB:Set(v, silent)
        if type(v) == "table" and v.Mode and (v.Mode == "Toggle" or v.Mode == "Hold" or v.Mode == "Always") then
            self.Mode = v.Mode
        end
        self.Key = ResolveKey(v)
        self:Refresh(); self:Sync(); Library:RefreshKeybindList()
        if self.Changed and not silent then Library:SafeCall(self.Changed, self.Key) end
    end
    function KB:Get() return self.Key, self.Mode, self.Toggled end

    chip.MouseButton1Click:Connect(function()
        if Library.Listening then return end
        Library.Listening = KB
        chip.Text = "..."
        local conn
        conn = UIS.InputBegan:Connect(function(i)
            local t = i.UserInputType
            if t == Enum.UserInputType.Keyboard then
                if i.KeyCode == Enum.KeyCode.Backspace or i.KeyCode == Enum.KeyCode.Escape then KB:Set(nil) else KB:Set(i.KeyCode) end
            elseif t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.MouseButton2 or t == Enum.UserInputType.MouseButton3 then
                KB:Set(t)
            else
                return
            end
            conn:Disconnect()
            task.defer(function() Library.Listening = nil end)
        end)
    end)
    chip.MouseButton2Click:Connect(function()
        local order = { Toggle = "Hold", Hold = "Always", Always = "Toggle" }
        KB:SetMode(order[KB.Mode] or "Toggle")
    end)

    table.insert(Library.Keybinds, KB)
    KB:Set(G(Data, "Default", "default"), true)
    KB.Mode = KB.Mode
    KB:Refresh()
    Library.SetFlags[KB.Flag] = function(v) KB:Set(v) end
    return KB
end

local function CreateColorpicker(rb, Data)
    local CP = {
        Flag = G(Data, "Flag", "flag") or Library:NextFlag(),
        Callback = G(Data, "Callback", "callback") or function() end,
        H = 0, S = 0, V = 1, A = 1,
    }
    local alphaOpt = G(Data, "Alpha", "alpha")
    CP.UseAlpha = (alphaOpt == true) or type(alphaOpt) == "number"

    local chip = New("TextButton", { Size = UDim2.fromOffset(26, 16), BackgroundTransparency = 0, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = 1, Parent = rb })
    Corner(chip, 5); Stroke(chip)

    local ui
    local function Build()
        ui = {}
        local hexY = CP.UseAlpha and 176 or 158
        local outer, frame = MakePopup(210, hexY + 24 + 10)
        ui.frame = outer

        local pal = New("Frame", { Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(190, 120), BackgroundColor3 = Color3.new(1, 0, 0), Parent = frame })
        Corner(pal, 5)
        local sat = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = pal })
        Corner(sat, 5); New("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = sat })
        local val = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Parent = pal })
        Corner(val, 5); New("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = val })
        local cursor = New("Frame", { Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Parent = pal })
        Corner(cursor, 99); New("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Parent = cursor })
        local phit = New("TextButton", { Size = UDim2.fromScale(1, 1), Parent = pal })
        ui.pal, ui.cursor = pal, cursor
        Drag(phit, function(i)
            local p, s = pal.AbsolutePosition, pal.AbsoluteSize
            CP.S = math.clamp((i.Position.X - p.X) / s.X, 0, 1)
            CP.V = 1 - math.clamp((i.Position.Y - p.Y) / s.Y, 0, 1)
            CP:Refresh()
        end)

        local function Bar(y)
            local b = New("Frame", { Position = UDim2.fromOffset(10, y), Size = UDim2.fromOffset(190, 10), BackgroundColor3 = Color3.new(1, 1, 1), Parent = frame })
            Corner(b, 99)
            local k = New("Frame", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), Parent = b })
            Corner(k, 99); New("UIStroke", { Color = Color3.fromRGB(20, 20, 26), Thickness = 2, Parent = k })
            local hit = New("TextButton", { Size = UDim2.new(1, 0, 1, 8), Position = UDim2.fromOffset(0, -4), Parent = b })
            return b, k, hit
        end

        local hue, hueK, hueHit = Bar(140)
        New("UIGradient", {
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)), ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
                ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)), ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
                ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)), ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
            }), Parent = hue,
        })
        ui.hueK = hueK
        Drag(hueHit, function(i)
            CP.H = math.clamp((i.Position.X - hue.AbsolutePosition.X) / hue.AbsoluteSize.X, 0, 1)
            CP:Refresh()
        end)

        if CP.UseAlpha then
            local al, alK, alHit = Bar(158)
            New("UIGradient", { Transparency = NumberSequence.new(1, 0), Parent = al })
            ui.alpha, ui.alphaK = al, alK
            Drag(alHit, function(i)
                CP.A = math.clamp((i.Position.X - al.AbsolutePosition.X) / al.AbsoluteSize.X, 0, 1)
                CP:Refresh()
            end)
        end

        local hex = New("TextBox", {
            Position = UDim2.fromOffset(10, hexY), Size = UDim2.fromOffset(190, 24), BackgroundTransparency = 0, ClearTextOnFocus = false,
            Theme = { BackgroundColor3 = "Element" }, TextSize = 12, Parent = frame,
        })
        Corner(hex, 6); Stroke(hex)
        ui.hex = hex
        hex.FocusLost:Connect(function() CP:Set(hex.Text, nil) end)
    end

    function CP:Color() return Color3.fromHSV(self.H, self.S, self.V) end

    function CP:Refresh(silent)
        local c = self:Color()
        chip.BackgroundColor3 = c
        Library.Flags[self.Flag] = { Color = c, Alpha = self.A, Hex = c:ToHex() }
        if ui then
            ui.pal.BackgroundColor3 = Color3.fromHSV(self.H, 1, 1)
            ui.cursor.Position = UDim2.fromScale(self.S, 1 - self.V)
            ui.hueK.Position = UDim2.fromScale(self.H, 0.5)
            ui.hex.Text = "#" .. c:ToHex():upper()
            if ui.alpha then
                ui.alpha.BackgroundColor3 = c
                ui.alphaK.Position = UDim2.fromScale(self.A, 0.5)
            end
        end
        if not silent then Library:SafeCall(self.Callback, c, self.A) end
    end

    function CP:Set(c, a, silent)
        if type(c) == "string" then
            local ok, r = pcall(Color3.fromHex, c)
            if not ok then self:Refresh(true); return end
            c = r
        elseif type(c) == "table" then
            c = Color3.fromRGB(c[1], c[2], c[3])
        end
        if typeof(c) ~= "Color3" then return end
        self.H, self.S, self.V = c:ToHSV()
        if a ~= nil then self.A = a end
        self:Refresh(silent)
    end
    function CP:Get() return self:Color(), self.A end

    chip.MouseButton1Click:Connect(function()
        if not ui then Build() end
        if Library.ActivePopup and Library.ActivePopup.Frame == ui.frame then
            Library:HidePopup()
        else
            CP:Refresh(true)
            Library:ShowPopup(ui.frame, chip, true)
        end
    end)

    CP:Set(G(Data, "Default", "default") or Color3.new(1, 1, 1), type(alphaOpt) == "number" and alphaOpt or 1)
    Library.SetFlags[CP.Flag] = function(v)
        if type(v) == "table" and v.Color then CP:Set(v.Color, v.Alpha) else CP:Set(v) end
    end
    return CP
end

-- lista de opções (dropdown / listbox) -----------------------------------------
local function OptionList(scroll, multi, onChange)
    local L = { Options = {}, Order = {}, Value = multi and {} or nil }

    function L:Paint(o)
        local on = o.Selected
        Tw(o.Button, 0.12, { BackgroundTransparency = on and 0.85 or 1 })
        Tw(o.Label, 0.12, { TextColor3 = on and Library.Theme.Text or Library.Theme.SubText })
    end

    function L:Add(name)
        name = tostring(name)
        if self.Options[name] then return end
        local btn = New("TextButton", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = #self.Order + 1, Theme = { BackgroundColor3 = "Accent" }, Parent = scroll })
        Corner(btn, 5)
        local lbl = New("TextLabel", {
            Text = name, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, Theme = { TextColor3 = "SubText" }, Parent = btn,
        })
        local o = { Name = name, Button = btn, Label = lbl, Selected = false }
        self.Options[name] = o
        table.insert(self.Order, name)
        btn.MouseButton1Click:Connect(function()
            if multi then
                local list = {}
                for _, n in ipairs(self.Order) do
                    local sel = self.Options[n].Selected
                    if n == name then sel = not sel end
                    if sel then table.insert(list, n) end
                end
                self:Set(list)
            else
                self:Set(name)
            end
            if self.OnPick then self.OnPick() end
        end)
        return o
    end

    function L:Set(v, silent)
        if multi then
            if type(v) ~= "table" then v = (v ~= nil) and { v } or {} end
            local want = {}
            for _, n in ipairs(v) do want[tostring(n)] = true end
            self.Value = {}
            for _, n in ipairs(self.Order) do
                local o = self.Options[n]
                o.Selected = want[n] == true
                if o.Selected then table.insert(self.Value, n) end
                self:Paint(o)
            end
        else
            if v ~= nil then
                v = tostring(v)
                if not self.Options[v] then return end
            end
            self.Value = v
            for n, o in pairs(self.Options) do o.Selected = (n == v); self:Paint(o) end
        end
        if onChange then onChange(self.Value, silent) end
    end

    function L:Clear()
        for _, o in pairs(self.Options) do o.Button:Destroy() end
        self.Options, self.Order = {}, {}
        self.Value = multi and {} or nil
    end

    function L:Filter(text)
        text = string.lower(text or "")
        for _, o in pairs(self.Options) do
            o.Button.Visible = text == "" or string.find(string.lower(o.Name), text, 1, true) ~= nil
        end
    end

    return L
end

--------------------------------------------------------------------------------
-- Classes
--------------------------------------------------------------------------------
local WindowClass  = {}; WindowClass.__index  = WindowClass
local PageClass    = {}; PageClass.__index    = PageClass
local SectionClass = {}; SectionClass.__index = SectionClass

local function Row(sec, h)
    return New("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 1, Parent = sec.Content })
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------
function Library:Window(Data)
    Data = Data or {}
    local W = setmetatable({
        Name = G(Data, "Name", "name") or "NovaUI",
        SubName = G(Data, "SubName", "subname") or "",
        Logo = G(Data, "Logo", "logo"),
        Pages = {}, IsOpen = true,
    }, WindowClass)
    Library.CurrentWindow = W

    local size = G(Data, "Size", "size") or (IsMobile and Vector2.new(540, 380) or Vector2.new(660, 460))
    local Root = New("Frame", {
        Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(size.X, size.Y), BackgroundTransparency = 1, Parent = Gui,
    })
    local Scale = New("UIScale", { Parent = Root })
    W.Root, W.Scale = Root, Scale

    New("ImageLabel", {
        Image = "rbxassetid://6014261993", ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 0.55,
        ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49, 49, 450, 450),
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 6), Size = UDim2.new(1, 56, 1, 56), Parent = Root,
    })

    -- halo colorido atrás da janela
    local halo = New("ImageLabel", {
        Image = "rbxassetid://6014261993", ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49, 49, 450, 450),
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 34, 1, 34),
        ImageTransparency = 0.86, Parent = Root,
    })
    Bind(halo, "ImageColor3", "Accent")

    local Main = New("Frame", { Size = UDim2.fromScale(1, 1), Theme = { BackgroundColor3 = "Background" }, Parent = Root })
    Corner(Main, 10)
    New("UIGradient", { Rotation = 115, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 220)), Parent = Main })
    local mainStroke = New("UIStroke", { Thickness = 1.2, Color = Color3.new(1, 1, 1), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = Main })
    EdgeGrad(mainStroke, 45)

    -- manchas de luz no fundo
    local function Blob(key, anchor, pos, w, h, tr)
        local b = New("ImageLabel", {
            Image = "rbxassetid://6014261993", ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49, 49, 450, 450),
            AnchorPoint = anchor, Position = pos, Size = UDim2.fromOffset(w, h), ImageTransparency = tr, Parent = Main,
        })
        Bind(b, "ImageColor3", key)
    end
    Blob("Accent", Vector2.new(0, 0), UDim2.fromOffset(0, 0), 380, 260, 0.9)
    Blob("AccentGradient", Vector2.new(1, 1), UDim2.new(1, 0, 1, 0), 340, 240, 0.92)

    local topLine = New("Frame", { Size = UDim2.new(1, -24, 0, 2), Position = UDim2.fromOffset(12, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = Main })
    Corner(topLine, 1); Grad(topLine)

    -- topo
    local Top = New("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Parent = Main })
    local tx = 16
    if W.Logo then
        New("ImageLabel", { Image = "rbxassetid://" .. tostring(W.Logo), Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(14, 13), Parent = Top })
        tx = 48
    end
    local titleLbl = New("TextLabel", { Text = W.Name, FontFace = Fonts.Bold, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(tx, 9), Size = UDim2.new(0.5, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Parent = Top })
    Grad(titleLbl, 0)
    New("TextLabel", { Text = W.SubName, TextSize = 11, Theme = { TextColor3 = "SubText" }, Position = UDim2.fromOffset(tx, 28), Size = UDim2.new(0.5, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, Parent = Top })

    local function TopButton(xoff, glyph)
        local b = New("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, xoff, 0.5, 0), Size = UDim2.fromOffset(28, 28),
            BackgroundTransparency = 1, Theme = { BackgroundColor3 = "Element" }, Parent = Top,
        })
        Corner(b, 7)
        local function Bar(rot, w)
            local f = New("Frame", {
                Size = UDim2.fromOffset(w, 2), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
                Rotation = rot, Theme = { BackgroundColor3 = "SubText" }, Parent = b,
            })
            Corner(f, 1)
        end
        if glyph == "x" then Bar(45, 12); Bar(-45, 12) else Bar(0, 11) end
        local red = glyph == "x"
        b.MouseEnter:Connect(function()
            if red then Tw(b, 0.12, { BackgroundTransparency = 0.7, BackgroundColor3 = Color3.fromRGB(255, 70, 90) })
            else Tw(b, 0.12, { BackgroundTransparency = 0 }) end
        end)
        b.MouseLeave:Connect(function() Tw(b, 0.12, { BackgroundTransparency = 1 }) end)
        return b
    end
    TopButton(-12, "x").MouseButton1Click:Connect(function() Library:Unload() end)
    TopButton(-44, "-").MouseButton1Click:Connect(function() W:SetOpen(false) end)

    local dragStart, startPos
    Drag(Top, function(i)
        local d = i.Position - dragStart
        Root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end, function(i) dragStart = i.Position; startPos = Root.Position end)

    New("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 52), Theme = { BackgroundColor3 = "Outline" }, Parent = Main })

    -- corpo
    local Body = New("Frame", { Position = UDim2.fromOffset(0, 53), Size = UDim2.new(1, 0, 1, -53), BackgroundTransparency = 1, Parent = Main })
    local Sidebar = New("Frame", { Size = UDim2.new(0, 170, 1, 0), BackgroundTransparency = 1, Parent = Body })
    New("Frame", { Position = UDim2.fromOffset(170, 0), Size = UDim2.new(0, 1, 1, 0), Theme = { BackgroundColor3 = "Outline" }, Parent = Body })

    local Tabs = New("ScrollingFrame", { Size = UDim2.new(1, 0, 1, -64), ScrollBarThickness = 0, Parent = Sidebar })
    Pad(Tabs, 10, 10, 10, 6); List(Tabs, 4)
    W.Tabs = Tabs

    -- chip do usuário
    local user = New("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10), Size = UDim2.new(1, -20, 0, 44), Theme = { BackgroundColor3 = "Panel" }, Parent = Sidebar })
    Corner(user, 8); Stroke(user)
    local avatar = New("ImageLabel", { Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(8, 7), Theme = { BackgroundColor3 = "Element" }, BackgroundTransparency = 0, Parent = user })
    Corner(avatar, 99)
    local online = New("Frame", { Size = UDim2.fromOffset(9, 9), AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 1, 1, 1), BackgroundColor3 = Color3.fromRGB(70, 220, 120), Parent = avatar })
    Corner(online, 99); New("UIStroke", { Thickness = 2, Color = Library.Theme.Panel, Parent = online })
    New("TextLabel", { Text = LocalPlayer.DisplayName, FontFace = Fonts.SemiBold, TextSize = 12, Position = UDim2.fromOffset(46, 6), Size = UDim2.new(1, -52, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = user })
    New("TextLabel", { Text = "@" .. LocalPlayer.Name, TextSize = 11, Theme = { TextColor3 = "SubText" }, Position = UDim2.fromOffset(46, 22), Size = UDim2.new(1, -52, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = user })
    task.spawn(function()
        local ok, img = pcall(Players.GetUserThumbnailAsync, Players, LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
        if ok and avatar.Parent then avatar.Image = img end
    end)

    W.Content = New("Frame", { Position = UDim2.fromOffset(171, 0), Size = UDim2.new(1, -171, 1, 0), BackgroundTransparency = 1, ClipsDescendants = true, Parent = Body })

    -- redimensionar
    local grip = New("TextButton", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -2, 1, -2), Size = UDim2.fromOffset(16, 16), ZIndex = 5, Parent = Main })
    for i, w in ipairs({ 10, 5 }) do
        New("Frame", {
            Size = UDim2.fromOffset(w, 1), AnchorPoint = Vector2.new(1, 1), Rotation = -45,
            Position = UDim2.new(1, -2 - (i == 2 and 0 or 0), 1, -4 - (i - 1) * 0), Theme = { BackgroundColor3 = "Outline" }, ZIndex = 5, Parent = grip,
        })
    end
    local rs, rsize, rpos
    Drag(grip, function(i)
        local d = i.Position - rs
        local nx = math.max(520, rsize.X + d.X)
        local ny = math.max(360, rsize.Y + d.Y)
        Root.Size = UDim2.fromOffset(nx, ny)
        Root.Position = UDim2.new(rpos.X.Scale, rpos.X.Offset + (nx - rsize.X) / 2, rpos.Y.Scale, rpos.Y.Offset + (ny - rsize.Y) / 2)
    end, function(i)
        rs = i.Position; rsize = Vector2.new(Root.Size.X.Offset, Root.Size.Y.Offset); rpos = Root.Position
    end)

    -- botão flutuante (mobile)
    if IsMobile then
        local fb = New("TextButton", {
            AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(44, 44),
            BackgroundTransparency = 0, Theme = { BackgroundColor3 = "Panel" }, Text = string.sub(W.Name, 1, 1), FontFace = Fonts.Bold, TextSize = 18, Parent = Gui,
        })
        Corner(fb, 99); Stroke(fb)
        fb.MouseButton1Click:Connect(function() W:SetOpen(not W.IsOpen) end)
    end

    return W
end

function WindowClass:SetOpen(b)
    self.IsOpen = b
    Library:HidePopup()
    if b then
        self.Root.Visible = true
        self.Scale.Scale = 0.94
        Tw(self.Scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Quint)
    else
        Tw(self.Scale, 0.15, { Scale = 0.94 })
        task.delay(0.15, function()
            if not self.IsOpen then self.Root.Visible = false end
        end)
    end
end

function WindowClass:Category(name)
    New("TextLabel", {
        Text = string.upper(name), TextSize = 10, FontFace = Fonts.Bold, Theme = { TextColor3 = "SubText" },
        Size = UDim2.new(1, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = #self.Pages + 1, Parent = self.Tabs,
    })
end

function WindowClass:Select(page)
    for _, p in ipairs(self.Pages) do
        local on = p == page
        if on and not p.Active then
            p.Frame.Position = UDim2.fromOffset(0, 14)
            Tw(p.Frame, 0.3, { Position = UDim2.new() }, Enum.EasingStyle.Quint)
        end
        p.Frame.Visible = on
        p.Active = on
        Tw(p.Tab, 0.18, { BackgroundTransparency = on and 0 or 1 })
        Tw(p.TabText, 0.18, { TextColor3 = on and Library.Theme.Text or Library.Theme.SubText })
        Tw(p.Indicator, 0.18, { BackgroundTransparency = on and 0 or 1 })
        if p.TabIcon then Tw(p.TabIcon, 0.18, { ImageColor3 = on and Library.Theme.Accent or Library.Theme.SubText }) end
    end
    Library:HidePopup()
end

function WindowClass:Init() end
function WindowClass:SetCenter() self.Root.Position = UDim2.fromScale(0.5, 0.5) end

--------------------------------------------------------------------------------
-- Page
--------------------------------------------------------------------------------
function WindowClass:Page(Data)
    Data = Data or {}
    local P = setmetatable({
        Window = self, Name = G(Data, "Name", "name") or "Page", Columns = G(Data, "Columns", "columns") or 2,
        Sections = {}, ColumnFrames = {}, Active = false,
    }, PageClass)
    local icon = G(Data, "Icon", "icon")

    local tab = New("TextButton", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, BackgroundColor3 = Color3.new(1, 1, 1), LayoutOrder = #self.Pages + 1, Parent = self.Tabs })
    Corner(tab, 8)
    local tabGrad = Grad(tab, 0)
    tabGrad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.72), NumberSequenceKeypoint.new(1, 1) })
    local ind = New("Frame", { Size = UDim2.fromOffset(3, 16), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), BackgroundTransparency = 1, BackgroundColor3 = Color3.new(1, 1, 1), Parent = tab })
    Corner(ind, 2); Grad(ind, 90)
    local tx = 14
    if icon then
        P.TabIcon = New("ImageLabel", { Image = "rbxassetid://" .. tostring(icon), Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), ImageColor3 = Library.Theme.SubText, Parent = tab })
        tx = 36
    end
    P.TabText = New("TextLabel", { Text = P.Name, FontFace = Fonts.SemiBold, Position = UDim2.fromOffset(tx, 0), Size = UDim2.new(1, -tx, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Theme = { TextColor3 = "SubText" }, Parent = tab })
    P.Tab, P.Indicator = tab, ind

    tab.MouseEnter:Connect(function() if not P.Active then Tw(P.TabText, 0.12, { TextColor3 = Library.Theme.Text }) end end)
    tab.MouseLeave:Connect(function() if not P.Active then Tw(P.TabText, 0.12, { TextColor3 = Library.Theme.SubText }) end end)
    tab.MouseButton1Click:Connect(function() self:Select(P) end)

    P.Frame = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = self.Content })
    New("TextLabel", { Text = P.Name, FontFace = Fonts.Bold, TextSize = 18, Position = UDim2.fromOffset(22, 12), Size = UDim2.new(0.7, 0, 0, 22), TextXAlignment = Enum.TextXAlignment.Left, Parent = P.Frame })
    local desc = G(Data, "Description", "description")
    if desc then
        New("TextLabel", { Text = desc, TextSize = 12, Theme = { TextColor3 = "SubText" }, Position = UDim2.fromOffset(22, 34), Size = UDim2.new(0.8, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, Parent = P.Frame })
    end
    local top = desc and 58 or 46
    P.Cols = New("Frame", { Position = UDim2.fromOffset(0, top), Size = UDim2.new(1, 0, 1, -top), BackgroundTransparency = 1, Parent = P.Frame })
    Pad(P.Cols, 12, 0, 12, 12)
    New("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = P.Cols })
    local n = P.Columns
    for i = 1, n do
        local col = New("ScrollingFrame", {
            Size = UDim2.new(1 / n, -(10 * (n - 1)) / n, 1, 0), LayoutOrder = i, Parent = P.Cols,
        })
        List(col, 10); Pad(col, 0, 0, 4, 0)
        P.ColumnFrames[i] = col
    end

    table.insert(self.Pages, P)
    if #self.Pages == 1 then self:Select(P) end
    return P
end

--------------------------------------------------------------------------------
-- Section
--------------------------------------------------------------------------------
function PageClass:Section(Data)
    Data = Data or {}
    local S = setmetatable({
        Window = self.Window, Page = self,
        Name = G(Data, "Name", "name") or "Section",
        Description = G(Data, "Description", "description") or "",
        Enabled = true,
    }, SectionClass)
    local side = math.clamp(G(Data, "Side", "side") or 1, 1, self.Columns)
    local enableToggle = G(Data, "EnableToggle", "enabletoggle") or false

    local frame = New("Frame", { Size = UDim2.new(1, 0, 0, 36), AutomaticSize = Enum.AutomaticSize.Y, Theme = { BackgroundColor3 = "Panel" }, LayoutOrder = #self.Sections + 1, Parent = self.ColumnFrames[side] })
    Corner(frame, 8); Stroke(frame)
    New("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 228)), Parent = frame })

    local header = New("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, Parent = frame })
    local dot = New("Frame", { Size = UDim2.fromOffset(4, 14), Position = UDim2.fromOffset(12, 11), BackgroundColor3 = Color3.new(1, 1, 1), Parent = header })
    Corner(dot, 2); Grad(dot, 90); Glow(dot, "Accent", 18, 0.6)
    New("TextLabel", { Text = S.Name, FontFace = Fonts.SemiBold, Position = UDim2.fromOffset(26, 0), Size = UDim2.new(0.6, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
    if S.Description ~= "" then
        New("TextLabel", { Text = S.Description, TextSize = 11, Theme = { TextColor3 = "SubText" }, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, enableToggle and -54 or -12, 0, 0), Size = UDim2.new(0.4, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Parent = header })
    end
    local dv = New("Frame", { Size = UDim2.new(1, -20, 0, 1), Position = UDim2.fromOffset(10, 35), BackgroundColor3 = Color3.new(1, 1, 1), Parent = header })
    Grad(dv, 0).Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.6, 0.85), NumberSequenceKeypoint.new(1, 1) })

    S.Content = New("Frame", { Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = frame })
    List(S.Content, 6); Pad(S.Content, 12, 10, 12, 12)

    if enableToggle then
        local overlay = New("TextButton", { Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 1, -36), BackgroundTransparency = 0.35, Theme = { BackgroundColor3 = "Panel" }, Visible = false, Active = true, Parent = frame })
        local sw = New("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(34, 18), Theme = { BackgroundColor3 = "Element" }, BackgroundTransparency = 0, Parent = header })
        Corner(sw, 9); Stroke(sw)
        local fill = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = sw })
        Corner(fill, 9); Grad(fill)
        local knob = New("Frame", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -15, 0.5, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = sw })
        Corner(knob, 99)
        sw.MouseButton1Click:Connect(function()
            S.Enabled = not S.Enabled
            overlay.Visible = not S.Enabled
            Tw(fill, 0.18, { BackgroundTransparency = S.Enabled and 0 or 1 })
            Tw(knob, 0.18, { Position = S.Enabled and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = S.Enabled and Color3.new(1, 1, 1) or Library.Theme.SubText })
        end)
    end

    self.Sections[#self.Sections + 1] = S
    return S
end

--------------------------------------------------------------------------------
-- Elementos
--------------------------------------------------------------------------------
function SectionClass:Divider()
    New("Frame", { Size = UDim2.new(1, 0, 0, 1), Theme = { BackgroundColor3 = "Outline" }, Parent = self.Content })
end

function SectionClass:Label(text)
    local L = {}
    local row = New("Frame", { Size = UDim2.new(1, 0, 0, 22), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = self.Content })
    local lbl = New("TextLabel", {
        Text = tostring(text or "Label"), TextWrapped = true, Size = UDim2.new(1, 0, 0, 22), AutomaticSize = Enum.AutomaticSize.Y,
        TextXAlignment = Enum.TextXAlignment.Left, Theme = { TextColor3 = "SubText" }, Parent = row,
    })
    local function EnsureRB()
        if not L.RB then
            L.RB = RightBox(row)
            lbl.Size = UDim2.new(1, -90, 0, 22)
        end
        return L.RB
    end
    function L:SetText(t) lbl.Text = tostring(t) end
    function L:SetVisibility(b) row.Visible = b end
    function L:Colorpicker(Data) return CreateColorpicker(EnsureRB(), Data or {}) end
    function L:Keybind(Data) Data = Data or {}; Data.Name = Data.Name or lbl.Text; return CreateKeybind(EnsureRB(), Data) end
    return L
end

function SectionClass:Colorpicker(Data)
    Data = Data or {}
    local l = self:Label(G(Data, "Name", "name") or "Color")
    return l:Colorpicker(Data)
end

function SectionClass:Keybind(Data)
    Data = Data or {}
    local l = self:Label(G(Data, "Name", "name") or "Keybind")
    return l:Keybind(Data)
end

function SectionClass:Toggle(Data)
    Data = Data or {}
    local T = {
        Name = G(Data, "Name", "name") or "Toggle", Flag = G(Data, "Flag", "flag") or Library:NextFlag(),
        Callback = G(Data, "Callback", "callback") or function() end, Value = false,
    }
    local row = Row(self, 28)
    local hit = New("TextButton", { Size = UDim2.fromScale(1, 1), Parent = row })
    local label = New("TextLabel", { Text = T.Name, Size = UDim2.new(1, -60, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Theme = { TextColor3 = "SubText" }, Parent = row })
    local rb = RightBox(row)
    T.RightBox = rb
    local sw = New("Frame", { Size = UDim2.fromOffset(34, 18), BackgroundTransparency = 0, Theme = { BackgroundColor3 = "Element" }, LayoutOrder = 100, Parent = rb })
    Corner(sw, 9); Stroke(sw)
    local swGlow = Glow(sw, "Accent", 18, 1)
    local fill = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Parent = sw })
    Corner(fill, 9); Grad(fill)
    local knob = New("Frame", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = Library.Theme.SubText, Parent = sw })
    Corner(knob, 99)

    function T:Set(v, silent)
        v = v and true or false
        self.Value = v
        Library.Flags[self.Flag] = v
        Tw(fill, 0.18, { BackgroundTransparency = v and 0 or 1 })
        Tw(knob, 0.18, { Position = v and UDim2.new(1, -15, 0.5, 0) or UDim2.new(0, 3, 0.5, 0), BackgroundColor3 = v and Color3.new(1, 1, 1) or Library.Theme.SubText })
        Tw(label, 0.18, { TextColor3 = v and Library.Theme.Text or Library.Theme.SubText })
        Tw(swGlow, 0.25, { ImageTransparency = v and 0.55 or 1 })
        if not silent then Library:SafeCall(self.Callback, v) end
    end
    function T:Get() return self.Value end
    function T:SetVisibility(b) row.Visible = b end
    function T:Colorpicker(d) return CreateColorpicker(rb, d or {}) end
    function T:Keybind(d) d = d or {}; d.Name = d.Name or T.Name; return CreateKeybind(rb, d) end

    hit.MouseEnter:Connect(function() if not T.Value then Tw(label, 0.12, { TextColor3 = Library.Theme.SubText:Lerp(Library.Theme.Text, 0.55) }) end end)
    hit.MouseLeave:Connect(function() if not T.Value then Tw(label, 0.12, { TextColor3 = Library.Theme.SubText }) end end)
    hit.MouseButton1Click:Connect(function() T:Set(not T.Value) end)
    T:Set(G(Data, "Default", "default") or false)
    Library.SetFlags[T.Flag] = function(v) T:Set(v) end
    return T
end

function SectionClass:Button(Data)
    Data = Data or {}
    local B = { Name = G(Data, "Name", "name") or "Button", Callback = G(Data, "Callback", "callback") or function() end }
    local btn = New("TextButton", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 0, Theme = { BackgroundColor3 = "Element" }, Parent = self.Content })
    Corner(btn, 6)
    local btnStroke = Stroke(btn)
    local glow = New("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, Parent = btn })
    Corner(glow, 6); Grad(glow)
    local txt = New("TextLabel", { Text = B.Name, Size = UDim2.fromScale(1, 1), Theme = { TextColor3 = "SubText" }, Parent = btn })
    btn.MouseEnter:Connect(function()
        Tw(glow, 0.15, { BackgroundTransparency = 0.82 }); Tw(txt, 0.15, { TextColor3 = Library.Theme.Text })
        Tw(btnStroke, 0.15, { Color = Library.Theme.Accent })
    end)
    btn.MouseLeave:Connect(function()
        Tw(glow, 0.15, { BackgroundTransparency = 1 }); Tw(txt, 0.15, { TextColor3 = Library.Theme.SubText })
        Tw(btnStroke, 0.15, { Color = Library.Theme.Outline })
    end)
    function B:Press()
        Tw(glow, 0.06, { BackgroundTransparency = 0.45 })
        task.delay(0.08, function() Tw(glow, 0.2, { BackgroundTransparency = 0.82 }) end)
        Library:SafeCall(self.Callback)
    end
    function B:SetVisibility(b) btn.Visible = b end
    btn.MouseButton1Click:Connect(function() B:Press() end)
    return B
end

function SectionClass:Slider(Data)
    Data = Data or {}
    local S = {
        Name = G(Data, "Name", "name") or "Slider", Flag = G(Data, "Flag", "flag") or Library:NextFlag(),
        Min = G(Data, "Min", "min") or 0, Max = G(Data, "Max", "max") or 100, Suffix = G(Data, "Suffix", "suffix") or "",
        Step = G(Data, "Step", "step", "Decimals", "decimals") or 1,
        Callback = G(Data, "Callback", "callback") or function() end, Value = nil,
    }
    local digits = 0
    do local d = tostring(S.Step):match("%.(%d+)"); if d then digits = #d end end

    local row = Row(self, 40)
    New("TextLabel", { Text = S.Name, Size = UDim2.new(0.65, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Theme = { TextColor3 = "SubText" }, Parent = row })
    local pill = New("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 0, 0, 18), AutomaticSize = Enum.AutomaticSize.X, Theme = { BackgroundColor3 = "Element" }, Parent = row })
    Corner(pill, 5); Pad(pill, 8, 0, 8, 0)
    local valLbl = New("TextLabel", { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextSize = 12, Parent = pill })
    local track = New("Frame", { Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 6), BackgroundTransparency = 0, Theme = { BackgroundColor3 = "Element" }, Parent = row })
    Corner(track, 99)
    local fill = New("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track })
    Corner(fill, 99); Grad(fill)
    local knob = New("Frame", { Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track })
    Corner(knob, 99); New("UIStroke", { Color = Library.Theme.Accent, Thickness = 2, Parent = knob })
    local hit = New("TextButton", { Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 24), Parent = row })
    hit.MouseEnter:Connect(function() Tw(knob, 0.12, { Size = UDim2.fromOffset(15, 15) }) end)
    hit.MouseLeave:Connect(function() Tw(knob, 0.12, { Size = UDim2.fromOffset(12, 12) }) end)

    function S:Set(v, silent)
        v = tonumber(v)
        if not v then return end
        v = self.Min + math.floor((v - self.Min) / self.Step + 0.5) * self.Step
        v = math.clamp(v, self.Min, self.Max)
        v = tonumber(string.format("%." .. digits .. "f", v))
        local first = self.Value == nil
        local changed = v ~= self.Value
        self.Value = v
        Library.Flags[self.Flag] = v
        local a = (self.Max == self.Min) and 0 or (v - self.Min) / (self.Max - self.Min)
        Tw(fill, 0.08, { Size = UDim2.fromScale(a, 1) })
        Tw(knob, 0.08, { Position = UDim2.fromScale(a, 0.5) })
        valLbl.Text = string.format("%." .. digits .. "f%s", v, self.Suffix)
        if (changed or first) and not silent then Library:SafeCall(self.Callback, v) end
    end
    function S:Get() return self.Value end
    function S:SetVisibility(b) row.Visible = b end

    Drag(hit, function(i)
        local a = math.clamp((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
        S:Set(S.Min + a * (S.Max - S.Min))
    end, function() Tw(knob, 0.12, { Size = UDim2.fromOffset(16, 16) }) end,
        function() Tw(knob, 0.12, { Size = UDim2.fromOffset(12, 12) }) end)

    S:Set(G(Data, "Default", "default") or S.Min)
    Library.SetFlags[S.Flag] = function(v) S:Set(v) end
    return S
end

function SectionClass:Dropdown(Data)
    Data = Data or {}
    local D = {
        Name = G(Data, "Name", "name") or "Dropdown", Flag = G(Data, "Flag", "flag") or Library:NextFlag(),
        Callback = G(Data, "Callback", "callback") or function() end, Multi = G(Data, "Multi", "multi") or false,
    }
    local width = G(Data, "Size", "size") or 150

    local row = Row(self, 30)
    New("TextLabel", { Text = D.Name, Size = UDim2.new(1, -width - 10, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Theme = { TextColor3 = "SubText" }, Parent = row })
    local btn = New("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(width, 26), BackgroundTransparency = 0, Theme = { BackgroundColor3 = "Element" }, Parent = row })
    Corner(btn, 6); Stroke(btn)
    local valLbl = New("TextLabel", { Text = "...", Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -32, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Parent = btn })
    local chev = Chevron(btn, Library.Theme.SubText)
    chev.Position = UDim2.new(1, -16, 0.5, 0)

    local popup, panel = MakePopup(width, 40)
    local scroll = New("ScrollingFrame", { Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8), Parent = panel })
    List(scroll, 2)

    local function Resize() popup.Size = UDim2.fromOffset(width, math.min(#D.List.Order * 26 + 6, 176)) end

    local function Text(v)
        if D.Multi then return (#v > 0) and table.concat(v, ", ") or "..." end
        return v or "..."
    end

    D.List = OptionList(scroll, D.Multi, function(v, silent)
        D.Value = v
        Library.Flags[D.Flag] = D.Multi and table.clone(v) or v
        valLbl.Text = Text(v)
        if not silent then Library:SafeCall(D.Callback, v) end
    end)
    D.List.OnPick = function() if not D.Multi then Library:HidePopup() end end

    for _, it in ipairs(G(Data, "Items", "items") or { "One", "Two", "Three" }) do D.List:Add(it) end
    Resize()

    function D:Get() return self.Value end
    function D:Set(v, silent) self.List:Set(v, silent) end
    function D:Add(o) self.List:Add(o); Resize() end
    function D:Remove(o)
        local op = self.List.Options[o]
        if op then
            op.Button:Destroy(); self.List.Options[o] = nil
            table.remove(self.List.Order, table.find(self.List.Order, o))
            Resize()
        end
    end
    function D:Refresh(list, default)
        self.List:Clear()
        for _, it in ipairs(list) do self.List:Add(it) end
        Resize()
        self.List:Set(default, true)
        if default == nil then
            Library.Flags[self.Flag] = D.Multi and {} or nil
            valLbl.Text = "..."
        end
    end
    function D:SetVisibility(b) row.Visible = b end

    btn.MouseButton1Click:Connect(function()
        if Library.ActivePopup and Library.ActivePopup.Frame == popup then
            Library:HidePopup()
        else
            Library:ShowPopup(popup, btn, true, function() Tw(chev, 0.15, { Rotation = 0 }) end)
            Tw(chev, 0.15, { Rotation = 180 })
        end
    end)

    local def = G(Data, "Default", "default")
    if def ~= nil then D:Set(def, true) end
    if def ~= nil then Library:SafeCall(D.Callback, D.Value) end
    Library.SetFlags[D.Flag] = function(v) D:Set(v) end
    return D
end

function SectionClass:Listbox(Data)
    Data = Data or {}
    local D = {
        Flag = G(Data, "Flag", "flag") or Library:NextFlag(),
        Callback = G(Data, "Callback", "callback") or function() end, Multi = G(Data, "Multi", "multi") or false,
    }
    local h = G(Data, "Size", "size") or 140
    local box = New("Frame", { Size = UDim2.new(1, 0, 0, h), BackgroundTransparency = 0, Theme = { BackgroundColor3 = "Element" }, Parent = self.Content })
    Corner(box, 6); Stroke(box)
    local search = New("TextBox", { PlaceholderText = "Buscar...", Text = "", ClearTextOnFocus = false, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, TextSize = 12, PlaceholderColor3 = Library.Theme.SubText, Parent = box })
    New("Frame", { Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 1), Theme = { BackgroundColor3 = "Outline" }, Parent = box })
    local scroll = New("ScrollingFrame", { Position = UDim2.fromOffset(4, 33), Size = UDim2.new(1, -8, 1, -37), Parent = box })
    List(scroll, 2)

    D.List = OptionList(scroll, D.Multi, function(v, silent)
        D.Value = v
        Library.Flags[D.Flag] = D.Multi and table.clone(v) or v
        if not silent then Library:SafeCall(D.Callback, v) end
    end)
    for _, it in ipairs(G(Data, "Items", "items") or {}) do D.List:Add(it) end
    search:GetPropertyChangedSignal("Text"):Connect(function() D.List:Filter(search.Text) end)

    function D:Get() return self.Value end
    function D:Set(v, silent) self.List:Set(v, silent) end
    function D:Add(o) self.List:Add(o) end
    function D:Refresh(list)
        self.List:Clear()
        for _, it in ipairs(list) do self.List:Add(it) end
        self.Value = D.Multi and {} or nil
    end
    function D:SetVisibility(b) box.Visible = b end

    local def = G(Data, "Default", "default")
    if def ~= nil then D:Set(def, true) end
    Library.SetFlags[D.Flag] = function(v) D:Set(v) end
    return D
end

function SectionClass:Textbox(Data)
    Data = Data or {}
    local T = {
        Flag = G(Data, "Flag", "flag") or Library:NextFlag(), Callback = G(Data, "Callback", "callback") or function() end,
        Numeric = G(Data, "Numeric", "numeric") or false, Finished = G(Data, "Finished", "finished") or false, Value = "",
    }
    local frame = New("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 0, Theme = { BackgroundColor3 = "Element" }, Parent = self.Content })
    Corner(frame, 6)
    local stroke = Stroke(frame)
    local input = New("TextBox", {
        Text = "", ClearTextOnFocus = false, PlaceholderText = G(Data, "Placeholder", "placeholder") or "Digite...", PlaceholderColor3 = Library.Theme.SubText,
        Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Parent = frame,
    })
    input.Focused:Connect(function() Tw(stroke, 0.15, { Color = Library.Theme.Accent }) end)
    input.FocusLost:Connect(function(enter)
        Tw(stroke, 0.15, { Color = Library.Theme.Outline })
        if T.Finished and enter then T:Set(input.Text) end
    end)

    function T:Set(v, silent)
        v = tostring(v or "")
        if self.Numeric and v ~= "" and not tonumber(v) then v = self.Value end
        self.Value = v
        input.Text = v
        Library.Flags[self.Flag] = v
        if not silent then Library:SafeCall(self.Callback, v) end
    end
    function T:Get() return self.Value end
    function T:SetVisibility(b) frame.Visible = b end

    if not T.Finished then
        input:GetPropertyChangedSignal("Text"):Connect(function()
            if input.Text ~= T.Value then T:Set(input.Text) end
        end)
    end
    local def = G(Data, "Default", "default")
    if def then T:Set(def, true) end
    Library.SetFlags[T.Flag] = function(v) T:Set(v) end
    return T
end

--------------------------------------------------------------------------------
-- Página de configurações pronta
--------------------------------------------------------------------------------
function Library:CreateSettingsPage(Window, KeybindList)
    local Page = Window:Page({ Name = "Settings", Columns = 2 })
    local sel

    local cfg = Page:Section({ Name = "Configs", Description = "Salvar / carregar", Side = 1 })
    local list = cfg:Listbox({ Flag = "ConfigsList", Size = 130, Callback = function(v) sel = v end })
    local nameBox = cfg:Textbox({ Flag = "ConfigsName", Placeholder = "Nome da config" })

    local function Path(n) return Library.Folders.Configs .. "/" .. n end
    cfg:Button({ Name = "Criar", Callback = function()
        local n = Library.Flags["ConfigsName"]
        if not FS() then return Library:Notification({ Title = "Configs", Description = "Executor sem suporte a arquivos.", Duration = 3 }) end
        if n and n ~= "" then
            if not n:find("%.json$") then n = n .. ".json" end
            writefile(Path(n), Library:GetConfig())
            Library:RefreshConfigsList(list)
            Library:Notification({ Title = "Config criada", Description = n, Duration = 3 })
        end
    end })
    cfg:Button({ Name = "Carregar", Callback = function()
        if FS() and sel and isfile(Path(sel)) then
            Library:LoadConfig(readfile(Path(sel)))
            Library:Notification({ Title = "Config carregada", Description = sel, Duration = 3 })
        end
    end })
    cfg:Button({ Name = "Salvar", Callback = function()
        if FS() and sel and isfile(Path(sel)) then
            writefile(Path(sel), Library:GetConfig())
            Library:Notification({ Title = "Config salva", Description = sel, Duration = 3 })
        end
    end })
    cfg:Button({ Name = "Deletar", Callback = function()
        if FS() and sel and isfile(Path(sel)) then
            delfile(Path(sel)); sel = nil
            Library:RefreshConfigsList(list)
        end
    end })
    cfg:Button({ Name = "Atualizar lista", Callback = function() Library:RefreshConfigsList(list) end })
    Library:RefreshConfigsList(list)

    local ui = Page:Section({ Name = "Interface", Description = "Visual e atalhos", Side = 2 })
    ui:Toggle({ Name = "Watermark", Flag = "WatermarkToggle", Callback = function(v)
        if Library.WatermarkFrame then Library.WatermarkFrame.Visible = v end
    end })
    ui:Toggle({ Name = "Lista de keybinds", Flag = "KeybindListToggle", Callback = function(v)
        if KeybindList then KeybindList:SetVisibility(v) end
    end })
    ui:Keybind({ Name = "Tecla do menu", Flag = "MenuBind", Default = Enum.KeyCode.Insert, ShowInList = false, Changed = function(k)
        Library.MenuKey = k
    end })
    local themeDD = ui:Dropdown({ Name = "Tema", Flag = "ThemePreset", Items = Library.PresetNames, Callback = function(n) Library:ApplyPreset(n) end })
    themeDD:Set("Nova", true)
    ui:Label("Cor principal"):Colorpicker({ Flag = "AccentColor", Default = Library.Theme.Accent, Callback = function(c) Library:ChangeTheme("Accent", c) end })
    ui:Label("Cor secundária"):Colorpicker({ Flag = "AccentGradientColor", Default = Library.Theme.AccentGradient, Callback = function(c) Library:ChangeTheme("AccentGradient", c) end })
    ui:Button({ Name = "Descarregar UI", Callback = function() Library:Unload() end })

    return Page
end

if getgenv then getgenv().NovaLib = Library end
return Library