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
    local whistle =  get_whistle_fingerings()
    songs = parse_abc_file(arg[1])
    if songs and songs[1] then
        stream = compile_tokens(songs[1].token_stream)
        unplayable, penalty = check_instrument(stream,whistle,0)
        print("% Original penalty "..penalty.. " unplayable notes "..unplayable)
        optimal_transpose(songs[1].token_stream, whistle)
        print(emit_abc(songs[1].token_stream))        
        stream = compile_tokens(songs[1].token_stream)
        unplayable, penalty = check_instrument(stream,whistle,0)
        print("% New penalty "..penalty.. " unplayable notes "..unplayable)
    else
        print("Could not read " .. arg[1])
    end
end
