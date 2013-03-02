
local pitch_table = {c=0, d=2, e=4, f=5, g=7, a=9, b=11}
local pitches = {'c', 'd', 'e', 'f', 'g', 'a', 'b'}


function diatonic_transpose_note(original_mapping, shift, new_mapping, inverse_mapping, pitch, accidental)
    -- Transpose a note name (+ accidental) in an original key mapping to a new key mapping which is
    -- shift semitones away    
        local semi = (get_semitone(original_mapping, pitch, accidental)%12 + shift)
        
        -- test for octave shift
        local octave = 0
        if semi<0 then
            octave = math.floor((semi/12))
         end
               
        if semi>11 then
            octave = math.floor(((semi)/12))            
        end        
        
        semi = semi % 12             
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
        return new_pitch, new_accidental, octave
end


function diatonic_transpose(tokens, shift)
    -- Transpose a whole token stream by a given number of semitones    
    local current_key, original_key        
    local mapping, key_struct
    local inverse_mapping = {}
    
    
    for i,token in ipairs(tokens) do
        if token.token=='key' then                               
                        
            -- get new root key
            original_key = create_key_structure(token.key)
            token.key.root = transpose_note_name(token.key.root, shift)
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
            local pitch,accidental,octave
            
            -- transpose embedded chords
            if token.note.chord then
                token.note.chord = transpose_chord(token.note.chord, shift % 12)                        
            end
        
            -- if we have a pitched note
            if token.note.pitch then        
                -- transpose the note                
                pitch,accidental,octave = diatonic_transpose_note(original_key, shift, mapping, inverse_mapping, token.note.pitch.note, token.note.pitch.accidental)                
                token.note.pitch.note = pitch
                token.note.pitch.accidental = accidental                    
                token.note.pitch.octave = token.note.pitch.octave + octave
            end
            
            -- apply to grace notes
            if token.note.grace then
                for i,v in ipairs(token.note.grace) do
                    pitch,accidental,octave = diatonic_transpose_note(original_key, shift, mapping, inverse_mapping, v.pitch.note, v.pitch.accidental)
                    v.pitch.note = pitch
                    v.pitch.accidental = accidental                
                    v.pitch.octave = v.pitch.octave + octave
                end
            end
            
        end
        
    end       
end


function swap_or_insert(t, match, position, default)
    -- Find match in t; if it exists, swap it into position
    -- if not, insert a default at that position
    local ref = find_first_match(t, match) 
    local elt
    
    -- insert default if does not match
    if not ref then                 
        table.insert(t, position, default)        
    else        
        elt = t[ref]
        table.remove(t, ref)
        -- swap it into place
        table.insert(t, position, elt)
    end
    
end

function validate_token_stream(tokens)
    -- Make sure the given token stream is valid
    -- Forces the token stream to begin with X:, followed by T:, followed by the other
    -- fields, followed by K:, followed by the notes
        
    swap_or_insert(tokens, {token='field_text', name='ref'}, 1, {token='field_text', name='ref', content='1', is_field=true})    
    swap_or_insert(tokens, {token='field_text', name='title'}, 2, {token='field_text', name='title', content='untitled', is_field=true})
                
    local first_note = 1
    -- find first non-field element
    for i,v in ipairs(tokens) do                                                       
        if not v.is_field  then       
            break
        end        
        first_note = i                
    end    
        
    if first_note>#tokens then
        first_note = #tokens
    end


    -- make sure last element before a note is a key  
    local ref = find_first_match(tokens, {token='key'}) 
    if not ref then
        table.insert(tokens, first_note+1, {token='key', key={root='c'}})                               
    else
        local elt = tokens[ref]
        table.remove(tokens, ref)
        ref = find_first_match(tokens, {token='key'}) 
        table.insert(tokens, first_note, elt)
    end
    
    
    return tokens
end


function header_end_index(tokens)
    -- Return the index of the end of the header
    -- returns nil if there is only header
    for i,v in ipairs(tokens) do        
        if not v.is_field then return i end
    end
    return #tokens+1
end
