-------------------------------------------
-- Prints out an ABC tune (or set of tunes)
-- as a score, rendered poorly in ASCII
------------------------------------------

require "abclua"



local rest_breve=[[


[]
]]

local rest_semi_breve = [[


=
]]

local rest_half_note = 
[[


~ 
]]

local rest_crotchet = 
[[


}
]]

local rest_quaver = 
[[


¬
]]

local rest_semi_quaver = 
[[

 ¬
 ¬
]]


local rest_demi_semi_quaver = 
[[
 ¬
 ¬
 ¬
]]


-- heads must be on the base
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

   ---||
  e   ||
  d---||
  c   ||
  b---||
  a   ||
  g---||
  f   ||
  e---||


]]

local bar_line = 
[[


   
|--
|
|--
|
|--
|
|--
|
|--


]]

local start_repeat = 
[[



|
|
|@ 
|
|
|
|@ 
|
|


]]


local mid_repeat = 
[[



 |
 |
@|@
 |
 |
 |
@|@
 |
 |


]]

local end_repeat = 
[[



  |
  |
 @|
  |
  |
  |
 @|
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
    -- print an ASCII state object to stdout
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
local stave_spacing = 20


function render_stream(ascii_state, stream, meter, x, y)
    -- render a stream of notes/bars, starting at x,y;
    local subdivisions = math.floor((meter.num / (meter.den/4)) * 12)
    local note_position 
    local t
    local last_broken = 0
    local last_tied 
    local x_origin = x
    x = x + 1
    for i,v in ipairs(stream) do
        
        if v.token=='note' then
            if not v.note.pitch then
                note_position = 4 -- rests are centered
            else
                 -- find vertical position of note
                note_position = note_locations[v.note.pitch.note] - v.note.pitch.octave * 8
            end
           
            local dur = v.note.play_bars * 4 
            
            -- compute visual length of the note
            local len = math.floor(dur*subdivisions/4)
            local note_form
            local dot = false
            
            -- score lines
            for i=x,x+len do
                render_ascii(ascii_state,  i, y, stave)
            end
                       
            -- work out triplets
            local frac = 128/(dur-math.floor(dur))
            
            local triplet
            local triplets = {3,5,7,9} -- possible triplet values
            for j,n in ipairs(triplets) do
                if frac%n==0 then -- if divides evenly, this is a triplet
                    triplet = ''..n
                end
                
            end
            
            -- calculate note form
            
            if (dur*8)%3==0 then dot=true end
            
            if dur>=0.125 then note_form = demi_semi_quaver end            
            if dur>=0.25 then note_form = semi_quaver end
            if dur>=0.5 then note_form = quaver end
            if dur>=1 then note_form = crotchet end
            if dur>=2 then note_form = half_note end
            if dur>=4 then note_form = semi_breve end
            if dur>=8 then note_form = breve end
            
            -- draw rests
            if v.note.rest then
                if dur>=0.125 then note_form = rest_demi_semi_quaver end            
                if dur>=0.25 then note_form = rest_semi_quaver end
                if dur>=0.5 then note_form = rest_quaver end
                if dur>=1 then note_form = rest_crotchet end
                if dur>=2 then note_form = rest_half_note end
                if dur>=4 then note_form = rest_semi_breve end
                if dur>=8 then note_form = rest_breve end
            end
            
            local note_x, note_y = math.floor(x+len/2)-3, y+note_position
            
            
            -- flip notes below middle of stave
            if note_position>6 then
                note_form = string.reverse(note_form)
                note_y = note_y + 1            
            end
            
           -- guide lines for notes above/below stave
            
            for i=9,note_position,2 do
                  render_ascii(ascii_state,  note_x, y+i, '-')    
            end
            
            for i=1,note_position,-2 do
                  render_ascii(ascii_state,  note_x, y+i, '-')    
            end
            
            w,h = render_ascii(ascii_state,  note_x, note_y, note_form)
            if (note_position<4 or note_position>10)and note_position%2==1 then
                 render_ascii(ascii_state,  note_x-1, note_y+2, '-')
                 render_ascii(ascii_state,  note_x+1, note_y+2, '-')
            end
         
            
            -- dotted notes
            if dot then
                render_ascii(ascii_state,  note_x+2, note_y+h-2, '.')
            end
            
            if triplet then
                render_ascii(ascii_state,  note_x+1, note_y+h-4, triplet)
            end
           
            -- accidentals
            if v.note.pitch and v.note.pitch.accidental then
                local accidental = v.note.pitch.accidental.num / v.note.pitch.accidental.den
                local accidentals = {[-1]='_', [1]='^', [0]='=', [-2]='__', [2]='^^'}
                render_ascii(ascii_state,  note_x-1, note_y+h-2, accidentals[accidental] or '=')
            end
            
            -- deal with ties
             if last_tied then
                render_ascii(ascii_state, last_tied[1], last_tied[2], string.rep('~', 2+note_x-last_tied[1]))
            end
                
            if v.note.tie then
                 last_tied = {note_x+1, note_y}
            else
                last_tied = nil
            end
       
             if v.note.chord  then
                render_ascii(ascii_state,  x, y+15, abc_chord(v.note.chord))
            end
      
            x = x + len
        end
        
          -- write chord symbols
        if v.chord  then
           render_ascii(ascii_state,  x, y+15, abc_chord(v.chord))
        end
      
        -- bar line symbols
        if v.token=='bar' then
            
            -- break on bars if possible
            local bar_sprite
            local sprites = {start_repeat=start_repeat, plain=bar_line, double=heavy_bar_line, thickthin=heavy_bar_line, thinthick=heavy_bar_line, end_repeat=end_repeat, mid_repeat=mid_repeat}
            bar_sprite = sprites[v.bar.type]
            
            local w, h = render_ascii(ascii_state, x, y, bar_sprite)
            x = x + w
            -- variant endings
            if v.bar.variant_range then
                render_ascii(ascii_state, x-2, y+1, '['..v.bar.variant_range[1])
            end
            
            -- break line if close to the end of a bar
             if x>max_line_width then
                x = x_origin
                y = y + stave_spacing
            end      
           
        end
    end
end

function render_title(ascii_state, y, main_title, sub_title)
    -- render a centered title (and optional subtitle) at the
    -- given y co-ordinate
    local centre = (max_line_width-string.len(main_title))/2
    render_ascii(ascii_state, centre, y, main_title)
    if sub_title then
        render_ascii(ascii_state, centre, y+1, '('..sub_title..')') 
    end
end

function ascii_score(fname)
    -- Index fname and write the index to stdout
    tunes = {}
    index_songbook(fname, tunes)
    sort_index(tunes)
    for i,v in ipairs(tunes) do
        ascii_state = {}
        meter = {num=4, den=4} -- default meter
        local key, meter
        -- precompile to get real durations
        precompile_token_stream(v.tokens)
        -- assumes only one meter/key in the song
        for j,n in ipairs(v.tokens) do
            if n.token=='key' then key=n.key end
            if n.token=='meter' then meter=n.meter end
        end
        
        -- title
        render_title(ascii_state, 2, v.title[1], v.title[2])
        
        -- tempo
        if v.tempo then
            render_ascii(ascii_state, max_line_width, 3, v.tempo)
        end
        
        local x,y = 1, 10
        
        -- key and time signature
        bar_header = fill_time_key(key, meter)
        x,y = render_ascii(ascii_state, x,y,bar_header)
        
        -- the notes
        render_stream(ascii_state, v.tokens, meter, x+2, 10)
        print_ascii(ascii_state)
    end
    io.write("\n")
end


if #arg~=1 then
    print "Usage: ascii_score <file.abc>"
else
   ascii_score(arg[1])
end


-- TODO: simplify