require "abclua"

-- Takes an ABC file "xyz.abc", and should reproduce an equivalent ABC file as "xyz_reproduced.abc"

function reproduce_abc(fname)
   local songs = abclua.parse_abc_file(fname)
   local outname = fname:gsub('.abc', '_reproduced.abc')   
   local out = io.open(outname, 'w')
   for i,v in ipairs(songs) do
        out:write(abclua.token_stream_to_abc(v.token_stream))
        out:write('\n\n')
    end
    out:close()
end

reproduce_abc(arg[1])