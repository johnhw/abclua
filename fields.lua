-- Routines for parsing metadata in headers and inline inside songs
local re = require "re"
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

function parse_key(k)
    -- Parse a key definition, in the format <root>[b][#][mode] [accidentals] [expaccidentals]
    key_pattern = [[
    key <- ( {:none: ('none') :} / {:pipe: ('Hp' / 'HP') :} / (
        {:root: ([a-gA-G]):}  ({:flat: ('b'):}) ? ({:sharp: ('#'):}) ?  
        (%s * {:mode: (mode %S*):}) ? 
        (%s * {:accidentals: (accidentals):}) ?         
         ({:clef:  ((%s + <clef>) +) -> {}   :})  ?           
        )) -> {} 
        
    clef <-  (({:clef: clefs :} / clef_def /  middle  / transpose / octave / stafflines )  ) 
    
    
    clef_def <- ('clef=' {:clef: <clefs> :} (%s + number) ? (%s + ( '+8' / '-8' )) ? ) 
    clefs <- ('alto' / 'bass' / 'none' / 'perc' / 'tenor' / 'treble' )
    middle <- ('middle=' {:middle: <number> :})
    transpose <- ('transpose=' {:transpose: <number> :}) 
    octave <- ('octave=' {:octave: <number> :}) 
    stafflines <- ('stafflines=' {:stafflines: <number> :})
    
    
    number <- ('-' ? '+' ? [0-9]+)
    
    mode <- ( ({'maj'}) / ({'aeo'}) / ({'ion'}) / ({'mix'}) / ({'dor'}) / ({'phr'}) / ({'lyd'}) /
          ({'loc'}) /  ({'exp'}) / ({'min'}) / {'m'}) 
    accidentals <- ( {accidental} (%s+ {accidental}) * ) -> {}
    accidental <- ( ('^' / '_' / '__' / '^^' / '=') [a-g] )
]]

    k = k:lower()
    captures = re.match(k,  key_pattern)    
    
    return {naming = captures,  clef=captures.clef}
    
end


function parse_length(l)
    -- Parse a string giving note length, as a fraction "1/n" (or plain "1")
    -- Returns integer representing denominator.
    captures = re.match(l,  "('1' ('/' {[0-9] +}) ?)")    
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

function add_lyrics(song, field)
    -- add lyrics to a song
    lyrics = parse_lyrics(field)        
    append_table(song.internal.lyrics, lyrics)
    table.insert(song.journal, {event='words', lyrics=parse_lyrics(field), field=true})            
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
     
    
    -- continuation
    if field_name=='continuation' then
        -- append to metadata field
        song.metadata[song.parse.last_field] = song.metadata[song.parse.last_field] .. content
        
        -- append plain text if necessary
        if not is_in(song.parse.last_field, {'length', 'tempo', 'parts', 'meter', 'words', 'key'}) then
            table.insert(song.journal, {event='append_field_text', name=song.parse.last_field, content=content, inline=inline, field=true})
        end
        
        -- make sure lyrics continue correctly. Example:
        -- w: oh this is a li-ne
        -- +: and th-is fol-lows__

        if song.parse.last_field == 'words' then
            add_lyrics(song, content)
        end
        -- other lines cannot be continued! (e.g. no splitting key across multiple lines)
        -- anything but a continuation
         
    else
        -- if not a parsable field, store it as plain text
    
        if not is_in(field_name, {'length', 'tempo', 'words', 'parts', 'meter', 'key'}) then
            table.insert(song.journal, {event='field_text', name=field_name, content=content, inline=inline, field=true}) 
        end
        
        song.metadata[field_name] = content    
        song.parse.last_field = field_name
    end
    
    
    -- update specific tune settings
    if field_name=='length' then
        song.internal.note_length = parse_length(content)
        table.insert(song.journal, {event='note_length', note_length=parse_length(content), inline=inline,  field=true}) 
        update_timing(song)
    end
            
    -- update tempo
    if field_name=='tempo' then            
        song.internal.tempo = parse_tempo(content)
        table.insert(song.journal, {event='tempo', tempo=parse_tempo(content), inline=inline, field=true})
        update_timing(song)
    end
    
    -- parse lyric definitions
    if field_name=='words' then                        
        add_lyrics(song, content)
    end
            
            
    if field_name=='parts' then            
        -- parts definition if we are still in the header
        -- look up the parts and expand them out
        if song.internal.in_header then
            table_print(content)
            parts = content:gsub('\\.', '') -- remove dots
            song.internal.part_structure = parse_parts(parts)
            parts = parse_parts(content)
            song.internal.part_sequence = expand_parts(song.internal.part_structure)      
            table.insert(song.journal, {event='parts', parts=parts, sequence=expand_parts(parts), inline=inline, field=true})            
        else
            -- otherwise we are starting a new part   
            -- parts are always one character long, spaces and dots are ignored
            part = content.gsub('%s', '')
            part = part.gsub('.', '')
            current_part = string.sub(part,1,1)
            song.in_variant_part = nil -- clear the variant flag
            start_new_part(song, current_part)
            table.insert(song.journal, {event='new_part', part=part, inline=inline, field=true})            
        end
    end
    
    -- update meter
    if field_name=='meter' then            
        song.internal.meter_data = parse_meter(content)
        table.insert(song.journal, {event='meter', meter=parse_meter(content), inline=inline, field=true})            
    end       
    
    -- update key
    if field_name=='key' then            
        song.internal.key_data = parse_key(content)
        table.insert(song.journal, {event='key', key=parse_key(content), inline=inline, field=true}) 
        apply_key(song, song.internal.key_data)
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