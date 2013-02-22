require "abclua"


scale = abclua.parse_abc_fragment([[[K:C]CDEFGab]])
abclua.diatonic_transpose(scale,-13)    
print(emit_abc(scale))
print()
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

print_transposed_scales(abclua.parse_abc_fragment([[[K:C]CDEFGab]]))
print_transposed_scales(abclua.parse_abc_fragment([[[K:G]CDE=FGab]]))
print_transposed_scales(abclua.parse_abc_fragment([[[K:C]^C^D^E^F^G^a^b]]))
print_transposed_scales(abclua.parse_abc_fragment([[[K:C]_C_D_E_F_G_a_b]]))
print_transposed_scales(abclua.parse_abc_fragment([[[K:C#]_C_D_E_F_G_a_b]]))
print_transposed_scales(abclua.parse_abc_fragment([[[K:C]{d}C{e}D{f}E{g}F{a}G{b}a{c'}b]]))
print_transposed_scales(abclua.parse_abc_fragment([[[K:C]"Cmaj"D"C#7"E"Dmin/G"]]))
