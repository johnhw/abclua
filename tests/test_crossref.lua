-- Verify that cross referencing and aligned ABC emission works correctly
abclua = require "abclua"

function get_crossrefs(tokens, refs)
    -- return a table of all the cross references in the stream, as strings
   
    for i,v in ipairs(tokens) do 
        if v.cross_ref then
            table.insert(refs,v.cross_ref.tune..'-'..v.cross_ref.tune_line..'-'..v.cross_ref.line..'-'..v.cross_ref.at)
        end
    end
   
end

function verify_crossrefs(str, result, test)
    -- verify that the pitches match the expected values
    local songs = abclua.parse_abc_multisong(str, {cross_ref=true})
    local refs = {}
    for i,v in ipairs(songs) do
        tokens = v.token_stream
        get_crossrefs(tokens, refs)
    end
    -- table_print(refs)
    for i, v in ipairs(result) do
        assert(refs[i]==result[i], test)
    end
    print(test.." passed OK") 
end

function test_crossrefs()
    -- Test repeats and variant endings
    
    verify_crossrefs([[
    X:1
    K:C
    CDE    
    ]], {
    '1-1-1-1', 
    '1-2-2-1', 
    '1-3-3-1', 
    '1-3-3-2',
    '1-3-3-3',
    '1-3-3-4',
    '1-3-3-4',  -- newline
    }, 'Simple notes cross refs')
    
    
    verify_crossrefs([[
    X:1
    K:C
    C[r:remark]DE    
    ]], {
    '1-1-1-1', '1-2-2-1', 
    '1-3-3-1', 
    '1-3-3-2',
    '1-3-3-12',
    '1-3-3-13',
    '1-3-3-14',  
    '1-3-3-14',  -- newline
    }, 'Inline fields cross refs')
    
    verify_crossrefs([[
    X:1
    K:C
    C"r:remark"DE    
    ]], {
    '1-1-1-1', '1-2-2-1', 
    '1-3-3-1', 
    '1-3-3-2',
    '1-3-3-13',
    '1-3-3-14',  
    '1-3-3-14',  -- newline
    }, 'Annotations cross refs')
    
    verify_crossrefs([[
    X:1
    K:C
    CDE

    X:1
    K:C
    CDE
    ]], {
    '1-1-1-1', 
    '1-2-2-1', 
    '1-3-3-1', 
    '1-3-3-2',
    '1-3-3-3',
    '1-3-3-3',
 
    '2-1-4-1', 
    '2-2-5-1', 
    '2-3-6-1', 
    '2-3-6-2',
    '2-3-6-3',
    '2-3-6-3',
   
    }, 'Multiple song cross refs')
    
end

test_crossrefs()
