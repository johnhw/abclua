------------------------------------------------------
-- Separates a songbook into a set of individual tunes
------------------------------------------------------
require "abclua"

function separate_abc(fname)
    local f = io.open(fname, 'r')
    assert(f, "Could not open file "..fname)
    local contents = f:read('*a')
 
    -- iterate through songs
    for v in parse_abc_song_iterator(contents) do
        if v.metadata.title then
            title = v.metadata.title[1] 
            title = title:gsub('%p', '-')
            title = title:gsub(' ', '_')
            title = title:gsub('/', '-')
            title = title:gsub('\\\\', '-')
            title = title:gsub('~', '-')
            title = title:gsub('@', '-')
            title = title:gsub('"', '-')
            title = title:gsub("'", '')
            title = title:gsub('\\-\\_', '_')
            title = title:gsub('\\_\\-', '_')
            
            -- local out = io.open(title..'.abc', 'w')
            -- out:write(abc_from_songs({v}))
            -- out:close()
        end
    end
end

if #arg~=1 then
    print("Usage: separate_abc.lua <file.abc>")
else
    separate_abc(arg[1])
end
