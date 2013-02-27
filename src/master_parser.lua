-- The master grammar and functions for applying it
local tune_pattern = [[
elements <- ( ({}  <element>)  +) -> {}
element <- (  {:field: field :}  / {:top_note: <complete_note>:}  / {:overlay: '&'+ :} / {:bar: (<bar> / <variant>) :}   / {:free_text: free :} / {:triplet: triplet :} / {:slur_begin: '(' :} / {:slur_end: ')' :} /  {:chord_begin: '[' :} / {:chord_end: ']' :} / {:s: %s+ :}  / {:continuation: '\' :}) -> {}
free <- ( '"' {:text: [^"]* :} '"' ) -> {}
bar <- ( {:type: (('[') * ('|' / ':') + (']') *) :} ({:variant_range: (<range_set>) :}) ? ) -> {}
variant <- ({:type: '[' :} {:variant_range: <range_set> :})   -> {}
range_set <- (range (',' range)*)
range <- ([0-9] ('-' [0-9]) ?)
complete_note <- (({:grace: (grace)  :}) ?  ({:chord: (chord)  :}) ?  ({:decoration: ({decoration} +)->{} :}) ?  (({:pitch: (note) :} / {:rest: (rest) :} / {:space: (space) :}/{:measure_rest: <measure_rest> :} ) {:duration: (duration ?)  :}  {:broken: (broken ?)  :})  (%s * {:tie: (tie)  :}) ? ) -> {} 
triplet <- ('(' {[1-9]} (':' {[1-9] ?}  (':' {[1-9]} ? ) ?) ?) -> {}
grace <- ('{' full_note + '}') -> {}
tie <- ('-')
chord <- (["] {([^"] *)} ["])
full_note <- ((({:pitch: (note) :} / {:rest: (rest) :} / {:space: (space) :}/{:measure_rest: <measure_rest> :} ) {:duration: (duration ?)  :}  {:broken: (broken ?)  :})) -> {}
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

function abc_body_parser(str)
    return tune_matcher:match(str)
end


local function parse_free_text(text)
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
            if v.chord_begin then            
                
                table.insert(song.token_stream, {token='chord_begin'})                                
            end
            
            if v.chord_end then
                table.insert(song.token_stream, {token='chord_end'})                                                
            end
            
            if v.slur_begin then
                table.insert(song.token_stream, {token='slur_begin'})
            end
            
            if v.slur_end then
                table.insert(song.token_stream, {token='slur_end'})
            end
            
            -- if we have slur groups then there are some notes to parse...
            if v.top_note then                            
                -- add a note to the token stream
                local cnote = parse_note(v.top_note)    
                if cnote.free_text then
                        local position, text = parse_free_text(cnote.free_text)                   
                        table.insert(song.token_stream, {token='text', text=text, position = position})                            
                        cnote.free_text = nil
                end
                table.insert(song.token_stream, {token='note', note=cnote})          
            end
        end
    end
    
end