local s = core.get_mod_storage()
local st = core.settings
local F = core.formspec_escape
local enabled = st:get_bool("geminti.enabled", true)

local http = core.request_http_api()

if not http then
	core.log("error",
		"Can not access HTTP API. Please add this mod to secure.http_mods to grant access")
	return
end

local chat = core.deserialize(s:get_string("chat")) or {}
local selected_ids = {}
local errors_count = 0

local function store_chat()
	local str = core.serialize(chat)
	if str then
		s:set_string("chat", str)
	end
end
core.register_on_shutdown(store_chat)

local function reset()
	chat = {}
	store_chat()
	selected_ids = {}
end

local function geminti_chat(callback, with_context)
	http.fetch({
		url = "https://generativelanguage.googleapis.com/v1beta/models/"..(st:get("geminti.model") or "gemini-2.0-flash")..":generateContent?key="..st:get("geminti.api_key"),
		method = "POST",
		extra_headers = {"Content-Type: application/json"},
		data = core.write_json({
			system_instruction = {
				parts = {
					{
						text = st:get("geminti.system_prompt") or "You are in a multiuser chat. Messages follow the pattern '<username> message', where <username> is the sender's name and 'message' is their content. Do not use <username> prefix in your messages."
					}
				}
			},
			contents = chat
		}),
	},
	function(res)
		local data = res.data
		local pjson = core.parse_json(res.data)
		local content = pjson and pjson.candidates and pjson.candidates[1].content
		if content and content.parts then
			table.insert(chat, content)
			store_chat()
			callback(content.parts[1].text or "")
		else
			errors_count = errors_count + 1
			local msg = "-!- Geminti: something went wrong: no content!"
			if errors_count > (tonumber(st:get("geminti.max_errors")) or 3) then
				reset()
				errors_count = 0
				msg = "-!- Geminti: errors limit exceeded, context has been reset"
			end
			core.chat_send_all(msg)
			core.log("error",msg)
		end
	end)
end

core.register_chatcommand("resetgeminti",{
	privs = {server=true},
	description = "Reset geminti context",
	func = function(name, param)
		reset()
		return true, "geminti context has been reset."
end})

core.register_chatcommand("togglegeminti",{
	privs = {server=true},
	description = "Toggle geminti functionality",
	func = function(name, param)
		enabled = not enabled
		st:set_bool("geminti_enabled", enabled)
		return true, "geminti has been "..(enabled and "enabled" or "disabled")
end})

local callwords = {
	"^hello!?$",
	"^hello there!?$",
	"^hi!?$",
	"^привет!?$", "^Привет!?$",
	(st:get("geminti.name") or "[AI] Geminti"):lower()
}

local function geminti_on_chat_msg(name, msg)
	if not enabled or msg:sub(1,1) == "/" then return end
	table.insert(chat, {
		role = "user",
		parts = {
			{
				text = "<"..name.."> "..msg
			}
		}
	})
	local reply
	local prefix = st:get("geminti_prefix") or "!"
	if msg:match("^"..prefix.."%S+") then
		msg = msg:sub(#prefix+1)
		reply = true
	else
		for _,word in ipairs(callwords) do
			if msg:lower():match(word) then
				reply = true
				break
			end
		end
	end
	if reply then
		geminti_chat(function(answer)
			if not st:get_bool("geminti_newlines", false) then
				answer = answer:gsub("\n"," ")
			end
			local color = st:get("geminti_color") or "#aef"
			core.chat_send_all(core.colorize(color, core.format_chat_message((st:get("geminti.name") or "[AI] Geminti"), answer)))
		end, true)
	end
end

core.register_on_mods_loaded(function()
	table.insert(core.registered_on_chat_messages, 1, geminti_on_chat_msg)
	core.callback_origins[geminti_on_chat_msg] = {
		mod = "geminti",
		name = "register_on_chat_message"
	}
end)

local dd_helper = {
	user = "1",
	model = "2"
}

local function geminti_chatedit(name)
	if not next(chat) then return false, "Chat history is empty" end
	local out = {}
	for _, msg in ipairs(chat) do
		table.insert(out, F(msg.role)..","..F(msg.parts[1].text):gsub("\n"," "))
	end
	core.show_formspec(name, "geminti_chatedit", "size[16,9]" ..
		"tablecolumns[text;text]" ..
		"table[0,0;15.8,6;msgs;"..table.concat(out,",")..";"..(selected_ids[name] or 1).."]" ..
		"textarea[0.3,6.3;16,2;edit;;"..(selected_ids[name] and chat[selected_ids[name]].parts[1].text or "").."]" ..
		"dropdown[0,8.1;1.5,1;role;user,model;"..(selected_ids[name] and dd_helper[chat[selected_ids[name]].role] or "0").."]" ..
		"button[12,8;2,1;del;Delete]" ..
		"button[14,8;2,1;save;Save]" ..
		"button[3.7,8;2,1;moveup;Move up]" ..
		"button[1.8,8;2,1;movedown;Move down]"
	)
end

core.register_on_player_receive_fields(function(player, fname, fields)
	if fname ~= "geminti_chatedit" then return end
	local name = player:get_player_name()
	if fields.msgs then
		local evnt = core.explode_table_event(fields.msgs)
		if evnt.type == "CHG" or evnt.type == "DCL" then
			selected_ids[name] = evnt.row
			geminti_chatedit(name)
			return
		end
	end
	local sel = selected_ids[name] or 0
	if not chat[sel] then return end
	if fields.save then
		if fields.role == "user" or fields.role == "model" then
			chat[sel].role = fields.role
		end
		chat[sel].parts[1].text = fields.edit
	end
	if fields.del then
		table.remove(chat, sel)
		if not next(chat) then
			core.close_formspec(name, "geminti_chatedit")
			return
		end
	end
	if fields.moveup and sel > 1 then
		chat[sel], chat[sel-1] = chat[sel-1], chat[sel]
		selected_ids[name] = sel - 1
	end
	if fields.movedown and sel < #chat then
		chat[sel], chat[sel+1] = chat[sel+1], chat[sel]
		selected_ids[name] = sel + 1
	end
	if not fields.quit then
		geminti_chatedit(name)
	else
		selected_ids[name] = nil
	end
end)

core.register_on_leaveplayer(function(player)
	local name = player and player:get_player_name()
	if name then
		selected_ids[name] = nil
	end
end)

core.register_chatcommand("geminti_chatedit",{
	description = "Edit geminti chat history",
	privs = {server=true},
	func = geminti_chatedit
})
