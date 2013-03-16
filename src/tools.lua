local pitch_table = {c=0, d=2, e=4, f=5, g=7, a=9, b=11}


function diatonic_transpose_note(original_mapping, shift, new_mapping, inverse_mapping, pitch, accidental)
    -- Transpose a note name (+ accidental) in an original key mapping to a new key mapping which is
    -- shift semitones away    
    
        local octave = 0
        
        local original_semi = get_semitone(original_mapping, pitch, accidental)                
        
        local semi = (original_semi%12) + shift                        
        -- test for octave shift        
        if semi<0 then
            octave = octave + math.floor((semi/12))
         end
               
        if semi>11 then
            octave = octave + math.floor(((semi)/12))            
        end        
        
        -- get the octave-wrapped semitone        
        semi = semi % 12             
        
        -- work out if this accidental was an "up" (^ or = from a flat)
        -- or a "down" (_ or = from a sharp)
        local up     
       
        if accidental then
            if accidental.num>0 then up = true end
            if accidental.num<0 then up = false end
            -- natural from flat
            if accidental.num==0 and original_mapping[pitch]<0 then up = true end
            -- natural from sharp
            if accidental.num==0 and original_mapping[pitch]>0 then up = false end 
            if accidental.num==0 and original_mapping[pitch]==0 then up = 0 end
        end
                    
        
        local new_accidental, new_pitch  
        
        -- if we don't need an accidental, just look up the pitch
        if inverse_mapping[semi] then
            new_pitch = inverse_mapping[semi]  
            new_accidental = nil 
            if up==0 then
                new_accidental = {num=0, den=0}
            end
        else
        
            -- was a sharp/natural before
            if up==true then
                new_pitch = inverse_mapping[(semi-1)%12]                            
                t = new_mapping[new_pitch]
                if t==0 then new_accidental={num=1, den=1} end
                if t==-1 then new_accidental={num=0, den=0} end
                if t==1 then new_accidental={num=2, den=1} end
            end
            
            -- was a flat before
            if up==false then
                new_pitch = inverse_mapping[(semi+1)%12]                 
                t = new_mapping[new_pitch]
                if t==0 then new_accidental={num=-1, den=1} end
                if t==1 then new_accidental={num=0, den=0} end
                if t==-1 then new_accidental={num=-2, den=1} end
            end
            
            if up==nil or up==0 then
                -- othwerwise check the note above, and see if we can flatten
                new_pitch = inverse_mapping[(semi+1)%12]                     
                t = new_mapping[new_pitch]            
                -- if not, then try sharpening the note below
                if not t or t==-1 then 
                    -- check the note lower and sharpen it
                    new_pitch = inverse_mapping[(semi-1)%12] 
                    
                    t = new_mapping[new_pitch]
                    if t==0 then new_accidental={num=1, den=1} end
                    if t==-1 then new_accidental={num=0, den=0} end
                    -- if all else fails, we double sharpen the note below
                    -- (this will never happen in a standard scale)
                    if t==1 then new_accidental={num=2, den=1} end
                else
                    -- if we can just flatten that one, use that
                    if t==0 then new_accidental={num=-1, den=1} end
                    if t==1 then new_accidental={num=0, den=0} end            
                end            
            end
        end        
        return new_pitch, new_accidental, octave
end


function transpose_key(key, shift)
    -- create "fake" key without the explicit accidentals        
    local fake_key = {root=key.root, mode=key.mode}
    local original_mapping = create_key_structure(fake_key)                                               
    key.root = transpose_note_name(key.root, shift)
    -- transpose explicit accidentals
    
    -- create "fake" key without the explicit accidentals    
    fake_key = {root=key.root, mode=key.mode}
    -- get the semitone mappings
    new_mapping = create_key_structure(fake_key)
    local inverse_mapping = {}
    for i,v in pairs(pitch_table) do                                           
        local k = v+new_mapping[i]
        k = k % 12
        inverse_mapping[k] = i
    end          
    
    -- local new_accidentals ={}
    -- update all of the accidentals
    -- for i,v in ipairs(key.accidentals) do               
        -- table.insert(new_accidentals, {note=note, accidental=accidental})                
    -- end    
    -- key.accidentals = new_accidentals    
    return key
end

function update_accidentals(accidentals, pitch,  mode)
    -- update the accidental table according to the current mode
    
    if mode=='not' then
       -- do nothing
       return pitch.accidental
    else
        local accidental_key 
        -- in 'octave' mode, accidentals only propagate within an octave
        -- otherwise, they propagate to all notes of the same pitch class
        if mode=='octave' then
           accidental_key = pitch.octave..pitch.note
        else
           accidental_key = pitch.note
        end
            
        -- set the appropriate accidental, and return the current
        -- active one if there is one
        if accidental then
            accidentals[accidental_key] = pitch.accidental 
            return accidental
        else
            return accidentals[accidental_key]
        end
    end
end
    

function diatonic_transpose(tokens, shift)
    -- Transpose a whole token stream by a given number of semitones 
    -- Shifts notes; keys; written chords; and grace notes
    local current_key, original_key        
    local mapping, key_struct
    local inverse_mapping = {}
    
    -- how accidentals are propagated
    local accidental_mode = 'bar'
    local accidentals = {}
    
    for i,token in ipairs(tokens) do
        if token.token=='bar' then
            -- clear lingering accidentals
            accidentals = {}
        end
        
        if token.token=='instruction' and token.directive.directive=='propagate-accidentals' then
            -- change accidental mode
            accidental_mode = token.directive.arguments[1]
        end
        
        -- shift the key signature
        if token.token=='key' then                               
            if token.key.none then
                accidental_mode = 'not'
            else
                -- get new root key
                original_key = create_key_structure(token.key)
                token.key = transpose_key(token.key, shift)
                
                current_key = token.key            
                -- work out the semitones in this key
                mapping = create_key_structure(current_key)                                               
                for i,v in pairs(pitch_table) do                                           
                    local k = v+mapping[i]
                    k = k % 12
                    inverse_mapping[k] = i
                end                       
            end
        end        
        
        -- transpose standalone chords
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
                local implied_accidental = update_accidentals(accidentals, token.note.pitch,  accidental_mode)  
                local accidental = token.note.pitch.accidental or implied_accidental
                pitch,accidental,octave = diatonic_transpose_note(original_key, shift, mapping, inverse_mapping, token.note.pitch.note, token.note.pitch.accidental, accidentals)             
                token.note.pitch.note = pitch
                token.note.pitch.accidental = accidental                    
                token.note.pitch.octave = token.note.pitch.octave + octave
               
            end
            
            -- apply to grace notes
            if token.note.grace then
                -- preserve accidental states
                local temp_accidentals = copy_table(accidentals) 
                for i,v in ipairs(token.note.grace) do
                    local implied_accidental = update_accidentals(accidentals, token.note.pitch,  accidental_mode)  
                    local accidental = v.pitch.accidental or implied_accidental
                    pitch,accidental,octave = diatonic_transpose_note(original_key, shift, mapping, inverse_mapping, v.pitch.note, accidental, accidentals)
                    v.pitch.note = pitch
                    v.pitch.accidental = accidental                
                    v.pitch.octave = v.pitch.octave + octave
                end
                accidentals = temp_accidentals
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
    -- Make sure the metadata fields in the given token stream are in a valid order
    -- Forces the token stream to begin with X:, followed by T:, followed by the other
    -- fields, followed by K:, followed by the notes. If these fields don't exist in the
    -- token stream, they are created.
        
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
    -- Return the index of the end of the header (first non-metadata token)
    -- returns #tokens+1 if there is only header
    for i,v in ipairs(tokens) do        
        if not v.is_field then return i end
    end
    return #tokens+1
end
