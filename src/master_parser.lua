-- The master grammar and functions for applying it
local tune_pattern = [[
elements <- (
                (
                    {}                  -- Cross reference (position capture)
                    <element>           -- Each tune body element
                )  
            +) -> {}

element <- (  
    {:field: field :}  /                -- Field e.g [X:title] 
    {:top_note: <complete_note>:}  /    -- A note definition 'A/2>'
    {:overlay: '&'+ :} /                -- Bar overlay symbol '&'
    {:bar: <bar> :}   /                 -- Bar symbol  '[|'  
    {:variant: <variant> :} /           -- Part variant
    {:free_text: free :} /              -- Chords or annonations "Dm7" or ">Some text"
    {:triplet: triplet :} /             -- Triplet definition '(3 abc'
    {:slur_begin: '(' :} /              -- Start of a slur group '(abc...' 
    {:slur_end: ')' :} /                -- End of a slur group '...ded)'
    {:chord_begin: '[' :} /             -- Start of chord group '[CEG...'
    {:chord_end: ']' :} /               -- End of chord group '...eg]'
    {:s: %s+ :}  /                      -- Space (splits beams in notes)
    {:continuation: '\' :} /            -- End of line continuation character
    '`' /                               -- backquote (ignored)
    comment  /                           -- comment line '% this is a comment' (ignored)
    {:linebreak_maybe: [$] :}             -- possible newline
    ) -> {}
    
    
comment <- ('%' .*)                     -- % followed by anything is a comment

free <- ( '"' 
         {:text: [^"]* :}               -- Free text within quotes 
         '"' 
        ) -> {}

oldbar <- ( 
        {:type: (('[') * ('|' / ':') + (']') *) :}  -- The bar symbol
        ({:variant_range: (<range_set>) :}) ?       -- Optional variant range :|1 or :|2,3
        ) -> {}
        
        
bar <- (    (
                {:mid_repeat: <mid_repeat> :} /  
                {:end_repeat: <end_repeat> :}  / 
                {:start_repeat: <start_repeat> :} / 
                {:double: <double> :} /
                {:thickthin: <thickthin> :} / 
                {:thinthick: <thinthick> :} /  
                {:plain: <plain> :} / 
                {:just_colons: <just_colons> :} 
            )
            {:variant_range: (<range_set>) :} ?     -- Optional variant indicator
            ) -> {}        
            
mid_repeat <- (                         -- Mid repeat ::|::
                                        -- Note the position captures capture the number of colons
                {} <colons> {} (<plain>+) {} <colons>{}     
              ) -> {}
              
start_repeat <- (                       -- Start repeat |:
                (<thickthin> / <double> / <plain> ) {} <colons> {}      
                ) -> {}
                
end_repeat <- (                         -- End repeat :|
                {} <colons> {} 
                (<thinthick> / <double> / <plain> )
              ) -> {}
              
just_colons <- (
                {} ':' <colons>  {}     -- Two or more colons (alternative mid repeat form)
                ) -> {}
                
plain <- '|'          -- Plain bar
thickthin <- (  '[' + '|' + )      -- Thick thin bar
thinthick <- ('|' + ']' + )        -- Thin thick bar
double <- ('|' ('[' / ']') * '|')  -- Double bar        
colons <- (':' +)                  -- colons
        
variant <- (
     '['                               -- A part variant (e.g. '| [4 a bc | [5 d e f')
    {:variant_range: <range_set> :}     -- Followed by a numerical range 
           )   -> {}
        
range_set <- (
                (<range>) (',' <range>) *       -- List of range elements
            ) -> {}
            
range <- (  
        <range_id> / <number>    -- Range or number
        ) -> {}
        
range_id <- (                    -- Range indicator 2-3
            <number> '-' <number>
            )
            
number <- ({ [0-9]+ }) 
         
complete_note <- (
                -- A full note definition
                ({:grace: (grace)  :}) ?  -- Grace notes as a sequence in braces {df} 
                ({:chord: (chord +)->{}  :}) ?  -- Chord or text annotation "Cm7"
                ({:decoration: ({decoration} +)->{} :}) ?  -- Sequence of decorations
                (
                    (
                        {:pitch: (note) :} /        -- Pitch of the note if a note
                        {:rest: (rest) :} /         -- or a rest
                        {:space: (space) :}/        -- or a "y" space
                        {:measure_rest: <measure_rest> :}   -- or a measure rest
                    ) 
                    {:duration: (duration)  :}?     -- Duration, as a fraction
                    {:broken: (<broken>)  :}?)      -- Broken rhythm symbols '>'
                    (%s * {:tie: '-'  :}) ?       -- Any following tie symbol A2-|A3
                ) -> {} 
                
triplet <- (
            '('                         -- Begins with a bracker 
            {[0-9]+}                    -- Followed by a number
            (':' {[0-9]+ ?}             -- Optionally followed by a number ':' or just ':' 
                (':' {[0-9]+} ? )       -- Followed by a number
                ?) 
            ? ) 
            -> {}
            
grace <- (                              -- Grace note definition
        '{'                             -- Begins with open brace
        {:acciacatura: '/' :} ?         -- Optional slash at start to distingush acciatacura
        full_note + '}'                 -- Then a sequence of notes
        ) -> {}
        

chord <- (
        ["]                             -- Quoted string  
        {([^"] *)}                      
        ["]
    )
full_note <- (                          -- Note, as appears in a grace note 
                (
                    {:pitch: (note) :} /     -- Pitch 
                    {:rest: (rest) :} /      -- Or rest
                    {:space: (space) :}/     -- Or space
                    {:measure_rest: <measure_rest> :}  -- Or measure rest
                ) 
                {:duration: (duration)  :}?     -- Optional duration, as a fraction 
                {:broken: (<broken>)  :}?       -- Broken note specifier
            ) -> {}

rest <- ( 'z' / 'x' )                  -- z or x for a rest
space <- 'y'                           -- y for invisible no-duration rest

measure_rest <- (
                ('Z' / 'X')            -- Measure rest
                ) -> {}

broken <- ( 
            ('<' +) /                 -- sequence of '<' 
            ('>' +)                   -- or '>' for broken notes
          )
          
note <- (                           -- note with a pitch
            (                       -- Optional accidental
            {:accidental: (
                           {accidental} -- Accidental symbol
                           duration ?   -- Fraction for microtonal accidentals 
                          ) -> {}  :}
            )? 
            
            {:note:  ([a-g]/[A-G]) :}   -- Note pitch
            {:octave: (octave)  :} ?    -- Octave specifier
        ) -> {}
        
decoration <- (                         -- Note decorations
                ('!' ([^!] *) '!') /    -- !xyz! style    
                ('+' ([^+] *) '+') /    -- +xyz+ style
                ([h-wH-W] / '~' / '.')              -- or a predefined decoration
                )
                
octave <- (
    ( ['] / ',') +                  -- Octave specifier; any sequence of ' or ,
    )
    
accidental <- ( 
    ('^^' /  '__' /  '^' / '_' / '=') -- Accidental symbol
    ) 
    
duration <- (                       -- Fraction pattern for durations
            {:num: [0-9] + :} ?     -- Numerator (optional)
            {:slashes: '/' +  :} ?  -- A sequence of slashes (optional) e.g. to recognise A//
            {:den: [0-9]+  :} ?     -- Denominator
            )  -> {}
            
field <- (                          -- Inline field [T:title]
            '['                     -- Open brackets
            {:contents:         
                [a-zA-Z]            -- One letter tag of the field
                ':'                 -- Colon
                [^]%nl] +           -- Everything until ] (nb %nl hack never matches)
            :}
            ']'                     -- Close brackets
        ) -> {}        
]]


local tune_matcher = re.compile(tune_pattern)

function abc_body_parser(str)
    return tune_matcher:match(str)
end


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
    return {position=position, text=new_text}
end


function read_tune_segment(tune_data, song)
    -- read the next token in the note stream    
  
    local insert = table.insert
    local token_stream = song.token_stream
    local last_cross_ref = nil
    local token 
  
    for i,v in ipairs(tune_data) do
        token = nil
        if type(v) == 'number' then
            -- insert cross refs, if they are enabled
            if song.parse.cross_ref then
                 last_cross_ref =  {at=v, line=song.parse.line, tune_line=song.parse.tune_line, tune=song.parse.tune}
            end
        else
            if v.top_note then                         
                -- add a note to the token stream                
                local cnote = parse_note(v.top_note, song.parse.user_macros)                          
                token =  {token='note', note=cnote}                     
            -- store annotations
            elseif v.free_text then
                -- could be a standalone chord
                local chord = parse_chord(v.free_text.text)                                                
                if chord then
                    token =  {token='chord', chord=chord}
                else                    
                    token =  {token='text', text=parse_free_text(v.free_text.text)}
                end
            
            -- parse inline fields (e.g. [r:hello!])
            elseif v.field then                
                -- this automatically writes it to the token_stream
                -- not correct for inline fields!
                token = parse_field(v.field.contents, song, true)
                
            -- deal with triplet definitions
            elseif v.triplet then                                        
                token =  {token='triplet', triplet=parse_triplet(v.triplet, song)}                            
            
            -- voice overlay
            elseif v.overlay then
                token =  {token='overlay', bars=string.len(v.overlay)}
            
            
            -- beam splits
            elseif v.s then
                token =  {token='split'}
            
            
            -- linebreaks
            elseif v.linebreak then
                token =  {token='split_line'}
            
            
            elseif v.continue_line then
                token =  {token='continue_line'}
            
                                        
            -- deal with bars and repeat symbols
            elseif v.bar then   
                local bar = parse_bar(v.bar)
                song.parse.measure = song.parse.measure + 1 -- record the measures numbers as written
                bar.measure = song.parse.measure
                token =  {token='bar', bar=bar}               
            elseif v.variant then
                token =  {token='variant', variant=parse_variant(v.variant)}               
            
            
            -- chord groups
            elseif v.chord_begin then            
                
                token =  {token='chord_begin'}                                
            
            
            elseif v.chord_end then
                token =  {token='chord_end'}                                               
            
            
            elseif v.slur_begin then
                token =  {token='slur_begin'}
            
            
            elseif v.slur_end then
                token = {token='slur_end'}
                
            elseif v.linebreak_maybe then
                -- dollar/exclamation linebreak symbols
                -- (enabled by I:linebreak)    
                if song.parse.linebreaks.dollar or song.parse.linebreaks.exclamation then
                    token = {token='split_line'}
                end
           end
                      
            -- insert token and set the cross reference
            if token then
                token.cross_ref = last_cross_ref
                insert(token_stream, token)
            end
        end
    end
    
end