------------------------------------------------------
-- Separates a songbook into a set of individual tunes
------------------------------------------------------
require "abclua"

function separate_abc(fname)
    local songs = parse_abc_file(fname)    
    for i,v in ipairs(songs) do
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
            title = title:gsub('-_', '_')
            title = title:gsub('_-', '_')
            
            local out = io.open(title..'.abc', 'w')
            out:write(abc_from_songs({v}))
            out:close()
        end
    end
end

if #arg~=1 then
    print("Usage: separate_abc.lua <file.abc>")
else
    separate_abc(arg[1])
end
