-- Functions for parsing and canonicalising notes

local function canonicalise_duration(duration)
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

end

function canonicalise_accidental(accidental)
    -- Transform string indicator to integer and record any fractional part
    -- (for microtonal tuning)
    local acc = accidental[1]
    local value
    local fraction = {num=1, den=1}

    -- fractional accidentals
    if accidental[2] and (accidental[2].num or accidental[2].slashes) then
        canonicalise_duration(accidental[2])
        fraction = accidental[2] 
    end
        
    local values = {
    ['^']={num=fraction.num, den=fraction.den},
    ['^^']={num=2*fraction.num, den=fraction.den},
    ['_']={num=-fraction.num, den=fraction.den},
    ['__']={num=-2*fraction.num, den=fraction.den},
    ['=']={num=0, den=0}}
    
    return values[acc]
    
end

local function canonicalise_note(note)
    -- Canonicalise a note, filling in the full duration field. 
    -- Remove slashes from the duration
    -- Fills in full duration field
    -- Replaces broken with an integer representing the dotted value (e.g. 0 = plain, 1 = once dotted,
    --  2 = twice, etc.)    
    canonicalise_duration(note.duration)
        
    note.duration.broken = 0
    if note.broken then        
        local l = string.len(note.broken)
        local char = string.sub(note.broken, 1,1)        
        if char==">" then note.duration.broken = l end
        if char=="<" then note.duration.broken = -l end        
    end
  
  if note.pitch then
      -- add octave shifts  
      
        local octave = 0
        if note.pitch.octave then
            local l = string.len(note.pitch.octave)
            local char = string.sub(note.pitch.octave, 1,1)
            if char=="'" then octave = l end
            if char=="," then octave = -l end
            
            -- for c in note.pitch.octave:gmatch"." do
                -- if c == "'" then
                    -- octave = octave + 1
                -- end
                -- if c==',' then 
                    -- octave = octave - 1
                -- end
            -- end
        end        
        -- +1 octave for lower case notes
        if note.pitch.note == string.lower(note.pitch.note) then
            octave = octave + 1           
        end        
        note.pitch.note = string.lower(note.pitch.note)
        note.pitch.octave = octave        
        if note.pitch.accidental then
            note.pitch.accidental  =  canonicalise_accidental(note.pitch.accidental)
        end
    end
    
    -- parse chords
    if note.chord then        
        local chord = parse_chord(note.chord) 
        if chord then
            note.chord = chord
        else
            -- store free text annotations
            note.free_text = note.chord
            note.chord = nil
        end
    end
        
    if note.decoration then        
        -- clean up decorations (replace +xxx+ with !xxx!)    
        for i,v in ipairs(note.decoration) do            
            if string.sub(v,1,1)=='+'  then
                note.decoration[i] = '!'..string.sub(v,2,-2)..'!'
            end
        end        
    end
    
    note.duration.slashes = nil
    return note        
end

function parse_note(note)
    -- Clean up a note structure. 
    -- Clean up the duration and pitch of notes and any grace notes
    -- Replace the decoration string with a sequence of decorators
    -- fix the note itself
    canonicalise_note(note)
    
    -- and the grace notes
    if note.grace then
        for i,v in ipairs(note.grace) do
            canonicalise_note(v)
        end
    end
    return note    
end



