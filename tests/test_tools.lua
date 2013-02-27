-- test helper functions for manipulating ABC files
local abclua = require "abclua"

function test_validate(str, result, test)
    local validated = emit_abc(validate_token_stream(parse_abc_fragment(str)))    
    assert(validated:gsub('%s','')==result:gsub('%s',''), test)
    print(test.." passed OK")
end

function test_validation()
    -- Test validation
    
    test_validate([[X:1
    T:Title
    K:G
    abcdef]], [[X:1
    T:Title
    K:G
    abcdef]], 'Validation: Simple tune body')
    
    
    test_validate([[X:1
    T:Title
    K:G]], [[X:1
    T:Title
    K:G]], 'Validation: No tune body')
    
    test_validate([[X:1    
    K:G
    T:Title
    ]], [[X:1
    T:Title
    K:G]], 'Validation: Title wrong order')
    
    test_validate([[K:G    
    T:Title
    X:1
    ]], [[X:1
    T:Title
    K:G]], 'Validation: Wrong order')
    
    
    test_validate([[abcdef
    ]], [[X:1
    T:untitled
    K:C
    abcdef
    ]], 'Validation: No header')
    
    test_validate([[E:editor
    A:Author
    K:G
    X:2
    H:Somewhere
    T:A song    
    abcdef
    ]], [[
    X:2    
    T:A song
    E:editor
    A:Author       
    H:Somewhere
    K:G 
    abcdef
    ]], 'Validation: Jumbled')
    
    
    
end


function test_header(str, index, test)
    local found_index = header_end_index(parse_abc_fragment(str))    
    assert(found_index==index, test)
    print(test.." passed OK")
end

function test_header_end()
    -- test header index finding
    test_header([[X:1
    T:Title
    K:G]], nil, 'Header index: No tune body')
    
    
    test_header([[X:1
    T:Title
    K:G
    abcdef
    ]], 4, 'Header index: Simple tune')
    
    
    test_header([[X:1
    H:Some history
    which continues    
    T:Title    
    K:G
    abc
    ]], 5, 'Header index: bare lines')
    
    
    
    test_header([[
    abcdef
    ]], 1, 'Header index: No header')
    
    
    test_header([[
    abcdef
    K:G
    ]], 1, 'Header index: No header, following fields')
    
end

test_header_end()
test_validation()