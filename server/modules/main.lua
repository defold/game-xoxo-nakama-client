--[[
  Copyright 2020 The Nakama Authors

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
]]--

local nk = require("nakama")

local function create_tournament()
    nk.logger_info("Creating tournament")

    local id = "4ec4f126-3f9d-11e7-84ef-b7c182b36521"
    local authoritative = false
    local sort = "desc"     -- one of: "desc", "asc"
    local operator = "best" -- one of: "best", "set", "incr"
    local reset = "0 12 * * *" -- noon UTC each day
    local metadata = {
      weather_conditions = "rain"
    }
    title = "Daily Dash"
    description = "Dash past your opponents for high scores and big rewards!"
    category = 1
    start_time = nk.time() / 1000 -- starts now in seconds
    end_time = 0                  -- never end, repeat the tournament each day forever
    duration = 3600               -- in seconds
    max_size = 10000              -- first 10,000 players who join
    max_num_score = 3             -- each player can have 3 attempts to score
    join_required = true          -- must join to compete
    nk.tournament_create(id, sort, operator, duration, reset, metadata, title, description, category,
        start_time, endTime, max_size, max_num_score, join_required)
end


local function create_leaderboard()
    nk.logger_info("Creating leaderboard")

    local id = "level1"
    local authoritative = false
    local sort = "desc"
    local operator = "best"
    local reset = "0 0 * * 1"
    local metadata = {
      weather_conditions = "rain"
    }
    nk.leaderboard_create(id, authoritative, sort, operator, reset, metadata)
end

local format = string.format
local function log(fmt, ...)
    nk.logger_info(string.format(fmt, ...))
end

local function pprint(value)
    if type(value) == "table" then
        for k,v in pairs(value) do
            log("'%s' = '%s'", tostring(k), tostring(v))
        end
    else
        log(tostring(value))
    end
end


local function makematch(context, matched_users)
    log("Creating TicTacToe match")
    -- print matched users
    for _, user in ipairs(matched_users) do
        local presence = user.presence
        log("Matched user '%s' named '%s'", presence.user_id, presence.username)
        for k, v in pairs(user.properties) do
            log("Matched on '%s' value '%s'", k, v)
        end
    end

    local modulename = "tictactoe_match"
    local setupstate = { invited = matched_users }
    local matchid = nk.match_create(modulename, setupstate)
    return matchid
end




nk.run_once(function(ctx)

  local now = os.time()
  nk.logger_info(("Backend loaded at %d"):format(now))

  nk.register_matchmaker_matched(makematch)

  create_tournament()
end)
