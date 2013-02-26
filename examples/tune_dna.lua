-- Takes an ABC tune, and returns it's "DNA" -- an encoding of the 
-- relative melody/rhythm that can subsequently be quickly matched
-- Needs the bitop library http://bitop.luajit.org/api.html
require "abclua"
require "bit"

function dna_tune(melody)
    -- compute the DNA of a melody table. Replaces each symbol with either
    -- = if the note is the same as the previous
    -- ^ if it is higher
    -- _ if it is lower
    local mdna = {}
    for i,v in ipairs(melody) do
        if v==0 then table.insert(mdna, '=') end
        if v>0 then table.insert(mdna, '^') end
        if v<0 then table.insert(mdna, '_') end         
    end       
    return table.concat(mdna)
end

function code_tune(stream)
    -- Compute the "code" of a compiled event stream. Computes relative changes in pitch
    -- and relative shifts in duration, and return two tables, melody and rhythm. Melody
    -- contains relative pitch shifts in semitones; rhythm contains ratios between each duration
    -- where ratios < 1 have been replaced with -1/ratio (e.g 0.5 becomes -2).
    local note, step, dur, new_dur, rat
    local melody, rhythm = {}, {}
 
    for i,v in ipairs(stream) do
        if v.event=='note' then
            new_note = v.note.play_pitch 
            new_dur = v.note.play_notes
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


    
function pop_count(v)
    -- return the population count of the bit-vector c
    local band = bit.band
    local shr = bit.rshift
    
    c = (band(v,0x55555555)) + band(shr(v,1), 0x55555555)
    c = (band(c,0x33333333)) + band(shr(c,2), 0x33333333)
    c = (band(c,0x0F0F0F0F)) + band(shr(c,4), 0x0F0F0F0F)
    c = (band(c,0x00FF00FF)) + band(shr(c,8), 0x00FF00FF)
    c = (band(c,0x0000FFFF)) + band(shr(c,16), 0x0000FFFF)
    return c
end

function match_ngrams(ngrams, ngram, scores, mask)
    -- take an ngram, and match it against a list of ngrams
    -- scoring each id according to how closely it matches.
    -- Mask specifies a bit mask to be applied after comparison.
    -- E.g.0xffffff00 ignores the last 4 bits of info. 
    -- A mask of 0x3 just compares the first element, etc.
    local v, c
    local xor = bit.bxor
    local band = bit.band
    local shr = bit.rshift
    mask = mask or 0xffffffff
    scores = scores or {}
    
    -- compute maximum number of on bits
    local max_score = pop_count(band(0xfffffff, mask))
    for i,ids in pairs(ngrams) do
        -- compare strings
        v = band(mask, xor(i, ngram))
        c = pop_count(v)
        
        -- add mismatch score to each id associated with this ngram
        for j,id in pairs(ids) do
            scores[id] = (scores[id] or 0) + math.pow(2,max_score-c)
        end
    end
    return scores
end



function get_ngrams(sequence, with_masks)
    -- convert a string into a set of 16-grams, where
    -- each field is a 2 bit integer encoding a variable with 3 values
    -- which can be compared very quickly. If with_masks is true,
    -- includes all n-grams (including incomplete ones) and returns a mask
    -- table which indicates the bits of the words to compare for the corresponding ngram
    -- e.g. 0x3 for an ngram with only the first element present
    local ngrams = {}
    local masks = {}
    local ngram = 0
    local v
    local ct = 1
    local mask = 0
    for i in sequence:gmatch(".") do
        ngram = bit.lshift(ngram, 2)
        mask = bit.bor(bit.lshift(mask,2), 0x3) -- set bottom two bits and shift left
        -- encode the symbol
        if i=='=' then v=1 end
        if i=='^'  then v=3 end
        if i=='_'  then v=0 end
        ngram = bit.bor(ngram, v)
        if ct>15 or with_masks then
            table.insert(ngrams, ngram)
            table.insert(masks, mask)
        end
        ct = ct + 1
    end
    
    -- add in "end" left overs
    if with_masks then
        for i=1,8 do 
             ngram = bit.lshift(ngram, 2)
             mask = bit.lshift(mask,2)
             table.insert(ngrams, ngram)
             table.insert(masks, mask)
        end
    end
    
    return ngrams, masks
end
   
   
function match_sequence(ngrams, id_counts, sequence)
    -- Taking a list of ngrams->id mappings, the number of ngrams for each
    -- id, and a sequence to match, returns a ranked list of matching ids.
    
   local scores = {}
   
   -- get every ngram in the sequence (including partial ones), along
   -- with the mask for comparison
   local matchers, masks = get_ngrams(sequence, true)
   
   -- match each ngram
   for i,v in ipairs(matchers) do
       match_ngrams(ngrams, v, scores, masks[i])
   end
   
   -- insert the scores
   local score_table = {}
   for id,score in pairs(scores) do
        table.insert(score_table, {id=id, score=score/id_counts[id]})
   end
   
   -- sort, highest score first
   table.sort(score_table, function(a,b) return (a.score>b.score) end)
   return score_table
end


function add_ngrams(ngrams, ngram_count, id, sequence)
    -- associate all ngrams in sequences with id, updating <ngrams>, and setting
    -- the ngram count for the given id in <ngram_count>
    -- get the ngrams (don't use masks -- we only want whole ngrams)
    local ngram_set = get_ngrams(sequence)
    for i,v in ipairs(ngram_set) do
        ngrams[v] = ngrams[v] or {}
        ngrams[v][id] = id   
    end
    ngram_count[id] = #ngram_set
end

-- test code
local songs = parse_abc_file("tests/p_hardy.abc")    
local melody_ngrams = {}
local melody_ngram_count = {}

for i, song in ipairs(songs) do
    if song.metadata.title then
        for j,voice in pairs(song.voices) do 
            m,r = code_tune(voice.stream)
            melody  = dna_tune(m)
            add_ngrams(melody_ngrams, melody_ngram_count, song.metadata.ref[1], melody)
        end
    end
end


misses = 0
for i, song in ipairs(songs) do
    if song.metadata.title then
        for j,voice in pairs(song.voices) do 
            m,r = code_tune(voice.stream)
            melody = dna_tune(m)            
            scores = match_sequence(melody_ngrams, melody_ngram_count, string.sub(melody,2,15))
            if scores and scores[1] and song.metadata.ref then
                print(song.metadata.ref[1], scores[1].id, scores[2].id,  scores[3].id)
                if song.metadata.ref[1] ~= scores[1].id then
                    misses = misses + 1
                end
            end
        end
    end
end
    
print(misses/#songs)
