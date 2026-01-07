-- Cursor Outline (menubar + full-screen outline)
-- Hotkey: Ctrl+Alt+Cmd+F
local function fileExists(p)
  local f = io.open(p, "r")
  if f then f:close() return true end
  return false
end

local config = {
  enabled = true,
  speedMultiplier = 0.7,
  borderExtraPixels = 1,
  iconPath = "assets/cursor_outline_icon.png",
}

local userConfigPath = hs.configdir .. "/config.lua"
if fileExists(userConfigPath) then
  local ok, userCfg = pcall(dofile, userConfigPath)
  if ok and type(userCfg) == "table" then
    for k, v in pairs(userCfg) do config[k] = v end
  end
end

local KEY_PREFIX = "cursor_outline."

local DEFAULTS = {
  enabled = true,
  style = "solid",     -- solid | pulse | rainbow
  color = "System",    -- System | Red | Orange | Yellow | Green | Blue | Purple | Cyan | Magenta | White
  thickness = 4,
  icon_hpad = 0,

  spotlight_material = "Tinted",   -- Clear | Tinted | Off
  dim_tint = true,
  auto_hide_fullscreen_video = true,
  auto_hide_screen_sharing = true,

  feedback_sound = true,
  feedback_pop = true,
}

local ANIM_SPEED = 0.50

local COLORS = {
  Red     = { red = 1.00, green = 0.20, blue = 0.20 },
  Orange  = { red = 1.00, green = 0.55, blue = 0.15 },
  Yellow  = { red = 0.98, green = 0.85, blue = 0.20 },
  Green   = { red = 0.20, green = 0.85, blue = 0.30 },
  Blue    = { red = 0.20, green = 0.60, blue = 1.00 },
  Purple  = { red = 0.70, green = 0.35, blue = 1.00 },
  Cyan    = { red = 0.20, green = 0.95, blue = 0.90 },
  Magenta = { red = 1.00, green = 0.25, blue = 0.85 },
  White   = { red = 1.00, green = 1.00, blue = 1.00 },
}

local STYLE_LABELS = {
  solid   = "Solid",
  pulse   = "Pulse",
  rainbow = "Rainbow",
}

local STYLE_ORDER = { "solid", "pulse", "rainbow" }
local COLOR_ORDER = { "System", "Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Cyan", "Magenta", "White" }
local MATERIAL_ORDER = { "Clear", "Tinted", "Off" }

_G.CursorOutline = _G.CursorOutline or {}
local M = _G.CursorOutline

local function settingGet(key, fallback)
  local v = hs.settings.get(KEY_PREFIX .. key)
  if v == nil then return fallback end
  return v
end

local function settingSet(key, value)
  hs.settings.set(KEY_PREFIX .. key, value)
end

M.state = M.state or {
  enabled = settingGet("enabled", DEFAULTS.enabled),
  style = settingGet("style", DEFAULTS.style),
  color = settingGet("color", DEFAULTS.color),
  thickness = DEFAULTS.thickness,
  icon_hpad = DEFAULTS.icon_hpad,

  spotlight_material = settingGet("spotlight_material", DEFAULTS.spotlight_material),
  dim_tint = settingGet("dim_tint", DEFAULTS.dim_tint),
  auto_hide_fullscreen_video = settingGet("auto_hide_fullscreen_video", DEFAULTS.auto_hide_fullscreen_video),
  auto_hide_screen_sharing = settingGet("auto_hide_screen_sharing", DEFAULTS.auto_hide_screen_sharing),

  feedback_sound = settingGet("feedback_sound", DEFAULTS.feedback_sound),
  feedback_pop = settingGet("feedback_pop", DEFAULTS.feedback_pop),
}

if M.state.style == "blink" then
  M.state.style = "solid"
  settingSet("style", "solid")
end

M.state.thickness = DEFAULTS.thickness
M.state.icon_hpad = DEFAULTS.icon_hpad
settingSet("icon_hpad", M.state.icon_hpad)

M.screens = M.screens or {}
M.anim = M.anim or { timer = nil, t = 0, hue = 0 }
M._iconImage = M._iconImage or nil
M.menubar = M.menubar or nil
M.screenWatcher = M.screenWatcher or nil
M.hotkey = M.hotkey or nil
M.appWatcher = M.appWatcher or nil
M.suppressed = M.suppressed or false
M.activeScreenId = M.activeScreenId or nil

M.spotlightHoldActive = M.spotlightHoldActive or false
M.spotlightFadeAlpha = M.spotlightFadeAlpha or 0.0
M.spotlightFadeFrom = M.spotlightFadeFrom or 0.0
M.spotlightFadeTo = M.spotlightFadeTo or 0.0
M.spotlightFadeStart = M.spotlightFadeStart or 0.0
M.spotlightFadeDur = M.spotlightFadeDur or 0.08
M.spotlightLastX = M.spotlightLastX or nil
M.spotlightLastY = M.spotlightLastY or nil
M.spotlightLastScreenId = M.spotlightLastScreenId or nil

M._spotlightFadeTimer = M._spotlightFadeTimer or nil
M._spotlightMoveTap = M._spotlightMoveTap or nil
M._spotlightMaxHz = M._spotlightMaxHz or 120
M._spotlightLastMoveTs = M._spotlightLastMoveTs or 0
M._spotlightRedrawTimer = M._spotlightRedrawTimer or nil

M._systemAccentBase = M._systemAccentBase or nil

M._hapticSound = M._hapticSound or nil
M._outlinePopTimer = M._outlinePopTimer or nil
M._outlinePopScreenId = M._outlinePopScreenId or nil

M._a11yTimer = M._a11yTimer or nil
M._ctxTimer = M._ctxTimer or nil
M.a11y = M.a11y or { reduceTransparency = false, increaseContrast = false, reduceMotion = false }
M.ctx = M.ctx or { suppressed = false, reason = "" }
M._spotlightProfileKey = M._spotlightProfileKey or nil

M._menuDirty = M._menuDirty or true
M._menuApplyTimer = M._menuApplyTimer or nil
M._lastMenuSig = M._lastMenuSig or nil

M._hotkeyOverride = M._hotkeyOverride or false
M._menuOpen = M._menuOpen or false

local HAPTIC_SOUND_VOLUME = 0.08
local OUTLINE_POP_EXTRA_PX = 1
local OUTLINE_POP_DURATION = 0.12

local function now()
  return hs.timer.secondsSinceEpoch()
end

local function clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end

local function smoothstep01(t)
  t = clamp(t, 0, 1)
  return t * t * (3 - 2 * t)
end

local function hsvToRgb(h, s, v)
  local i = math.floor(h * 6)
  local f = h * 6 - i
  local p = v * (1 - s)
  local q = v * (1 - f * s)
  local t = v * (1 - (1 - f) * s)
  i = i % 6
  if i == 0 then return v, t, p end
  if i == 1 then return q, v, p end
  if i == 2 then return p, v, t end
  if i == 3 then return p, q, v end
  if i == 4 then return t, p, v end
  return v, p, q
end

local function colorWithAlpha(c, a)
  return { red = c.red, green = c.green, blue = c.blue, alpha = a }
end

local function mix(a, b, t)
  t = clamp(t, 0, 1)
  return {
    red = a.red + (b.red - a.red) * t,
    green = a.green + (b.green - a.green) * t,
    blue = a.blue + (b.blue - a.blue) * t,
  }
end

local function systemAccentBase()
  if M._systemAccentBase ~= nil then
    return M._systemAccentBase
  end

  local ok, result = pcall(function()
    if not (hs.drawing and hs.drawing.color and hs.drawing.color.lists and hs.drawing.color.colorsFor and hs.drawing.color.asRGB) then
      return nil
    end

    local lists = hs.drawing.color.lists()
    if type(lists) ~= "table" then return nil end

    local names = {
      "controlAccentColor",
      "accentColor",
      "keyboardFocusIndicatorColor",
      "alternateSelectedControlColor",
      "selectedControlColor",
    }

    for listName, _ in pairs(lists) do
      local colors = hs.drawing.color.colorsFor(listName)
      if type(colors) == "table" then
        for _, n in ipairs(names) do
          local c = colors[n]
          if c then
            local rgb = hs.drawing.color.asRGB(c)
            if type(rgb) == "table" and rgb.red then
              return { red = rgb.red, green = rgb.green, blue = rgb.blue }
            end
          end
        end
      end
    end

    return nil
  end)

  if ok then
    M._systemAccentBase = result
  else
    M._systemAccentBase = nil
  end

  return M._systemAccentBase
end

local function baseAccentOrRed()
  return systemAccentBase() or COLORS.Blue
end

local function readBoolDefaults(key)
  local ok, out = pcall(function()
    local s = hs.execute("/usr/bin/defaults read -g " .. key .. " 2>/dev/null") or ""
    s = tostring(s):lower()
    if s:find("1") or s:find("true") or s:find("yes") then return true end
    return false
  end)
  if ok then return out end
  return false
end

local function refreshA11y()
  local rt = readBoolDefaults("AppleReduceTransparency")
  local ic = readBoolDefaults("AppleIncreaseContrast")

  local rm = false
  do
    local ok, v = pcall(function()
      local s = hs.execute("/usr/bin/defaults read -g reduceMotion 2>/dev/null") or ""
      s = tostring(s):lower()
      return (s:find("1") or s:find("true") or s:find("yes")) ~= nil
    end)
    if ok then rm = v end
  end

  local changed =
    (M.a11y.reduceTransparency ~= rt) or
    (M.a11y.increaseContrast ~= ic) or
    (M.a11y.reduceMotion ~= rm)

  M.a11y.reduceTransparency = rt
  M.a11y.increaseContrast = ic
  M.a11y.reduceMotion = rm

  return changed
end

local function effectiveStyle()
  if M.a11y.reduceMotion then
    return "solid"
  end
  return M.state.style
end

local function currentStrokeColor()
  local style = effectiveStyle()

  if style == "rainbow" then
    local r, g, b = hsvToRgb(M.anim.hue % 1, 0.95, 1.00)
    return { red = r, green = g, blue = b, alpha = 1.0 }
  end

  local base
  if M.state.color == "System" then
    base = baseAccentOrRed()
  else
    base = COLORS[M.state.color] or baseAccentOrRed()
  end

  if style == "solid" then
    return colorWithAlpha(base, 1.0)
  end

  if style == "pulse" then
    local period = 0.60 / ANIM_SPEED
    local x = (M.anim.t % period) / period
    local a = 0.25 + 0.75 * (0.5 + 0.5 * math.sin(x * 2 * math.pi))
    return colorWithAlpha(base, clamp(a, 0.10, 1.0))
  end

  return colorWithAlpha(base, 1.0)
end

local function applyMacOSOutlineStyle(outlineEl, stroke)
  if not outlineEl or not stroke then return end

  local base = { red = stroke.red, green = stroke.green, blue = stroke.blue }
  local bright = mix(base, { red = 1, green = 1, blue = 1 }, 0.18)

  local a = stroke.alpha or 1.0
  local lineA = clamp(a * 0.90 + 0.10, 0, 1)
  local glowA = clamp(a * 0.32, 0, 0.52)

  if M.a11y.reduceTransparency or M.a11y.increaseContrast then
    glowA = 0.0
    lineA = 1.0
  end

  outlineEl.strokeColor = { red = bright.red, green = bright.green, blue = bright.blue, alpha = lineA }

  pcall(function()
    outlineEl.shadow = {
      blurRadius = 10,
      color = { red = bright.red, green = bright.green, blue = bright.blue, alpha = glowA },
      offset = { h = 0, w = 0 },
    }
  end)

  pcall(function() outlineEl.strokeJoinStyle = "round" end)
  pcall(function() outlineEl.strokeCapStyle = "round" end)
end

local function spotlightProfile()
  if M.a11y.reduceTransparency or M.a11y.increaseContrast then
    return {
      dimAlpha = 0.46,
      innerR = 20,
      outerR = 110,
      steps = 18,
      holeStrength = 1.0,
    }
  end

  return {
    dimAlpha = 0.34,
    innerR = 18,
    outerR = 130,
    steps = 22,
    holeStrength = 0.78,
  }
end

local function spotlightFadeInOut()
  if M.a11y.reduceMotion then
    return 0.02, 0.05
  end
  return 0.08, 0.18
end

local function spotlightCompositeRule()
  local rule = "destinationOut"
  pcall(function()
    if hs.canvas and hs.canvas.compositeTypes and hs.canvas.compositeTypes.destinationOut then
      rule = hs.canvas.compositeTypes.destinationOut
    end
  end)
  return rule
end

local function isFullscreenWindow(w)
  if not w then return false end
  local ok, fs = pcall(function() return w:isFullScreen() end)
  if ok and fs then return true end
  return false
end

local VIDEO_APPS = {
  ["IINA"] = true,
  ["VLC"] = true,
  ["QuickTime Player"] = true,
  ["TV"] = true,
  ["Music"] = false,
}

local BROWSER_APPS = {
  ["Safari"] = true,
  ["Google Chrome"] = true,
  ["Arc"] = true,
  ["Firefox"] = true,
  ["Brave Browser"] = true,
  ["Microsoft Edge"] = true,
}

local VIDEO_TITLE_HINTS = {
  "youtube", "netflix", "prime video", "hulu", "disney", "max", "vimeo", "twitch",
  "meet", "zoom", "teams", "webex",
}

local function isFullscreenVideoContext()
  local app = hs.application.frontmostApplication()
  if not app then return false end
  local w = app:focusedWindow() or app:mainWindow()
  if not isFullscreenWindow(w) then return false end

  local name = app:name() or ""
  if VIDEO_APPS[name] then return true end

  if BROWSER_APPS[name] then
    local title = ""
    pcall(function() title = (w and w:title()) or "" end)
    title = tostring(title):lower()
    for _, h in ipairs(VIDEO_TITLE_HINTS) do
      if title:find(h, 1, true) then
        return true
      end
    end
    return false
  end

  return false
end

local function menuItemEnabled(app, path)
  local ok, item = pcall(function() return app:findMenuItem(path) end)
  if not ok or not item then return false end
  if type(item) == "table" and item.enabled ~= nil then
    return item.enabled == true
  end
  return true
end

local function isScreenSharingActiveHeuristic()
  local zoom = hs.application.get("zoom.us")
  if zoom then
    if menuItemEnabled(zoom, { "Meeting", "Stop Share" }) then return true end
    if menuItemEnabled(zoom, { "Meeting", "Stop Share Screen" }) then return true end
    if menuItemEnabled(zoom, { "Meeting", "Stop Screen Share" }) then return true end
  end

  local screenSharing = hs.application.get("Screen Sharing")
  if screenSharing and hs.application.frontmostApplication() == screenSharing then
    return true
  end

  local qt = hs.application.get("QuickTime Player")
  if qt then
    if menuItemEnabled(qt, { "File", "Stop Screen Recording" }) then return true end
  end

  return false
end

local function refreshContextSuppression()
  local suppressed = false
  local reason = ""

  if M.state.auto_hide_fullscreen_video and isFullscreenVideoContext() then
    suppressed = true
    reason = "Full-Screen Video"
  end

  if (not suppressed) and M.state.auto_hide_screen_sharing and isScreenSharingActiveHeuristic() then
    suppressed = true
    reason = "Screen Sharing"
  end

  local changed = (M.ctx.suppressed ~= suppressed) or (M.ctx.reason ~= reason)
  M.ctx.suppressed = suppressed
  M.ctx.reason = reason
  return changed
end

local function isEffectivelyAllowed()
  if not M.state.enabled then return false end
  if M.suppressed then return false end
  if M._hotkeyOverride then return true end
  return not M.ctx.suppressed
end

local ICON_PATH = hs.configdir .. "/cursor_outline_icon.png"
local ICON_B64 = [[
iVBORw0KGgoAAAANSUhEUgAAABIAAAASCAYAAABWzo5XAAAAQklEQVR4nGNgGGyA
Ecb4////f7ggIyMjLjF09TBxJmq5iAXDiUg2o7tiiIL/UECueqoFNtUMGgWEAdl5
DR0M41gDALqvJAcrbf9qAAAAAElFTkSuQmCC
]]

local function loadMenubarIcon()
  local img = nil

  do
    local ok, sym = pcall(function()
      if hs.image and hs.image.imageFromSystemSymbolName then
        return hs.image.imageFromSystemSymbolName("cursorarrow.rays", { })
      end
      return nil
    end)
    if ok and sym then
      img = sym
    end
  end

  if not img then
    local raw
    do
      local ok, decoded = pcall(function()
        local b64 = ICON_B64:gsub("%s", "")
        return hs.base64.decode(b64)
      end)
      if ok then raw = decoded end
    end

    if raw then
      local f = io.open(ICON_PATH, "wb")
      if f then
        f:write(raw)
        f:close()
      end
    end

    img = hs.image.imageFromPath(ICON_PATH)
  end

  if img then
    pcall(function() img:setTemplate(true) end)
    pcall(function() img:template(true) end)
    pcall(function()
      local sz = img:size()
      if not (sz and sz.h == 18) then
        local okSize = pcall(function() img:size({ w = 18, h = 18 }) end)
        if not okSize then
          pcall(function() img:setSize({ w = 18, h = 18 }) end)
        end
      end
    end)
  end

  return img
end

local function ensureMenubar()
  local ok, inBar = pcall(function()
    return (M.menubar ~= nil) and M.menubar:isInMenuBar()
  end)

  if (not ok) or (not inBar) then
    M.menubar = hs.menubar.new()
  end
  if not M.menubar then return end

  if not M._iconImage then
    M._iconImage = loadMenubarIcon()
  end

  if M._iconImage then
    M.menubar:setIcon(M._iconImage, true)
  else
    M.menubar:setTitle("⌖")
  end
end

local function stopMainTimer()
  if M.anim.timer then
    M.anim.timer:stop()
    M.anim.timer = nil
  end
end

local function activeScreenId()
  local s = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  if not s then return nil end
  return s:id()
end

local function deleteCanvas(entry)
  if not entry then return end
  if entry.canvas then entry.canvas:delete() end
end

local function clearAllCanvases()
  for _, entry in pairs(M.screens) do
    deleteCanvas(entry)
  end
  M.screens = {}
end

local function spotlightProfileKey(profile)
  return table.concat({
    tostring(profile.dimAlpha),
    tostring(profile.innerR),
    tostring(profile.outerR),
    tostring(profile.steps),
    tostring(profile.holeStrength),
  }, "|")
end

local function ensureCanvasForScreen(screen, profile)
  local id = screen:id()
  local full = screen:fullFrame()
  local t = M.state.thickness

  local half = t / 2
  local pad = math.ceil(half) + 2

  local canvasFrame = {
    x = full.x - pad,
    y = full.y - pad,
    w = full.w + pad * 2,
    h = full.h + pad * 2,
  }

  local rectFrame = {
    x = pad + half,
    y = pad + half,
    w = full.w - t,
    h = full.h - t,
  }

  local screenFillFrame = { x = pad, y = pad, w = full.w, h = full.h }

  local entry = M.screens[id]
  if not entry then
    local canvas = hs.canvas.new(canvasFrame)
    canvas:level("overlay")
    canvas:behaviorAsLabels({ "canJoinAllSpaces", "stationary", "fullScreenAuxiliary", "ignoresCycle" })
    canvas:canvasMouseEvents(false, false, false, false)

    canvas[1] = {
      type = "rectangle",
      action = "stroke",
      strokeWidth = t,
      strokeColor = { red = 1, green = 0, blue = 0, alpha = 1 },
      frame = rectFrame,
    }

    canvas[2] = {
      type = "rectangle",
      action = "skip",
      fillColor = { red = 0, green = 0, blue = 0, alpha = profile.dimAlpha },
      frame = screenFillFrame,
    }

    local comp = spotlightCompositeRule()
    local cutoutFirst = 3
    local cutoutLast = 2

    for i = 1, profile.steps do
      local idx = cutoutFirst + (i - 1)
      local ok = pcall(function()
        canvas[idx] = {
          type = "circle",
          action = "skip",
          fillColor = { red = 1, green = 1, blue = 1, alpha = 0 },
          compositeRule = comp,
          center = { x = 0, y = 0 },
          radius = 1,
        }
      end)
      if not ok then
        pcall(function()
          canvas[idx] = {
            type = "oval",
            action = "skip",
            fillColor = { red = 1, green = 1, blue = 1, alpha = 0 },
            compositeRule = comp,
            frame = { x = 0, y = 0, w = 2, h = 2 },
          }
        end)
      end
      cutoutLast = idx
    end

    local glassFirst = cutoutLast + 1
    local glassLast = cutoutLast

    local glassSteps = 5
    for i = 1, glassSteps do
      local idx = glassFirst + (i - 1)
      local ok = pcall(function()
        canvas[idx] = {
          type = "circle",
          action = "skip",
          fillColor = { red = 1, green = 1, blue = 1, alpha = 0 },
          compositeRule = "sourceOver",
          center = { x = 0, y = 0 },
          radius = 1,
        }
      end)
      if not ok then
        pcall(function()
          canvas[idx] = {
            type = "oval",
            action = "skip",
            fillColor = { red = 1, green = 1, blue = 1, alpha = 0 },
            compositeRule = "sourceOver",
            frame = { x = 0, y = 0, w = 2, h = 2 },
          }
        end)
      end
      glassLast = idx
    end

    entry = {
      screen = screen,
      canvas = canvas,
      pad = pad,

      spotlightDimIdx = 2,

      cutoutFirst = cutoutFirst,
      cutoutLast = cutoutLast,
      cutoutSteps = profile.steps,

      glassFirst = glassFirst,
      glassLast = glassLast,
      glassSteps = glassSteps,

      lastCx = nil,
      lastCy = nil,
      lastA = nil,
      lastHoleStrength = nil,
      lastDimA = nil,
      lastGlassMode = nil,
      lastGlassA = nil,
      lastDimRGB = nil,
      lastGlassRGB = nil,
      lastShow = nil,
    }
    M.screens[id] = entry
  else
    entry.screen = screen
    entry.pad = pad
    entry.canvas:frame(canvasFrame)
    entry.canvas[1].frame = rectFrame
    entry.canvas[1].strokeWidth = t
    if entry.canvas[2] then
      entry.canvas[2].frame = screenFillFrame
    end
  end

  return entry
end

local function refreshScreens()
  local profile = spotlightProfile()
  local key = spotlightProfileKey(profile)

  local alive = {}
  for _, s in ipairs(hs.screen.allScreens()) do
    alive[s:id()] = true
    ensureCanvasForScreen(s, profile)
  end

  for id, entry in pairs(M.screens) do
    if not alive[id] then
      deleteCanvas(entry)
      M.screens[id] = nil
    end
  end

  return key
end

local function hideSpotlightOnScreen(entry)
  if not entry or not entry.canvas then return end
  if entry.canvas[entry.spotlightDimIdx] then
    if entry.canvas[entry.spotlightDimIdx].action ~= "skip" then
      entry.canvas[entry.spotlightDimIdx].action = "skip"
    end
  end
  for i = entry.cutoutFirst or 3, entry.cutoutLast or 2 do
    if entry.canvas[i] and entry.canvas[i].action ~= "skip" then entry.canvas[i].action = "skip" end
  end
  for i = entry.glassFirst or 0, entry.glassLast or -1 do
    if entry.canvas[i] and entry.canvas[i].action ~= "skip" then entry.canvas[i].action = "skip" end
  end

  entry.lastA = 0
  entry.lastShow = false
end

local function clearOutlinePop()
  if M._outlinePopTimer then
    M._outlinePopTimer:stop()
    M._outlinePopTimer = nil
  end

  if M._outlinePopScreenId then
    local entry = M.screens[M._outlinePopScreenId]
    if entry and entry.canvas and entry.canvas[1] then
      entry.canvas[1].strokeWidth = M.state.thickness
    end
  end

  M._outlinePopScreenId = nil
end

local function playSoftHaptic()
  if not M.state.feedback_sound then return end
  pcall(function()
    if not (hs.sound and hs.sound.getByName) then return end
    if not M._hapticSound then
      M._hapticSound = hs.sound.getByName("Tink") or hs.sound.getByName("Pop") or hs.sound.getByName("Glass")
    end
    if not M._hapticSound then return end
    pcall(function() M._hapticSound:volume(HAPTIC_SOUND_VOLUME) end)
    M._hapticSound:play()
  end)
end

local function outlinePopAtCursorScreen()
  if not M.state.feedback_pop then return end

  clearOutlinePop()

  local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  if not screen then return end
  local entry = M.screens[screen:id()]
  if not entry then return end
  if not (entry.canvas and entry.canvas[1]) then return end

  entry.canvas[1].strokeWidth = M.state.thickness + OUTLINE_POP_EXTRA_PX
  M._outlinePopScreenId = screen:id()

  M._outlinePopTimer = hs.timer.doAfter(OUTLINE_POP_DURATION, function()
    clearOutlinePop()
  end)
end

local function setSpotlightFadeTarget(targetAlpha, duration)
  M.spotlightFadeFrom = M.spotlightFadeAlpha
  M.spotlightFadeTo = targetAlpha
  M.spotlightFadeStart = now()
  M.spotlightFadeDur = duration
end

local function spotlightFadeAlpha()
  local dur = (M.spotlightFadeDur or 0.08)
  if dur <= 0 then
    M.spotlightFadeAlpha = M.spotlightFadeTo
    return M.spotlightFadeAlpha
  end

  local t = (now() - (M.spotlightFadeStart or 0)) / dur
  local s = smoothstep01(t)
  local a = (M.spotlightFadeFrom or 0) + ((M.spotlightFadeTo or 0) - (M.spotlightFadeFrom or 0)) * s
  M.spotlightFadeAlpha = clamp(a, 0, 1)
  return M.spotlightFadeAlpha
end

local function spotlightVisualParams()
  local profile = spotlightProfile()
  local holeStrength = profile.holeStrength

  if M.state.spotlight_material == "Off" then
    holeStrength = 1.0
  end

  local dimRGB = { red = 0, green = 0, blue = 0 }
  local useTint = M.state.dim_tint and (not M.a11y.reduceTransparency) and (not M.a11y.increaseContrast)
  if useTint then
    local accent = baseAccentOrRed()
    dimRGB = mix(dimRGB, accent, 0.12)
  end

  local glassMode = M.state.spotlight_material
  if M.a11y.reduceTransparency or M.a11y.increaseContrast then
    glassMode = "Off"
  end

  local glassColor = { red = 1, green = 1, blue = 1 }
  local glassCenterAlpha = 0.06
  if glassMode == "Tinted" then
    local accent = baseAccentOrRed()
    glassColor = mix({ red = 1, green = 1, blue = 1 }, accent, 0.35)
    glassCenterAlpha = 0.07
  elseif glassMode == "Clear" then
    glassColor = { red = 1, green = 1, blue = 1 }
    glassCenterAlpha = 0.05
  else
    glassCenterAlpha = 0.0
  end

  return profile, holeStrength, dimRGB, glassMode, glassColor, glassCenterAlpha
end

local function approxEqual(a, b, eps)
  eps = eps or 0.25
  return math.abs((a or 0) - (b or 0)) <= eps
end

local function approxEqualA(a, b, eps)
  eps = eps or 0.01
  return math.abs((a or 0) - (b or 0)) <= eps
end

local function spotlightRender()
  local allowed = isEffectivelyAllowed()

  if not allowed and M.spotlightHoldActive then
    M.spotlightHoldActive = false
    local _, fadeOut = spotlightFadeInOut()
    setSpotlightFadeTarget(0.0, fadeOut)
  end

  local a = spotlightFadeAlpha()

  if not (M.spotlightLastX and M.spotlightLastY and M.spotlightLastScreenId) then
    return
  end

  local screen = hs.screen.find(M.spotlightLastScreenId)
  if not screen then return end

  local entry = M.screens[screen:id()]
  if not entry or not entry.canvas then return end

  local cf = entry.canvas:frame()
  local cx = M.spotlightLastX - cf.x
  local cy = M.spotlightLastY - cf.y

  local show = (a > 0.001)

  if not show and (entry.lastA == nil or entry.lastA <= 0.001) then
    return
  end

  local profile, holeStrength, dimRGB, glassMode, glassColor, glassCenterAlpha = spotlightVisualParams()
  local dimA = profile.dimAlpha * a

  local moved = (not approxEqual(entry.lastCx, cx, 0.5)) or (not approxEqual(entry.lastCy, cy, 0.5))
  local aChanged = not approxEqualA(entry.lastA, a, 0.01)
  local holeChanged = not approxEqualA(entry.lastHoleStrength, holeStrength, 0.01)
  local dimChanged = not approxEqualA(entry.lastDimA, dimA, 0.01)
  local dimRgbChanged = not entry.lastDimRGB
    or (not approxEqualA(entry.lastDimRGB.red, dimRGB.red, 0.005))
    or (not approxEqualA(entry.lastDimRGB.green, dimRGB.green, 0.005))
    or (not approxEqualA(entry.lastDimRGB.blue, dimRGB.blue, 0.005))

  local glassChanged = (entry.lastGlassMode ~= glassMode) or not approxEqualA(entry.lastGlassA, glassCenterAlpha, 0.01)
  local glassRgbChanged = not entry.lastGlassRGB
    or (not approxEqualA(entry.lastGlassRGB.red, glassColor.red, 0.005))
    or (not approxEqualA(entry.lastGlassRGB.green, glassColor.green, 0.005))
    or (not approxEqualA(entry.lastGlassRGB.blue, glassColor.blue, 0.005))

  if dimChanged or dimRgbChanged or (entry.lastShow ~= show) then
    local el = entry.canvas[entry.spotlightDimIdx]
    if el then
      if show then
        el.fillColor = { red = dimRGB.red, green = dimRGB.green, blue = dimRGB.blue, alpha = dimA }
        if el.action ~= "fill" then el.action = "fill" end
      else
        if el.action ~= "skip" then el.action = "skip" end
      end
    end
  end

  if (moved or aChanged or holeChanged or (entry.lastShow ~= show)) then
    local steps = entry.cutoutSteps or 18
    for i = 1, steps do
      local idx = (entry.cutoutFirst or 3) + (i - 1)
      local el = entry.canvas[idx]
      if el then
        if show then
          local t = (steps > 1) and ((i - 1) / (steps - 1)) or 0
          local baseA = 1.0 - smoothstep01(t)
          local alpha = baseA * a * holeStrength
          el.fillColor = { red = 1, green = 1, blue = 1, alpha = alpha }

          local r = profile.innerR + t * (profile.outerR - profile.innerR)
          if el.center ~= nil and el.radius ~= nil then
            el.center = { x = cx, y = cy }
            el.radius = r
          elseif el.frame ~= nil then
            el.frame = { x = cx - r, y = cy - r, w = r * 2, h = r * 2 }
          end

          if el.action ~= "fill" then el.action = "fill" end
        else
          if el.action ~= "skip" then el.action = "skip" end
        end
      end
    end
  end

  if (glassChanged or glassRgbChanged or moved or aChanged or (entry.lastShow ~= show)) then
    local steps = entry.glassSteps or 5
    for i = 1, steps do
      local idx = (entry.glassFirst or 0) + (i - 1)
      local el = entry.canvas[idx]
      if el then
        local alpha = 0.0
        if show and glassMode ~= "Off" then
          local t = (steps > 1) and ((i - 1) / (steps - 1)) or 0
          local baseA = 1.0 - smoothstep01(t)
          alpha = baseA * a * glassCenterAlpha
        end

        if alpha > 0.001 then
          el.fillColor = { red = glassColor.red, green = glassColor.green, blue = glassColor.blue, alpha = alpha }

          local t = (steps > 1) and ((i - 1) / (steps - 1)) or 0
          local inner = math.max(10, profile.innerR * 0.75)
          local outer = math.max(inner + 20, profile.innerR + 55)
          local r = inner + t * (outer - inner)

          if el.center ~= nil and el.radius ~= nil then
            el.center = { x = cx, y = cy }
            el.radius = r
          elseif el.frame ~= nil then
            el.frame = { x = cx - r, y = cy - r, w = r * 2, h = r * 2 }
          end

          if el.action ~= "fill" then el.action = "fill" end
        else
          if el.action ~= "skip" then el.action = "skip" end
        end
      end
    end
  end

  entry.lastCx = cx
  entry.lastCy = cy
  entry.lastA = a
  entry.lastHoleStrength = holeStrength
  entry.lastDimA = dimA
  entry.lastGlassMode = glassMode
  entry.lastGlassA = glassCenterAlpha
  entry.lastDimRGB = { red = dimRGB.red, green = dimRGB.green, blue = dimRGB.blue }
  entry.lastGlassRGB = { red = glassColor.red, green = glassColor.green, blue = glassColor.blue }
  entry.lastShow = show

  if (not M.spotlightHoldActive) and (a <= 0.001) then
    hideSpotlightOnScreen(entry)
    M.spotlightLastX = nil
    M.spotlightLastY = nil
    M.spotlightLastScreenId = nil
  end
end

local function stopSpotlightFadeTimer()
  if M._spotlightFadeTimer then
    M._spotlightFadeTimer:stop()
    M._spotlightFadeTimer = nil
  end
end

local function ensureSpotlightFadeTimer()
  if M._spotlightFadeTimer then return end
  M._spotlightFadeTimer = hs.timer.doEvery(1/60, function()
    spotlightRender()
    if (not M.spotlightHoldActive) and approxEqualA(M.spotlightFadeAlpha, M.spotlightFadeTo, 0.01) then
      if (M.spotlightFadeAlpha or 0) <= 0.001 then
        stopSpotlightFadeTimer()
      end
    end
  end)
end

local function stopSpotlightMoveTap()
  if M._spotlightMoveTap then
    pcall(function() M._spotlightMoveTap:stop() end)
  end
end

local function ensureSpotlightMoveTap()
  if M._spotlightMoveTap then return end
  if not hs.eventtap then return end

  local types = {}
  pcall(function()
    types = {
      hs.eventtap.event.types.mouseMoved,
      hs.eventtap.event.types.leftMouseDragged,
      hs.eventtap.event.types.rightMouseDragged,
      hs.eventtap.event.types.otherMouseDragged,
    }
  end)
  if #types == 0 then return end

  M._spotlightMoveTap = hs.eventtap.new(types, function()
    if not M.spotlightHoldActive then return false end
    if not isEffectivelyAllowed() then return false end

    local tnow = now()
    local minDt = 1.0 / (M._spotlightMaxHz or 120)
    if (tnow - (M._spotlightLastMoveTs or 0)) < minDt then
      return false
    end
    M._spotlightLastMoveTs = tnow

    local pos = hs.mouse.absolutePosition()
    local screen = hs.mouse.getCurrentScreen()
    if pos and screen then
      M.spotlightLastX = pos.x
      M.spotlightLastY = pos.y
      M.spotlightLastScreenId = screen:id()
      spotlightRender()
    end
    return false
  end)
end

local function startSpotlightFollow()
  if not isEffectivelyAllowed() then return end

  local fadeIn = select(1, spotlightFadeInOut())

  local pos = hs.mouse.absolutePosition()
  local screen = hs.mouse.getCurrentScreen()
  if pos and screen then
    M.spotlightLastX = pos.x
    M.spotlightLastY = pos.y
    M.spotlightLastScreenId = screen:id()
  end

  M.spotlightHoldActive = true
  setSpotlightFadeTarget(1.0, fadeIn)

  ensureSpotlightMoveTap()
  if M._spotlightMoveTap then pcall(function() M._spotlightMoveTap:start() end) end

  ensureSpotlightFadeTimer()
  spotlightRender()
end

local function stopSpotlightFollow()
  local _, fadeOut = spotlightFadeInOut()
  M.spotlightHoldActive = false
  setSpotlightFadeTarget(0.0, fadeOut)
  stopSpotlightMoveTap()
  ensureSpotlightFadeTimer()
  spotlightRender()
  clearOutlinePop()
end

local function updateAllCanvases()
  local enabled = isEffectivelyAllowed()
  local activeId = activeScreenId()
  M.activeScreenId = activeId

  local stroke = enabled and currentStrokeColor() or { red = 0, green = 0, blue = 0, alpha = 0 }

  for id, entry in pairs(M.screens) do
    local canvas = entry.canvas
    if canvas then
      local isActive = enabled and (activeId ~= nil) and (id == activeId)

      if not isActive then
        hideSpotlightOnScreen(entry)
        if M._outlinePopScreenId == id then
          clearOutlinePop()
        end
      end

      if isActive then
        applyMacOSOutlineStyle(canvas[1], stroke)
        canvas:show()
      else
        canvas[1].strokeColor = { red = 0, green = 0, blue = 0, alpha = 0 }
        pcall(function() canvas[1].shadow = nil end)
        canvas:hide()
      end
    end
  end
end

local function startMainLoop()
  stopMainTimer()

  local profileKey = refreshScreens()
  M._spotlightProfileKey = profileKey

  local interval = (effectiveStyle() == "solid") and 0.25 or 0.06

  if (not M.state.enabled) or M.suppressed then
    updateAllCanvases()
    return
  end

  M.anim.timer = hs.timer.doEvery(interval, function()
    M.anim.t = M.anim.t + interval
    if effectiveStyle() == "rainbow" then
      M.anim.hue = (M.anim.hue + interval * 0.80 * ANIM_SPEED) % 1
    end
    updateAllCanvases()
  end)

  updateAllCanvases()
end

local function setEnabled(v)
  if not v then
    stopSpotlightFollow()
  end
  M.state.enabled = v
  settingSet("enabled", v)
  startMainLoop()
  M._menuDirty = true
end

local function setStyle(style)
  M.state.style = style
  settingSet("style", style)
  startMainLoop()
  M._menuDirty = true
end

local function setColor(name)
  M.state.color = name
  settingSet("color", name)
  updateAllCanvases()
  M._menuDirty = true
end

local function setMaterial(name)
  M.state.spotlight_material = name
  settingSet("spotlight_material", name)
  spotlightRender()
  M._menuDirty = true
end

local function setToggle(key, v)
  M.state[key] = v
  settingSet(key, v)
  spotlightRender()
  M._menuDirty = true
end

local function a11ySummaryLine()
  local parts = {}
  if M.a11y.reduceTransparency then parts[#parts+1] = "Reduce Transparency" end
  if M.a11y.increaseContrast then parts[#parts+1] = "Increase Contrast" end
  if M.a11y.reduceMotion then parts[#parts+1] = "Reduce Motion" end
  if #parts == 0 then return "Accessibility: Default" end
  return "Accessibility: " .. table.concat(parts, " • ")
end

local function contextSummaryLine()
  if not M.ctx.suppressed then return "Auto-Hide: Ready" end
  return "Auto-Hide: " .. (M.ctx.reason or "On")
end

local function menuSignature(payload)
  return hs.hash.SHA256(hs.json.encode(payload) or "")
end

local function buildMenu()
  local styleMenu = {}
  for _, key in ipairs(STYLE_ORDER) do
    styleMenu[#styleMenu+1] = {
      title = STYLE_LABELS[key],
      checked = (M.state.style == key),
      fn = function() setStyle(key) end,
    }
  end

  local colorMenu = {}
  for _, name in ipairs(COLOR_ORDER) do
    colorMenu[#colorMenu+1] = {
      title = name,
      checked = (M.state.color == name),
      fn = function() setColor(name) end,
    }
  end

  local materialMenu = {}
  for _, name in ipairs(MATERIAL_ORDER) do
    materialMenu[#materialMenu+1] = {
      title = name,
      checked = (M.state.spotlight_material == name),
      fn = function() setMaterial(name) end,
    }
  end

  local feedbackMenu = {
    {
      title = "Sound",
      checked = M.state.feedback_sound == true,
      fn = function() setToggle("feedback_sound", not M.state.feedback_sound) end,
    },
    {
      title = "Outline Pop",
      checked = M.state.feedback_pop == true,
      fn = function() setToggle("feedback_pop", not M.state.feedback_pop) end,
    },
  }

  local autoHideMenu = {
    {
      title = "In Full-Screen Video",
      checked = M.state.auto_hide_fullscreen_video == true,
      fn = function() setToggle("auto_hide_fullscreen_video", not M.state.auto_hide_fullscreen_video) end,
    },
    {
      title = "During Screen Sharing",
      checked = M.state.auto_hide_screen_sharing == true,
      fn = function() setToggle("auto_hide_screen_sharing", not M.state.auto_hide_screen_sharing) end,
    },
  }

  local spotlightMenu = {
    { title = "Material", menu = materialMenu },
    {
      title = "Dim Tint",
      checked = M.state.dim_tint == true,
      fn = function() setToggle("dim_tint", not M.state.dim_tint) end,
    },
    { title = "-" },
    { title = "Auto-Hide", menu = autoHideMenu },
  }

  local toggleTitle = M.state.enabled and "Disable Cursor Outline" or "Enable Cursor Outline"

  return {
    { title = "Cursor Outline", disabled = true },
    { title = "Hold Ctrl⌥⌘F to spotlight cursor", disabled = true },
    { title = a11ySummaryLine(), disabled = true },
    { title = contextSummaryLine(), disabled = true },
    { title = "-" },
    { title = "Animation", menu = styleMenu },
    { title = "Outline Color", menu = colorMenu },
    { title = "Spotlight", menu = spotlightMenu },
    { title = "Feedback", menu = feedbackMenu },
    { title = "-" },
    { title = toggleTitle, fn = function() setEnabled(not M.state.enabled) end },
  }
end

local function applyMenuIfNeeded()
  if not M._menuDirty then return end
  ensureMenubar()
  if not M.menubar then return end
  if M._menuOpen then return end

  local payload = buildMenu()
  local sig = menuSignature(payload)
  if sig == M._lastMenuSig then
    M._menuDirty = false
    return
  end

  M._lastMenuSig = sig
  M.menubar:setMenu(payload)
  M._menuDirty = false
end

local function markMenuDirty()
  M._menuDirty = true
  if not M._menuApplyTimer then
    M._menuApplyTimer = hs.timer.doAfter(0.08, function()
      M._menuApplyTimer = nil
      applyMenuIfNeeded()
    end)
  end
end

local function startWatchers()
  if M._a11yTimer then
    M._a11yTimer:stop()
    M._a11yTimer = nil
  end

  refreshA11y()
  M._a11yTimer = hs.timer.doEvery(4.0, function()
    local changed = refreshA11y()
    if changed then
      local key = spotlightProfileKey(spotlightProfile())
      if key ~= M._spotlightProfileKey then
        clearAllCanvases()
        M._spotlightProfileKey = refreshScreens()
      end
      startMainLoop()
      markMenuDirty()
    end
  end)

  if M._ctxTimer then
    M._ctxTimer:stop()
    M._ctxTimer = nil
  end

  M._ctxTimer = hs.timer.doEvery(8.0, function()
    local changed = refreshContextSuppression()
    if changed then
      updateAllCanvases()
      markMenuDirty()
    end
  end)
end

local function start()
  ensureMenubar()

  refreshContextSuppression()
  applyMenuIfNeeded()
  startWatchers()

  if M.screenWatcher then
    M.screenWatcher:stop()
    M.screenWatcher = nil
  end
  M.screenWatcher = hs.screen.watcher.new(function()
    hs.timer.doAfter(0.10, function()
      local key = spotlightProfileKey(spotlightProfile())
      if key ~= M._spotlightProfileKey then
        clearAllCanvases()
      end
      startMainLoop()
      markMenuDirty()
    end)
  end)
  M.screenWatcher:start()

  if M.appWatcher then
    M.appWatcher:stop()
    M.appWatcher = nil
  end
  M.appWatcher = hs.application.watcher.new(function(appName, eventType)
    if eventType ~= hs.application.watcher.activated then return end

    local changed = refreshContextSuppression()
    if changed then
      updateAllCanvases()
      markMenuDirty()
    end

    if appName == "Dock" then
      if not M.suppressed then
        M.suppressed = true
        stopSpotlightFollow()
        startMainLoop()
        markMenuDirty()
      end
    else
      if M.suppressed then
        M.suppressed = false
        startMainLoop()
        markMenuDirty()
      end
    end
  end)
  M.appWatcher:start()

  if M.hotkey then
    M.hotkey:delete()
    M.hotkey = nil
  end

  M.hotkey = hs.hotkey.bind({ "cmd", "ctrl", "alt" }, "F",
    function()
      M._hotkeyOverride = true

      local changed = refreshContextSuppression()
      if changed then
        updateAllCanvases()
      end
      markMenuDirty()

      if isEffectivelyAllowed() then
        playSoftHaptic()
        outlinePopAtCursorScreen()
        startSpotlightFollow()
      end
    end,
    function()
      M._hotkeyOverride = false
      stopSpotlightFollow()

      local changed = refreshContextSuppression()
      if changed then
        updateAllCanvases()
      end
      markMenuDirty()
    end
  )

  startMainLoop()
  markMenuDirty()

  if M.menubar then
    pcall(function()
      M.menubar:setClickCallback(function()
        M._menuOpen = true
        hs.timer.doAfter(0.25, function()
          M._menuOpen = false
          applyMenuIfNeeded()
        end)
      end)
    end)
  end
end

start()