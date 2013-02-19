
function midi_control(args, midi_state)
    -- insert a control change
    local cc, value, channel, track
    
    
    -- change bass, guitar, drone or drums channel
    if args[2]=='bass' or args[2]=='guitar' or args[2]=='drum' or args[2]=='drums' then
        if check_arguments(args[3], 1, 128, 'Bad CC number') and check_arguments(args[4], 1, 128, 'Bad CC value') then
            cc = tonumber(args[3])-1
            value = tonumber(args[4])-1
            
            -- find out which instrument we are working with
            local instrument_map={bass=midi_state.bass,
            guitar=midi_state.guitar,
            drone=midi_state.drone,
            drum=midi_state.drum}
            channel = channel_map[args[2]].channel
            track = channel_map[args[2]].track
        end
    else
        -- change the cc on the current channel
        if check_arguments(args[2], 1, 128, 'Bad CC number') and check_arguments(args[3], 1, 128, 'Bad CC value') then
            channel = midi_state.channel
            track = midi_state.current_track
            cc = tonumber(args[2])-1
            value = tonumber(args[3])-1
        end
    end
    
    -- distort time
    local t = get_distorted_time(midi_state.t, midi_state)
    table.insert(track, {'control_change', t, channel, cc, value})
end


function midi_channel(arguments, midi_state, score)
    -- change the current channel
    if check_argument(arguments[2], 1, 16, 'Invalid MIDI Channel') then 
        midi_state.channel = arguments[2]-1    
    end
end

function midi_program(arguments, midi_state, score)
    -- change the program by directly inserting a patch change into the score
    --
    
    local t = get_distorted_time(midi_state.t, midi_state)
    if len(arguments)==3 then
        -- channel and program
        if check_argument(arguments[2], 1, 16, 'Invalid MIDI Channel') and check_argument(arguments[3], 1, 128, 'Invalid program') then
            score.insert({'patch_change', t, tonumber(arguments[2])-1, tonumber(arguments[3])-1})
        end
    else
        -- just program change on current channel
        if check_argument(arguments[2], 1, 128, 'Invalid program') then
             score.insert({'patch_change', t, midi_state.channel, tonumber(arguments[2])-1})
         end
    end
end


function midi_trim(args, midi_state)
    -- set the trimming fraction
    
    local trim_pattern = re.compile([[
    ratio <- ({:num: <number> :} '/' {:den: <number> :}) -> {}
    number <- [0-9]+
    ]])
    local match = trim_pattern:match(args[2])
        
    -- convert to floating point
    if match then
        midi_state.trimming = 1.0-(match.num / match.den)
    end
    
end