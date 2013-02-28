-- functions for dealing with symbol lines

function parse_symbol_line(symbols)]
    -- Parse a symbol defintion line
    -- Returns a table containing each symbol and an advance field
    -- Advance can be 1 or "bar"
    local symbol_list = symbols.split('%s')
    local all_symbols = {}
    local symbol, advance
    for i,v in ipairs(symbol_list) do
        if string.sub(v,-1)=='|' then
            advance = 'bar'
        else
            advance = 1
         end        
         
        if v=='*' then symbol = {type='spacer'} end
        if v:match('![^!]!') then symbol = {type='decoration', decoration=v} end
        if v:match('"[^"]"') then symbol = {type='chord_text', text=v} end        
        
        table.insert(all_symbols, {symbol=symbol, advance=advance})
    end
end


function merge_symbol_line(tokens)
    -- merge a symbol line into a token stream in place
    -- adds decorations, chord symbols and free text to note events in the sequence
    local symbol_index = 1
    local symbol
    local symbols
    local wait 
    for i,v in ipairs(tokens) do
                
        if v.token=='symbol_line' then
            symbols = v.symbols
            
            -- we clear the symbol line so subsequent write-outs don't
            -- double all the symbols!
            v.symbols = {}
            symbol_index = 1
            if symbol_index<#symbols then
                wait = symbols[symbol_index].advance
            else
                wait = nil
            end
        end
        
        if v.token=='note' then
            -- note alignment
            if symbols and wait==1 then
                if symbol_index<#symbols then
                    symbol = symbols[symbol_index]
                    if symbol.type=='decoration' then table.insert(v.decorations, symbol.decoration) end
                    -- change chord                    
                    -- change annotation
                    wait = symbols[symbol_index].advance
                else
                    wait = nil
                end
                symbol_index = symbol_index + 1
            end
        end
        
        -- got a bar symbol, move on to the next symbol if we were waiting for one
        if v.token=='bar' then
            -- bar alignment
            if symbols and wait=='bar' then                
                if symbol_index<#symbols then
                    wait = symbols[symbol_index].advance
                else
                    wait = nil
                end
                symbol_index = symbol_index+1                
            end
        end
    end        
end