require "parse_abc"

skye=[[
% this is a comment
X:437
T:Over the Sea to Skye
T:The Skye Boat Song 
S:Childhood memories
V:tenor
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


function test_skye()
    songs = parse_all_abc(skye)
    for i,v in ipairs(songs) do
        make_midi(songs[1], 'skye.mid')
        print(journal_to_abc(v.journal))
    end 
end

test_skye()