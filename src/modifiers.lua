local pitch_table = {c=0, d=2, e=4, f=5, g=7, a=9, b=11}
local pitches = {'c', 'd', 'e', 'f', 'g', 'a', 'b'}

function midi_note_from_note(key, note)
    -- Given a key, get the midi note of a given note    
    local base_pitch = pitch_table[note.pitch.note]    
   
    local mapping = create_key_structure(key)          
    -- accidentals / keys
    if note.pitch.accidental then        
        base_pitch = base_pitch + note.pitch.accidental        
    else        
        -- apply key signature sharpening / flattening
        local acc = mapping[string.lower(note.pitch.note)]
        base_pitch = base_pitch + acc
    end    
    return base_pitch
end


function diatonic_transpose(tokens, shift)
    -- transpose the given token stream by a given number of semitones    
    local current_key, original_key        
    local mapping, key_struct
    local inverse_mapping = {}
    
    shift = shift % 12
        
    for i,token in ipairs(tokens) do
        if token.token=='key' then                               
                        
            -- get new root key
            original_key = deepcopy(token.key)
            token.key.root = shift_root_key(token.key.root, shift)
            current_key = token.key            
            -- work out the semitones in this key
            mapping = create_key_structure(current_key)                                   
            key_struct = create_key_structure(current_key)                                   
            for i,v in pairs(pitch_table) do                                           
                local k = v+mapping[i]
                k = k % 12
                mapping[i] = k
                inverse_mapping[k] = i
            end           
            -- invert the table; mapping semitones to note names       
            inverse_mapping = invert_table(mapping)            
        end        
        
        if token.token=='note' and mapping then
            -- if we have a pitched note
            if token.note.pitch then                
                local semi = midi_note_from_note(original_key, token.note)  + shift
                
                -- wrap semitone to 0-11
                semi = semi % 12
                                
                -- if we don't need an accidental
                if inverse_mapping[semi] then
                    token.note.pitch.note = inverse_mapping[semi]       
                    token.note.pitch.accidental = nil
                else
                    -- check the next note
                    token.note.pitch.note = inverse_mapping[(semi+1)%12]                     
                    t = key_struct[token.note.pitch.note]
                    
                    if not t or t==-1 then 
                        -- check the note lower and sharpen it
                        token.note.pitch.note = inverse_mapping[(semi-1)%12] 
                        t = key_struct[token.note.pitch.note]
                        if t==0 then token.note.pitch.accidental=1 end
                        if t==-1 then token.note.pitch.accidental=0 end
                        if t==1 then token.note.pitch.accidental=2 end
                    else
                        -- if we can just flatten that one, use that
                        if t==0 then token.note.pitch.accidental=-1 end
                        if t==1 then token.note.pitch.accidental=0 end
                    
                    end
                
                    
                end                                
            end
        end
        
    end
    
end


