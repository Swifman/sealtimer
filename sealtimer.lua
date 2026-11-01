addon.name    = 'sealtimer';
addon.author  = 'Spencer';
addon.version = '1.0';
addon.desc    = 'Shows when Beastmen/Kindred seals can drop again (5 min cooldown after a seal drops).';
addon.link    = '';

--[[
    HOW THE COOLDOWN WORKS (LandSandBoat server code, which Phoenix runs on)
      - After a seal drops, nobody in the killer's party (who is in the zone)
        can get another seal for 5 minutes.
      - Each eligible kill has a 20% seal roll while nobody is on cooldown.
      - Phoenix keeps the cooldown through zoning (and logout). Other servers may reset it.
      - Never from NMs, Too Weak mobs, BCNMs or Dynamis.

    HOW THIS ADDON KNOWS
      It watches the "item found" packet the server already sends when loot
      enters the treasure pool. When that item is a Beastmen's or Kindred's
      Seal from a mob, the timer starts. It sends nothing to the server.

    COMMANDS (/sealtimer or /st)
      /st                 show or hide the window
      /st reset           clear the timer (e.g. if you know it reset)
      /st start           start the timer by hand
      /st zone on|off     reset the timer when you zone (default off for Phoenix)
      /st duration 300    cooldown length in seconds (default 300)
      /st hide on|off     hide the window while the seal is ready
      /st alert on|off    chat message when the timer is up (default on)
]]

require('common');
local imgui    = require('imgui');
local settings = require('settings');
local chat     = require('chat');

local SEALS = {
    [1126] = "Beastmen's Seal",
    [1127] = "Kindred's Seal",
};

local defaults = T{
    visible       = true,
    duration      = 300,   -- seconds
    reset_on_zone = false, -- Phoenix keeps the timer through zoning
    hide_ready    = false,
    alert         = true,
    pos_x         = 300,
    pos_y         = 300,
    -- live state, saved so an addon reload doesn't lose the timer
    expires       = 0,     -- os.time() when seals can drop again
    last_name     = '',
    last_time     = 0,
};

local cfg     = settings.load(defaults);
local session = 0;     -- seals seen this session
local alerted = true;  -- already announced "ready" for the current cooldown
local posSet  = false;
local isOpen  = { true };

settings.register('settings', 'sealtimer_update', function(s)
    if (s ~= nil) then cfg = s; end
    posSet = false;
    settings.save();
end);

local function say(text)
    print(chat.header('SealTimer'):append(chat.message(text)));
end

local function remaining()
    return math.max(0, cfg.expires - os.time());
end

local function start(name)
    cfg.expires   = os.time() + cfg.duration;
    cfg.last_name = name or cfg.last_name;
    cfg.last_time = os.time();
    alerted = false;
    settings.save();
end

local function clear()
    cfg.expires = 0;
    alerted = true;
    settings.save();
end

-- If an old timer already ran out while the addon was off, don't announce it.
if (remaining() == 0) then alerted = true; end

------------------------------------------------------------------------------------------------------
-- Packets (read only)
------------------------------------------------------------------------------------------------------
ashita.events.register('packet_in', 'sealtimer_packet_in', function(e)
    -- 0x00D2: an item was added to the treasure pool.
    if (e.id == 0x00D2) then
        local item        = struct.unpack('H', e.data, 0x10 + 1);
        local old         = struct.unpack('B', e.data, 0x15 + 1); -- 1 = was already in pool when you joined/zoned
        local isContainer = struct.unpack('B', e.data, 0x16 + 1); -- 1 = from a chest/box, no cooldown
        local name = SEALS[item];
        if (name ~= nil and old == 0 and isContainer == 0) then
            session = session + 1;
            start(name);
            say(string.format('%s dropped. Next seal possible in %d:%02d.', name,
                math.floor(cfg.duration / 60), cfg.duration % 60));
        end
        return;
    end

    -- 0x000A: zone in. The server clears the cooldown on zone by default.
    if (e.id == 0x000A and cfg.reset_on_zone and remaining() > 0) then
        clear();
        say('Zoned: seal timer reset.');
    end
end);

------------------------------------------------------------------------------------------------------
-- Commands
------------------------------------------------------------------------------------------------------
local function onoff(v, current)
    if (v == 'on') then return true; end
    if (v == 'off') then return false; end
    return not current;
end

ashita.events.register('command', 'sealtimer_command', function(e)
    local args = e.command:args();
    if (#args == 0) then return; end
    local cmd = args[1]:lower();
    if (cmd ~= '/sealtimer' and cmd ~= '/st') then return; end
    e.blocked = true;

    local sub = (args[2] or ''):lower();
    local val = (args[3] or ''):lower();

    if (sub == '') then
        cfg.visible = not cfg.visible;
    elseif (sub == 'reset') then
        clear();
        say('Timer cleared.');
    elseif (sub == 'start') then
        start(cfg.last_name ~= '' and cfg.last_name or "Beastmen's Seal");
        say('Timer started by hand.');
    elseif (sub == 'zone') then
        cfg.reset_on_zone = onoff(val, cfg.reset_on_zone);
        say('Reset on zone: ' .. (cfg.reset_on_zone and 'on' or 'off'));
    elseif (sub == 'duration' and tonumber(args[3])) then
        cfg.duration = math.max(10, math.floor(tonumber(args[3])));
        say(string.format('Cooldown set to %d seconds.', cfg.duration));
    elseif (sub == 'hide') then
        cfg.hide_ready = onoff(val, cfg.hide_ready);
        say('Hide while ready: ' .. (cfg.hide_ready and 'on' or 'off'));
    elseif (sub == 'alert') then
        cfg.alert = onoff(val, cfg.alert);
        say('Ready alert: ' .. (cfg.alert and 'on' or 'off'));
    else
        say('/st [reset | start | zone on|off | duration <sec> | hide on|off | alert on|off]');
        return;
    end
    settings.save();
end);

------------------------------------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------------------------------------
local GREEN = { 0.45, 0.85, 0.45, 1.0 };
local AMBER = { 0.95, 0.70, 0.30, 1.0 };
local DIM   = { 0.60, 0.60, 0.60, 1.0 };

local function ago(t)
    local s = os.time() - t;
    if (s < 60) then return string.format('%ds ago', s); end
    if (s < 3600) then return string.format('%dm ago', math.floor(s / 60)); end
    return string.format('%dh ago', math.floor(s / 3600));
end

ashita.events.register('d3d_present', 'sealtimer_present', function()
    local left = remaining();

    if (left == 0 and not alerted) then
        alerted = true;
        if (cfg.alert) then say('Seals can drop again.'); end
    end

    if (not cfg.visible) then return; end
    if (cfg.hide_ready and left == 0) then return; end

    if (not posSet) then
        imgui.SetNextWindowPos({ cfg.pos_x, cfg.pos_y });
        posSet = true;
    end

    local flags = bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_AlwaysAutoResize,
                          ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav);
    if (imgui.Begin('sealtimer', isOpen, flags)) then
        imgui.Text('Seals');
        imgui.SameLine();
        if (left == 0) then
            imgui.TextColored(GREEN, 'READY');
        else
            imgui.TextColored(AMBER, string.format('%d:%02d', math.floor(left / 60), left % 60));
            imgui.ProgressBar(1 - (left / cfg.duration), { 140, 6 }, '');
        end

        if (cfg.last_time > 0) then
            imgui.TextColored(DIM, string.format('Last: %s, %s', cfg.last_name, ago(cfg.last_time)));
        end
        if (session > 0) then
            imgui.TextColored(DIM, string.format('This session: %d', session));
        end

        -- remember where the window was dragged
        local x, y = imgui.GetWindowPos();
        if (x ~= cfg.pos_x or y ~= cfg.pos_y) then
            cfg.pos_x, cfg.pos_y = x, y;
            if (not imgui.IsMouseDown(ImGuiMouseButton_Left)) then settings.save(); end
        end
    end
    imgui.End();
end);

ashita.events.register('unload', 'sealtimer_unload', function()
    settings.save();
end);
