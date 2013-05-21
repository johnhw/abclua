local pitch_table = {c=0, d=2, e=4, f=5, g=7, a=9, b=11}

local sharp_table = {
[0]={'b',1},
[1]={'c',1},

[3]={'d',1},

[5]={'e',1},
[6]={'f',1},

[8]={'g',1},

[10]={'a',1},

}

local flat_table = {

[1]={'d',-1},

[3]={'e',-1},
[4]={'f',-1},

[6]={'g',-1},

[8]={'a',-1},

[10]={'b',-1},
[11]={'c',-1},
}


local natural_table = {
[0]={'c',0},
[2]={'d',0},
[4]={'e',0},
[5]={'f',0},
[7]={'g',0},
[9]={'a',0},
[11]={'b',0},
}


function diatonic_transpose_note(pitch, shift, mapping)
    -- Transpose a note name (+ accidental) in an original key mapping to a new key mapping which is
    -- shift semitones away    
    
        -- determine if this is a flat or sharp key
        local flat_key = false        
        for i,v in ipairs(mapping) do
            if v==-1 then flat_key = true end
        end
        local octave = 0
        
        -- get octave shift
        if shift<0 then
            octave = -math.floor(-shift/12)
        else
            octave = math.floor(shift/12)
        end
        
        semi = (pitch + shift) % 12
        
        local sharp_note = sharp_table[semi]
        local flat_note = flat_table[semi]
        local natural_note = natural_table[semi]
        
        local key_note
        
        local accidental
        
        if natural_note and mapping[natural_note[1]]==0 then
            -- cancel natural sign           
            key_note = natural_note
        elseif sharp_note and mapping[sharp_note[1]]==1 then
            -- cancel sharp sign           
            key_note = sharp_note
        elseif flat_note and mapping[flat_note[1]]==-1 then
            -- cancel flat sign           
            key_note = flat_note
        else
            -- choose which accidental to use
            if natural_note then 
                key_note = natural_note 
            elseif flat_key then 
                key_note = flat_note 
            else 
                key_note = sharp_note 
            end            
            -- this an accidental; propagate it
            mapping[key_note[1]] = key_note[2]
            accidental = {num=key_note[2], den=math.abs(key_note[2])}
        end
                        
        return key_note[1], accidental, octave
end


function transpose_key(key, shift)

    
    -- create "fake" key without the explicit accidentals        
    local fake_key = {root=key.root, mode=key.mode}
    local fake_mapping = create_key_structure(fake_key)                                               
    local real_mapping = create_key_structure(key) 
    
            
           
    local intervals = {}
    
    -- semitone of the root of this key (e.g. c=0, c#=1, d=2, etc.)
    local root = string.sub(key.root,1,1)
    local root_semi = pitch_table[root] + real_mapping[root]
    
    local scale = {}
    -- work out what intervals are in this key
    for i,v in pairs(real_mapping) do
        local semi = pitch_table[i] + real_mapping[root]
        local offset = (semi-root_semi) % 12
        table.insert(scale, {note=i,offset=offset})        
        print(i, key.root, offset)        
    end
    table.sort(scale, function (a,b) return a.offset<b.offset end)
    local offsets = {}
    local last =0 
    
    for i,v in ipairs(scale) do
        table.insert(offsets, v.offset-last)
        last = v.offset
    end
    table_print(offsets)
    
   
    
    -- transpose the root
    key.root = transpose_note_name(key.root, shift)
    local new_mapping = create_key_structure(key) 
    
    
    local new_root = string.sub(key.root,1,1)
    local new_root_semi = pitch_table[new_root] + real_mapping[new_root]
    for i,v in pairs(new_mapping) do
        local semi = pitch_table[i] + new_mapping[new_root]
        local offset = (semi-new_root_semi) % 12
        print(offset)
    end
    
    -- table_print(key.accidentals)
    -- print()
    table_print(accidentals)
    --key.accidentals = accidentals
    
    return key
end

function diatonic_transpose(tokens, shift)
    -- Transpose a whole token stream by a given number of semitones 
    -- Shifts notes; keys; written chords; and grace notes
    -- Does not work correctly with propagate-accidentals:octave
    local current_key, original_key        
    local mapping, key_struct
    local inverse_mapping = {}
    
    -- how accidentals are propagated
    local accidental_mode = 'bar'
    local base_mapping = {}
        
    precompile_token_stream(tokens)
    
    for i,token in ipairs(tokens) do
        if token.token=='bar' then
            -- clear lingering accidentals
            mapping = copy_table(base_mapping)
        end
        
        if token.token=='instruction' and token.directive.directive=='propagate-accidentals' then
            -- change accidental mode
            accidental_mode = token.directive.arguments[1]
        end
        
        -- shift the key signature
        if token.token=='key' then    
            -- disable accidental propagation for K:none
            if token.key.none then
                accidental_mode = 'not'
            end
            -- get new root key
            original_key = create_key_structure(token.key)
            token.key = transpose_key(token.key, shift)
            
            current_key = token.key            
            -- work out the semitones in this key
            
            -- store mapping so we can restore when 
            base_mapping = create_key_structure(current_key)                                                           
            mapping = copy_table(base_mapping)
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
                pitch,accidental,octave = diatonic_transpose_note(token.note.play_pitch, shift, mapping)             
                token.note.pitch.note = pitch
                token.note.pitch.accidental = accidental                    
                token.note.pitch.octave = token.note.pitch.octave + octave  
                if accidental_mode=='not' then
                    -- cancel any accidentals if we are not propagating
                    mapping = base_mapping
                end                               
            end
            
            -- apply to grace notes
            if token.note.grace then
                -- preserve accidental states
                local temp_mapping = copy_table(mapping)
                for i,v in ipairs(token.note.grace) do
                    pitch,accidental,octave = diatonic_transpose_note(v.play_pitch, shift, mapping) 
               
                    v.pitch.note = pitch
                    v.pitch.accidental = accidental                
                    v.pitch.octave = v.pitch.octave + octave
                    if accidental_mode=='not' then
                        -- cancel any accidentals if we are not propagating
                        mapping = base_mapping
                    end
                end
                mapping = temp_mapping
                
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
