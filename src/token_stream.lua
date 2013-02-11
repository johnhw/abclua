-- Functions from transforming a parsed token_stream stream into a song structure and then an event stream


function default_note_length(song)
    -- return the default note length
    -- if meter.num/meter.den > 0.75 then 1/8
    -- else 1/16
    if song.context.meter_data then
        local ratio = song.context.meter_data.num / song.context.meter_data.num
        if ratio>=0.75 then
            return 8
        else
            return 16
        end
    end
    return 8
end


function update_timing(song)
    -- Update the base note length (in seconds), given the current L and Q settings
    local total_note = 0
    local rate = 0    
    local note_length = song.context.note_length or default_note_length(song)
    
    for i,v in ipairs(song.context.tempo) do
        total_note = total_note + (v.num / v.den)
    
    end                    
    rate = 60.0 / (total_note * song.context.tempo.div_rate)
    song.context.timing.base_note_length = rate / note_length
    -- grace notes assumed to be 32nds
    song.context.timing.grace_note_length = rate / 32
end    



function is_compound_time(song)
    -- return true if the meter is 6/8, 9/8 or 12/8
    -- and false otherwise
    local meter = song.context.meter_data
    if meter then
        if meter.den==8 and (meter.num==6 or meter.num==9 or meter.num==12) then
            return true
        end
    end
    return false
end


function apply_repeats(song, bar)
        -- clear any existing material
        if bar.type=='start_repeat' then
            add_section(song, 1)
        end
                                
        -- append any repeats, and variant endings
        if bar.type=='mid_repeat' or bar.type=='end_repeat' or bar.type=='double' or bar.type=='thickthin' or bar.type=='thinthick' then
        
            add_section(song, bar.end_reps+1)
            
            -- mark that we will now go into a variant mode
            if bar.variant_range then
                -- only allows first element in range to be used (e.g. can't do |1,3 within a repeat)
                song.context.in_variant = bar.variant_range[1]
            else
                song.context.in_variant = nil
            end            
        end
        
        -- part variant; if we see this we go into a new part
        if bar.type=='variant' then
            start_variant_part(song, bar)
        end        
end


function apply_key(song, key_data) 
    -- apply transpose / octave to the song state
    if key_data.clef then                 
        if key_data.clef.octave then
            song.context.global_transpose = 12 * key_data.clef.octave -- octave shift
        else
            song.context.global_transpose = 0
        end
        
        if key_data.clef.transpose then 
            song.context.global_transpose = song.context.global_transpose + key_data.clef.transpose                
        end
    end 
    
    -- update key map
    song.context.key_mapping = create_key_structure(key_data.naming)
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
    song.stream = insert_lyrics(song.context.lyrics, song.stream)
    time_stream(song.stream)
    
end


function start_new_voice(song, voice)
    -- compose old voice into parts
    if song.context and song.context.voice then
        finalise_song(song)
        song.voices[song.context.voice] = {stream=song.stream, context=song.context}
    end

    -- reset song state
    -- set up context state
    song.context.lyrics = {}
    song.context.current_part = 'default'
    song.context.part_map = {}
    song.context.pattern_map = {}
    song.context.timing = {}
    
    song.context.timing.triplet_state = 0
    song.context.timing.triplet_compress = 1
    song.context.timing.prev_broken_note = 1
    song.context.voice = voice
    song.temp_part = {}
    song.opus = song.temp_part
        
    update_timing(song) -- make sure default timing takes effect    
end


function expand_token_stream(song)
    -- expand a token_stream into a song structure
    
    for i,v in ipairs(song.token_stream) do
   
        -- write in the ABC notation event as a string
        table.insert(song.opus, {event='abc', abc=abc_element(v)}) 
        
        -- copy in standard events that don't change the context state
        if v.event ~= 'note' then
            table.insert(song.opus, deepcopy(v))
        else
           insert_note(v.note, song)                                         
        end
       
        -- end of header; store metadata so far
        if v.event=='header_end' then
            song.header_metadata = deepcopy(song.metadata)
            song.header_context = deepcopy(song.context) 
        end
       
        -- deal with triplet definitions
        if v.event=='triplet' then                
            -- update the context tuplet state so that timing is correct for the next notes
            apply_triplet(song, v.triplet)
            end
        
        -- deal with bars and repeat symbols
        if v.event=='bar' then
            apply_repeats(song, v.bar)                               
            song.context.accidental = nil -- clear any lingering accidentals             
        end
            
       
        if v.event=='append_field_text' then       
            song.metadata[v.field.name] = song.metadata[v.field.name] .. ' ' .. v.content
        else
            if v.field then               
                song.metadata[v.field.name] = v.field.content
            end
        end
        
        -- new voice
        if v.event=='voice_change' then
            start_new_voice(song, v.voice.id)
        end
         
        
        if v.event=='note_length' then
             song.context.note_length = v.note_length
            update_timing(song)
        end
        
        if v.event=='tempo' then
            song.context.tempo = v.tempo
            update_timing(song)
        end
        
        if v.event=='words' then                            
            append_table(song.context.lyrics, v.lyrics)
        end
            
        if v.event=='parts' then
            song.context.part_structure = v.parts
            song.context.part_sequence = expand_parts(song.context.part_structure)      
        end
        
        if v.event=='new_part' then
            song.in_variant_part = nil -- clear the variant flag
            start_new_part(song, v.part)    
        end
        
        if v.event=='meter' then  
            song.context.meter_data = v.meter
            update_timing(song)   
        end
        
        -- update key
        if v.event=='key' then            
            song.context.key_data = v.key
            apply_key(song, song.context.key_data)
        end
 
    
    end
    
end





function token_stream_to_stream(song, context, metadata)
    -- Convert a token_stream into a full
    -- a song datastructure. 
    -- 
    -- song.metadata contains header data about title, reference number, key etc.
    --  stored as plain text
   
    -- The song contains a table of voices
    -- each voice contains:
    -- voice.stream: a series of events (e.g. note on, note off)
    --  indexed by microseconds,
    -- voice.context contains all of the parsed song data
   
    
    -- copy any inherited data from the file header
    
    song.default_context = context
    song.context = deepcopy(song.default_context)
   
    song.voices = {}
    song.metadata = metadata    
    start_new_voice(song, 'default')
    expand_token_stream(song)
    
    -- finalise the voice
    start_new_voice(song, nil)
    
    -- clean up
    song.stream = nil
    
end