-- Functions from transforming a parsed token stream into a song structure and then an event stream

function get_bpm_from_tempo(tempo)
    -- return the real bpm of a tempo 
    local total_note = 0
    for i,v in ipairs(tempo) do
        total_note = total_note + (v.num / v.den)
    end                    
    
    local rate = 60.0 / (total_note * tempo.tempo_rate)
    return rate
end

function update_timing(song)
    -- Update the base note length (in seconds), given the current L and Q settings
    -- Returns a timing state update event to be inserted into the output stream
    local rate = 0    
    local note_length = song.context.note_length or default_note_length(song)
    
    rate = get_bpm_from_tempo(song.context.tempo)
    song.context.timing.base_note_length = rate / note_length
    
    song.context.timing.grace_note_length = rate / (song.context.grace_length.den/song.context.grace_length.num)
    song.context.timing.bar_length = compute_bar_length(song)
        
    table.insert(song.opus, {event='timing_change', timing={base_note_length=song.context.timing.base_note_length*1e6, bar_length=song.context.timing.bar_length,
    beats_in_bar = song.context.meter.num, note_length=note_length, beat_length = song.context.timing.bar_length/song.context.meter.num}})
end    

function is_compound_time(song)
    -- return true if the meter is 6/8, 9/8 or 12/8
    -- and false otherwise
    local meter = song.context.meter
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

function apply_key(song, key) 
    -- apply transpose / octave to the song state
    if key.clef then                 
        if key.clef.octave then
            song.context.global_transpose = 12 * key.clef.octave -- octave shift
        else
            song.context.global_transpose = 0
        end
        
        if key.clef.transpose then 
            song.context.global_transpose = song.context.global_transpose + key.clef.transpose                
        end
    end 
    
    -- update key map
    song.context.key_mapping = create_key_structure(key)
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
    song.stream = insert_lyrics(song.context.lyrics, song.stream)
end


function apply_voice_specifiers(song)
    -- apply the voice specifiers. this sets the voice transpose if need be
    song.context.voice_transpose = 0
    -- compute transpose
    local transpose =  song.context.voice_specifiers.transpose or  song.context.voice_specifiers.t or 0
    local octaves =   (song.context.voice_specifiers.octave) or 0
    
    -- look for '+8' or '-8' at the end of a clef (e.g. treble+8)
    if song.context.voice_specifiers.clef then
        local clef = song.context.voice_specifiers.clef
        if string.len(clef)>2 and string.sub(clef,-2)=='+8' then octaves=octaves+1 end
        if string.len(clef)>2 and string.sub(clef,-2)=='-8' then octaves=octaves-1 end
    end
    
    song.context.voice_transpose = 12*octaves + transpose   
    
end


function reset_timing(song)
    -- reset the timing state of the song
    song.context.timing = {} 
    song.context.timing.triplet_state = {}    
    song.context.timing.triplet_compress = 1
    song.context.timing.prev_broken_note = 1
    song.context.timing.bar_time = 0
    update_timing(song)
end


function reset_bar_time(song)
    -- if warnings are enabled, mark underfull and overfull bars
    if song.context.bar_warnings then    
        if song.context.timing.bar_time>1 then
            warn('Overfull bar')
        end
        
        if song.context.timing.bar_time<1 then
            warn('Underfull bar')
        end
    end
    
    song.context.timing.bar_time = 0
end

function start_new_voice(song, voice, specifiers)
    -- compose old voice into parts
    if song.context and song.context.voice then
        finalise_song(song)                
        song.voices[song.context.voice] = {stream=song.stream, context=song.context}
    end

    song.context.voice_specifiers = {}    
    -- merge in voice specifiers from heder and from this definition line
    if song.voice_specifiers[voice] then
        for i,v in pairs(song.voice_specifiers[voice]) do
            song.context.voice_specifiers[v.lhs] = v.rhs            
        end    
    end
    
    if specifiers then
        for i,v in pairs(specifiers) do
            song.context.voice_specifiers[v.lhs] = v.rhs
        end    
    end    
    
    apply_voice_specifiers(song)
    
    -- reset song state
    -- set up context state
    song.context.lyrics = {}
    song.context.current_part = 'default'
    song.context.part_map = {}
    song.context.pattern_map = {}
    
    song.context.voice = voice
    song.temp_part = {}
    song.opus = song.temp_part
    reset_timing(song)
            
end


function precompile_token_stream(token_stream)
    -- run through a token stream, giving duration and pitches to all notes
    -- splitting off chord symbols. Does not expand repeats/parts/voices/etc.
    -- One-to-one mapping of original token stream (no tokens added or removed)
    local song = {context=get_default_context(), opus={}}
    reset_timing(song)

    for i,v in ipairs(token_stream) do
        -- notes
        if v.token=='note' then 
           compile_note(v.note, song)
           advance_note_time(song, v.note.play_duration)
        end
        
        -- deal with triplet definitions
        if v.token=='triplet' then                
            -- update the context tuplet state so that timing is correct for the next notes
            apply_triplet(song, v.triplet)
        end
        
        -- deal with bars and repeat symbols
        if v.token=='bar' then
            reset_bar_time(song)
            song.context.accidental = {} -- clear any lingering accidentals             
        end
          
        if v.token=='note_length' then
            song.context.note_length = v.note_length
            update_timing(song)
        end
        
        if v.token=='tempo' then
            song.context.tempo = v.tempo
            update_timing(song)
        end
               
        if v.token=='meter' then  
            song.context.meter = v.meter
            update_timing(song)  
        end
        
        -- update key
        if v.token=='key' then            
            song.context.key = v.key
            apply_key(song, song.context.key)
        end
    end
end

function expand_token_stream(song)
    -- expand a token_stream into a song structure
    
    for i,v in ipairs(song.token_stream) do
   
        if song.context.write_abc_events then
            -- write in the ABC notation event as a string
            table.insert(song.opus, {event='abc', abc=abc_element(v)})
        end
        
        local event
        -- copy in standard events that don't change the context state
        if v.token ~= 'note' then
           event = copy_table(v)
           event.event = event.token
           event.token = nil
           table.insert(song.opus, event)
        else
           insert_note(v.note, song)                                         
        end
       
        -- end of header; store metadata so far
        if v.token=='header_end' then
            song.header_metadata = deepcopy(song.metadata)
            song.header_context = deepcopy(song.context) 
        end
       
        -- deal with triplet definitions
        if v.token=='triplet' then                
            -- update the context tuplet state so that timing is correct for the next notes
            apply_triplet(song, v.triplet)
        end
        
        -- deal with bars and repeat symbols
        if v.token=='bar' then
            reset_bar_time(song)
            apply_repeats(song, v.bar)  
            song.context.accidental = {} -- clear any lingering accidentals             
        end
        
            
        -- text fields
        if v.token=='field_text'  then       
            if song.metadata[v.name] then
                table.insert(song.metadata[v.name], v.content)
            else            
                song.metadata[v.name] =  {v.content}
            end
        end                
        
        -- append fields
        if v.token=='append_field_text' then
            local last
            if song.metadata[v.name] then
                last = song.metadata[v.name][#song.metadata[v.name]] 
                last = last..' '..v.content
                song.metadata[v.name][#song.metadata[v.name]]  = last                
            else
                warn("Continuing a field with +: that doesn't exist.")
            end          
                
        end
        
        -- new voice
        if v.token=='voice_change' then
            start_new_voice(song, v.voice.id, v.voice.specifiers)
        end
        
        if v.token=='voice_def' then
            -- store any voice specific settings for later
            song.voice_specifiers[v.voice.id] = v.voice.specifiers
        end
        
        if v.token=='instruction' then
            if v.directive then
                apply_directive(song, v.directive.directive, v.directive.arguments)
            end
        end
         
        
        if v.token=='note_length' then
             song.context.note_length = v.note_length
             update_timing(song)
         end
        
        if v.token=='tempo' then
            song.context.tempo = v.tempo
            update_timing(song)
             -- store tempo string in metadata
            song.metadata.tempo = string.sub(abc_tempo(v.tempo),3)
   
        end
        
        if v.token=='words' then         
            table.insert(song.opus, {event='lyric_align'}) 
            table.insert(song.context.lyrics, v.lyrics)
        end
            
        if v.token=='parts' then
            song.context.part_structure = v.parts
            song.context.part_sequence = expand_parts(song.context.part_structure)      
        end
        
        if v.token=='new_part' then
            song.in_variant_part = nil -- clear the variant flag
            start_new_part(song, v.part)    
        end
        
        if v.token=='meter' then  
            song.context.meter = v.meter
            update_timing(song)  
            -- store key string in metadata
            song.metadata.meter = string.sub(abc_meter(v.meter),3)
                
        end
        
        -- update key
        if v.token=='key' then            
            song.context.key = v.key
            apply_key(song, song.context.key)
            
            -- store key string in metadata
            song.metadata.key = string.sub(abc_key(v.key),3)
        end
 
    
    end
    
end


function compile_token_stream(song, context, metadata)
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
    
    song.default_context = context or get_default_context()
    song.context = song.default_context
   
    song.voices = {}
    song.voice_specifiers = {}
    song.metadata = metadata or {}
    start_new_voice(song, 'default')
    expand_token_stream(song)
    
    -- finalise the voice
    start_new_voice(song, nil)
    
    -- clean up
    song.stream = nil
    
end