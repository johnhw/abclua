local pitch_table = {c=0, d=2, e=4, f=5, g=7, a=9, b=11}


function default_note_length(song)
    -- return the default note length
    -- if meter.num/meter.den > 0.75 then 1/8
    -- else 1/16
    if song.context.meter then
        local ratio = song.context.meter.num / song.context.meter.num
        if ratio>=0.75 then
            return 8
        else
            return 16
        end
    end
    return 8
end


function canonicalise_duration(duration)
    -- fill in duration field; remove slashes
    -- and fill in numerator and denominator
    
    if duration.slashes and not duration.den then
         local den = 1
         local l = string.len(duration.slashes)
         for i = 1,l do
            den = den * 2
         end
         duration.den = den
    end
    
    if not duration.num then
        duration.num = 1
    end
    
    if not duration.den then
        duration.den = 1
    end
    duration.slashes = nil

end

function canonicalise_accidental(accidental)
    -- Transform string indicator to integer and record any fractional part
    -- (for microtonal tuning)
    local acc = accidental[1]
    local value
    local fraction = {num=1, den=1}

    -- fractional accidentals
    if accidental[2] and (accidental[2].num or accidental[2].slashes) then
        canonicalise_duration(accidental[2])
        fraction = accidental[2] 
    end
        
    -- accidentals
    if acc == '^' then
       value = {num=fraction.num, den=fraction.den}
    end
    
    if acc == '^^' then
       value = {num=2*fraction.num, den=fraction.den}
    end
    
    if acc == '_' then
        value = {num=-fraction.num, den=fraction.den}
    end
    
    if acc == '__' then
        value = {num=-2*fraction.num, den=fraction.den}
    end
    
    if acc == '=' then
        value = {num=0, den=0}
    end
    
    return value

end

function canonicalise_note(note)
    -- Canonicalise a note, filling in the full duration field. 
    -- Remove slashes from the duration
    -- Fills in full duration field
    -- Replaces broken with an integer representing the dotted value (e.g. 0 = plain, 1 = once dotted,
    --  2 = twice, etc.)    
    canonicalise_duration(note.duration)
        
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
    else
        note.duration.broken = 0
    end
  
  if note.pitch then
      -- add octave shifts  
      
        local octave = 0
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
        end        
        note.pitch.note = string.lower(note.pitch.note)
        note.pitch.octave = octave        
        if note.pitch.accidental then
            note.pitch.accidental  =  canonicalise_accidental(note.pitch.accidental)
        end
    end
    
    -- tied notes
    if note.tie then
        note.tie = true
    end
        
    if note.decoration then        
        -- clean up decorations (replace +xxx+ with !xxx!)    
        for i,v in ipairs(note.decoration) do            
            if string.sub(v,1,1)=='+'  then
                note.decoration[i] = '!'..string.sub(v,2,-2)..'!'
            end
        end        
    end
    
    note.duration.slashes = nil
    return note        
end

function make_note(note)
    -- Clean up a note structure. 
    -- Clean up the duration and pitch of notes and any grace notes
    -- Replace the decoration string with a sequence of decorators
    -- fix the note itself
    canonicalise_note(note)
    
    -- and the grace notes
    if note.grace then
        for i,v in ipairs(note.grace) do
            canonicalise_note(v)
        end
    end
    
    
    return note
    
end

function parse_note(note)
    -- move note def into the note itself
    
    for i,v in pairs(note.note_def) do
        note[i] = v
    end
    note.note_def = nil
    return make_note(note)
    
end


function get_semitone(key_mapping, pitch, accidental)
    -- return the semitone of a note (0-11) in a given key, with the given accidental
    local base_pitch = pitch_table[pitch]    
           
    -- accidentals / keys
    if accidental then   
        if accidental.den==0 then 
            accidental =  0 
        else
            accidental = accidental.num / accidental.den
        end
        base_pitch = base_pitch + accidental        
    else        
        -- apply key signature sharpening / flattening
        if key_mapping then
            accidental = key_mapping[string.lower(pitch)]
            base_pitch = base_pitch + (accidental)
        end
    end        
    return base_pitch 
end

function midi_note_from_note(mapping, note, accidental)
    -- Given a key mapping, get the midi note of a given note        
    -- optionally applying a forced accidental
    accidental = note.pitch.accidental or accidental    
    local base_pitch = get_semitone(mapping, note.pitch.note, accidental)    
    return base_pitch + 60 + (note.pitch.octave or 0) * 12
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
    if note.rest or note.measure_rest or note.space then
        return nil
    end
    
    local accidental
    
    -- in K:none mode or propagate-accidentals is off, 
    -- accidentals don't persist until the end of the bar. 
    if song.context.key.none or song.context.propagate_accidentals=='not' then
        -- must specify accidental as there is no key mapping
        accidental = note.pitch.accidental or {num=0, den=0}
    else
        local accidental_key 
        -- in 'octave' mode, accidentals only propagate within an octave
        -- otherwise, they propagate to all notes of the same pitch class
        if song.context.propagate_accidentals=='octave' then
           accidental_key = note.pitch.octave..note.pitch.note
        else
           accidental_key = note.pitch.note
        end
        
        -- get the appropriate accidental
        if note.pitch.accidental then
            song.context.accidental[accidental_key] = note.pitch.accidental
            accidental = note.pitch.accidental
        else
            accidental = song.context.accidental[accidental_key]
        end            
    end    
    local base_pitch
    base_pitch = midi_note_from_note(song.context.key_mapping, note, accidental)                
    base_pitch = base_pitch + song.context.global_transpose + song.context.voice_transpose
    return base_pitch 
end

function compute_bar_length(song)
    -- return the current length of one bar
    local note_length = song.context.note_length or default_note_length(song)
    return (song.context.meter.num / song.context.meter.den) * note_length * song.context.timing.base_note_length * 1e6 
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
    
    if note.space then return 0 end
    
    -- we are guaranteed to have filled out the num and den fields
    local length = note.duration.num / note.duration.den
    
    
    -- measure rest (duration is in bars, not unit lengths)
    if note.measure_rest then   
        -- one bar =  meter ratio * note length (e.g. 1/16 = 16)
        return compute_bar_length(song) *  length
    end
    
    
    local shift = 1
    local this_note = 1
    local next_note = 1
    
    local prev_note = 1
    
    -- take into account previous dotted note, if needed
    if song.context.timing.prev_broken_note then
        prev_note = song.context.timing.prev_broken_note
    else
        prev_note = 1
    end
    
    -- deal with broken note information
    -- a < shortens this note by 0.5, and increases the next by 1.5
    -- vice versa for >
    -- multiple > (e.g. >> or >>>) lengthens by 1.75 (0.25) or 1.875 (0.125) etc.
    if note.duration.broken then
        shift = math.pow(song.context.broken_ratio, math.abs(note.duration.broken))
        
        if shift<0 then
            this_note = 1.0 / -shift
            next_note = 1.0 + 1 - (1.0 / -shift)
        else
            this_note = 1.0 + 1 - (1.0 / shift)
            next_note = (1.0 / shift)
        end
        
        -- store for later
        song.context.timing.prev_broken_note = next_note
    else
        song.context.timing.prev_broken_note = 1
    end
        
    length = length * song.context.timing.base_note_length * this_note * prev_note * 1e6 * song.context.timing.triplet_compress
   
  
    return length
   
end


function update_triplet_ratio(song)
    -- compute the current compression ratio
    -- The product of all active triplets
    local ratio = 1
    for i,v in ipairs(song.context.timing.triplet_state) do
        ratio = ratio / v.ratio
    end
    song.context.timing.triplet_compress = ratio
end

function push_triplet(song, p, q, r)
    -- push a new triplet onto the stack
    table.insert(song.context.timing.triplet_state, {count=r, ratio=p/q})
    update_triplet_ratio(song)
end

function update_tuplet_state(song)
    -- a note has occured; change tuplet state
    -- update tuplet counters; if back to zero, remove that triplet
    
    local actives = {}
    for i,v in ipairs(song.context.timing.triplet_state) do
        v.count = v.count-1
        -- keep only triplets with counters > 0
        if v.count > 0 then
            table.insert(actives, v)
        end
    end    
    song.context.timing.triplet_state = actives
        
    -- update the time compression
    update_triplet_ratio(song)

end

function apply_triplet(song, triplet)
    -- set the triplet fields in the song
    local p,q,r
    
    if triplet.q == 'n' then
        -- check if compound time -- if so
        -- the default timing for (5 (7 and (9 changes
        if is_compound_time(song) then
            q = 3
        else    
            q = 2
        end
    else
        q = triplet.q
    end
    p = triplet.p
    r = triplet.r 
    
    -- set compression and number of notes to apply this to    
    push_triplet(song, triplet.p, triplet.q, triplet.r)
    
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

    -- allow long triplets
    -- if p>9 then
        -- warn("Bad triplet length (p>9)")
    -- end
    
    -- default to choosing q from the table
    local q_table = {-1,3,2,3,'n',2,'n',3,'n'}
    if q==-1 then
        q = q_table[p]
    end
        
    return {p=p, q=q, r=r}
end

function expand_grace(song, grace_note)
    -- insert a grace note sequence into a song
    -- grace notes have their own separate timing (i.e. no carryover of
    -- broken note state or of triplet state)
    
    -- preserve the timing state
    local preserved_state = deepcopy(song.context.timing)
    
    song.context.timing.prev_broken_note = 1
    song.context.timing.triplet_compress = 1
    song.context.timing.base_note_length = song.context.timing.grace_note_length -- switch to grace note timing
       
    local grace = {}
    
    for i,v in ipairs(grace_note) do
        local note_def = v
        local pitch = compute_pitch(note_def, song)
        local duration = compute_duration(note_def, song)
        table.insert(grace, {pitch=pitch, duration=duration, grace=note_def})
    end
    
    -- restore timing state
    song.context.timing = preserved_state
    
    -- insert the grace sequence   
    return grace

end
    
    



function insert_note(note, song)
        -- insert a new note into the song
        local note_def = note
        local pitch = compute_pitch(note_def, song)
        local duration = compute_duration(note_def, song)
       
        -- insert grace notes before the main note, if there are any
        if note.grace then
            note.grace.sequence = expand_grace(song, note.grace) 
        end
        
        -- extract any chords into a separate event
        if note.chord then
            table.insert(song.opus, {event='chord', chord=note.chord})
        end
      
        -- insert the note events
        if pitch==nil then
            -- rest            (strip out 0-duration y rests)
            if duration>0 then
                table.insert(song.opus, {event='rest', duration=duration, bar_time = song.context.timing.bar_time,
                note=note})    
            end            
        else       
            -- pitched note
            table.insert(song.opus, {event='note', pitch=pitch, bar_time = song.context.timing.bar_time, duration=duration, note = note})
            
        end
    
        update_tuplet_state(song)
   
        
        -- advance bar time (in fractions of a bar)
        song.context.timing.bar_time = song.context.timing.bar_time + duration / song.context.timing.bar_length
end
