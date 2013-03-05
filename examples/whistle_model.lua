abclua = require "abclua"


function set_instrument_score(instrument, notes, score)
    -- Set the score for each specified note in notes to the     
    -- score given. Notes are specified as if they were in the
    -- key of C; all flats and sharps must be explicitly stated
    local fragment = abclua.parse_abc_fragment(notes)
    for i,v in ipairs(fragment) do
        if v.token=='note' then
            local index = abclua.midi_note_from_note(nil,v.note)
            instrument[index] = {difficulty=score}
        end
    end
end

function transpose_instrument(instrument, offset)
    -- Transpose an instrument definition by the given number
    -- of semitones. e.g. transpose_instrument_score(d_whistle, -2)
    -- returns a high c whistle definition
    local transposed = {}
    for i,v in pairs(instrument) do
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
                total_penalty = total_penalty + instrument[pitch].difficulty
                v.penalty = instrument[pitch].difficulty
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
        table.insert(scores, {unplayable*300 + penalty, i})
    end    
    -- sort by score
    table.sort(scores, function(a,b) return a[1]<b[1] end)
    local optimal = scores[1][2]
    diatonic_transpose(stream, optimal)
end

function make_whistle()
    -- create a basic instrument which has penalties for playing on a high D whistle
    local d_whistle_score = {}
    set_instrument_score(d_whistle, 'DE^FGAB^cde^fga', 0)
    set_instrument_score(d_whistle, "b^c'=C=c", 2)
    set_instrument_score(d_whistle, "^DFF^G^A", 10)
    set_instrument_score(d_whistle, "d'e'^f'g", 20)       
    return d_whistle_score
end

function get_whistle_fingerings(transpose)
     -- transpose shifts the whistle key (e.g. transpose -7 fingers an A whistle)
     -- fingering stored as a table {48 = {fingers={0,0,0,0,0,0}, octave=0, difficulty=}} etc.
    transpose = transpose or 0
    local d_fingers = {}
    local fragment = abclua.parse_abc_fragment('DE^FGAB^c')
    local fingers = {1,1,1,1,1,1}
    
    -- standard open holes
    for i,v in ipairs(fragment) do
        if v.note then
            local index = abclua.midi_note_from_note(nil, v.note) + transpose            
            d_fingers[index] = {fingers=copy_table(fingers), octave=0, difficulty=i}
            d_fingers[index+12] = {fingers=copy_table(fingers), octave=1, difficulty=7+i*2}
            fingers[7-i] = 0
        end
    end    
    
    -- half holing
    d_fingers[63+transpose] = {fingers={1,1,1,1,1,0.5}, octave=0, difficulty=40}
    d_fingers[65+transpose] = {fingers={1,1,1,1,0.5,0}, octave=0, difficulty=41}
    d_fingers[69+transpose] = {fingers={1,1,0.5,0,0,0}, octave=0, difficulty=42}
    d_fingers[71+transpose] = {fingers={1,0.5,0,0,0,0}, octave=0, difficulty=43}
    d_fingers[73+transpose] = {fingers={0.5,0,0,0,0,0}, octave=0, difficulty=44}
    
    d_fingers[12+63+transpose] = {fingers={1,1,1,1,1,0.5}, octave=1, difficulty=50}
    d_fingers[12+65+transpose] = {fingers={1,1,1,1,0.5,0}, octave=1, difficulty=51}
    d_fingers[12+69+transpose] = {fingers={1,1,0.5,0,0,0}, octave=1, difficulty=52}
    d_fingers[12+71+transpose] = {fingers={1,0.5,0,0,0,0}, octave=1, difficulty=53}
    d_fingers[12+73+transpose] = {fingers={0.5,0,0,0,0,0}, octave=1, difficulty=54}
        
    
    -- c natural cross-fingering
    d_fingers[72+transpose] = {fingers={0,1,1,0,0,0}, octave=1, difficulty=15}
    d_fingers[60+transpose] = {fingers={0,1,1,0,0,0}, octave=0, difficulty=5}
    
    -- high d fingering
    d_fingers[74+transpose] = {fingers={0,1,1,1,1,1}, octave=1, difficulty=10}
    -- very high d fingering
    d_fingers[86+transpose] = {fingers={1,1,1,1,1,1}, octave=2, difficulty=20}
    
        
    return d_fingers         
end


