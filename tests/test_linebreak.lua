local abclua = require "abclua"

function verify_linebreaks(str, result, test)
    local songs = abclua.parse_abc_multisong(str)
    local j = 1
    
    -- check each linebreak is in the expected position
    for i,v in ipairs(songs[1].token_stream) do
        if v.token=='split_line' then
            -- print(i)
            assert(i == result[j], test)
            j=j+1
        end    
    end
    assert(j-1==#result)
    print(test.. " passed OK")
end

local songs = verify_linebreaks([[X:1
K:G
a
d
g
]], {4,6,8}, 'Standard eol')

local songs = verify_linebreaks([[X:1
K:G
a\
d
g\
f
]], {6,10}, 'Standard eol, continuations')


local songs = verify_linebreaks([[X:1
K:G
I:linebreak <eol>
a\
d
g\
f
]], {6,10}, 'Specified eol, continuations')


local songs = verify_linebreaks([[X:1
K:G
I:linebreak <none>
a
d
g
]], {}, 'No line breaks')

local songs = verify_linebreaks([[X:1
K:G
I:linebreak $
a$d$g$
]], {4,6,8}, '$ linebreaks')

-- ! not supported
local songs = verify_linebreaks([[X:1
K:G
I:linebreak !
a!d!g!
]], {4,6,8}, '! linebreaks')

local songs = verify_linebreaks([[X:1
K:G
I:linebreak $ <eol>
a$d 
g 
]], {4,7,10}, 'Mixed linebreaks')
