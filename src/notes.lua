-- Functions for compiling notes in context (e.g. computing duration and pitch)

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
    
    if note.space then return 0,0 end
    
    -- we are guaranteed to have filled out the num and den fields
    local length = note.duration.num / note.duration.den
        
    -- measure rest (duration is in bars, not unit lengths)
    if note.measure_rest then   
        -- one bar =  meter ratio * note length (e.g. 1/16 = 16)
        local bar = compute_bar_length(song) *  length 
        return bar, bar/song.context.meter.num
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
    
    local beats = length * this_note * prev_note * song.context.timing.triplet_compress    
    length = beats * song.context.timing.base_note_length * 1e6

    return length, beats
end


function expand_grace(song, grace_note)
    -- Expand a grace note sequence 
    -- grace notes have their own separate timing (i.e. no carryover of
    -- broken note state or of triplet state)
    
    -- preserve the timing state
    local preserved_state = deepcopy(song.context.timing)
    
    song.context.timing.prev_broken_note = 1
    reset_triplet_state(song)
       
    local grace = {}
    
    for i,v in ipairs(grace_note) do        
        compile_note(v, song)
        table.insert(grace, v)
    end
    
    -- restore timing state
    song.context.timing = preserved_state
    
    -- insert the grace sequence   
    return grace

end
    
    
function compile_note(note, song)
    -- compile a single note: compute pitch and duration
    local pitch = compute_pitch(note, song)
    local duration, beats = compute_duration(note, song)
    -- insert grace notes before the main note, if there are any
    if note.grace then
            note.grace.sequence = expand_grace(song, note.grace) 
    end
    note.play_pitch = pitch
    note.play_duration = duration
    note.play_beats = beats
    note.play_bar_time = song.context.timing.bar_time
    return note
end

function advance_note_time(song, duration)
    -- advance time, update tuplet state
    update_tuplet_state(song)   
    -- advance bar time (in fractions of a bar)
    song.context.timing.bar_time = song.context.timing.bar_time + duration / song.context.timing.bar_length
end

function insert_note(note, song)
        -- insert a new note into the song
       
        note = compile_note(note, song)
        
        -- extract any chords into a separate event
        if note.chord then
            table.insert(song.opus, {event='chord', chord=note.chord})
        end
      
        -- insert the note events
        if note.play_pitch==nil then
            -- rest            (strip out 0-duration y rests)
            if note.play_duration>0 then
                table.insert(song.opus, {event='rest', note=note})    
            end            
        else       
            -- pitched note
            table.insert(song.opus, {event='note', note = note})
        end
        advance_note_time(song, note.play_duration)        
end
