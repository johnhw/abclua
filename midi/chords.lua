
---------------------------------------------
--------------- CHORDS ----------------------
---------------------------------------------

function get_default_chord_pattern(meter)
    local patterns
    patterns = {{'c'}, {'f','c'},{'f', 'z', 'c'}, {'f','z','c','z'}, {'f','z','z','c','z'}, {'f','z','f','c','z','z'}, {'f','z','f','z','c','z','z'}, 
    {'f', 'z', 'z', 'z', 'c', 'z', 'f', 'z'}, {'f', 'z', 'f', 'z', 'z', 'c', 'z', 'f', 'z'}}
    
    if meter.den==8 then
        -- changes here    
    end
   
    -- nil if no matching pattern
    return patterns[meter.num]
    
end


function midi_gchord(args,midi_state,score)
    -- set the chord pattern
    local chord_matcher = re.compile([[
    gchord <- (<elt>+) -> {}
    elt <- ({:type: <type> :} {:count: <count>? :}) -> {}
    type <- ('z'/'f'/'c'/[g-j]/[G-J])
    count <- ([0-9]+)
    ]])
   
    local pattern = chord_matcher:match(args[2])
    local expanded = {}
    for i,v in ipairs(pattern) do
        v.count = tonumber(v.count) or 1
        
        -- expand the table, removing repeat indicators
        for j=1,v.count do 
            table.insert(expanded, v.type)
        end
    end    
    midi_state.chord.pattern = expanded
end



function midi_bassprog(arguments, midi_state, score)
    -- Change of bass program (and optionally octave)
    
    local program
    if check_argument(arguments[2], 1, 128, 'Invalid bass program') then
        midi_state.bass.program = tonumber(arguments[2])-1
       score.insert({'patch_change', midi_state.t, midi_state.bass.channel, midi_state.bass.program})
    end
    
    -- octave shift
    if arguments[3] then
        lhs,rhs = parse_assignment(octaves[3])
        if lhs=='octave' and tonumber(rhs) then
            midi_state.bass.octave = tonumber(rhs)
        end
    end
end

function midi_chordprog(arguments, midi_state, score)
    -- Change of bass program (and optionally octave)
    
    local program
    if check_argument(arguments[2], 0, 128, 'Invalid chord program') then
        midi_state.chord.program = tonumber(arguments[2])-1
       score.insert({'patch_change', midi_state.t, midi_state.chord.channel, midi_state.chord.program})
    end
    
    -- octave shift
    if arguments[3] then
        lhs,rhs = parse_assignment(octaves[3])
        if lhs=='octave' and tonumber(rhs) then
            midi_state.chord.octave = tonumber(rhs)
        end
    end

end



function insert_midi_chord(event, midi_state)
    -- Insert a chord / bass pattern into the score
    
    -- do nothing if chords are currently disabled
    if not midi_state.chord.enabled then return end
    
    local pattern
    -- if no pattern specified, find a matching default pattern for
    -- this meter
    if midi_state.chord.pattern=='default' then
        pattern = get_default_chord_pattern(midi_state.meter)
    else
        pattern = midi_state.chord.pattern
    end
        
    local chord = midi_state.chord
    local bass= midi_state.bass
    
    local chord_score = chord.track
    local bass_score = bass.track
    
    -- return if no pattern to play!
    if not pattern then return end
        
    -- divide up bar
    local division = (midi_state.bar_length / #pattern)
    local t = midi_state.last_bar_time -- start the pattern at the start of this bar
    
    -- get chord notes (first is the bass note)
    local base_notes = create_chord(event.chord)
    local notes = voice_chord(base_notes, chord.octave+4)
    
    -- arpeggiated notes, in the form {chord_number, transpose}
    local arpegs = {g={1,0}, h={2,0}, i={3,0}, j={4,0}, G={1,-12}, H={2,-12}, I={3,-12}, J={4,-12}}
    
    -- play the pattern
    for i,v in ipairs(pattern) do
        -- bass note
        if v=='f' then
             local pitch = base_notes[1] + (bass.octave+3)*12
             add_note(midi_state, bass_score, t, division, bass.channel, pitch, bass.velocity)
             
        end
        
        -- chord note
        if v=='c' then
            -- get the notes for this chord and put them in the sequence            
            local chord_t = t
            for j, n in ipairs(notes) do
                 -- chords get transposed too
                 local pitch = n
                 add_note(midi_state, chord_score, t, division, chord.channel, pitch, chord.velocity)
                 chord_t = chord_t + chord.delay + math.random()*chord.random_delay
                 
            end            
        end
        
        -- insert arpeggiated chord (ghij, GHIJ)
        if arpegs[v] then                        
            -- for three note chords, make the fourth note root+octave
             local note = (base_notes[arpegs[v][1]]) or (base_notes[1]+12)             
             local pitch = note + (chord.octave+4)*12 + arpegs[v][2]
             add_note(midi_state, chord_score, t, division, chord.channel, pitch, chord.velocity)             
        end
        
        -- advance time
        t = t + division
    end
    
        
                
end