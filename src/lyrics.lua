-- functions for dealing with lyrics 

function parse_lyrics(lyrics)
    -- Parse a lyric definition string
    -- Returns a table containing a sequence of syllables and advance field
    -- each advance field specifies how far to move for the next syllable
    -- either an integer number of notes, or "bar" to wait until the next bar
    -- e.g. 'he-llo wo-rld_ oh~yes | a test___' becomes
    -- { 
    -- {syllable='he', advance=1}
    -- {syllable='llo', advance=1}
    -- {syllable='wo', advance=1}
    -- {syllable='rld', advance=2}
    -- {syllable='oh yes', advance='bar'}
    -- {syllable='a', advance=1}
    -- {syllable='test', advance=4}    
    -- }
    
    -- make escaped dashes into backquotes
    lyrics = lyrics:gsub('\\\\-', '`')

    local lyrics_pattern = [[
    lyrics <- ( %s* (({:syl: <syllable> / '-' :} ? {:br: <break> :}) -> {} *)  {:syl: (<syllable>)  :} -> {} ) -> {}
    break <- ( ( %s +)  / ('-')  )
    
    syllable <- ( ([^%s-] +) )        
    ]]
    
    local match = re.match(lyrics, lyrics_pattern)
    -- empty lyric pattern
    if not match then
        return {}
    end
    
    local lyric_sequence = {}
    local note_count
    local advance
    local next_advance = 1 -- always start on first note of the song
    
    -- construct the syllable sequence
    for i,syllable in ipairs(match) do
        
        local syl = syllable.syl        
        
        -- fix backquotes
        syl = syl:gsub('`', '-')
        -- note advance on trailing underscore
        note_count = 1
        for c in syl:gmatch"_" do
            note_count = note_count + 1
        end
        
        -- bar advance
        if string.sub(syl,-1)=='|' then
            advance = 'bar'
        else
            advance = note_count
        end        
        -- remove _, ~ and | from the display syllables
        syl = syl:gsub('|', '')        
        syl = syl:gsub('_', '')        
        syl = syl:gsub('~', ' ')        
        
        table.insert(lyric_sequence, {syllable=syl, advance=next_advance, br=syllable.br})        
        next_advance = advance
    end
    return lyric_sequence
end

-- expand lyrics so it is a sequence of spacers, without counts etc.
function expand_lyrics(lyrics)
    local expanded = {}
    for i,v in ipairs(lyrics) do
    
        if tonumber(v.advance) then
            for j=1,tonumber(v.advance-1) do
                table.insert(expanded, {syllable=nil, advance='note'})
            end
            table.insert(expanded, {syllable=v.syllable, advance='note'})
        end
        -- split bar advances into a bar followed by a note
        if v.advance=='bar' then
            table.insert(expanded, {syllable=nil, advance='bar'})
            table.insert(expanded, {syllable=v.syllable, advance='note'})
        end
    end
    return expanded
end

function merge_lyrics(tokens)
    -- Merge a lyrics in a token stream in place.    
        
    local token_ptr = 1     -- index of the current position at which we look for notes to align to
    local last_lyric_index -- index of the last symbol_line token in the stream (use this to check for stacked symbol lines)
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
            
    -- run through all lyrics
    for ix,token in ipairs(tokens) do                       
        
        if token.token=='words' then            
            local lyrics = expand_lyrics(token.lyrics or {})
            -- deal with stacked lyrics.
            if last_lyric_index==ix-1 then
                -- last token was also a lyric_line; this is te
                -- second, third,... nth line of a stack
                token_ptr = last_ptr                
            else
                -- this is not a stack, or is the first line, so remember
                -- the alignment position
                last_ptr = token_ptr 
            end
           
            -- run through each lyric
            for i,v in ipairs(lyrics) do                    
                token = advance_token_ptr(v)           
                -- attach decorations and text to notes
                if token and token.token=='note' then
                    local syl = v.syllable
                    if syl and syl~='*' and syl~='-' then add_lyric_note(token.note, syl) end
                end                
            end 
            last_lyric_index = ix
            -- advance the pointer to this lyric line
            if token_ptr<ix then token_ptr=ix end             
        end
    end    
end


function new_insert_lyrics(stream)
    -- Takes a lyrics structure and an event stream, and inserts the lyric
    -- events into the stream accordingly. Returns a new event stream
    -- with the lyrics in place. 
    local v
    local new_stream = {}
    
    for i=1,#stream  do
        v = stream[i]
        if v.event=='note' then
            if v.note.lyrics then
                -- create an index if there is not already one
                v.note.lyrics.index = (v.note.lyrics.index or 0) + 1
                -- insert new lyric
                local lyric = v.note.lyrics[v.note.lyrics.index]
                -- must check if there _is_ actually a lyric for this repeat
                if lyric then
                    new_stream[#new_stream+1] = {event='lyric', syllable=lyric}
                end
            end
        end
        new_stream[#new_stream+1] = v
    end
    return new_stream
end

function insert_lyrics_stream(lyrics, stream, new_stream, stream_index)
    -- Takes a lyrics structure and an event stream, and inserts the lyric
    -- events into the stream accordingly. Returns a new event stream
    -- with the lyrics in place. Lyrics are aligned to lyric_align events in the stream
    local lyric_index = 1
    
    local note_wait 
    local advance = false
    local bar_advance = false
    -- determine where to wait for the first lyric
    if lyrics[lyric_index] then
        note_wait = lyrics[lyric_index].advance
    else
        note_wait = 'end'
    end
     
    local v
    
    while stream_index<#stream do    
        v = stream[stream_index]
        
        
        -- note; decrement wait if we're not looking for a bar
        if v.event=='note' then
            if bar_advance then                
                bar_advance = false                
                note_wait = 1
            end
            
            if note_wait ~= 'end' and note_wait ~= 'bar' then
                note_wait = note_wait - 1                
                
                -- wait hit zero; insert the lyric syllable
                if note_wait == 0 then
                    advance = true                                        
                end                
            end            
        end
        
        
        -- if waiting for a bar, reset on next bar symbol
        if v.event == 'bar' then         
            if note_wait == 'bar' then                
                bar_advance = true                                
            end                    
        end
        
        -- if we've waited long enough, insert the lyric symbol into the stream
        if advance then            
            if  lyrics[lyric_index].syllable~='-' and  lyrics[lyric_index].syllable~='*' then
                table.insert(new_stream, {event='lyric', syllable=lyrics[lyric_index].syllable})
            end
            lyric_index = lyric_index + 1                    
            -- move on the lyric pointer
            if lyric_index > #lyrics then
                note_wait = 'end'
            else
                note_wait = lyrics[lyric_index].advance                
            end            
            advance = false
        end        
                       
        -- insert original event
        table.insert(new_stream, v)
                   
        -- if we get an align event then return and start on the next lyric segment
        if v.event=='lyric_align' then
            return stream_index
        end
      
        stream_index = stream_index + 1
    end
    
    return stream_index
end


function insert_lyrics(lyrics, stream)
    -- insert a sequence of lyrics into the stream
    -- each lyric line (except the first, which starts at the first note) is aligned with
    -- the corresponding "lyric_align" event in the event stream
    
    local index = 1 -- index into the original stream
    local new_stream = {}
    
    -- insert each lyric line in turn
    for i,v in ipairs(lyrics) do        
        index = insert_lyrics_stream(v, stream, new_stream, index)+1
    end
    -- copy in any left over events 
    for i=index, #stream do
        table.insert(new_stream, stream[i])
    end
    return new_stream
end



function test_lyric_parsing()
    -- test the lyrics parser
    local tests = {
    'hello',
    'he-llo',
    'he-llo th-is~a te\\-st___',
    'he-llo wo-rld_ oh~yes | a test___',
    'this is sim-ple~but fine'
    }
    
    for i,v in ipairs(tests) do    
        print(v)
        table_print(parse_lyrics(v))
        print()
    end
    
    
end