-- Takes an ABC tune, and automatically adds accompanying chords
-- Not very good at guessing good chords!
require "abclua"



local common_chords = 
{
["aug"] = { 0, 4, 8, },
["dim"] = { 0, 3, 6, },
["dim5"] = { 0, 4, 6, },
["maj"] = { 0, 4, 7, },
["min"] = { 0, 3, 7, },
["sus2"] = { 0, 2, 7, },
["sus4"] = { 0, 6, 7, },
["6"] = { 0, 4, 7, 9, },
["7"] = { 0, 4, 7, 10, },
["7sus2"] = { 0, 2, 7, 10, },
["7sus4"] = { 0, 6, 7, 10, },
["add2"] = { 0, 2, 4, 7, },
["add4"] = { 0, 4, 6, 7, },
["add9"] = { 0, 4, 7, 14, },
["dim7"] = { 0, 3, 6, 9, },
["madd9"] = { 0, 3, 7, 14, },
["mmaj7"] = { 0, 3, 7, 11, },
["m6"] = { 0, 3, 7, 9, },
["m7"] = { 0, 3, 7, 10, },
["m7#5"] = { 0, 3, 8, 10, },
["m7b5"] = { 0, 3, 6, 10, },
["maj7"] = { 0, 4, 7, 11, },
["maj7#5"] = { 0, 4, 8, 11, },
["maj7b5"] = { 0, 4, 6, 11, },
["9"] = { 0, 4, 7, 10, 14, },
["mmaj9"] = { 0, 3, 7, 11, 14, },
["m6/7"] = { 0, 3, 7, 9, 10, },
["m6/9"] = { 0, 3, 7, 9, 14, },
["m7/11"] = { 0, 3, 7, 10, 18, },
["m7add4"] = { 0, 3, 6, 7, 10, },
["m9"] = { 0, 3, 7, 10, 14, },
["m9/11"] = { 0, 3, 10, 14, 18, },
["m9b5"] = { 0, 3, 6, 10, 14, },
["maj9"] = { 0, 4, 7, 11, 14, },
}


local chord_weights = 
{
["aug"] = 0.1,
["dim"] = 0.1,
["dim5"] = 0.3,
["maj"] = 4,
["min"] = 2,
["sus2"] = 0.8,
["sus4"] = 0.8,
["6"] = 0.4,
["7"] = 1.2,
["7sus2"] = 0.15,
["7sus4"] = 0.15,
["add2"] = 0.1,
["add4"] = 0.1,
["add9"] = 0.7,
["dim7"] = 0.1,
["madd9"] = 0.3,
["mmaj7"] = 0.2,
["m6"] = 0.8,
["m7"] = 1.0,
["m7#5"] = 0.2,
["m7b5"] = 0.2,
["maj7"] = 0.7,
["maj7#5"] = 0.1,
["maj7b5"] = 0.1,
["9"] = 0.9,
["mmaj9"] = 0.1,
["m6/7"] = 0.2,
["m6/9"] = 0.2,
["m7/11"] = 0.05,
["m7add4"] = 0.05,
["m9"] = 0.5,
["m9/11"] = 0.05,
["m9b5"] = 0.05,
["maj9"] = 0.3,
}



-- score by: 
-- key (tonic, type) 
-- type (favour simple chords/jazzy chords)
-- note match (in bar)
-- beat position (weight first and strong notes more)


function score_chords(key)
    -- given a key, return chords scored according to their fit        
    -- weighting for chord fit to key; (poorer fit -> lower score)
    -- weighting for tonic; (favours I over V over VI over ii etc...)
    
    local key_root = get_note_number(key.root)
    local in_key = notes_in_key(key)
    -- build a key map for this key
    
    local in_key_chords = {}
    
    -- I, V, IV, ii, vi, iii, vii
    local tonic_weights = {[0]=10, [7]=6, [5]=3, [2]=1, [9]=1, [4]=0.5, [11]=0.25}    
    local default_tonic_score = 0.1 -- all other notes
    for i=0,11 do
        local chord = {}
        local tonic = (i-key_root) % 12
        
        -- weight by tonic
        if tonic_weights[tonic] then
            score = tonic_weights[tonic]
        else
            score = default_tonic_score
        end
        
        chord.root = canonical_note_name(i)
        
        -- now check the notes
        for name,chord_form in pairs(common_chords) do
            local penalty = 0
            -- count the out of key notes
           
            for k,note in ipairs(chord_form) do
                local semi = (i+note) % 12
                if not in_key[semi] then
                    penalty = penalty + 1
                end
            end
            penalty = math.pow(10, -penalty) * score 
            -- store the chord table
            in_key_chords[canonical_note_name(i)..name] = penalty
        end
    end
    return in_key_chords
end


function score_bar_chords(notes, key_scores, jazz)
    -- Take a bar full of notes, and work out new scores
    local in_bar = {}
    local chords = {}
    local key_weight = 1 -- how much influence the key has
    -- get semitones in this bar
    for i,v in ipairs(notes) do
        if v.play_pitch then 
            if i==1 then
                -- upweight first note in bar
                in_bar[v.play_pitch % 12] = 60
            else
                in_bar[v.play_pitch % 12] = (in_bar[v.play_pitch]  or 10) + 5
            end
        end
    end
    
    -- for each chord root and type
    for i=0,11 do
        for name,chord_form in pairs(common_chords) do
            local score = 1e-8
            -- score by notes in bar        
            for k,note in ipairs(chord_form) do
                local semi = (i+note) % 12
                if in_bar[semi] then
                    -- increase score for every in bar note
                    score = score + in_bar[semi] 
                end
            end
            
             -- weight by the key scoring
             local chord_name = canonical_note_name(i)..name
             score = (score *  (key_weight*key_scores[canonical_note_name(i)..name])) * math.pow(chord_weights[name],jazz)
            
             table.insert(chords, {root=canonical_note_name(i), chord_type=name, score=score})
        end
    end
    table.sort(chords, function(a,b) return (a.score>b.score) end)
  
    return chords
end


function random_select(t)
    -- select an element from t
    -- renormalising the scores to form a pdf
    -- then selecting randomly from that pdf
    local sum = 0
    for i,v in ipairs(t) do
        sum = sum + v.score
    end
    local r = math.random()
    local cum = 0
    
    for i,v in ipairs(t) do
        cum = cum + v.score/sum
        if r<cum then
            return v
        end
    end
    return nil -- shouldn't happen!
end


function bar_end(out, bar, notes, key_scores, jazz)
    -- insert all of the events in this bar
    local ranked = score_bar_chords(notes, key_scores, jazz)
    local top = random_select(ranked) 
    table.insert(out, {token='chord', chord={root=top.root, chord_type=top.chord_type}})
    for i,v in ipairs(bar) do
        table.insert(out, v)
    end
end

function auto_chord(tokens, jazz)
    -- find automatic fitting chords, given the key and the notes in a bar
    local current_key
    local key_scores 
    local out = {}
    local bar_notes = {}
    local bar = {}    
    local in_header = true     
    if jazz=='jazz' then
        jazz = -1 -- favour complex chords
    else
        jazz = 4 -- favour simple chords
    end
    precompile_token_stream(tokens) -- get semitones for all notes
    for i,token in ipairs(tokens) do
        if not in_header then
            if token.token~='chord' then
                if token.token=='note' then
                    token.note.chord = nil -- clear exisiting chords
                end
                table.insert(bar, token)
          
            end
        else
            -- pass header through unchanged
            table.insert(out, token)
        end
        -- track key changes
        if token.token=='key' then 
            current_key = token.key 
            key_scores = score_chords(current_key)
            in_header = false
        end
        
        -- track notes
        if token.token=='note' then 
            table.insert(bar_notes, token.note)
        end
        
        -- end of bar found
        if token.token=='bar' then 
            -- copy out the events
            bar_end(out, bar, bar_notes, key_scores, jazz)     
            -- clear the bar buffer
            bar_notes = {}
            bar = {}
        end        
    end
    
    -- must keep any trailing notes
    bar_end(out, bar, bar_notes, key_scores, jazz)
    
    return out    
end

function auto_chords(fname, jazz)
    local songs = parse_abc_file(fname)       
    -- transpose each song
    for i, song in ipairs(songs) do
        print(emit_abc(auto_chord(song.token_stream, jazz)))
    end            
end

if #arg<1 or #arg>2 then
    print("Usage: auto_chords.lua <file.abc> [jazz]")    
else
    auto_chords(arg[1], arg[2])
end
