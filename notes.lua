local pitch_table = {C=0, D=2, E=4, F=5, G=7, A=9, B=11}

function parse_note(note)
    -- Parse a note structure. 
    -- Clean up the duration and pitch of notes and any grace notes
    -- Replace the decoration string with a sequence of decorators
    
    -- Replace decorations with sequences
    if note.decoration then
        local decoration = {}
        for c in string.gmatch(note.decoration, '.') do
            table.insert(decoration, c)
        end
        note.decoration = decoration
    end
    
    -- fix the note itself
    if note.note_def then
        parse_note_def(note.note_def)
    end
    
    -- and the grace notes
    if note.grace then
        for i,v in ipairs(note.grace) do
            parse_note_def(v)
        end
    end
    return note
    
end

function parse_note_def(note)
    -- Canonicalise a note, filling in the full duration field. 
    -- Remove slashes from the duration
    -- Fills in full duration field
    -- Replaces broken with an integer representing the dotted value (e.g. 0 = plain, 1 = once dotted,
    --  2 = twice, etc.)
    
    -- fill in measure rests
    if note.measure_rest and not note.measure_rest.bars then
        note.measure_rest.bars = 1
    end
    
    if note.duration.slashes and not note.duration.den then
         den = 1
         local l = string.len(note.duration.slashes)
         for i = 1,l do
            den = den * 2
         end
         note.duration.den = den
    end
    
    if not note.duration.num then
        note.duration.num = 1
    end
    
    if not note.duration.den then
        note.duration.den = 1
    end

    if note.broken then
        local shift = 0
        -- get the overall shift: negative means this note gets shortened
        for c in note.broken:gmatch"." do
            
            if c == '>' then
                shift = shift + 1
            end
            if c == '<' then
                shift = shift - 1
            end
        end
        note.broken = nil
        note.duration.broken = shift
    end
  
  if note.pitch then
      -- add octave shifts  
        octave = 0
        if note.pitch.octave then
            for c in note.pitch.octave:gmatch"." do
                if c == "'" then
                    octave = octave + 1
                end
                if c==',' then 
                    octave = octave - 1
                end
            end
        end
        
        -- +1 octave for lower case notes
        if note.pitch.note == string.lower(note.pitch.note) then
            octave = octave + 1
            note.pitch.note = string.upper(note.pitch.note)
        end
        
        
        -- accidentals
        if note.pitch.accidental == '^' then
           note.pitch.accidental = 1
        end
        
        if note.pitch.accidental == '^^' then
           note.pitch.accidental = 2
        end
        
        if note.pitch.accidental == '_' then
            note.pitch.accidental = -1
        end
        
        if note.pitch.accidental == '__' then
            note.pitch.accidental = -2
        end
        
        if note.pitch.accidental == '=' then
            note.pitch.accidental = 0
        end

    end
    
    -- tied notes
    if note.tie then
        note.tie = true
    end
    
    
    note.duration.slashes = nil
    return note
    
    
end

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
    if note.rest or note.measure_rest then
        return -1
    end
    
   
    local base_pitch = pitch_table[note.pitch.note]
    
    
    if note.octave then
        base_pitch = base_pitch * note.octave * 12
    end
    
    -- accidentals / keys
    if note.pitch.accidental  then
        base_pitch = base_pitch + note.pitch.accidental
    else        
        -- apply key signature sharpening / flattening
        acc = song.internal.key_mapping[string.lower(note.pitch.note)]
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
    -- bars for multi-measure rests  
    
    local length = 1
    
    
    -- measure rest
    if note.measure_rest then   
        -- one bar =  meter ratio * note length (e.g. 1/16 = 16)
        return (song.internal.meter_data.num / song.internal.meter_data.den) * song.internal.note_length * song.internal.base_note_length * 1e6
    end
    
    -- we are guaranteed to have filled out the num and den fields
    if note.duration then
        length = note.duration.num / note.duration.den
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
    if note.duration.broken then
        shift = math.pow(2, math.abs(note.duration.broken))
        
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
