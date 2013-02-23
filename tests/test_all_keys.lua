-- Test all keys

require "abclua"

scale = [[CDEFGABcdefgab]]

keys = {'X:1\nQ:1/4=100\nL:1/32\n'}

all_keys = {'none', 'Hp', 'HP', 'exp ^c', 'exp ^c _g _f', 'exp _g _a _a# _bb ^f'}
modes = {'aeolian', 'm', 'minor', 'maj', 'major', '', 'phrygian', 'lydian', 'locrian', 'mixolydian', 'dorian'}
accidentals = {'^c', '^c ^f ^g', "_f ^c _g# ^fb", "_/2f ^3/9c _/2g# ^/13fb", ""}

for i=0,11 do
    local note = printable_note_name(i)
    table.insert(all_keys, note)
    for j, n in ipairs(modes) do
        for k,a in ipairs(accidentals) do
            table.insert(all_keys, 'K:'..note..' '..n..' '..a)
        end
    end
end

for i,v in ipairs(all_keys) do
    table.insert(keys, v..'\n')
    table.insert(keys, scale.."\n")
end

songs = abclua.parse_abc_multisong(table.concat(keys))    
abclua.make_midi(songs[1], 'out/all_keys.mid')
