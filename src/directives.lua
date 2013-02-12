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

-- table maps directive names to functions
-- each function takes two arguments: the song structure, and an argument list from
-- the directive (as a table)
local directive_table = {
gracenote  = directive_set_grace_note_length
}

function apply_directive(song, directive, arguments)
    -- Apply a directive; look it up in the directive table,
    -- and if there is a match, execute it
    if directive_table[directive] then
        print(directive)
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
    local directive_pattern = [[
    directives <- (%s * ({:directive: %S+ :} ) %s+ ?  {:arguments: ( ({%S+} %s +) * {%S+}  ) -> {}  :} )  -> {}
    ]]
    
    local match = re.match(directive, directive_pattern)
    return match
end
