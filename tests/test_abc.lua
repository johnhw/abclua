
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

require "abclua_all"

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
|: D>ED  | G2 G | A>BA | d3 | B>AB | E2- :|1 E | D2 |  D3 :|2 E | F2 | G3 :|  
]]


function test_chord_names()

skye_chords=[[
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

    songs = abclua.parse_all_abc(skye_chords)
    abclua.make_midi_from_stream(songs[1].voices['default'].stream, 'out/skye_chords.mid')        
    
end

function test_grace_notes()
    grace = [[
X:1
K:G
DED | ABA | DED |
{ed}DED | {fgA}ABA | {ed}DE{fA}D |
]]
    songs = abclua.parse_all_abc(grace)
    grace_stream = abclua.render_grace_notes(songs[1].voices['default'].stream)
    abclua.make_midi_from_stream(grace_stream, 'out/grace.mid')        
    
end

function test_trimming()
    -- test event trimming into time windows
    local songs = abclua.parse_all_abc(skye)
            
    stream = songs[1].voices['default'].stream
    abclua.make_midi_from_stream(stream, 'out/skye_untrimmed.mid')
    
    -- trim events that start within 3-6 seconds
    start_stream = trim_event_stream(stream, 'starts', 3e6, 6e6)    
    abclua.make_midi_from_stream(start_stream, 'out/skye_starts.mid')
    
    -- trim events that start within 3-6 seconds
    end_stream = trim_event_stream(stream, 'ends', 3e6, 6e6)    
    abclua.make_midi_from_stream(end_stream, 'out/skye_ends.mid')
    
    -- trim events that start or end within 3-6 seconds
    any_stream = trim_event_stream(stream, 'any', 3e6, 6e6)    
    abclua.make_midi_from_stream(any_stream, 'out/skye_any.mid')
    
    -- trim events that start and end within 3-6 seconds
    within_stream = trim_event_stream(stream, 'within', 3e6, 6e6)    
    abclua.make_midi_from_stream(within_stream, 'out/skye_within.mid')
    
    -- trim events that start and end any time 3-6 seconds, but cut
    -- the events to fit exactly
    trim_stream = trim_event_stream(stream, 'trim', 3e6, 6e6)    
    abclua.make_midi_from_stream(trim_stream, 'out/skye_trim.mid')
            
    
end


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
    A B [CEG] A B [K:G] A B F [R:remarkable]
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
    
    songs = abclua.parse_all_abc(keys)    
    print(abclua.token_stream_to_abc(songs[1].token_stream))
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
    print(abclua.token_stream_to_abc(songs[1].token_stream))
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


function test_macros()
    -- Test macros, transposing macros and user macros
    macros = [[
    X:1
    U:n=G/G
    U:p=A/A
    m:d2=d//f//d2
    m:n4=o//n//t//n4
    K:g
    A B C | p n p | d2 A | a4 B | d4 B | e,4 B |
   ]]
    
    songs = abclua.parse_all_abc(macros)      
    abclua.print_notes(songs[1].voices['default'].stream)
    print(abclua.token_stream_to_abc(songs[1].token_stream))
    
    songs = abclua.parse_all_abc(macros, {no_expand=true})      
    print(abclua.token_stream_to_abc(songs[1].token_stream))
    abclua.make_midi(songs[1], 'out/macros.mid')
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
    print(abclua.token_stream_to_abc(songs[1].token_stream))
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
    print(abclua.token_stream_to_abc(songs[1].token_stream))
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
    print(abclua.token_stream_to_abc(songs[1].token_stream))
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
    print(abclua.token_stream_to_abc(songs[1].token_stream))
end

function test_clefs()
    -- Test clef definitions on the key line
    clefs = [[
    X:1    
    K:G clef=alto
    K:G bass
    K:G clef=treble-8
    K:G clef=treble t=-4
    K:G clef=treble transpose=-4
    K:G middle=3 transpose=-4 octave=2 bass
    K:G clef=treble-8
    ]]
    songs = abclua.parse_all_abc(clefs)
    print(abclua.token_stream_to_abc(songs[1].token_stream))
end



function test_directives()
    local function print_args(song, directive, arguments)
        for i,v in ipairs(arguments) do
            print(v)
        end
    end
    abclua.register_user_directive('printargs', print_args)
    directives = [[
    I:gracenote 1/64
    I:pagesize A4
    I:abc-version 2.0
    %%printargs these are arguments
    K:g
    A B [R:this is a] G
    ]]
    songs = abclua.parse_all_abc(directives)
    print(abclua.token_stream_to_abc(songs[1].token_stream))
end

function test_decorations()
    -- Test chords, grace notes and decorations
    decorations = [[
    X:1    
    K:G
    C D ~F .G +fermata+D !legato!G 
    {cg}D {ab}C {f2fe}G
    "Cm7"C G "Dmaj"D A D
    {cg}"Cm7"+fermata+~=D    
    ]]
    songs = abclua.parse_all_abc(decorations)
    abclua.make_midi(songs[1], 'out/decorations.mid')    
    print(abclua.token_stream_to_abc(songs[1].token_stream))
end


function test_overlay()
    -- Test voice overlay with &
    overlay = [[
    X:1    
    K:G
    ceg & C3 | dfa & D3 | C3 & E3 & G/ G/ G/  G/G/G/ |
    ]]
    songs = abclua.parse_all_abc(overlay)
    abclua.make_midi(songs[1], 'out/overlay.mid')    
    print(abclua.token_stream_to_abc(songs[1].token_stream))
end

function test_include()
    -- test file inclusion
    includes = [[
    %%abc-include tests/notarealfile.abc
    X:4    
    K:G
    %%abc-include tests/setkey.abc
    CDEFGab z2
    %%abc-include tests/tune.abc
    [I:abc-include tests/tune.abc]
    %%abc-include tests/recursive.abc
    ]]
    songs = abclua.parse_all_abc(includes)
    abclua.make_midi(songs[1], 'out/includes.mid')    
    print(abclua.token_stream_to_abc(songs[1].token_stream))
end

    
function test_skye()
    -- test a simple tune

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

-- test_include()
--test_overlay()
test_macros()
-- test_directives()
-- test_clefs()
-- test_decorations()
-- test_inline()
-- test_keys()
-- test_trimming()
-- test_grace_notes()
-- test_chord_names()
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

