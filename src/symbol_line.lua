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
        if v=='|' then symbol = {type='bar'} end
        if v=='*' then symbol = {type='spacer'} end
        if v:match('![^!]+!') then symbol = {type='decoration', decoration=v} end
        if v:match('"[^"]+"') then symbol = {type='chord_text', chord_text=v} end        
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
    
    local last_line_index = 1
    -- combine all symbols into one single array
    for i,v in ipairs(tokens) do                        
        if v.token=='symbol_line' then            
            local symbols = v.symbol_line or {}                       
            for i,v in ipairs(symbols) do                
                table.insert(all_symbols, v)
            end            
            last_line_index = #all_symbols
        end
    end
    

    local symbol_index = 1
    local wait = 'note'
    if all_symbols[symbol_index] and all_symbols[symbol_index].type=='bar' then
        wait = 'bar'
    end
    
    -- apply each symbol to each note
    for i,v in ipairs(tokens) do        
        
                
        if v.token=='note' and wait=='note' then
            
            -- keep a track of the current note number            
                if symbol_index<=#all_symbols then
                    symbol = all_symbols[symbol_index]
                    
                    -- add a decoration to this note
                    if symbol.type=='decoration' then add_decoration_note(v.note, symbol.decoration) end
                    
                    -- add annotation / change chord (removing quotes)
                    if symbol.type=='chord_text' then add_chord_or_annotation_note(v.note, string.sub(symbol.chord_text,2,-2)) end
                    
                    -- wait for next note, or for a bar, if this is a bar symbol
                    if symbol.type=='bar' then wait='bar' else wait='note' end                                        
                else
                    wait = nil
                end
                symbol_index = symbol_index + 1
        end
        
        -- got a bar symbol, move on to the next symbol if we were waiting for one
        if v.token=='bar' and wait=='bar' then        
            wait = 'note'            
            symbol_index = symbol_index+1                            
        end
    end        
end