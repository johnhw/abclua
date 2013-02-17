-- Functions for handling key signatures and modes
-- and working out sharps and flats in keys.

function midi_to_frequency(midi, reference)
    -- transform a midi note to a frequency (in Hz)
    -- optionally use a different tuning than concert A
    -- specify frequency of A in Hz as the second parameter if required
    reference = reference or 440.0    
    return reference * math.pow(2.0, (midi-69)/12.0)
end

-- Table mapping notes to semitones
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

function get_note_number(note)
    return note_table[string.lower(note:gsub('#','s'))]
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


function shift_root_key(key, semis)
    -- given a root note and a shift (in semitones)
    -- work out the new root key. Examples
    -- C,+2  = D
    -- C,-1 = B
    -- E,-1 = Eb
    local k = string.lower(key:gsub('#','s'))
    local inv_note_table = invert_table(key_note_table)
    local semi = (key_note_table[k]+semis)
    if semi<0 then
        semi = semi + 12
    end
    return inv_note_table[semi % 12]
end


-- semitones in the major scale
local major = {'c','d','e','f','g','a','b'}
local key_table = 
{
c = {0,0,0,0,0,0,0},
g = {0,0,0,1,0,0,0},
d = {1,0,0,1,0,0,0},
a = {1,0,0,1,1,0,0},
e = {1,1,0,1,1,0,0},
b = {1,1,0,1,1,1,0},
fs = {1,1,1,1,1,1,0},
cs = {1,1,1,1,1,1,1},
f =  {0,0,0,0,0,0,-1},
bb = {0,0,-1,0,0,0,-1},
eb = {0,0,-1,0,0,-1,-1},
ab = {0,-1,-1,0,0,-1,-1},
db = {0,-1,-1,0,-1,-1,-1},
gb = {-1,-1,-1,0,-1,-1,-1},
cb = {-1,-1,-1,-1,-1,-1,-1},

-- not real keys, but sound correct
as = {0,0,-1,0,0,0,0},
ds = {0,0,-1,0,0,-1,-1},
gs = {0,-1,-1,0,0,-1,-1},
fs = {-1,-1,-1,0,-1,-1,-1},
bs = {-1,-1,-1,-1,-1,-1,-1},
}


local diatonic_scale = {[0]='b', 'c', 'd', 'e', 'f', 'g', 'a', 'b'}
local inverse_diatonic_scale = invert_table(diatonic_scale)

function nth_note_of_key(key, n)
    -- return the nth note of a key (e.g. 2nd note of C is D,
    -- 2nd note of G is A etc.)
    local base = inverse_diatonic_scale[key]
    return diatonic_scale[(base+n) % 7]
end

local inverse_note_table = invert_table(note_table)
local inverse_key_note_table = invert_table(key_note_table)

-- offsets for the common modes
local mode_offsets = {maj=0, min=3, mix=5, dor=10, phr=8, lyd=7, loc=1}


function get_major_key(key)
    -- return the semitones in a given major key
    -- (e.g. C = {0,2,4,5,7,9,11})
    local c_major = {0,2,4,5,7,9,11}
    for i,v in ipairs(key_table[key]) do
        
        local semi = c_major[i] + v
        
        -- wrap to 0-12
        if semi<0 then
            semi = semi + 12
        end
        if semi>12 then
            semi = semi - 12
        end
        c_major[i] = semi
    end
    return c_major
end

function get_major_keys()
    -- return a table mapping key names to semitone values
    local keys = {}
    for i,v in pairs(key_table) do
        keys[i] = get_major_key(i)
    end   
    return keys
end


function compute_mode(offset)
    -- compute a mapping from notes in a given mode to the corresponding major key
    -- e.g. compute_mode(3) gives the relative major keys of each possible minor key
    -- return value is a table mapping from the modal key (e.g. E min) to the 
    -- corresponding major key (e.g. G)
    local notes = {}
    for note, semi in pairs(note_table) do
        semi = (semi + offset) % 12        
        notes[note] = inverse_key_note_table[semi]
    end
    return notes
end


local key_matcher = re.compile([[
    key <- ( {:none: ('none') :} / {:pipe: ('Hp' / 'HP') :} / (
        {:root: ([a-gA-G]) 'b'? '#'? :}  
        (%s * {:mode: (mode %S*):}) ? 
        (%s * {:accidentals: (accidentals):}) ?         
         ({:clef:  ((%s + <clef>) +) -> {}   :})  ?           
        )) -> {} 
        
    clef <-  (({:clef: clefs :}  / clef_def /  middle  / transpose / octave / stafflines / custom )  ) 
    
    custom <- ([^:] + ':' [^=] + '=' [%S] +)
    clef_def <- ('clef=' {:clef: <clefs> :} [0-9] ? ({:plus8: (  '+8' / '-8' ) :})  ? ) 
    clefs <- ('alto' / 'bass' / 'none' / 'perc' / 'tenor' / 'treble' )
    middle <- ('middle=' {:middle: <number> :})
    transpose <- (('transpose='/'t=')  {:transpose: <number> :}) 
    octave <- ('octave=' {:octave: <number> :}) 
    stafflines <- ('stafflines=' {:stafflines: <number> :})
    
    
    number <- ( ('+' / '-') ? [0-9]+)
    
    mode <- ( ({'maj'}) / ({'aeo'}) / ({'ion'}) / ({'mix'}) / ({'dor'}) / ({'phr'}) / ({'lyd'}) /
          ({'loc'}) /  ({'exp'}) / ({'min'}) / {'m'}) 
    accidentals <- ( accidental (%s+ accidental) * ) -> {} 
    accidental <- ( {('^^' / '__' / '_' / '^' / '=')} (duration)? {[a-g]}  ) -> {} 
    duration <- ( (({:num: ([1-9] +) :}) ? ({:slashes: ('/' +)  :})?  ({:den: ((  [1-9]+  ) ) :})?))  -> {}

]])

function parse_key(k)
    -- Parse a key definition, in the format <root>[b][#][mode] [accidentals] [expaccidentals]
    

    k = k:lower()
    local captures = key_matcher:match(k)
    
    -- normalise the accidentals
    local accidentals = {}
    local value
    if captures.accidentals then    
        for i,v in ipairs(captures.accidentals) do            
            value = canonicalise_accidental(v)
            table.insert(accidentals, {note=v[3],accidental=value})
        end
    end
    captures.accidentals = accidentals
   
    --replace +8 / -8 with a straightforward transpose
    if captures.clef and captures.clef.plus8 then
        if captures.clef.plus8=='-8' then
            captures.clef.octave = (captures.clef.octave or 0) + 1
        else
            captures.clefoctave = (captures.clef.octave or 0) - 1 
        end
        captures.clef.plus8 = nil
    end
    
    -- replace transpose with t
    if captures.clef and captures.clef.t then
        captures.clef.transpose = captures.clef.t
        captures.clef.t = nil
    end
    
    return captures
    
    
end




function create_key_structure(k)
    -- Create a key structure, which lists each note as written (e.g. A or B)
    -- and maps it to the correct semitone in the interval
    
    local key_mapping = {}    
    
    -- default: C major if no signature
    for i,v in pairs(key_table['c']) do                        
            key_mapping[major[i]] = v
    end        
    
    -- none = c major, all accidentals must be specified
    if k.none then
        return key_mapping
    end
    
    
    -- Pipe notation (Hp or HP): F sharp and G sharp
    if k.pipe then
        for i,v in pairs(key_table['c']) do                        
                key_mapping[major[i]] = v
        end        
        
        key_mapping[1] = 1 -- C sharp
        key_mapping[4] = 1 -- F sharp
                    
    else
        -- find the matching key        
        local root = k.root
        root = root:gsub('#', 's')
        
        -- offset according to mode
        if k.mode then
            if k.mode=='aeo'  or k.mode=='m' then
                k.mode = 'min'
            end
            
            if k.mode=='ion' then
                k.mode = 'maj'
            end            
            
            -- get the modal offset
            local modal_root = root            
            
            if mode_offsets[k.mode] then
                local major_mapping = compute_mode(mode_offsets[k.mode])
                root = major_mapping[root] -- get relative major key                        
            end            
        end
                
      
        for i,v in pairs(key_table[root]) do                        
            key_mapping[major[i]] = v
        end
        
        -- add accidentals
        if k.accidentals then
            for i,v in pairs(k.accidentals) do
                if v.accidental.num == 0 then
                    key_mapping[v.note] = 0
                else
                    key_mapping[v.note] = v.accidental.num / v.accidental.den
                end
            end
        end
        
                        
    end
    return key_mapping
end

