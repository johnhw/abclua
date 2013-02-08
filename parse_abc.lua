require "utils"
require "keys"
require "parts"
require "notes"
require "lyrics"
require "chords"
require "stream"
require "fields"
local re = require "re"


-- Grammar for parsing tune definitions
tune_pattern = [[
elements <- ( ({} <element>)  +) -> {}
element <- ( ({:slur: <slurred_note> :}) / ({:chord_group: <chord_group> :})  / {:bar: (<bar> / <variant>) :} / {:field: field :}  / {:free_text: free :} / {:triplet: triplet :} / {:s: beam_split :} / {:continuation: continuation :}) -> {}
continuation <- ('\')
beam_split <- (%s +)
free <- ( '"' {:text: [^"]* :} '"' ) -> {}
bar <- ( {:type: ((']' / '[') * ('|' / ':') + (']' / '[') *) :} ({:variant_range: (<range_set>) :}) ? ) -> {}
variant <- {:type: '[' :} {:variant_range: <range_set> :}   -> {}
range_set <- (range (',' range)*)
range <- ([0-9] ('-' [0-9]) ?)
slurred_note <- ( (<complete_note>) -> {} / ('(' (<complete_note> +) ')' )  -> {}  ) 
chord_group <- ( ('[' (<complete_note> +) -> {} ']' ) ) 
complete_note <- (({:grace: (grace)  :}) ?  ({:chord: (chord)  :}) ?  ({:decoration: (decoration) :}) ? {:note_def: full_note  :} ({:tie: (tie)  :}) ? ) -> {}
triplet <- ('(' {[1-9]} (':' {[1-9] ?}  (':' {[1-9]} ? ) ?) ?) -> {}
grace <- ('{' full_note + '}') -> {}
tie <- ('-')
chord <- (["] {[^"]} * ["]) -> {}
full_note <-  (({:pitch: (note) :} / {:rest: (rest) :}) {:duration: (duration ?)  :}  {:broken: (broken ?)  :})  -> {}
rest <- ( 'z' / 'x' )
broken <- ( ('<' +) / ('>' +) )
note <- (({:accidental: (accidental )  :})? ({:note:  ([a-g]/[A-G]) :}) ({:octave: (octave)  :}) ? ) -> {}
decoration <- ('.' / [~] / 'H' / 'L' / 'M' / 'O' / 'P' / 'S' / 'T' / 'u' / 'v' / ('!' [^!] '!') / ('+' [^+] '+'))
octave <- (( ['] / ',') +)
accidental <- ( '^' / '^^' / '_' / '__' / '=' )
duration <- ( {:slashes: ('/' +) ? :} ({:num: ([1-9] +) :} {:den: (('/'  [1-9]+  ) ?) :}))  -> {}
field <- ( {:contents: '['  field_element  ':'  [^] ] +  ']' :}) -> {}
field_element <- ([A-Za-z])

]]

tune_matcher = re.compile(tune_pattern)



function is_compound_time(song)
    -- return true if the meter is 6/8, 9/8 or 12/8
    -- and false otherwise
    local meter = song.internal.meter_data
    if meter then
        if meter.den == 8  then
            if meter.num == 6 or meter.num==9 or meter.num==12 then
                return true
            end
        end
    end
    return false
end


function apply_repeats(song, bar)
        -- clear any existing material
        if bar.start_repeat then
            add_section(song, 1)
        end
                                
        -- append any repeats, and variant endings
        if bar.mid_repeat or bar.end_repeat then
        
           
            add_section(song, bar.end_reps+1)
            
            -- mark that we will now go into a variant mode
            if bar.variant_range then
                song.internal.in_variant = bar.variant_range
            else
                song.internal.in_variant = nil
            end            
        end
        
        -- part variant; if we see this we go into a new part
        if bar.variant then
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
        
            -- store annotations
            if v.free_text then
                table.insert(song.opus, {event='text', text=v.free_text})
            end
            
            -- parse inline fields (e.g. [r:hello!])
            if v.field then                
                parse_field(v.field.contents, song)
                table.insert(song.opus, {event='metadata', text=v.field})
            end
            
            -- deal with triplet definitions
            if v.triplet then                
                triplet = parse_triplet(v.triplet, song)
                table.insert(song.opus, {event='triplet', triplet=triplet})
                
                -- update the internal tuplet state so that timing is correct for the next notes
                song.internal.triplet_compress = triplet.p / triplet.q
                song.internal.triplet_state = triplet.r
            end
            
            -- beam splits
            if v.s then
                table.insert(song.opus, {event='split'})
            end
            
            -- linebreaks
            if v.linebreak then
                table.insert(song.opus, {event='split_line'})
            end
                
            
            -- deal with bars and repeat symbols
            if v.bar then
                bar = parse_bar(v.bar)                                
                table.insert(song.opus, {event='bar', bar=bar})   
                apply_repeats(song, bar)                               
                             
            end
            
            -- chord groups
            if v.chord_group then
                if v.chord_group[1] then
                    table.insert(song.opus, {event='chord_begin'} )
                    
                    -- insert the individual notes
                    for i,note in ipairs(v.chord_group) do                
                        insert_note(note, song)                                                            
                    end
                    
                    table.insert(song.opus, {event='chord_end'})                
                end                               
                
            end
            
            -- if we have slur groups then there are some notes to parse...
            if v.slur then
                -- slur groups
                if #v.slur>2 then
                    table.insert(song.opus, {event='slur_begin'} )
                end
                
                -- insert the individual notes
                for i,note in ipairs(v.slur) do                
                    insert_note(note, song)                                                            
                end
                    
                if #v.slur>2 then
                    table.insert(song.opus, {event='slur_end'} )
                end

                
            end
        end
    end
    
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
        {:mid_repeat: <mid_repeat> :} /  {:end_repeat: <end_repeat> :}  / {:start_repeat: <start_repeat> :} / {:end: <end> :}
        / {:plain: <plain> :} /  {:thick: <thick> :} / {:variant: <variant> :} / {:colons: <just_colons> :} ) -> {}        
        mid_repeat <- ({}<colons> {}<plain>{} <colons>{}) -> {}
        start_repeat <- (<plain> {} <colons> {} ) -> {}
        end_repeat <- ({}<colons> {} <plain> ) -> {}
        end <- (<plain> (<plain> +))
        just_colons <- ({} <colons> {}) -> {}
        plain <- ('|')
        thick <- ('[' * ']'* '|' ']' * '[' *)
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
    if type_info.thick then
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
    end
    
    type_info.variant_range = bar.variant_range
    return type_info           
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


function add_lyrics(song, field)     
    -- add lyrics to a song        
    lyrics = parse_lyrics(field)        
    append_table(song.internal.lyrics, lyrics)
end


    
function parse_abc_line(line, song)
    -- Parse one line of ABC, updating the song
    -- datastructure. Temporary state is held in
    -- song.internal, which can be used to carry over 
    -- information from line to line
    
    if re.find(line, matchers.doctype,1) then
        song.internal.valid_doctype = true
    end
    
    -- strip whitespace
    line = line:gsub('^%s*', '')
    line = line:gsub('%s*$', '')
    
    -- remove any backquotes
    line = line:gsub('`', '')
    
    if line:len()==0 then
        -- blank line found!
        
    end
    
    -- strip comments
    line = line:gsub("%%.*", "")
        
    --
    -- read tune
    --
    if not song.internal.in_header then
    
        -- try and match notes
        local match = tune_matcher:match(line)
        --table_print(match)
           
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
    
    -- read continuation fields
    contd = re.match(line, [[('+:' %s * {.*}) -> {}]])
    if contd then                
        song.metadata[song.internal.last_field] = song.metadata[song.internal.last_field] .. ' ' .. contd[1]
        
        -- make sure lyrics continue correctly. Example:
        -- w: oh this is a li-ne
        -- +: and th-is fol-lows__
        if song.internal.last_field=='words' then
            add_lyrics(song, contd[1])
        end
    end
    
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
    -- song.stream: a series of events (e.g. note on, note off)
    -- indexed by microseconds,
    -- song.metadata which contains header data about title, reference number, key etc.
    -- as plain text
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
    song = {opus=opus, metadata=metadata, header = {}, internal=internal, temp_part=temp_part}
    
    lines = split(str, "[\r\n]")
    
    song.lines = lines
    update_timing(song) -- make sure default timing takes effect
    
    for i,line in pairs(lines) do 
        song.internal.line_number = i
        parse_abc_line(line, song)
    end
    
    finalise_song(song)
    notes = get_note_stream(song.stream)
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

-- TODO: 
-- test variant parts
parse_abc_file('skye.abc')