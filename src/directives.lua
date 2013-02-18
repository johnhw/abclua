-- functions for handling custom directives

-- table maps directive names to functions
-- each function takes two arguments: the song structure, and an argument list from
-- the directive (as a table)
local directive_table = {}


function apply_directive(song, directive, arguments)
    -- Apply a directive; look it up in the directive table,
    -- and if there is a match, execute it    
    if directive_table[directive] then        
        directive_table[directive].fn(song, directive, arguments, directive_table[directive].user)
    end
    
    -- record all directives in the context
    if song.context then
       song.context.directives[directive] = song.context.directives[directive] or {}
       table.insert(song.context.directives[directive], arguments)
    end

end

function register_directive(directive, fn, parse, user)
    -- Register a user directive. Will call fn(song, directive, arguments) when
    -- the given directive is found. If parse is true, this directive is executed at parse time
    -- (e.g. to insert new tokens into the stream)    
    -- user can represent user data to be passed to the function on execution
        directive_table[directive] = {fn=fn, parse=parse, user=user}    
    
end

function inject_tokens(song, tokens)
    -- insert tokens immediately after current point
    for i,v in ipairs(tokens) do
        table.insert(song.token_stream, v)
    end
end


function inject_events(song, events)
    -- add events to the opus (to be called from directives)
    for i,v in ipairs(events) do
        table.insert(song.opus, v)
    end
end

function parse_directive(directive)
    -- parse a directive into a directive, followed by sequence of space separated directives
    -- returns true if this directive must be executed at parse time (e.g. abc-include)
    local directive_pattern = [[
    directives <- (%s * ({:directive: %S+ :} ) %s+ ?  {:arguments: ( ({%S+} %s +) * {%S+}  )? -> {}  :} )  -> {}
    ]]
    
    local match = re.match(directive, directive_pattern)
  
    if match and directive_table[match.directive] and directive_table[match.directive].parse then       
        return true, match
    else
        return false, match
    end
    
end
