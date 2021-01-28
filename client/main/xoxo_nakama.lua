local xoxo = require "xoxo.xoxo"
local nakama = require "nakama.nakama"
local log = require "nakama.util.log"
local defold = require "nakama.engine.defold"
local json = require "nakama.util.json"

local M = {}


local client = nil
local socket = nil
local match = nil

local OP_CODE_MOVE = 1
local OP_CODE_STATE = 2

local function device_login(client)
	local body = nakama.create_api_account_device(defold.uuid())
	local result = nakama.authenticate_device(client, body, true)
	if result.token then
		nakama.set_bearer_token(client, result.token)
		return true
	end
	local result = nakama.authenticate_device(client, body, false)
	if result.token then
		nakama.set_bearer_token(client, result.token)
		return true
	end
	log("Unable to login")
	return false
end


local function join_match(match_id, token, match_callback)
	nakama.sync(function()
		log("Sending match_join message")
		local message = nakama.create_match_join_message(match_id, token, nil)
		local result = nakama.socket_send(socket, message)
		if result.match then
			match = result.match
			match_callback(true)
		elseif result.error then
			log(result.error.message)
			pprint(result)
			match = nil
			match_callback(false)
		end
	end)
end

local function leave_match(match_id)
	nakama.sync(function()
		log("Sending match_leave message")
		local message = nakama.create_match_leave_message(match_id)
		local result = nakama.socket_send(socket, message)
		pprint(result)
		if result.error then
			log(result.error.message)
		end
	end)
end

local function find_opponent_and_join_match(match_callback)
	nakama.on_matchmakermatched(socket, function(message)
		local matched = message.matchmaker_matched
		if matched and (matched.match_id or matched.token) then
			join_match(matched.match_id, matched.token, match_callback)
		else
			match_callback(nil)
		end
	end)

	nakama.sync(function()
		log("Sending matchmaker_add message")
		local message = nakama.create_matchmaker_add_message("*", 2, 2)
		local result = nakama.socket_send(socket, message)
		if result.error then
			print(result.error.message)
			pprint(result)
			match_callback(nil)
		end
	end)
end


local function send_player_move(match_id, row, col)
	nakama.sync(function()
		local data = json.encode({
			row = row,
			col = col,
		})
		log("Sending match_data message")
		local message = nakama.create_match_data_message(match_id, OP_CODE_MOVE, data)
		local result = nakama.socket_send(socket, message)
		if result.error then
			print(result.error.message)
			pprint(result)
		end
	end)
end



local function handle_match_data(match_data)
	local data = json.decode(match_data.data)
	local op_code = tonumber(match_data.op_code)
	if op_code == OP_CODE_STATE then
		xoxo.match_update(data.state, data.active_player, data.other_player, data.your_turn)
	else
		log(("Unknown opcode %d"):format(op_code))
	end
end


local config = {
	host = "127.0.0.1",
	port = 7350,
	username = "defaultkey",
	password = "",
	engine = defold,
}


function M.login(callback)
	log.print()

	client = nakama.create_client(config)
	pprint(client)

	nakama.sync(function()
		local ok = device_login(client)
		if not ok then
			callback(false, "Unable to login")
			return
		end
		local account = nakama.get_account(client)
		pprint(account)

		socket = nakama.create_socket(client)
		local ok, err = nakama.socket_connect(socket)
		if not ok then
			log("Unable to connect: ", err)
			callback(false, "Unable to create socket connection")
			return
		end

		local match_id = nil

		nakama.on_matchpresence(socket, function(message)
			log("nakama.on_matchpresence")
			pprint(message)
			if #message.match_presence_event.leaves > 0 then
				xoxo.opponent_left()
			end
		end)
		
		nakama.on_matchdata(socket, function(message)
			log("nakama.on_matchdata")
			pprint(message)
			handle_match_data(message.match_data)
		end)
		
		xoxo.on_join_match(function(callback)
			log("xoxo.on_join_match")
			find_opponent_and_join_match(callback)
		end)

		xoxo.on_leave_match(function()
			log("xoxo.on_leave_match")
			leave_match(match.match_id)
		end)

		xoxo.on_send_player_move(function(row, col)
			log("xoxo.on_send_player_move")
			send_player_move(match.match_id, row, col)
		end)

		callback(true)
	end)
end


return M
