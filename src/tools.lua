
local pitch_table = {c=0, d=2, e=4, f=5, g=7, a=9, b=11}
local pitches = {'c', 'd', 'e', 'f', 'g', 'a', 'b'}


function diatonic_transpose_note(original_mapping, shift, new_mapping, inverse_mapping, pitch, accidental)
    -- Transpose a note name (+ accidental) in an original key mapping to a new key mapping which is
    -- shift semitones away    
        local semi = (get_semitone(original_mapping, pitch, accidental) + shift) % 12             
        local new_accidental, new_pitch                       
        -- if we don't need an accidental
        if inverse_mapping[semi] then
            new_pitch = inverse_mapping[semi]       
            new_accidental = nil                  
        else
            -- check the next note
            new_pitch = inverse_mapping[(semi+1)%12]                     
            t = new_mapping[new_pitch]            
            if not t or t==-1 then 
                -- check the note lower and sharpen it
                new_pitch = inverse_mapping[(semi-1)%12] 
                t = new_mapping[new_pitch]
                if t==0 then new_accidental={num=1, den=1} end
                if t==-1 then new_accidental={num=0, den=0} end
                if t==1 then new_accidental={num=2, den=1} end
            else
                -- if we can just flatten that one, use that
                if t==0 then new_accidental={num=-1, den=1} end
                if t==1 then new_accidental={num=0, den=0} end            
            end            
        end        
        return new_pitch, new_accidental
end


function diatonic_transpose(tokens, shift)
    -- Transpose a whole token stream by a given number of semitones    
    local current_key, original_key        
    local mapping, key_struct
    local inverse_mapping = {}
    
    shift = shift % 12      
    for i,token in ipairs(tokens) do
        if token.token=='key' then                               
                        
            -- get new root key
            original_key = create_key_structure(token.key)
            token.key.root = shift_root_key(token.key.root, shift)
            current_key = token.key            
            -- work out the semitones in this key
            mapping = create_key_structure(current_key)                                               
            for i,v in pairs(pitch_table) do                                           
                local k = v+mapping[i]
                k = k % 12
                inverse_mapping[k] = i
            end                       
        end        
        
        -- transpose chords
        if token.token=='chord' then
          token.chord = transpose_chord(token.chord, shift)                        
        end
        
        if token.token=='note' and mapping then
            local pitch,accidental 
            
            -- transpose embedded chords
            if token.note.chord then
                token.note.chord = transpose_chord(token.note.chord, shift)                        
            end
        
            -- if we have a pitched note
            if token.note.pitch then        
                -- transpose the note                
                pitch,accidental = diatonic_transpose_note(original_key, shift, mapping, inverse_mapping, token.note.pitch.note, token.note.pitch.accidental)                
                token.note.pitch.note = pitch
                token.note.pitch.accidental = accidental                    
            end
            
            -- apply to grace notes
            if token.note.grace then
                for i,v in ipairs(token.note.grace) do
                    pitch,accidental = diatonic_transpose_note(original_key, shift, mapping, inverse_mapping, v.pitch.note, v.pitch.accidental)
                    v.pitch.note = pitch
                    v.pitch.accidental = accidental                
                end
            end
            
        end
        
    end
    
end


 -- if token.token=='note' and mapping then
            -- --if we have a pitched note
            -- if token.note.pitch then                
                -- local semi = (midi_note_from_note(original_key, token.note) % 12) + shift
                
                -- wrap semitone to 0-11
                -- semi = semi % 12
                                
                ----if we don't need an accidental
                -- if inverse_mapping[semi] then
                    -- token.note.pitch.note = inverse_mapping[semi]       
                    -- token.note.pitch.accidental = nil
                -- else
                    ----check the next note
                    -- token.note.pitch.note = inverse_mapping[(semi+1)%12]                     
                    -- t = mapping[token.note.pitch.note]
                    
                    -- if not t or t==-1 then 
                       ---- check the note lower and sharpen it
                        -- token.note.pitch.note = inverse_mapping[(semi-1)%12] 
                        -- t = mapping[token.note.pitch.note]
                        -- if t==0 then token.note.pitch.accidental={num=1, den=1} end
                        -- if t==-1 then token.note.pitch.accidental={num=0, den=0} end
                        -- if t==1 then token.note.pitch.accidental={num=2, den=1} end
                    -- else
                      ----  if we can just flatten that one, use that
                        -- if t==0 then token.note.pitch.accidental={num=-1, den=1} end
                        -- if t==1 then token.note.pitch.accidental={num=0, den=0} end
                    
                    -- end
                
                    
                -- end                                
            -- end
        -- end
        