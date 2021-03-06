-- functions for dealing with symbol lines

function parse_symbol_line(symbols)
    -- Parse a symbol defintion line
    -- Returns a table containing each symbol and an advance field
    -- Advance can be "note" or "bar"    
    local symbol_list = split(symbols, '%s')
    local all_symbols = {}
    local symbol, advance
    
    for i,v in ipairs(symbol_list) do       
        symbol = nil
        -- bar advance; wait for a new measure before aligning future symbols
        if v=='|' then symbol = {type='bar', advance='bar'} end
        -- spacer; do nothing and align to the following note
        if v=='*' then symbol = {type='spacer', advance='note'} end
        -- decoration; align to the next note
        if v:match('![^!]+!') then symbol = {type='decoration', decoration=v, advance='note'} end
        -- chord or annotation; align to the next note
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
        
    local token_ptr = 1     -- index of the current position at which we look for notes to align to
    local last_symbol_index -- index of the last symbol_line token in the stream (use this to check for stacked symbol lines)
    local last_ptr          -- the token_ptr used by the previous symbol_line definition (so we can jump back)
    
    -- move along to the next matching token in the stream
    -- we call this every time we see a symbol in a symbol line
    local function advance_token_ptr(sym)
        while token_ptr<=#tokens do
            local t = tokens[token_ptr].token
            token_ptr = token_ptr + 1
            -- if we match, return the matching token
            if t==sym.advance then return tokens[token_ptr-1] end                    
        end
        return nil -- ran over end of the token list
    end
    
    -- run through all tokens, looking for symbol lines
    for ix,token in ipairs(tokens) do                        
        if token.token=='symbol_line' then            
            local symbols = token.symbol_line or {}     
            
            -- deal with stacked symbols.
            if last_symbol_index==ix-1 then
                -- last token was also a symbol_line; this is te
                -- second, third,... nth line of a stack
                token_ptr = last_ptr                
            else
                -- this is not a stack, or is the first line, so remember
                -- the alignment position for future stacking
                last_ptr = token_ptr 
            end
           
            -- run through each symbol
            for i,v in ipairs(symbols) do                                                         
                token = advance_token_ptr(v)           
                
                -- attach decorations and text to notes
                if token and token.token=='note' then
                    token.note = copy_table(token.note)
                    if v.type=='decoration' then add_decoration_note(token.note, v.decoration) end                    
                    -- add annotation / change chord (removing quotes)
                    if v.type=='chord_text' then add_chord_or_annotation_note(token.note, string.sub(v.chord_text,2,-2)) end                                                   
                end                
            end 
            last_symbol_index = ix
            
            -- advance the pointer to this symbol line
            if token_ptr<ix then token_ptr=ix end             
        end
    end
    
end