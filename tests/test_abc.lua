abclua = require "abclua"
-- Print anything - including nested tables
function table_print (tt, indent, done)
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
    for key, value in pairs (tt) do
      io.write(string.rep (" ", indent)) -- indent it
      if type (value) == "table" and not done [value] then
        done [value] = true
        io.write(string.format("[%s] => table\n", tostring (key)));
        io.write(string.rep (" ", indent+4)) -- indent it
        io.write("(\n");
        table_print (value, indent + 7, done)
        io.write(string.rep (" ", indent+4)) -- indent it
        io.write(")\n");
      else
        io.write(string.format("[%s] => %s\n",
            tostring (key), tostring(value)))
      end
    end
  else
    io.write(tt .. "\n")
  end
end



local skye=[[
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
|: D>ED  | G2 G | A>BA | d3 | B>AB | E2- :|1 E | D2 |  D3 :|2 E | F2 | G3 :|  
]]


function test_chord_names()

local skye_chords=[[
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
"Dmin"D>ED | "Gmaj"G G | "Gm7"A>BA | "Dmin"d3 | "Bmaj"B>AB | E2 E | D2- | D3 :|:     
B>GB | B3 | A>EA | A3 | G>EG | G2 G | E3 | E3 | 
B>GB | B3 | A>EA | A3 | G>EG | G2 G | E3 | D3 || 
|: D>ED  | G2 G | A>BA | d3 | B>AB | E2- :|1 E | D2 |  D3 :|2 E | F2 | G3 :|  
]]

    local songs = abclua.parse_abc_multisong(skye_chords)
    abclua.make_midi_from_stream(songs[1].voices['default'].stream, 'out/skye_chords.mid')        
    
end

function test_grace_notes()
    local grace = [[
X:1
K:G
DED | ABA | DED |
{ed}DED | {fgA}ABA | {ed}DE{fA}D |
]]
    local songs = abclua.parse_abc_multisong(grace)
    local grace_stream = abclua.render_grace_notes(songs[1].voices['default'].stream)    
    abclua.make_midi_from_stream(grace_stream, 'out/grace.mid')        
    
end

function test_cross_ref()
    local xref = [[
X:1
K:G
DED | ABA | DED |
]]
    local songs = abclua.parse_abc_multisong(xref, {cross_ref=true})
    table_print(songs[1].token_stream)    
    
end


function test_trimming()
    -- test event trimming into time windows
    local songs = abclua.parse_abc_multisong(skye)
            
    local stream = songs[1].voices['default'].stream
    abclua.make_midi_from_stream(stream, 'out/skye_untrimmed.mid')
    
    -- trim events that start within 3-6 seconds
    local start_stream = abclua.trim_event_stream(stream, 'starts', 3e6, 6e6)    
    abclua.make_midi_from_stream(start_stream, 'out/skye_starts.mid')
    
    -- trim events that start within 3-6 seconds
    local end_stream = abclua.trim_event_stream(stream, 'ends', 3e6, 6e6)    
    abclua.make_midi_from_stream(end_stream, 'out/skye_ends.mid')
    
    -- trim events that start or end within 3-6 seconds
    local any_stream = abclua.trim_event_stream(stream, 'any', 3e6, 6e6)    
    abclua.make_midi_from_stream(any_stream, 'out/skye_any.mid')
    
    -- trim events that start and end within 3-6 seconds
    local within_stream = abclua.trim_event_stream(stream, 'within', 3e6, 6e6)    
    abclua.make_midi_from_stream(within_stream, 'out/skye_within.mid')
    
    -- trim events that start and end any time 3-6 seconds, but cut
    -- the events to fit exactly
    local trim_stream = abclua.trim_event_stream(stream, 'trim', 3e6, 6e6)    
    abclua.make_midi_from_stream(trim_stream, 'out/skye_trim.mid')
            
    
end


function test_fragments()
    -- Test that parsing fragments produces sensible
    -- token streams, and that token -> event conversion works
    local tokens = abclua.parse_abc_fragment('A>bA')
    table_print(tokens)
    
    local events = abclua.compile_tokens(tokens)
    table_print(events)
    
    tokens = abclua.parse_abc_fragment('X:title')
    table_print(tokens)    
    events = abclua.compile_tokens(tokens)
    table_print(events)
    
    tokens = abclua.parse_abc_fragment([[K:C
    abc]])
    table_print(tokens)    
    events = abclua.compile_tokens(tokens)
    table_print(events)


end


function test_inline()
    -- Test inline fields and chords (i.e. [] groups)
    local inline = [[
    X:1
    K:G
    A B [CEG] A B [K:G] A B F [R:remarkable]
    ]]
    
    local songs = abclua.parse_abc_multisong(inline)    
    print(abclua.emit_abc(songs[1].token_stream))
    abclua.make_midi(songs[1], 'out/inline.mid')        
end

function test_keys()
    -- Test that key signature affects notes appropriately
    local keys = [[
    X:1
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
    K:Gdor
    GABcdefg z4
    K:Gloc
    GABcdefg z4 [K:Gphy]
    GABcdefg z4
    K:G ^c _g
    GABcdefg z4
    [K:G]
    GABcdefg z4        
    K:G exp ^f
    GABcdefg z4        
    ]]
    
    local songs = abclua.parse_abc_multisong(keys)    
    print(abclua.emit_abc(songs[1].token_stream))
    abclua.make_midi(songs[1], 'out/keys.mid')
end

function test_triplets()
    -- Test that triplet timing works as expected
    local triplets = [[
    X:1
    K:G
    A A A z | (3 A A A A z | A A A z | (5:3:5 A A A A A z 
    ]]

    local songs = abclua.parse_abc_multisong(triplets)    
    print(abclua.emit_abc(songs[1].token_stream))
    abclua.make_midi(songs[1], 'out/triplets.mid')
end

function test_repeats()
    -- Test repeats and variant endings
    local repeats = [[
    X:1
    K:G
    D E D | A B  :|
    |:: A A A ::|1 B B B :|2 c c c :|3 d d d |]
    |: d e d :|: A B c :|1 g ||
    ]]
    
    local songs = abclua.parse_abc_multisong(repeats)      
    abclua.print_notes(songs[1].voices['default'].stream)
    abclua.make_midi(songs[1], 'out/repeats.mid')
end


function test_macros()
    -- Test macros, transposing macros and user macros
    local macros = [[
    X:1
    U:n=G/G
    U:p=A/A
    m:d2=d//f//d2
    m:n4=o//n//t//n4
    K:g
    A B C | p n p | d2 A | a4 B | d4 B | e,4 B |
   ]]
    
    local songs = abclua.parse_abc_multisong(macros)      
    abclua.make_midi(songs[1], 'out/macros.mid')
    abclua.print_notes(songs[1].voices['default'].stream)
    print(abclua.emit_abc(songs[1].token_stream))
    
    songs = abclua.parse_abc_multisong(macros, {no_expand=true})      
    print(abclua.emit_abc(songs[1].token_stream))
  
end


function test_accidentals()
    -- Test accidentals (sharp, flat, implied)
    local accs = [[
    X:1
    K:C
    A A z z | ^A _A =A z | ^^A __A =A z | z z z 
    ^A A A z | _A A A z | _A A =A z |  zzz
    K:none
    A A z z | ^A _A =A z | ^^A __A =A z | z z z 
    ^A A A z | _A A A z | _A A =A z |  zzz
    ]]
    
    local songs = abclua.parse_abc_multisong(accs)          
    print(abclua.emit_abc(songs[1].token_stream))
    abclua.make_midi(songs[1], 'out/accidentals.mid')
end


function test_lyrics()
    -- Test lyrics aligned with notes
    local lyrics = [[
    X:1
    K:G
    A B C D | E F G A | B4
    w:doh re me fah so la~a ti-do
    C D E F 
    w:oh-yes that's right
    G G G
    w:
    D E F
    w:lyric spacing works
    ]]

    local songs = abclua.parse_abc_multisong(lyrics)    
    print(abclua.emit_abc(songs[1].token_stream))
    abclua.print_lyrics_notes(songs[1].voices['default'].stream)
    
end

function test_octaves()
    -- Test octave specifiers
    local octaves =[[
    X:1
    K:G
    CDEFGABcdefgab
    c'd'e'f'g'a'b'
    c''d''e''f''g''a''b''
    C,D,E,F,G,A,B,
    C,,D,,E,,F,,G,,A,,B,,
    C,,,D,,,E,,,F,,,G,,,A,,,B,,,
    ]]
    local songs = abclua.parse_abc_multisong(octaves)
    table_print(songs[1].voices['default'].stream)
    abclua.make_midi(songs[1], 'out/octaves.mid')    
end

function test_parts()
    -- Test multi-part sequences and variant endings
    local parts = [[
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
    local songs = abclua.parse_abc_multisong(parts)
    abclua.make_midi(songs[1], 'out/parts.mid')
    abclua.print_notes(songs[1].voices['default'].stream)
end

function test_rhythms()
    -- Test rhythms (/ /2 1/2) dotted rhythms >< and rest durations
    -- (regular and multi-measure)
    local rhythms = [[
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
    local songs = abclua.parse_abc_multisong(rhythms)
    abclua.make_midi(songs[1], 'out/rhythms.mid')
    print(abclua.emit_abc(songs[1].token_stream))
end


function test_voices()
    -- Test multi-voice output
    local voices = [[
    X:1    
    M:3/4
    V:B octave=-2
    K:G
    V:A
    G G G | G G G | G G G
    V:B
    e3 | e3 | e3
    V:C transpose=4 octave=0
    b3 | d3 | b/ d/ b/ f/ a/ b/
    ]]
    local songs = abclua.parse_abc_multisong(voices)
    abclua.make_midi(songs[1], 'out/voices.mid')    
    print(abclua.emit_abc(songs[1].token_stream))
end

function test_clefs()   
    -- Test clef definitions on the key line
    local clefs = [[
    X:1    
    K:G clef=alto
    K:G bass
    K:G clef=treble-8
    K:G clef=treble t=-4
    K:G clef=treble transpose=-4
    K:G middle=3 transpose=-4 octave=2 bass
    K:G clef=treble-8
    ]]
    local songs = abclua.parse_abc_multisong(clefs)
    print(abclua.emit_abc(songs[1].token_stream))
end



function test_directives()
    local function print_args(song, directive, arguments)
        for i,v in ipairs(arguments) do
            print(v)
        end
    end
    abclua.register_directive('printargs', print_args)
    local directives = [[
    I:gracenote 1/64
    I:pagesize A4
    I:abc-version 2.0
    %%printargs these are arguments
    K:g
    A B [R:this is a] G
    ]]
    local songs = abclua.parse_abc_multisong(directives)
    table_print(songs[1].voices['default'].context.directives)
    print(abclua.emit_abc(songs[1].token_stream))
end

function test_decorations()
    -- Test chords, grace notes and decorations
    local decorations = [[
    X:1    
    K:G
    C D ~F .G +fermata+D !legato!G 
    {cg}D {ab}C {f2fe}G
    "Cm7"C G "Dmaj"D A D
    {cg}"Cm7"+fermata+~=D    
    ]]
    local songs = abclua.parse_abc_multisong(decorations)
    abclua.make_midi(songs[1], 'out/decorations.mid')    
    print(abclua.emit_abc(songs[1].token_stream))
end


function test_overlay()
    -- Test voice overlay with &
    local overlay = [[
    X:1    
    K:G
    ceg & C3 | dfa & D3 | C3 & E3 & G/ G/ G/  G/G/G/ | D D D |
    C C C & E E E | F F F & G E G |
    ]]
    local songs = abclua.parse_abc_multisong(overlay)
    abclua.make_midi(songs[1], 'out/overlay.mid')    
    print(abclua.emit_abc(songs[1].token_stream))
end


function test_rests()
    -- Test rests and measure rests
    local rests = [[
    X:1    
    K:G
    c z c z2 | Z  | c c c c |  Z2 | c z c z
    ]]
    local songs = abclua.parse_abc_multisong(rests)
    abclua.make_midi(songs[1], 'out/rests.mid')    
    table_print(songs[1].token_stream)
    print(abclua.emit_abc(songs[1].token_stream))
end

function test_include()
    -- test file inclusion
    local includes = [[
    %%abc-include tests/notarealfile.abc
    X:4    
    K:G
    %%abc-include tests/setkey.abc
    CDEFGab z2
    %%abc-include tests/tune.abc
    [I:abc-include tests/tune.abc]
    %%abc-include tests/recursive.abc
    ]]
    local songs = abclua.parse_abc_multisong(includes)
    abclua.make_midi(songs[1], 'out/includes.mid')    
    print(abclua.emit_abc(songs[1].token_stream))
end

    
function test_skye()
    -- test a simple tune

    local songs = abclua.parse_abc_multisong(skye)
    for i,v in ipairs(songs) do
        abclua.make_midi(songs[1], 'out/skye.mid')        
        print(abclua.emit_abc(v.token_stream))
    end 
end

function test_file()
    local songs = abclua.parse_abc_file('tests/p_hardy.abc')
    local title
    for i,v in ipairs(songs) do
        if v.metadata.title then
            title = v.metadata.title[1] or 'untitled'
        else
            title = 'untitled'
        end
        title = title:gsub(' ', '_')
        title = title:gsub('/', '')        
        title = title:gsub('?', '')        
        title = title:gsub('#', '')        
        title = title:gsub('~', '')        
        title = title:gsub('"', '')        
        title = title:gsub("'", '')        
        title = title:gsub("`", '')        
        title = title:gsub("%%", '')        
        
        abclua.make_midi(v, 'out/songs/'..title..'.mid')
        
    end 
end


function test_tempos()

  -- Test rests and measure rests
    local tempos = [[
    X:1
    Q:120
    Q:1/8=120
    Q:"allegro"
    Q:"lento"
    Q:"allegro" 1/4=120
    Q:1/4=120 "allegro"     
    K:G    
    ]]
    local songs = abclua.parse_abc_multisong(tempos) 
    table_print(songs[1].token_stream)
end

function test_validate()
    -- empty
    print(abclua.emit_abc(abclua.validate_token_stream({})))
    print()
    print(abclua.emit_abc(abclua.validate_token_stream(abclua.parse_abc_fragment([[
    T:title
    X:2
    K:G
    ]]))))
    print()
    print(abclua.emit_abc(abclua.validate_token_stream(abclua.parse_abc_fragment([[
    T:title
    X:2
    K:G
    ABCD]]))))
    print()
    print(abclua.emit_abc(abclua.validate_token_stream(abclua.parse_abc_fragment([[
    T:title
    X:2    
    ABCD
    K:G
    ]]))))
    print()
    print(abclua.emit_abc(abclua.validate_token_stream(abclua.parse_abc_fragment([[
    ABCD
    K:G
    ]]))))
    
    print()
    print(abclua.emit_abc(abclua.validate_token_stream(abclua.parse_abc_fragment([[
    ABCD
    ]]))))
    
    print()
    print(abclua.emit_abc(abclua.validate_token_stream(abclua.parse_abc_fragment([[
    ABCD
    K:G
    ]]))))
    
end

function test_propagate()
    -- test acciental propagation modes
    local propagate =  [[
    K:G
    %%propagate-accidentals pitch
    A ^A B ^B A B a' B, | B A |
    %%propagate-accidentals not
    A ^A B ^B A B a' B, | B A |
    %%propagate-accidentals octave
    A ^A B ^B A B a' B, | B A |
    ]]
    local songs = abclua.parse_abc_multisong(propagate) 
    table_print(abclua.filter_event_stream(songs[1].voices['default'].stream, 'note'))
    abclua.make_midi(songs[1], 'out/propagate.mid')        
       
end


function test_bar_timing()
    local timing = [[
    M:3/4
    L:1/4
    K:G
    %%enable-bar-warnings
    A B C | D E F | G E G | F A F F | E D | A B C- | D E F |
    ]]
    local songs = abclua.parse_abc_multisong(timing)    
    table_print(abclua.filter_event_stream(songs[1].voices['default'].stream, 'note'))       
end
 
function test_broken()
    local broken = [[
    K:G
    %%MIDI ratio 2 1
    A>BB | B>BB | B>B>F |
    %%MIDI ratio 3 1
    A>BB | B>BB | B>B>F |
    %%MIDI ratio 4 1
    A>BB | B>BB | B>B>F |
    %%MIDI ratio 4 3
    A>BB | B>BB | B>B>F ]]
    local songs = abclua.parse_abc_multisong(broken) 
    abclua.make_midi(songs[1], 'out/broken.mid')        
end
 
function test_nested_tuplet()
    local nested = [[
    K:G
    A A A A |
    (3 A A A A A |
    (7:5:7 A A (3 A A A A A
    ]]
    local songs = abclua.parse_abc_multisong(nested)
    abclua.make_midi(songs[1], 'out/nested.mid')        
end
 
function test_bar_numbers()
    local bar_numbers = [[
    X:1
    K:G
    %%measurefirst 0
    A | G>A>F>F |
    %%setbarnb 5
    F>F>A>G | D>EAA |
    ]]
    local songs = abclua.parse_abc_multisong(bar_numbers)
    table_print(songs[1].token_stream)
end

function test_non_metric()
    local unmetered = [[
    X:1
    K:G
    M:none
    A | G>A>F>F | G G G G G G A F | FF | D A B E E | F |    
    ]]
    local songs = abclua.parse_abc_multisong(unmetered)
    precompile_token_stream(songs[1].token_stream)
    table_print(songs[1].token_stream)    
end


function test_bar_time()
    local bar_time = [[
    X:1
    K:G
    M:3/4
    L:1/4
    G G G  | [M:4/4] G G G G | [M:5/4] G G G G G      
    ]]
    local songs = abclua.parse_abc_multisong(bar_time)
    precompile_token_stream(songs[1].token_stream)
    table_print(songs[1].token_stream)    
end

test_bar_time()
test_non_metric()
test_nested_tuplet()
test_bar_numbers()
test_broken()
test_bar_timing()
test_propagate()
test_validate()
test_tempos()
test_rests()
test_cross_ref()  
test_octaves()  
test_include()
test_overlay()
test_macros()
test_directives()
test_clefs()
test_decorations()
test_inline()
test_keys()
test_trimming()
test_grace_notes()
test_chord_names()
test_voices()
test_rhythms()
test_accidentals()
test_repeats()
test_lyrics()
test_parts()
test_fragments()
test_triplets()
test_skye()
test_file()


