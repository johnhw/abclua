-- Grammar for parsing tune definitions

-- The master grammar
local tune_pattern = [[
elements <- ( ({}  <element>)  +) -> {}
element <- (  {:field: field :}  / ({:slur: <slurred_note> :}) / ({:chord_group: <chord_group> :})  / {:overlay: <overlay> :} / {:bar: (<bar> / <variant>) :}   / {:free_text: free :} / {:triplet: triplet :} / {:s: beam_split :}  / {:continuation: continuation :}) -> {}

overlay <- ('&' +)
continuation <- ('\')
beam_split <- (%s +)
free <- ( '"' {:text: [^"]* :} '"' ) -> {}
bar <- ( {:type: ((']' / '[') * ('|' / ':') + (']' / '[') *) :} ({:variant_range: (<range_set>) :}) ? ) -> {}
variant <- ({:type: '[' :} {:variant_range: <range_set> :})   -> {}
range_set <- (range (',' range)*)
range <- ([0-9] ('-' [0-9]) ?)
slurred_note <- ( ((<complete_note>) -> {}) / ( ({:chord: chord :} ) ? '(' ((<complete_note> %s*)+) ')' )  -> {}  ) 


chord_group <- ( ({:chord: chord :} ) ? ('[' ((<complete_note> %s*) +) ']' ) ) -> {} 
complete_note <- (({:grace: (grace)  :}) ?  ({:chord: (chord)  :}) ?  ({:decoration: ({decoration} +)->{} :}) ?  {:note_def: full_note :}  (%s * {:tie: (tie)  :}) ? ) -> {} 
triplet <- ('(' {[1-9]} (':' {[1-9] ?}  (':' {[1-9]} ? ) ?) ?) -> {}
grace <- ('{' full_note + '}') -> {}
tie <- ('-')
chord <- (["] {([^"] *)} ["])
full_note <-  (({:pitch: (note) :} / {:rest: (rest) :} / {:space: (space) :}/{:measure_rest: <measure_rest> :} ) {:duration: (duration ?)  :}  {:broken: (broken ?)  :})  -> {}
rest <- ( 'z' / 'x' )
space <- 'y'
measure_rest <- (('Z' / 'X')  ) -> {}
broken <- ( ('<' +) / ('>' +) )
note <- (({:accidental: ({accidental} duration ? ) -> {}  :})? ({:note:  ([a-g]/[A-G]) :}) ({:octave: (octave)  :}) ? ) -> {}
decoration <- ( ('!' ([^!] *) '!') / ('+' ([^+] *) '+') / '.' / [~] / 'H' / 'L' / 'M' / 'O' / 'P' / 'S' / 'T' / 'u' / 'v' )
octave <- (( ['] / ',') +)
accidental <- ( ('^^' /  '__' /  '^' / '_' / '=')   ) 
duration <- ( (({:num: ([1-9] +) :}) ? ({:slashes: ('/' +)  :})?  ({:den: ((  [1-9]+  ) ) :})?))  -> {}

field <- (  '['  {:contents: field_element  ':'  [^]`] + :} ']' ) -> {}
field_element <- ([A-Za-z])

]]
local tune_matcher = re.compile(tune_pattern)


function parse_free_text(text)
    -- split off an annotation symbol from free text, if it is there
    local annotations = {'^', '_', '@', '<', '>'}
    -- separate annotation symbols
    local position, new_text
    if string.len(text)>1 and is_in(string.sub(text,1,1), annotations) then
        position = string.sub(text,1,1)
        new_text = string.sub(text,2)
    else
        new_text = text
    end
    return position, new_text
end

function add_note_to_stream(token_stream, note)
    -- add a note to the token stream
    local cnote = parse_note(note)    
    if cnote.free_text then
            local position, text = parse_free_text(cnote.free_text)                   
            table.insert(token_stream, {token='text', text=text, position = position})                            
            cnote.free_text = nil
    end
    table.insert(token_stream, {token='note', note=cnote})          
 end

function read_tune_segment(tune_data, song)
    -- read the next token in the note stream    
    local cross_ref = nil
    for i,v in ipairs(tune_data) do
        
        if type(v) == 'number' then
            -- insert cross refs, if they are enabled
            if song.parse.cross_ref then
                 table.insert(song.token_stream, {token='cross_ref', at=v, line=song.parse.line})
            end
        else
                    
            -- store annotations
            if v.free_text then
                -- could be a standalone chord
                local chord = parse_chord(v.free_text.text)                                                
                if chord then
                    table.insert(song.token_stream, {token='chord', chord=chord})
                else
                    local position, text = parse_free_text(v.free_text.text)                   
                    table.insert(song.token_stream, {token='text', text=text, position = position})
                end
            end
            
            -- parse inline fields (e.g. [r:hello!])
            if v.field then                
                -- this automatically writes it to the token_stream            
                parse_field(v.field.contents, song, true)
            end
            
            -- deal with triplet definitions
            if v.triplet then                                        
                table.insert(song.token_stream, {token='triplet', triplet=parse_triplet(v.triplet, song)})
                
            end
            
            -- voice overlay
            if v.overlay then
                table.insert(song.token_stream, {token='overlay', bars=string.len(v.overlay)})
            end
            
            -- beam splits
            if v.s then
                table.insert(song.token_stream, {token='split'})
            end
            
            -- linebreaks
            if v.linebreak then
                table.insert(song.token_stream, {token='split_line'})
            end
            
            if v.continue_line then
                table.insert(song.token_stream, {token='continue_line'})
            end
                                        
            -- deal with bars and repeat symbols
            if v.bar then   
                local bar = parse_bar(v.bar)
                if bar.type ~= 'variant' then
                    song.parse.measure = song.parse.measure + 1 -- record the measures numbers as written
                end
                bar.measure = song.parse.measure
                table.insert(song.token_stream, {token='bar', bar=bar})               
            end
            
            -- chord groups
            if v.chord_group then
            
                -- textual chords
                if v.chord_group.chord then
                    table.insert(song.token_stream, {token='chord', chord=parse_chord(v.chord_group.chord)})                                
                end
                
                if v.chord_group[1] then
                    table.insert(song.token_stream, {token='chord_begin'})                                
                    -- insert the individual notes
                    for i,note in ipairs(v.chord_group) do                
                        add_note_to_stream(song.token_stream, note)                        
                    end
                    table.insert(song.token_stream, {token='chord_end'})                                
                end                               
                
            end
            
            -- if we have slur groups then there are some notes to parse...
            if v.slur then            
                if v.slur.chord then
                    table.insert(song.token_stream, {token='chord', chord=parse_chord(v.slur.chord)})                                
                end
                
                -- slur groups (only put the group in if there
                -- are more than elements, or there is an associated chord name)
                if #v.slur>1  then
                    table.insert(song.token_stream, {token='slur_begin'} )
                   
                end
                
                -- insert the individual notes
                for i,note in ipairs(v.slur) do                                    
                    add_note_to_stream(song.token_stream, note)
                end
                    
                if #v.slur>1 then
                    table.insert(song.token_stream, {token='slur_end'} )
                end
            end
        end
    end
    
end


function expand_macros(song, line)
    -- expand any macros in a line   
    local converged = false
    local iterations = 0
    local expanded_line
    
    expanded_line = apply_macros(song.parse.macros, line)
    expanded_line = apply_macros(song.parse.user_macros, expanded_line)
     
    -- macros changed this line; must now re-parse the line
    match = tune_matcher:match(expanded_line)
    if not match then
        warn('Macro expansion produced invalid output '..line..expanded_line)
        return nil -- if macro expansion broke the parsing, ignore this line
    end
    
    return match    
    
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
    -- read header or metadata
    --       
    -- read metadata fields
    local field_parsed = parse_field(line, song)
      
   
    -- check if we've read the complete header; terminated on a key
    if song.parse.found_key and song.parse.in_header then
        song.parse.in_header = false
        table.insert(song.token_stream, {token='header_end'})
    end
        
    --
    -- read tune
    --
    if not field_parsed and not song.parse.in_header then
        local match
        if not song.parse.no_expand and (#song.parse.macros>0 or #song.parse.user_macros>0)  then               
                match = expand_macros(song, line)                
        else
            match = tune_matcher:match(line)
        end
                
        -- if it was a tune line, then parse it
        -- (if not, it should be a metadata field)
        if match then            
        
            -- check for macros           
            
            -- we found tune notes; this isn't a file header
            song.parse.has_notes = true
            
            -- insert linebreaks if there is not a continuation symbol
            if  not match[#match].continuation then
                table.insert(match, {linebreak=''})    
            else
                table.insert(match, {continue_line=''})    
            end
            
            read_tune_segment(match, song)
        end
    end
    
    
end    


function parse_abc_string(song, str)    
    -- parse an ABC file and fill in the song structure
    -- this is a separate method so that recursive calls can be made to it 
    -- to include subfiles
    
    
    local lines = split(str, "[\r\n]")
    for i,line in pairs(lines) do        
        song.parse.line = i
        --parse_abc_line( line, song)
        local success, err = pcall(parse_abc_line, line, song)
        if not success then
            warn('Parse error reading line '  .. line.. '\n'.. err)
        end
    end
end
    

function parse_abc(str, options, in_header)
    -- parse and ABC file and return a song with a filled in token_stream field
    -- representing all of the tokens in the stream    
    local song = {}    
    
    song.token_stream = {}
    options = options or {}    
    -- default to being in the header
    if in_header==nil then
        in_header = true
    end
    song.parse = {in_header=in_header, has_notes=false, macros={}, user_macros={}, measure = options.measure or 1, no_expand=options.no_expand or false, cross_ref=options.cross_ref or false}    
    parse_abc_string(song, str)
     
    return song 
end
    
function compile_abc(str, options)
    -- parse an ABC string and compile it
    song = parse_abc(str, options) 
    compile_token_stream(song,  get_default_context(), {})    
    return song
end
    
function get_default_context()
    return   {
    tempo = {tempo_rate=120, [1]={num=1, den=8}}, 
    use_parts = false,
    meter = {num=4, den=4},
    key = { root='C', mode='maj', clef={}},
    key_mapping = {c=0,d=0,e=0,f=0,g=0,a=0,b=0},
    global_transpose = 0,
    voice_transpose = 0,
    grace_length = {num=1, den=32},
    propagate_accidentals = 'pitch',
    accidental = {},
    directives = {},
    broken_ratio=2,
    write_abc_events = false
    }
end
    
local section_matcher = re.compile([[
     abc_tunes <- (section (break section) * last_line ?) -> {}
     break <- (([ ] * %nl)  )
     section <- { (line +)  }
     line <- ( ([^%nl] +  %nl) )
     last_line <- ( ([^%nl]+) )
    ]] 
)    
function parse_abc_multisong(str, options)
         
    -- split file into sections
   
    
    str = str..'\n'
    
    -- tunes must begin with a field (although there
    -- can be directives or comments first)
    local sections = section_matcher:match(str)
    local tunes = {}    
    
    -- malformed file
    if not sections or #sections==0 then
        return {}
    end
   
    -- only include patterns with a field in them; ignore 
    -- free text blocks
    for i,v in ipairs(sections) do    
        if v:gmatch('\n[a-zA-Z]:') then            
            table.insert(tunes, v)  
        end
    end
        
    -- set defaults for the whole tune
    local default_metadata = {}
    
    local default_context = get_default_context()
    
    -- no tunes!
    if #tunes<1 then
        return {}
    end
    
    local songs = {}
    
    -- first tune might be a file header
    local first_tune = parse_abc(tunes[1], options) 
    compile_token_stream(first_tune,  default_context, default_metadata)
    table.insert(songs, first_tune)
    
    
    -- if no notes, is a global header for this whole file
    if not first_tune.parse.has_notes then
        default_metadata = first_tune.metadata
        default_context = first_tune.context
    end
    
   
    -- add remaining tunes, using file header as default, if needed
    for i,v in ipairs(tunes) do
        -- don't add first tune twice
        if i~=1 then
            local tune = parse_abc(v, options) 
            compile_token_stream(tune, deepcopy(default_context), deepcopy(default_metadata))    
            table.insert(songs, tune)
        end
    end
    
    return songs
end

function parse_abc_file(filename, options)
    -- Read a file and send it for parsing. Returns the 
    -- corresponding song table.
    local f = io.open(filename, 'r')
    local contents = f:read('*a')
    return parse_abc_multisong(contents, options)
end

function parse_abc_fragment(str, options)
    -- Parse a short abc fragment, and return the token stream table    
    options = options or {}
    local song = parse_abc(str, options, false)
    return song.token_stream
end

function compile_tokens(tokens, context)
    --Converts a token stream from a fragment into a timed event stream
    -- Returns the event stream if this is a single voice fragment, or
    -- a table of voices, if it is a multi-voice fragment
    --    
    context = context or get_default_context()
    
    local song = {token_stream=tokens}
    compile_token_stream(song, context, {})
                
    if #song.voices>1 then
        local voice_stream = {}
        -- return a table of voices
        for i,v in pairs(song.voices) do
            voice_streams[i] = {stream=v.stream, context=v.context}
        end
        return voice_streams
    else    
        -- return the default voice stream
        return song.voices['default'].stream, song.voices['default'].context    
    end
end


-- module exports
local abclua = {
name="abclua",
parse_abc_multisong = parse_abc_multisong,
parse_abc = parse_abc,
parse_abc_fragment = parse_abc_fragment,
compile_tokens = compile_tokens,
parse_abc_file = parse_abc_file,
print_notes = print_notes,
print_lyrics_notes = print_lyrics_notes,
emit_abc = emit_abc,
song_to_opus = song_to_opus,
stream_to_opus = stream_to_opus,
make_midi = make_midi,
make_midi_from_stream = make_midi_from_stream,
trim_event_stream = trim_event_stream,
render_grace_notes = render_grace_notes,
register_directive = register_directive,
abc_from_songs = abc_from_songs,
diatonic_transpose = diatonic_transpose,
get_note_stream = get_note_stream,
get_chord_stream = get_chord_stream,
abc_element = abc_element,
validate_token_stream = validate_token_stream,
filter_event_stream = filter_event_stream,
get_note_number = get_note_number,
get_bpm_from_tempo = get_bpm_from_tempo,
printable_note_name = printable_note_name,
version=0.2,
}


return abclua
-- TODO:

-- Allow chords with key-relative values (e.g. "ii", "V", "V7", "I")
-- add tune matcher example
-- Text string encodings
-- Pre-compile phase (without parts/repeats/etc.) -- just fill in real durations and pitches
-- More assertions / test cases

-- ABCLint -> check abc files for problems

-- transposing macros don't work when octave modifiers and ties are applied



