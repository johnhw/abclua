-- functions for handling custom directives

function directive_set_grace_note_length(song, arguments)
    -- set the length of grace notes
    -- Directive should be of the form I:gracenotes 1/64
   
    grace_pattern = [[ 
    length <- {:num: (number) :} '/' {:den: (number) :}
    number <- ([0-9]+)
    ]]
    
    if arguments[1] then
        -- extract ratio
        ratio = grace_pattern.match(arguments[1])
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
    -- apply a directive
    if directive_table[directive] then
        directive_table[directive](song, match.arguments)
    end

end

function parse_directive(directive)
    -- parse a directive into a directive, followed by sequence of space separated directives
    local directive_pattern = [[
    directives <- (%s * ({:directive: %S+ :} ) %s+ ?  {:arguments: ( ({%S+} %s +) * {%S+}  ) -> {}  :} )  -> {}
    ]]
    
    local match = re.match(directive, directive_pattern)
    return match
end
