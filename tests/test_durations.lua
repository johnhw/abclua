-- verify that pitches are rendered correctly
abclua = require "abclua"

function get_durations(stream, event)
    -- return a table representing the computed durations of each note
    local notes = {}
    event = event or 'note'
    for i,v in ipairs(stream) do        
        if v.event==event then
            table.insert(notes, v.duration)
        end
    end
   
    return notes
end


function verify_durations(str, result, test, event)
    -- verify that the pitches match the expected values
   
    local songs = abclua.parse_abc_multisong(str)          
    local stream = songs[1].voices['default'].stream
    local durations = get_durations(stream, event)
    for i, v in ipairs(result) do
        assert(math.abs((durations[i]/1e6)-result[i])<1e-4, test)
    end
    print(test.." passed OK")
end

function test_durations()
    -- Test durations of notes
    
    verify_durations([[
    X:1
    Q:1/4=30
    K:C
    CDEF    
    ]], {1,1,1,1}, 'Even time')
    
    
    verify_durations([[
    X:1
    Q:1/4=30
    K:C
    CD2E3F4    
    ]], {1,2,3,4}, 'Integer multipliers')
    
    verify_durations([[
    X:1
    Q:1/4=60   
    K:G
    CDEF 
    ]], {0.5,0.5,0.5,0.5}, 'Tempo change')
    
    verify_durations([[
    X:1
    Q:1/4=30
    L:1/4
    K:G
    CDEF 
    ]], {2,2,2,2}, 'Note length')
    
    
    verify_durations([[
    X:1
    Q:1/4=30
    L:1/4
    K:G
    CDEF 
    ]], {2,2,2,2}, 'Note length 1/4')
    
    verify_durations([[
    X:1
    Q:1/4=30
    L:1/16
    K:G
    CDEF 
    ]], {0.5,0.5,0.5,0.5}, 'Note length 1/16')
    
    
    verify_durations([[
    X:1
    Q:1/4=30
    K:G
    CD/E//F/// 
    ]], {1,0.5,0.25,0.125}, 'Slashes')
    
    
    verify_durations([[
    X:1
    Q:1/4=30
    K:G
    CD/2E1/4F4/32 
    ]], {1,0.5,0.25,0.125}, 'Ratios')
    
    
    verify_durations([[
    X:1
    Q:1/4=30
    K:G
    CD/2E1/3F4/5 
    ]], {1,0.5,1/3,4/5}, 'Complex ratios')
    
    
    verify_durations([[
    X:1
    Q:1/4=30
    K:G
    CD>DD<D
    ]], {1,1.5,0.5,0.5,1.5}, 'Broken rhythm')
    
    
    verify_durations([[
    X:1
    Q:1/4=30
    K:G
    CD>>DD<<<D
    ]], {1,1.75,0.25,0.125,1.875}, 'Multiple broken rhythm')
    
    
    verify_durations([[
    X:1
    Q:1/4=30
    K:G
    C (3 D D D D
    ]], {1,2/3,2/3,2/3,1}, 'Simple triplet')
    
    
    verify_durations([[
    X:1
    Q:1/4=30
    K:G
    C (3:2:4 D D D D
    ]], {1,2/3,2/3,2/3,2/3}, 'Triplet with extended r')
    
    
    verify_durations([[
    X:1
    Q:1/4=30
    K:G
    C (3:5:4 D D D D
    ]], {1,5/3,5/3,5/3,5/3}, 'Triplet with extended q')
    
    
    verify_durations([[
    X:1
    Q:1/4=30
    K:G
    C (5:2 D D D D D D
    ]], {1,2/5,2/5,2/5,2/5,2/5, 1}, 'Triplet with extended p, default r')
    
    verify_durations([[
    X:1
    Q:1/4=30
    K:G
    C (5:5:5 D D D D D D
    ]], {1,1,1,1,1,1,1}, 'Triplet with no effect')
    
    print("Durations passed OK")
end

function test_rests()
    verify_durations([[
    X:1
    Q:1/4=30
    K:C
    zzzz    
    ]], {1,1,1,1}, 'Simple rests','rest')
   
   verify_durations([[
    X:1
    Q:1/4=30
    K:C
    zz2z3z4    
    ]], {1,2,3,4}, 'Integer rests','rest')
   
   
   verify_durations([[
    X:1
    Q:1/4=30
    K:C
    (3 zzzz    
    ]], {2/3,2/3,2/3,1}, 'Triplet rests','rest')
   
   
   verify_durations([[
    X:1
    Q:1/4=30
    M:3/4
    K:C
    ZZZ    
    ]], {6,6,6}, '3/4 Measure rests','rest')
   
   
   verify_durations([[
    X:1
    Q:1/4=30
    M:4/4
    K:C
    ZZZ    
    ]], {8,8,8}, '4/4 Measure rests','rest')
   

   verify_durations([[
    X:1
    Q:1/4=30
    M:9/8
    K:C
    ZZZ    
    ]], {9,9,9}, '9/8 Measure rests','rest')
  
   verify_durations([[
    X:1
    Q:1/4=30
    M:4/4
    K:C
    Z2Z3Z4    
    ]], {16,24,32}, 'Measure rests multiples','rest')
     
     
   verify_durations([[
    X:1
    Q:1/4=30
    M:4/4
    K:C
    Z/2Z/4    
    ]], {4,2}, 'Fractional measure rests','rest')
     
end   

test_durations()
test_rests()