-- Chord handling functions
local chords = 
{
["+2"] = { 0, 2, },
["+3"] = { 0, 4, },
["+4"] = { 0, 6, },
["+b3"] = { 0, 3, },
["5"] = { 0, 7, },
["b5"] = { 0, 6, },
["6sus4(-5)"] = { 0, 6, 9, },
["aug"] = { 0, 4, 8, },
["dim"] = { 0, 3, 6, },
["dim5"] = { 0, 4, 6, },
["maj"] = { 0, 4, 7, },
["min"] = { 0, 3, 7, },
["m"] = { 0, 3, 7, },
["sus2"] = { 0, 2, 7, },
["sus2sus4(-5)"] = { 0, 2, 6, },
["sus4"] = { 0, 6, 7, },
["6"] = { 0, 4, 7, 9, },
["6sus2"] = { 0, 2, 7, 9, },
["6sus4"] = { 0, 6, 7, 9, },
["7"] = { 0, 4, 7, 10, },
["7#5"] = { 0, 4, 8, 10, },
["7b5"] = { 0, 4, 6, 10, },
["7sus2"] = { 0, 2, 7, 10, },
["7sus4"] = { 0, 6, 7, 10, },
["add2"] = { 0, 2, 4, 7, },
["add4"] = { 0, 4, 6, 7, },
["add9"] = { 0, 4, 7, 14, },
["dim7"] = { 0, 3, 6, 9, },
["dim7susb13"] = { 0, 3, 9, 20, },
["madd2"] = { 0, 2, 3, 7, },
["madd4"] = { 0, 3, 6, 7, },
["madd9"] = { 0, 3, 7, 14, },
["mmaj7"] = { 0, 3, 7, 11, },
["m6"] = { 0, 3, 7, 9, },
["m7"] = { 0, 3, 7, 10, },
["m7#5"] = { 0, 3, 8, 10, },
["m7b5"] = { 0, 3, 6, 10, },
["minadd2"] = { 0, 2, 3, 7, },
["minadd4"] = { 0, 3, 6, 7, },
["minadd9"] = { 0, 3, 7, 14, },
["minmaj7"] = { 0, 3, 7, 11, },
["min6"] = { 0, 3, 7, 9, },
["min7"] = { 0, 3, 7, 10, },
["min7#5"] = { 0, 3, 8, 10, },
["min7b5"] = { 0, 3, 6, 10, },
["maj7"] = { 0, 4, 7, 11, },
["maj7#5"] = { 0, 4, 8, 11, },
["maj7b5"] = { 0, 4, 6, 11, },
["maj7sus2"] = { 0, 2, 7, 11, },
["maj7sus4"] = { 0, 6, 7, 11, },
["sus2sus4"] = { 0, 2, 6, 7, },
["6/7"] = { 0, 4, 7, 9, 10, },
["6add9"] = { 0, 4, 7, 9, 14, },
["7s5b9"] = { 0, 4, 8, 10, 13, },
["7s9"] = { 0, 4, 7, 10, 15, },
["7s9b5"] = { 0, 4, 6, 10, 15, },
["7/11"] = { 0, 4, 7, 10, 18, },
["7/13"] = { 0, 4, 7, 10, 21, },
["7add4"] = { 0, 4, 6, 7, 10, },
["7b9"] = { 0, 4, 7, 10, 13, },
["7b9b5"] = { 0, 4, 6, 10, 13, },
["7sus4/13"] = { 0, 6, 7, 10, 21, },
["9"] = { 0, 4, 7, 10, 14, },
["9s5"] = { 0, 4, 8, 10, 14, },
["9b5"] = { 0, 4, 6, 10, 14, },
["9sus4"] = { 0, 7, 10, 14, 18, },
["m maj9"] = { 0, 3, 7, 11, 14, },
["mmaj9"] = { 0, 3, 7, 11, 14, },
["m6/7"] = { 0, 3, 7, 9, 10, },
["m6/9"] = { 0, 3, 7, 9, 14, },
["m7/11"] = { 0, 3, 7, 10, 18, },
["m7add4"] = { 0, 3, 6, 7, 10, },
["m9"] = { 0, 3, 7, 10, 14, },
["m9/11"] = { 0, 3, 10, 14, 18, },
["m9b5"] = { 0, 3, 6, 10, 14, },
["min maj9"] = { 0, 3, 7, 11, 14, },
["minmaj9"] = { 0, 3, 7, 11, 14, },
["min6/7"] = { 0, 3, 7, 9, 10, },
["min6/9"] = { 0, 3, 7, 9, 14, },
["min7/11"] = { 0, 3, 7, 10, 18, },
["min7add4"] = { 0, 3, 6, 7, 10, },
["min9"] = { 0, 3, 7, 10, 14, },
["min9/11"] = { 0, 3, 10, 14, 18, },
["min9b5"] = { 0, 3, 6, 10, 14, },
["maj6/7"] = { 0, 4, 7, 9, 11, },
["maj7/11"] = { 0, 4, 7, 11, 18, },
["maj7/13"] = { 0, 4, 7, 11, 21, },
["maj9"] = { 0, 4, 7, 11, 14, },
["maj9s5"] = { 0, 4, 8, 11, 14, },
}

local common_chords = 
{
["aug"] = { 0, 4, 8, },
["dim"] = { 0, 3, 6, },
["dim5"] = { 0, 4, 6, },
["maj"] = { 0, 4, 7, },
["min"] = { 0, 3, 7, },
["sus2"] = { 0, 2, 7, },
["sus4"] = { 0, 6, 7, },
["6"] = { 0, 4, 7, 9, },
["7"] = { 0, 4, 7, 10, },
["7sus2"] = { 0, 2, 7, 10, },
["7sus4"] = { 0, 6, 7, 10, },
["add2"] = { 0, 2, 4, 7, },
["add4"] = { 0, 4, 6, 7, },
["add9"] = { 0, 4, 7, 14, },
["dim7"] = { 0, 3, 6, 9, },
["madd9"] = { 0, 3, 7, 14, },
["mmaj7"] = { 0, 3, 7, 11, },
["m6"] = { 0, 3, 7, 9, },
["m7"] = { 0, 3, 7, 10, },
["m7#5"] = { 0, 3, 8, 10, },
["m7b5"] = { 0, 3, 6, 10, },
["maj7"] = { 0, 4, 7, 11, },
["maj7#5"] = { 0, 4, 8, 11, },
["maj7b5"] = { 0, 4, 6, 11, },
["9"] = { 0, 4, 7, 10, 14, },
["mmaj9"] = { 0, 3, 7, 11, 14, },
["m6/7"] = { 0, 3, 7, 9, 10, },
["m6/9"] = { 0, 3, 7, 9, 14, },
["m7/11"] = { 0, 3, 7, 10, 18, },
["m7add4"] = { 0, 3, 6, 7, 10, },
["m9"] = { 0, 3, 7, 10, 14, },
["m9/11"] = { 0, 3, 10, 14, 18, },
["m9b5"] = { 0, 3, 6, 10, 14, },
["maj9"] = { 0, 4, 7, 11, 14, },
}


local chord_matcher = re.compile([[
        chord <- ({:root: root :} ({:type: [^/%s] +:}) ? ('/' {:inversion: (<root>/[1-3]) :}) ?) -> {}
        root <- ([a-g] ('b' / 's') ?)
    ]])
    
    
function apply_inversion(inversion, base_pitch, chord_offsets)
    -- apply the inversion
    local notes = {}    
    
    for i,v in ipairs(chord_offsets) do
        -- if inversion, shift the note to the octave below
        if inversion and inversion==(v+base_pitch) % 12 then
             table.insert(notes, v+base_pitch-12)
             inversion = nil -- clear the inversion field so we don't re-add the note
        else               
            table.insert(notes, v+base_pitch)
        end        
    end
    
    -- an inversion which was not in the chord itself
    -- (e.g. Cmaj/F)
    if inversion then
        table.insert(notes, inversion-12)
    end
    return notes
end

function match_chord(chord, custom_table)
    -- Matches chord definitions, returning the root note
    -- the chord type, and the notes in that chord (as semitone offsets)
    -- convert sharp signs to s and lowercase
    -- optionally take a table of custom chord types
    custom_table = custom_table or {}    
    chord = chord:gsub('#', 's')
    chord = string.lower(chord)
           
    local match = chord_matcher:match(chord)
    if not match or not match.root then
        return nil
    end
    
    local base_pitch = get_note_number(match.root)
    local inversion
        
        
    match.type = match.type or 'maj' -- default to major chord    
    local chord_offsets    
        
    local chord_form = custom_table[match.type] or chords[match.type]
    if chord_form  then
        chord_offsets = chord_form
    else    
        return nil -- not a valid chord
    end    
    
    -- get inversion pitch
    if match.inversion then 
        if tonumber(match.inversion) then
            
            inversion = (chord_form[tonumber(match.inversion)] + base_pitch) % 12
        else
            inversion = get_note_number(match.inversion)
        end       
    end
    
    local notes = apply_inversion(inversion, base_pitch, chord_offsets)       
    return {chord_type=match.type, base_pitch=match.root, offsets=chord_offsets, notes=notes, inversion=canonical_note_name(inversion)}   
end



function transpose_chord(chord, shift)
    -- return a transposed chord name given a string and an integer offset
    -- e.g. transpose_chord('Cm', 4) returns 'Em'     
    
      chord.base_pitch = transpose_note_name(chord.base_pitch, shift)
      -- need to transpose inversions as well
      if chord.inversion then
            chord.inversion = transpose_note_name(chord.inversion, shift)   
      end 
      return chord            
end

function is_chord(str)
    -- Return true if this string is a valid chord identifier
    if match_chord(str) then
        return true
    else
        return false
    end
end


function parse_chord(chord, custom)
    -- parse a chord, returning a chord structure
    return match_chord(chord, custom)    
end

function invert_chord(chord)
-- takes a chord defintion string (e.g. "Gm" or "Fm7" or "Asus2") and returns the notes in it
-- as a table of pitches (with C=0)

    
    local match = chord
    local notes = {}
    local inversion
    if match then  
       inversion = match.inversion      
        for i,v in ipairs(match.notes) do
            -- if inversion, shift the note to the octave below
            if inversion and inversion==(v+match.base_pitch) % 12 then
                 table.insert(notes, v+match.base_pitch-12)
                 inversion = nil -- clear the inversion field so we don't re-add the note
            else               
                table.insert(notes, v+match.base_pitch)
            end
        end
    end
    
    -- an inversion which was not in the chord itself
    -- (e.g. Cmaj/F)
    if inversion then
        table.insert(notes, inversion-12)
    end
    
    return notes
    
end

function voice_chord(notes, octave)
    -- Takes a note sequence for a chord and expands the chord across several octaves
    -- Returns a MIDI note number set
    local octave = octave or 5
    
    local base = octave * 12
    
    local out_notes = {}    

    -- make sure root is in first position
    -- (may not be if chord is inverted)
    table.sort(notes)
    
    -- add original notes
    for i,v in ipairs(notes) do 
        table.insert(out_notes, v+base)
    end
    
    -- root at octave above and below
    local root = notes[1]
    table.insert(out_notes, root+base-12)
    table.insert(out_notes, root+base+12)
    
    -- -- fifth at octave above
    -- if #notes>=3 then
        -- fifth = notes[3]
        -- table.insert(out_notes, fifth+base+12)
    -- end
    
    return out_notes
    
end


function test_chords()
    
    local test_chords = {'Gm', 'G', 'F#min7', 'dM9', 'bbmin', 'Dmin/F', 'Cmaj/E', 'Cmaj/F'}
    for i,v in ipairs(test_chords) do
        print(v)
        table_print(voice_chord(create_chord(v), 5))
        print()
    end   
end

