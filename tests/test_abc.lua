require "abclua"

skye=[[
% this is a comment
X:437
T:Over the Sea to Skye
T:The Skye Boat Song 
S:Childhood memories
V:tenor
H:Written a long time ago
about Skye, an island off
Scotland
Z:Nigel Gatherer
+:and friends
Q:1/4=140 
M:3/4
L:1/4
K:G
D>ED | G G | A>BA | d3 | B>AB | E2 E | D2- | D3 :|:     
B>GB | B3 | A>EA | A3 | G>EG | G2 G | E3 | E3 | 
B>GB | B3 | A>EA | A3 | G>EG | G2 G | E3 | D3 || 
|: D>ED | G2 G | A>BA | d3 | B>AB | E2 :|1 E | D2 |  D3 :|2 E | F2 | G3 :|  
]]

function test_fragments()
    -- Test that parsing fragments produces sensible
    -- token streams, and that token -> event conversion works
    tokens = abclua.parse_abc_fragment('A>bA')
    table_print(tokens)

    events = abclua.fragment_to_stream(tokens)
    table_print(events)
end

function test_triplets()
    -- Test that triplet timing works as expected
    triplets = [[
    X:1
    K:G
    A A A z | (3 A A A A z | A A A z | (5:3:5 A A A A A z 
    ]]

    songs = abclua.parse_all_abc(triplets)    
    abclua.make_midi(songs[1], 'triplets.mid')
end

function test_repeats()
    -- Test repeats and variant endings
    repeats = [[
    X:1
    K:G
    D E D | A B  :|
    |:: A A A ::|1 B B B :|2 c c c :|3 d d d |]
    |: d e d :|: A B c :|1 g ||
    ]]
    
    songs = abclua.parse_all_abc(repeats)      
    abclua.print_notes(songs[1].voices['default'].stream)
    abclua.make_midi(songs[1], 'repeats.mid')
end


function test_accidentals()
    -- Test accidentals (sharp, flat, implied)
    accs = [[
    X:1
    K:C
    A A z z | ^A _A =A z | ^^A __A =A z | z z z 
    ^A A A z | _A A A z | _A A =A z |  zzz
    ]]
    
    songs = abclua.parse_all_abc(accs)          
    abclua.print_notes(songs[1].voices['default'].stream)
    abclua.make_midi(songs[1], 'accidentals.mid')
end


function test_lyrics()
    -- Test lyrics aligned with notes
    lyrics = [[
    X:1
    K:G
    A B C D | E F G A | B4
    w:doh re me fah so la~a ti-do
    ]]

    songs = abclua.parse_all_abc(lyrics)    
    abclua.print_lyrics_notes(songs[1].voices['default'].stream)
    
end

function test_parts()
    -- Test multi-part sequences and variant endings
    parts = [[
    X:1
    P:ABABA2(CAC)2
    M:3/4
    K:G
    P:A
    D E D [1 G |] [2 E F |] [5,6 a,, |]
    P:B
    d e d 
    P:C
    a a a [2 a'
    ]]
    songs = abclua.parse_all_abc(parts)
    abclua.make_midi(songs[1], 'parts.mid')
    abclua.print_notes(songs[1].voices['default'].stream)
end

function test_voices()
    -- Test multi-voice output
    voices = [[
    X:1    
    M:3/4
    K:G
    V:A
    G G G | G G G | G G G
    V:B
    e3 | e3 | e3
    V:C
    b3 | d3 | b/ d/ b/ f/ a/ b/
    ]]
    songs = abclua.parse_all_abc(voices)
    abclua.make_midi(songs[1], 'voices.mid')    
end

    
function test_skye()
    local songs = abclua.parse_all_abc(skye)
    for i,v in ipairs(songs) do
        abclua.make_midi(songs[1], 'skye.mid')
        print(abclua.token_stream_to_abc(v.token_stream))
    end 
end

function test_file()
    local songs = abclua.parse_abc_file('tests/p_hardy.abc')
    abclua.make_midi(songs[2], 'song1.mid')
    print(abclua.token_stream_to_abc(songs[2].token_stream))
    for i,v in ipairs(songs) do
        v=v
        
    end 
end

-- test_voices()
-- test_accidentals()
-- test_repeats()
-- test_lyrics()
-- test_parts()
-- test_fragments()
-- test_triplets()
-- test_skye()
--test_file()
