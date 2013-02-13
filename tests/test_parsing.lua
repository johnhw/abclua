require "abclua"

-- Tests check wheter ABCLua can parse a given ABC string
-- and reproduce it exactly. This only tests the parser and emitter,
-- and it only tests those strings which are unchanged by the parse/emit process.

function reproduce(str)
    -- parse, then regenerate
    return token_stream_to_abc(abclua.parse_abc(str, {no_expand=true}).token_stream)
end


    
function check_reproduce(str, name)
    -- Verify that a string is reproduced by the ABC parser/emitter    
    -- Macro expansion is disabled
    local r = reproduce(str)    
    local mis = first_difference_string(str, r)
    -- print mismatch
    if mis then
        print("Mismatch")
        print(str)
        print(string.sub(r, 1, mis-1)..'-->'..string.sub(r, mis-1))
        print(r)
        print()
        print()
    end           
    assert(str==reproduce(str))   
    
    if name then 
        print("Test "..name.. " passed OK")
    end
end


function check_result(str, result, name)    
    -- Verify that passing a string through the parser gives a particular result
    -- This includes macro expansion
    str = token_stream_to_abc(abclua.parse_abc(str).token_stream)
    local mis = first_difference_string(str, result)
    if mis then
        print("Mismatch")
        print(name)
        print(str)        
        print(string.sub(result, 1, mis)..'-->'..string.sub(result, mis))
        
    end
        
    assert(str==result)
    if name then 
        print("Test "..name.. " passed OK")
    end
end


check_reproduce([[X:1]], 'Xref')
check_reproduce([[X:1
K:G
a a a]], 'Key and notes')

check_reproduce([[
I:abc-creator abclua
%%directive this is a directive
K:G]], 'Directives'
)

check_reproduce([[X:1
K:G
ceg & C3 | dfa & D3 | C3 & E3 & G/2 G/2 G/2 G/2G/2G/2 |]], 'Voice overlay')

check_reproduce([[X:1
K:G
C D ~F .G +fermata+D !legato!G
{cg}D {ab}C {f2fe}G
"Cm7"C G "Dmaj"D A D
{cg}"Cm7"+fermata+~=D
G]], 'Decorations and chord names')

check_reproduce(
[[
X:1
K:G alto
K:G bass
K:G
K:G treble transpose=-4
K:G bass octave=2
K:G bass middle=3]], 'Key with clefs')

check_reproduce(
[[X:1
M:3/4
K:G
V:A
G G G | G G G | G G G
V:B
e3 | e3 | e3
V:C
b3 | d3 | b/2 d/2 b/2 f/2 a/2 b/2]], 'Multi-voice')


check_reproduce(
[[X:1
M:3/4
K:G
A A/2 A/4 z
A A/2 A/3 A/4 z
A1/2 A1/4 A1/5 z
A2/3 A3/4 A8/5 z
A z A z1 A z2 A z/2 A z/2 A z4
A A A A z A>A A>A z A<A A<A z Z a a a Z2 a a a]], 'Note durations')



check_reproduce(
[[X:1
P:ABABA2(CAC)2
M:3/4
K:G
P:A
D E D [1 G |] [2 E F |] [5,6 A,, |]
P:B
d e d
P:C
a a a [2 a']],  'Multi-parts')


check_reproduce(
[[X:1
K:G
CDEFGabcdefgab
a'b'c'd'e'f'g'a''b''
a''b''c''d''e''f''g''a'''b'''
C,D,E,F,G,AB
C,,D,,E,,F,,G,,A,B,
C,,,D,,,E,,,F,,,G,,,A,,B,,]], 'Octaves')

check_reproduce([[X:1
K:G
A B C D | E F G A | B4
w:doh re me fah so la~a ti-do]], 'Lyrics')

check_reproduce([[X:1
K:C
A A z z | ^A _A =A z | ^^A __A =A z | z z z
^A A A z | _A A A z | _A A =A z | zzz]], 'Accidentals')

check_reproduce([[X:1
m:d2=d//f//d2
m:n4=o//n//t//n4
K:G
A B C | d2 A | a4 B | d4 B | E4 B |]],'Unexapnded macros')

check_result([[X:1
m:d2=gg
K:G
d2]],
[[X:1
K:G
gg]],'Macro expansion'
)


check_reproduce([[X:1
K:G
A B- D- D2- D3-]], 'Ties')



check_result([[X:1
m:n2=lmnopq
K:G
A2]],
[[X:1
K:G
FGABcd]],'Transposing macro expansion'
)


check_reproduce([[X:1
K:G
D E D | A B :|
|:: A A A ::|1 B B B :|2 c c c :|3 d d d |]
|: d e d :|: A B c :|1 g ||]], 'Repeats')

check_reproduce([[X:1
K:none
CDEFGABc z4
K:C
CDEFGABc z4
K:D
DEFGABcd z4
K:E
EFGABcde z4
K:G
GABcdefg z4
K:Gb
GABcdefg z4
K:C#
GABcdefg z4
K:Gdor
GABcdefg z4
K:Gloc
GABcdefg z4 [K:Gphr]
GABcdefg z4
K:G ^c _g
GABcdefg z4
[K:G]
GABcdefg z4
K:Gexp ^f
GABcdefg z4]], 'Keys with modes and accidentals')

check_reproduce(
[[X:1
K:G
A B [CEG] A B [K:G] A B F [R:remarkable] B]], 'Inline fields and chord groups'
)

check_reproduce(
[[X:1
K:G
A B (CDE) (AB) G]], 'Slur groups'
)

check_reproduce([[
X:1
K:G
DED | ABA | DED |
{ed}DED | {fgA}ABA | {ed}DE{fA}D |]], 'Grace notes')

check_reproduce([[
X:1
K:G
"Cm7"B | "DMaj"[abc] | "F7"(def) | "Gm"]], 'Chord names')

check_reproduce([[
X:1
L:1/8
L:1/2
L:1/1
L:1/16
K:G
A B C]], 'Note lengths')


check_reproduce([[
X:1
Q:1/8=200 "Allegro"
Q:120
Q:1/4=120
Q:1/8 1/8 1/4=140
K:G
A B C]], 'Tempos')


check_reproduce([[X:1
K:G
A A A z | (3  A A A A z | (3::2  A A A z | (5:3:4  A A A A A z | (3:4:2  D D D]],'Tuplets')

check_result([[
X:1
T:My song
whose title
+:just goes on
K:G
]], [[X:1
T:My song
+:whose title
+:just goes on
K:G]], 'Continuation')


check_reproduce([[X:1
T:My song
+:continued
A:Kildare
C:Unknown
B:book
D:none
F:this_file.abc
G:ungrouped
H:Very little is known
I:abc-creator ABCLua
L:1/4
M:4/4
N:A test song
O:The test suite
R:reel
P:AB(CA)2B2
Q:1/4=120
R:remarkable
S:a source
s:g ^ = a
U:n=b
w:oh the-se are so-me words to~a song
W:Th-ese app-ear at the end
Z:no one in particular
K:G]], 'All fields')


