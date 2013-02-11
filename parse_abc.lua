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
local tune_pattern = [[
elements <- ( ( <element>)  +) -> {}
element <- ( ({:slur: <slurred_note> :}) / ({:chord_group: <chord_group> :})  / {:bar: (<bar> / <variant>) :} / {:field: field :}  / {:free_text: free :} / {:triplet: triplet :} / {:s: beam_split :}  / {:continuation: continuation :}) -> {}

continuation <- ('\')
beam_split <- (%s +)
free <- ( '"' {:text: [^"]* :} '"' ) -> {}
bar <- ( {:type: ((']' / '[') * ('|' / ':') + (']' / '[') *) :} ({:variant_range: (<range_set>) :}) ? ) -> {}
variant <- {:type: '[' :} {:variant_range: <range_set> :}   -> {}
range_set <- (range (',' range)*)
range <- ([0-9] ('-' [0-9]) ?)
slurred_note <- ( (<complete_note>) -> {} / ( ({:chord: chord :} ) ? '(' (<complete_note> +) ')' )  -> {}  ) 
chord_group <- ( ({:chord: chord :} ) ? ('[' (<complete_note> +) ']' ) ) -> {} 
complete_note <- (({:grace: (grace)  :}) ?  ({:chord: (chord)  :}) ?  ({:decoration: {(decoration +)}->{} :}) ? {:note_def: full_note  :} ({:tie: (tie)  :}) ? ) -> {}
triplet <- ('(' {[1-9]} (':' {[1-9] ?}  (':' {[1-9]} ? ) ?) ?) -> {}
grace <- ('{' full_note + '}') -> {}
tie <- ('-')
chord <- (["] {([^"] *)} ["])
full_note <-  (({:pitch: (note) :} / {:rest: (rest) :} / {:measure_rest: <measure_rest> :} ) {:duration: (duration ?)  :}  {:broken: (broken ?)  :})  -> {}
rest <- ( 'z' / 'x' )
measure_rest <- (('Z' / 'X') ({:bars: ([0-9]+) :}) ? ) -> {}
broken <- ( ('<' +) / ('>' +) )
note <- (({:accidental: (accidental )  :})? ({:note:  ([a-g]/[A-G]) :}) ({:octave: (octave)  :}) ? ) -> {}
decoration <- ('.' / [~] / 'H' / 'L' / 'M' / 'O' / 'P' / 'S' / 'T' / 'u' / 'v' / ('!' ([^!] *) '!') / ('+' ([^+] *) '+'))
octave <- (( ['] / ',') +)
accidental <- ( '^' / '^^' / '_' / '__' / '=' )
duration <- ( (({:num: ([1-9] +) :}) ? ({:slashes: ('/' +)  :})?  ({:den: ((  [1-9]+  ) ) :})?))  -> {}
field <- ( {:contents: '['  field_element  ':'  [^] ] +  ']' :}) -> {}
field_element <- ([A-Za-z])

]]
local tune_matcher = re.compile(tune_pattern)

function read_tune_segment(tune_data, song)
    -- read the next token in the note stream
    
    for i,v in ipairs(tune_data) do
   
        if v.measure_rest then
            local bars = v.measure_rest.bars or 1
            table.insert(song.journal, {event='measure_rest', bars=bars})
        end
        
        -- store annotations
        if v.free_text then
            -- could be a standalone chord
            if is_chord(v.free_text.text) then
                table.insert(song.journal, {event='chord', chord=v.free_text.text})
            else
                table.insert(song.journal, {event='text', text=v.free_text.text})
            end
        end
        
        -- parse inline fields (e.g. [r:hello!])
        if v.field then                
            -- this automatically writes it to the journal
            parse_field(v.field.contents, song, true)
        end
        
        -- deal with triplet definitions
        if v.triplet then                                        
            table.insert(song.journal, {event='triplet', triplet=parse_triplet(v.triplet, song)})
            
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
            table.insert(song.journal, {event='bar', bar=parse_bar(v.bar)  })                      
        end
        
        -- chord groups
        if v.chord_group then
        
            -- textual chords
            if v.chord_group.chord then
                table.insert(song.journal, {event='chord', chord=v.chord_group.chord})                                
            end
            
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
            
            if v.slur.chord then
                table.insert(song.journal, {event='chord', chord=v.slur.chord})                                
            end
            
            -- slur groups (only put the group in if there
            -- are more than elements, or there is an associated chord name)
            if #v.slur>1  then
                table.insert(song.journal, {event='slur_begin'} )
               
            end
            
            -- insert the individual notes
            for i,note in ipairs(v.slur) do                
                local cnote = parse_note(note)                
                table.insert(song.journal, {event='note', note=cnote})
            end
                
            if #v.slur>1 then
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
    
    -- replace stylesheet directives with I: information fields
    line = line:gsub("^%%%%", "I:")    
    
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
            
            -- check for macros
            if #song.parse.macros>0 or #song.parse.user_macros>0  then
                local expanded_line = apply_macros(song.parse.macros, line)
                expanded_line = apply_macros(song.parse.user_macros, expanded_line)
                if expanded_line ~= line then
                    -- macros changed this line; must now re-parse the line
                    match = tune_matcher:match(expanded_line)
                    if not match then
                        warn('Macro expansion produced invalid output '..line..expanded_line)
                        return -- if macro expansion broke the parsing, ignore this line
                    end
                end
            end
            
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
    local lines = split(str, "[\r\n]")
    local song = {}
    song.journal = {}
    song.parse = {in_header=true, has_notes=false, macros={}, user_macros={}}
    for i,line in pairs(lines) do 
        local success = pcall(parse_abc_line, line, song)
        if not success then
            warn('Parse error reading line '  .. line)
        end
    end
    
    
    return song 
end
    


function get_default_internal()
    return   deepcopy({
    tempo = {div_rate=120, [1]={num=1, den=8}}, 
    use_parts = false,
    meter_data = {num=4, den=4},
    key_data = {0,0,0,0,0,0,0,0},
    global_transpose = 0,
    })
end
    
    
function parse_all_abc(str)
         
    -- split file into sections
   
    
    str = str..'\n'
    local section_pattern = [[
     abc_tunes <- (section (break section) * last_line ?) -> {}
     break <- (([ ] * %nl)  )
     section <- { (line +)  }
     line <- ( ([^%nl] +  %nl) )
     last_line <- ( ([^%nl]+) )
    ]] 
    
    
    -- tunes must begin with a field (although there
    -- can be directives or comments first)
    local sections = re.match(str, section_pattern)
    local tunes = {}
    local tune_pattern = [[
        tune <- (comment * field + line *)
        comment <- ('%' [^%] line)
        field <- ([a-zA-Z] ':' line) / ('%%' line)
        line <- ( ([^%nl] +  %nl) )
        
    ]]
    
    -- malformed file
    if not sections or #sections==0 then
        return {}
    end
   
    -- only include patterns with a field in them; ignore 
    -- free text blocks
    for i,v in ipairs(sections) do
        if re.match(v, tune_pattern) then
            table.insert(tunes, v)  
        end
    end
    
    -- set defaults for the whole tune
    local default_metadata = {}
    
    local default_internal = get_default_internal()
    
    -- no tunes!
    if #tunes<1 then
        return {}
    end
    
    local songs = {}
    
    -- first tune might be a file header
    local first_tune = parse_abc(tunes[1]) 
    journal_to_stream(first_tune,  deepcopy(default_internal), deepcopy(default_metadata))
    table.insert(songs, first_tune)
    
  
    -- if no notes, is a global header for this whole file
    if not first_tune.parse.has_notes then
        default_metadata = first_tune.metadata
        default_internal = first_tune.internal
    end
    
   
    -- add remaining tunes, using file header as default, if needed
    for i,v in ipairs(tunes) do
        -- don't add first tune twice
        if i~=1 then
            local tune = parse_abc(v) 
            journal_to_stream(tune, deepcopy(default_internal), deepcopy(default_metadata))    
            table.insert(songs, tune)
        end
    end
    
    return songs
end

function parse_abc_file(filename)
    -- Read a file and send it for parsing. Returns the 
    -- corresponding song table.
    local f = io.open(filename, 'r')
    local contents = f:read('*a')
    return parse_all_abc(contents)
end

-- Does not support:

-- fix part handling
-- function for parsing an abc fragement (e.g. parse_abc_fragment('Ab')
-- function for rendering a journal fragment in a context (extract_abc(song, fragment))
-- convert midi to abc (quantize, find key, map notes, specify chord channel (and match chords))
--directives table from I: fields
--check for misused globals


-- TODO:
-- grace notes
-- create test suite
-- styling for playback
-- tolerant error handling

