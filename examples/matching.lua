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




function check_instrument(stream, instrument)
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
    
    for i,v in ipairs(stream) do
        if v.event=='note' then
            -- check if playable at all
            if not instrument[v.pitch]  then
                total_unplayable = total_unplayable + 1
                v.penalty = -1
            else
                -- accumulate penalty
                total_penalty = total_penalty + instrument[v.pitch]
                               
                v.penalty = instrument[v.pitch]
            end
        end
        
    end
    
    return total_unplayable, total_penalty    
end

skye=[[
% this is a comment
X:437
T:Over the Sea to Skye
T:The Skye Boat Song 
S:Childhood memories
V:tenor
H:Written a long time ago
about Skye, an island off
Scotland
Z:Nigel Gatherer
+:and friends
Q:1/4=140 
M:3/4
L:1/4
K:G
D>ED | G G | A>BA | d3 | B>AB | E2 E | D2- | D3 :|:     
B>GB | B3 | A>EA | A3 | G>EG | G2 G | E3 | E3 | 
B>GB | B3 | A>EA | A3 | G>EG | G2 G | E3 | D3 || 
|: D>ED  | G2 G | A>BA | d3 | B>AB | E2- :|1 E | D2 |  D3 :|2 E | F2 | G3 :|  
]]


local d_whistle = {}
set_instrument_score(d_whistle, 'DE^FGAB^cdefg', 0)
set_instrument_score(d_whistle, "ab^c'=C=c", 2)
set_instrument_score(d_whistle, "d'e'f'g", 10)
set_instrument_score(d_whistle, "^DFF^G^A", 10)

song = compile_abc(skye)
print(check_instrument(song.voices['default'].stream, d_whistle))
