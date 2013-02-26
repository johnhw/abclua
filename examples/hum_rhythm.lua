--------------------------------------------------------------------
-- Print the rhythm of a song to stdout.
-- e.g. "abc | a/a d a/a/4a/4" becomes daah-daah-daah da-da-daah-da-da-tata
---------------------------------------------------------------------

require "abclua"

local names = {[8] = 'daaaa-aaaa-aaaa-aaah',
[4] = 'daaaa-aaah',
[3] = 'daaaaaa',
[2] = 'daaah',
[1.5] = 'daah',
[1] = 'dah',
[0.5] = 'da',
[2/3]= 'baah',
[1/3]= 'ba',
[0.25]= 'ta',
[1/6]= 'ra',
[0.125] = 'ki'
}


function print_rhythm(song)
    local tied = false
    local bars = 0
    local last_dash = ''
    for i,v in ipairs(song.voices['default'].stream) do
        if v.event=='note' then
            local dur = v.note.play_notes*4            
            -- if we know the name of this note...
            if names[dur] then 
                local name = names[dur]   
                -- remove consonant at start on tied notes
                if tied then name=name:gsub('[bdtk]', '') end
                tied=false
                -- use vowels as crude pitch
                if v.note.play_pitch>=72 then name=name:gsub('a', 'e') end
                if v.note.play_pitch>=68 then name=name:gsub('a', 'u') end
                if v.note.play_pitch<=54 then name=name:gsub('a', 'o') end
                if v.note.tie then tied=true end
                -- only write dashes between long notes
                if last_dash then io.write(last_dash) end
                if dur>=0.5 then
                    last_dash = '-' 
                end
                
                io.write(name)
            else
                print(dur)
            end
        end
        
        -- write bar spaces
        if v.event=='bar' then
            last_dash = ''
            -- if tied across a bar, then use a dash instead of a space
            if tied then io.write('') else io.write(' ') end
            
            -- break line after 6 bars
            bars = bars + 1
            if bars==6 then
                bars = 0
                io.write('\n')
            end
        
        end
        
    end
end

function rhythm(fname)
    local songs = parse_abc_file(fname)    
    -- transpose each song
    for i,v in ipairs(songs) do
        if v.metadata.title then
            print(v.metadata.title[1])
            print()
            print_rhythm(v)
        end
    end
end

if #arg~=1 then
    print("Usage: hum_rhythm.lua <file.abc>")
  else
    rhythm(arg[1])
end

