-- pitch arithmetic functions


local natural_pitch_table = {c=0, d=2, e=4, f=5, g=7, a=9, b=11}

function get_semitone(key_mapping, pitch, accidental)
    -- return the semitone of a note (0-11) in a given key, with the given accidental
    local base_pitch = natural_pitch_table[pitch]    
           
    -- accidentals / keys
    if accidental then   
        if accidental.den==0 then 
            accidental =  0 
        else
            accidental = accidental.num / accidental.den
        end
        base_pitch = base_pitch + accidental        
    else        
        -- apply key signature sharpening / flattening
        if key_mapping then
            accidental = key_mapping[string.lower(pitch)]
            base_pitch = base_pitch + (accidental)
        end
    end        
    return base_pitch 
end

function midi_note_from_note(mapping, note, accidental)
    -- Given a key mapping, get the midi note of a given note        
    -- optionally applying a forced accidental
    accidental = note.pitch.accidental or accidental    
    local base_pitch = get_semitone(mapping, note.pitch.note, accidental)    
    return base_pitch + 60 + (note.pitch.octave or 0) * 12
end

local note_table = {
c=0,
cb=11,
cs=1,
d=2,
db=1,
ds=3,
e=4,
eb=3,
es=5,
f=5,
fb=4,
fs=6,
g=7,
gb=6,
gs=8,
a=9,
ab=8,
as=10,
b=11,
bb=10,
bs=12
}

function all_note_table()
    -- return a list of all notes and their semitone numbers
    return note_table
end

local key_note_table = {
c=0,
cb=11,
cs=1,
d=2,
db=1,
e=4,
eb=3,
f=5,
fs=6,
g=7,
gb=6,
a=9,
ab=8,
b=11,
bb=10
}

local inverse_key_note_table = invert_table(key_note_table)

function midi_to_frequency(midi, reference)
    -- transform a midi note to a frequency (in Hz)
    -- optionally use a different tuning than concert A
    -- specify frequency of A in Hz as the second parameter if required
    reference = reference or 440.0    
    return reference * math.pow(2.0, (midi-69)/12.0)
end


function transpose_note_name(name, shift)
    -- convert a note string into a canonical note string shifted by shift 
    -- semitones. Wraps around at octave boundaries
    return canonical_note_name((get_note_number(name)+shift)%12)
end

function get_note_number(note)
    -- Convert a note string to a note number (0-11)
    -- e.g. get_note_number('C#') returns 1
    return note_table[string.lower(note:gsub('#','s'))]
end

function canonical_note_name(num)
    -- change a semitone number (0-11) to a note name.
    -- only returns one of the canonical names (so there is no
    -- enharmonic ambiguity). 
    -- This means that canonical_note_name(get_note_number(note)) is not necessarily equal to note 
    return inverse_key_note_table[num]
end

function chord_case(str)
    -- Convert a note name to upper case, with proper # symbol
    return string.upper(string.sub(str,1,1))..string.sub(str,2,-1):gsub('s', '#')
end

function printable_note_name(n)
    -- convert a note number to a note symbol, and then return it as
    -- a printable note (uppercase, with #)
    local str = inverse_key_note_table[n%12]
    return chord_case(str)
end