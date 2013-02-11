-- Functions from transforming an raw stream into a timed event stream

function time_stream(stream)
    -- take a stream of events and insert time indicators (in microseconds)
    -- as the t field in each event
    -- Time advances only on notes or rests
    
    local t 
    local in_chord = false
    local max_duration 
    
    t = 0
    
    
    for i,event in ipairs(stream) do        
        event.t = t
        
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
        end
        
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
           table.insert(notes, event.note.note_def.pitch.note)
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
           table.insert(notes, event.syllable)
        end
    
        if event.event == 'note' then                      
           table.insert(notes, event.note.note_def.pitch.note)
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

function note_stream_to_opus(note_stream)
    -- make sure events are in time order
    table.sort(note_stream, function(a,b) return a.t<b.t end)
    
    local last_t = 0
    score = {}
    local dtime
    for i,event in ipairs(note_stream) do
        dtime = (event.t - last_t)/1000.0 -- microseconds to milliseconds
        table.insert(score, {event.event, dtime, event.channel, event.pitch, 100})
        last_t = event.t
    end
    return score
end

function stream_to_opus(stream, channel, patch)
    -- return the opus form of a single note stream song, with millisecond timing    
    channel = channel or 1
    patch = patch or 41 -- default to violin
    
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
        },          
    }    
    -- set the patch for each channel
    for i=1,#song.voices do
        if patches[i] then
            table.insert(score[2], 'patch_change', 0, i, patches[i])
        else
            table.insert(score[2], 'patch_change', 0, i, 41)
        end
    end
    
    -- merge in each voice
    for i,v in pairs(song.voices) do
        channel = channel + 1        
        append_table(merged_stream, get_note_stream(v.stream, channel))         
    end
        
   append_table(score[2], note_stream_to_opus(merged_stream))
   return score
end


function make_midi_from_stream(stream, fname)
    -- Turn a note stream into a MIDI file
     local MIDI = require 'MIDI'

     opus = stream_to_opus(stream)
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

