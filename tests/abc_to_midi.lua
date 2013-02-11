require "abclua"

-- Takes an ABC file "xyz.abc", and produces a midi file rendering the notes

function abc_to_midi(fname)
   local songs = abclua.parse_abc_file(fname)
   local outname = fname:gsub('.abc', '.mid')         
   abclua.make_midi(songs[1], outname)   
end

abc_to_midi(arg[1])