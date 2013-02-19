local abclua = require "abclua"
local re = require "re"
require "midi/drone"
require "midi/chords"



    -- %%MIDI barlines
    --++ %%MIDI bassprog
    -- %%MIDI beat
    -- %%MIDI beataccents
    -- %%MIDI beatmod
    -- %%MIDI beatstring
    -- %%MIDI bendvelocity
    --++ %%MIDI channel
    --++ %%MIDI chordattack
    --XXX %%MIDI chordname
    --++ %%MIDI chordprog
    --++ %%MIDI bassprog
    
    --++ %%MIDI control
    -- %%MIDI deltaloudness
    --++ %%MIDI droneon
    --++ %%MIDI droneoff
    --++ %%MIDI drone
    -- %%MIDI drum
    --++ %%MIDI drumon
    --++ %%MIDI drumoff
    --++ %%MIDI drumbars
    -- %%MIDI drummap
    -- %%MIDI fermatafixed
    -- %%MIDI fermataproportional
    --++ %%MIDI gchord
    --++ %%MIDI gchordon
    --++ %%MIDI gchordoff
    --++ %%MIDI grace
    --++ %%MIDI gracedivider
    -- %%MIDI makechordchannels
    -- %%MIDI nobarlines
    -- %%MIDI nobeataccents
    -- %%MIDI pitchbend
    -- %%MIDI portamento
    --++ %%MIDI program
    -- %%MIDI ptstress
    --++ %%MIDI randomchordattack
    -- %%MIDI ratio
    -- %%MIDI stressmodel
    -- %%MIDI snt
    --++ %%MIDI rtranspose
    --++ %%MIDI transpose
    --++ %%MIDI trim 



function warn(str)
    -- warn the user of an error
    print('WARNING: '..str)
end


function reset_midi_state(midi_state, channel)
    -- reset the midi state for a new track
     midi_state.channel = channel or midi_state.channel
     midi_state.program = 1
     midi_state.transpose = 0
     midi_state.bar_length = 0
     midi_state.beat_length = 0
     midi_state.beats_in_bar = 0
     midi_state.note_length = 4
     midi_state.base_note_length = 0
    
end

function default_midi_state()
    -- get a copy of the default midi state
    local midi_state = {
        channel = 0,
        program = 1,  
         -- 'default': update everytime we see a meter marker and at start of song
        chord = {enabled=true, delay=0, random_delay = 0, channel=14, program=24, octave=0, velocity=82, pattern='default', notes_down={}, track={}},
        bass = {program=45, channel=13, octave=0, velocity=88, notes_down={}, track={}},
        drone = {enabled=false, program=70, pitches={70,45}, velocities={80,80}, channel=12, track={}},
        drum = {enabled=false, bars=1, pattern='dddd', pitches={35,35,35,35}, velocities={110,80,90,80}, track={}},
        note_mapping = {}, -- for drummap
        accents = {enabled=true, mode='beat', first=127, strong=100, other=80, accent_multiple=4, pattern=nil,stress=nil},
        transpose = 0,
        trimming = 1.0,
        grace_divider = 4,
        note_length = 4,
        portamento = {normal=0, bass=0, chord=0},
        meter = {den=4, num=4, empahsis={0}},
        channel_notes_down = {},
        t = 0,
        current_track = {},
        bar_length = 0,
        base_note_length = 0,
        beat_length = 0,
        beats_in_bar = 0,
        last_bar_time = 0,
    
    }
    
    -- create the note down table
    for i=0,15 do 
        midi_state.channel_notes_down[i] = {}
    end
    
    -- create the tracks
    local chord_score = new_track(midi_state.chord.program, midi_state.chord.channel)
    local bass_score = new_track(midi_state.bass.program, midi_state.bass.channel)
    local drone_score = new_track(midi_state.drone.program, midi_state.drone.channel)
    local drum_score = new_track()
    
    midi_state.chord.track = chord_score
    midi_state.bass.track = bass_score
    midi_state.drone.track = drone_score
    midi_state.drum.track = drum_score
    
    return midi_state
end

function check_argument(argument, min, max, msg)
    -- Check if the arguments is present, is a number
    -- and is within a given range
    msg = msg..(argument or '<nil>')
    if not argument then warn(msg) return false end
    argument = tonumber(argument)
    if not argument then warn(msg) return false end
    if argument<min or argument>max then warn(msg) return false end
    return true
end



function parse_assignment(assignment)
    -- parse a string of the form x=y, and return the two sides, or nil if this does not match
    local matcher = re.compile("(%s*{:lhs: [^=%s]+:} %s* '=' %s * {:rhs: %S+ :}) -> {}")
    local result = matcher:match(assignment)
    if result then
        return result.lhs, result.rhs
    end
end





----------------------------
---- TRACKS ----------------
----------------------------

function stable_sort(t,key)
    -- sort by key, maintaining original order
    for i,v in ipairs(t) do
        v.__sort_index_sequence = i
    end    
    table.sort(t, function(a,b) if a[key]==b[key] then return a.__sort_index_sequence<b.__sort_index_sequence else return (a[key] or 0)<(b[key] or 0) end end)    
end

function new_track(patch, channel)
    -- return a new, empty track, with one tick per second    
    local track = {{'set_tempo', 0, 1000000}}    
    if patch and channel then
        table.insert(track, {'patch_change', 0, channel, patch})
    end
    return track
end

function delta_time(tracks)
    -- convert tracks to delta timing
    for j, score in ipairs(tracks) do   
    
        stable_sort(score, 2)
        
        -- make times into delta times
        local t = 0, last_t
        for i,v in ipairs(score) do
            last_t = v[2]
            v[2] = v[2]-t
            -- forbid negative delta times
            if v[2]<0 then v[2] = 0 end
            t = last_t
        end
    end
end


-----------------------------
------ BEATS ----------------
-----------------------------

function midi_beat(args, midi_state)
    if not check_argument(args[2], 1, 128, 'Bad beat first velocity') then return end
    if not check_argument(args[3], 1, 128, 'Bad beat strong velocity') then return end
    if not check_argument(args[4], 1, 128, 'Bad beat other velocity') then return end
    if not check_argument(args[5], 1, 64, 'Bad beat multiple') then return end
    
    midi_state.accents.first = tonumber(args[2])
    midi_state.accents.strong = tonumber(args[3])
    midi_state.accents.other = tonumber(args[4])
    midi_state.accents.accent_multiple = tonumber(args[5])
    midi_state.accents.pattern = nil -- clear any explicit pattern
end

function midi_beatstring(args, midi_state)
 -- set the beat string for note empahsis
 local beat_matcher = re.compile([[
    gchord <- (<elt>+) -> {}
    elt <- ({:type: <type> :} {:count: <count>? :}) -> {}
    type <- ('f'/'m'/'p')
    count <- ([0-9]+)
    ]])
    local pattern = beat_matcher:match(args[2])
    if pattern then
        midi_state.accents.pattern = expand_counted_sequence(pattern)
    end
end

function midi_set_stress(args, midi_state)
    -- set the stress accenting. If not present, uses the default
    -- stress model for the current rhythm

end

function midi_stressmodel(args, midi_state)
    -- set the stress mode (beat, articulate or distort)
    if args[2]=='beat' or tonumber(args[2])==0 then
        midi_state.accents.mode = 'beat'
    end
    
    if args[2]=='articulate' or tonumber(args[2])==1 then
        midi_state.accents.mode = 1
    end
    
    if args[2]=='distort' or tonumber(args[2])==1 then
        midi_state.accents.mode = 2
    end
    
    midi_set_stress()
end



function midi_ptstress(args, midi_state)
    -- set the stress model
    local stress = {}
    local nbeats
    
    if not args[2] then
        -- set default stress model for this rhythm if no stress
        accents.stress = nil
        midi_set_stress()
    end
    
    if tonumber(args[2]) then
        -- is a literal stress model
        nbeats = args[2]
        local arg_index = 3
        -- first number is the number of divisions, subsequent numbers are velocity, stress pairs
        for i=1,nbeats do
            table.insert(stress, {velocity=args[arg_index], stretch=args[arg_index+1]})
            arg_index = arg_index + 2
        end
        
    else
        local f = io.open(args[2], 'r')
        -- read from a file
        if f then
            -- file consists of number of beats, followed by velocity, stress pairs
            nbeats = f:read('*number')                 
            for i=1,nbeats do
                table.insert(stress, {velocity=f:read('*number'), stretch=f:read('*number')})
            end
            
            f:close()
        end
    end
    stress.divisions = nbeats
    
    midi_state.accents.stress = stress    
end

-- the dispatch table for the various directives
local midi_directives = {
    channel = midi_channel,
    program = midi_program,
    bassprog = midi_bassprog,
    chordprog = midi_chordprog,
    gchordoff = function(args,midi_state,score) midi_state.chord.enable=false end,
    gchordon = function(args,midi_state,score) midi_state.chord.enable=true end,
    chordattack = function(args,midi_state,score) midi_state.chord.delay=tonumber(args[2]) or midi_state.chord.delay end,
    randomchordattack = function(args,midi_state,score) midi_state.chord.random_delay=tonumber(args[2]) or midi_state.chord.random_delay end,
    drumoff = function(args,midi_state,score) midi_state.drum.enable=false end,
    drumon = function(args,midi_state,score) midi_state.drum.enable=true end,
    transpose = function(args,midi_state,score) midi_state.transpose=tonumber(args[2]) or midi_state.transpose end,
    rtranspose = function(args,midi_state,score) midi_state.transpose=midi_state.transpose + (tonumber(args[2]) or 0) end,
    trim = midi_trim,
    gracedivider = function(args,midi_state,score) midi_state.grace_divider=tonumber(args[2]) or midi_state.grace_divider end,
    grace = function() warn('grace not supported; use gracedivider instead.') end,
    droneoff = disable_drone,
    droneon = enable_drone,
    drumbars =function(args,midi_state,score) midi_state.drum.bars=(tonumber(args[2]) or midi_state.drum.bars) end, 
    gchord = midi_gchord,
    drone = midi_drone,
    control = midi_control,
    beat = midi_beat,
    beatstring = midi_beatstring,
    beataccents = function(args,midi_state,score) midi_state.accents.enabled=true end,
    nobeataccents = function(args,midi_state,score) midi_state.accents.enabled=false end,
}



function apply_midi_directive(arguments, midi_state, score)
    -- apply a midi state change by dispatching to the correct handler
    if arguments[1] and midi_directives[arguments[1]] then
        midi_directives[arguments[1]](arguments, midi_state, score)
    end
end

function add_note(midi_state, track, t, duration, channel, pitch, velocity, tied)
    -- add a note/off pair, applying the transpose, and inserting necessary pitch bend commands
    -- for fractional notes
    pitch = pitch+midi_state.transpose        
    
    -- insert pitch bends for microtones
    local pitch_offset = pitch-math.floor(pitch)
    if math.abs(pitch_offset)>0.01 then       
        
        table.insert(track, {'pitch_wheel_change', t, channel,  4096*pitch_offset})    
    end
    
    table.insert(track, {'note_on', t, channel,  pitch, velocity})
    if not tied then
        table.insert(track, {'note_off', t+duration-0.1, channel, pitch, velocity})                
        
        if math.abs(pitch_offset)>0.01 then       
            table.insert(track, {'pitch_wheel_change', t+duration-0.05, channel,  0})    
        end
    
    end
                
end

function get_beat_velocity(midi_state)
    -- get the velocity of a note from the accent, when using
    -- simple beat form
    local velocity
    if midi_state.t == midi_state.last_bar_time then
            velocity = midi_state.accents.first
        else                    
            -- not first note, work out which multiple it is and emphasise that
            local beat_index = math.floor((midi_state.t-midi_state.last_bar_time) / midi_state.beat_length+1)            
            if beat_index % midi_state.accents.accent_multiple==0 then
                velocity = midi_state.accents.strong
            else
                velocity = midi_state.accents.other
            end
        end
    return velocity
end

function get_beat_string_velocity(midi_state)
    -- get the velocity of a note from the accent, when using
    -- the full beat string
    local beats = #midi_state.accents.pattern
    -- work out which segment we are in
    local beat_index = math.floor(((midi_state.t-midi_state.last_bar_time) / midi_state.bar_length)*beats)+1    
    local velocities = {f=midi_state.accents.first, m=midi_state.accents.strong, p=midi_state.accents.other}
    return  velocities[midi_state.accents.pattern[beat_index]]
end


function insert_midi_note(event, midi_state)
    -- insert a plain note into the score
    local duration = event.duration/1e3
    local velocity = 127    
    local track = midi_state.current_track
    midi_state.t = event.t / 1e3
    
    -- work out velocity from the accents
    if midi_state.accents.enabled then
        if midi_state.accents.pattern then
            velocity = get_beat_string_velocity(midi_state)
        else
            velocity = get_beat_velocity(midi_state)
        end
    end
    
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
    
    add_note(midi_state, track, midi_state.t, duration*midi_state.trimming, midi_state.channel, event.pitch, velocity, event.tie)    
    midi_state.t = midi_state.t+duration
end


function update_midi_meter(event, midi_state)
    -- change of meter 
    midi_state.meter = event.meter
    midi_set_stress()
end

function produce_midi_opus(song)
    -- return an opus format version of this song, suitable to
    -- be written as a MIDI file
    local midi_state
    local score
    local tracks = {}
    
    midi_state = default_midi_state()        
    
    local channel = 0
    -- new state and track for each voice
    for id,voice in pairs(song.voices) do
        midi_state.current_track = new_track(0, channel)
        
        midi_state.channel = channel
        channel = channel + 1
        
        for j,event in ipairs(voice.stream) do
        
            -- apply MIDI state changes
            if event.event=='instruction' and event.directive and event.directive.directive and event.directive.directive=='MIDI' then
                apply_midi_directive(event.directive.arguments, midi_state)
            end
            
            -- rests and notes
            -- if event.event=='rest' then
                -- insert_midi_rest(event,midi_state,score)
            -- end
            
            if event.event=='note' then
                insert_midi_note(event,midi_state)
            end
            
            
            
            if event.event=='chord' then
                insert_midi_chord(event, midi_state)
            end
            
            if event.event=='bar' and event.bar.type~='variant' then
                midi_state.last_bar_time = event.t/1e3
                midi_state.t = event.t/1e3
                
            end
            
            -- change of meter
            if event.event=='meter' then
                -- update gchord
                update_midi_meter(event, midi_state)
                
            end
                        
             -- change of rhythm specifier
            if event.event=='field_text' and event.name=='rhythm' then
                midi_set_stress()
                
            end
            if event.event=='note_length' then
                -- update grace subdivisions
                midi_state.note_length = note_length
            end
            
            if event.event=='timing_change' then
                midi_state.base_note_length = event.base_note_length / 1e3
                midi_state.bar_length = event.bar_length / 1e3
                midi_state.beat_length = event.beat_length / 1e3
                
            end
        end
                
        -- store the score
        table.insert(tracks, midi_state.current_track)        
    end    
    
    -- insert the chord, bass, drone and drum tracks
    table.insert(tracks, midi_state.chord.track)        
    table.insert(tracks, midi_state.bass.track)        
    table.insert(tracks, midi_state.drum.track)        
    table.insert(tracks, midi_state.drone.track)        
    delta_time(tracks)
    -- insert the millsecond tick indicator    
    table.insert(tracks, 1, 1000)
    
    return tracks
end

local MIDI = require "MIDI"
fname = 'beatstring'
songs = parse_abc_file('midi/tests/'..fname..'.abc')
opus = produce_midi_opus(songs[1])
--table_print(opus)
local midifile = assert(io.open('midi/tests/'..fname..'.mid','wb'))
midifile:write(MIDI.opus2midi(opus))
midifile:close()  