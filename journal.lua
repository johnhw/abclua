-- Functions from transforming a parsed journal stream into a song structure and then an event stream

function update_timing(song)
    -- Update the base note length (in seconds), given the current L and Q settings
    local total_note = 0
    local rate = 0
    
    note_length = song.internal.note_length or default_note_length(song)
    
    for i,v in ipairs(song.internal.tempo) do
        total_note = total_note + (v.num / v.den)
    
    end                    
    rate = 60.0 / (total_note * song.internal.tempo.div_rate)
    song.internal.timing.base_note_length = rate / note_length
    -- grace notes assumed to be 32nds
    song.internal.timing.grace_note_length = rate / 32
end    



function is_compound_time(song)
    -- return true if the meter is 6/8, 9/8 or 12/8
    -- and false otherwise
    local meter = song.internal.meter_data
    if meter then
        if meter.den==8 and (meter.num==6 or meter.num==9 or meter.num==12) then
            return true
        end
    end
    return false
end


function default_note_length(song)
    -- return the default note length
    -- if meter.num/meter.den > 0.75 then 1/8
    -- else 1/16
    if song.internal.meter_data then
        ratio = song.internal.meter_data.num / song.internal.meter_data.num
        if ratio>=0.75 then
            return 8
        else
            return 16
        end
    end
end

function apply_repeats(song, bar)
        -- clear any existing material
        if bar.type=='start_repeat' then
            add_section(song, 1)
        end
                                
        -- append any repeats, and variant endings
        if bar.type=='mid_repeat' or bar.type=='end_repeat' then
        
            add_section(song, bar.end_reps+1)
            
            -- mark that we will now go into a variant mode
            if bar.variant_range then
                -- only allows first element in range to be used (e.g. can't do |1,3 within a repeat)
                song.internal.in_variant = bar.variant_range[1]
            else
                song.internal.in_variant = nil
            end            
        end
        
        -- part variant; if we see this we go into a new part
        if bar.type=='variant' then
            start_variant_part(song, bar)
        end        
end


function expand_journal(song)
    -- expand a journal into a song structure
    
    for i,v in ipairs(song.journal) do
   
        -- write in the ABC notation event as a string
        table.insert(song.opus, {event='abc', abc=abc_element(v)}) 
        
        -- copy in standard events that don't change the internal state
        if v.event ~= 'note' then
            table.insert(song.opus, deepcopy(v))
        else
           insert_note(v.note, song)                                         
        end
       
        -- end of header; store metadata so far
        if v.event=='header_end' then
            song.header_metadata = deepcopy(song.metadata)
            song.header_internal = deepcopy(song.internal) 
        end
       
        -- deal with triplet definitions
        if v.event=='triplet' then                
            -- update the internal tuplet state so that timing is correct for the next notes
            apply_triplet(song, v.triplet)
            end
        
        -- deal with bars and repeat symbols
        if v.event=='bar' then
            apply_repeats(song, v.bar)                               
            song.internal.accidental = nil -- clear any lingering accidentals             
        end
            
        
        if v.event=='append_text_field' then      
            song.metadata[v.name] = song.metadata[v.name] .. v.content
        end
        
        -- new voice
        if v.event=='voice_change' then
            start_new_voice(song, v.voice.id)
        end
         
        if v.field then               
            song.metadata[v.field.name] = v.field.content
        end
        
        if v.event=='note_length' then
             song.internal.note_length = v.note_length
            update_timing(song)
        end
        
        if v.event=='tempo' then
            song.internal.tempo = v.tempo
            update_timing(song)
        end
        
        if v.event=='words' then                            
            append_table(song.internal.lyrics, v.lyrics)
        end
            
        if v.event=='parts' then
            song.internal.part_structure = v.parts
            song.internal.part_sequence = expand_parts(song.internal.part_structure)      
        end
        
        if v.event=='new_part' then
            song.in_variant_part = nil -- clear the variant flag
            start_new_part(song, v.part)    
        end
        
        if v.event=='meter' then  
            song.internal.meter_data = v.meter
            update_timing(song)   
        end
        
        -- update key
        if v.event=='key' then            
            song.internal.key_data = v.key
            apply_key(song, song.internal.key_data)
        end
 
    
    end
    
end



function apply_key(song, key_data) 
    -- apply transpose / octave to the song state
    if key_data.clef then                 
        if key_data.clef.octave then
            song.internal.global_transpose = 12 * key_data.clef.octave -- octave shift
        else
            song.internal.global_transpose = 0
        end
        
        if key_data.clef.transpose then 
            song.internal.global_transpose = song.internal.global_transpose + key_data.clef.transpose                
        end
    end 
    
    -- update key map
    song.internal.key_mapping = create_key_structure(key_data.naming)
end


function start_new_voice(song, voice)
    -- compose old voice into parts
    if song.internal and song.internal.voice then
        finalise_song(song)
        song.voices[song.internal.voice] = {stream=song.stream, internal=song.internal}
    end
    
    -- reset song state
    -- set up internal state
    song.internal.lyrics = {}
    song.internal.current_part = 'default'
    song.internal.part_map = {}
    song.internal.pattern_map = {}
    song.internal.timing = {}
    
    song.internal.timing.triplet_state = 0
    song.internal.timing.triplet_compress = 1
    song.internal.timing.prev_broken_note = 1
    song.internal.voice = voice
    song.temp_part = {}
    song.opus = song.temp_part
        
    update_timing(song) -- make sure default timing takes effect    
end

function finalise_song(song)
    -- Finalise a song's event stream
    -- Composes the parts, repeats into a single stream
    -- Inserts absolute times into the events 
    -- Inserts the lyrics into the song

    compose_parts(song)
    
    -- clear temporary data
    song.opus = nil
    song.temp_part = nil 
 
    -- time the stream and add lyrics
    time_stream(song.stream)
    song.stream = insert_lyrics(song.internal.lyrics, song.stream)
    
end




function journal_to_stream(song, internal, metadata)

    
    -- Convert a journal into a full
    -- a song datastructure. 
    -- 
    -- song.metadata contains header data about title, reference number, key etc.
    --  stored as plain text
   
    -- The song contains a table of voices
    -- each voice contains:
    -- voice.stream: a series of events (e.g. note on, note off)
    --  indexed by microseconds,
    -- voice.internal contains all of the parsed song data
   
    
    -- copy any inherited data from the file header
    
    song.default_internal = internal
    song.internal = deepcopy(song.default_internal)
   
    song.voices = {}
    song.metadata = metadata    
    start_new_voice(song, 'default')
    expand_journal(song)
    
    -- finalise the voice
    start_new_voice(song, nil)
    
    -- clean up
    song.internal = nil
    song.stream = nil
    
end