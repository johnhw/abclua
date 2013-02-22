-- Functions from transforming an raw stream into a timed event stream

function time_stream(stream)
    -- take a stream of events and insert time indicators (in microseconds)
    -- as the t field in each event
    -- Time advances only on notes or rests
    
    local t 
    local in_chord = false
    local max_duration 
    local measure = 1
    local written_measure = 1
    t = 0    
    local last_bar = 0
    local bar_time
    
    for i,event in ipairs(stream) do        
        event.t = t
        
        -- record position of last bar
        if event.event=='bar' and event.bar.type~='variant' then
            last_bar = event.t
            measure = measure + 1
            written_measure = event.bar.meeasure
        end
        
        
        -- now, if we get an overlay, jump time
        -- back to the start of that bar
        if event.event=='overlay' then
            t = last_bar
        end
        
        -- rests and notes
        if event.event=='rest' or event.event=='note' then
            if not in_chord then
                t = t + event.duration
            else
                -- record maximum time in chord; this is how much we will advance by
                if event.duration > max_duration then
                    max_duration = event.duration
                end
            end            
            bar_time = event.bar_time
        end
        
        -- record bar/bar-relative timing
        event.measure = {play_measure = measure, written_measure=measure, bar_time=bar_time}        
        
        -- chord symbols
       
        -- chord starts; stop advancing time
        if event.event=='chord_begin' then
            in_chord = true
            max_duration = 0
        end
        
        if event.event=='chord_end' then
            in_chord = false
            t = t + max_duration -- advance by longest note in chord
        end
       
       
    end
    
    -- make sure events are in order
    --table.sort(stream, function(a,b) return a.t<b.t end)
    
end

function get_note_stream(timed_stream, channel)
    -- Extract all play events from a timed stream, as sequence of note on / note off events
    -- take into account ties in computing note offs
    
   local out = {}
   local notes_on = {}
   
   local channel = channel or 1
   for i,event in ipairs(timed_stream) do        
            if event.event=='note' then                
                if not notes_on[event.pitch] then 
                    table.insert(out, {event='note_on', t=event.t, pitch=event.pitch, channel=channel})
                    notes_on[event.pitch] = true
                end
                
                -- don't insert a note off if the note is tied
                if not event.note.tie then                    
                    table.insert(out, {event='note_off', t=event.t+event.duration-1, pitch=event.pitch, channel=channel})                                    
                    notes_on[event.pitch] = false
                end          
            end
    end
    return out
end


function print_notes(stream)
    -- print out the notes, as a sequence of pitches
    local notes = {}
    
    for i,event in ipairs(stream) do        
        if event.event == 'note' then                      
           table.insert(notes, event.note.pitch.note)
        end
        if event.event == 'rest' then
            table.insert(notes, '~')
        end
        if event.event == 'bar' then
            table.insert(notes, '|')
        end
        if event.event == 'split_line' then
            table.insert(notes, '\n')
        end
    end
    
    print(table.concat(notes))
    
end




function print_lyrics_notes(stream)
    -- print out the notes and lyrics, as a sequence of pitches interleaved with 
    -- syllables
    local notes = {}
    
    for i,event in ipairs(stream) do        
    
        if event.event == 'lyric' then                      
           table.insert(notes, ' "'..event.syllable..'" ')
        end
    
        if event.event == 'note' then                      
           table.insert(notes, event.note.pitch.note)
        end
        if event.event == 'rest' then
            table.insert(notes, '~')
        end
        if event.event == 'bar' then
            table.insert(notes, '|')
        end
        if event.event == 'split_line' then
            table.insert(notes, '\n')
        end
    end
    
    print(table.concat(notes))
    
end



function filter_event_stream(stream, includes)
    -- return a copy of the stream, keeping only those specified events in the stream
    local filtered = {}
    
    if #stream=={} then
        return {}
    end
    
    if type(includes)=='string' then        
        for i,v in ipairs(stream) do
            if v.event==includes then
                table.insert(filtered, v)            
            end
        end       
    end
    
    if type(includes)=='table' then        
        for i,v in ipairs(stream) do
            for j,n in ipairs(includes) do 
                if v.event==n then
                table.insert(filtered, v)            
                end
            end
        end       
    end    
    return filtered   
end

function duration_stream(stream)
    -- return the duration of the stream, from the first event, to
    -- the end of the last note
    if #stream==0 then
        return 0
    end
    
    local end_time = stream[-1].t
    -- must add on duration to avoid chopping last note
    if stream[-1].duration then
        end_time = end_time + stream[-1].duration
    end
    return end_time
end

function start_time_stream(stream)
    -- return the time of the first event
    if #stream==0 then
        return 0
    end    
    return stream[1].t
end

function zero_time_stream(stream)
    -- fix the time of the first element of the stream to t=0, and shift
    -- the rest of the stream to match
    -- Modifies the stream in place -- copy it if you don't want to modify the 
    -- original data
    if #stream=={} then
        return {}
    end
    
    local t = stream[1].t
    for i,v in ipairs(stream) do
        stream.t = stream.t - t
    end    
end




function render_grace_notes(stream)
    -- Return a the stream with grace notes rendered in 
    -- as ordinary notes. These notes will cut into the following note 
    local out = {}
    for i,v in ipairs(stream) do
        if v.event=='note' and v.note.grace then        
            local sequence = v.note.grace.sequence            
            local duration = 0 -- total duration of the grace notes
            for j,n in ipairs(sequence) do                    
                table.insert(out, {event='note', t=duration+v.t, duration=n.duration, pitch=n.pitch, note=n.grace})
                duration = duration + n.duration
            end            
            
            -- cut into the time of the next note, and push it along
            local cut_note = v
            cut_note.duration = cut_note.duration - duration
            
            -- if we manage to cut the note completely then make sure
            -- it doesn't have negative duration
            if cut_note.duration <= 0 then                
                cut_note.duration = 1                
            end
            cut_note.t = cut_note.t + duration
            table.insert(out, cut_note) 
        else
            table.insert(out, v)
        end
    end    
    return out
end


function trim_event_stream(stream,  mode, start_time, end_time)
    -- return a copy of the stream, including only events that fall inside
    -- [start_time:end_time] (given in microseconds)
    -- mode can be = 'starts' which returns event that start in the given period
    --               'ends' which returns events that end in the given period
    --               'any' which returns events that overlap the period at all
    --               'within' which returns that are wholly in the period
    --               'trim' which is like any, but trims notes to fit the given time
    -- start_time and end_time are optional (default to start and end of the tune)   
    
    if #stream=={} then
        return {}
    end
    
    local filtered = {}
    start_time = start_time or nil
    end_time = end_time or duration_stream(stream)         
    
    
    for i,v in ipairs(stream) do
        local start_t = v.t
        local end_t = v.t
        
        -- notes and rests occupy time
        if v.event == 'note' or v.event=='rest' then
            end_t = v.t + v.duration
        end
        
        -- work out if this event starts or stops in this interval
        local start_in = (start_t>=start_time and  start_t<=end_time) 
        local end_in = (end_t>=start_time and end_t<=end_time)
        
        if mode=='any' then
            if start_in or end_in  then
                table.insert(filtered, v)
            end
        end
        
        if mode=='starts' then
            if start_in then
                table.insert(filtered, v)
            end
        end
        
        if mode=='ends' then
            if end_in then
                table.insert(filtered, v)
            end
        end
        
        if mode=='within' then
            if start_in and end_in then
                table.insert(filtered, v)
            end
        end
        
        if mode == 'trim' then
             if start_in or end_in  then
                -- must copy event to avoid changing the original
                local event = deepcopy(v)
                
                -- starts, but is too long
                if start_in and not end_in then
                    event.duration = end_time - event.t
                end
                
                -- starts before, but ends in
                if end_in and not start_in then
                    event.duration = (event.t+event.duration)-start_time
                    event.t = start_time                    
                end
                table.insert(filtered, event)
             end
        end
        
    end
    
    return filtered
end
    

function transpose_stream(stream, semitones)
    -- Transpose events in the stream (only changes the numerical pitch field
    -- see diatonic_transpose() to transpose a token stream with note renaming etc.)
    for i,v in ipairs(stream) do
        if v.event=='note' then 
            v.pitch = v.pitch + semitones
        end
    end    
end
    
    

function time_stretch_stream(stream, factor)
    -- Change the playback rate of the stream (only changes the numerical duration field)
    -- and then retimes
    for i,v in ipairs(stream) do    
        if v.event.duration  then 
            v.duration = v.duration * factor
        end
    end    
    time_stream(stream)
end

function note_stream_to_opus(note_stream)
    -- make sure events are in time order
    table.sort(note_stream, function(a,b) return a.t<b.t end)
    
    local last_t = 0
    local score = {}    
    local dtime
    for i,event in ipairs(note_stream) do
        dtime = (event.t - last_t)/1000.0 -- microseconds to milliseconds
        table.insert(score, {event.event, dtime, event.channel or 1, event.pitch, event.velocity or 127})
        last_t = event.t
    end
    return score
end



function get_chord_stream(stream, octave)
    -- extract all the named chords from a stream (e.g. "Cm7" or "Dmaj") and write 
    -- them in as note events in a stream
   local out = {}
   local notes_on = {}
   local t
   local channel = channel or 1
   octave = octave or 5
   local notes
   
   for i,event in ipairs(stream) do        
        
        if (event.event=='note' and event.note.chord) or event.event=='chord' then                
            local chord = event.note.chord or event.chord
            
            t = event.t
            -- turn off last chord!
            for j, n in ipairs(notes_on) do
                table.insert(out, {event='note_off', t=t, channel})                                           
                notes_on = {}
            end
            
            -- get the notes for this chord and put them in the sequence
            notes = voice_chord(chord.notes, octave)
            for j, n in ipairs(notes) do
                 table.insert(out, {event='note_on', t=t, pitch=n, channel})                           
                 notes_on[n] = true
            end                    
        end
    end
    
    -- turn off last chord
    for j, n in ipairs(notes_on) do
            table.insert(out, {event='note_off', t=t, channel=channel})                                           
            notes_on = {}
    end            
    
    return out 
end


function merge_streams(streams)
    -- merge a list of streams into one single, ordered stream
    local merged_stream = {}
    
    for i,v in pairs(streams) do
        append_table(merged_stream, v)         
    end    
    table.sort(merged_stream, function(a,b) return a.t<b.t end)
    return merged_stream    
end

-- sort out stream functions

function stream_to_opus(stream,  patch)
    -- return the opus form of a single note stream song, with millisecond timing        
    patch = patch or 41 -- default to violin
    local channel = 0
    local note_stream = get_note_stream(stream, channel)
    
     local score = {
        1000,  -- ticks per beat
        {    -- first track
            {'set_tempo', 0, 1000000},
            {'patch_change', 0, channel, patch},            
        },  
     }     
    append_table(score[2], note_stream_to_opus(note_stream))
    return score  
end


function song_to_opus(song, patches)
    -- return the opus form of all the voices song, with millisecond timing
    -- one channel per voice
    
    
    patches = patches or {}
    local channel = 0    
    local merged_stream = {}
    local score = {1000,
        {    
            {'set_tempo', 0, 1000000},     
           {'patch_change', 0,1,1},     
             
        },          
    }    
    -- set the patch for each channel
    local j = 0
    for i,v in pairs(song.voices) do
        if patches[i] then
            table.insert(score[2], {'patch_change', 0, i, patches[i]})
        else
            table.insert(score[2], {'patch_change', 0, j, 1})
        end
        j = j + 1
    end
    
    
    -- merge in each voice
    for i,v in pairs(song.voices) do        
        append_table(merged_stream, get_note_stream(v.stream, channel))         
        channel = channel + 1        
    end
        
   append_table(score[2], note_stream_to_opus(merged_stream))
   
 
   return score
end


function make_midi_from_stream(stream, fname)
    -- Turn a note stream into a MIDI file
     local MIDI = require 'MIDI'

     local opus = stream_to_opus(stream)
     local midifile = assert(io.open(fname,'wb'))
     midifile:write(MIDI.opus2midi(opus))
     midifile:close()
end

function make_midi(song, fname)
    -- make a midi file from a song
    -- merge all of the voices into a single event stream
    local MIDI = require 'MIDI'
    local opus = song_to_opus(song)
    
    local midifile = assert(io.open(fname,'wb'))
    midifile:write(MIDI.opus2midi(opus))
    midifile:close()    
end

