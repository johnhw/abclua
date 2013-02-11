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
    tokens = abclua.parse_abc_fragment('A>bA')
    table_print(tokens)

    events = abclua.fragment_to_stream(tokens)
    table_print(events)
end

function test_triplets()
    triplets = [[
    X:1
    K:G
    A A A z | (3 A A A A z | A A A z | (5:3:5 A A A A A z 
    ]]

    songs = abclua.parse_all_abc(triplets)
    table_print(songs[1].voices['default'].stream)
    abclua.make_midi(songs[1], 'triplets.mid')
end

function test_parts()
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
    
    --table_print(songs[1].token_stream)
    --table_print(songs[1].voices['default'].stream)
    abclua.make_midi(songs[1], 'parts.mid')
    abclua.print_notes(songs[1].voices['default'].stream)
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
    for i,v in ipairs(songs) do
        abclua.make_midi(songs[1], 'song1.mid')
        print(abclua.token_stream_to_abc(v.token_stream))
    end 
end


test_parts()
--test_skye()
--test_file()
