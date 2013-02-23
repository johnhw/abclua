-------------------------------------------
-- Prints out an ABC tune (or set of tunes)
-- as a score, rendered poorly in ASCII
------------------------------------------

require "abclua"

local breve=[[
||O||
]]

local semi_breve = [[
O
]]

local half_note = 
[[
 |
 |
O
]]

local crotchet = 
[[
 |
 |
*
]]

local quaver = 
[[
 |\
 |
*
]]

local semi_quaver = 
[[
 ||\\
 ||
*
]]


local demi_semi_quaver = 
[[
 |||\\\
 |||
..
]]

local time_signature_key =
[[
N /
 / D

  --||
 e  ||
 d--||
 c  ||
 b--||
 a  ||
 g--||
 f  ||
 e--||


]]

local bar_line = 
[[


   
|
|
|
|
|
|
|
|
|


]]

local start_repeat = 
[[



|
|
|**
|
|
|
|**
|
|


]]


local mid_repeat = 
[[



 |
 |
*|*
 |
 |
 |
*|*
 |
 |


]]

local end_repeat = 
[[



  |
  |
**|
  |
  |
  |
**|
  |
  |


]]

local heavy_bar_line = 
[[



| |
| |
| |
| |
| |
| |
| |
| |
| |


]]

local stave = 
[[



-

-

-

-

-



]]


function render_ascii(ascii_state, x, y, sprite)
    -- render a block of ASCII at the given location, overwriting what is there
    -- chop off leading and trailing newlines
    -- sprite = string.sub(sprite, 1, -1)
    local x_origin = x
    local key
    local w, h = 0,0
    for v in sprite:gmatch('.') do
        -- shift down one line
        key = x..'+'..y
           
        if v=='\n' then
            ascii_state[key] = {x=x, y=y, c=' '} -- blanks to make sure we print all whitespace
            x = x_origin
            y = y + 1
            h = h + 1
        
        else
            -- just move along
            ascii_state[key] = {x=x, y=y, c=v}
            x=x+1
            if x-x_origin>w then w=x-x_origin end
        end
    end    
    
    -- return dimensions of this sprite
   return w,h
end

function print_ascii(ascii_state)
    cells = {}
    for i,v in pairs(ascii_state) do
        table.insert(cells, v)
    end
    
    -- put into scanline order
    table.sort(cells, function(a,b) return a.y<b.y or (a.y==b.y and a.x<b.x) end) 
    
    local x,y = 0,0
    for i,v in ipairs(cells) do
       -- move to current draw point
       while y<v.y do io.write("\n"); y=y+1; x=0; end
       while x<v.x do io.write(" "); x=x+1; end
       -- draw cell
       io.write(v.c)
       x = x + 1
    end
end


function fill_time_key(key, meter)
    -- fill out the fields in the key/time marker
    local tskey = time_signature_key
    
    mapping = create_key_structure(key)
    for i,v in pairs(mapping) do
        if v==0 then tskey=string.gsub(tskey,i,' ') end
        if v==1 then tskey=string.gsub(tskey,i,'^') end
        if v==-1 then tskey=string.gsub(tskey,i,'_') end
    end
    
    tskey=string.gsub(tskey,'N', meter.num)
    tskey=string.gsub(tskey,'D', meter.den)
    return tskey
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
            meta.tokens = song.token_stream
            table.insert(tunes, meta)
        end
    end
end


function sort_index(index)
    -- order the index by title and then by file
    table.sort(index, function(a,b) return (a.title[1] or a.file)<(b.title[1] or b.file) end)
end

local note_locations = {c=4, b=5, a=6, g=7, f=8, e=9, d=10}

local max_line_width = 70
local stave_spacing = 14


function render_stream(ascii_state, stream, meter, x, y)
    -- render a bar, starting at x,y;
    -- return the stream index to continue from
    -- and the new x, y position
    local subdivisions = 24--math.floor((meter.num / (meter.den/4)) * 8)
    local note_position 
    local t
    local last_broken = 0
    local last_tied 
    local x_origin = x
    x = x + 1
    for i,v in ipairs(stream) do
        if v.token=='note' then
            if not v.note.pitch then
                note_position = 4
            else
                note_position = note_locations[v.note.pitch.note] - v.note.pitch.octave * 8
            end
           
            local dur = (v.note.duration.num/v.note.duration.den)            
            local len = math.floor((v.note.duration.num/v.note.duration.den)*subdivisions/4)
            local note_form
            local dot = false
            
            -- score lines
            for i=x,x+len do
                render_ascii(ascii_state,  i, y, stave)
            end
            
            if last_broken then
               if last_broken==1 then dur = dur * 0.5 end
                if last_broken==-1 then dur = dur * 1.5 end
            end
            
            -- broken rhythms
            if v.note.duration.broken then
                last_broken = v.note.duration.broken
                if last_broken==1 then dur = dur * 1.5 end
                if last_broken==-1 then dur = dur * 0.5 end
            else
                last_broken = 0
            end
            
            -- calculate note form
            
            if dur==0.25 then note_form = semi_quaver end
            if dur==0.625 then note_form = semi_quaver; dot=true end           
            if dur==0.5 then note_form = quaver end
            if dur==0.75 then note_form = quaver; dot=true end
            if dur==1 then note_form = crotchet end
            if dur==1.5 then note_form = crotchet; dot=true; end
            if dur==2 then note_form = half_note end
            if dur==3 then note_form = half_note; dot = true end
            if dur==4 then note_form = semi_breve end
            if dur==6 then note_form = semi_breve; dot = true end
            if dur==8 then note_form = breve end
            if dur==12 then note_form = breve; dot=true end
            
            if v.note.rest then
                note_form = '}'
            end
            local note_x, note_y = x+len/2, y+note_position
            w,h = render_ascii(ascii_state,  note_x, note_y, note_form)
            
           -- guide lines for notes above/below stave
            if note_position<0 and note_position%2==1 then
                 render_ascii(ascii_state,  note_x-1, note_y+h-1, '-')
                 render_ascii(ascii_state,  note_x+1, note_y+h-1, '-')

            end
         
            -- dotted notes
            if dot then
                render_ascii(ascii_state,  note_x+2, note_y+h-2, '.')
            end
            
            -- deal with ties
             if last_tied then
                render_ascii(ascii_state, last_tied[1], last_tied[2], string.rep('=', 2+note_x-last_tied[1]))
            end
                
            if v.note.tie then
                 last_tied = {note_x+1, note_y-2}
            else
                last_tied = nil
            end
            
            x = x + len
        end
        -- stop if we get a bar
        if v.token=='bar' then
            
            -- break on bars if possible
            local bar_sprite
            local sprites = {start_repeat=start_repeat, plain=bar_line, double=heavy_bar_line, thickthin=heavy_bar_line, thinthick=heavy_bar_line, end_repeat=end_repeat, mid_repeat=mid_repeat}
            bar_sprite = sprites[v.bar.type]
            
            local w, h = render_ascii(ascii_state, x, y, bar_sprite)
            x = x + w
            if v.bar.variant_range then
                render_ascii(ascii_state, x-2, y+1, '['..v.bar.variant_range[1])
            end
             if x>max_line_width then
                x = x_origin
                y = y + stave_spacing
            end      
           
        end
    end
end

function ascii_score(fname)
    -- Index fname and write the index to stdout
    tunes = {}
    index_songbook(fname, tunes)
    sort_index(tunes)
    for i,v in ipairs(tunes) do
         ascii_state = {}
   
        local key, meter
        for j,n in ipairs(v.tokens) do
            if n.token=='key' then key=n.key end
            if n.token=='meter' then meter=n.meter end
        end
        
        -- title
        local title = v.title[1]
        local centre = (max_line_width-string.len(title))/2
        render_ascii(ascii_state, centre, 2, title)
        if v.title[2] then
            render_ascii(ascii_state, centre, 3, '('..v.title[2]..')') 
        end
        -- tempo
        if v.tempo then
            render_ascii(ascii_state, max_line_width, 3, v.tempo)
        end
        
        local x,y = 1, 4
         
        -- key and time signature
        bar_header = fill_time_key(key, meter)
        x,y = render_ascii(ascii_state, x,y,bar_header)
        
        -- the notes
        render_stream(ascii_state, v.tokens, meter, x, 4)
        
        print_ascii(ascii_state)
        io.write("\n")
    end
end


if #arg~=1 then
    print "Usage: ascii_score <file.abc>"
else
   ascii_score(arg[1])
end


-- TODO: simplify