-- Functions for compiling notes in context (e.g. computing duration and pitch)

function compute_pitch(note, song)
    -- compute the real pitch (in MIDI notes) of a note event
    -- taking into account: 
    --  written pitch
    --  capitalisation
    --  octave modifier
    --  current key signature
    --  accidentals
    --  transpose and octave shift
    local context = song.context
    local pitch = note.pitch
    -- -1 indicates a rest note
    if note.rest or note.measure_rest or note.space then
        return nil
    end
    
    local accidental
    
    -- in K:none mode or propagate-accidentals is off, 
    -- accidentals don't persist until the end of the bar. 
    if context.key.none or context.propagate_accidentals=='not' then
        -- must specify accidental as there is no key mapping
        accidental = pitch.accidental or {num=0, den=0}
    else
        local accidental_key 
        -- in 'octave' mode, accidentals only propagate within an octave
        -- otherwise, they propagate to all notes of the same pitch class
        if context.propagate_accidentals=='octave' then
           accidental_key = pitch.octave..pitch.note
        else
           accidental_key = pitch.note
        end
        
        -- get the appropriate accidental
        if pitch.accidental then
            context.accidental[accidental_key] = pitch.accidental
            accidental = pitch.accidental
        else
            accidental = context.accidental[accidental_key]
        end            
    end    
    local base_pitch
    base_pitch = midi_note_from_note(context.key_mapping, note, accidental)                
    base_pitch = base_pitch + context.global_transpose + context.voice_transpose
    return base_pitch 
end

function compute_bar_length(song)
    -- return the current length of one bar
    local note_length = song.context.note_length or song.context.default_note_length
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
    local timing = song.context.timing
    local duration = note.duration
    local meter = song.context.meter
    if note.space then return 0,0,0 end
    
    -- we are guaranteed to have filled out the num and den fields
    local length = duration.num / duration.den
        
    -- measure rest (duration is in bars, not unit lengths)
    if note.measure_rest then   
        -- one bar =  meter ratio * note length (e.g. 1/16 = 16)
        local bar = compute_bar_length(song) *  length 
        return bar, length*meter.num, length
    end
    
    
    local shift = 1
    local this_note = 1
    local next_note = 1
    
    local prev_note = 1
    
    -- take into account previous dotted note, if needed
    if timing.prev_broken_note then
        prev_note = timing.prev_broken_note
    else
        prev_note = 1
    end
    
    -- deal with broken note information
    -- a < shortens this note by 0.5, and increases the next by 1.5
    -- vice versa for >
    -- multiple > (e.g. >> or >>>) lengthens by 1.75 (0.25) or 1.875 (0.125) etc.
    if duration.broken then
        shift = math.pow(song.context.broken_ratio, math.abs(duration.broken))
        if duration.broken<0 then
            this_note = 1.0 / shift
            next_note = 1.0 + 1 - (1.0 / shift)
        else
            this_note = 1.0 + 1 - (1.0 / shift)
            next_note = (1.0 / shift)
        end
        
        -- store for later
        timing.prev_broken_note = next_note
    else
        timing.prev_broken_note = 1
    end
    
    local beats = length * this_note * prev_note * timing.triplet_compress    
    length = beats * timing.base_note_length * 1e6
    local note_length = song.context.note_length or song.context.default_note_length

    local notes = beats/note_length
    local bars = notes*meter.den/meter.num
    
    return length, notes, bars
end


function expand_grace(song, grace_note)
    -- Expand a grace note sequence 
    -- grace notes have their own separate timing (i.e. no carryover of
    -- broken note state or of triplet state)
    
    -- preserve the timing state, and the accidental propagation state
    -- accidentals propagate IN from the surrounding context, but not out again
    local preserved_state = deepcopy(song.context.timing)
    local preserved_accidentals = deepcopy(song.context.accidentals)
    
    song.context.timing.prev_broken_note = 1
    reset_triplet_state(song)
       
    local grace = {}
    
    for i,v in ipairs(grace_note) do        
        compile_note(v, song)
        table.insert(grace, v)
    end
    
    -- restore timing state
    song.context.timing = preserved_state
    song.context.accidentals = preserved_accidentals
    -- insert the grace sequence   
    return grace

end
    
    
function compile_note(note, song)
    -- compile a single note: compute pitch and duration
    local pitch = compute_pitch(note, song)
    local duration, notes, bars = compute_duration(note, song)
    
    -- insert grace notes before the main note, if there are any
    if note.grace then
            note.grace.sequence = expand_grace(song, note.grace) 
    end
    note.play_pitch = pitch
    note.play_duration = duration
    note.play_notes = notes
    note.play_bars = bars
    
    note.play_bar_time = song.context.timing.bar_time    
        -- advance time, update tuplet state
    update_tuplet_state(song)   
    -- advance bar time (in fractions of a bar)
    song.context.timing.bar_time = song.context.timing.bar_time + note.play_bars
    return note
end


function insert_note(note, song, token_index, abc)
        -- insert a new note into the song
       
        note = compile_note(note, song)
        
        -- extract any chords into a separate event
        if note.chord then
            local chord = {event='chord', chord=note.chord, token_index=token_index}
            chord.chord.notes = get_chord_notes(chord.chord, {}, song.context.key)
            song.opus[#song.opus+1] = chord
        end
        
       -- free text annotations
       if note.text then
            for i,v in ipairs(note.text) do
                local text = {event='text', text=v, token_index=token_index}
                song.opus[#song.opus+1] = text
            end
        end
      
     
        -- insert the note events
        if note.play_pitch==nil then
            -- rest            (strip out 0-duration y rests)
            if note.play_duration>0 then
                song.opus[#song.opus+1] = {event='rest', note=note, token_index=token_index, abc=abc}
            end            
        else       
            -- pitched note            
            song.opus[#song.opus+1] = {event='note', note=note, token_index=token_index, abc=abc}
        end
       
end
