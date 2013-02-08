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
        (%s + {:accidentals: (accidentals):}) ?         
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
    
    return {naming = captures, mapping=create_key_structure(captures), clef=captures.clef}
    
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

function parse_meter(m)
    -- Parse a string giving the meter definition
    -- Returns fraction as a two element table
    local captures = re.match(m,  [[
    meter <- (fraction / cut / common / none) -> {}
    common <- ({:num: '' -> '4':} {:den: '' -> '4':} 'C') -> {}
    cut <- ({:num: '' -> '2':} {:den: '' -> '2' :} 'C|' ) -> {}
    none <- ('none' / '')  -> {}    
    fraction <- ({:num: complex :} '/' {:den: complex :}) -> {}    
    complex <- ( '(' ? {([0-9]+ '+') * [0-9]+} ')' ? )    
    ]])
    
    return captures
    
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

function parse_field(f, song)
    -- parse a metadata field, of the form X: stuff
    -- (either as a line on its own, or as an inline [x:stuff] field
     local name, field, match
     for name, field in pairs(fields) do
        match = re.match(f, field)         
        
        if match then            
            song.metadata[name] = match[1]    
            song.internal.last_field = name
        end
                
        -- update specific tune settings
        if match and name=='length' then
            song.internal.note_length = parse_length(match[1])
            update_timing(song)
        end
        
        if match and name=='tempo' then            
            song.internal.real_tempo = parse_tempo(match[1])
            update_timing(song)
        end
        
        -- parse lyric definitions
        if match and name=='words' then                        
            add_lyrics(song, match[1])            
        end
        
        
        if match and name=='parts' then            
            -- parts definition if we are still in the header
            -- look up the parts and expand them out
            if song.internal.in_header then
                parts = match[1]:gsub('\\.', '') -- remove dots
                song.internal.part_sequence = parse_parts(parts)                
            else
                -- otherwise we are starting a new part   
                -- parts are always one character long, spaces and dots are ignored
                part = match[1].gsub('%s', '')
                part = part.gsub('.', '')
                current_part = string.sub(part,1,1)
                song.in_variant_part = nil -- clear the variant flag
                start_new_part(song, current_part)
            end
                        
        end
        
        if match and name=='meter' then            
            song.internal.meter_data = parse_meter(match[1])
        end       
        
        if match and name=='key' then            
            song.internal.key_data = parse_key(match[1])
            
            -- apply transpose / octave
            if song.internal.key_data.clef then
                                
                if song.internal.key_data.clef.octave then
                    song.internal.global_transpose = 12 * song.internal.key_data.clef.octave -- octave shift
                else
                    song.internal.global_transpose = 0
                end
                
                if song.internal.key_data.clef.transpose then 
                    song.internal.global_transpose = song.internal.global_transpose + song.internal.key_data.clef.transpose                
                end
            end
        end
        
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
    
    return expand_parts(captures)
    
end