-- Routines for parsing metadata in headers and inline inside songs

-- create the various pattern matchers

local fields = {}
fields.key = [[('K:' {.*} ) -> {}]]
fields.title = [[('T:' %s * {.*}) -> {}]]
fields.ref =  [[('X:' %s * {.*}) -> {}]]
fields.area =  [[('A:' %s * {.*}) -> {}]]
fields.book =  [[('B:' %s * {.*}) -> {}]]
fields.composer =  [[('C:' %s * {.*}) -> {}]]
fields.discography =  [[('D:' %s * {.*}) -> {}]]
fields.file =  [[('F:' %s * {.*}) -> {}]]
fields.group =  [[('G:' %s * {.*}) -> {}]]
fields.history =  [[('H:' %s * {.*}) -> {}]]
fields.instruction =  [[('I:' %s * {.*}) -> {}]]
fields.length =  [[('L:' %s * {.*}) -> {}]]
fields.meter =  [[('M:' %s * {.*}) -> {}]]
fields.macro =  [[('m:' %s * {.*}) -> {}]]
fields.notes =  [[('N:' %s * {.*}) -> {}]]
fields.origin =  [[('O:' %s * {.*}) -> {}]]
fields.parts =  [[('P:' %s * {.*}) -> {}]]
fields.tempo =  [[('Q:' %s * {.*}) -> {}]]
fields.rhythm =  [[('R:' %s * {.*}) -> {}]]
fields.remark =  [[('r:' %s * {.*}) -> {}]]
fields.source =  [[('S:' %s * {.*}) -> {}]]
fields.symbolline =  [[('s:' %s * {.*}) -> {}]]
fields.user =  [[('U:' %s * {.*}) -> {}]]
fields.voice =  [[('V:' %s * {.*}) -> {}]]
fields.words =  [[('w:' %s * {.*}) -> {}]]
fields.end_words =  [[('W:' %s * {.*}) -> {}]]
fields.transcriber =  [[('Z:' %s * {.*}) -> {}]]
fields.continuation =  [[('+:' %s * {.*}) -> {}]]


-- compile field matchers
for i,v in pairs(fields) do
    fields[i] = re.compile(v)
end

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




function parse_field(f, song, inline)
    -- parse a metadata field, of the form X: stuff
    -- (either as a line on its own, or as an inline [x:stuff] field
     local name, field, match, field_name, content
          
     -- find matching field
     local field_name = nil
     for name, field in pairs(fields) do
        match = field:match(f)         
        if match then
            field_name = name
            content = match[1]                
        end
     end
     
            
     -- not a metadata field at all
     if not field_name then
        -- in the header, treat lines without a tag as continuations
        if song.parse.in_header then
            field_name = 'continuation' 
            content = f                
        else
            -- otherwise it was probably a tune line
            return false
        end
     end    
        
    local token
   
    local parsable = {'length', 'tempo', 'parts', 'meter', 'words', 'key', 'macro', 'user', 'voice', 'instruction'} -- those fields we parse individually
    local field = {name=field_name, content=content}
    -- continuation
    if field_name=='continuation' then
        if song.parse.last_field then
            -- append plain text if necessary
            if not is_in(song.parse.last_field, parsable) then            
                token = {token='append_field_text', name=song.parse.last_field, content=content}                
            end
            
             if song.parse.last_field=='words' then
                 token = {token='words', lyrics=parse_lyrics(content)}
             end
         end
         
    else
        -- if not a parsable field, store it as plain text
    
        song.parse.last_field = field_name
        if not is_in(field_name, parsable) then
            token =  {token='field_text', name=field_name, content=content}
        end

    end
    
    
    -- update specific tune settings
    if field_name=='length' then
        token = {token='note_length', note_length=parse_length(content)}
    end
            
    -- update tempo
    if field_name=='tempo' then            
        token = {token='tempo', tempo=parse_tempo(content)}
    end
    
    -- parse lyric definitions
    if field_name=='words' then                        
         token = {token='words', lyrics=parse_lyrics(content)}           
    end
    
     -- parse lyric definitions
    if field_name=='instruction' then                       
         local parse_time, directive = parse_directive(content)
         -- must execute parse time directives immediately
         
         if parse_time and not song.parse.no_expand then
            apply_directive(song, directive.directive, directive.arguments)
         else
            -- otherwise defer
            token = {token='instruction', directive=directive}           
         end
    end
            
     -- parse voice definitions
    if field_name=='voice' then  
        -- in the header this just sets up the voice properties
        if song.parse.in_header then
            token = {token='voice_def', voice=parse_voice(content)}
        else
            token = {token='voice_change', voice=parse_voice(content)}
        end
    end
      
   
    if field_name=='parts' then            
        -- parts definition if we are still in the header
        -- look up the parts and expand them out
        if song.parse.in_header then
            local parts = content:gsub('\\.', '') -- remove dots
            parts = parse_parts(content)
            token = {token='parts', parts=parts}           
        else
            
            -- otherwise we are starting a new part   
            -- parts are always one character long, spaces and dots are ignored
            local part = content:gsub('%s', '')
            part = part:gsub('\\.', '')
            part = string.sub(part,1,1)
                        
            token = {token='new_part', part=part}           
        end
    end
    
    
    if field_name=='user' then
        -- user macro (not transposable)
        if song.parse.no_expand then
            token = {token='field_text', name='user', content=content}                   
        else        
            table.insert(song.parse.user_macros, parse_macro(content))
        end
    end
    
    if field_name=='macro' then
        if song.parse.no_expand then
            token = {token='field_text', name='macro', content=content}                   
        else
            -- we DON'T insert macros into the token_stream. Instead
            -- we expand them as we find them
            local macro = parse_macro(content)
            
            -- transposing macro
            if re.find(macro.lhs, "'n'") then
                local notes = {'a', 'b', 'c', 'd', 'e', 'f', 'g'}             
                local note                   
                -- insert one macro for each possible note
                for i,v in ipairs(notes) do
                    table.insert(song.parse.macros, transpose_macro(macro.lhs, v, macro.rhs)) 
                    table.insert(song.parse.macros, transpose_macro(macro.lhs, string.upper(v), macro.rhs))                                                    
                end
            else
                -- non-transposing macro
                table.insert(song.parse.macros, macro)
            end
        end
    end
    
    -- update meter
    if field_name=='meter' then            
        token = {token='meter', meter=parse_meter(content)}           
    end       
    
    -- update key
    if field_name=='key' then            
        token = {token='key', key=parse_key(content)}
        song.parse.found_key = true -- key marks the end of the header
    end
    
    if token then
        token.inline = inline
        token.is_field = true
        table.insert(song.token_stream, token)
    end
    
    return true
 
end

