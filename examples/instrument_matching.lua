--------------------------------------------------------------------
-- Instrument matching
-- Takes an ABC tune file, and finds a transposition which would be
-- most playable on a high D tin whistle, and writes that to stdout
--------------------------------------------------------------------

require "abclua"

function set_instrument_score(instrument, notes, score)
    -- Set the score for each specified note in notes to the     
    -- score given. Notes are specified as if they were in the
    -- key of C; all flats and sharps must be explicitly stated
    local fragment = parse_abc_fragment(notes)
    for i,v in ipairs(fragment) do
        if v.token=='note' then
            local index = midi_note_from_note(nil,v.note)
            instrument[index] = score
        end
    end
end

function transpose_instrument(instrument, offset)
    -- Transpose an instrument definition by the given number
    -- of semitones. e.g. transpose_instrument_score(d_whistle, -2)
    -- returns a high c whistle definition
    local transposed = {}
    for i,v in pairs(instrument)
        transposed[i+offset] = v 
    end
    return transposed
end

function check_instrument(stream, instrument, offset)
    -- check how well a stream matches a given instrument
    -- instrument specifies the penalties for playing different pitches
    -- (given in MIDI note numbers)
    -- 0=most desirable, 1=less desirable, etc. If not specified
    -- then that instrument cannot play that note
    --
    -- returns: total_unplayable, total_penalty
    -- modifies stream so that note elements have a penalty field (equals -1 if unplayable)
   
    local total_unplayable = 0
    local total_penalty = 0
    local pitch
    for i,v in ipairs(stream) do
        if v.event=='note' then
            pitch = v.note.play_pitch+offset
            
            -- check if playable at all
            if not instrument[pitch]  then
                total_unplayable = total_unplayable + 1
                v.penalty = -1
            else
                -- accumulate penalty
                total_penalty = total_penalty + instrument[pitch]                    
                v.penalty = instrument[pitch]
            end
        end     
    end    
 
    return total_unplayable, total_penalty    
end


function optimal_transpose(stream, instrument)   
    -- find the transposition that minimises the unplayable/difficult notes
    -- for the given instrument, and transpose the token stream to that key
    local scores = {}
    local compiled_stream = compile_tokens(stream)
    
    -- try each transposition in a +/- 2 octave range
    for i=-24,24 do
        local unplayable, penalty
        unplayable, penalty = check_instrument(compiled_stream, instrument, i)
        table.insert(scores, {unplayable*30 + penalty, i})
    end
    
    -- sort by score
    table.sort(scores, function(a,b) return a[1]<b[1] end)
    local optimal = scores[1][2]
    diatonic_transpose(stream, optimal)
end

function make_whistle()
    -- create an instrument which has penalties for playing on a high D whistle
    local d_whistle = {}
    set_instrument_score(d_whistle, 'DE^FGAB^cde^fga', 0)
    set_instrument_score(d_whistle, "b^c'=C=c", 2)
    set_instrument_score(d_whistle, "^DFF^G^A", 10)
    set_instrument_score(d_whistle, "d'e'^f'g", 20)
    return d_whistle
end

if #arg~=1 then
    print("Usage: match_whistle <file.abc>")
else
    local whistle = make_whistle()
    songs = parse_abc_file(arg[1])
    if songs and songs[1] then
        optimal_transpose(songs[1].token_stream, whistle)
        print(emit_abc(songs[1].token_stream))
    else
        print("Could not read " .. arg[1])
    end
end
