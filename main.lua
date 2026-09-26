require "import"
import "android.widget.*"
import "android.view.*"
import "android.speech.tts.TextToSpeech"
import "android.content.Intent"
import "android.content.Context"
import "android.net.Uri"
import "android.media.MediaPlayer"
import "android.os.Handler"
import "android.os.Looper"

math.randomseed(os.time())

local ArrayList = luajava.bindClass("java.util.ArrayList")
local HandlerClass = luajava.bindClass("android.os.Handler")
local LooperClass = luajava.bindClass("android.os.Looper")
local UriClass = luajava.bindClass("android.net.Uri")

local SOUND_PATH = "/storage/emulated/0/Music/gemini_music (8).mp3"

local showMainMenu, showMoreMenu, showSettingMenu, showAbout,
      showGameMenu, showSetup, showToss, doToss,
      chooseBatOrBowl, showDecision, startInnings,
      resolveBall, endInnings, speak, initTTS, showTTSSettings,
      showAnnouncementSettings, showSoundSettings, createTTSListener,
      openInningsDialog, updateGameView, openWhatsApp,
      closeAndOpenWhatsApp, playStartupSound, playTestSound,
      stopSound, exitApp

local state = {
  overs = 1, wickets = 1, innings = 1, battingSide = "user",
  runs = 0, wkts = 0, balls = 0,
  userScore = nil, compScore = nil, firstInningsScore = nil,
  ttsEngine = "", ttsRate = 1.0, ttsPitch = 1.0,
  scoreEvery = 1, requiredEvery = 1, ballAnnounce = true,
}

local ttsEngine = nil
local appCtx = nil
local ttsInitListener = nil
local gameUI = { dialog = nil, titleTV = nil, statusTV = nil, lock = false }

-- ===== Sound =====
local soundMP = nil
local hasPlayedStartup = false

local function playSoundFile(path, volume)
  local mp = MediaPlayer()
  local ok = pcall(function()
    mp.setDataSource(path)
    mp.setVolume(volume, volume)
    mp.prepare()
    mp.start()
  end)
  if not ok then
    pcall(function() mp.release() end)
    return nil
  end
  return mp
end

function stopSound()
  pcall(function()
    if soundMP then
      soundMP.stop()
      soundMP.release()
      soundMP = nil
    end
  end)
end

function playStartupSound()
  if hasPlayedStartup then return end
  hasPlayedStartup = true
  pcall(function()
    if not appCtx then return end
    local prefs = appCtx.getSharedPreferences("game_tts", 0)
    if not prefs.getBoolean("soundEnabled", true) then return end
    local vol = prefs.getFloat("soundVolume", 1.0)
    soundMP = playSoundFile(SOUND_PATH, vol)
  end)
end

function playTestSound()
  pcall(function()
    if not appCtx then return end
    local prefs = appCtx.getSharedPreferences("game_tts", 0)
    local vol = prefs.getFloat("soundVolume", 1.0)
    local enabled = prefs.getBoolean("soundEnabled", true)
    if not enabled then return end
    local mp = playSoundFile(SOUND_PATH, vol)
    if mp then
      local h = HandlerClass(LooperClass.getMainLooper())
      h.postDelayed(luajava.createProxy("java.lang.Runnable", {
        run = function() pcall(function() mp.release() end) end
      }), 4000)
    end
  end)
end

-- ===== Exit / Back =====
function exitApp()
  -- 1. stop sound
  stopSound()
  -- 2. stop TTS
  pcall(function() if ttsEngine then ttsEngine.stop() end end)
  -- 3. dismiss any dialog
  pcall(function()
    if gameUI.dialog then gameUI.dialog.dismiss(); gameUI.dialog = nil end
  end)
  -- 4. finish the plugin activity
  pcall(function()
    if activity and activity.finish then activity.finish() end
  end)
end

-- ===== TTS =====
function createTTSListener()
  return luajava.createProxy("android.speech.tts.TextToSpeech$OnInitListener", {
    onInit = function(status)
      pcall(function()
        if ttsEngine then
          ttsEngine.setSpeechRate(state.ttsRate or 1.0)
          ttsEngine.setPitch(state.ttsPitch or 1.0)
        end
      end)
    end
  })
end

function initTTS(ctx)
  appCtx = ctx
  local prefs = ctx.getSharedPreferences("game_tts", 0)
  state.ttsEngine = prefs.getString("engine", "")
  state.ttsRate = prefs.getFloat("rate", 1.0)
  state.ttsPitch = prefs.getFloat("pitch", 1.0)
  state.scoreEvery = prefs.getInt("scoreEvery", 1)
  state.requiredEvery = prefs.getInt("requiredEvery", 1)
  state.ballAnnounce = prefs.getBoolean("ballAnnounce", true)

  pcall(function()
    if ttsEngine then ttsEngine.stop(); ttsEngine.shutdown() end
  end)
  ttsEngine = nil
  ttsInitListener = createTTSListener()

  pcall(function()
    if state.ttsEngine and state.ttsEngine ~= "" then
      ttsEngine = TextToSpeech(ctx, ttsInitListener, state.ttsEngine)
    else
      ttsEngine = TextToSpeech(ctx, ttsInitListener)
    end
  end)
end

function speak(text)
  pcall(function()
    if ttsEngine then
      ttsEngine.setSpeechRate(state.ttsRate or 1.0)
      ttsEngine.setPitch(state.ttsPitch or 1.0)
      ttsEngine.speak(text, 0, nil)
    end
  end)
end

-- ===== WhatsApp =====
function openWhatsApp()
  local number = "+923439840305"
  local msg = "Assalam o Alaikum, main amazing game bro use kar raha hoon."
  local digits = number:gsub("[^%d]", "")
  pcall(function()
    local url = "https://wa.me/" .. digits .. "?text=" .. Uri.encode(msg)
    local intent = Intent(Intent.ACTION_VIEW)
    intent.setData(UriClass.parse(url))
    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    appCtx.startActivity(intent)
  end)
end

function closeAndOpenWhatsApp()
  stopSound()
  pcall(function() if ttsEngine then ttsEngine.stop() end end)
  pcall(function()
    if gameUI.dialog then gameUI.dialog.dismiss(); gameUI.dialog = nil end
  end)

  local activityToFinish = activity
  pcall(function()
    if not activityToFinish and appCtx then activityToFinish = appCtx end
  end)

  local h = HandlerClass(LooperClass.getMainLooper())
  h.postDelayed(luajava.createProxy("java.lang.Runnable", {
    run = function()
      pcall(function()
        if activityToFinish and activityToFinish.finish then
          activityToFinish.finish()
        end
      end)
      local h2 = HandlerClass(LooperClass.getMainLooper())
      h2.postDelayed(luajava.createProxy("java.lang.Runnable", {
        run = function() openWhatsApp() end
      }), 400)
    end
  }), 200)
end

-- ================= Main Menu =================
function showMainMenu()
  local dlg = LuaDialog()
  dlg.setTitle("amazing game bro")
  local layout = {
    LinearLayout; orientation = "vertical"; padding = "30dp";
    { Button; text = "Developer Mohammad Haseeb"; textSize = "16sp"; layout_marginBottom = "15dp"; onClick = function() end; };
    { Button; text = "Play Games"; textSize = "16sp"; layout_marginBottom = "15dp";
      onClick = function() dlg.dismiss(); showGameMenu() end; };
    { Button; text = "More Option"; textSize = "16sp"; layout_marginBottom = "15dp";
      onClick = function() dlg.dismiss(); showMoreMenu() end; };
    { Button; text = "Back"; textSize = "16sp"; layout_marginBottom = "15dp";
      onClick = function()
        dlg.dismiss()
        exitApp()
      end; };
    { Button; text = "Exit"; textSize = "16sp";
      onClick = function()
        dlg.dismiss()
        exitApp()
      end; };
  }
  local view = loadlayout(layout)
  dlg.setView(view); dlg.show()
  if not appCtx then initTTS(view.getContext()) end
  playStartupSound()
end

-- ================= More Option =================
function showMoreMenu()
  local dlg = LuaDialog()
  dlg.setTitle("More Option")
  local layout = {
    LinearLayout; orientation = "vertical"; padding = "30dp";
    { Button; text = "About and Support"; textSize = "16sp"; layout_marginBottom = "15dp";
      onClick = function() dlg.dismiss(); showAbout() end; };
    { Button; text = "Contact Developer"; textSize = "16sp"; layout_marginBottom = "15dp";
      onClick = function() dlg.dismiss(); closeAndOpenWhatsApp() end; };
    { Button; text = "Setting"; textSize = "16sp"; layout_marginBottom = "15dp";
      onClick = function() dlg.dismiss(); showSettingMenu() end; };
    { Button; text = "Back"; textSize = "16sp";
      onClick = function() dlg.dismiss(); showMainMenu() end; };
  }
  dlg.setView(loadlayout(layout)); dlg.show()
end

function showSettingMenu()
  local dlg = LuaDialog()
  dlg.setTitle("Setting")
  local layout = {
    LinearLayout; orientation = "vertical"; padding = "30dp";
    { Button; text = "TTS Setting"; textSize = "16sp"; layout_marginBottom = "15dp";
      onClick = function() dlg.dismiss(); showTTSSettings() end; };
    { Button; text = "Announcement Setting"; textSize = "16sp"; layout_marginBottom = "15dp";
      onClick = function() dlg.dismiss(); showAnnouncementSettings() end; };
    { Button; text = "Sound Setting"; textSize = "16sp"; layout_marginBottom = "15dp";
      onClick = function() dlg.dismiss(); showSoundSettings() end; };
    { Button; text = "Back"; textSize = "16sp";
      onClick = function() dlg.dismiss(); showMoreMenu() end; };
  }
  dlg.setView(loadlayout(layout)); dlg.show()
end

-- ================= Sound Setting =================
function showSoundSettings()
  if not appCtx then return end
  local prefs = appCtx.getSharedPreferences("game_tts", 0)
  local curEnabled = prefs.getBoolean("soundEnabled", true)
  local curVol = prefs.getFloat("soundVolume", 1.0)

  local dlg = LuaDialog()
  dlg.setTitle("Sound Setting")
  local layout = {
    LinearLayout; orientation = "vertical"; padding = "15dp";
    { CheckBox; id = "cbSound"; text = "Sound ON (background music)"; textSize = "14sp"; layout_marginBottom = "10dp"; };
    { TextView; text = "Volume"; textSize = "14sp"; };
    { SeekBar; id = "seekVol"; layout_width = "match_parent"; max = 100; progress = math.floor(curVol * 100); layout_marginBottom = "3dp"; };
    { TextView; id = "labelVol"; text = "Volume: " .. math.floor(curVol * 100) .. "%"; textSize = "12sp"; layout_marginBottom = "10dp"; };
    { Button; text = "Test Sound"; textSize = "14sp"; layout_marginBottom = "5dp";
      onClick = function()
        local v = seekVol.getProgress() / 100.0
        local en = cbSound.isChecked()
        local e = prefs.edit(); e.putFloat("soundVolume", v); e.putBoolean("soundEnabled", en); e.apply()
        if en then playTestSound() end
      end; };
    { Button; text = "Save"; textSize = "14sp"; layout_marginBottom = "5dp";
      onClick = function()
        local v = seekVol.getProgress() / 100.0
        local en = cbSound.isChecked()
        local e = prefs.edit()
        e.putFloat("soundVolume", v)
        e.putBoolean("soundEnabled", en)
        e.apply()
        speak("Sound settings saved")
      end; };
    { Button; text = "Back"; textSize = "14sp";
      onClick = function() dlg.dismiss(); showSettingMenu() end; };
  }
  local view = loadlayout(layout)
  dlg.setView(view); dlg.show()

  cbSound.setChecked(curEnabled)

  local vl = luajava.createProxy("android.widget.SeekBar$OnSeekBarChangeListener", {
    onProgressChanged = function(sb, progress, fromUser)
      pcall(function() labelVol.setText("Volume: " .. progress .. "%") end)
    end,
    onStartTrackingTouch = function(sb) end, onStopTrackingTouch = function(sb) end
  })
  seekVol.setOnSeekBarChangeListener(vl)
end

-- ================= About and Support =================
function showAbout()
  local aboutText =
    "About and Support\n\n" ..
    "Ye game 'amazing game bro' Hand Cricket ka ek simple aur mazedaar version hai. " ..
    "Isme aap computer ke khilaf khelte hain aur har ball par 1 se 6 tak koi number select karte hain.\n\n" ..
    "Kaise khelein:\n" ..
    "1) Play Games par click karein, phir Hand Cricket chunein.\n" ..
    "2) Overs (1 se 10) aur Wickets (1 se 10) select karein.\n" ..
    "3) Play dabayein, phir Toss ke liye Head ya Tail chunein.\n" ..
    "4) Toss jeetne par aap Batting ya Bowling chun sakte hain.\n" ..
    "5) Har ball par 1 se 6 tak number dabayein.\n" ..
    "6) Agar aap ka aur computer ka number same ho jaye to batsman OUT ho jata hai, " ..
    "warna aap ka number runs ke tor par count hota hai.\n" ..
    "7) Pehli innings ke baad target set hota hai aur dusri innings shuru hoti hai.\n\n" ..
    "TTS (Text To Speech) Setting:\n" ..
    "Yahan se aap apni pasand ka TTS engine, speed aur pitch select kar sakte hain.\n\n" ..
    "Announcement Setting:\n" ..
    "Yahan se aap control karte hain ke score kitni ballon ke baad announce ho, " ..
    "required runs kitni ballon ke baad batayein, aur balls remaining ka announcement " ..
    "ON ya OFF rakhna hai.\n\n" ..
    "Sound Setting:\n" ..
    "Yahan se background music ON ya OFF kar sakte hain aur uski volume " ..
    "(0 se 100%) apni marzi se set kar sakte hain.\n\n" ..
    "Mazeed madad ke liye More Option me 'Contact Developer' par click karein."

  local dlg = LuaDialog()
  dlg.setTitle("About and Support")
  local layout = {
    LinearLayout; orientation = "vertical"; padding = "15dp";
    { ScrollView; layout_width = "match_parent"; layout_height = "450dp";
      { TextView; id = "aboutTV"; text = aboutText; textSize = "14sp"; }; };
    { Button; text = "Back"; textSize = "15sp"; layout_marginTop = "10dp";
      onClick = function() dlg.dismiss(); showMoreMenu() end; };
  }
  dlg.setView(loadlayout(layout)); dlg.show()
end

-- ================= TTS Setting =================
function showTTSSettings()
  if not appCtx then return end
  if not ttsEngine then initTTS(appCtx) end

  local engineLabels = ArrayList()
  local engineNames = ArrayList()
  engineLabels.add("Default (System)")
  engineNames.add("")

  pcall(function()
    if ttsEngine then
      local engines = ttsEngine.getEngines()
      if engines then
        for i = 0, engines.size() - 1 do
          local info = engines.get(i)
          local nm = tostring(info.name)
          local lb = tostring(info.label)
          if lb == "" or lb == "nil" then lb = nm end
          engineLabels.add(lb); engineNames.add(nm)
        end
      end
    end
  end)

  local prefs = appCtx.getSharedPreferences("game_tts", 0)
  local curEngine = prefs.getString("engine", "")
  local curRate = prefs.getFloat("rate", 1.0)
  local curPitch = prefs.getFloat("pitch", 1.0)

  local dlg = LuaDialog()
  dlg.setTitle("TTS Setting")
  local layout = {
    LinearLayout; orientation = "vertical"; padding = "15dp";
    { TextView; text = "Select TTS Engine"; textSize = "14sp"; };
    { Spinner; id = "spinnerEngine"; layout_width = "match_parent"; layout_marginBottom = "10dp"; };
    { TextView; text = "Speed (Rate)"; textSize = "14sp"; };
    { SeekBar; id = "seekRate"; layout_width = "match_parent"; max = 200; progress = math.floor(curRate * 100); layout_marginBottom = "3dp"; };
    { TextView; id = "labelRate"; text = "Rate: " .. string.format("%.2f", curRate); textSize = "12sp"; layout_marginBottom = "10dp"; };
    { TextView; text = "Pitch"; textSize = "14sp"; };
    { SeekBar; id = "seekPitch"; layout_width = "match_parent"; max = 200; progress = math.floor(curPitch * 100); layout_marginBottom = "3dp"; };
    { TextView; id = "labelPitch"; text = "Pitch: " .. string.format("%.2f", curPitch); textSize = "12sp"; layout_marginBottom = "10dp"; };
    { Button; text = "Test Voice"; textSize = "14sp"; layout_marginBottom = "5dp";
      onClick = function()
        local r = seekRate.getProgress() / 100.0
        local p = seekPitch.getProgress() / 100.0
        pcall(function()
          if ttsEngine then
            ttsEngine.setSpeechRate(r); ttsEngine.setPitch(p)
            ttsEngine.speak("This is a test of text to speech settings.", 0, nil)
          end
        end)
      end; };
    { Button; text = "Save"; textSize = "14sp"; layout_marginBottom = "5dp";
      onClick = function()
        local idx = spinnerEngine.getSelectedItemPosition(); if idx < 0 then idx = 0 end
        local engName = engineNames.get(idx)
        local r = seekRate.getProgress() / 100.0
        local p = seekPitch.getProgress() / 100.0
        local e = prefs.edit()
        e.putString("engine", engName); e.putFloat("rate", r); e.putFloat("pitch", p); e.apply()
        state.ttsEngine = engName; state.ttsRate = r; state.ttsPitch = p
        initTTS(appCtx); speak("Settings saved")
      end; };
    { Button; text = "Back"; textSize = "14sp";
      onClick = function() dlg.dismiss(); showSettingMenu() end; };
  }
  local view = loadlayout(layout)
  dlg.setView(view); dlg.show()

  local adapter = ArrayAdapter(appCtx, android.R.layout.simple_spinner_item, engineLabels)
  adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
  spinnerEngine.setAdapter(adapter)
  for i = 0, engineNames.size() - 1 do
    if engineNames.get(i) == curEngine then spinnerEngine.setSelection(i); break end
  end

  local rl = luajava.createProxy("android.widget.SeekBar$OnSeekBarChangeListener", {
    onProgressChanged = function(sb, progress, fromUser)
      pcall(function() labelRate.setText("Rate: " .. string.format("%.2f", progress / 100.0)) end)
    end,
    onStartTrackingTouch = function(sb) end, onStopTrackingTouch = function(sb) end
  })
  seekRate.setOnSeekBarChangeListener(rl)

  local pl = luajava.createProxy("android.widget.SeekBar$OnSeekBarChangeListener", {
    onProgressChanged = function(sb, progress, fromUser)
      pcall(function() labelPitch.setText("Pitch: " .. string.format("%.2f", progress / 100.0)) end)
    end,
    onStartTrackingTouch = function(sb) end, onStopTrackingTouch = function(sb) end
  })
  seekPitch.setOnSeekBarChangeListener(pl)
end

-- ================= Announcement Setting =================
function showAnnouncementSettings()
  if not appCtx then return end
  if not ttsEngine then initTTS(appCtx) end

  local prefs = appCtx.getSharedPreferences("game_tts", 0)

  local scoreList = ArrayList()
  local requiredList = ArrayList()
  for i = 1, 6 do
    scoreList.add("Every " .. i .. " ball")
    requiredList.add("Every " .. i .. " ball")
  end

  local dlg = LuaDialog()
  dlg.setTitle("Announcement Setting")
  local layout = {
    LinearLayout; orientation = "vertical"; padding = "15dp";
    { TextView; text = "Select the score announcement"; textSize = "14sp"; };
    { Spinner; id = "spScore"; layout_width = "match_parent"; layout_marginBottom = "10dp"; };
    { TextView; text = "Select required announcement"; textSize = "14sp"; };
    { Spinner; id = "spRequired"; layout_width = "match_parent"; layout_marginBottom = "10dp"; };
    { CheckBox; id = "cbBall"; text = "Ball announcement (balls remaining)"; textSize = "14sp"; layout_marginBottom = "10dp"; };
    { Button; text = "Save"; textSize = "14sp"; layout_marginBottom = "5dp";
      onClick = function()
        local sIdx = spScore.getSelectedItemPosition()
        local rIdx = spRequired.getSelectedItemPosition()
        if sIdx < 0 then sIdx = 0 end
        if rIdx < 0 then rIdx = 0 end
        local sv = sIdx + 1
        local rv = rIdx + 1
        local bv = cbBall.isChecked()

        local e = prefs.edit()
        e.putInt("scoreEvery", sv)
        e.putInt("requiredEvery", rv)
        e.putBoolean("ballAnnounce", bv)
        e.apply()

        state.scoreEvery = sv
        state.requiredEvery = rv
        state.ballAnnounce = bv

        speak("Announcement settings saved")
      end; };
    { Button; text = "Back"; textSize = "14sp";
      onClick = function() dlg.dismiss(); showSettingMenu() end; };
  }
  local view = loadlayout(layout)
  dlg.setView(view); dlg.show()

  local a1 = ArrayAdapter(appCtx, android.R.layout.simple_spinner_item, scoreList)
  a1.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
  spScore.setAdapter(a1)

  local a2 = ArrayAdapter(appCtx, android.R.layout.simple_spinner_item, requiredList)
  a2.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
  spRequired.setAdapter(a2)

  local sv = prefs.getInt("scoreEvery", 1)
  local rv = prefs.getInt("requiredEvery", 1)
  local bv = prefs.getBoolean("ballAnnounce", true)
  if sv < 1 then sv = 1 end; if sv > 6 then sv = 6 end
  if rv < 1 then rv = 1 end; if rv > 6 then rv = 6 end
  spScore.setSelection(sv - 1)
  spRequired.setSelection(rv - 1)
  cbBall.setChecked(bv)
end

-- ================= Play Games =================
function showGameMenu()
  local dlg = LuaDialog()
  dlg.setTitle("Play Games")
  local layout = {
    LinearLayout; orientation = "vertical"; padding = "30dp";
    { Button; text = "Hand Cricket"; textSize = "16sp"; layout_marginBottom = "15dp";
      onClick = function() dlg.dismiss(); showSetup() end; };
    { Button; text = "Back"; textSize = "16sp";
      onClick = function() dlg.dismiss(); showMainMenu() end; };
  }
  dlg.setView(loadlayout(layout)); dlg.show()
end

-- ================= Setup =================
function showSetup()
  local oversList = ArrayList()
  local wicketsList = ArrayList()
  for i = 1, 10 do
    oversList.add(tostring(i)); wicketsList.add(tostring(i))
  end

  local dlg = LuaDialog()
  dlg.setTitle("Hand Cricket - Setup")
  local layout = {
    LinearLayout; orientation = "vertical"; padding = "20dp";
    { TextView; text = "Select Overs"; textSize = "16sp"; };
    { Spinner; id = "spinnerOvers"; layout_width = "match_parent"; layout_marginBottom = "15dp"; };
    { TextView; text = "Select Wickets"; textSize = "16sp"; };
    { Spinner; id = "spinnerWickets"; layout_width = "match_parent"; layout_marginBottom = "15dp"; };
    { Button; text = "Play"; textSize = "16sp";
      onClick = function()
        state.overs = tonumber(tostring(spinnerOvers.getSelectedItem()))
        state.wickets = tonumber(tostring(spinnerWickets.getSelectedItem()))
        dlg.dismiss(); showToss()
      end; };
  }
  local view = loadlayout(layout)
  dlg.setView(view); dlg.show()

  local ctx = view.getContext()
  if not appCtx then initTTS(ctx) end

  local a1 = ArrayAdapter(ctx, android.R.layout.simple_spinner_item, oversList)
  a1.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
  spinnerOvers.setAdapter(a1)

  local a2 = ArrayAdapter(ctx, android.R.layout.simple_spinner_item, wicketsList)
  a2.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
  spinnerWickets.setAdapter(a2)
end

-- ================= Toss =================
function showToss()
  speak("Toss time. Choose head or tail.")
  local dlg = LuaDialog()
  dlg.setTitle("Toss")
  local layout = {
    LinearLayout; orientation = "vertical"; padding = "20dp";
    { TextView; text = "Choose Head or Tail"; textSize = "18sp"; layout_marginBottom = "15dp"; };
    { Button; text = "Head"; textSize = "16sp"; layout_marginBottom = "10dp";
      onClick = function() dlg.dismiss(); doToss("Head") end; };
    { Button; text = "Tail"; textSize = "16sp";
      onClick = function() dlg.dismiss(); doToss("Tail") end; };
  }
  dlg.setView(loadlayout(layout)); dlg.show()
end

function doToss(userCall)
  local flip = (math.random(1, 2) == 1) and "Head" or "Tail"
  local userWon = (flip == userCall)
  local msg = "You chose " .. userCall .. ", and the flip result is " .. flip .. ". "
  msg = msg .. (userWon and "You won the toss." or "Computer won the toss.")
  speak(msg)

  local dlg = LuaDialog()
  dlg.setTitle("Toss Result")
  local layout = {
    LinearLayout; orientation = "vertical"; padding = "20dp";
    { TextView; text = msg; textSize = "16sp"; layout_marginBottom = "15dp"; };
    { Button; text = "Continue"; textSize = "16sp";
      onClick = function()
        dlg.dismiss()
        if userWon then chooseBatOrBowl()
        else
          local compBats = (math.random(1, 2) == 1)
          if compBats then showDecision("Computer chose batting.", false)
          else showDecision("Computer chose bowling.", true) end
        end
      end; };
  }
  dlg.setView(loadlayout(layout)); dlg.show()
end

function chooseBatOrBowl()
  local dlg = LuaDialog()
  dlg.setTitle("Choose")
  local layout = {
    LinearLayout; orientation = "vertical"; padding = "20dp";
    { TextView; text = "What do you want to do?"; textSize = "16sp"; layout_marginBottom = "15dp"; };
    { Button; text = "Batting"; textSize = "16sp"; layout_marginBottom = "10dp";
      onClick = function()
        dlg.dismiss(); state.innings = 1; state.battingSide = "user"; startInnings()
      end; };
    { Button; text = "Bowling"; textSize = "16sp";
      onClick = function()
        dlg.dismiss(); state.innings = 1; state.battingSide = "comp"; startInnings()
      end; };
  }
  dlg.setView(loadlayout(layout)); dlg.show()
end

function showDecision(text, userBatting)
  speak(text)
  local dlg = LuaDialog()
  dlg.setTitle("Toss Result")
  local layout = {
    LinearLayout; orientation = "vertical"; padding = "20dp";
    { TextView; text = text; textSize = "16sp"; layout_marginBottom = "15dp"; };
    { Button; text = "OK"; textSize = "16sp";
      onClick = function()
        dlg.dismiss(); state.innings = 1
        state.battingSide = userBatting and "user" or "comp"
        startInnings()
      end; };
  }
  dlg.setView(loadlayout(layout)); dlg.show()
end

-- ================= Innings =================
function startInnings()
  state.runs = 0; state.wkts = 0; state.balls = 0
  openInningsDialog()

  if state.innings == 2 then
    local target = (state.firstInningsScore or 0) + 1
    local maxBalls = state.overs * 6
    local whoBats = (state.battingSide == "user") and "You are batting." or "Computer is batting."
    speak("Second innings. " .. whoBats .. " Target is " .. target ..
      " runs from " .. maxBalls .. " balls. Pick a number from 1 to 6.")
  else
    local whoBats = (state.battingSide == "user") and "You are batting." or "Computer is batting."
    speak("First innings. " .. whoBats .. " " .. state.overs .. " overs and " ..
      state.wickets .. " wickets. Pick a number from 1 to 6.")
  end
end

function openInningsDialog()
  if gameUI.dialog then
    pcall(function() gameUI.dialog.dismiss() end)
    gameUI.dialog = nil
  end

  local dlg = LuaDialog()
  local layout = {
    LinearLayout; orientation = "vertical"; padding = "15dp";
    { TextView; id = "gameTitle"; text = ""; textSize = "16sp"; layout_marginBottom = "8dp"; };
    { TextView; id = "gameStatus"; text = ""; textSize = "14sp"; layout_marginBottom = "10dp"; };
  }
  for i = 1, 6 do
    local n = i
    layout[#layout + 1] = {
      Button; text = tostring(n); textSize = "16sp"; layout_marginBottom = "5dp";
      onClick = function()
        if gameUI.lock then return end
        gameUI.lock = true
        resolveBall(n)
        gameUI.lock = false
      end;
    }
  end
  local view = loadlayout(layout)
  dlg.setView(view)
  gameUI.dialog = dlg
  gameUI.titleTV = gameTitle
  gameUI.statusTV = gameStatus
  dlg.show()
  updateGameView()
end

function updateGameView()
  if not gameUI.titleTV or not gameUI.statusTV then return end
  local title = (state.battingSide == "user") and "Your Batting - Pick 1 to 6" or "Your Bowling - Pick 1 to 6"
  local oversDisplay = math.floor(state.balls / 6) .. "." .. (state.balls % 6)
  local maxBalls = state.overs * 6
  local ballsLeft = maxBalls - state.balls
  local wktsLeft = state.wickets - state.wkts

  local status = ""
  if state.innings == 2 and state.firstInningsScore then
    local target = state.firstInningsScore + 1
    local need = target - state.runs
    if need < 0 then need = 0 end
    status = "Target: " .. target .. "   Need: " .. need .. "\n"
  end
  status = status .. "Score: " .. state.runs .. "/" .. state.wkts .. "\n"
  status = status .. "Overs: " .. oversDisplay .. "/" .. state.overs .. "\n"
  status = status .. "Balls left: " .. ballsLeft .. "   Wickets left: " .. wktsLeft

  pcall(function() gameUI.titleTV.setText(title) end)
  pcall(function() gameUI.statusTV.setText(status) end)
end

function resolveBall(userNum)
  local compNum = math.random(1, 6)
  local battingIsUser = (state.battingSide == "user")
  local batNum, bowlNum
  if battingIsUser then batNum = userNum; bowlNum = compNum
  else batNum = compNum; bowlNum = userNum end

  local out = (batNum == bowlNum)
  local runsScored = out and 0 or batNum

  if out then state.wkts = state.wkts + 1
  else state.runs = state.runs + runsScored end
  state.balls = state.balls + 1

  local s
  if battingIsUser then
    s = "You played " .. batNum .. " and computer played " .. bowlNum .. ". "
  else
    s = "Computer played " .. batNum .. " and you played " .. bowlNum .. ". "
  end
  if out then
    s = s .. (battingIsUser and "You are out. " or "Computer is out. ")
  else
    s = s .. runsScored .. " runs. "
  end

  local maxBalls = state.overs * 6
  local ballsLeft = maxBalls - state.balls
  local wktsLeft = state.wickets - state.wkts

  local scoreEvery = state.scoreEvery or 1
  if scoreEvery < 1 then scoreEvery = 1 end
  if state.balls % scoreEvery == 0 then
    s = s .. "Your score is " .. state.runs .. " for " .. state.wkts .. ". "
  end

  if state.ballAnnounce then
    s = s .. ballsLeft .. " balls remaining and " .. wktsLeft .. " wickets remaining. "
  end

  local chaseDone = false
  if state.innings == 2 and state.firstInningsScore then
    local target = state.firstInningsScore + 1
    local need = target - state.runs
    local requiredEvery = state.requiredEvery or 1
    if requiredEvery < 1 then requiredEvery = 1 end
    if need <= 0 then
      chaseDone = true
    elseif not out and state.balls % requiredEvery == 0 then
      s = s .. "You need " .. need .. " runs from " .. ballsLeft .. " balls."
    end
  end

  speak(s)
  updateGameView()

  local allOut = state.wkts >= state.wickets
  local oversDone = state.balls >= maxBalls

  if allOut or oversDone or chaseDone then
    local h = HandlerClass(LooperClass.getMainLooper())
    h.postDelayed(luajava.createProxy("java.lang.Runnable", {
      run = function()
        if gameUI.dialog then
          pcall(function() gameUI.dialog.dismiss() end)
          gameUI.dialog = nil
        end
        endInnings()
      end
    }), 2500)
  end
end

function endInnings()
  if state.battingSide == "user" then state.userScore = state.runs
  else state.compScore = state.runs end

  if state.innings == 1 then
    state.firstInningsScore = state.runs
    local firstBattingSide = state.battingSide

    local msg
    if firstBattingSide == "user" then
      msg = "Your innings ended. Score " .. state.runs .. " for " .. state.wkts ..
        " in " .. math.floor(state.balls / 6) .. " overs and " .. (state.balls % 6) .. " balls."
    else
      msg = "Computer innings ended. Score " .. state.runs .. " for " .. state.wkts ..
        " in " .. math.floor(state.balls / 6) .. " overs and " .. (state.balls % 6) .. " balls."
    end
    speak(msg .. " Target is " .. (state.runs + 1) .. " runs.")

    local dlg = LuaDialog()
    dlg.setTitle("Innings Break")
    local layout = {
      LinearLayout; orientation = "vertical"; padding = "20dp";
      { TextView; text = msg .. "\n\nTarget: " .. (state.runs + 1) .. " runs";
        textSize = "16sp"; layout_marginBottom = "15dp"; };
      { Button; text = "Start 2nd Innings"; textSize = "16sp";
        onClick = function()
          dlg.dismiss()
          state.innings = 2
          state.battingSide = (firstBattingSide == "user") and "comp" or "user"
          startInnings()
        end; };
    }
    dlg.setView(loadlayout(layout)); dlg.show()
  else
    local userScore = state.userScore or 0
    local compScore = state.compScore or 0
    local result
    if userScore > compScore then result = "You won!"
    elseif compScore > userScore then result = "Computer won!"
    else result = "Match tied!" end

    local msg = "Match Over\n\nYour score: " .. userScore ..
      "\nComputer score: " .. compScore .. "\n\n" .. result
    speak("Match over. " .. result .. " Your score " .. userScore .. " and computer score " .. compScore .. ".")

    local dlg = LuaDialog()
    dlg.setTitle("Result")
    local layout = {
      LinearLayout; orientation = "vertical"; padding = "20dp";
      { TextView; text = msg; textSize = "16sp"; layout_marginBottom = "15dp"; };
      { Button; text = "Back to Menu"; textSize = "16sp";
        onClick = function() dlg.dismiss(); showMainMenu() end; };
    }
    dlg.setView(loadlayout(layout)); dlg.show()
  end
end

-- ================= Start =================
showMainMenu()