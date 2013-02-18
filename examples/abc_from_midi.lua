-- Generates an ABC file from a (simple) MIDI file
require "abclua"
local MIDI = require "MIDI"
require "src/utils"

function octaved_count(tab, t)
    -- count instance of t scaled by various factors
    -- This is like the harmonic product spectrum algorithm for pitch tracking
    local scalings = {1.25, 1.75, 1.5, 1, 2, 3, 2*1.75, 4, 8, 16}
    local tv
    for i,v in ipairs(scalings) do
        tv = t * v
        tab[tv] = (tab[tv] or 0) + 1
        tv = t / v
        tab[tv] = (tab[tv] or 0) + 1
    end
end
    
    
function guess_tempo(events)
    -- Guess the tempo of the event stream in BPM
    -- Returns the BPM, and the most likely note length
     local last_t = 0
     local intervals = {}
     
     for i,v in ipairs(events[2]) do 
        -- record time since last note    
        if v[1]=='note' then
            octaved_count(intervals, v[2]-last_t)        
            last_t = v[2]
        end
     end
     
     -- create table of (tempo, count) pairs
     local ordered_intervals = {}
     for i,v in pairs(intervals) do
        table.insert(ordered_intervals, {i,v})
     end
     
     -- sort the histogram
     table.sort(ordered_intervals, function(a,b) return a[2]>b[2] end)
     
     -- compute estimated BPM
     local tempo = 60e3 / ordered_intervals[1][1]
     local note_length = 1
     
     -- Force BPM into [60, 240]
     while tempo<60 do
        tempo = tempo * 2
        note_length = note_length / 2
     end
     
     while tempo>240 do        
        tempo = tempo / 2
        note_length = note_length * 2
     end
     
    return tempo, note_length
end

local note_semis = 
{
    [0]='c',
    [1]='cs',
    [2]='d',
    [3]='eb',
    [4]='e',
    [5]='f',
    [6]='fs',
    [7]='g',
    [8]='ab',
    [9]='a',
    [10]='bb',
    [11]='b'
}

function guess_key(events)
    -- Guess the key of a MIDI event stream (as a score)
    -- Only guesses the major key -- does not distingush
    -- relative minor keys or modes
    
    local note_histogram = {}
    
    -- construct a histogram of semitone occurence
    local last_note
    for i,v in ipairs(events[2]) do 
        if i~=1 and v[1]=='note' then
            local note = v[5] % 12
            note_histogram[note] = (note_histogram[note] or 0) + 1
            last_note = note
        end

    end 
    
    local last_semi = note_semis[last_note]
    
    -- get all the possible keys
    local major_keys = get_major_keys()
    
    -- score each key by how well it matches
    local scores = {}
    local key_scores = {}
    for i,v in pairs(major_keys) do
        local score = 0
        local k = invert_table(v)
        for j,n in pairs(note_histogram) do
            -- if this key has this note, increase score by the count seen
            if k[j] then
                score = score + n    
            end
        end
        key_scores[i] = score
        table.insert(scores, {i, score})
    end
    
    -- find maximum score
    table.sort(scores, function(a,b) return a[2]>b[2] end)

    local key_guess 
    
    -- if last note is tied for best match, choose that
    if key_scores[last_semi]==scores[1][2] then
        key_guess = last_semi
    else
        -- otherwise choose the most likely key
        key_guess = scores[1][1]
    end
    
    return key_guess
end


function get_duration_fraction(duration, base_length)
    -- given a duration (in ms) and a base note length (also in ms)
    -- return the duration fraction for this note    
     local ticks
     local subdiv = 32*3 -- minimum note length is 32nd triplets
     local frac, num, den
     
    -- round to nearest subdivision and simplify
    ticks = math.floor(0.5+subdiv * (duration/base_length))
    frac = gcd(ticks, subdiv)
    return ticks/frac, subdiv/frac
end

function score_bar_guess(durations, length)
    -- return a penalty score representing how many times a bar
    -- cut into a note (i.e. it would have to be written with
    -- a tie over the bar). Higher numbers represent a less
    -- likely fit
    
   local bar_position = 0
   local score = 0
   for i,v in ipairs(durations) do
        bar_position = bar_position + v
        
        
        if bar_position>=length then 
            bar_position = bar_position - length
            
            -- we had to break inside a note or rest
            if bar_position>0 then                                
                score = score + 1            
            end
            --bar_position = 0
        end
   end   
   
   return score
   
end

function guess_bar_length(events, base_length)
    -- Given a note sequence, guess how long the measures are
    -- Return the measure length in units of base_length
    local t = 0
    local duration
    local durations = {}
        
    for i,v in ipairs(events) do
        -- find length of each note in the sequences
        if v[1]=='note' then            
            -- if t ~= v[2]  then
                -- need to add a rest               
                -- num, den = get_duration_fraction(v[2]-t, base_length)                
                -- table.insert(durations, num/den)
            -- end           
            -- get length of this note            
            num, den = get_duration_fraction(v[3], base_length)
            table.insert(durations, num/den)
            t = v[2]
        end
    end
    
    
    local bar_lengths = {2,3,4,5,6,7}
    local multipliers = {1,2,4,8}
    
    local scores = {}
    for ii,i in ipairs(bar_lengths) do
        for jj,j in ipairs(multipliers) do
            table.insert(scores, {bar=i, multiplier=j, length=i*j, score=score_bar_guess(durations, i*j)})
        end       
    end
    
    table.sort(scores, function(a,b) return a.score<b.score end)
    table_print(scores)
    
     
end

function note_from_midi_note(note, key)
    -- return the root note, octave and accidentals of a MIDI note
    -- when in a given (major) key
    
    local semi, octave, note_table
    local key_semis = invert_table(get_major_key(key))
    
    -- offset the note by the base of the key
    note = note - get_note_number(key)
    semi = note % 12
     
    -- work out the octave
    octave = ((note-semi)-48) / 12
    if key_semis[semi] then
       note_table = {note=string.upper(nth_note_of_key(key, key_semis[semi]-1)), octave=octave}
    else
        -- we always flatten
       note_table = {accidental=-1, note=string.upper(nth_note_of_key(key, key_semis[semi])), octave=octave}
    end
    return note_table
end




function abc_from_midi(filename)
     local midifile = assert(io.open(filename,'rb'))
     local midi = MIDI.opus2score(MIDI.to_millisecs(MIDI.midi2opus(midifile:read('*a'))))
     midifile:close()
     
     
     
     local events = MIDI.grep(midi, {0})
     local mixed = {}
     for i,v in ipairs(events) do
        if i~=1 then 
            for j,n in ipairs(v) do
                table.insert(mixed, n)
            end
        end
     end
     
     events = {1000, mixed}
     -- guess key and tempo
     local tempo, note_length = guess_tempo(events)
     local key = guess_key(events)
    
     
    
     local tokens = {}
     
     -- write in the header
     table.insert(tokens, {token='field_text', name='ref', content='1'})
     table.insert(tokens, {token='note_length',  note_length=note_length})
     table.insert(tokens, {token='tempo',  tempo={[1]={num=1, den=8}, tempo_rate=math.floor(0.5+tempo)}})     
     table.insert(tokens, {token='key',  key={root=key}})
     
     -- work out length of base note (in ms)
     local base_length =  ((60/tempo)/note_length ) * 1000 
     local duration, t, fraction
     local pitch, num, den
     local last_note, last_note_duration
     t = 0
     
     
     
     for i,v in ipairs(events[2]) do
     
        if v[1]=='note' then
            last_note = v
            last_note_duration = v[3]
        end
        
        if last_note then
            if t ~= v[2]  then
                -- need to add a rest; this note doesn't start
                -- where the last one ended
                num, den = get_duration_fraction(v[2]-t, base_length)
                local note = {rest=true,  duration={broken=0, num=num, den=den}}
                table.insert(tokens, {token='note', note=note})
         
            end
            
            -- get length of this note
            duration = v[3]
            num, den = get_duration_fraction(duration, base_length)
            
            -- compute pitch naming
            pitch = note_from_midi_note(v[5], key)
            t = t + duration
            
            local note = {pitch=pitch,  duration={broken=0, num=num, den=den}}
            table.insert(tokens, {token='note', note=note})            
        end
     end
     
     print(token_stream_to_abc(tokens))
     
     
 
end

abc_from_midi('bonidoon.mid')

--  guess bar locations; break every 4 bars
--  guess broken rhythm
