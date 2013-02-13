-- Grammar for parsing tune definitions
local tune_pattern = [[
elements <- ( ( <element>)  +) -> {}
element <- (  {:field: field :}  / ({:slur: <slurred_note> :}) / ({:chord_group: <chord_group> :})  / {:overlay: <overlay> :} / {:bar: (<bar> / <variant>) :}   / {:free_text: free :} / {:triplet: triplet :} / {:s: beam_split :}  / {:continuation: continuation :}) -> {}

overlay <- ('&')
continuation <- ('\')
beam_split <- (%s +)
free <- ( '"' {:text: [^"]* :} '"' ) -> {}
bar <- ( {:type: ((']' / '[') * ('|' / ':') + (']' / '[') *) :} ({:variant_range: (<range_set>) :}) ? ) -> {}
variant <- ({:type: '[' :} {:variant_range: <range_set> :})   -> {}
range_set <- (range (',' range)*)
range <- ([0-9] ('-' [0-9]) ?)
slurred_note <- ( ((<complete_note>) -> {}) / ( ({:chord: chord :} ) ? '(' ((<complete_note> %s*)+) ')' )  -> {}  ) 


chord_group <- ( ({:chord: chord :} ) ? ('[' ((<complete_note> %s*) +) ']' ) ) -> {} 
complete_note <- (({:grace: (grace)  :}) ?  ({:chord: (chord)  :}) ?  ({:decoration: {(decoration +)}->{} :}) ?  {:note_def: full_note :}  (%s * {:tie: (tie)  :}) ? ) -> {} 
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
accidental <- (  '^^' /  '__' /  '^' / '_' / '=' )
duration <- ( (({:num: ([1-9] +) :}) ? ({:slashes: ('/' +)  :})?  ({:den: ((  [1-9]+  ) ) :})?))  -> {}

field <- (  '['  {:contents: field_element  ':'  [^]`] + :} ']' ) -> {}
field_element <- ([A-Za-z])

]]
local tune_matcher = re.compile(tune_pattern)

function read_tune_segment(tune_data, song)
    -- read the next token in the note stream
    
    for i,v in ipairs(tune_data) do
        
        if v.measure_rest then
            local bars = v.measure_rest.bars or 1
            table.insert(song.token_stream, {token='measure_rest', bars=bars})
        end
        
        -- store annotations
        if v.free_text then
            -- could be a standalone chord
            if is_chord(v.free_text.text) then
                table.insert(song.token_stream, {token='chord', chord=v.free_text.text})
            else
                table.insert(song.token_stream, {token='text', text=v.free_text.text})
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
            table.insert(song.token_stream, {token='overlay'})
        end
        
        -- beam splits
        if v.s then
            table.insert(song.token_stream, {token='split'})
        end
        
        -- linebreaks
        if v.linebreak then
            table.insert(song.token_stream, {token='split_line'})
        end
            
        
        -- deal with bars and repeat symbols
        if v.bar then            
            table.insert(song.token_stream, {token='bar', bar=parse_bar(v.bar)  })                      
        end
        
        -- chord groups
        if v.chord_group then
        
            -- textual chords
            if v.chord_group.chord then
                table.insert(song.token_stream, {token='chord', chord=v.chord_group.chord})                                
            end
            
            if v.chord_group[1] then
                table.insert(song.token_stream, {token='chord_begin'})                                
                -- insert the individual notes
                for i,note in ipairs(v.chord_group) do                
                    local cnote = parse_note(note)
                    table.insert(song.token_stream, {token='note', note=cnote})                        
                end
                table.insert(song.token_stream, {token='chord_end'})                                
            end                               
            
        end
        
        -- if we have slur groups then there are some notes to parse...
        if v.slur then            
            if v.slur.chord then
                table.insert(song.token_stream, {token='chord', chord=v.slur.chord})                                
            end
            
            -- slur groups (only put the group in if there
            -- are more than elements, or there is an associated chord name)
            if #v.slur>1  then
                table.insert(song.token_stream, {token='slur_begin'} )
               
            end
            
            -- insert the individual notes
            for i,note in ipairs(v.slur) do                
                
                local cnote = parse_note(note)                
                table.insert(song.token_stream, {token='note', note=cnote})
            end
                
            if #v.slur>1 then
                table.insert(song.token_stream, {token='slur_end'} )
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
        
        -- try and match notes
        local match = tune_matcher:match(line)
                
        -- if it was a tune line, then parse it
        -- (if not, it should be a metadata field)
        if match then            
        
            -- check for macros
            if not song.parse.no_expand and (#song.parse.macros>0 or #song.parse.user_macros>0)  then               
                match = expand_macros(song, line)
                if not match then 
                    return nil -- bad macro messed this line up
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
    
    
end    


function parse_abc_song(song, str)    
    -- parse an ABC file and fill in the song structure
    -- this is a separate method so that recursive calls can be made to it 
    -- to include subfiles
    local lines = split(str, "[\r\n]")
    for i,line in pairs(lines) do 
        --parse_abc_line(line, song)
        
        local success, err = pcall(parse_abc_line, line, song)
        if not success then
            warn('Parse error reading line '  .. line.. '\n'.. err)
        end
    end
end
    

function parse_abc(str, options)
    -- parse and ABC file and return a song with a filled in token_stream field
    -- representing all of the tokens in the stream    
    local song = {}    
    
    song.token_stream = {}
    options = options or {}    
    song.parse = {in_header=true, has_notes=false, macros={}, user_macros={}, no_expand=options.no_expand or false}    
    parse_abc_song(song, str)
     
    return song 
end
    
function compile_abc(str, options)
    -- parse an ABC string and compile it
    song = parse_abc(str, options) 
    compile_token_stream(song,  get_default_context(), {})    
    return song
end
    
function get_default_context()
    return   deepcopy({
    tempo = {tempo_rate=120, [1]={num=1, den=8}}, 
    use_parts = false,
    meter_data = {num=4, den=4},
    key = { root='C', mode='maj', clef={}},
    key_mapping = {c=0,d=0,e=0,f=0,g=0,a=0,b=0},
    global_transpose = 0,
    grace_length = {num=1, den=32}
    })
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
    compile_token_stream(first_tune,  deepcopy(default_context), deepcopy(default_metadata))
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

function parse_abc_fragment(str, parse, options)
    -- Parse a short abc fragment, and return the token stream table
    local song = {}
    options = options or {}
    song.token_stream = {}
    
    -- use default parse structure if not one specified
    song.parse = parse or {in_header=false, has_notes=false, macros={}, user_macros={}, no_expand=options.no_expand}    
    if not pcall(parse_abc_line, str, song) then
        song.token_stream = nil -- return nil if the fragment is unparsable
    end
    return song.token_stream
end

function compile_tokens(tokens, context)
    --Converts a token stream from a fragment into a timed event stream
    -- Returns the event stream if this is a single voice fragment, or
    -- a table of voices, if it is a multi-voice fragment
    --
    -- Note that this is a relatively slow function to execute, as it
    -- must copy the context, expand the stream and then finalise the song
    context = context or get_default_context()
    
    local song = {context=deepcopy(context), token_stream=tokens}
            
    song.voices = {}
    song.metadata = {}
    start_new_voice(song, 'default')
    expand_token_stream(song)    
    
    -- finalise the voice
    start_new_voice(song, nil)
    
    if #song.voices>1 then
        local voice_stream = {}
        -- return a table of voices
        for i,v in pairs(song.voices) do
            voice_streams[i] = v.stream
        end
        return voice_streams
    else    
        -- return the default voice stream
        return song.voices['default'].stream    
    end
end


-- module exports
abclua = {
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
register_user_directive = register_user_directive,
abc_from_songs = abc_from_songs,
abc_element = abc_element
}



-- TODO:

-- render decorations
-- match against instrument notes (penalties for notes)

-- transposing macros don't work when octave modifiers and ties are applied
-- tidy up stream rendering
-- voice transpose/octave/+8-8

-- fix lyrics alignment (2.0 compatible and verses)


-- styling for playback
-- decorators with extended effect (e.g. crescendo, accelerando)



