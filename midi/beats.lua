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

function midi_set_stress(midi_state)
    -- set the stress accenting. If not present, uses the default
    -- stress model for the current rhythm
    if not midi_state.accents.stress then    
        local descriptor = midi_state.rhythm..'_'..midi_state.meter.num..'_'..midi_state.meter.den
        -- find a stress model for this rhythm/time signatures
        midi_state.accents.stress = stress_rhythms[descriptor] 
    end
    
    -- clear any time distortion in effect
    midi_state.accents.time_distortion = nil
    
    -- normalise stress model
    if midi_state.accents.mode=='articulate' then
        local max = 0
        -- normalise max length to 1.0
        for i,v in ipairs(midi_state.accents.stress) do            
            if v.stretch>max then
                max = v.stretch
            end
        end        
        for i,v in ipairs(midi_state.accents.stress) do
            v.stretch = v.stretch / max            
        end        
    end
    
    if midi_state.accents.mode=='distort' then    
        -- it's a distort model; need lengths normalised to sum to one bars worth
        local sum = 0
        -- normalise total length to divisions
        for i,v in ipairs(midi_state.accents.stress) do
            sum = sum + v.stretch
        end        
        for i,v in ipairs(midi_state.accents.stress) do
            v.stretch = v.stretch / (sum/midi_state.accents.stress.divisions)
        end     
        compute_distortion_table(midi_state)
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
        
    midi_set_stress(midi_state)
end



function midi_ptstress(args, midi_state)
    -- set the stress model
    local stress = {}
    local nbeats
    
    if not args[2] then
        -- set default stress model for this rhythm if no stress
        accents.stress = nil
        midi_set_stress(midi_state)
        return
    end
    
    if tonumber(args[2]) then
        -- is a literal stress model
        nbeats = args[2]
        local arg_index = 3
        -- first number is the number of divisions, subsequent numbers are velocity, stress pairs
        for i=1,nbeats do
            table.insert(stress, {velocity=tonumber(args[arg_index]), stretch=tonumber(args[arg_index+1])})
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
    midi_set_stress(midi_state)
end

function get_beat(t, midi_state)
    -- return the beat that t is in
    local division =  (t-midi_state.last_bar_time) / midi_state.beat_length       
    return math.floor(division)+1
end

function get_division(t,midi_state,divisions)
    -- return the division of the bar we are in
    local division
    
    -- equal spaced divisions
    division = (t-midi_state.last_bar_time) / (midi_state.bar_length/divisions)    
    
    local whole_division = math.floor(division)
    local remainder = division-whole_division
    return whole_division+1, remainder
end

function compute_distortion_table(midi_state)
    -- compute the time distortion function
    local distortion = {}
    local t = 0
    local distorted_t = 0
    local divisions = #midi_state.accents.stress
    local duration, distorted_duration
    
    -- create a table of intervals: {original_start, original_end, distorted_start, distorted_end, stretch}
    for i,v in ipairs(midi_state.accents.stress) do
        duration = (midi_state.bar_length / divisions)
        distorted_duration = duration * v.stretch
        table.insert(distortion, {original_start=t, original_end=t+duration, distorted_start=distorted_t, 
        distorted_end=distorted_t+distorted_duration, stretch=v.stretch})
        -- advance time
        t = t + duration
        distorted_t = distorted_t + distorted_duration
    end
    
    -- set the distortion table
    midi_state.accents.time_distortion = distortion        
        
end

function get_distorted_time(t,midi_state)
    -- return the time of an event after bar distortion     
    
    -- if no distortion in effect, don't do anything
    if not midi_state.accents.time_distortion then
        return t
    end
        
    local bar_time = t-midi_state.last_bar_time        
    -- get the division we are in    
    for i,v in ipairs(midi_state.accents.time_distortion) do
        if bar_time>=v.original_start and bar_time<=v.original_end+0.1 then
            -- get offset from start of this interval
            local offset = bar_time - v.original_start
            -- distort and return
            t = v.distorted_start + offset * v.stretch
        end
    end    
        
    t = t+midi_state.last_bar_time    
    return t
end

function get_distorted_duration(t,duration,midi_state)
    -- return the duration of an event after being distorted by the distortion function
    local t1 = get_distorted_time(t, midi_state)
    local t2 = get_distorted_time(t+duration, midi_state)
    return t2-t1
end

function get_distorted_beat_velocity(midi_state)
      -- get the velocity of this note
      -- compute beat in _undistorted_ time
      local division = get_division(midi_state.t, midi_state, #midi_state.accents.stress)
      
      local stress = midi_state.accents.stress[division]
      if  stress then                                
          return stress.velocity
      else
          return 127
      end
end

function get_articulated_beat(midi_state, duration)
    -- return the new velocity and duration of this note
    local start_beat, start_fraction, end_beat, end_fraction
    
    -- need to get the weighted average here if this doesn't fall within one region
    start_beat, start_fraction = get_division(midi_state.t, midi_state, #midi_state.accents.stress)
    end_beat, end_fraction = get_division(midi_state.t+duration, midi_state,#midi_state.accents.stress)
        
    if start_beat==end_beat then
        local division = start_beat        
        local stress = midi_state.accents.stress[division]        
        if  stress then                                
            return stress.velocity, stress.stretch           
        else
            return 127, 1.0
        end
        
    end
    
    -- stretches over more than one division
    -- need to interpolate
    local n_beats = end_beat - start_beat  -- number of distinct beats in this note
    local total_weight = (n_beats-1)+(1-start_fraction)+end_fraction -- total length of this note    
    
    local default = {velocity=127,stretch=1.0} -- the default value for missing divisions
    -- create a weighting table
    -- each table is of the form {weight, stress_value}
    local weights = {}
    weights[1] = {(1-start_fraction)/total_weight, midi_state.accents.stress[start_beat] or default}
    for i=2,n_beats do
        table.insert(weights, {1.0/total_weight,midi_state.accents.stress[start_beat+i-1] or default})
    end
    table.insert(weights, {end_fraction/total_weight, midi_state.accents.stress[end_beat] or default})
    
    
    -- now find average weight
    local velocity=0
    local stretch = 0
    for i,v in ipairs(weights) do        
        velocity = velocity + v[1] * v[2].velocity
        stretch = stretch + v[1] * v[2].stretch
    end        
    
    -- default: return full intensity, full length
    return velocity, stretch
end


function saturated_increment(value, inc, v_min, v_max)
    -- increase a value by inc, clipping it to [v_min, v_max]
    value = value+inc
    if value<v_min then value=v_min end
    if value>v_max then value=v_max end    
    return value
end

function midi_deltaloudness(args, midi_state)
    -- set the delta loudness adjustment for crescendo and diminuendo
    midi_state.accents.delta = (check_argument(args[2], -128,128, 'Bad deltaloudness value')) or midi_state.accents.delta
end

function increment_dynamics(midi_state, n)
    -- adjust beat accent dynamics by n steps
    midi_state.accents.first = saturated_increment(midi_state.accents.first, n, 0, 127)
    midi_state.accents.strong = saturated_increment(midi_state.accents.strong, n, 0, 127)
    midi_state.accents.other = saturated_increment(midi_state.accents.other, n, 0, 127)            
end

function midi_beatmod(args, midi_state)
    -- adjust the velocities in beat accent mode
    local n = check_argument(args[2], -128, 128, 'Bad beatmod value')    
    increment_dynamics(midi_state, n)
end

function get_beat_velocity(midi_state)
    -- get the velocity of a note from the accent, when using
    -- simple beat form
    local velocity
    if midi_state.t == midi_state.last_bar_time then
            velocity = midi_state.accents.first
        else                    
            -- not first note, work out which multiple it is and emphasise that
            local beat_index = get_beat(midi_state.t, midi_state)
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