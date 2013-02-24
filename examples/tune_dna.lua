-- Takes an ABC tune, and returns it's "DNA" -- an encoding of the 
-- relative melody/rhythm that can subsequently be quickly matched

require "abclua"

function dna_tune(melody, rhythm)
    -- compute the DNA of a stream
    local mdna, rdna = {}, {}
    local big_step = 3
    for i,v in ipairs(melody) do
        if v==0 then table.insert(mdna, 's') end
        if v>0 and v<big_step then table.insert(mdna, 'u') end
        if v>=big_step then table.insert(mdna, 'h') end
        if v<0 and -v<big_step then table.insert(mdna, 'd') end
        if v<=-big_step then table.insert(mdna, 'l') end         
    end
    
    big_step = 3
    for i,v in ipairs(rhythm) do
        if v==1 then table.insert(rdna, 's') end
        if v>1 and v<big_step then table.insert(rdna, 'u') end
        if v>=big_step then table.insert(rdna, 'h') end
        if v<-1 and -v<big_step then table.insert(rdna, 'd') end
        if v<=-big_step then table.insert(rdna, 'l') end         
    end
    return table.concat(mdna), table.concat(rdna)
end

function code_tune(stream)
    -- compute the code of a compiled event stream
    local note, step, dur, new_dur, rat
    local melody, rhythm = {}, {}
 
    for i,v in ipairs(stream) do
        if v.event=='note' then
            new_note = v.note.play_pitch 
            new_dur = v.note.play_beats
            if note then
                -- get relative change in pitch/duration
                table.insert(melody, new_note-note)
                rat = (new_dur/dur)
                if rat<1 then rat=-1/rat end
                table.insert(rhythm, rat)
            end
            note = new_note
            dur = new_dur
        end
    end
    return melody, rhythm
end

require "bit"
    
function match_ngrams(ngrams, ngram, scores)
    -- take an ngram, and match it against a list of ngrams
    -- scoring each id according to how closely it matches
    local v, c
    local xor = bit.bxor
    local band = bit.band
    local shr = bit.rshift
    scores = scores or {}
    for i,ids in pairs(ngrams) do
        -- compare strings
        v = xor(i, ngram)
        -- popluation count
        c = (band(v,0x55555555)) + band(shr(v,1), 0x55555555)
        c = (band(c,0x33333333)) + band(shr(c,2), 0x33333333)
        c = (band(c,0x0F0F0F0F)) + band(shr(c,4), 0x0F0F0F0F)
        c = (band(c,0x00FF00FF)) + band(shr(c,8), 0x00FF00FF)
        c = (band(c,0x0000FFFF)) + band(shr(c,16), 0x0000FFFF)
        
        -- add mismatch score to each id associated with this ngram
        for j,id in pairs(ids) do
            scores[id] = (scores[id] or 0) + math.pow(6,14-c)
        end
    end
    return scores
end

function get_ngrams(sequence)
    -- convert a string into a set of 8-grams, where
    -- each field is a 4 bit integer encoding a variable with 5 values
    -- which can be compared very quickly
    local ngrams = {}
    local ngram = 0
    local v
    local ct = 1
    for i in sequence:gmatch(".") do
        ngram = bit.lshift(ngram, 4)
        -- encode the symbol
        if i=='h' then v=15 end
        if i=='u' then v=7 end
        if i=='s' then v=3 end
        if i=='d' then v=1 end
        if i=='l' then v=0 end
        ngram = bit.bor(ngram, v)
        if ct>7 then
            table.insert(ngrams, ngram)
        end
        ct = ct + 1
    end
    
    return ngrams
end


function get_ngrams(sequence)
    -- convert a string into a set of 8-grams, where
    -- each field is a 4 bit integer encoding a variable with 5 values
    -- which can be compared very quickly
    local ngrams = {}
    local ngram = 0
    local v
    local ct = 1
    for i in sequence:gmatch(".") do
        ngram = bit.lshift(ngram, 2)
        -- encode the symbol
        if i=='s' then v=1 end
        if i=='h' or i=='u' then v=3 end
        if i=='d' or i=='l' then v=0 end
        ngram = bit.bor(ngram, v)
        if ct>15 then
            table.insert(ngrams, ngram)
        end
        ct = ct + 1
    end
    
    return ngrams
end
   
   
function match_sequence(ngrams, id_counts, sequence)
   local scores = {}
   
   -- get every ngram in the sequence
   local matchers = get_ngrams(sequence)
   
   -- match each ngram
   for i,v in ipairs(matchers) do
       match_ngrams(ngrams, v, scores)
   end
   
   local score_table = {}
   for id,score in pairs(scores) do
        table.insert(score_table, {id=id, score=score/id_counts[id]})
   end
   
   -- sort, lowest score first
   table.sort(score_table, function(a,b) return (a.score>b.score) end)
   return score_table
end

-- associate all ngrams in sequences with id, updating <ngrams>
function add_ngrams(ngrams, ids, id, sequence)
    local ngram_set = get_ngrams(sequence)
    for i,v in ipairs(ngram_set) do
        ngrams[v] = ngrams[v] or {}
        ngrams[v][id] = id   
    end
    ids[id] = #ngram_set
end

function interleave(melody, rhythm)
    local combined = {}
  
    for i=1,string.len(melody) do
        table.insert(combined, string.sub(melody,i,i+1))
        table.insert(combined, string.sub(rhythm,i,i+1)) 
    end
    return table.concat(combined)
end    

local songs = parse_abc_file("tests/p_hardy.abc")    
local melody_ngrams,rhythm_ngrams = {}, {}
local melody_ids, rhythm_ids = {}, {}

for i, song in ipairs(songs) do
    if song.metadata.title then
        for j,voice in pairs(song.voices) do 
            m,r = code_tune(voice.stream)
            melody, rhythm = dna_tune(m,r)
            add_ngrams(melody_ngrams, melody_ids, song.metadata.ref[1], melody)
            --add_ngrams(rhythm_ngrams, rhythm_ids, song.metadata.ref[1], rhythm)
        end
    end
end


misses = 0
for i, song in ipairs(songs) do
    if song.metadata.title then
        for j,voice in pairs(song.voices) do 
            m,r = code_tune(voice.stream)
            melody, rhythm = dna_tune(m,r)
            
            scores = match_sequence(melody_ngrams, melody_ids, string.sub(melody,2,19))
            if scores and scores[1] and song.metadata.ref then
                print(song.metadata.ref[1], scores[1].id)
                if song.metadata.ref[1] ~= scores[1].id then
                    misses = misses + 1
                end
            end
        end
    end
end
    
print(misses/#songs)
