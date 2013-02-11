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

function make_midi_from_note_stream(note_stream, fname)
    -- Turn a note stream into a MIDI file
     local MIDI = require 'MIDI'

     -- make sure events are in time order
     table.sort(note_stream, function(a,b) return a.t<b.t end)
     
     local score = {
        1000,  -- ticks per beat
        {    -- first track
            {'set_tempo', 0, 1000000},
            {'patch_change', 0, 1, 0},            
        },  
     }
     
    local last_t = 0
    local dtime
    for i,event in ipairs(note_stream) do
        dtime = (event.t - last_t)/1000.0 -- microseconds to milliseconds
        table.insert(score[2], {event.event, dtime, event.channel, event.pitch, 100})
        last_t = event.t
    end
     
     local midifile = assert(io.open(fname,'wb'))
     midifile:write(MIDI.opus2midi(score))
     midifile:close()
end

function make_midi(song, fname)
    -- make a midi file from a song
    -- merge all of the voices into a single event stream
    local channel = 0
    
    local merged_stream = {}
    
    -- merge in each voice
    for i,v in pairs(song.voices) do
        channel = channel + 1        
        append_table(merged_stream, get_note_stream(v.stream, channel)) 
    end
    
    -- this will automatically sort the event order
    make_midi_from_note_stream(merged_stream, fname)
    
end

