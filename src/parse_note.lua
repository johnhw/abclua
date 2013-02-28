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
    
   
    
    -- parse chords
    if note.chord then        
        local chord = parse_chord(note.chord) 
        if chord then
            note.chord = chord
        else
            -- store free text annotations
            note.text = parse_free_text(note.chord)
            note.chord = nil
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
                        -- set free text/chord -- should really append this instead of overwriting
                        note.chord = user_macro[v]
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



