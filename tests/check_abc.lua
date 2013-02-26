require "abclua"

-- Takes an ABC file "xyz.abc", and check the file is reproduced correctly
-- Ignores any spaces

--
-- Note that failing this test does not indicate a parsing/emitter problem; ABC is ambiguous,
-- and ABCLua always produces canonical form files (e.g A/2 becomes A/).

function check_abc(fname)
   local file = io.open(fname)
   local contents = file:read('*a')
   -- remove comments
   contents = contents:gsub('%%[^%][^\n]*\n','')
   file:close()
   local songs = abclua.parse_abc_multisong(contents)
   local abc = abc_from_songs(songs)
   
   local nospace_songs = contents:gsub('%s', '')
   local nospace_abc = abc:gsub('%s', '')
   
   if nospace_songs~=nospace_abc then
        print("Mismatch")
        -- print("--- ORIGINAL ---")
        -- print(contents)
        -- print("\n\n")
        -- print("--- REPRODUCED ---")
        -- print(abc)
        -- print("\n\n")
        local error_location = first_difference_string(nospace_songs, nospace_abc)
        
        print(string.sub(nospace_songs,error_location-32,error_location))
        print(string.rep(' ',33)..string.sub(nospace_songs,error_location+1,error_location+32))
        print()
        print(string.sub(nospace_abc,error_location-32,error_location))
        print(string.rep(' ',33)..string.sub(nospace_abc,error_location+1,error_location+32))
        
 
    else
        print("Reproduced correctly.")
   end
end

if #arg~=1 then
    print("Usage: check_abc <file.abc>")
else
    check_abc(arg[1])
end