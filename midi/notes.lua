
---------------------------
----- NOTES ---------------
---------------------------

function add_note(midi_state, track, t, duration, channel, pitch, velocity, tied)
    
    -- add a note/off pair, applying the transpose, and inserting necessary pitch bend commands
    -- for fractional notes
    pitch = pitch+midi_state.transpose  

    -- fix notes too short to render
    if duration<1 then return end
    
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
   for i,v in pairs(midi_state.sustained_notes) do        
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

function apply_modifier_decorations(midi_state, decorations)
    -- apply state modifiying decorations like !ped! !crescendo!
    local modifiers = {
    ['!ped!'] = function() midi_state.sustain=true end, 
    ['!ped-end!'] = function() midi_state.sustain=false flush_sustained_notes(midi_state.current_track, midi_state) end,    
    ['!crescendo(!'] = function() increment_dynamics(midi_state, midi_state.accents.delta) end,
    ['!crescendo)!'] = function() increment_dynamics(midi_state, -midi_state.accents.delta) end,
    ['!diminuendo(!'] = function() increment_dynamics(midi_state, -midi_state.accents.delta) end,
    ['!diminuendo)!'] = function() increment_dynamics(midi_state, midi_state.accents.delta) end,
    }
    
    modifiers['!>(!'] = modifiers['crescendo(']
    modifiers['!>)!'] = modifiers['crescendo)']
    modifiers['!<(!'] = modifiers['diminuendo(']
    modifiers['!<)!'] = modifiers['diminuendo)']
    
    for i,v in ipairs(decorations) do
        if modifiers[v] then modifiers[v]() end
    end
end
  



function apply_articulation_decorators(midi_state, velocity, trimming, decorations)
    -- apply staccato and dynamics modifiers
        
    local modifier = 1
    local dynamics_decorations = {
    ["!pppp!"]=0.05,
    ["!ppp!"]=0.15,
    ["!pp!"]=0.3,
    ["!p!"]=0.6,
    ["!mp!"]=0.9,
    ["!mf!"]=1.2,
    ["!ff!"]=1.6,
    ["!fff!"]=2.0,
    ["!ffff!"]=2.5,
    ["L"]=2.0,
    ["!emphasis!"]=2.0,
    ["!accent!"]=2.0,
    ["!staccato!"]=0.8,
    }
    
    -- find any matching decorations
    for i,v in ipairs(decorations) do
        if dynamics_decorations[v] then 
            modifier=dynamics_decorations[v] 
        end
        
        if v=='.' or v=='!staccato!' then
            trimming = trimming * 0.3
        end
        
        if v=='!emphasis!' or v=='!accent!' then
            trimming = trimming * 0.8
        end
        
        
        if v=='!tenuto!' or v=='!legato!' then
            trimming = trimming * 1.2
        end
        
        if v=='!snap!' then
            trimming = trimming * 0.1
        end
        if v=='!+!' then
            trimming = trimming * 0.15
        end                
    end    
    
    velocity = velocity * modifier    
    -- force saturation by incrementing by 0
    velocity = saturated_increment(velocity, 0, 0, 127) 
    
    return velocity, trimming
    
end

function apply_slides(midi_state, start_time, end_time, decorations)
    -- apply slides and rolls; does not play well with microtones or linear temperaments
    -- since both use the pitch wheel to apply tuning changes
    local t, real_t, semi_bend
    local duration, fraction
    
    
    for i,v in ipairs(decorations) do
        if v=='!slide!' then 
            -- slide up in the first half of the note
            duration = (end_time-start_time)/2
            for j=1,16 do
                fraction = j/16.0
                t = start_time + duration*fraction
                real_t = get_distorted_time(t, midi_state)
                semi_bend = -(1-fraction)
                table.insert(midi_state.current_track, {'pitch_wheel_change', real_t, midi_state.channel, semi_bend*4096})
            end            
            table.insert(midi_state.current_track, {'pitch_wheel_change', real_t, midi_state.channel, 0})
        end
        
        if v=='!bend!' then 
            -- bend the note, bending more towards the end
            for j=1,16 do
                fraction = j/16.0
                t = start_time + (end_time-start_time)*fraction
                real_t = get_distorted_time(t, midi_state)
                semi_bend = fraction*fraction*2
                table.insert(midi_state.current_track, {'pitch_wheel_change', real_t, midi_state.channel, semi_bend*4096})
            end
            table.insert(midi_state.current_track, {'pitch_wheel_change', real_t, midi_state.channel, 0})
        end
        
    end
    
end

function insert_midi_note(event, midi_state)
    -- insert a plain note into the score
    local duration = event.duration/1e3
    
    local velocity = 127    
    local track = midi_state.current_track
    local trimming 
    midi_state.t = event.t / 1e3
    local start_time = midi_state.t
    local end_time = midi_state.t + duration
    
    local decorations = event.note.decoration or {}
    
    -- check for state modifier  decorators
    apply_modifier_decorations(midi_state, decorations)
    
    -- check if we need to remap this pitch from the drummap
    local note_id =  event.note.pitch.note..event.note.pitch.octave        
    pitch = midi_state.drum.map[note_id] or event.note.play_pitch
        
    -- get the velocity and articulation of this note
    velocity, trimming = get_accent_velocity(midi_state, duration)    
    -- apply articulation modifiers 
    velocity, trimming = apply_articulation_decorators(midi_state, velocity, trimming, decorations)    
    
    local notes_to_render = {}   
    -- render grace notes
    if event.note.grace and midi_state.grace_divider~=0 then        
        -- get grace note length
        local note_duration = midi_state.base_note_length / midi_state.grace_divider                
        for j,n in ipairs(event.note.grace.sequence) do            
                table.insert(notes_to_render, {pitch=n.play_pitch, duration=note_duration, velocity=velocity})                                               
        end        
    end    
    
    -- add ornaments
    for i,v in ipairs(decorations) do
        -- upper mordents
        if v=='!uppermordent!' or v=='!pralltriller!' or v=='P' then
            table.insert(notes_to_render, {pitch=pitch, duration=duration/8, velocity=velocity}) 
            table.insert(notes_to_render, {pitch=pitch+2, duration=duration/4, velocity=velocity}) 
        end
        -- lower mordents
        if v=='!lowermordent!' or v=='!mordent!' or v=='M' then
            table.insert(notes_to_render, {pitch=pitch, duration=duration/8, velocity=velocity}) 
            table.insert(notes_to_render, {pitch=pitch-2, duration=duration/4, velocity=velocity}) 
        end
        -- trills
        if v=='!trill!' or v=='T' then
            local trill_duration = midi_state.base_note_length/8
            for i=1,7 do
                table.insert(notes_to_render, {pitch=pitch+(i%2)*2, duration=trill_duration, velocity=velocity}) 
            end            
        end
        -- rolls
        if v=='!roll!' or v=='~' then
            table.insert(notes_to_render, {pitch=pitch+2, duration=midi_state.base_note_length/4, velocity=velocity}) 
            table.insert(notes_to_render, {pitch=pitch-2, duration=midi_state.base_note_length/4, velocity=velocity}) 
        end
        -- turns
        if v=='!turn!' or v=='!turnx!' then
            table.insert(notes_to_render, {pitch=pitch+2, duration=duration/4, velocity=velocity}) 
            table.insert(notes_to_render, {pitch=pitch, duration=duration/4, velocity=velocity}) 
            table.insert(notes_to_render, {pitch=pitch-2, duration=duration/4, velocity=velocity}) 
        end
        
    end
    
    table.insert(notes_to_render, {pitch=pitch, duration=duration*trimming, velocity=velocity, tied=event.tie})       
    for i,v in ipairs(notes_to_render) do                
        -- truncate notes that would be longer than the original note
        if midi_state.t+v.duration>end_time then
            v.duration = end_time - midi_state.t
        end
        -- render the notes themselves
        add_note(midi_state, track, midi_state.t, v.duration, midi_state.channel, v.pitch, v.velocity, v.tied)    
        midi_state.t = midi_state.t + v.duration
    end
    
    -- add slides and bends
    apply_slides(midi_state, start_time, end_time, decorations)
    
    midi_state.t = end_time
end
