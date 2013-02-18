require "abclua"
-- index a set of ABC tunes

function read_songbook(fname, tunes)
    -- parse the tune
    local songs = parse_abc_file(fname)
    local meta
    
    -- read in the metadata
    for i,song in ipairs(songs) do 
        meta = song.header_metadata 
        if meta and meta.ref then
            meta.file_index = i
            meta.file = fname
            table.insert(tunes, meta)
        end
    end
end

local field_order = {'title', 'composer', 'key', 'meter', 'tempo', 'rhythm', 'area', 'book',  'discography', 
'file', 'group', 'history', 'notes ', 'origin', 'remark ', 'source ', 'transcriber ', 'ref'}

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
            if type(meta[v])=='string' then fields = {meta[v]} else fields=meta[v] end
            
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


tunes = {}
read_songbook('tests/p_hardy.abc', tunes)
table.sort(tunes, function(a,b) return (a.title[1] or a.file)<(b.title[1] or b.file) end)
for i,v in ipairs(tunes) do
    print(get_field_text(v))
end