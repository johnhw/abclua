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


function directive_abc_include(song, directive, arguments)
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

function directive_broken_ratio(song, directive, arguments)
        -- set the broken rhythm ratio
        local p = arguments[2]
        local q = arguments[3] or 1
        song.context.broken_ratio = p/q
end


function directive_propagate_accidentals(song, directive, arguments)
    -- Set the accidental propagation mode. Can be
    -- 'not': do not propagate accidentals
    -- 'ocatave': propagate only within an octave until end of bar
    -- 'pitch': propagate within pitch class until end of bar
    song.context.propagate_accidentals = arguments[1]
end


function directive_enable_bar_warnings(song, directive, arguments)
    -- turn on bar warnings, so that overfull and underfull bars cause
    -- warnings to be printed
    song.context.bar_warnings = true
end

register_directive('enable-bar-warnings', directive_enable_bar_warnings)
register_directive('gracenote', directive_set_grace_note_length)
register_directive('abc-include', directive_abc_include)
register_directive('broken-ratio', directive_broken_ratio)
register_directive('propagate-accidentals', directive_propagate_accidentals)


