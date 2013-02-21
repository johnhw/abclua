require "midi/generate_midi"
local fname = arg[1]
local midi_fname =arg[1]:gsub('.abc$', '.mid')
print("Converting "..fname.." to "..midi_fname)
convert_file(fname, midi_fname)
print("Success!")
