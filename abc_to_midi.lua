require "midi/generate_midi"

if #arg~=1 then
    print("Usage: abc_to_midi <file.abc>")
else
    local fname = arg[1]
    local midi_fname =arg[1]:gsub('.abc$', '.mid')
    print("Converting "..fname.." to "..midi_fname)
    convert_file(fname, midi_fname)
    print("Success!")
end
