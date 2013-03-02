require "abclua"
-------------------------------------------
-- Index a set of ABC tunes --
-- produces a sortable searchable index --
------------------------------------------

-- Takes a directory as a command line parameter, and writes out 
-- an HTML representation of all the tunes in that directory tree to "index.html". 
-- Uses list.js (http://listjs.com) to provide Javascript search and sort functions

-- This example needs the LuaFileSystem module http://keplerproject.github.com/luafilesystem/

function index_songbook(fname, tunes)
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

local field_order = {'title', 'file', 'composer', 'key', 'meter', 'tempo', 'rhythm', 'area', 'book',  'discography', 
 'group', 'history', 'notes', 'origin', 'remark', 'source', 'transcriber', 'ref'}

function title(str)
    -- make a string start with a captial
    return string.upper(string.sub(str, 1,1)) .. string.sub(str,2)
end


function dirtree(dir)
   -- Code by David Kastrup
  require "lfs" -- need lfs to iterate through directories
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


function sort_index(index)
    -- order the index by title and then by file
    table.sort(index, function(a,b) return (a.title[1] or a.file)<(b.title[1] or b.file) end)
end


function get_html(meta) 
    -- return an HTML representation of a tune
    local out = {}
    local fields
    
    table.insert(out, '<li class="bullet">')
    for i,v in ipairs(field_order) do
        if meta[v] then 
            -- make into a table if just a plain string
            if type(meta[v])=='string' then fields = {meta[v]} else fields=meta[v] end
            if v=='file' then
                local fname = fields[1]
                fname = fname:gsub('\\', '/')                
                fields = {string.format('<a href="%s">%s</a>', fname,'Download')}
            end
            -- print out each field (might be e.g. multiple titles for one song)
            for j,n in ipairs(fields) do              
                if v~='ref' then
                    if v~='title' and v~='file' then
                        table.insert(out, string.format('<span class="field">%s</span><span class="%s">%s</span><br>\n', title(v), v, n))
                    else             
                        -- make secondary titles a different class
                        if v=='title' and j~=1 then
                            table.insert(out, string.format('<span class="alt-title">%s</span>\n',  n))
                        else
                            
                            table.insert(out, string.format('<span class="%s">%s</span>\n', v, n))
                            if v=='file' then table.insert(out, "<br>") end
                        end
                    end
                end
            end
        end
    end
    table.insert(out, '</li>')
    table.insert(out, '\n')
    return table.concat(out)
end

function add_script(html)   
    -- add the javascript to index the table fields
    table.insert(html, '</ul>\n')
    table.insert(html, [[<script type="text/javascript">    
    var options = { valueNames: [ ]])
    for i,v in ipairs(field_order) do
        table.insert(html, "'"..v.."'"..",")
    end    
    table.insert(html, ']};\n')
    table.insert(html, "var tune_list = new List('tune-list', options);\n")
    table.insert(html, '</script>\n')   
end

function make_html_index(dir)
    -- need lfs to iterate through directories
    local tunes = {}
    local html = {}
    
    table.insert(html, [[
    <!DOCTYPE html>
    <html> 
    <head>
    <meta charset='utf-8'>
    <script src="list.js/list.js" type="text/javascript"></script>
    <link rel="stylesheet" type="text/css" href="examples/abc_index.css">
    <title> ABC Tune index </title>
    </head>
    <body>
    ]])
    table.insert(html, '<div id="tune-list">\n')
    -- add sort buttons
    for i,v in ipairs(field_order) do    
        table.insert(html, string.format('<span class="sort" data-sort="%s">%s</span>', v, title(v)))
    end
    -- add search bar
    table.insert(html, '<br><span id="search_label">Search</span><input class="search" />\n<br>')
    
    -- add the tune table
    
    table.insert(html, '<ul class="list">\n')
    
    -- index the files
    for fname, attr in dirtree(dir) do
        -- find all ABC files        
        if attr.mode=='file' and string.sub(fname,-4)=='.abc' then  
            print("Indexing: "..fname)
            index_songbook(fname, tunes)
        end
    end
    sort_index(tunes)    
    
    for i,v in ipairs(tunes) do
        table.insert(html, get_html(v))
    end
    
    add_script(html)    
    print("Done!")
    table.insert(html, '</div></body></html>\n')
    return table.concat(html)
end

-- entry point
if #arg~=1 then
    print("Usage: html_index <dirname>")
else
    local html = make_html_index(arg[1])
    local f = io.open('index.html', 'w')
    f:write(html)
    f:close()
end