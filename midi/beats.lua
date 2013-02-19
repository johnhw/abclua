-----------------------------
------ BEATS ----------------
-----------------------------

function midi_beat(args, midi_state)
    if not check_argument(args[2], 1, 128, 'Bad beat first velocity') then return end
    if not check_argument(args[3], 1, 128, 'Bad beat strong velocity') then return end
    if not check_argument(args[4], 1, 128, 'Bad beat other velocity') then return end
    if not check_argument(args[5], 1, 64, 'Bad beat multiple') then return end
    
    midi_state.accents.first = tonumber(args[2])
    midi_state.accents.strong = tonumber(args[3])
    midi_state.accents.other = tonumber(args[4])
    midi_state.accents.accent_multiple = tonumber(args[5])
    midi_state.accents.pattern = nil -- clear any explicit pattern
end

function midi_beatstring(args, midi_state)
 -- set the beat string for note empahsis
 local beat_matcher = re.compile([[
    gchord <- (<elt>+) -> {}
    elt <- ({:type: <type> :} {:count: <count>? :}) -> {}
    type <- ('f'/'m'/'p')
    count <- ([0-9]+)
    ]])
    local pattern = beat_matcher:match(args[2])
    if pattern then
        midi_state.accents.pattern = expand_counted_sequence(pattern)
    end
end

local stress_rhythms = {}

function midi_set_stress(args, midi_state)
    -- set the stress accenting. If not present, uses the default
    -- stress model for the current rhythm
    if not midi_state.accents.stress then    
        local descriptor = midi_state.rhythm..'_'..midi_state.meter.num..'_'..midi_state.meter.den
        -- find a stress model for this rhythm/time signatures
        midi_state.accents.stress = stress_rhythms[descriptor] 
    end
    
end

function midi_stressmodel(args, midi_state)
    -- set the stress mode (beat, articulate or distort)
    if args[2]=='beat' or tonumber(args[2])==0 then
        midi_state.accents.mode = 'beat'
    end
    
    if args[2]=='articulate' or tonumber(args[2])==1 then
        midi_state.accents.mode = 'articulate'
    end
    
    if args[2]=='distort' or tonumber(args[2])==2 then
        midi_state.accents.mode = 'distort'
    end
    
    midi_set_stress()
end



function midi_ptstress(args, midi_state)
    -- set the stress model
    local stress = {}
    local nbeats
    
    if not args[2] then
        -- set default stress model for this rhythm if no stress
        accents.stress = nil
        midi_set_stress()
    end
    
    if tonumber(args[2]) then
        -- is a literal stress model
        nbeats = args[2]
        local arg_index = 3
        -- first number is the number of divisions, subsequent numbers are velocity, stress pairs
        for i=1,nbeats do
            table.insert(stress, {velocity=args[arg_index], stretch=args[arg_index+1]})
            arg_index = arg_index + 2
        end
        
    else
        local f = io.open(args[2], 'r')
        -- read from a file
        if f then
            -- file consists of number of beats, followed by velocity, stress pairs
            nbeats = f:read('*number')                 
            for i=1,nbeats do
                table.insert(stress, {velocity=f:read('*number'), stretch=f:read('*number')})
            end
            
            f:close()
        end
    end
    stress.divisions = nbeats
    
    midi_state.accents.stress = stress    
end

function get_beat_velocity(midi_state)
    -- get the velocity of a note from the accent, when using
    -- simple beat form
    local velocity
    if midi_state.t == midi_state.last_bar_time then
            velocity = midi_state.accents.first
        else                    
            -- not first note, work out which multiple it is and emphasise that
            local beat_index = math.floor((midi_state.t-midi_state.last_bar_time) / midi_state.beat_length+1)            
            if beat_index % midi_state.accents.accent_multiple==0 then
                velocity = midi_state.accents.strong
            else
                velocity = midi_state.accents.other
            end
        end
    return velocity
end

function get_beat_string_velocity(midi_state)
    -- get the velocity of a note from the accent, when using
    -- the full beat string
    local beats = #midi_state.accents.pattern
    -- work out which segment we are in
    local beat_index = math.floor(((midi_state.t-midi_state.last_bar_time) / midi_state.bar_length)*beats)+1    
    local velocities = {f=midi_state.accents.first, m=midi_state.accents.strong, p=midi_state.accents.other}
    return  velocities[midi_state.accents.pattern[beat_index]]
end