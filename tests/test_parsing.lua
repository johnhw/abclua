local abclua = require "abclua"

-- Tests check wheter ABCLua can parse a given ABC string
-- and reproduce it exactly. This only tests the parser and emitter,
-- and it only tests those strings which are unchanged by the parse/emit process.

function reproduce(str)
    -- parse, then regenerate
    local parsed = abclua.parse_abc(str, {no_expand=true}).token_stream
    stream, context = compile_tokens(parsed)
    return emit_abc(parsed)
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
    local parsed = abclua.parse_abc(str).token_stream
    abclua.precompile_token_stream(parsed)
    stream, context = compile_tokens(parsed)
    str = emit_abc(parsed)
    local mis = first_difference_string(str, result)
    if mis then
        print("Mismatch")
        print(name)
        print(result)
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
ceg & C3 | dfa & D3 | C3 & E3 & G/2 G/2 G/2 G/2G/2G/2 | && D &&& C C C]], 'Voice overlay')

check_result([[X:1
K:G
C D ~F T~.G +fermata+D !legato!G
{cg}D {ab}C {f2fe}G
"Cm7"C G "Dmaj"D A D
{cg}"Cm7"+fermata+~=D
G]],[[X:1
K:G
C D ~F T~.G !fermata!D !legato!G
{cg}D {ab}C {f2fe}G
"Cm7"C G "D"D A D
{cg}"Cm7"!fermata!~=D
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


check_reproduce([[X:1003
T:Amazing Grace
M:3/4
K:G
"D7"A/B/|(d3d)zB|
"G"d2 B/G/|B2A|"C"G2 E|"G"D2 D|"Em"G2 (3 B/A/G/|"D"B2 A|("G"G3G2)||]], 'Slurs')


check_reproduce(
[[X:1
M:3/4
K:G
V:A nm=alto
G G G | G G G | G G G
V:B clef=treble-8
e3 | e3 | e3
V:C octave=-2
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

check_result([[X:1
K:C
A A z z | ^/2A _/A =A z | ^2/3A __/9A =A z | z z z
^A A A z | _A A A z | _A A =A z | zzz]], [[X:1
K:C
A A z z | ^/2A _/2A =A z | ^2/3A _2/9A =A z | z z z
^A A A z | _A A A z | _A A =A z | zzz]],'Fractional Accidentals')

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


check_result([[X:1
U:n=g
U:p=A
U:~=!coda!
K:G
npn|~g~n|]],
[[X:1
K:G
gAg|!coda!g!coda!g|]],'User macros'
)

check_reproduce([[X:1
K:G
A B- D- D2- D3-]], 'Ties')

check_reproduce([[X:1
K:G
[abc] [def] [CEg] D]], 'Chords')

check_reproduce([[X:1
K:G
"Cm"F "D"(def) "Amin/G"[CEg] "G7"]], 'Chord names')

check_reproduce([[X:1003
T:Amazing Grace
R:Waltz
C:Carrell and Clayton 1831
N:Words by Newton 1779
O:England
M:3/4
L:1/4
Q:1/4=100
K:G
D|"G"G2 B/G/|B2 "D7"A|"Em"G2 "C"E|"G"D2 D|G2 B/G/|B2 "D7"A/B/|("D"d3|d)zB|
"G"d2 B/G/|B2A|"C"G2 E|"G"D2 D|"Em"G2 (3B/A/G/|"D"B2 A|("G"G3|G2)|]
]], 'Amazing Grace')

check_reproduce([[X:1
K:G
"Cm"y y "D"y !crescendo(!y !crescendo)!y]], 'y Spaces')

check_reproduce([[X:1
K:G
"this is free"AB C "<text" A ">around" "@here" a b c]], 'Free text')


check_reproduce([[X:1
K:G
(AB) (CD) (EFG) (EEE)]], 'Slurs')


check_result([[X:1
M:none
M:
M:C
M:C|
M:4/4
M:3/4
M:(1+3)/4
M:(2+2+2)/4
K:G
A B C]],
[[X:1
M:none
M:none
M:4/4
M:2/2
M:4/4
M:3/4
M:(1+3)/4
M:(2+2+2)/4
K:G
A B C]], 'Meters')

check_reproduce([[X:1
K:G
A B C | D E F |] A B C [| DEG ||
ABC |: DEF :|: GAB :|
|: GAB :|1 DEF |2 GEF |3 FED ||
|:: GAB ::|:: DEF ::|
|:: GAB ::|:: DEF ::|
| A B C | [4 DEF ||
| A B C | [4,5 DEF ||
| A B C | [1,4,5 DEF ||]], 'Bar types')

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
A A A
B B B\
C C C\
D D D
E E E]],
'Line breaks and continue')


check_result([[X:1
K:G
D E D | A B :|
|:: A A A ::|1 B B B :|2 c c c :|3 d d d |] D D D |: e e e :::: f f f :|
|: d e d :|: A B c :|1 g ||]],
[[X:1
K:G
D E D | A B :|
|:: A A A ::|1 B B B :|2 c c c :|3 d d d |] D D D |: e e e ::|:: f f f :|
|: d e d :|: A B c :|1 g ||]],'Repeats')


check_result([[X:1
K:G
GABcdefg
K:G ^c _g
GABcdefg z4
K:G ^^c __g _f
GABcdefg
K:G ^2/3c _/4g _/f
GABcdefg
]], 
[[X:1
K:G
GABcdefg
K:G ^c _g
GABcdefg z4
K:G ^^c __g _f
GABcdefg
K:G ^2/3c _/4g _/2f
GABcdefg]], 
'Keys with fraction accidentals')

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
"Cm7"B | "D/2"[abc] | "F7"(def) | "Gm/E"]], 
'Chord names')

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
K:G
abzabZ2| Z2 | Z4 | z z Z a]], 'Rests')


check_result([[
X:1
Q:1/8=200 "Allegro"
Q:120
Q:"Allegro"
Q:1/4=120
Q:1/8 1/8 1/4=140
K:G
A B C]], 
[[
X:1
Q:1/8=200 "Allegro"
Q:120
Q:1/4=120 "Allegro"
Q:1/4=120
Q:1/8 1/8 1/4=140
K:G
A B C]],
'Tempos')


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


check_result([[X:1
T:My song
T:Also known as my other song
+:continued
A:Kildare
C:Unknown
B:book
D:none
F:this_file.abc
G:ungrouped
H:Very little is known
H:about
+:this song
but it does support freeform text
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
w:oh the-se are so-me words to~a song
W:Th-ese app-ear at the end
Z:no one in particular
K:G]],
[[X:1
T:My song
T:Also known as my other song
+:continued
A:Kildare
C:Unknown
B:book
D:none
F:this_file.abc
G:ungrouped
H:Very little is known
H:about
+:this song
+:but it does support freeform text
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
w:oh the-se are so-me words to~a song
W:Th-ese app-ear at the end
Z:no one in particular
K:G]], 'All fields')



