
--------------
--- DRONES ---
--------------
function enable_drone(args, midi_state)
    -- turn on the drone
    if not midi_state.drone.enabled then
        
        midi_state.drone.enabled = true
        -- switch to correct program
        table.insert(midi_state.drone.track, {'patch_change', midi_state.t, midi_state.drone.channel, midi_state.drone.program})
        for i,v in ipairs(midi_state.drone.pitches) do        
            -- drone is *not* transposed           
            table.insert(midi_state.drone.track, {'note_on', midi_state.t, midi_state.drone.channel, midi_state.drone.pitches[i], midi_state.drone.velocities[i]})
        end        
    end    
end

function disable_drone(args, midi_state)
    -- turn off the drone
    if midi_state.drone.enabled then
        midi_state.drone.enabled = false
        for i,v in ipairs(midi_state.drone.pitches) do        
            -- drone is *not* transposed
            table.insert(midi_state.drone.track, {'note_off', midi_state.t-0.1, midi_state.drone.channel, midi_state.drone.pitches[i], midi_state.drone.velocities[i]})
        end
    end    
end


function midi_drone(args, midi_state, score) 
    -- Set the drone state, in the form 
    --%%MIDI drone <program> <pitch1> <pitch2> <velocity1> <velocity2>
    if not check_argument(args[2], 1, 128, 'Bad drone program') then return end
    if not check_argument(args[3], 1, 128, 'Bad drone pitch 1') then return end
    if not check_argument(args[4], 1, 128, 'Bad drone pitch 2') then return end
    if not check_argument(args[5], 1, 128, 'Bad drone velocity 1') then return end
    if not check_argument(args[6], 1, 128, 'Bad drone velocity 2') then return end
    
    local enabled = midi_state.drone.enabled
    
    if enabled then
        disable_drone(nil, midi_state)
    end
    
    
    midi_state.drone.program = args[2]-1
    midi_state.drone.pitches[1] = args[3]-1
    midi_state.drone.pitches[2] = args[4]-1
    midi_state.drone.velocities[1] = args[5]-1
    midi_state.drone.velocities[2] = args[6]-1
    
    -- re-enable drone if it was on
    if enabled then
        enable_drone(nil, midi_state)        
    end
end