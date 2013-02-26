-- verify that repeats work correctly
abclua = require "abclua"

function get_notes(stream)
    -- return a string representing the named pitches of each note
    local notes = {}
    for i,v in ipairs(stream) do        
        if v.event=='note' then
            table.insert(notes, string.lower(v.note.pitch.note))
        end
    end
    return table.concat(notes)
end


function verify_notes(str, result, test)
    local songs = abclua.parse_abc_multisong(str)          
    local stream = songs[1].voices['default'].stream    
    assert(get_notes(stream) == result, test)   
    print(test.." passed OK")
end

function test_repeats()
    -- Test repeats and variant endings
    
    verify_notes([[
    X:1
    K:G
    D E D | A B  :|    
    ]], 'dedabdedab', 'Single bar repeat')
    
    verify_notes([[
    X:1
    K:G
    | D E D |: A B  :|    
    ]], 'dedabab', 'Second bar repeat')
    
    verify_notes([[
    X:1
    K:G
    |:: D E D ::|: A B  :|    
    ]], 'deddeddedabab', 'Multi repeats')
    
    verify_notes([[
    X:1
    K:G
    |: D E D :|1 A B  :|2 C D || 
    ]], 'dedabdedcd', 'Variant endings')
    
    verify_notes([[
    X:1
    K:G
    |:: D E D ::|1 A B  :|2 C D  :|3 E G A || 
    ]], 'dedabdedcddedega', '3 Variant endings')
    
    verify_notes([[
    X:1
    K:G
    |: D E D :|1 A B  :|2 C D  :|3 E G A || F G A
    ]], 'dedabdedcdfga', 'Variant endings with extra variant')
    
    verify_notes([[
    X:1
    K:G
    |: D E D :|1 A B  :| F F E
    ]], 'dedabdedffe', 'Variant endings with missing variant')

    print("Repeats passed OK")
end



function test_parts()
    -- Test repeats and variant endings
    
    verify_notes([[
    X:1
    P:A
    K:G
    P:A
    D E D | A B 
    ]], 'dedab', 'Single part')
    
    verify_notes([[
    X:1    
    K:G
    P:A
    D E D | A B 
    ]], 'dedab', 'Single part, missing definition')
    
    
    verify_notes([[
    X:1    
    K:G
    P:A
    D E D | A B 
    P:C
    G F G | D A
    P:D
    E E E | B B
    ]], 'dedabgfgdaeeebb', 'Multi part, missing definition')
    
    verify_notes([[
    X:1
    P:AA
    K:G
    P:A
    D E D | A B 
    ]], 'dedabdedab', 'Repeated part')
    
    verify_notes([[
    X:1
    P:ABA
    K:G
    P:A
    D E D | A B 
    P:B
    G F G
    ]], 'dedabgfgdedab', 'Simple part string')
    
    verify_notes([[
    X:1
    P:A2B2A
    K:G
    P:A
    D E D | A B 
    P:B
    G F G
    ]], 'dedabdedabgfggfgdedab', 'Repeat part string')
    
    verify_notes([[
    X:1
    P:(AB)2A
    K:G
    P:A
    D E D | A B 
    P:B
    G F G
    ]], 'dedabgfgdedabgfgdedab', 'Bracketed repeat part string')
    
    
    verify_notes([[
    X:1
    P:(A(BC)2)2A
    K:G
    P:A
    D E D
    P:B
    A B
    P:C
    B B
    ]], 'dedabbbabbbdedabbbabbbded', 'Bracketed repeat part string')
        
        
    verify_notes([[
    X:1
    P:AA
    K:G
    P:A
    D E D | [2 A B 
    ]], 'deddedab', 'Repeated part, variant ending')
    
    verify_notes([[
    X:1
    P:AAA
    K:G
    P:A
    D E D | [1,3 A B 
    ]], 'dedabdeddedab', 'Repeated part, variant ending list')
    
    verify_notes([[
    X:1
    P:A5
    K:G
    P:A
    D E D | [1-2,4-5 A B 
    ]], 'dedabdedabdeddedabdedab', 'Repeated part, variant ending list')
    
    verify_notes([[
    X:1
    P:A5
    K:G
    P:A
    D E D | [1-2,4-5 A B | [3 GGG
    ]], 'dedabdedabdedgggdedabdedab', 'Repeated part, multiple variant ending list')
                
    print("Parts passed OK")
end


test_repeats()
test_parts()