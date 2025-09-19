-- auto_dir_enqueue.lua
-- Erweiterung als Interface: ergänzt automatisch den vorherigen und nächsten Titel
-- aus demselben Verzeichnis der aktuell abgespielten Datei (ohne Wrap-Around).

local app_name = "AutoDirEnqueue"
local media_extensions = {
  ".mp4", ".mkv", ".avi", ".mov", ".mp3", ".flac", ".m4v", ".wmv", ".mpeg", ".mpg", ".webm", ".m2ts", ".ts"
}

local last_processed_uri = nil
vlc.msg.err("auto_dir_enqueue: loaded")

-- Diagnose: welche Kernobjekte sind verfügbar?
vlc.msg.err("auto_dir_enqueue: has vlc.input=" .. tostring(type(vlc.input)))
vlc.msg.err("auto_dir_enqueue: has vlc.playlist=" .. tostring(type(vlc.playlist)))
vlc.msg.err("auto_dir_enqueue: has vlc.misc=" .. tostring(type(vlc.misc)))

local function dump_table(label, t, max)
  max = max or 100
  vlc.msg.err(label .. ": type=" .. tostring(type(t)))
  if type(t) ~= "table" then return end
  local n = 0
  for k,v in pairs(t) do
    n = n + 1
    if n <= max then
      vlc.msg.err((label .. ":[%s]=%s"):format(tostring(k), tostring(type(v))))
    end
  end
  vlc.msg.err(label .. ": keys=" .. tostring(n))
end

local function log_environment()
  dump_table("env.vlc", vlc, 80)
  dump_table("env.vlc.input", vlc.input, 80)
  dump_table("env.vlc.playlist", vlc.playlist, 80)
  dump_table("env.vlc.strings", vlc.strings, 80)
  dump_table("env.vlc.io", vlc.io, 80)
  dump_table("env.vlc.net", vlc.net, 80)
  dump_table("env.vlc.var", vlc.var, 80)
  dump_table("env.vlc.misc", vlc.misc, 80)

  local ok, res
  ok, res = pcall(function()
    local node = vlc.playlist and vlc.playlist.get and vlc.playlist.get("normal", false) or nil
    local count = (node and node.children) and #node.children or 0
    vlc.msg.err("env.playlist.children=" .. tostring(count))
  end)
  if not ok then vlc.msg.err("env.playlist.get failed: " .. tostring(res)) end

  ok, res = pcall(function()
    local it = vlc.input and vlc.input.item and vlc.input.item() or nil
    vlc.msg.err("env.input.item.present=" .. tostring(it ~= nil))
    if it and it.uri then
      local u = it:uri()
      vlc.msg.err("env.input.uri=" .. tostring(u))
    end
  end)
  if not ok then vlc.msg.err("env.input.item failed: " .. tostring(res)) end
end

local function get_playlist_length()
  local node = vlc.playlist.get("normal", false)
  if not node or not node.children then
    return 0
  end
  return #node.children
end

local function is_windows()
  return vlc.win ~= nil
end

local function get_directory_path(item)
  local dir_uri = item:uri():match("(.*[/\\])")
  local decoded = vlc.strings.decode_uri(dir_uri)
  if is_windows() then
    return decoded:gsub("file:///", "")
  else
    return decoded:gsub("file://", "")
  end
end

local function get_file_name(item)
  local file_name = item:uri():match("([^/\\]*)$")
  return vlc.strings.decode_uri(file_name)
end

local function is_file_extension_valid(file_path)
  local ext = file_path:match("(%.[^%.]*)$")
  if not ext then return false end
  for _, v in ipairs(media_extensions) do
    if v:lower() == ext:lower() then return true end
  end
  return false
end

local function get_playlist_path_set()
  local set = {}
  local node = vlc.playlist.get("normal", false)
  if node and node.children then
    for _, child in ipairs(node.children) do
      if child.path then set[child.path] = true end
    end
  end
  return set
end

local function list_sorted_files(dir_path)
  local files = {}
  local ok, res = pcall(function()
    local list = vlc.net.opendir(dir_path)
    if not list then return end
    for _, f in pairs(list) do
      if is_file_extension_valid(f) then table.insert(files, f) end
    end
  end)
  if not ok then
    vlc.msg.err("auto_dir_enqueue: readdir failed: " .. tostring(res) .. "; dir_path=" .. tostring(dir_path))
  end
  table.sort(files)
  return files
end

local function make_uri_for_file(dir_path, file_name)
  if is_windows() then
    return "file:///" .. dir_path .. file_name
  else
    return vlc.strings.make_uri(dir_path .. file_name, "file")
  end
end

local function clean_playlist_except_current()
  local current_id = vlc.playlist.current()
  if not current_id then return false end
  local playlist = vlc.playlist.get("playlist")
  if not playlist or not playlist.children then return false end
  for _, item in pairs(playlist.children) do
    if item.id and item.id ~= current_id then
      vlc.playlist.delete(item.id)
    end
  end
  return true
end

local function move_last_to_first()
  local playlist = vlc.playlist.get("playlist")
  if not playlist or not playlist.id or not playlist.children or #playlist.children < 2 then return end
  vlc.playlist.move(playlist.children[#playlist.children].id, playlist.id)
end

local function try_enqueue_neighbors_for_item(item)
  local dir_path = get_directory_path(item)
  local file_name = get_file_name(item)
  local names = list_sorted_files(dir_path)
  if #names < 2 then
    vlc.msg.err("auto_dir_enqueue: no adjacent media files in dir: " .. tostring(dir_path))
    return
  end

  -- Index der aktuellen Datei finden
  local idx = nil
  for i, n in ipairs(names) do
    if n == file_name then idx = i; break end
  end
  if not idx then
    vlc.msg.err("auto_dir_enqueue: current file not found in dir listing: " .. file_name)
    return
  end

  -- Playlist bereinigen (nur aktueller Eintrag bleibt)
  clean_playlist_except_current()

  local count = #names

  -- Vorherigen hinzufügen (mit Wrap-Around nur wenn >=3, analog example.lua)
  if names[idx - 1] then
    vlc.playlist.enqueue({ { path = make_uri_for_file(dir_path, names[idx-1]) } })
    move_last_to_first()
  elseif count >= 3 then
    vlc.playlist.enqueue({ { path = make_uri_for_file(dir_path, names[count]) } })
    move_last_to_first()
  end

  -- Nächsten hinzufügen (mit Wrap-Around nur wenn >=3, analog example.lua)
  if names[idx + 1] then
    vlc.playlist.enqueue({ { path = make_uri_for_file(dir_path, names[idx+1]) } })
  elseif count >= 3 then
    vlc.playlist.enqueue({ { path = make_uri_for_file(dir_path, names[1]) } })
  end
end

local function run_loop()
  vlc.msg.err("auto_dir_enqueue: run_loop start")
  local last_uri = nil
  local heartbeat = 0
  while true do
    local it = vlc.input and vlc.input.item and vlc.input.item() or nil
    local uri = it and it:uri() or nil

    if uri ~= last_uri then
      last_uri = uri
      vlc.msg.err("auto_dir_enqueue: input uri changed to: " .. tostring(uri))
      if uri then
        if last_processed_uri ~= uri then
          last_processed_uri = uri
          try_enqueue_neighbors_for_item(it)
          vlc.msg.err("auto_dir_enqueue: playlist length now: " .. tostring(get_playlist_length()))
          -- Meta setzen, um Mehrfachverarbeitung zu vermeiden
          local ok = pcall(function() it:set_meta(app_name, "processed") end)
          if not ok then vlc.msg.dbg("auto_dir_enqueue: set_meta failed (ignored)") end
        end
      end
    end

    heartbeat = heartbeat + 1
    if heartbeat % 10 == 0 then
      vlc.msg.err("auto_dir_enqueue: alive; uri=" .. tostring(last_uri) .. "; len=" .. tostring(get_playlist_length()))
    end

    if vlc.misc and vlc.misc.mdate and vlc.misc.mwait then
      vlc.misc.mwait(vlc.misc.mdate() + 300000)
    end
  end
end

-- Ergänzt bei Einzeldatei die Wiedergabeliste automatisch um den gesamten Ordner,
-- sodass "Nächster/Vorheriger Titel" alphanumerisch im Ordner funktioniert.

local last_processed_dir = nil
vlc.msg.err("auto_dir_enqueue: loaded")

local function get_playlist_length()
  local node = vlc.playlist.get("normal", false)
  if not node or not node.children then
    return 0
  end
  return #node.children
end

local function to_dir_uri_from_item_uri(item_uri)
  -- Erwartet eine file-URI wie: file:///C:/Pfad/Datei.mp4
  -- Liefert: file:///C:/Pfad/
  if type(item_uri) ~= "string" then
    return nil
  end
  local dir_uri = item_uri:match("^(file:///.*/)")
  return dir_uri
end

local function try_enqueue_directory(current_uri)
  local dir_uri = to_dir_uri_from_item_uri(current_uri)
  if not dir_uri then
    vlc.msg.dbg("auto_dir_enqueue: no dir_uri from uri: " .. tostring(current_uri))
    return
  end
  if last_processed_dir == dir_uri then
    vlc.msg.dbg("auto_dir_enqueue: dir already processed: " .. dir_uri)
    return
  end

  if get_playlist_length() <= 1 then
    vlc.msg.err("auto_dir_enqueue: enqueue directory URI: " .. dir_uri)
    vlc.playlist.enqueue({ { path = dir_uri } })
    last_processed_dir = dir_uri
  else
    vlc.msg.dbg("auto_dir_enqueue: playlist length > 1; skip enqueue")
  end
end

-- Interface entrypoint for luaintf
function main()
  vlc.msg.err("auto_dir_enqueue: main entry")
  log_environment()
  run_loop()
end

-- Extension-style entrypoints (in case VLC calls these)
function descriptor()
  return { title = "Auto Dir Enqueue", version = "1.0", author = "assistant" }
end
function activate()
  vlc.msg.err("auto_dir_enqueue: activate entry")
  log_environment()
  run_loop()
end
function deactivate()
  vlc.msg.err("auto_dir_enqueue: deactivate entry")
end

-- Fallback: Falls VLC main()/activate() nicht aufruft, bootstrappe run_loop selbst einmalig
if not _G.__auto_dir_enqueue_started then
  _G.__auto_dir_enqueue_started = true
  vlc.msg.err("auto_dir_enqueue: bootstrap run_loop")
  log_environment()
  local ok, err = pcall(run_loop)
  if not ok then
    vlc.msg.err("auto_dir_enqueue: bootstrap error: " .. tostring(err))
  end
end



