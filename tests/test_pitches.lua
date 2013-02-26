-- verify that pitches are rendered correctly
abclua = require "abclua"

function get_semis(stream)
    -- return a table representing the computed pitches of each note
    local notes = {}
    for i,v in ipairs(stream) do        
        if v.event=='note' then
            table.insert(notes, v.note.play_pitch)
        end
    end
    return notes
end


function verify_semis(str, result, test)
    -- verify that the pitches match the expected values
    local songs = abclua.parse_abc_multisong(str)          
    local stream = songs[1].voices['default'].stream
    semis = get_semis(stream)
    for i, v in ipairs(result) do
        assert(semis[i]==result[i], test)
    end
    print(test.." passed OK") 
end

function test_scales()
    -- Test repeats and variant endings
    
    verify_semis([[
    X:1
    K:C
    CDEFGAB    
    ]], {60,62,64,65,67,69,71}, 'C Major Scale')
    
    verify_semis([[
    X:1
    K:G
    CDEFGAB    
    ]], {60,62,64,66,67,69,71}, 'G Major Scale')
    
    verify_semis([[
    X:1
    K:C exp _c _f _g
    CDEFGAB    
    ]], {59,62,64,64,66,69,71}, 'Explicit Scale')
    
    
    verify_semis([[
    X:1
    K:D dorian
    CDEFGAB    
    ]], {60,62,64,65,67,69,71}, 'D Dorian scale')
    
    
    verify_semis([[
    X:1
    K:Hp
    CDEFGAB    
    ]], {61,62,64,65,68,69,71}, 'Pipe scale')
    
    
    verify_semis([[
    X:1
    K:none
    CDEFGAB    
    ]], {60,62,64,65,67,69,71}, 'Pipe scale')
    
    
    verify_semis([[
    X:1
    K:C exp ^/4c _2/5f
    CDEFGAB    
    ]], {60.25,62,64,64.6,67,69,71}, 'Microtonal scale')
    
    
    print("Scales passed OK")
end



function test_pitches()
    -- Test repeats and variant endings
    
    verify_semis([[
    X:1
    K:C
    CDEFGAB    
    ]], {60,62,64,65,67,69,71}, 'C Major Scale')
    
    
    verify_semis([[
    X:1
    K:C
    ^C^^D_E__FGAB    
    ]], {61,64,63,63,67,69,71}, 'Accidentals')
    
    
    verify_semis([[
    X:1
    K:D
    =CDE=FGAB    
    ]], {60,62,64,65,67,69,71}, 'Naturals')
    
    
    verify_semis([[
    X:1
    K:C
    ^/4CDE_3/5FGAB    
    ]], {60.25,62,64,64.4,67,69,71}, 'Microtonal accidentals')
    
    
    verify_semis([[
    X:1
    K:C
    C,,,,,C,,,,C,,,C,,C,C cc'c''c'''c''''    
    ]], {0,12,24,36,48,60,72,84,96,108,120}, 'Octaves')
    
   
    
    print("Pitches passed OK")
end




test_scales()
test_pitches()
