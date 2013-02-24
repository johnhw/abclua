local abclua = require "abclua"
local re = require "re"
require "midi/drone"
require "midi/chords"
require "midi/beats"
require "midi/commands"
require "midi/notes"
require "midi/drums"


    -- %%MIDI barlines
    --++ %%MIDI bassprog
    -- %%MIDI beat
    --++ %%MIDI beataccents
    -- %%MIDI beatmod
    --++ %%MIDI beatstring
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
    --++ %%MIDI nobeataccents
    --++ %%MIDI pitchbend
    -- %%MIDI portamento
    --++ %%MIDI program
    -- %%MIDI ptstress
    --++ %%MIDI randomchordattack
    -- %%MIDI ratio
    --++ %%MIDI stressmodel
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
     midi_state.last_bar_time = 0
     midi_state.sustain = false          
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
        drum = {enabled=true, bars=1, pattern=nil, pitches={35,35,35,35}, velocities={110,80,90,80}, channel=9, bar_counter=0, track={}, map={}},
        note_mapping = {}, -- for drummap
        accents = {enabled=true, delta=15, mode='beat', first=127, strong=100, other=80, accent_multiple=4, pattern=nil,stress={}},
        transpose = 0,
        trimming = 1.0,
        key = nil,
        grace_divider = 4,
        custom_chords = {},
        note_length = 4,
        portamento = {normal=0, bass=0, chord=0},
        meter = {den=4, num=4, empahsis={0}},
        sustained_notes = {},
        t = 0,
        current_track = {},
        bar_length = 0,
        base_note_length = 0,
        beat_length = 0,
        beats_in_bar = 0,
        last_bar_time = 0,
        rhythm = '',        
        sustain = false,        
    }
    
    
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
    if not argument then warn(msg) return nil end
    argument = tonumber(argument)
    if not argument then warn(msg) return nil end
    if argument<min or argument>max then warn(msg) return nil end
    return tonumber(argument)
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


function update_midi_meter(event, midi_state)
    -- change of meter 
    midi_state.meter = event.meter
    midi_set_stress(midi_state)
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
        midi_state.current_track = new_track(40, channel)
        
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
            
                        
            if event.event=='chord' or event.event=='text' then
                -- check free text for custom chord events!
                insert_midi_chord(event, midi_state)
            end
            
            if event.event=='bar' and event.bar.type~='variant' then
                midi_state.last_bar_time = event.t/1e3
                midi_state.t = event.t/1e3
                insert_midi_drum(midi_state)                
            end
            
            -- change of meter
            if event.event=='meter' then
                -- update gchord
                update_midi_meter(event, midi_state)
                
            end
                        
             -- change of rhythm specifier
            if event.event=='field_text' and event.name=='rhythm' then            
                midi_state.rhythm = event.content
                midi_set_stress(midi_state)
                
            end
            if event.event=='note_length' then
                -- update grace subdivisions
                midi_state.note_length = note_length
            end
           
            if event.event=='key' then
                midi_state.key = event.key
            end
            
            if event.event=='timing_change' then
                midi_state.base_note_length = event.timing.base_note_length / 1e3
                midi_state.bar_length = event.timing.bar_length / 1e3
                midi_state.beat_length = event.timing.beat_length / 1e3
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


-- the dispatch table for the various directives
local midi_directives = {
    channel = midi_channel,
    program = midi_program,
    bassprog = midi_bassprog,
    chordprog = midi_chordprog,
    chordname = midi_chordname,
    chordvol = function(args,midi_state,score) midi_state.chord.velocity=(check_argument(args[2],1,128,'Bad chord velocity')+1) or midi_state.chord.velocity end,
    bassvol = function(args,midi_state,score) midi_state.bass.velocity=(check_argument(args[2],1,128,'Bad bass velocity')+1) or midi_state.bass.velocity end,
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
    ptstress = midi_ptstress,
    stressmodel = midi_stressmodel,
    pitchbend = midi_pitchbend,
    temperamentlinear = midi_temperamentlinear,
    temperamentnormal = function(args,midi_state,score) midi_state.temperament = nil end,
    drum = midi_drum,
    drummap = midi_drum_map,
    beatmod = midi_beatmod,
    deltaloudness = midi_deltaloudness,
    portamento = midi_portamento,
}

function apply_midi_directive(arguments, midi_state, score)
    -- apply a midi state change by dispatching to the correct handler
    
    if arguments[1] and midi_directives[arguments[1]] then        
        midi_directives[arguments[1]](arguments, midi_state, score)
    end
end


function convert_file(abc_fname, mid_fname)
    -- convert an abc file to a midi file
    local MIDI = require "MIDI"   
    songs = parse_abc_file(abc_fname)
    opus = produce_midi_opus(songs[1])    
    local midifile = assert(io.open(mid_fname,'wb'))
    midifile:write(MIDI.opus2midi(opus))
    midifile:close()  
end

function test_midi_generation()
    -- run the test suite
    tests = {'stress_2', 'stress_1', 'accents', 'beatstring', 'chordattack', 'chords', 'drone', 
    'micro', 'transpose', 'trim', 'linear', 'pitch_bend', 'drum', 'chordname', 'beatmod', 'drummap', 'pedal', 'crescendo',
    'dynamics', 'grace', 'ornaments', 'portamento', 'cc'}

    for i,v in ipairs(tests) do
        print("Testing: "..v)
        convert_file('midi/tests/'..v..'.abc','midi/test_out/'..v..'.mid')
    end
end

-- todo:
-- chordattack apply to chords
-- ccs for decorations
