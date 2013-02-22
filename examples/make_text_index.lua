------------------------------
-- Index a set of ABC tunes --
------------------------------

-- Takes an ABC file as a command line parameter, and writes out 
-- the metadata fields from the file to stdout. Multiple tunes
-- are sorted into title order.

require "abclua"

local field_order = {'title', 'file', 'file_index', 'composer', 'key', 'meter', 'tempo', 'rhythm', 'area', 'book',  'discography', 
 'group', 'history', 'notes', 'origin', 'remark', 'source', 'transcriber', 'ref'}

function title(str)
    -- make a string start with a captial
    return string.upper(string.sub(str, 1,1)) .. string.sub(str,2)
end

function get_field_text(meta) 
    -- return a text representation of a tune
    local out = {}
    local fields
    for i,v in ipairs(field_order) do
        if meta[v] then 
            -- make into a table if just a plain string
            if type(meta[v])~='table' then fields = {meta[v]} else fields=meta[v] end
            
            -- print out each field (might be e.g. multiple titles for one song)
            for j,n in ipairs(fields) do
                padding = string.rep(' ', 16-(string.len(v)+1))
                table.insert(out, title(v)..':'..padding..n..'\n')
            end
        end
    end
    table.insert(out, '\n')
    return table.concat(out)
end

function index_songbook(fname, tunes)
    -- parse the tune
    local songs = parse_abc_file(fname)
    local meta    
    -- read in the metadata
    for i,song in ipairs(songs) do 
        -- if this is a valid abc tune
        meta = song.header_metadata 
        if meta and meta.ref then
            meta.file_index = i
            meta.file = fname
            table.insert(tunes, meta)
        end
    end
end


function sort_index(index)
    -- order the index by title and then by file
    table.sort(index, function(a,b) return (a.title[1] or a.file)<(b.title[1] or b.file) end)
end


function text_index(fname)
    -- Index fname and write the index to stdout
    tunes = {}
    index_songbook(fname, tunes)
    sort_index(tunes)
    for i,v in ipairs(tunes) do
        print(get_field_text(v))
    end
end

if #arg~=1 then
    print "Usage: make_text_index <file.abc>"
else
    text_index(arg[1])
end


