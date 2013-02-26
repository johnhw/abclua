require "abclua"


-- scale = abclua.parse_abc_fragment([[[K:C]CDEFGab]])
-- abclua.diatonic_transpose(scale,-13)    
-- print(emit_abc(scale))
-- print()

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

-- print_transposed_scales(abclua.parse_abc_fragment([[[K:C]CDEFGab]]))
-- print_transposed_scales(abclua.parse_abc_fragment([[[K:G]CDE=FGab]]))
-- print_transposed_scales(abclua.parse_abc_fragment([[[K:C]^C^D^E^F^G^a^b]]))
-- print_transposed_scales(abclua.parse_abc_fragment([[[K:C]_C_D_E_F_G_a_b]]))
-- print_transposed_scales(abclua.parse_abc_fragment([[[K:C#]_C_D_E_F_G_a_b]]))
-- print_transposed_scales(abclua.parse_abc_fragment([[[K:C]{d}C{e}D{f}E{g}F{a}G{b}a{c'}b]]))
-- print_transposed_scales(abclua.parse_abc_fragment([[[K:C]"Cmaj"D"C#7"E"Dmin/G"]]))


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
    print(emit_abc(scale))
    assert(emit_abc(scale)==start,test)
    print(test.." repeated transpose passed OK")
end

test_transposed_scales('[K:C]CDEFGAB', 'C major')
test_transposed_scales("[K:C]C,,DEFg'a''b'''", 'C major octaves')
test_transposed_scales('[K:C#]CDEFGAB', 'C# major')
test_transposed_scales('[K:Gb]GABCDEF', 'Gb major')
test_transposed_scales('[K:C]_DDEFGA_B', 'C major accidentals')
test_transposed_scales('[K:C#]C=DEFGAB', 'C# major accidentals')


function check_transpose(str, shift, result, test) 
    local fragment = parse_abc_fragment(str)
    diatonic_transpose(fragment, shift) 
    local abc = emit_abc(fragment)    
    assert(abc==result, test)
    print(test.." passed OK")
end

check_transpose('[K:C]cde',2,'[K:D]def', 'Transpose')
check_transpose('[K:C]cde',12,"[K:C]c'd'e'", 'Octave up transpose')
check_transpose('[K:C]cde',-12,"[K:C]CDE", 'Octave down transpose')
check_transpose('[K:C]cde',1,"[K:C#]cde", 'Semitone transpose')
check_transpose('[K:C]"Cm7"cde',2,'[K:D]"Dm7"def', 'Chord transpose')
check_transpose('[K:C]"Cm7/G"cde',2,'[K:D]"Dm7/A"def', 'Inversion transpose')
check_transpose('[K:C]c{c}de',2,'[K:D]d{d}ef', 'Grace transpose')

print("Transpose passed OK")