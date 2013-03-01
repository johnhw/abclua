-- Functions for parsing and canonicalising notes

local broken_table = {
['<']=-1, 
['<<']=-2, 
['<<<']=-3, 
['<<<<']=-4, 
['<<<<<']=-5, 
['<<<<<<']=-6, 
['>']=1, 
['>>']=2, 
['>>>']=3, 
['>>>>']=4, 
['>>>>>']=5, 
['>>>>>>']=6, 
}

local function canonicalise_duration(duration, broken)
    -- fill in duration field; remove slashes
    -- and fill in numerator and denominator
    
    if duration.slashes and not duration.den then
         local den = 1
         local l = string.len(duration.slashes)
         den = math.pow(2, l)         
         duration.den = den
    end
    
    duration.num = duration.num or 1
    duration.den = duration.den or 1
        
    duration.slashes = nil

    duration.broken = broken_table[broken] or 0
    -- if broken then        
        -- local l = string.len(broken)
        -- local char = string.sub(broken, 1,1)        
        -- if char==">" then duration.broken = l 
        -- elseif char=="<" then duration.broken = -l end        
    -- else
        -- duration.broken = 0
    -- end
end

function canonicalise_accidental(accidental)
    -- Transform string indicator to integer and record any fractional part
    -- (for microtonal tuning)
    local acc = accidental[1]
    local frac_acc = accidental[2]
    local value
    local fraction = {num=1, den=1}

    -- fractional accidentals
    if frac_acc and (frac_acc.num or frac_acc.slashes) then
        canonicalise_duration(frac_acc)
        fraction = frac_acc 
    end
        
    local values = {
    ['^']={num=fraction.num, den=fraction.den},
    ['^^']={num=2*fraction.num, den=fraction.den},
    ['_']={num=-fraction.num, den=fraction.den},
    ['__']={num=-2*fraction.num, den=fraction.den},
    ['=']={num=0, den=0}}
    
    return values[acc]
    
end

function add_chord_or_annotation_note(note, text)
    -- Take a text string; if it's a an annotation, 
    -- add it to the annotations; otherwise, set the chord for this note
    -- Note: each note can only have one chord. Setting a new chord
    -- overwrites the old one.    
    local chord = parse_chord(text) 
        
    if chord then
        -- update chord for this note (only one chord per note)
        note.chord = chord
    else
        -- store free text annotations            
        table.insert(note.text, parse_free_text(text))                
    end
end

function add_decoration_note(note, decoration)
    -- Add a text string as a decoration to a note
    note.decoration = note.decoration or {}
    table.insert(note.decoration, decoration)    
end


local function canonicalise_note(note)
    -- Canonicalise a note, filling in the full duration field. 
    -- Remove slashes from the duration
    -- Fills in full duration field
    -- Replaces broken with an integer representing the dotted value (e.g. 0 = plain, 1 = once dotted,
    --  2 = twice, etc.)        
    canonicalise_duration(note.duration, note.broken)        
    
  local pitch = note.pitch
  if pitch then
      -- add octave shifts  
      
        local octave = 0
        if pitch.octave then            
            for c in pitch.octave:gmatch"." do
                if c == "'" then
                    octave = octave + 1
                end
                if c==',' then 
                    octave = octave - 1
                end
            end
        end        
        -- +1 octave for lower case notes
        if pitch.note == string.lower(pitch.note) then
            octave = octave + 1           
        end        
        pitch.note = string.lower(pitch.note)
        pitch.octave = octave        
        if pitch.accidental then
            pitch.accidental  =  canonicalise_accidental(pitch.accidental)
        end
    end
    
    
    note.text = {}
    local note_chord = note.chord
    note.chord = nil
    -- parse chords
    
    if note_chord then        
        for i,v in ipairs(note_chord) do           
            add_chord_or_annotation_note(note, v)            
        end
    end
         
    return note        
end

function parse_note(note, user_macro)
    -- Clean up a note structure. 
    -- Clean up the duration and pitch of notes and any grace notes
    -- Replace the decoration string with a sequence of decorators
    -- fix the note itself
         
    if note.decoration then        
        -- clean up decorations (replace +xxx+ with !xxx!)    
        for i,v in ipairs(note.decoration) do            
            if string.sub(v,1,1)=='+'  then
                note.decoration[i] = '!'..string.sub(v,2,-2)..'!'
            end
            
            -- apply user macro
            if v:match('^[h-wH-W.~]$') then 
                if user_macro[v] then
                    if string.sub(user_macro[v],1,1)=='"' then                        
                        table.insert(note.chord, user_macro[v])
                    else
                        note.decoration[i] = user_macro[v]
                    end
                end
                
            end
        end        
    end
    
    canonicalise_note(note)        
    
    -- and the grace notes
    if note.grace then
        for i,v in ipairs(note.grace) do
            canonicalise_note(v)
        end
    end
    return note    
end



