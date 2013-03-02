-- Routines for parsing metadata in headers and inline inside songs

-- create the various pattern matchers



local field_tags = {key = 'K'
,title = 'T'
,ref =  'X'
,area =  'A'
,book =  'B'
,composer =  'C'
,discography =   'D'
,extended = 'E'
,file =   'F'
,group =   'G'
,history =   'H'
,instruction =   'I'
,length =   'L'
,meter =   'M'
,macro =   'm'
,notes =   'N'
,origin =   'O'
,parts =   'P'
,tempo =   'Q'
,rhythm =   'R'
,remark =  'r'
,source =   'S'
,symbol_line =   's'
,user =   'U'
,voice =   'V'
,words =  'w'
,end_words =  'W'
,transcriber =  'Z'
,continuation =  '+'
}

local field_names = invert_table(field_tags)

local parts_matcher = re.compile(
[[
    parts <- (part +) -> {}
    part <- ( ({element}  / ( '(' part + ')' ) )  {:repeat: [0-9]* :}) -> {}    
    element <- [A-Za-z]    
    ]])
    
function parse_parts(m)
    -- Parse a parts definition that specifies the parts to be played
    -- including any repeats
    -- Returns a fully expanded part list
    
    local captures = parts_matcher:match(m)
    
    return captures
    
end


local voice_matcher = re.compile([[
    voice <- (({:id: [%S]+ :}) %s * {:specifiers: (<specifier> *) -> {} :}) -> {}
    specifier <- (%s * {:lhs: ([^=] +) :} + '=' {:rhs: [^%s]* :}) -> {} 
    ]])

function parse_voice(voice)
    -- Parse a voice definition string
    -- Voices of the form V:ID [specifier] [specifier] ...
    -- Returns a table with an ID and a table as used for keys
    -- e.g. V:tenor becomes {id="tenor"}
    
    local parsed_voice = voice_matcher:match(voice)
    return parsed_voice
end



function expand_parts(parts)
    -- Recurisvely expand a parts table into a string
    -- Input is a table with entries which are either an array of tables or
    -- a table with entries [1] = terminal, repeat = repeat count
    local reps = parts['repeat']
    local r
    if not reps or reps=='' then
        r = 1
    else
        r = reps + 0
    end
   
    local sym = ''
    local    t=''
    local i,v
    for i,v in ipairs(parts) do
    
        -- terminal symbol
        if type (v) == "string" then
            t =  t..v
        else
            -- recursive part (i.e. a nested group)
            t = t..expand_parts(v)
        end
    end
    
    -- repeat whatever we got as many times as required
    for i = 1, r do
            sym = sym .. t
    end
       
    return sym
end


function text_token(content, song, field_name)      
    return  {token='field_text', name=field_name, content=content} 
end

function key_token(content, song)
     song.parse.found_key = true -- key marks the end of the header
     return {token='key', key=parse_key(content)}     
end

function length_token(content, song)
        
        return {token='note_length', note_length=parse_length(content)}
end

function tempo_token(content, song)
    local tempo=parse_tempo(content)
    if tempo then
        return  {token='tempo', tempo=tempo}
    end
end

function words_token(content, song) 
        local lyrics = parse_lyrics(content)
        song.parse.last_lyrics = lyrics
        if lyrics then
            return {token='words', lyrics=lyrics}          
        end
end

function instruction_token(content, song)
     local parse_time, directive = parse_directive(content)
     -- + -- must execute parse time directives immediately
     if directive then
         if parse_time and not song.parse.no_expand then
            apply_directive(song, directive.directive, directive.arguments)
         else
            -- + -- otherwise defer
            return {token='instruction', directive=directive}           
         end
     end
end


function voice_token(content, song)    
    local voice = parse_voice(content)
    if voice then                
        ---- in the header this just sets up the voice properties
        if song.parse.in_header then
            return {token='voice_def', voice=voice}
        else
            return {token='voice_change', voice=parse_voice(content)}
        end
    end
end

function user_token(content, song)
    -- user macro for decorations etc.
    if song.parse.no_expand then
        return {token='field_text', name='user', content=content}                   
    else               
        local macro = parse_macro(content)
        if macro then
            -- allow macros to be cleared using !nil!
            if macro.rhs=='!nil!' then
                macro.rhs =nil
            end
            -- assign the macro
            song.parse.user_macros[macro.lhs] = macro.rhs
        end
    end      
end


function parts_token(content, song)
        ---- parts definition if we are still in the header
        ---- look up the parts and expand them out
        if song.parse.in_header then
            local parts = content:gsub('\\.', '') -- remove dots
            parts = parse_parts(content)
            if parts then
                return {token='parts', parts=parts}           
            end
        else            
            ---- otherwise we are starting a new part   
            ---- parts are always one character long, spaces and dots are ignored
            local part = content:gsub('%s', '')
            part = part:gsub('\\.', '')
            part = string.sub(part,1,1)
                        
            return {token='new_part', part=part}           
        end
    
end
    
function meter_token(content, song)    
    -- update meter   
    return {token='meter', meter=parse_meter(content)}              
end

function macro_token(content, song)
    if song.parse.no_expand then
        return {token='field_text', name='macro', content=content}                   
    else
        ---- we DON'T insert macros into the token_stream. Instead
        ---- we expand them as we find them
        local macro = parse_macro(content)
        
        ---- transposing macro
        if re.find(macro.lhs, "'n'") then
            local notes = {'a', 'b', 'c', 'd', 'e', 'f', 'g'}             
            local note                   
            ----- insert one macro for each possible note
            for i,v in ipairs(notes) do
                table.insert(song.parse.macros, transpose_macro(macro.lhs, v, macro.rhs)) 
                table.insert(song.parse.macros, transpose_macro(macro.lhs, string.upper(v), macro.rhs))                                                    
            end
        else
            ---- non-transposing macro
            table.insert(song.parse.macros, macro)
        end
    end    
end
    
function symbol_line_token(content, song)
    -- parse a symbol line    
    -- we may need to append to this later, if we get a continuation field
    song.parse.last_symbol_line = parse_symbol_line(content)
    return {token='symbol_line', symbol_line = song.parse.last_symbol_line}
end    
    
function continuation_token(content, song)
     local parsable = {'length', 'tempo', 'parts', 'meter', 'words', 'key', 'symbol_line', 'macro', 'user', 'voice', 'instruction'} -- those fields we parse individually    
     
     if song.parse.last_field then
        -- append plain text if necessary
        if not is_in(song.parse.last_field, parsable) then        
            return {token='append_field_text', name=song.parse.last_field, content=content}                
        end
         
         -- append lyrics
         if song.parse.last_field=='words' then
               -- we are guaranteed that song.parse.last_lyrics line is set
            local appended_lyrics = parse_lyrics(content)
            for i,v in ipairs(appended_lyrics) do
                table.insert(song.parse.last_lyrics, v)
            end 
         end
         
         -- append to a symbol line
         if song.parse.last_field=='symbol_line' then            
            -- we are guaranteed that song.parse.last_symbol line is set
            local appended_symbols = parse_symbol_line(content)
            for i,v in ipairs(appended_symbols) do
                table.insert(song.parse.last_symbol_line, v)
            end
         end
     end                 
end
        
 local field_fns = {key = key_token
,title = text_token
,ref =  text_token
,area =  text_token
,book =  text_token
,composer =  text_token
,discography = text_token
,extended = text_token
,file = text_token
,group =  text_token
,history = text_token
,instruction =   instruction_token
,length =   length_token
,meter =   meter_token
,macro =   macro_token
,notes =   text_token
,origin =  text_token
,parts =   parts_token
,tempo =   tempo_token
,rhythm =   text_token
,remark =  text_token
,source =   text_token
,symbol_line =   symbol_line_token
,user =   user_token
,voice =   voice_token
,words =  words_token
,end_words =  text_token
,transcriber =  text_token
,continuation =  continuation_token
}


function scan_metadata(str)
    -- quickly scan a string, and fill out the metadata fields
    local meta = {}
    local last_field         
    for i,line in ipairs(split(str, '\n')) do        
        local match, content = line:match('^([%a\\+]):([^]:[|]?.*)')        
        if match then
            field_name = field_names[match]            
            if field_name then                 
                if field_name=='continuation' and last_field then
                    -- continuation fields with +:
                    meta[field_name][#meta[field_name]] = meta[field_name][#meta[field_name]]..content
                else
                    -- standard fields
                    meta[field_name] = meta[field_name] or {}
                    table.insert(meta[field_name], content)
                    last_field = field_name
                end
            end            
        end        
     end
    return meta    
end

function parse_field(f, song, inline, at)
    -- parse a metadata field, of the form X: stuff
    -- (either as a line on its own, or as an inline [x:stuff] field
     local name, field, field_name
     local match, content = f:match('^([%a\\+]):([^]:[|]?.*)')
          
     -- not a metadata field at all
     if not match then
        -- in the header, treat lines without a tag as continuations
        if song.parse.in_header then
            if song.parse.strict then
                warn("Bare metadata line in header.")
            end
            field_name = 'continuation' 
            content = f                
        else
            -- otherwise it was probably a tune line
            return 
        end
     else
        field_name = field_names[match]
        if not field_name then return end -- unknown field
     end

    local token =  field_fns[field_name](content, song, field_name)
          
    if token then        
        if field_name~='continuation' then song.parse.last_field = field_name end        
        token.inline = inline
        token.is_field = true
        
    end
    
    return token
 
end

