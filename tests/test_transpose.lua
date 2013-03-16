require "abclua"

function print_transposed_scales(scale)
    print(emit_abc(scale))
    for i=1,12 do
        diatonic_transpose(scale,1)    
        --table_print(scale[2])
        print(emit_abc(scale))
    end
    
    for i=1,12 do
        diatonic_transpose(scale,-1)            
        print(emit_abc(scale))
    end
    print()
end


function test_transposed_scales(scale_str, test)
    -- test repeated upward/downward transposition
    scale = abclua.parse_abc_fragment(scale_str)
    local start = emit_abc(scale)
    for i=1,12 do
        diatonic_transpose(scale,1)            
    end
    
    for i=1,12 do
        diatonic_transpose(scale,-1)                    
    end
    
    assert(emit_abc(scale)==start,test)
    print(test.." repeated transpose passed OK")
end

test_transposed_scales('[K:C]CDEFGAB', 'C major')
test_transposed_scales("[K:C]C,,DEFg'a''b'''", 'C major octaves')
test_transposed_scales('[K:C#]CDEFGAB', 'C# major')
test_transposed_scales('[K:Gb]GABCDEF', 'Gb major')
test_transposed_scales('[K:C]_DDEFGA_B', 'C major accidentals')
test_transposed_scales('[K:C#]C=DEFGAB', 'C# major accidentals')


function get_pitches(tokens)
    -- get all of the pitches from compiling a token stream
    local stream = compile_tokens(tokens)
    local pitches = {}
    for i,v in ipairs(tokens) do
        if v.note and v.note.play_pitch then
            table.insert(pitches, v.note.play_pitch)
        end    
    end
    return pitches
end

function check_transpose(str, shift, result, test) 
    local fragment = parse_abc_fragment(str)    
    diatonic_transpose(fragment, shift)     
    local abc = emit_abc(fragment)        
    -- check that the ABC matches
    assert(abc==result, test)
    -- check the pitches actually match    
    print(test.." passed OK")       
end


function check_unchanged(str, test)
    -- randomly transpose a string up and down several times, restoring it
    -- to it's original state, and check that the pitches haven't been altered
    -- (tests that accidental propagation doesn't break when transposed)
    local fragment = parse_abc_fragment(str)
    local original_pitches = get_pitches(fragment)
    
    local transpose_sequence = {}
    for i=1,10 do
        table.insert(transpose_sequence, 1)-- math.random(-12,12))
    end
   print(emit_abc(fragment)) 
    -- apply the transposes forwards
    for i,v in ipairs(transpose_sequence) do        
        diatonic_transpose(fragment, v)       
        print(emit_abc(fragment))        
    end
    
    -- and then backwards     
    for i = #transpose_sequence, 1, -1 do
      local v = transpose_sequence[i]
      diatonic_transpose(fragment, -v)      
    end
               
    print(emit_abc(fragment))
    local new_pitches = get_pitches(fragment)    
    table_print(original_pitches)
    table_print(new_pitches)
    -- check the pitches actually match
    for i,v in ipairs(original_pitches) do        
        assert(original_pitches[i] == new_pitches[i])
    end
    print(test.." passed OK")       
end


check_transpose('[K:C]cde',2,'[K:D]def', 'Transpose')
check_transpose('[K:C]cde',12,"[K:C]c'd'e'", 'Octave up transpose')
check_transpose('[K:C]cde',-12,"[K:C]CDE", 'Octave down transpose')
check_transpose('[K:C]cde',1,"[K:C#]cde", 'Semitone transpose')
check_transpose('[K:C]"Cm7"cde',2,'[K:D]"Dm7"def', 'Chord transpose')
check_transpose('[K:C]"Cm7/G"cde',2,'[K:D]"Dm7/A"def', 'Inversion transpose')
check_transpose('[K:C]c{c}de',2,'[K:D]d{d}ef', 'Grace transpose')


-- check_transpose('[K:G exp ^f _d _c]abcdefg', 0, '[K:G exp ^f _d _c]abcdefg', 'Explicit scale 3')

check_unchanged('[K:C]cdefgab', 'C scale unchanged transpose')
check_unchanged('[K:G]gabcdef', 'G scale unchanged transpose')
check_unchanged('[K:C#min]abcdefgab', 'C# minor scale')
check_unchanged('[K:Gdor]abcdefgab', 'G dorian scale')
check_unchanged('[K:G]^gabcdef', 'G scale accidentals unchanged transpose')
check_unchanged('[K:G]^gabcdefgab_gab=ff_f', 'G scale multiple accidentals unchanged transpose')
check_unchanged('[K:G]^gabc|def|gab_|gab', 'G scale multiple accidentals bars unchanged transpose')
check_unchanged('[K:Gdor]ab^cd^efgab', 'G dorian scale accidentals')
check_unchanged('[K:C#min]ab^cd^efgab', 'C# minor scale accidentals')

check_unchanged('[K:G]"G"B2 B B_B=B|', 'Liberty bell extract')

check_unchanged([[X:12003
T:Liberty Bell
T:Monty Python
R:Jig
C:John Philip Sousa, 1893
O:USA
M:6/8
L:1/8
Q:1/8=200
K:G
d/c/|"G"B2 B B_B=B|g2 d d2 B|"Am"c2 c c2 d|e3 e2 c|"D"A2 A A^GA|"D7"f2 e e2 c|"G"B2 B "D7"B2 c|("G"d3"D7"d2) c|
"G"B2 B B_B=B|g2 d d2 B|"A"^c2 a a2 a|"A7"a3 a2 g|"D"f2 a a^ga|"A7"e2 a a^ga|"D7"d2 ^c d2 c|d3 d2:|
|:c|"G"B_B=B "D7"e2 d|"G"B3 G3|"C"E3 "D7"A3|"G"G3 G2 G|"D7"ABd f2 e|"G"d3 g3|"D"f3 "A7"e3|"D7"d3 d2 d|
"C"e2 e e_e=e|"B7"f3 f3|"Em"g2 g aga|"B"b3 b2 b|"C"a2 g e2 c|"G"B3 G3|"D7"A3 F3|G3 G2:|
K:C
G|:"C"E3 F3|^F3 G3|e2 e e2 _e|e3 e2 G|E3 F3|^F3 G3|"G"f2 f f2 e|f3 f2 e|"G"d3 "Gdim"^c3|"G"d2 G ^F2 G|
"C"e3 "Cdim"_e3|"C"e2 G ^F2 G|1"G"B3 d3|"D7"c2 d A2 c|"G"B2 c A2 B|"G7"G2 A F2 G:|2 "F"A3 f3|"C"e2 c "G"d2 B|"C"c6|c6|
]], 'Liberty bell')

-- check_unchanged('[K:G exp ^f]abcdefgababcdef', 'Explicit scale')
-- check_unchanged('[K:G exp ^f _d _c]abcdefg', 'Explicit scale 3')
-- check_unchanged('[K:G exp _a _b ^c ^d _e _f ^g]abcdefgababcdef', 'Explicit scale 2')
-- check_unchanged('[K:G exp ^a _d]ab^cdc|efc|ga_b|abc_cde|fag|g_a^g=g|', 'Explicit scale accidentals')


print("Transpose passed OK")