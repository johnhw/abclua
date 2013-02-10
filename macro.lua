local re = require "re"

-- subsitution macro handling

-- tables for shifting notes (diatonically)
local transpose_notes = { 
    'C,,', 'D,,', 'E,,', 'F,,', 'G,,', 'A,,', 'B,,',
    'C,', 'D,', 'E,', 'F,', 'G,', 'A,', 'B,',
    'C', 'D', 'E', 'F', 'G', 'A', 'B',
     'c', 'd', 'e', 'f', 'g', 'a', 'b',
     "c'", "d'", "e'", "f'", "g'", "a'", "b'",
     "c''", "d''", "e''", "f''", "g''", "a''", "b''"    
    }
    
local transpose_note_lookup = invert_table(transpose_notes)

function transpose_note(note, offset)
    -- transpose a note (a-g A-G) by the given number of steps
    -- e.g. transpose_note('a', 1) = 'b'
    --      transpose_note('g', 3) = 'c''
    --      transpose_note('E', -1) = 'D'
    
    return transpose_notes[transpose_note_lookup[note]+offset]
end

function transpose_macro(lhs, note, rhs)
    -- create the macro expansion for lhs -> rhs
-- replace n in lhs with note
-- and any letters h..z in rhs with relatively offset pitches

    local lhs = lhs:gsub('n', note)
    rhs = rhs:gsub('([h-zH-Z])', function (s)
    -- only allow lowercase values
    s = string.lower(s)
    relative = string.byte(s) - string.byte('n')
    return transpose_note(note, relative)
    end)
    return {lhs=lhs, rhs=rhs}
end


function parse_macro(macro)
    -- take a raw ABC string block and expand any macros defined it
    -- expansion takes place *before* any other parsing
    macro_pattern = [[
    macro <- (%s * ({:lhs: [^=%s] + :}) %s * '=' %s * ({:rhs: ([^%nl] *) :})) -> {} 
    ]]
    
    local match = re.match(macro, macro_pattern)
    
    return match
    
end
