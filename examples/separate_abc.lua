------------------------------------------------------
-- Separates a songbook into a set of individual tunes
------------------------------------------------------
require "abclua"

function separate_abc(fname)
    local f = io.open(fname, 'r')
    assert(f, "Could not open file "..fname)
    local contents = f:read('*a')
 
    -- iterate through songs
    for v in songbook_block_iterator(contents) do 
        meta = scan_metadata(v)
        
        if meta.title then
            title = meta.title[1] 
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
            
            local out = io.open(title..'.abc', 'w')
            out:write(v)
            out:close()
        end
    end
end

if #arg~=1 then
    print("Usage: separate_abc.lua <file.abc>")
else
    separate_abc(arg[1])
end
