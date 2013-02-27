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
["dim9"] = { 0, 3, 6, 9, 13},
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

    
function apply_inversion(inversion, root, chord_offsets)
    -- apply the inversion
    local notes = {}    
    
    local base_pitch = get_note_number(root)
    if inversion then 
        -- numerical inversion
        if tonumber(inversion) then
            if inversion < #chord_offsets then 
                inversion = (chord_offsets[tonumber(inversion)+1]+base_pitch) % 12
            else
                inversion = nil -- not a real inversion
            end
            
        else
            -- note name inversion
            inversion = get_note_number(inversion) 
        end
    end
   
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

local chord_matcher = re.compile([[
        chord <- ({:root: root :} ({:type: [^/%s] +:}) ? ('/' {:inversion: (<root>/[1-3]) :}) ?) -> {}
        root <- (([a-g] ('b' / '#') ?) / (<numeral>))
        numeral <- ('iii' / 'ii' / 'iv' / 'vii' / 'vi' / 'v' / 'i') 
    ]])
    
function parse_chord(chord)
    -- Matches chord definitions, returning the root note
    -- the chord type, and the inversion
    -- convert sharp signs to s and lowercase
    
    chord = string.lower(chord)
    
    local match = chord_matcher:match(chord)
    if not match or not match.root then
        return nil
    end    
    
    match.root = match.root:gsub('#', 's')
  
    local inversion        
    -- get inversion pitch
    if match.inversion then 
        if tonumber(match.inversion) then       
            inversion = tonumber(match.inversion)
        else
            inversion = canonical_note_name(get_note_number(match.inversion))
        end       
    end
   
    return {chord_type=match.type or 'maj', root=match.root,inversion=inversion, original_type=match.type}   
end

local numerals = {iii=3, ii=2, i=1, iv=4, v=5, vi=6, vii=7}

function get_chord_notes(chord, custom_table, key)
    -- get the notes in a chord
     local chord_type
     local root, tonic
     local base_pitch
     local semis
     -- deal with numeral chords
     if numerals[chord.root] then 
        -- work out which root note this is
        tonic = numerals[chord.root]
        semis = key_semitones(key)        
        root = canonical_note_name(semis[tonic])
        
        
        -- decide whether major or minor
        if tonic == 2 or tonic==3 or tonic==6 then            
            chord_type = chord.original_type or 'min'
            if chord_type=='7' then chord_type='m7' end
            if chord_type=='9' then chord_type='m9' end
            
        elseif tonic == 7  then
            chord_type = chord.original_type or 'dim'
            if chord_type=='7' then chord_type='dim7' end
            if chord_type=='9' then chord_type='dim9' end
         
        else
            chord_type = chord.original_type or 'maj' 
        end
     else
        -- not a numeral chord
        root = chord.root
        chord_type = chord.original_type or 'maj' -- default to major chord    
     end
    
     local chord_form = custom_table[chord_type] or chords[chord_type]
     -- empty chord if we can't play it
     if not chord_form then return nil end
     local notes = apply_inversion(chord.inversion, root, chord_form)       
     return notes
end


function transpose_chord(chord, shift)
    -- return a transposed chord name given a string and an integer offset
    -- e.g. transpose_chord('Cm', 4) returns 'Em'     
    
      chord.root = transpose_note_name(chord.root, shift)
      -- need to transpose inversions as well
      if chord.inversion then
            chord.inversion = transpose_note_name(chord.inversion, shift)   
      end 
      return chord            
end

function is_chord(str)
    -- Return true if this string is a valid chord identifier
    if parse_chord(str) then
        return true
    else
        return false
    end
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

