-- Routines for parsing metadata in headers and inline inside songs
local re = require "re"
require "macro"

-- create the various pattern matchers
matchers = {}
matchers.doctype = [[ doctype <- ('%abc' '-'? {[0-9.]+} %nl) -> {}]]

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


function parse_voice(voice)
    -- Parse a voice definition string
    -- Voices of the form V:ID [specifier] [specifier] ...
    -- Returns a table with an ID and a specifiers table
    -- e.g. V:tenor becomes {id="tenor", specifiers={}}
    -- V:tenor clef=treble becomes {id="tenor", specifiers={lhs='clef', rhs='treble'}}
    voice_pattern = [[
    voice <- (({:id: [%S]+ :}) %s * {:specifiers: (<specifier> *) -> {} :}) -> {}
    specifier <- (%s * {:lhs: ([^=] +) :} + '=' {:rhs: [^%s]* :}) -> {} 
    ]]
    
    return re.match(voice, voice_pattern)
end


function parse_tempo(l)
    -- Parse a tempo string
    -- Returns a tempo table, with an (optional) name and div_rate field
    -- div_rate is in units per second
    -- the numbered elements specify the unit lengths to be played up to that point
    -- each element has a "num" and "den" field to specify the numerator and denominator
    tempo_pattern = [[
tempo <- (
({:name: qstring :} %s +) ?
    ( 
    (  (  (div (%s + div) *)  )  '=' {:div_rate: number:} )  /
    (  'C=' {:div_rate: number:} ) /
    (  {:div_rate: number :} ) 
    ) 
(%s + {:name: qstring :}) ?
) -> {}

div <- ({:num: number:} '/' {:den: number:}) -> {}
number <- ( [0-9] + )
qstring <- ( ["] [^"]* ["] )
]]
    captures = re.match(l,  tempo_pattern)    
  
    return captures
end


function parse_length(l)
    -- Parse a string giving note length, as a fraction "1/n" (or plain "1")
    -- Returns integer representing denominator.
    local captures = re.match(l,  "('1' ('/' {[0-9] +}) ?)")    
    if captures then
        return captures+0
    else
        return 1    
    end
end



function get_simplified_meter(meter)
    -- return meter as a simple num/den form
    -- with the beat emphasis separate
    -- by summing up all num elements
    -- (e.g. (2+3+2)/8 becomes 7/8)
    -- the beat emphasis is stored as
    -- emphasis = {1,3,5}
    local total_num = 0
    local emphasis = {}
    for i,v in ipairs(meter.num) do
        table.insert(emphasis, total_num)
        total_num = total_num + v
    end
    return {num=total_num, den=meter.den, emphasis=emphasis}
end

function parse_meter(m)
    -- Parse a string giving the meter definition
    -- Returns fraction as a two element table
    local captures = re.match(m,  [[
    meter <- (fraction / cut / common / none) 
    common <- ({:num: '' -> '4':} {:den: '' -> '4':} 'C') -> {}
    cut <- ({:num: '' -> '2':} {:den: '' -> '2' :} 'C|' ) -> {}
    none <- ('none' / '')  -> {}    
    fraction <- ({:num: complex :} '/' {:den: [0-9]+ :}) -> {}    
    complex <- ( '(' ? ((number + '+') * number) ->{} ')' ? )
    number <- {([0-9]+)}     
    ]])
   
    return get_simplified_meter(captures)
    
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

function is_in(str, tab)
-- return true if str is in the given table of strings
    for i,v in ipairs(tab) do
        if str==v then
            return true
        end
    end
    return false
end



function parse_field(f, song, inline)
    -- parse a metadata field, of the form X: stuff
    -- (either as a line on its own, or as an inline [x:stuff] field
     local name, field, match, field_name
     
     -- find matching field
     field_name = nil
     for name, field in pairs(fields) do
        match = re.match(f, field)         
        if match then
            field_name = name
            content = match[1]
        end
     end
     
     -- not a metadata field at all
     if not field_name then
        return
     end    
    
   
   
    local parsable = {'length', 'tempo', 'parts', 'meter', 'words', 'key', 'macro', 'user', 'voice'} -- those fields we parse individually
    local field = {name=field_name, content=content}
    -- continuation
    if field_name=='continuation' then
        
        -- append plain text if necessary
        if not is_in(song.parse.last_field, parsable) then
            
            table.insert(song.journal, {event='append_field_text', name=song.parse.last_field, content=content, inline=inline, field={name=song.parse.last_field, content=content}})
            
        end
        
         if song.parse.last_field=='words' then
             table.insert(song.journal, {event='words', lyrics=parse_lyrics(content), field=field})            
         end
         
    else
        -- if not a parsable field, store it as plain text
    
        song.parse.last_field = field_name
        if not is_in(field_name, parsable) then
            table.insert(song.journal, {event='field_text', name=field_name, content=content, inline=inline, field=field}) 
        end

    end
    
    
    -- update specific tune settings
    if field_name=='length' then
        table.insert(song.journal, {event='note_length', note_length=parse_length(content), inline=inline,  field=field}) 
    end
            
    -- update tempo
    if field_name=='tempo' then            
        table.insert(song.journal, {event='tempo', tempo=parse_tempo(content), inline=inline, field=field})
    end
    
    -- parse lyric definitions
    if field_name=='words' then                        
         table.insert(song.journal, {event='words', lyrics=parse_lyrics(content), field=field, inline=inline})            
    end
            
     -- parse voice definitions
    if field_name=='voice' then  
        -- in the header this just sets up the voice properties
        if song.parse.in_header then
            table.insert(song.journal, {event='voice_def', voice=parse_voice(content), inline=inline, field=field})
        else
            table.insert(song.journal, {event='voice_change', voice=parse_voice(content), inline=inline, field=field})
        end
    end
      
   
    if field_name=='parts' then            
        -- parts definition if we are still in the header
        -- look up the parts and expand them out
        if song.parse.in_header then
            parts = content:gsub('\\.', '') -- remove dots
            parts = parse_parts(content)
            table.insert(song.journal, {event='parts', parts=parts, inline=inline, field=field})            
        else
            -- otherwise we are starting a new part   
            -- parts are always one character long, spaces and dots are ignored
            part = content.gsub('%s', '')
            part = part.gsub('.', '')
            part = string.sub(part,1,1)
            
            table.insert(song.journal, {event='new_part', part=part, inline=inline, field=field})            
        end
    end
    
    
    if field_name=='user' then
        -- user macro (not transposable)
        macro = parse_macro(content)
        table.insert(song.parse.user_macros, macro)
    end
    
    if field_name=='macro' then
        -- we DON'T insert macros into the journal. Instead
        -- we expand them as we find them
        macro = parse_macro(content)
        
        -- transposing macro
        if re.find(macro.lhs, "'n'") then
            notes = {'a', 'b', 'c', 'd', 'e', 'f', 'g'} 
            for i,v in ipairs(notes) do
                table.insert(song.parse.macros, transpose_macro(macro.lhs, v, macro.rhs)) 
                table.insert(song.parse.macros, transpose_macro(macro.lhs, string.upper(v), macro.rhs)) 
            end
        else
            -- non-transposing macro
            table.insert(song.parse.macros, macro)
        end
    end
    
    -- update meter
    if field_name=='meter' then            
        table.insert(song.journal, {event='meter', meter=parse_meter(content), inline=inline, field=field})            
    end       
    
    -- update key
    if field_name=='key' then            
        table.insert(song.journal, {event='key', key=parse_key(content), inline=inline, field=field}) 
        song.parse.found_key = true -- key marks the end of the header
    end
 
end

function parse_parts(m)
    -- Parse a parts definition that specifies the parts to be played
    -- including any repeats
    -- Returns a fully expanded part list
    
    captures = re.match(m,  [[
    parts <- (part +) -> {}
    part <- ( ({element}  / ( '(' part + ')' ) )  {:repeat: [0-9]* :}) -> {}    
    element <- [A-Za-z]    
    ]])
    
    return captures
    
end