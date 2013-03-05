-- Estimate the difficulty of a tune to play
-- Scores by:
-- Entropy of note distribution / note delta distribution;
-- Entropy of tempo distribution / tempo delta distribution;
-- Average note length;
-- Average pitch delta
-- Instrument specific
--  Finger velocity
--  Playable/hard notes

local abclua = require "abclua"


function code_tune(stream)
    -- Compute the "code" of a compiled event stream. Computes relative changes in pitch
    -- and relative shifts in duration, and return two tables, melody and rhythm. Melody
    -- contains relative pitch shifts in semitones; rhythm contains ratios between each duration
    -- where ratios < 1 have been replaced with -1/ratio (e.g 0.5 becomes -2).
    local note, step, dur, new_dur, rat
    local melody, rhythm = {}, {}
    local pitches, durations = {}, {}
 
    for i,v in ipairs(stream) do
        if v.event=='note' then
            new_note = v.note.play_pitch 
            new_dur = v.note.play_duration/1e6
            table.insert(pitches, v.note.play_pitch)
            table.insert(durations, v.note.play_duration/1e6)
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
    return melody, rhythm, pitches, durations
end


function lzw_compress(sequence)
    -- LZW compresss a sequence of (primitive) values
    local pattern = ''..sequence[1]
    local lzw_table = {}
    local output = {}
    
    -- this had better never appear in the input sequence
    local token = 32000
    
    for i=2,#sequence do
        local k = ''..sequence[i]
        local concat = pattern..k        
        -- if not in the table, emit and add
        if not lzw_table[concat] then
            table.insert(output, lzw_table[pattern] or pattern)
            lzw_table[concat] = token
            -- generate new token
            token = token + 1
            pattern = k
        else
            -- else extend
            pattern = concat
        end            
    end
    table.insert(output, lzw_table[pattern] or pattern)
    return output
end

function compute_lzw_entropy(sequence)
    -- return the relative entropy of a sequence
    -- n_elts(sequence)/n_elts(compressed sequence)
    local lzw = lzw_compress(sequence)
    return #lzw/#sequence
end

function compute_entropy(sequence)
    -- compute the entropy of a sequence. Ignores any
    -- timing information; just computes the entropy of the histogram.
    local hist = {}
    for i,v in ipairs(sequence) do
        hist[v] = (hist[v] or 0) + 1
    end
    
    -- compute normalising sum
    local sum = 0
    for i,v in ipairs(sequence) do
        sum = sum + hist[v]
    end
    
    -- compute entropy
    local h = 0
    local p
    for i,v in ipairs(sequence) do
        p = hist[v] / sum
        h = h - p * math.log(p)/math.log(2)
    end
    
    return h 
end

function compute_speed_difficulty(melody, rhythm, pitches, durations)
    -- compute difficulty based on change in pitch over duration
    -- (i.e. time derivative of interval)
    local pitch_rate = 0
    for i,v in ipairs(melody) do
        pitch_rate = pitch_rate + math.abs(melody[i]/durations[i])
    end
    return pitch_rate / #melody
end

function rate_songbook(fname)
    -- parse the tune
    local songs = parse_abc_file(fname)
    local meta
    local ratings = {}
    -- read in the metadata
    for i,song in ipairs(songs) do 
        meta = song.header_metadata 
        if meta and meta.ref then
            melody,rhythm,pitches,durations = code_tune(song.voices['default'].stream)
            
            -- score each of the tune streams
            local h_melody = compute_entropy(melody)
            local lzw_melody = compute_lzw_entropy(melody)
            
            local h_pitches = compute_entropy(pitches)
            local lzw_pitches = compute_lzw_entropy(pitches)
            
            local h_rhythm = compute_entropy(rhythm)
            local lzw_rhythm = compute_lzw_entropy(rhythm)
            
            local h_durations = compute_entropy(durations)
            local lzw_durations = compute_lzw_entropy(durations)
            
            local rate = compute_speed_difficulty(melody, rhythm, pitches, durations)
            
            -- combine all of the elements into a numerical score
            local score = lzw_melody*rate*(h_melody+h_pitches+h_rhythm+h_durations)/100.0
            
            table.insert(ratings, {title=meta.title[1], score=score})            
        end
    end
    
    table.sort(ratings, function(a,b) return a.score<b.score end)
    for i,v in ipairs(ratings) do
        print(v.title .. string.rep(' ',64-string.len(v.title))..v.score)
    end
end




rate_songbook('tests/p_hardy.abc')