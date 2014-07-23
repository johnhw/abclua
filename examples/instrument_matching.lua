--------------------------------------------------------------------
-- Instrument matching
-- Takes an ABC tune file, and finds a transposition which would be
-- most playable on a high D tin whistle, and writes that to stdout
--------------------------------------------------------------------

require "abclua"
require "examples/instrument_model"


if #arg~=1 then
    print("Usage: instrument_matching <file.abc>")
else
    local whistle =  make_whistle()
	
    songs = parse_abc_file(arg[1])
    if songs and songs[1] then
		tr = optimal_transpose(songs[1], whistle)	
		
		print(emit_abc(tr.token_stream))
    else
        print("Could not read " .. arg[1])
    end
end
