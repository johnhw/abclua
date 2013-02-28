-- verify that chords are rendered correctly
abclua = require "abclua"

function get_chords(stream)
    -- return a table representing the computed pitches of each note
    local notes = {}
    for i,v in ipairs(stream) do        
        if v.event=='chord' then
            table.insert(notes, v.chord.notes)           
        end
    end
    return notes
end


function chord_matches(chord, result)
    -- returns true if all semitones are equivalent modulo 12
    if not result or not chord or #chord~=#result then return false end
    for i,v in ipairs(chord) do        
        if chord[i]%12~=result[i]%12 then
            return false
        end    
    end
    return true
end

function verify_chords(str, result, test)
    -- verify that the pitches match the expected values
    local songs = abclua.parse_abc_multisong(str)          
    local stream = songs[1].voices['default'].stream
    chords = get_chords(stream)        
    for i, v in ipairs(result) do        
        assert(chord_matches(v, chords[i]), test)
    end
    print(test.." passed OK") 
end

function test_chords()
    -- Test repeats and variant endings
    
    verify_chords([[X:1
    K:G
    "C"]], {{0, 4, 7}}, 'C major chord')
    
        
    verify_chords([[X:1
    K:G
    "Am"]], {{9, 12, 16}}, 'A minor chord')
    
    
    verify_chords([[X:1
    K:G
    "Cmaj"]], {{0, 4, 7}}, 'C major chord synonyms')
    
    verify_chords([[X:1
    K:G
    "Gmaj" "Dmaj"]], {{7, 11, 2}, {2, 6, 9}}, 'G major / D Major chords')
    
    verify_chords([[X:1
    K:G
    "C#" "Cb"]], {{1, 5, 8}, {-1, 3, 6}}, 'Flat and sharp chords')
    
    verify_chords([[X:1
    K:G
    "C/F" "C/G" "C/C#"]], {{0, 4, 7, 5}, {0, 4, 7}, {0,4,7,1}}, 'Inverted chords')
    
    verify_chords([[X:1
    K:G
    "Csus2" "Csus4"]], {{0, 2, 7}, {0, 6, 7}}, 'Suspended chords')
    
    verify_chords([[X:1
    K:G
    "C7" "Cm7" "Cmmaj7" ]], {{0, 4, 7, 10}, {0, 3, 7, 10}, {0,3,7,11}}, '7th chords')
    
    verify_chords([[X:1
    K:G
    "C7/D"  ]], {{0, 4, 7, 10, 2},}, 'Inverted 7ths')

    verify_chords([[X:1
    K:G
    "C" "C/1" "C/2"  ]], {{0,4,7}, {0,-8,7}, {0,4,-5}}, 'Numerical inversion')
    
    verify_chords([[X:1
    K:C
    "I" "ii" "iii" "IV" "V" "vi" "vii"]], {
    {0,4,7},
    {2,5,9},
    {4,7,11},
    {5,9,12},
    {7,11,14},
    {9,12,16},
    {11,14,17},    
    }, 'Tonic chords')
    
    
    verify_chords([[X:1
    K:C
    "I7" "ii7" "iii7" "IV7" "V7" "vi7" "vii7"]], {
    {0,4,7,10},
    {2,5,9,12},
    {4,7,11,14},
    {5,9,12, 15},
    {7,11,14,17},
    {9,12,16,19},
    {11,14,17,20},    
    }, '7th Tonic chords')
    
    print("Chords passed OK")
end




test_chords()

