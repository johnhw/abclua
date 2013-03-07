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
    -- LZW compresss a sequence of (primitive) values. Every value
    -- must be transformable into a unique string.
    local pattern = ''..sequence[1]
    local lzw_table = {}
    local output = {}
    
    -- this had better never appear in the input sequence!
    local token = 320000
    
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
    for i,v in pairs(hist) do
        sum = sum + v
    end    
    
    -- compute entropy
    local h = 0
    local p
    for i,v in pairs(hist) do
        p = v / sum        
        h = h - p * math.log(p)/math.log(2)
    end
    
    return h 
end



function compute_speed_difficulty(melody, rhythm, pitches, durations)
    -- compute difficulty based on change in pitch over duration
    -- (i.e. time derivative of interval), and the simple speed of the song
    local pitch_rate = 0
    local rate = 0
    for i,v in ipairs(melody) do
        pitch_rate = pitch_rate + math.abs(melody[i]/durations[i])
        rate = rate + 1.0/durations[i]
    end
    return pitch_rate / #melody, rate/#melody
end



function rate_songs(songs)     
    -- rate each song in the last, adding a .ratings field to the song entry
    -- the ratings can subsequently be combined to come up with an "average"
    -- difficulty level for the song
    local meta
    local ratings = {}    
    -- read in the metadata
    for i,song in ipairs(songs) do 
        meta = song.header_metadata 
        if meta and meta.ref then
            melody,rhythm,pitches,durations = code_tune(song.voices['default'].stream)
            
            -- score each of the tune streams
            -- score by: LZW compression ratio (for pitch, interval, duration and duration interval)
            -- symbol entropy (for pitch, interval, duration and duration interval)
            -- speed rating (derivative of interval)
            
            local h_melody = compute_entropy(melody)
            local lzw_melody = compute_lzw_entropy(melody)
            
            local h_pitches = compute_entropy(pitches)
            local lzw_pitches = compute_lzw_entropy(pitches)
            
            local h_rhythm = compute_entropy(rhythm)
            local lzw_rhythm = compute_lzw_entropy(rhythm)
            
            local h_durations = compute_entropy(durations)
            local lzw_durations = compute_lzw_entropy(durations)
            
            local interval_rate, rate = compute_speed_difficulty(melody, rhythm, pitches, durations)
           
            
            local rating = {
            h_melody = h_melody,
            h_pitches = h_pitches,
            h_rhythm = h_rhythm,
            h_durations = h_durations,
            rate = rate,
            lzw_melody = lzw_melody,
            lzw_pitches = lzw_pitches,
            lzw_rhythm = lzw_rhythm,
            lzw_durations = lzw_durations,
            rate = rate,             
            interval_rate = interval_rate,
            score=score, repetition=1/lzw_melody}
            
            song.rating = rating                        
        end
    end
end




function rank_by_difficulty(songs, score_combiner)
    -- sort songs by difficulty, given a function to combine the various weighting scores
    local ranks = {}
    for i,v in ipairs(songs) do
        if v.rating then
            v.score = score_combiner(v.rating)
            table.insert(ranks, v)
        end
    end    
    table.sort(ranks, function(a,b) return a.score<b.score end)
        
    for i,v in ipairs(ranks) do
        title = v.metadata.title[1]
        print(title .. string.rep(' ',64-string.len(title))..v.score)
    end
    return ranks
end

if #arg~=1 then
    print("Usage: tune_difficulty <file.abc>")
else
    local songs = parse_abc_file(arg[1])
    rate_songs(songs) 
    rank_by_difficulty(songs, function(ratings) return  5*ratings.rate + ratings.lzw_melody*ratings.h_melody*5 end)
end