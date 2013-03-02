-- verify that pitches are rendered correctly
abclua = require "abclua"

function get_lyrics(stream)
    -- return a table representing the time of each lyric in the stream
    local notes = {}
    for i,v in ipairs(stream) do        
        if v.event=='lyric' then
            
            table.insert(notes, {v.syllable, v.t/1e6})
        end
    end
    return notes
end


function verify_lyrics(str, result, test)
    -- verify that the lyric timings match the expected values
    local songs = abclua.parse_abc_multisong(str) 
    
    local stream = songs[1].voices['default'].stream

    local lyrics = get_lyrics(stream)       
    
    for i, v in ipairs(result) do        
        assert(v[1]==lyrics[i][1], test..' syllable')
        assert(v[2]==lyrics[i][2], test..' time')        
    end
    print(test.." passed OK") 
end

function test_lyrics()
    -- Test repeats and variant endings
    
    verify_lyrics([[
    X:1
    K:C
    Q:1/4=60
    L:1/4
    C D E F
    w: oh there we go
    ]], {{'oh',0}, {'there',1}, {'we', 2}, {'go',3}
    }, 'Simple lyrics')
        
    verify_lyrics([[
    X:1
    K:C
    Q:1/4=60
    L:1/4
    C D E F
    w: oh the-re we~go
    ]], {{'oh',0}, {'the',1}, {'re', 2}, {'we go',3}
    }, 'Dash and tilde lyrics')
    
        
    verify_lyrics([[
    X:1
    K:C
    Q:1/4=60
    L:1/4
    C D E F G A B
    w: - - oh the-re
    ]], {{'oh',2}, {'the',3}, {'re', 4}
    }, 'Initial align')
    
    
    verify_lyrics([[
    X:1
    K:C
    Q:1/4=60
    L:1/4
    C D E F G A B C D
    w: - - oh the-re - we - go
    ]], {{'oh',2}, {'the',3}, {'re', 4}, {'we',6}, {'go', 8}
    }, 'Full lyrics align')
    
    
    verify_lyrics([[
    X:1
    K:C
    Q:1/4=60
    L:1/4
    C D E F G A B C C D E F
    w: we go_ aw-ay___ to
    ]], {{'we',0}, {'go',1}, {'aw', 3}, {'ay',4}, {'to', 8}
    }, 'Full lyrics align')
    

    verify_lyrics([[
    X:1
    K:C
    Q:1/4=60
    L:1/4
    C D E F G A B C C D E F
    w: we go_ aw-ay___ to
    ]], {{'we',0}, {'go',1}, {'aw', 3}, {'ay',4}, {'to', 8}
    }, 'Full lyrics align')
        
        
        verify_lyrics([[
    X:1
    K:C
    Q:1/4=60
    L:1/4
    C D E F | G A B C | C D E F
    w: we go| to the market| later
    ]], {{'we',0}, {'go',1}, {'to', 4}, {'the',5}, {'market', 6}, {'later', 8}
    }, 'Bar lyrics align')
    verify_lyrics([[
    X:1
    K:C
    Q:1/4=60
    L:1/4
    C D E F 
    w:* we * go
    ]], {{'we',1}, {'go',3}
    }, 'Asterisks in lyrics')
    
    
    verify_lyrics([[
    X:1
    K:C
    Q:1/4=60
    L:1/4
    C D E F |
    w:here we go go
    G A B C |
    w:
    D E D A |
    w:oh yes we do
    ]], {{'here',0}, {'we',1},
    {'go',2}, {'go',3}, {'oh',8}, {'yes',9}, {'we',10},{'do',11}
    }, 'Aligned with blank w:')
    
    verify_lyrics([[
    X:1
    K:C
    Q:1/4=60
    L:1/4
    C D E F |   
    G A B C |
    w:
    D E D A |
    w:oh yes we do
    ]], {{'oh',8}, {'yes',9}, {'we',10},{'do',11}
    }, 'Aligned with blank w: not on start')
    
    -- doesn't work
    
    -- verify_lyrics([[
    -- X:1
    -- K:C
    -- Q:1/4=60
    -- L:1/4
    -- C D E F
    -- G A B C
    -- w:oh there we go    
    -- w:away again to there
    -- ]], {
    -- {'oh',0}, {'there',1}, {'we',2}, {'go',3},
    -- {'away',4}, {'again',5}, {'to',6}, {'there',7}
    -- }, 'Lyrics in repeats')
    
    -- verify_lyrics([[
    -- X:1
    -- P:A2
    -- Q:1/4=60
    -- L:1/4
    -- K:C
    -- p:A
    -- C D E F
    -- G A B C
    -- w:oh there we go    
    -- w:away again to there
    -- ]], {
    -- {'oh',0}, {'there',1}, {'we',2}, {'go',3},
    -- {'away',4}, {'again',5}, {'to',6}, {'there',7}
    -- }, 'Lyrics in repeated parts')
    
    
    
    print("Lyrics passed OK")
end


test_lyrics()

