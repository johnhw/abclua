require "utils"
require "keys"
require "parts"
require "notes"
require "lyrics"
require "chords"
require "stream"
require "fields"
require "bar"
require "write_abc"
require "journal"
local re = require "re"


-- Grammar for parsing tune definitions
tune_pattern = [[
elements <- ( ( <element>)  +) -> {}
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


function read_tune_segment(tune_data, song)
    -- read the next token in the note stream
    
    
    for i,v in ipairs(tune_data) do
   
        if v.measure_rest then
            bars = v.measure_rest.bars or 1
            table.insert(song.journal, {event='measure_rest', bars=bars})
        end
        
        -- store annotations
        if v.free_text then
            table.insert(song.journal, {event='text', text=v.free_text})
        end
        
        -- parse inline fields (e.g. [r:hello!])
        if v.field then                
            -- this automatically writes it to the journal
            parse_field(v.field.contents, song, true)
        end
        
        -- deal with triplet definitions
        if v.triplet then                
            
            triplet = parse_triplet(v.triplet, song)
            table.insert(song.journal, {event='triplet', triplet=triplet})
            
        end
        
        -- beam splits
        if v.s then
            table.insert(song.journal, {event='split'})
        end
        
        -- linebreaks
        if v.linebreak then
            table.insert(song.journal, {event='split_line'})
        end
            
        
        -- deal with bars and repeat symbols
        if v.bar then
            bar = parse_bar(v.bar)                                
            table.insert(song.journal, {event='bar', bar=bar})                      
        end
        
        -- chord groups
        if v.chord_group then
            if v.chord_group[1] then
                table.insert(song.journal, {event='chord_begin'})                
                
                -- insert the individual notes
                for i,note in ipairs(v.chord_group) do                
                    local cnote = parse_note(note)
                    table.insert(song.journal, {event='note', note=cnote})    
                end
                table.insert(song.journal, {event='chord_end'})                                
            end                               
            
        end
        
        -- if we have slur groups then there are some notes to parse...
        if v.slur then
            -- slur groups
            if #v.slur>2 then
                table.insert(song.journal, {event='slur_begin'} )
            end
            
            -- insert the individual notes
            for i,note in ipairs(v.slur) do                
                local cnote = parse_note(note)
                table.insert(song.journal, {event='note', note=cnote})
            end
                
            if #v.slur>2 then
                table.insert(song.journal, {event='slur_end'} )
            end

        end
    end
    
end


    
function parse_abc_line(line, song)
    -- Parse one line of ABC, updating the song
    -- datastructure. Temporary state is held in
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
    if not song.parse.in_header then
        -- try and match notes
        local match = tune_matcher:match(line)
        
        -- if it was a tune line, then parse it
        -- (if not, it should be a metadata field)
        if match then

            -- we found tune notes; this isn't a file header
            song.parse.has_notes = true
            
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
    if song.parse.found_key and song.parse.in_header then
        song.parse.in_header = false
        table.insert(song.journal, {event='header_end'})
    end

  
end    

    

function parse_abc(str)
    -- parse and ABC file and return a song with a filled in journal field
    -- representing all of the tokens in the stream
    lines = split(str, "[\r\n]")
    song = {}
    song.journal = {}
    song.parse = {in_header=true, has_notes=false}
    for i,line in pairs(lines) do 
        parse_abc_line(line, song)
    end
    
    
    
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
    use_parts = false,
    meter_data = {num=4, den=4},
    key_data = {0,0,0,0,0,0,0,0},
    global_transpose = 0,
    }
    
    -- no tunes!
    if #tunes<1 then
        return {}
    end
    
    local songs = {}
    
    -- first tune might be a file header
    first_tune = parse_abc(tunes[1]) 
    journal_to_stream(first_tune,  deepcopy(default_internal), deepcopy(default_metadata))
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
            tune = parse_abc(v) 
            journal_to_stream(tune, deepcopy(default_internal), deepcopy(default_metadata))    
            table.insert(songs, tune)
        end
    end
    
    return songs
end

function parse_abc_file(filename)
    -- Read a file and send it for parsing. Returns the 
    -- corresponding song table.
    f = io.open(filename, 'r')
    contents = f:read('*a')
    return parse_all_abc(contents)
end

-- copy parsed header fields into header (add end of header token to journal)

-- Does not support:
-- multiple voices
-- instruction field
-- macros
-- directives

-- TODO:
-- create test suite
-- styling for playback
-- chords "Cm7" before slurs or chord groups (e.g. "Cm7"[cd#gb])
-- multi-bar rests (Z3 etc.)
songs = parse_abc_file('skye.abc')
print_notes(songs[1].stream)
make_midi(get_note_stream(songs[1].stream), 'skye.mid')
print(journal_to_abc(songs[1].journal))
