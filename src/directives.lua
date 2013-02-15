-- functions for handling custom directives

local grace_matcher = re.compile([[ 
    length <- ({:num: (number) :} '/' {:den: (number) :}) -> {}
    number <- ([0-9]+)
    ]])




-- table maps directive names to functions
-- each function takes two arguments: the song structure, and an argument list from
-- the directive (as a table)
local directive_table = {}


function apply_directive(song, directive, arguments)
    -- Apply a directive; look it up in the directive table,
    -- and if there is a match, execute it    
    if directive_table[directive] then        
        directive_table[directive].fn(song, directive, arguments)
    end

end

function register_directive(directive, fn, parse)
    -- Register a user directive. Will call fn(song, directive, arguments) when
    -- the given directive is found. If parse is true, this directive is executed at parse time
    -- (e.g. to insert new tokens into the stream)    
        directive_table[directive] = {fn=fn, parse=parse}    
    
end


function parse_directive(directive)
    -- parse a directive into a directive, followed by sequence of space separated directives
    -- returns true if this directive must be executed at parse time (e.g. abc-include)
    local directive_pattern = [[
    directives <- (%s * ({:directive: %S+ :} ) %s+ ?  {:arguments: ( ({%S+} %s +) * {%S+}  ) -> {}  :} )  -> {}
    ]]
    
    local match = re.match(directive, directive_pattern)
    
    if match and directive_table[match] and directive_table[match].parse then       
        return true, match
    else
        return false, match
    end
    
end
