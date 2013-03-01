-- functions for dealing with symbol lines

function parse_symbol_line(symbols)
    -- Parse a symbol defintion line
    -- Returns a table containing each symbol and an advance field
    -- Advance can be 1 or "bar"    
    local symbol_list = split(symbols, '%s')
    local all_symbols = {}
    local symbol, advance
    for i,v in ipairs(symbol_list) do       
        symbol = nil
        if v=='|' then symbol = {type='bar', advance='bar'} end
        if v=='*' then symbol = {type='spacer', advance='note'} end
        if v:match('![^!]+!') then symbol = {type='decoration', decoration=v, advance='note'} end
        if v:match('"[^"]+"') then symbol = {type='chord_text', chord_text=v, advance='note'} end        
        if symbol then
            table.insert(all_symbols, symbol)
        end
    end
    
    return all_symbols
end


function merge_symbol_line(tokens)
    -- Merge a symbol lines in a token stream in place.
    -- Adds decorations, chord symbols and free text to note events in the sequence.
    
    local note_align = 0 -- current note alignment
    local last_note_align = 0 -- previous note alignment
    local note_index = 0 -- index of each note in the token stream
    local all_symbols = {}
    
    
    local token_ptr = 1
    local last_symbol_index, last_ptr
    
    -- move along to the next matching token in the stream
    local function advance_token_ptr(sym)
        while token_ptr<=#tokens do
            local t = tokens[token_ptr].token
            token_ptr = token_ptr + 1
            if t==sym.advance then return tokens[token_ptr-1] end                    
        end
        return nil -- ran over end of the token list
    end
    
    -- run through all symbols
    for ix,token in ipairs(tokens) do                        
        if token.token=='symbol_line' then            
            local symbols = token.symbol_line or {}                       
            -- stacked symbols!
            if last_symbol_index==ix-1 then
                token_ptr = last_ptr
            else
                -- in case we need to go back here with stacked lines
                last_ptr = token_ptr 
            end
           
            -- run through each symbol
            for i,v in ipairs(symbols) do                                                         
                token = advance_token_ptr(v)               
                if token and token.token=='note' then
                    if v.type=='decoration' then add_decoration_note(token.note, v.decoration) end                    
                    -- add annotation / change chord (removing quotes)
                    if v.type=='chord_text' then add_chord_or_annotation_note(token.note, string.sub(v.chord_text,2,-2)) end                                                   
                end
                
            end 
            last_symbol_index = ix
            -- advance to this symbol line
            if token_ptr<ix then token_ptr=ix end 
            
        end
    end
    
end