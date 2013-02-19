
---------------------------------------------
--------------- DRUMS ----------------------
---------------------------------------------

function get_default_drum_pattern(meter)
    local patterns
    patterns = {{'d'}, {'z','d'},{'z', 'z', 'd'}, {'z','z','d','z'}, {'z','z','z','d','z'}, {'z','z','z','d','z','z'}, {'z','z','z','z','d','z','z'}, 
    {'z', 'z', 'z', 'z', 'd', 'z', 'z', 'z'}, {'z', 'z', 'z', 'z', 'z', 'd', 'z', 'z', 'z'}}
    
    if meter.den==8 then
        -- changes here    
    end
   
    -- nil if no matching pattern
    return patterns[meter.num]
    
end

function midi_drum(args,midi_state,score)
    -- set the drum pattern
    local drum_matcher = re.compile([[
    drum <- (<elt>+) -> {}
    elt <- ({:type: <type> :} {:count: <count>? :}) -> {}
    type <- ('z'/'d')
    count <- ([0-9]+)
    ]])
   
    local pattern = drum_matcher:match(args[2])
    if not pattern then return nil end
    local drum = midi_state.drum
    drum.pattern = expand_counted_sequence(pattern)
    
    -- count total hits
    local hits = 0
    for i,v in ipairs(drum.pattern) do
        if v=='d' then hits = hits + 1 end
    end
    
    -- get note / velocity indicators; notes first, then velocities
    local notes = {}
    local velocities = {}
    -- got note and velocity indicators
    if #args>2 then
        for i=3, #args do 
            -- insert notes first
            if #notes<hits then
                table.insert(notes, tonumber(args[i])) 
            else
             -- then velocities
             table.insert(velocities, tonumber(args[i])) 
            end
        end
    end
    
    -- set note and velocity for each hit
    local j = 1
    for i,v in ipairs(drum.pattern) do
        if v=='d' then 
            drum.pattern[i] = {'d', notes[j] or 50, velocities[j] or 100}
            j = j + 1
        else
            drum.pattern[i] = {'z'}
        end
    end
    
end



function insert_midi_drum(midi_state)
    -- Insert a drum pattern into the score
    
    -- do nothing if chords are currently disabled
    if not midi_state.drum.enabled then return end    
    
    local pattern
    -- if no pattern specified, find a matching default pattern for
    -- this meter
    if midi_state.drum.pattern=='default' then
        pattern = get_default_drum_pattern(midi_state.meter)
    else
        pattern = midi_state.drum.pattern
    end
    
    local drum = midi_state.drum
    local drum_score = drum.track
        
    -- return if no pattern to play!
    if not pattern then return end
        
    -- get length of this bar sequence
    local subsequence_len = (#pattern / drum.bars)
    local offset = subsequence_len * drum.bar_counter 
    
    -- get the pattern for this bar
    local bar_pattern = {}
    for i=offset+1, offset+subsequence_len do
        table.insert(bar_pattern, pattern[i])
    end
    
    -- advance bar counter
    drum.bar_counter = (drum.bar_counter + 1)%drum.bars
        
    -- divide up bar
    local division = (midi_state.bar_length / #bar_pattern)
    local t = midi_state.last_bar_time -- start the pattern at the start of this bar
        
    -- play the pattern
    for i,v in ipairs(bar_pattern) do
        -- bass note
        if v[1]=='d' then
         
             add_note(midi_state, drum_score, t, division, drum.channel, v[2], v[3])             
        end
                
        -- advance time
        t = t + division
    end
    
        
                
end