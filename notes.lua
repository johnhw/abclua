

local pitch_table = {c=12, d=14, e=16, f=17, g=19, a=21, b=23,
C=0, D=2, E=4, F=5, G=7, A=9, B=11}

local  key_order_table = {c=1, d=2, e=3, f=4, g=5, a=6, b=7,
C=1, D=2, E=3, F=4, G=5, A=6, B=7}


function compute_pitch(note, song)
    -- compute the real pitch (in MIDI notes) of a note event
    -- taking into account: 
    --  written pitch
    --  capitalisation
    --  octave modifier
    --  current key signature
    --  accidentals
    --  transpose and octave shift
    
    -- -1 indicates a rest note
    if note.rest then
        return -1
    end
    
    local base_pitch = pitch_table[note.pitch.note]
    
    -- add octave shifts
    if note.pitch.octave then
        for c in note.pitch.octave:gmatch"." do
            if c == "'" then
                base_pitch = base_pitch + 12
            end
            if c==',' then 
                base_pitch = base_pitch - 12
            end
        end
    end
    
    -- accidentals / keys
    
    if note.pitch.accidental then
        if note.pitch.accidental == '^' then
            base_pitch = base_pitch + 1
        end
        
        if note.pitch.accidental == '^^' then
            base_pitch = base_pitch + 2
        end
        
        if note.pitch.accidental == '_' then
            base_pitch = base_pitch - 1
        end
        
        if note.pitch.accidental == '__' then
            base_pitch = base_pitch - 2
        end
        
        if note.pitch.accidental == '=' then
            base_pitch = base_pitch
        end
        
    else        
        -- apply key signature sharpening / flattening
        acc = song.internal.key_data.mapping[string.lower(note.pitch.note)]
        base_pitch = base_pitch + acc
    end
        
    base_pitch = base_pitch + song.internal.global_transpose
    return base_pitch + 60  -- MIDI middle C
end

function compute_duration(note, song)
    -- compute the duration (in microseconds) of a note_def
    
    -- takes into account:
    -- tempo 
    -- note length
    -- triplet state 
    -- broken state
    -- duration field of the note itself
    
    
    local length = 1
    
    if note.duration then
    
        -- use A3/4 notation
        if note.duration.den and note.duration.num and string.len(note.duration.den)>1 then
            
            length = note.duration.num / note.duration.den
        end
        
        -- use A3 notation
        if note.duration.num then
            length = note.duration.num + 0
            
        end
        
        -- use A/ notation
        if note.duration.slashes then
            local l = string.len(note.duration.slashes)
            for i = 1,l do
                length = length / 2
            end
        end
        
    end
    
    local shift = 1
    local this_note = 1
    local next_note = 1
    
    local prev_note = 1
    
    -- take into account previous dotted note, if needed
    if song.internal.prev_broken_note then
        prev_note = song.internal.prev_broken_note
    else
        prev_note = 1
    end
    
    -- deal with broken note information
    -- a < shortens this note by 0.5, and increases the next by 1.5
    -- vice versa for >
    -- multiple > (e.g. >> or >>>) lengthens by 1.75 (0.25) or 1.875 (0.125) etc.
    if note.broken then
        
        -- get the overall shift: negative means this note gets shortened
        for c in note.broken:gmatch"." do
            
            if c == '>' then
                shift = shift * 2
            end
            if c == '<' then
                shift = shift * -2
            end
        end
        
        if shift<0 then
            this_note = 1.0 / -shift
            next_note = 1.0 + 1 - (1.0 / -shift)
        else
            this_note = 1.0 + 1 - (1.0 / shift)
            next_note = (1.0 / shift)
        end
        
        -- store for later
        song.internal.prev_broken_note = next_note
    else
        song.internal.prev_broken_note = 1
    end
    
    
    length = length * song.internal.base_note_length * this_note * prev_note * 1e6 * song.internal.triplet_compress
    
    
    return length
   
end




function parse_triplet(triplet, song)
-- parse a triplet/tuplet definition, which specifies the contraction of the following
-- n notes. General form of p notes in the time of q for the next r notes

    local n, p, q, r
    q=-1
    r=-1
            
    -- simple triplet of form (3:
    if #triplet==1 then
        p = triplet[1]+0                
    end
    
    -- triplet of form (3:2
    if #triplet==2 then
        p = triplet[1]+0                
        q = triplet[2]+0
    end
    
    -- triplet of form (3:2:3 or (3::2 or (3::
    if #triplet==3 then
        p = triplet[1]+0
        if triplet[2] and string.len(triplet[2])>0 then
            q = triplet[2]+0
        end
        if triplet[3] and string.len(triplet[3])>0 then
            r = triplet[3]+0
        end
    end
       
    -- default: r is equal to p
    if r==-1 then
        r = p
    end

    -- check if compound time -- if so
    -- the default timing for (5 (7 and (9 changes
    if is_compound_time(song) then
        n = 3
    else    
        n = 2
    end
    
    if p>9 then
        warn("Bad triplet length (p>9)")
    end
    
    -- default to choosing q from the table
    q_table = {-1,3,2,3,n,2,n,3,n}
    if q==-1 then
        q = q_table[p]
    end
        
    return {p=p, q=q, r=r}
end

function insert_grace(grace_note, song)
    -- insert a grace note sequence into a song
    -- grace notes have their own separate timing (i.e. no carryover of
    -- broken note state or of triplet state)
    
    -- preserve the timing state
    local preserved_state = {triplet_state=song.internal.triplet_state, triplet_compress=song.internal.triplet_compress, prev_broken_note=song.internal.prev_broken_note, base_note_length = song.internal.base_note_length}
    song.internal.prev_broken_note = 1
    song.triplet_compress = 1
    song.internal.base_note_length = song.internal.grace_note_length -- switch to grace note timing
    
    local grace = {}
    
    for i,v in ipairs(grace_note) do
        local note_def = v
        local pitch = compute_pitch(note_def, song)
        local duration = compute_duration(note_def, song)
        table.insert(grace, {pitch=pitch, duration=duration, grace=note_def})
    end
    
    -- restore timing state
    song.internal.prev_broken_note = preserved_state.prev_broken_note
    song.internal.triplet_compress = preserved_state.triplet_compress
    song.internal.triplet_state= preserved_state.triplet_state
    song.internal.base_note_length = preserved_state.base_note_length
    
    -- insert the grace sequence
    table.insert(song.opus, {event='grace', grace=grace_note, sequence=grace})
   
   table_print(grace)
end
    
function insert_note(note, song)
        -- insert a new note into the song
        local note_def = note.note_def
        local pitch = compute_pitch(note_def, song)
        local duration = compute_duration(note_def, song)
       
        -- insert grace notes before the main note, if there are any
        if note.grace then
            insert_grace(note.grace, song)
        end
        
        
        -- insert the note events
        if pitch==-1 then
            -- rest
            table.insert(song.opus, {event='rest', duration=duration,
            note=note})        
        else       
            -- pitched note
            table.insert(song.opus, {event='note', pitch=pitch, duration=duration, note = note})
            
        end

        
        
       
        -- update tuplet counter; if back to zero, reset triplet compression
        if song.internal.triplet_state>0 then 
            song.internal.triplet_state = song.internal.triplet_state - 1
        else
            song.internal.triplet_compress = 1
        end
    
end
