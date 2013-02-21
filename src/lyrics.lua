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
    lyrics <- ( (({:syl: <syllable> :} {:br: <break> :}) -> {} *)  {:syl: (<syllable>)  :} -> {} ) -> {}
    break <- ( ( %s +)  / ('-')  )
    
    syllable <- ( ([^%s-] +) )        
    ]]
    
    local match = re.match(lyrics, lyrics_pattern)
    -- empty lyric pattern
    if not match then
        return {}
    end
    
    local lyric_sequence = {}
    
    local next_advance = 1 -- always start on first note of the song
    
    -- construct the syllable sequence
    for i,syllable in ipairs(match) do
        local syl = syllable.syl
        -- fix backquotes
        syl = syl:gsub('`', '-')
        -- note advance on trailing underscore
        local note_count = 1
        for c in syl:gmatch"_" do
            note_count = note_count + 1
        end
        
        local advance = next_advance
        
        -- bar advance
        if string.sub(syl,-1)=='|' then
            next_advance = 'bar'
        else
            next_advance = note_count
        end
        
        -- remove _, ~ and | from the display syllables
        for i,v in ipairs(match) do
            syl = syl:gsub('|', '')        
            syl = syl:gsub('_', '')        
            syl = syl:gsub('~', ' ')        
        end
                
        table.insert(lyric_sequence, {syllable=syl, advance=advance, br=syllable.br})
    end
    return lyric_sequence
end


function insert_lyrics_stream(lyrics, stream, new_stream, stream_index)
    -- Takes a lyrics structure and an event stream, and inserts the lyric
    -- events into the stream accordingly. Returns a new event stream
    -- with the lyrics in place. Lyrics are aligned to lyric_align events in the stream
    local lyric_index = 1
    
    local note_wait 
    local advance = false
    
    -- determine where to wait for the first lyric
    if lyrics[lyric_index] then
        note_wait = lyrics[lyric_index].advance
    else
        note_wait = 'end'
    end
    
    local v
    while stream_index<#stream do    
        v = stream[stream_index]
        
        -- insert original event
        table.insert(new_stream, v)
        
        -- if waiting for a bar, reset on next bar symbol
        if v.event == 'bar' then         
            if note_wait == 'bar' then
                advance = true                
            end
        end
        
        -- note; decrement wait if we're not looking for a bar
        if v.event=='note' then
            if note_wait ~= 'end' and note_wait ~= 'bar' then
                note_wait = note_wait - 1                
                -- wait hit zero; insert the lyric syllable
                if note_wait == 0 then
                    advance = true                                        
                end                
            end            
        end
            
        -- if we've waited long enough, insert the lyric symbol into the stream
        if advance then
            
            table.insert(new_stream, {event='lyric', syllable=lyrics[lyric_index].syllable})
            lyric_index = lyric_index + 1                    
            -- move on the lyric pointer
            if lyric_index > #lyrics then
                note_wait = 'end'
            else
                note_wait = lyrics[lyric_index].advance                
            end
            
            advance = false
        end
        
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