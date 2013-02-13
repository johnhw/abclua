-- functions for handling custom directives

local grace_matcher = re.compile([[ 
    length <- ({:num: (number) :} '/' {:den: (number) :}) -> {}
    number <- ([0-9]+)
    ]])

function directive_set_grace_note_length(song, directive, arguments)
    -- set the length of grace notes
    -- Directive should be of the form I:gracenotes 1/64
    if arguments[1] then
        -- extract ratio
        local ratio = grace_matcher:match(arguments[1])
        if ratio then
            song.context.grace_note_length = {num=ratio.num, den=ratio.den}
        end
    end
    update_timing(song) -- must recompute note lengths
end




function abc_include(song, directive, arguments)
    -- Include a file. We can just directly invoke parse_abc_string() on 
    -- the file contents. The include file must have only one tune -- no multi-tune files
    
    local filename = arguments[1]
    if filename then
        local f = io.open(filename, 'r')            
        song.includes = song.includes or {}
        
        -- disallow include loops!
        if song.includes[filename] then
            return 
        end
        
        -- remember we included this file
        song.includes[filename] = filename
        
        -- check if the file exists
        if f then
            -- and we can read it...
            local contents = f:read('*a')
            if contents then
                -- then recursively invoke parse_abc_string
                parse_abc_string(song, contents)
            end
        end
    end
end

-- table maps directive names to functions
-- each function takes two arguments: the song structure, and an argument list from
-- the directive (as a table)
local directive_table = {
gracenote  = directive_set_grace_note_length,
['abc-include'] = abc_include
}

-- directives listed here must be executed at parse time,
-- not at compile time (because they change the parsing of future
-- text, e.g. by inserting new tokens)
local parse_directives = {
    'abc-include'
}

function apply_directive(song, directive, arguments)
    -- Apply a directive; look it up in the directive table,
    -- and if there is a match, execute it
    
    if directive_table[directive] then        
        directive_table[directive](song, directive, arguments)
    end

end

function register_user_directive(directive, fn)
    -- Register a user directive. Will call fn(song, directive, arguments) when
    -- the given directive is found
    directive_table[directive] = fn
    
end


function parse_directive(directive)
    -- parse a directive into a directive, followed by sequence of space separated directives
    -- returns true if this directive must be executed at parse time (e.g. abc-include)
    local directive_pattern = [[
    directives <- (%s * ({:directive: %S+ :} ) %s+ ?  {:arguments: ( ({%S+} %s +) * {%S+}  ) -> {}  :} )  -> {}
    ]]
    
    local match = re.match(directive, directive_pattern)
    
    if match and is_in(match.directive, parse_directives) then
        return true, match
    else
        return false, match
    end
    
end
