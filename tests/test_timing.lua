-- verify that pitches are rendered correctly
abclua = require "abclua"

function get_times(stream, event)
    -- return a table representing the computed durations of each note
    local notes = {}
    event = event or 'note'
    for i,v in ipairs(stream) do        
        if v.event==event then
            table.insert(notes, v.t)
        end
    end
   
    return notes
end


function verify_times(str, result, test, event)
    -- verify that the pitches match the expected values
   
    local songs = abclua.parse_abc_multisong(str)          
    local stream = songs[1].voices['default'].stream
    local times = get_times(stream, event)
    for i, v in ipairs(result) do
        assert(math.abs((times[i]/1e6)-result[i])<1e-4, test)
    end
    print(test.." passed OK")
end

function test_times()
    -- Test durations of notes
    
    verify_times([[
    X:1
    Q:1/4=30
    K:C
    CDEF    
    ]], {0,1,2,3}, 'Even time')
    
   verify_times([[
    X:1
    Q:1/4=30
    K:C
    zzzz    
    ]], {0,1,2,3}, 'Simple rests','rest')
    
    
   verify_times([[
    X:1
    Q:1/4=30
    K:C
    A/2A>AA/3A   
    ]], {0,0.5,2,2.5,2.5+1/3}, 'Complex time')
 
 
   verify_times([[
    X:1
    Q:1/4=30
    K:C
    [CEG]   
    ]], {0,0,0}, 'Chord group')
 
 
   verify_times([[
    X:1
    Q:1/4=30
    K:C
    [CEG]A[DEF]   
    ]], {0,0,0,1,2,2,2}, 'Multiple chord groups')
 
 
   verify_times([[
    X:1
    Q:1/4=30
    K:C
    A B C | D E F & G A B  
    ]], {0,1,2,3,4,5,3,4,5}, 'Bar overlay')
 
   verify_times([[
    X:1
    Q:1/4=30
    K:C
    A B C | D E F & G A B | G A B 
    ]], {0,1,2,3,4,5,3,4,5,6,7,8}, 'Bar overlay with follow on')
   
   verify_times([[
    X:1
    Q:1/4=30
    K:C
    A B C | D E F & G A B & G A B 
    ]], {0,1,2,3,4,5,3,4,5,3,4,5}, 'Multiple bar overlay')
     
end   
test_times()