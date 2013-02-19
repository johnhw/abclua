
---------------------------
----- NOTES ---------------
---------------------------

function add_note(midi_state, track, t, duration, channel, pitch, velocity, tied)
    -- add a note/off pair, applying the transpose, and inserting necessary pitch bend commands
    -- for fractional notes
    pitch = pitch+midi_state.transpose        
    
    local real_t, real_duration
    -- distort the time and duration
    real_t = get_distorted_time(t, midi_state)
    real_duration = get_distorted_duration(t, duration, midi_state)
    
    -- get the semitone number and then the temperament adjustment       
    local temperament_detune = 0
    
    -- get the detune / shift from the temperament
    if midi_state.temperament then         
        temperament_detune = midi_state.temperament[pitch].detune
        pitch = midi_state.temperament[pitch].semi
    end
    
    -- insert pitch bends for microtones
    local pitch_offset = (pitch-math.floor(pitch)) + temperament_detune
    
    if math.abs(pitch_offset)>0.0001 then               
        table.insert(track, {'pitch_wheel_change', real_t, channel,  4096*pitch_offset})    
    end
    
    table.insert(track, {'note_on', real_t, channel,  pitch, velocity})
    if not tied and not midi_state.sustain then
        table.insert(track, {'note_off', real_t+real_duration-0.1, channel, pitch, velocity})                
        
        if math.abs(pitch_offset)>0.0001 then       
            table.insert(track, {'pitch_wheel_change', real_t+real_duration-0.05, channel,  0})    
        end
    
    end
    
    -- store sustained notes so we can turn them off later
    if midi_state.sustain then
        midi_state.sustained_notes[pitch] = channel
    end
                
end

function flush_sustained_notes(track, midi_state)
    -- clear any sustained notes playing
   real_t = get_distorted_time(midi_state.t, midi_state)
   for i,v in midi_state.sustained_notes do
        table.insert(track, {'note_off', real_t, v, i, 127})                
   end   
end

function get_tempered_note(pitch, octave, fifth)
    -- return the semitone and detune of a note after being tempered with the given intervals
    -- leaves  middle C unchanged
    
    local offset = pitch - 60 -- difference from middle C
    local octaves = math.floor(offset/12)
    local semis = offset % 12    
    local semi = 0
    local note_cents = 0
        
    -- find note in this octave
    while semi~=semis do
        semi = (semi+7) % 12
        note_cents = (note_cents + fifth) % octave
    end
            
    local total_cents = (octaves*octave) + note_cents
    local semis = math.floor((total_cents/100.0))
    local detune = (total_cents % 100) / 100.0    
    return 60+semis, detune
end

function midi_temperamentlinear(args, midi_state)
    
    -- set a new temperament
    if not check_argument(args[2], 0, 1e6, 'Bad octave in temperament') then return end
    if not check_argument(args[3], 0, 1e6, 'Bad fifth in temperament') then return end
    
    local octave, fifth
    octave = tonumber(args[2])
    fifth = tonumber(args[3])
    
    -- clear the temperament if we switch back
    -- to standard equal temperament
    if octave==1200 and fifth==700 then
        midi_state.temperament = nil
        return
    end
    
    -- get the newly tempered notes
    notes = {}
    for i=0,128 do 
        semi,detune = get_tempered_note(i, octave, fifth)
        notes[i] = {semi=semi, detune=detune}
    end
    
    midi_state.temperament = notes
        
end

function get_accent_velocity(midi_state, duration)
    -- get the velocity and trimming of the current time
    trimming = midi_state.trimming  
    if midi_state.accents.mode=='distort' then
        -- get velocity of this beat before we do any distortion
        velocity = get_distorted_beat_velocity(midi_state)
    end
    -- work out velocity from the accents
    if midi_state.accents.mode=='beat' or not midi_state.accents.stress then
        if midi_state.accents.enabled then
            if midi_state.accents.pattern then
                velocity = get_beat_string_velocity(midi_state)
            else
                velocity = get_beat_velocity(midi_state)
            end
        end
    end    
    
    -- work out trimming and velocity from articulation
    if midi_state.accents.mode=='articulate' then
        local stretch
        velocity, stretch = get_articulated_beat(midi_state, duration)
        trimming = trimming*stretch        
    end
    return velocity, trimming
   
end


function insert_midi_note(event, midi_state)
    -- insert a plain note into the score
    local duration = event.duration/1e3
    local velocity = 127    
    local track = midi_state.current_track
    local trimming 
    midi_state.t = event.t / 1e3
    velocity, trimming = get_accent_velocity(midi_state, duration)
    
    -- render grace notes
    if event.note.grace then
        local sequence = event.note.grace.sequence            
        -- get grace note length
        local note_duration = midi_state.base_note_length / midi_state.grace_divider        
        local t = midi_state.t 
        for j,n in ipairs(sequence) do            
            -- don't include grace notes that run over
            if t+note_duration<midi_state.t+duration then
                add_note(midi_state, track, t, note_duration, midi_state.channel, n.pitch, velocity)
                t = t + note_duration
                duration = duration - note_duration
            end
        end            
        -- adjust duration and timing of following note       
        midi_state.t = t
    end    
    
    add_note(midi_state, track, midi_state.t, duration*trimming, midi_state.channel, event.pitch, velocity, event.tie)    
    midi_state.t = midi_state.t+duration
end
