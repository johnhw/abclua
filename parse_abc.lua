require "utils"
require "keys"
require "parts"
require "notes"
require "lyrics"
require "chords"
require "stream"
require "fields"
require "write_abc"
local re = require "re"


-- Grammar for parsing tune definitions
tune_pattern = [[
elements <- ( ({} <element>)  +) -> {}
element <- ( ({:slur: <slurred_note> :}) / ({:chord_group: <chord_group> :})  / {:bar: (<bar> / <variant>) :} / {:field: field :}  / {:free_text: free :} / {:triplet: triplet :} / {:s: beam_split :}  / {:continuation: continuation :}) -> {}

continuation <- ('\')
beam_split <- (%s +)
free <- ( '"' {:text: [^"]* :} '"' ) -> {}
bar <- ( {:type: ((']' / '[') * ('|' / ':') + (']' / '[') *) :} ({:variant_range: (<range_set>) :}) ? ) -> {}
variant <- {:type: '[' :} {:variant_range: <range_set> :}   -> {}
range_set <- (range (',' range)*)
range <- ([0-9] ('-' [0-9]) ?)
slurred_note <- ( (<complete_note>) -> {} / ('(' (<complete_note> +) ')' )  -> {}  ) 
chord_group <- ( ('[' (<complete_note> +) -> {} ']' ) ) 
complete_note <- (({:grace: (grace)  :}) ?  ({:chord: (chord)  :}) ?  ({:decoration: (decoration +) :}) ? {:note_def: full_note  :} ({:tie: (tie)  :}) ? ) -> {}
triplet <- ('(' {[1-9]} (':' {[1-9] ?}  (':' {[1-9]} ? ) ?) ?) -> {}
grace <- ('{' full_note + '}') -> {}
tie <- ('-')
chord <- (["] {[^"]} * ["]) -> {}
full_note <-  (({:pitch: (note) :} / {:rest: (rest) :} / {:measure_rest: <measure_rest> :} ) {:duration: (duration ?)  :}  {:broken: (broken ?)  :})  -> {}
rest <- ( 'z' / 'x' )
measure_rest <- (('Z' / 'X') ({:bars: ([0-9]+) :}) ? ) -> {}
broken <- ( ('<' +) / ('>' +) )
note <- (({:accidental: (accidental )  :})? ({:note:  ([a-g]/[A-G]) :}) ({:octave: (octave)  :}) ? ) -> {}
decoration <- ('.' / [~] / 'H' / 'L' / 'M' / 'O' / 'P' / 'S' / 'T' / 'u' / 'v' / ('!' [^!] '!') / ('+' [^+] '+'))
octave <- (( ['] / ',') +)
accidental <- ( '^' / '^^' / '_' / '__' / '=' )
duration <- ( (({:num: ([1-9] +) :}) ? ({:slashes: ('/' +)  :})?  ({:den: ((  [1-9]+  ) ) :})?))  -> {}
field <- ( {:contents: '['  field_element  ':'  [^] ] +  ']' :}) -> {}
field_element <- ([A-Za-z])

]]

tune_matcher = re.compile(tune_pattern)


function is_compound_time(song)
    -- return true if the meter is 6/8, 9/8 or 12/8
    -- and false otherwise
    local meter = song.internal.meter_data
    if meter then
        if meter.den==8 and (meter.num==6 or meter.num==9 or meter.num==12) then
            return true
        end
    end
    return false
end


function default_note_length(song)
    -- return the default note length
    -- if meter.num/meter.den > 0.75 then 1/8
    -- else 1/16
    if song.internal.meter_data then
        ratio = meter_data.num / meter_data.num
        if ratio>=0.75 then
            return 8
        else
            return 16
        end
    end
end

function apply_repeats(song, bar)
        -- clear any existing material
        if bar.type=='start_repeat' then
            add_section(song, 1)
        end
                                
        -- append any repeats, and variant endings
        if bar.type=='mid_repeat' or bar.type=='end_repeat' then
        
            add_section(song, bar.end_reps+1)
            
            -- mark that we will now go into a variant mode
            if bar.variant_range then
                -- only allows first element in range to be used (e.g. can't do |1,3 within a repeat)
                song.internal.in_variant = bar.variant_range[1]
            else
                song.internal.in_variant = nil
            end            
        end
        
        -- part variant; if we see this we go into a new part
        if bar.type=='variant' then
            start_variant_part(song, bar)
        end        
end

function read_tune_segment(tune_data, song)
    -- read the next token in the note stream
    
    
    for i,v in ipairs(tune_data) do
   
        -- abc cross reference
        if type(v) == 'number' then
            -- store cross-reference
            cross_ref = {line=song.internal.line_number, position=v}
            table.insert(song.opus, {event='cross_ref', cross_ref=cross_ref})
            
        else
        
            if v.measure_rest then
                bars = v.measure_rest.bars or 1
                table.insert(song.opus, {event='measure_rest', bars=bars})
                table.insert(song.journal, {event='measure_rest', bars=bars})
            end
            
            -- store annotations
            if v.free_text then
                table.insert(song.opus, {event='text', text=v.free_text})
                table.insert(song.journal, {event='text', text=v.free_text})
            end
            
            -- parse inline fields (e.g. [r:hello!])
            if v.field then                
                -- this automatically writes it to the journal
                parse_field(v.field.contents, song, true)
                table.insert(song.opus, {event='metadata', text=v.field})
            end
            
            -- deal with triplet definitions
            if v.triplet then                
                
                triplet = parse_triplet(v.triplet, song)
                table.insert(song.journal, {event='triplet', triplet=triplet})
                table.insert(song.opus, {event='triplet', triplet=triplet})
                
                -- update the internal tuplet state so that timing is correct for the next notes
                song.internal.triplet_compress = triplet.p / triplet.q
                song.internal.triplet_state = triplet.r
            end
            
            -- beam splits
            if v.s then
                table.insert(song.opus, {event='split'})
                table.insert(song.journal, {event='split'})
            end
            
            -- linebreaks
            if v.linebreak then
                table.insert(song.opus, {event='split_line'})
                table.insert(song.journal, {event='split_line'})
            end
                
            
            -- deal with bars and repeat symbols
            if v.bar then
                bar = parse_bar(v.bar)                                
                table.insert(song.opus, {event='bar', bar=bar})                 
                table.insert(song.journal, {event='bar', bar=bar})                
                apply_repeats(song, bar)                               
                             
            end
            
            -- chord groups
            if v.chord_group then
                if v.chord_group[1] then
                    table.insert(song.opus, {event='chord_begin'} )
                    table.insert(song.journal, {event='chord_begin'})                
                    
                    -- insert the individual notes
                    for i,note in ipairs(v.chord_group) do                
                        local cnote = parse_note(note)
                        insert_note(cnote, song)                
                        table.insert(song.journal, {event='note', note=cnote})    
                    end
                    
                    table.insert(song.opus, {event='chord_end'})                
                    table.insert(song.journal, {event='chord_end'})                
                    
                end                               
                
            end
            
            -- if we have slur groups then there are some notes to parse...
            if v.slur then
                -- slur groups
                if #v.slur>2 then
                    table.insert(song.opus, {event='slur_begin'} )
                    table.insert(song.journal, {event='slur_begin'} )
                end
                
                -- insert the individual notes
                for i,note in ipairs(v.slur) do                
                    local cnote = parse_note(note)
                    insert_note(cnote, song)                                                          
                    table.insert(song.journal, {event='note', note=cnote})
                end
                    
                if #v.slur>2 then
                    table.insert(song.opus, {event='slur_end'} )
                    table.insert(song.journal, {event='slur_end'} )
                end

                
            end
        end
    end
    
end




function parse_range_list(range_list)
    -- parses a range identifier
    -- as a comma separated list of numbers or ranges
    -- (e.g. "1", "1,2", "2-3", "1-3,5-6")
    -- Returns each value in this range
    
        
    local range_pattern = [[
    range_list <- ((<range>) (',' <range>) *) -> {}
    range <- (   <range_id> / <number> ) -> {}
    range_id <- (<number> '-' <number>)
    number <- ({ [0-9]+ }) 
    ]]    
    local matches = re.match(range_list, range_pattern)    
    local sequence = {}    
    -- append each element of the range list
    for i,v in ipairs(matches) do
        -- single number
        if #v==1 then
            table.insert(sequence, v[1]+0)
        end
        
        -- range of values
        if #v==2 then            
            for j=v[1]+0,v[2]+0 do
                table.insert(sequence, j)
            end
        end    
    end
    
    return sequence

end


function parse_bar(bar, song)
-- Parse a bar symbol and repeat/variant markers. Bars can be
-- plain bars (|)
-- bars with thick lines (][)
-- repeat begin (|:)
-- repeat end (:|)
-- repeat middle (:||: or :: or :|:)
-- variant markers [range

    bar_pattern = [[
        bar <- (  
        {:mid_repeat: <mid_repeat> :} /  {:end_repeat: <end_repeat> :}  / {:start_repeat: <start_repeat> :} / {:double: <double> :}
        / {:plain: <plain> :} /  {:thickthin: <thickthin> :} / {:thinthick: <thinthick> :} / {:variant: <variant> :} / {:colons: <just_colons> :} ) -> {}        
        mid_repeat <- ({}<colons> {}<plain>{} <colons>{}) -> {}
        start_repeat <- (<plain> {} <colons> {} ) -> {}
        end_repeat <- ({}<colons> {} <plain> ) -> {}
        just_colons <- ({} <colons> {}) -> {}
        plain <- ('|')
        thickthin <- ('[' '|')
        thinthick <- ('[' '|')
        double <- ('|' '|')
        
        variant <- ('[')
        colons <- (':' +) 
    ]]
  
    type_info = re.match(bar.type, bar_pattern)
      
    -- compute number of colons around bar (which is the number of repeats of this section)
    if type_info.mid_repeat then
        type_info.end_reps = type_info.mid_repeat[2]-type_info.mid_repeat[1]
        type_info.start_reps = type_info.mid_repeat[4]-type_info.mid_repeat[3]
    end
    
    if type_info.end_repeat then
        type_info.end_reps = type_info.end_repeat[2]-type_info.end_repeat[1]        
    end
    
    -- thick bars work like repeats with a count of one
    if type_info.thickthin or type_info.thinthick or type_info.double then
        type_info.end_reps = 0
        type_info.end_repeat = true
    end
    
    if type_info.start_repeat then
        type_info.start_reps = type_info.start_repeat[2]-type_info.start_repeat[1]        
    end        
    
    -- for a colon sequence, interpret :: as one start end repeat, :::: as two start, two end, etc.
    -- odd colon numbers without a bar symbol don't make sense!
    if type_info.colons then
        type_info.start_reps = type_info.colons[2]-type_info.colons[1] / 2
        type_info.start_reps = type_info.colons[4]-type_info.colons[3] / 2
        type_info.mid_repeat = type_info.colons -- this is a mid repeat
        type_info.colons = nil
    end
    
    
    local bar_types = {'mid_repeat', 'end_repeat', 'start_repeat', 'variant',
    'plain', 'double', 'thickthin', 'thinthick'}
    
    local parsed_bar = {}
    
    -- set type field
    for i,v in ipairs(bar_types) do
        if type_info[v] then
            parsed_bar.type = v
        end
    end
    
    -- convert ranges into a list of integers
    if type_info.variant_range then
        parsed_bar.variant_range = parse_range_list(type_info.variant_range)
    end
    
    parsed_bar.end_reps = type_info.end_reps
    parsed_bar.start_reps = type_info.start_reps
    
    return parsed_bar           
end



function update_timing(song)
    -- Update the base note length (in seconds), given the current L and Q settings
    local total_note = 0
    local rate = 0
   
    
    for i,v in ipairs(song.internal.tempo) do
        total_note = total_note + (v.num / v.den)
    
    end                
    
    
    rate = 60.0 / (total_note * song.internal.tempo.div_rate)

    song.internal.base_note_length = rate / song.internal.note_length
    
    -- grace notes assumed to be 32nds
    song.internal.grace_note_length = rate / 32
end    



    
function parse_abc_line(line, song)
    -- Parse one line of ABC, updating the song
    -- datastructure. Temporary state is held in
    -- song.internal, which can be used to carry over 
    -- information from line to line
    
    
    -- strip whitespace from start and end of line
    line = line:gsub('^%s*', '')
    line = line:gsub('%s*$', '')
    
    -- remove any backquotes
    line = line:gsub('`', '')
    
    
    -- strip comments
    line = line:gsub("%%.*", "")
        
    --
    -- read tune
    --
    if not song.internal.in_header then
    
        -- try and match notes
        local match = tune_matcher:match(line)
        
        -- if it was a tune line, then parse it
        -- (if not, it should be a metadata field)
        if match then
            -- we found tune notes; this isn't a file header
            song.internal.has_notes = true
            
            -- insert linebreaks if there is not a continuation symbol
            if  not match[#match].continuation then
                table.insert(match, {linebreak=''})    
            end                             
            read_tune_segment(match, song)
        end
    end
    
    --
    -- read header or metadata
    --       
    -- read metadata fields
    parse_field(line, song)
      
    -- check if we've read the complete header; terminated on a key
    if song.metadata.key and song.internal.in_header then
        song.internal.in_header = false
        song.header = deepcopy(song.metadata)        
    end

  
end    


function finalise_song(song)
    -- Finalise a song's event stream
    -- Composes the parts, repeats into a single stream
    -- Inserts absolute times into the events 
    -- Inserts the lyrics into the song

    compose_parts(song)
    
    -- clear temporary data
    song.opus = nil
    song.temp_part = nil 
 
    -- time the stream and add lyrics
    time_stream(song.stream)
    song.stream = insert_lyrics(song.internal.lyrics, song.stream)
end
    

function parse_abc(str, metadata, internal)
    -- Parse an entire ABC tune and return
    -- a song datastructure. 
    -- 
    -- The song contains
    -- song.journal contains the song as a parsed symbol sequence
    -- this is one-to-one mappable to the ABC file, and contains events as they are read
    -- from the file
    
    -- song.stream: a series of events (e.g. note on, note off)
    --  indexed by microseconds,
    -- song.metadata which contains header data about title, reference number, key etc.
    --  stored as plain text
    -- song.internal contains all of the parsed song data
    -- song.lyrics contains the lyrics
    
    
    internal.in_header = true
    internal.has_notes = false
    internal.lyrics = {}
    internal.current_part = 'default'
    internal.part_map = {}
    internal.pattern_map = {}
    internal.triplet_state = 0
    internal.triplet_compress = 1
    
    temp_part = {}
    opus = temp_part
    song = {opus=opus, metadata=metadata, header = {}, internal=internal, journal={}, parse={}, temp_part=temp_part}
    
    lines = split(str, "[\r\n]")
    
    song.lines = lines
    update_timing(song) -- make sure default timing takes effect
    
    for i,line in pairs(lines) do 
        song.internal.line_number = i
        parse_abc_line(line, song)
    end
    
    finalise_song(song)
    notes = get_note_stream(song.stream)
    
    make_midi(notes, 'skye.mid')
    return song
end


function parse_all_abc(str)
         
    -- split file into sections
    local section_pattern = [[
     abc_tunes <- ((tune break +) * (tune)) -> {}
     break <- ([ ] * %nl )
     tune <- {   (line +)}
     line <- ( ([^%nl] +  %nl) )
    ]] 
    
    -- tunes must begin with a field (although there
    -- can be directives or comments first)
    local sections = re.match(str, section_pattern)
    local tunes = {}
    local tune_pattern = [[
        tune <- (comment * field + line *)
        comment <- ('%' line)
        field <- ([a-zA-Z] ':' line)
        line <- ( ([^%nl] +  %nl) )
        
    ]]
    
    -- only include patterns with a field in them; ignore 
    -- free text blocks
    for i,v in ipairs(sections) do
        if re.match(v, tune_pattern) then
            table.insert(tunes, v)  
        end
    end
    
    -- set defaults for the whole tune
    default_metadata = {}
    
    default_internal = {
    tempo = {div_rate=120, [1]={num=1, den=8}}, 
    note_length = 8,
    use_parts = false,
    meter_data = {num=4, den=4},
    key_data = {0,0,0,0,0,0,0,0},
    global_transpose = 0,
    }
    
    -- no tunes!
    if #tunes<1 then
        return {}
    end
    
    songs = {}
    
    -- first tune might be a file header
    first_tune = parse_abc(tunes[1], deepcopy(default_metadata), deepcopy(default_internal))
    table.insert(songs, first_tune)
    
    -- if no notes, is a global header for this whole file
    if not first_tune.has_notes then
        default_metadata = first_tune.metadata
        default_internal = first_tune.internal
    end
    
    -- add remaining tunes, using file header as default, if needed
    for i,v in ipairs(tunes) do
        -- don't add first tune twice
        if i~=1 then
            tune = parse_abc(v, deepcopy(default_metadata), deepcopy(default_internal))
            table.insert(songs, tune)
        end
    end
    
    
end

function parse_abc_file(filename)
    -- Read a file and send it for parsing. Returns the 
    -- corresponding song table.
    f = io.open(filename, 'r')
    contents = f:read('*a')
    return parse_all_abc(contents)
end

-- Does not support:
-- multiple voices
-- instruction flag
-- macros

-- TODO:
-- accidental rules (rest of measure, except in K:none)
-- song -> journal -> opus -> stream -> midi

-- create test suite
-- styling for playback
-- chords "Cm7" before slurs or chord groups (e.g. "Cm7"[cd#gb])
-- multi-bar rests (Z3 etc.)
-- abc writing
parse_abc_file('skye.abc')
print(journal_to_abc(song.journal))