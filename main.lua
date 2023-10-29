meta = {
    name = 'screen transitions',
    version = '1.0',
    description = 'test test tes',
    author = 'ac10022',
}

register_option_combo("transition_type", "Transition Type", "Changes the shape of transition", "None\0Classic\0Square\0\0", 2)

local cio = get_io() -- used to find screen dimensions
local fade_sound = create_sound("fadeout.mp3")

local TRANSITION_INFO = {
    enable_gui = false,
    gui_to_draw = nil,
    transition_speed = (1.7 * 1920) / 45,
    counter = 0,
    screen_width_pixels = 1920,
    thickness = 0,
    rect_l = 0, rect_t = 0, rect_r = 0, rect_b = 0,
    center_x = 0, center_y = 0, circle_radius = 0
}

-- used within set interval
local function increment_thickness(radius)
    if TRANSITION_INFO.thickness < (TRANSITION_INFO.screen_width_pixels * radius) then
        TRANSITION_INFO.thickness = TRANSITION_INFO.thickness + TRANSITION_INFO.transition_speed
        return false
    else
        return true
    end
end

-- returns the boundary of the sqaure, i.e. position of left, right, top, bottom
local function calculate_square_initial_pos(screen_x, screen_y)
    local radius
    if screen_x < 0.0 then -- to the left of the screen
        radius = 1 - screen_x
        -- left, top, right, bottom, radius
        return screen_x - radius, screen_y + radius, 1, screen_y - radius, radius
    else
        radius = screen_x + 1
        return -1, screen_y + radius, screen_x + radius, screen_y - radius, radius
    end
end

local function calculate_circle_initial_pos(screen_x, screen_y)
    local radius, x_distance, y_distance
    if screen_x < 0.0 then -- to the left of the screen
        y_distance = 1 - screen_y
        x_distance = 1 - screen_x
        radius = math.sqrt((y_distance * y_distance) + (x_distance * x_distance)) -- pythagoras lol
        return radius
    else
        y_distance = 1 - screen_y
        x_distance = 1 + screen_x
        radius = math.sqrt((y_distance * y_distance) + (x_distance * x_distance))
        return radius
    end
end

local function temp_pause()
    for _, uid in ipairs(get_entities_by(0, MASK.MONSTER, LAYER.BOTH)) do
        local type = get_entity_type(uid)
        if type ~= 326 and type ~= 327 and type ~= 328 then -- if not a pet
            get_entity(uid).flags = set_flag(get_entity(uid).flags, ENT_FLAG.PAUSE_AI_AND_PHYSICS) -- stops things moving
        end
    end
end

local function do_screen_transition(door_reference, type)
    -- function to freeze everything else kinda a bad solutions but normal state.pause prevents drawing
    temp_pause()
    if fade_sound then
        fade_sound:play()
    end
    -- wait 20 frames before the player exits
    set_timeout(function ()
        players[1]:set_behavior(CHAR_STATE.ENTERING)
    end, 20)
    -- time reference so that animation doesn't add time
    local time_reference = state.time_level
    if (type == 1) then
        TRANSITION_INFO.gui_to_draw = 1 -- circle
        --              --
        -- PRE GUI PREP --
        --              --
        local x, y = get_position(door_reference.uid)
        -- calculate screen position of door
        local screen_x, screen_y = screen_position(x, y + 0.25)
        TRANSITION_INFO.center_x, TRANSITION_INFO.center_y = screen_x, screen_y
        local radius = calculate_circle_initial_pos(screen_x, screen_y)
        TRANSITION_INFO.circle_radius = radius
        --               --
        -- POST GUI PREP --
        --               --
        TRANSITION_INFO.enable_gui = true
        -- gui effects stop being shown after however many frames calculated by this
        local wait_time = math.ceil((TRANSITION_INFO.screen_width_pixels * radius) / TRANSITION_INFO.transition_speed) + 5
        set_timeout(function() 
            TRANSITION_INFO.counter = 0
            state.time_level = time_reference
            -- since transition_level now true, door will function like normal
            door_reference:enter(players[1])
        end, wait_time)
        set_interval(function ()
            local to_continue = increment_thickness(radius)
            -- callback clears if predicate succeeds
            if to_continue then
                clear_callback()
            end
        end, 1)
    elseif (type == 2) then
        TRANSITION_INFO.gui_to_draw = 2 -- rectangle
        --              --
        -- PRE GUI PREP --
        --              --
        local x, y = get_position(door_reference.uid)
        local radius
        -- calculate screen position of door
        local screen_x, screen_y = screen_position(x, y + 0.5)
        TRANSITION_INFO.rect_l, TRANSITION_INFO.rect_t, TRANSITION_INFO.rect_r, TRANSITION_INFO.rect_b, radius = calculate_square_initial_pos(screen_x, screen_y)
        -- multiply by 16/9 due to mismatched resolutions
        TRANSITION_INFO.rect_t = (TRANSITION_INFO.rect_t / 9) * 16
        TRANSITION_INFO.rect_b = (TRANSITION_INFO.rect_b / 9) * 16
        --               --
        -- POST GUI PREP --
        --               --
        TRANSITION_INFO.enable_gui = true
        -- gui effects stop being shown after however many frames calculated by this
        local wait_time = math.ceil((TRANSITION_INFO.screen_width_pixels * radius) / TRANSITION_INFO.transition_speed) + 5
        set_timeout(function() 
            state.time_level = time_reference
            TRANSITION_INFO.counter = 0
            -- since transition_level now true, door will function like normal
            door_reference:enter(players[1])
        end, wait_time)
        set_interval(function ()
            local to_continue = increment_thickness(radius)
            -- callback clears if predicate succeeds
            if to_continue then
                clear_callback()
            end
        end, 1)
    end
end

set_callback(function()
    -- reset all info used for transitions
    TRANSITION_INFO.enable_gui = false
    TRANSITION_INFO.counter = 0
    TRANSITION_INFO.thickness = 0
    TRANSITION_INFO.rect_l = 0
    TRANSITION_INFO.rect_t = 0
    TRANSITION_INFO.rect_r = 0
    TRANSITION_INFO.rect_b = 0
    TRANSITION_INFO.gui_to_draw = nil
    -- only on level screens, not camp/transition screens
    if state.screen == 12 then
        local door = get_entity(get_entities_by(ENT_TYPE.FLOOR_DOOR_EXIT, MASK.FLOOR, 0)[1])
        -- first time it's activated we want the animation to run, not to proceed
        door:set_pre_activate(function()
            if options.transition_type == 1 then
                return false
            elseif TRANSITION_INFO.counter == 0 then
                do_screen_transition(door, options.transition_type - 1)
                -- counter prevents spamming the button to get weird results
                TRANSITION_INFO.counter = 1
                return true
            else
                return true
            end
        end)
    end
end, ON.POST_LEVEL_GENERATION)

set_callback(function(draw_ctx)
    if TRANSITION_INFO.enable_gui then
        if TRANSITION_INFO.gui_to_draw == 1 then -- circle
            draw_ctx:draw_circle(TRANSITION_INFO.center_x, TRANSITION_INFO.center_y, TRANSITION_INFO.circle_radius, TRANSITION_INFO.thickness, rgba(0, 0, 0, 255))
        elseif TRANSITION_INFO.gui_to_draw == 2 then -- square
            -- left, top, right, bottom
            draw_ctx:draw_rect(TRANSITION_INFO.rect_l, TRANSITION_INFO.rect_t, TRANSITION_INFO.rect_r, TRANSITION_INFO.rect_b, TRANSITION_INFO.thickness, 0, rgba(0, 0, 0, 255))
        end
    end
end, ON.GUIFRAME)