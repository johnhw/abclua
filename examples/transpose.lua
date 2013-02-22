---------------------------------------------
-- Transpose an ABC file, and write the 
-- transposed file to stdout 
--------------------------------------------

-- Usage: transpose.lua <file.abc> <semitones|key>
-- where semitones is an integer, and key is e.g. C#
-- 

require "abclua"

function get_relative_transpose(song, key)
    -- find the difference (in semitones) between the
    -- first key of the song, and the given key (as a string)
    local transpose
    local note_number = get_note_number(key)
    if not note_number then
        print("Error: bad key "..key)
        return nil
    end
    
    
    local first_key
    -- find the first key
    for i,v in ipairs(song.token_stream) do
        if v.token=='key' then
            first_key = get_note_number(v.key.root)
            break
        end
    end
    if not first_key then
        print("Error: ABC file does not have a key")
        return nil
    end 
    
    
    transpose = note_number - first_key
    -- make minimum shift (never by more than a fifth)
    if transpose>7 then tranpose = (transpose-12) end
    if transpose<-7 then tranpose = (transpose+12) end
    return transpose
end


function transpose_song(song, semitones_key)
    -- transpose a single song
    -- if semitones_key is an integer, transpose by that many semitones;
    -- otherwise, find first key, get the difference, and transpose 
    
    local transpose
    transpose = tonumber(semitones_key)
    
    -- convert to semitones if a string
    if not transpose then
        transpose = get_relative_transpose(song, semitones_key)        
    end
        
    -- and tranpose
    diatonic_transpose(song.token_stream, transpose)
    
    return song
end

function transpose(fname, semitones_key)
    transposed_songs = {}
    local songs = parse_abc_file(fname)    
    -- transpose each song
    for i, song in ipairs(songs) do
        table.insert(transposed_songs, transpose_song(song, semitones_key))
    end
        
    -- write back the transposed songs
    print(abc_from_songs(transposed_songs, "transpose.lua"))
end

if #arg~=2 then
    print("Usage: transpose.lua <file.abc> <semitones|key>")
    print("Example: transpose.lua skye.abc +5")
    print("Example: transpose.lua skye.abc Eb")
else
    transpose(arg[1], arg[2])
end

