-- Grammar for parsing tune definitions

function expand_macros(song, line)
    -- expand any macros in a line   
    local converged = false
    local iterations = 0
    local expanded_line
    
    -- ignore blank lines
    if string.len(line)==0 then return nil end
    expanded_line = apply_macros(song.parse.macros, line)    
    -- macros changed this line; must now re-parse the line
    match = abc_body_parser(expanded_line)
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
    line = line:gsub('^[%s]*', '')
                
    -- replace stylesheet directives with I: information fields
    line = line:gsub("^%%%%", "I:")    
    local field_parsed
    
    
    -- read metadata fields    
    if song.parse.in_header or string.sub(line,2,2)==':' then        
        field_parsed = parse_field(line, song)
        if song.parse.found_key and song.parse.in_header then
            song.parse.in_header = false
            table.insert(song.token_stream, {token='header_end'})
        end    
    end
         
    --
    -- read tune
    --
    if not field_parsed and not song.parse.in_header then
        local match
        if not song.parse.no_expand and (#song.parse.macros>0)  then               
            match = expand_macros(song, line)                
        else
            match = abc_body_parser(line)
        end
                
        -- if it was a tune line, then parse it
        -- (if not, it should be a metadata field)
        if match then                                           
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


local line_splitter = re.compile([[
lines <- (%nl* ({[^%nl]+} %nl*)+) -> {}
]])

function parse_abc_string(song, str)    
    -- parse an ABC file and fill in the song structure
    -- this is a separate method so that recursive calls can be made to it 
    -- to include subfiles            
    local lines = line_splitter:match(str)    
    if lines then
        for i=1,#lines do        
            song.parse.line = i        
            local success, err = pcall(parse_abc_line, lines[i], song)
            if not success then
                warn('Parse error reading line '  .. lines[i].. '\n'.. err)
            end
        end
    end
end
    
function default_user_macros()
    -- return the set of default user macros
    return 
    {
      ['~'] = '!roll!',
      ['.'] = '!staccato!',
      H = '!fermata!',
      L = '!accent!',
      M = '!lowermordent!',
      O = '!coda!',
      P = '!uppermordent!',
      S = '!segno!',
      T = '!trill!',
      u = '!upbow!',
      v = '!downbow!'
    }   
        
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
    
    song.parse = {in_header=in_header, has_notes=false, macros={}, user_macros=default_user_macros(), measure = options.measure or 1, no_expand=options.no_expand or false, cross_ref=options.cross_ref or false}    
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
    default_note_length = 8,
    write_abc_events = false
    }
end
    
local section_matcher = re.compile([[
     abc_tunes <- (section (break+ section) * last_line ?) -> {}
     break <- (([ ] * %nl)  )
     section <- { (line +)  }
     line <- ( ([^%nl] +  %nl) )
     last_line <- ( ([^%nl]+) )
    ]] 
)    

function parse_and_compile(tune_str, options, context, metadata)
    -- parse a tune and compile it; returns nil if cannot be parsed or compiled
    local success, tune = pcall(parse_abc,tune_str,options)
    if not success then 
        warn("Could not parse tune beginning: "..string.sub(tune_str, 1, 64)) 
        warn(tune)
        return nil
    end
    local success,err  = pcall(compile_token_stream,tune,context,metadata)
    if not success then 
        warn("Could not compile tune beginning: "..string.sub(tune_str, 1, 64)) 
        warn(err)
        return nil
    end
    return tune
end

function songbook_block_iterator(str, options)
    -- Iterator for iterating through tune blocks in a songbook    
    str = str..'\n'
    return coroutine.wrap( 
        function ()                
        -- tunes must begin with a field (although there
        -- can be directives or comments first)
        local sections = section_matcher:match(str)
         
        -- malformed file
        if not sections or #sections==0 then
            return 
        end
        
        -- only include patterns with a field in them; ignore 
        -- free text blocks
        for i,v in ipairs(sections) do    
            if v:gmatch('\n[a-zA-Z]:') then                            
                coroutine.yield(v)
            end
        end
    end)
    
end


function parse_abc_coroutine(str, options)
    -- Iterator for iterating through tunes in a songbook
    -- This is preferable to just reading the entire thing into an table
    -- as it saves memory.
    -- split file into sections
   
    local iterator = songbook_block_iterator(str, options)
        
    -- set defaults for the whole tune
    local default_metadata = {}
    local default_context = get_default_context()
    
    local tune_str 
    tune_str = iterator()
    
    if not tune_str then
        return -- no tunes at all
    end
    
    -- first tune might be a file header
    local first_tune = parse_and_compile(tune_str, options, default_context, default_metadata)
    
    -- if no notes, is a global header for this whole file
    if first_tune and not first_tune.parse.has_notes then
        default_metadata = first_tune.metadata
        default_context = first_tune.context
    else
        default_metadata = {}
        default_context = get_default_context()
    end
    
    -- return the first tune
    coroutine.yield(first_tune)
    
    -- remaining tunes
    tune_str = iterator()
    while tune_str do
        coroutine.yield(parse_and_compile(tune_str, options, deepcopy(default_context), deepcopy(default_metadata)))    
        tune_str = iterator()
    end
end

function parse_abc_song_iterator(str, options)
    -- return an iterator to iterate over songs in a songbook
    return coroutine.wrap(function() parse_abc_coroutine(str, options)end)
end

function parse_abc_multisong(str, options) 
    -- return a table of songs from a songbook
    local songs = {}
    for song in parse_abc_song_iterator(str, options) do
        table.insert(songs, song)
    end
    return songs 
end

function parse_abc_file(filename, options)
    -- Read a file and send it for parsing. Returns the 
    -- corresponding song table.
    local f = io.open(filename, 'r')
    assert(f, "Could not open file "..filename)
    local contents = f:read('*a')
    return parse_abc_multisong(contents, options)
end

function parse_abc_fragment(str, options)
    -- Parse a short abc fragment, and return the token stream table    
    options = options or {}    
    local song = parse_abc(str, options, options.in_header or false)
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
precompile_token_stream = precompile_token_stream,
parse_abc_song_iterator = parse_abc_song_iterator,
scan_metadata = scan_metadata,
songbook_block_iterator = songbook_block_iterator,
version=0.2,
}


return abclua
-- TODO:

-- Text string encodings
-- Make automatic tune reproduce tester
-- ABCLint -> check abc files for problems
-- Fix lyrics in repeats/parts
-- Cross ref: change to adding field to tokens and make index from start of file in block mode
-- Support I:linebreak
-- Merge adding ABC notation into event tokens

-- MIDI error on repeats with chords (doubles up chords)
-- transposing macros don't work when octave modifiers and ties are applied

-- Q:
-- multiple chords on one note
-- state changes in repeats/parts
-- user macros in symbol lines

