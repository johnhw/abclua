function add_cc_to_instrument(midi_state, instrument, cc, value)
    -- add a cc to an instrument channel. instrument can be 'current' for
    -- current instrument, or one of 'guitar', 'bass', 'drums', 'drone'
    local channel, track
    if check_argument(cc, 0, 128, 'Bad CC number') and check_argument(value, 0, 128, 'Bad CC value') then         
         
         if instrument=='current' then
            track = midi_state.current_track
            channel = midi_state.channel
         else
            -- find out which instrument we are working with
            local instrument_map={bass=midi_state.bass,
            guitar=midi_state.guitar,
            drone=midi_state.drone,
            drum=midi_state.drum}
            channel = channel_map[args[2]].channel
            track = channel_map[args[2]].track
        end
                
        -- distort time and insert the event
        local t = get_distorted_time(midi_state.t, midi_state)        
        table.insert(track, {'control_change', t, channel, cc, value})
    end    
end


function midi_control(args, midi_state)
    -- insert a control change. can set the portamento for the current track
    -- and also bass, guitar, drums and drone
    local cc, value, channel, track
    
    if tonumber(args[2]) then
        add_cc_to_instrument(midi_state, 'current', args[2], args[3])        
    else
        add_cc_to_instrument(midi_state, args[2], args[3], args[4])
    end    
end

    


function midi_portamento(args, midi_state)
    -- set the portamento value. can set the portamento for the current track
    -- and also bass, guitar, drums and drone
    
    local portamento, instrument
    
    if tonumber(args[2]) then
        instrument = 'current'
        portamento = check_argument(args[2], 0, 63, 'Bad portamento value')         
    else
        instrument = args[2]
        portamento = check_argument(args[3], 0, 63, 'Bad portamento value') 
    end
        
    if not portamento then return end
            
    -- disable portamento
    if portamento==0 then
        add_cc_to_instrument(midi_state, instrument, 65, 0)
    else
        add_cc_to_instrument(midi_state, instrument, 65, 127)
        add_cc_to_instrument(midi_state, instrument, 5, portamento)
    end
    
end

function midi_pitchbend(args, midi_state)
    -- insert a control change
    local value, channel, track
    
    
    -- change bass, guitar, drone or drums channel
    if args[2]=='bass' or args[2]=='guitar' or args[2]=='drum' or args[2]=='drums' then
        if check_argument(args[3], -8192, 8192, 'Bad pitch bend')  then
            
            value = tonumber(args[3])
            
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
        if check_argument(args[2], -8192, 8192, 'Bad pitch bend')  then
            channel = midi_state.channel
            track = midi_state.current_track            
            value = tonumber(args[2])
        end
    end
    
    -- distort time
    local t = get_distorted_time(midi_state.t, midi_state)
    table.insert(track, {'pitch_wheel_change', t, channel, value})
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