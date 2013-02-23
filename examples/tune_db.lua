--------------------------------------------------------
-- Tool for storing/accessing a database of ABC tunes --
-- Write/reads tunes using an SQLLite database 
--------------------------------------------------------
-- Requires lsqlite3

require "lsqlite3"
require "abclua"
require "lfs"

local field_order = {'title', 'abc', 'file', 'file_index', 'composer', 'key', 'meter', 'tempo', 'rhythm', 'area', 'book',  'discography', 
 'group', 'history', 'notes', 'origin', 'remark', 'source', 'transcriber', 'ref'}

local tune_db


function title(str)
    -- make a string start with a captial
    return string.upper(string.sub(str, 1,1)) .. string.sub(str,2)
end

function comma_joined(elts, quote)
    -- return elts joined with commas, optionally with each element surrounded by quote
    -- e.g. comma_joined({'a','b'}, '*') returns '*a*, *b*'
    quote = quote or ''
    out = {}
    for i,v in ipairs(elts) do if i==1 then table.insert(out, quote..v..quote) else table.insert(out, ', '..quote..v..quote) end end
   return table.concat(out)
end

function escape_quotes(str)
    --escape quotes to go into database
    return tostring(str):gsub("'", "''")
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
            meta.abc = emit_abc(song.token_stream)
            meta.file = fname
            table.insert(tunes, meta)
        end
    end
end


function sort_index(index)
    -- order the index by title and then by file
    table.sort(index, function(a,b) return (a.title[1] or a.file)<(b.title[1] or b.file) end)
end


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

function get_tunes(dir)
    -- return a table of all the tunes in the given file or directory
    local tunes = {}
    local files = {}
    local attr=lfs.attributes(dir)
    -- decide whether this a file or a directory
    if attr.mode=='file' then
        files = {dir}
    else
        for fname, attr in dirtree(dir) do
            -- find all ABC files        
            if attr.mode=='file' and string.sub(fname,-4)=='.abc' then 
                table.insert(files, fname)
            end
        end
    end
    
    for i,v in ipairs(files) do
        print("Indexing: "..v)
        index_songbook(v, tunes)
    end
    sort_index(tunes)    
    return tunes
end


function insert_alternate_titles(tune_db, ref, titles)
    -- store all titles for this song (a song can have several titles)
    local query 
    table_print(titles)
    for i,v in ipairs(titles) do
        query = string.format("INSERT INTO titles (%s, %s) VALUES('%s', '%s');", 'ref', 'alt_title', ref, escape_quotes(v))
          tune_db:exec(query)
    end
    
end


function insert_db_row(tune_db, meta) 
    -- Insert a new row into the database representing a tune
    local out = {}
    local fields
    local columns = {}
    local data = {}
  
    for i,v in pairs(meta) do
        if i=='title' then insert_alternate_titles(tune_db, meta.ref[1], v) end
        if type(v)=='table' then v = v[1] end
      
        if i=='group' then i='abc_group' end
        table.insert(columns, i)
        table.insert(data, tostring(escape_quotes(v)))
        
        -- if we get a tempo field, work out the the real
        -- speed of this song as well.
        if i=='tempo' then 
            local tokens = parse_abc_fragment('Q:'..v)
            local real_tempo = get_bpm_from_tempo(tokens[1].tempo)
            table.insert(columns, 'real_tempo')
            table.insert(data, real_tempo)
        end
    end
        

   table.insert(out, 'INSERT INTO abctunes (')
   table.insert(out, comma_joined(columns))
   table.insert(out, ') VALUES (')
   table.insert(out, comma_joined(data, "'"))
   table.insert(out, ');')
   tune_db:exec(table.concat(out))
  end


function tune_db_add(dir)

    local tunes = get_tunes(dir)
    recreate_db()
    
    tune_db:exec('BEGIN TRANSACTION;')
    for i,v in ipairs(tunes) do
        insert_db_row(tune_db, v)
    end
    tune_db:exec('COMMIT TRANSACTION;')  

end


function pad(str, len, padding)
    -- pad a string to be len characters, using the given
    -- padding character, or space if not specified
    local pad = len-string.len(str)
    if pad<=0 then return str end
    return str..string.rep(padding or ' ', pad)
end

function tune_db_list()
    -- list all entries in the database
    for row in tune_db:rows('SELECT ref,alt_title FROM titles;') do
       print(string.format("%s %s", pad(row[1],7), row[2]))
   end
end

function tune_db_show(ref)
    -- show a given entry, indexed by reference number
 local query = string.format("SELECT abc FROM abctunes WHERE ref='%s';", ref)
 for row in tune_db:rows(query) do
       print(row[1])
  end
end

function tune_db_search(text)
    -- search for the given text, and find matching titles
 local query = string.format("SELECT ref, alt_title FROM titles WHERE alt_title LIKE'%%%s%%';",text)
 for row in tune_db:rows(query) do
       print(pad(row[1],7).." "..row[2])
  end
end

function tune_db_remove(ref)
    -- remove a row (indexed by ref) from the tunes
     local query = string.format("DELETE FROM abctunes WHERE ref='%s';", ref)
     local result = tune_db:exec(query)
     local query = string.format("DELETE FROM titles WHERE ref='%s';", ref)
     local result = tune_db:exec(query)
    
     if result==0 then
        print("Could not remove " .. ref..".")
     else
        print("Removed "..ref..".")
     end
end

function recreate_db()
    -- Make sure the tables exist, recreating them if necessary
    tune_db:exec([[CREATE TABLE IF NOT EXISTS abctunes (title,
    file, abc, file_index, composer, key, meter, real_tempo, tempo, rhythm, area, book, discography, abc_group, history, notes, origin, remark, 
    source, transcriber, ref UNIQUE PRIMARY KEY);]])

    tune_db:exec([[CREATE TABLE IF NOT EXISTS titles (ref, alt_title);]])
end

function open_db()
    -- open the database
 tune_db = sqlite3.open('tunes.sqlite')
end

function close_db()
    -- close and sync the database
 tune_db:close()
end
   
function tune_db_clear()
    -- clear the database
    tune_db:exec('DROP TABLE abctunes;')
    tune_db:exec('DROP TABLE titles;')
    recreate_db()
    print("Database cleared.")
end

function print_usage()
    print "Usage: tune_db <action> [object]"
    print ""
    print "Action can be: "
    print "     list                    Lists the tunes in the database"
    print "     add     <file|dir>      Adds a tune or directory of tunes"
    print "     show    <ref>           Show a tune with given reference number"
    print "     remove  <ref>           Remove a tune with the given reference number"
    print "     search  <text>          Search for a tune matching the title"  
    print "     clear                   Clear the database"    
end



if #arg<1 then
    print_usage()
else
    local action, argument = arg[1], arg[2]
    
    open_db()
    -- determine what to do:
    if action=='add' then
        tune_db_add(argument)
    elseif action=='list' then
        tune_db_list()
    elseif action=='remove' then
        tune_db_remove(argument)
    elseif action=='clear' then 
        tune_db_clear()
    elseif action=='search' then
        tune_db_search(argument)
    elseif action=='show' then
        tune_db_show(argument)
    elseif action=='search' then
        tune_db_search(argument)
        
    else
        print_usage() -- not a recognised command
    end
    close_db()
end


