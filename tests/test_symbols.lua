-- verify that pitches are rendered correctly
abclua = require "abclua"

function get_decorators(tokens)
    -- return a table representing the decorators, chords and annotations of each note in the 
    -- given token stream
    local decorators = {}
    for i,v in ipairs(tokens) do        
        if v.token=='note' then       
            local chord =''
            local text =''
            local decoration =''
            
            if v.note.chord then
                chord = abc_chord(v.note.chord)
            end
            
            if v.note.text then
                text = abc_text(v.note.text)
            end
            
            if v.note.decoration then
                decoration = abc_decoration(v.note.decoration)
            end
                                    
            table.insert(decorators, '('..chord..')'..'('..text..')'..'('..decoration..')')
        end
    end
    return decorators
end


function verify_decorators(str, result, apply_merge, test)
    -- verify that the symbol line decorators are applied correctly
    local songs = abclua.parse_abc_multisong(str)          
    local stream = songs[1].token_stream        
    -- apply the symbol line if requested
    if apply_merge then
        merge_symbol_line(stream)
    end
    local decorators = get_decorators(stream)        
    for i, v in ipairs(result) do                
        local decorator = decorators[i]        
        assert(v==decorator)        
    end
    print(test.." passed OK") 
end

function test_symbol_line()
    -- Test symbol lines
    
    verify_decorators([[X:1
    K:G
    !roll!f !fermata!G d !trill!~a
    ]], 
    {
        '()()(~)',
        '()()(H)',
        '()()()',
        '()()(T~)'
    },    
    false,'Decorations without symbol line')
        
    verify_decorators([[X:1
    K:G
    "@there"f "<here""there"G d
    ]], 
    {
        '()("@there")()',
        '()("<here""there")()',
        '()()()'
    }, false,'Annotations without symbol line')
    
    verify_decorators([[X:1
    K:G
    "Cm7"f "<here""there"G "D"d
    ]], 
    {
        '("Cm7")()()',
        '()("<here""there")()',       
        '("D")()()'
    },false, 'Chords without symbol line')
    
    verify_decorators([[X:1
    K:G
    "Cm7"f "<here""there"G "D"d
    ]], 
    {
        '("Cm7")()()',
        '()("<here""there")()',       
        '("D")()()'
    },true, 'Symbol line applied with no symbols')
    
    
    verify_decorators([[X:1
    K:G
    abc
    s:"Cm7" !trill! "<annotation"
    ]], 
    {
        '()()()',
        '()()()',       
        '()()()'
    }, false, 'Symbol line, no existing decorations, not applied')

        
    verify_decorators([[X:1
    K:G
    abc
    s:"Cm7" !trill! "<annotation"
    ]], 
    {
        '("Cm7")()()',
        '()()(T)',       
        '()("<annotation")()'
    }, true, 'Symbol line, no existing decorations, applied')
    
    
    
    verify_decorators([[X:1
    K:G
    abc
    s:"Cm7" !trill! "<annotation"
    def
    s:"Dm7" !roll! "hello"
    ]], 
    {
        '("Cm7")()()',
        '()()(T)',       
        '()("<annotation")()',
        '("Dm7")()()',
        '()()(~)',       
        '()("hello")()'
    }, true, 'Multiple symbol lines')
    
    verify_decorators([[X:1
    K:G
    abc
    s:
    def
    s:"Dm7" !roll! "hello"
    ]], 
    {
        '()()()',
        '()()()',       
        '()()()',
        '("Dm7")()()',
        '()()(~)',       
        '()("hello")()'
    }, true, 'Multiple symbol lines with break')

                          
    verify_decorators([[X:1
    K:G
    "Dm"~a ~b "stuff".c
    s:"Cm7" !trill! "<annotation"
    ]], 
    {
        '("Cm7")()(~)',
        '()()(~T)',       
        '()("stuff""<annotation")(.)'
    }, true, 'Symbol line, existing decorations')
    
    verify_decorators([[X:1
    K:G
    "Dm"~a ~b "stuff".c d e f
    s:"Cm7" !trill! "<annotation"
    +:"Dm" !trill!
    ]], 
    {
        '("Cm7")()(~)',
        '()()(~T)',       
        '()("stuff""<annotation")(.)',
        '("Dm")()()',
        '()()(T)',
        '()()()'
    }, true, 'Symbol line, continuation')
    
        verify_decorators([[X:1
    K:G
    a a
    s:"Cm7" "Cm7" "Cm7"    
    ]], 
    {
        '("Cm7")()()',
        '("Cm7")()()',            
    }, true, 'Symbol line, excessive symbols')

    verify_decorators([[X:1
    K:G
    a a a a | a a a 
    s:* "Cm7" | * "D"
    ]], 
    {
        '()()()',
        '("Cm7")()()',            
        '()()()',
        '()()()',
        '()()()',
        '("D")()()',            
        '()()()',        
    }, true, 'Symbol line, bar alignment')


    verify_decorators([[X:1
    K:G
    "Dm"~a ~b "stuff".c 
    s:"Cm7" !trill! "<annotation"
    s:"G" "@hello" "more"
    s:*    *       "Gbmin"
    ]], 
    {
        '("G")()(~)',
        '()("@hello")(~T)',       
        '("Gbmin")("stuff""<annotation""more")(.)',
        
    }, true, 'Symbol line, parallel stack application')

    
    print("Symbol line passed OK")
end


test_symbol_line()

