-- Takes an ABC tune, and returns it's "DNA" -- an encoding of the 
-- relative melody/rhythm that can subsequently be quickly matched

require "abclua"

function dna_tune(melody, rhythm)
    -- compute the DNA of a stream
    local mdna, rdna = {}, {}
    local big_step = 4
    
    for i,v in ipairs(melody) do
        if v==0 then table.insert(mdna, '-') end
        if v>0 and v<big_step then table.insert(mdna, '^') end
        if v>=big_step then table.insert(mdna, '`') end
        if v<0 and -v<big_step then table.insert(mdna, ',') end
        if v<=-big_step then table.insert(mdna, '_') end         
    end
    
    big_step = 3
    for i,v in ipairs(rhythm) do
        if v==1 then table.insert(rdna, '|') end
        if v>1 and v<big_step then table.insert(rdna, '+') end
        if v>=big_step then table.insert(rdna, '_') end
        if v<-1 and -v<big_step then table.insert(rdna, '.') end
        if v<=-big_step then table.insert(rdna, ':') end         
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


function add_ngrams(ngrams, id, sequence, n)
    local ngram
    for i=1,string.len(sequence)-n do
        ngram = string.sub(sequence, i, i+n)
        ngrams[ngram] = ngrams[ngram] or {}
        ngrams[ngram][id] = id 
    end
end

-- local songs = parse_abc_file("skye.abc")    
-- for i, song in ipairs(songs) do
    -- print(song.metadata.title[1])
    
    -- melody_ngrams = {}
    -- for j,voice in pairs(song.voices) do 
        -- m,r = code_tune(voice.stream)
        -- melody, rhythm = dna_tune(m,r)
    -- end
    -- print(melody)
    -- print(rhythm)
-- end

