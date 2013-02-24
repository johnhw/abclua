------------------------------------------------------
-- Makes a single songbook from a directory of tunes. Tunes
-- are sorted in alphabetic order of title. Duplicate reference numbers are fixed
------------------------------------------------------
require "abclua"
require "lfs"

function dirtree(dir)
   -- Code by David Kastrup
  assert(dir and dir ~= "", "directory parameter is missing or empty")
  if string.sub(dir, -1) == "/" then
    dir=string.sub(dir, 1, -2)
  end

  local function yieldtree(dir)
    for entry in lfs.dir(dir) do
      if entry ~= "." and entry ~= ".." then
        entry=dir.."/"..entry
	local attr=lfs.attributes(entry)
	coroutine.yield(entry,attr)
	if attr.mode == "directory" then
	  yieldtree(entry)
	end
      end
    end
  end
  return coroutine.wrap(function() yieldtree(dir) end)
end


function combine_abc(dir, fname)
    local songs = {}
    local refs = {}
    local ref
    -- read all of the abc files
    for fname, attr in dirtree(dir) do
        -- find all ABC files            
        if attr.mode=='file' and string.sub(fname,-4)=='.abc' then
            -- don't crash on bad abc files
            local success, all_songs = pcall(parse_abc_file,fname)  
            for i,song in ipairs(all_songs) do 
                -- insert valid songs
                if success and song and song.metadata and song.metadata.title then
                    table.insert(songs, song)
                   
                    ref = tonumber(song.metadata.ref) or 1
                    -- generate new random reference number if this one is already used
                    if refs[ref] then
                        while refs[ref] do ref = ref+math.random(0,5000) end
                    end
                    -- remember we've used this reference number; can't be reused
                    refs[ref] = ref
                end
            end
        end    
    end
    
    -- alphabetical sort 
    table.sort(songs, function(a,b) return (a.metadata.title[1])<(b.metadata.title[1]) end)
    local out = io.open(fname, 'w')
    assert(out, "Could not open output file "..fname)
    out:write(abc_from_songs(songs, 'combine_abc.lua'))
    out:close()
end

if #arg~=2 then
    print("Usage: combine_abc.lua <directory> <file.abc>")
else
    combine_abc(arg[1], arg[2])
end
