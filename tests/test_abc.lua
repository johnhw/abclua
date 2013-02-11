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
|: D>ED | G2 G | A>BA | d3 | B>AB | E2- :|1 E | D2 |  D3 :|2 E | F2 | G3 :|  
]]

function test_fragments()
    -- Test that parsing fragments produces sensible
    -- token streams, and that token -> event conversion works
    tokens = abclua.parse_abc_fragment('A>bA')
    table_print(tokens)

    events = abclua.fragment_to_stream(tokens)
    table_print(events)
end


function test_inline()
    -- Test inline fields and chords (i.e. [] groups)
    inline = [[
    X:1
    K:G
    A B [CEG] A B [K:G] A B F
    ]]
    
    songs = abclua.parse_all_abc(inline)    
    print(abclua.token_stream_to_abc(songs[1].token_stream))
    abclua.make_midi(songs[1], 'out/inline.mid')
    
    
end

function test_keys()
    -- Test that key signature affects notes appropriately
    keys = [[
    X:1
    K:none
    CDEFGAB z4
    K:C
    CDEFGAB z4
    K:D
    DEFGABc z4
    K:D#
    DEFGABc z4    
    K:G
    GABcdef z4
    K:Gb
    CDEFGAB z4
    K:Gdor
    CDEFGAB z4
    K:Gloc
    CDEFGAB z4 [K:Gphr]
    CDEFGAB z4
    K:G ^c _g
    CDEFGAB z4
    [K:G]
    CDEFGAB z4        
    K:G exp ^f
    CDEFGAB z4        
    ]]
    
    songs = abclua.parse_all_abc(keys)    
    table_print(songs[1].token_stream)
    abclua.make_midi(songs[1], 'out/keys.mid')
    
    
end

function test_triplets()
    -- Test that triplet timing works as expected
    triplets = [[
    X:1
    K:G
    A A A z | (3 A A A A z | A A A z | (5:3:5 A A A A A z 
    ]]

    songs = abclua.parse_all_abc(triplets)    
    abclua.make_midi(songs[1], 'out/triplets.mid')
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
    abclua.make_midi(songs[1], 'out/repeats.mid')
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
    abclua.make_midi(songs[1], 'out/accidentals.mid')
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
    abclua.make_midi(songs[1], 'out/parts.mid')
    abclua.print_notes(songs[1].voices['default'].stream)
end

function test_rhythms()
    -- Test rhythms (/ /2 1/2) dotted rhythms >< and rest durations
    -- (regular and multi-measure)
    rhythms = [[
    X:1
    M:3/4
    K:G
    A A/ A// z
    A A/2 A/3 A/4 z
    A1/2 A1/4 A1/5 z
    A2/3 A3/4 A8/5 z
    A z A z1 A z2 A z/ A z/ A  z4
    A A A A z A>A A>A z A<A A<A z Z a a a Z2 a a a
    ]]
    songs = abclua.parse_all_abc(rhythms)
    abclua.make_midi(songs[1], 'out/rhythms.mid')
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
    abclua.make_midi(songs[1], 'out/voices.mid')    
end

    
function test_skye()
    local songs = abclua.parse_all_abc(skye)
    for i,v in ipairs(songs) do
        abclua.make_midi(songs[1], 'out/skye.mid')        
        print(abclua.token_stream_to_abc(v.token_stream))
    end 
end

function test_file()
    local songs = abclua.parse_abc_file('tests/p_hardy.abc')
        
    for i,v in ipairs(songs) do
        title = v.metadata.title or 'untitled'
        title = title:gsub(' ', '_')
        title = title:gsub('/', '')        
        
        abclua.make_midi(v, 'out/songs/'..title..'.mid')
        
    end 
end

test_inline()
--test_keys()
-- test_voices()
-- test_rhythms()
-- test_accidentals()
-- test_repeats()
-- test_lyrics()
-- test_parts()
-- test_fragments()
-- test_triplets()
-- test_skye()
-- test_file()
