-- functions for writing out text represenatations of the song token_stream
local field_tags = {key = 'K'
,title = 'T'
,ref =  'X'
,area =  'A'
,book =  'B'
,composer =  'C'
,discography =   'D'
,extended = 'E'
,file =   'F'
,group =   'G'
,history =   'H'
,instruction =   'I'
,length =   'L'
,meter =   'M'
,macro =   'm'
,notes =   'N'
,origin =   'O'
,parts =   'P'
,tempo =   'Q'
,rhythm =   'R'
,remark =  'r'
,source =   'S'
,symbolline =   's'
,user =   'U'
,voice =   'V'
,words =  'w'
,end_words =  'W'
,transcriber =  'Z'
,continuation =  '+'
}

local default_macros =  invert_table({
      ['~'] = '!roll!',
      ['.'] = '!staccato!',
      H = '!fermata!',
      L = '!accent!',
      M = '!lowermordent!',
      O = '!coda!',
      P = '!uppermordent!',
      S = '!segno!',
      T = '!trill!',
      u = '!upbow!',
      v = '!downbow!'
    }   
)

function abc_meter(meter)
    -- return the string representation of a meter
    -- e.g. {num=3, den=4} becomes 'M:3/4'
    -- if there is an explicit emphasis then this produces
    -- a compound numerator (e.g. M:(2+3+2)/4)
    local num = ''
    
    -- free meter
    if meter.num==0 and meter.den==0 then
        return 'M:none'
    end
    
    if #meter.emphasis==1 then
        -- simple meter
        num = meter.num
    else
        -- join together complex meters from the empahsis table
        local e = 0
        num = '(' -- parenthesise complex meters
        for j,n in ipairs(meter.emphasis) do
           if j ~= 1 then -- first emphasis is always on 0; skip that
            num = num .. (n-e) .. '+'
            e = n
           end
        end
        
        -- length of last emphasis is however much to make up
        -- to the total meter length
        num = num .. (meter.num-e) .. ')'
           
    end
   
    local ret = string.format('M:%s/%s' , num, meter.den..'')
    return ret
    
end

function abc_tempo(tempo)
    -- return the string represenation of a tempo definition
    -- e.g. Q:1/4=120 or Q=1/2 1/4 1/2=80 "allegro"
    local q = ''
    
    if not tempo[1] then
        -- tempo without length indicator
        q = ''..tempo.tempo_rate
    else
    
        -- abc out the tempo units
        for i,v in ipairs(tempo) do
            q = q .. string.format('%s/%s ', v.num..'', v.den..'')
        end
        
        -- strip trailing space
        q = string.sub(q, 1, -2)
        
        -- the rate as =140
        q = q .. '=' .. tempo.tempo_rate
    end
        
    -- tempo names (e.g. "allegro")
    if tempo.name then
        q = q .. ' "' .. tempo.name .. '"'
    end
    
   return string.format('Q:%s', q)
end

function abc_key(key)
    -- return the string representation of a key 
    local clef = ''
    local acc = ''
    
    -- no key
    if key.none then
        return 'K:none' 
    end
    
    if key.pipe then
        return 'K:'..key.pipe
    end
    
    -- root and modal modifier
    local root = string.upper(string.sub(key.root,1,1)) .. string.sub(key.root,2,-1)    
    root = root:gsub('s', '#')
    
    if key.mode then     
        root = root .. key.mode
    end

    -- accidentals
    if key.accidentals then
        acc = ''
        for i,v in ipairs(key.accidentals) do
            acc = acc .. ' '.. abc_accidental(v.accidental)..v.note
        end
    end
    
    -- handle clef modifiers 
    if key.clef then
        clef = ' '
        -- alto, treble, etc. as a bare string
        if key.clef.clef then
            clef = clef .. key.clef.clef
        end
        
        -- other settings (e.g. transpose=3) are in
        -- key=value format
        for i,v in pairs(key.clef) do
            if i ~= 'clef' then
                clef = clef .. string.format(' %s=%s',i,v..'')
            end
        end
    end
    
    return string.format('K:%s%s%s', root , acc, clef )
end

function abc_part_string(part_table)
    -- return the string representation of a parts table
    local ret = ''
    for i,v in  ipairs(part_table) do
        -- simple part
        if type(v[1])=='string' then
            ret = ret .. v[1]
        end
        
        -- sub part (e.g A(BC)2A)
        if type(v[1])=='table' then
            ret = ret .. '(' .. abc_part_string(v) .. ')'
        end
        
        
        -- repeats
        if v['repeat'] and string.len(v['repeat'])>0 and (0+v['repeat']) > 1 then
            ret = ret .. v['repeat']
        end
    end
    return ret
   
end

function abc_parts(parts)
    -- return the string representation of a parts structure
    return 'P:'..abc_part_string(parts)
end

function abc_note_length(note_length)
    return 'L:1/' .. note_length
end

function abc_lyrics(lyrics)
    -- return the ABC string for a given lyric structure
    -- lyrics should have:
    --    syllable field giving the syllable
    --    br field giving the break symbol ('-' or ' ')
    --    advance field giving the number of notes to advance to the next syllable
    local lyric_string = {}
    local next_advance
    for i,v in ipairs(lyrics) do
        local syl = v.syllable
        
        -- escape characters (unbreakable space and dash)
        syl = syl:gsub(' ', '~')
        syl = syl:gsub('-', '\\-')
        table.insert(lyric_string, syl)
        
        -- advance will be from the next symbol
        if #lyrics>i then
            next_advance = lyrics[i+1].advance
        else
            next_advance = 1
        end
        
        -- abc in holds (either syllable holds with _ or bar hold with |)
        if next_advance  then
            if next_advance=='bar' then 
                table.insert(lyric_string, '|')
            elseif next_advance>1 then
                for i=2,next_advance do
                    table.insert(lyric_string, '_')
                end
            end
        end
        
        -- insert the break symbol (' ' or '-')
        table.insert(lyric_string, v.br)
    end
    return 'w:'..table.concat(lyric_string)
end


function abc_voice(voice)
    -- return the ABC string represenation of a voice. Has
    -- an ID, and a set of optional specifiers 
    local str = 'V:'..voice.id
    
    for i,v in ipairs(voice.specifiers) do
        str = str..' '..v.lhs..'='..v.rhs
    end
    
    return str
    
end

function abc_new_part(part)
    -- return the abc definition of a new part
    return 'P:'..part
end

function abc_symbol_line(symbol_line)
    -- return the abc string for a symbol line
    -- e.g. s:* * "@here" * * !trill!
    local symbols = {}
    
    for i,v in ipairs(symbol_line) do
        -- get representation of each symbol
        if v.type=='spacer' then
            table.insert(symbols, '*')
        elseif v.type=='bar' then
            table.insert(symbols, '|')
        elseif v.type=='decoration' then
            table.insert(symbols, v.decoration)
        elseif v.type=='chord_text' then
            table.insert(symbols, v.chord_text)
        end
        table.insert(symbols, ' ')
    end
    
    -- strip trailing whitespace
    return 's:'..string.sub(table.concat(symbols), 1, -2)
end


function abc_directive(directive, inline)
    -- Return the ABC notation for a directive (I: or %%)
    -- Uses %% for all non-standard directives and I: only
    -- for standard ones. Forces I: if in inline mode
    local standard_directives = {'abc-charset', 'abc-version', 'abc-include', 'abc-creator'}
    local str
    
    if not directive then
        return ''
    end
    
    if is_in(directive.directive, standard_directives) or inline then
        str = 'I:'..directive.directive
    else
         str = '%%'..directive.directive
    end
    
    -- append space separated arguments
    for i,v in ipairs(directive.arguments) do
        str = str .. ' ' .. v
    end
    return str
end

function abc_field(v, inline)
    -- abc out a field entry (either inline [x:stuff] or 
    -- as its own line 
    -- X:stuff
    
    local str
    
    -- plain text tokens
    if v.token=='append_field_text' then 
        str =  '+' .. ':' .. v.content
    end
    
    if v.token=='field_text' then 
        str = field_tags[v.name] .. ':' .. v.content
    end
    
    -- key, tempo, meter
    if v.token=='meter' then
        str = abc_meter(v.meter)
    end
 
    -- voice definitions
    if v.token=='voice_def' or v.token=='voice_change' then
        str = abc_voice(v.voice)
    end
  
 
    if v.token=='key' then
        str = abc_key(v.key) 
    end

    if v.token=='tempo' then
        str = abc_tempo(v.tempo)
    end
    
    if v.token=='instruction' then
        str = abc_directive(v.directive, v.inline)
    end

    
    if v.token=='parts' then
        str = abc_parts(v.parts)
    end
    
    if v.token=='new_part' then
        str = abc_new_part(v.part)
    end
    
    if v.token=='symbol_line' then
        str = abc_symbol_line(v.symbol_line)
    end
    
    
    if v.token=='words' then
        str = abc_lyrics(v.lyrics)
    end
    
    if v.token=='note_length' then
        str = abc_note_length(v.note_length)
    end
    
    -- if this was a field
    if str then
        if inline then
            return '[' .. str .. ']'
        else
            return str .. '\n'
        end
    end
    
    return nil
end


function abc_triplet(triplet)
    -- abc the string represenation of a triplet specifier
    -- Uses the simplest ABC form
    -- 1-3 elements p:q:r
    -- p:q gives the ratio of the compression
    -- r gives the duration of the effect (in notes)
    
    local triplet_string
    local q_table = {-1,3,2,3,-1,2,-1,3,-1} -- default timing
    
    triplet_string = '('..triplet.p
    
    -- check if we need an r field
    local r_needed = triplet.r and triplet.r ~= triplet.p
    
    -- only need q if it's not default
    -- e.g. triplet p=3, q=2, r=3 should just be written as (3
    local q_needed = triplet.q and (q_table[triplet.p]~=triplet.q)
    
    -- triplet of form (3:2
    if q_needed or r_needed then
        triplet_string = triplet_string .. ':'
        if q_needed then 
            triplet_string = triplet_string .. triplet.q
        end
    end
    
    -- full triplet (only need r if it's not equal to p)
    if r_needed then
        triplet_string = triplet_string .. ':' .. triplet.r
    end
    
    return triplet_string -- .. ' ' -- must include trailing space separator!
end


function abc_accidental(accidental)
    local acc = ''
    if accidental then
        local ad = accidental
        -- microtonal accidenals
        if ad then
            -- 0 is = 
            if ad.den == 0 or ad.num==0 then
                acc = '='
                
            -- plain accidentals
            elseif ad.den == 1 then
                if ad.num==1 then
                    acc = '^'
                elseif ad.num==-1 then
                    acc = '_'
                elseif ad.num==2 then
                    acc = '^^'
                elseif ad.num==-2 then
                    acc = '__'
                else
                    -- triple etc. sharps notated ^3f
                    if ad.num>0 then
                        acc = '^'..ad.num
                    else
                        acc = '_'..-ad.num
                    end
                end
            else
                -- write as /n if possible
                if math.abs(ad.num)~=1 then
                    if ad.num+0<0 then
                        acc = -ad.num
                    else
                        acc = ad.num
                    end
                end
                
                
                if (ad.num+0)<0 then
                    acc = '_'..acc..'/'..ad.den
                else
                    acc = '^'..acc..'/'..ad.den
                end
                
            end
        end
    end
   return acc 
end

function abc_pitch(note_pitch)
    -- get the string represenation of a pitch table
    -- pitch; lowercase = +1 octave
    
 
    -- root note
    local pitch = note_pitch.note
    
    -- octave shifts
    if note_pitch.octave then
        local octave = note_pitch.octave
        
        if octave<1 then
            pitch = string.upper(note_pitch.note)
            octave = octave+1
        end
        
        
        -- increase octave with '
        if octave>1 then
            for i=1,octave-1 do
                pitch = pitch .. "'"
            end
        end 
        -- decrease octave with ,
        if octave<1 then
            for i=1,(1-octave) do
                pitch = pitch .. ","
            end
        end
    end
    
   -- add accidentals
    pitch = abc_accidental(note_pitch.accidental)..pitch
       
    return pitch
end


function abc_duration(note_duration)
    -- get the string representation of the duration of the note
    -- e.g. as a fraction (A/4 or A2/3 or A>)

    local duration 
 
   
    -- work out the duration form
    -- nothing if fraction is 1/1
    -- just a if fraction is a/1
    -- just /b if fraction is 1/a
    -- a/b otherwise
    if note_duration.num==1 and note_duration.den==1 then  
        duration = ''
    elseif note_duration.num~=1 and note_duration.den==1 then
        duration = note_duration.num   
    elseif note_duration.num==1 and note_duration.den~=1 then
        duration = string.format('/%d', note_duration.den)
    else
        duration = string.format('%d/%d', note_duration.num, note_duration.den)
    end
    
    -- special case: /2 becomes just / 
    if note_duration.den==2 and note_duration.num==1 then
        duration = '/'
    end

    -- add broken rhythm symbols (< and >)
    -- broken, this note shortened
    if note_duration.broken < 0 then
        duration = duration..string.rep('<',-note_duration.broken)
        
   end
   
    -- broken, this note lengthened
    if note_duration.broken > 0 then
        duration = duration..string.rep('>', note_duration.broken)        
    end
   
    return duration
end


function abc_note_def(note)
    local note_str = ''
    
    -- measure rests
    if note.measure_rest then
        if note.duration.num==1 and note.duration.den==1 then
            return 'Z'
        else
            if note.duration.den==1 then            
                return 'Z' .. note.duration.num
            else
                -- fractional bar rests aren't really in the standard, but
                -- we can genreate them anyway
                return 'Z' .. note.duration.den ..  '/' ..note.duration.num
            end
        end
    end
    
    -- space notes
    if note.space then
        return 'y'
    end
    
    -- pitch and duration
    if note.rest then
        note_str = 'z'
    else
        note_str = abc_pitch(note.pitch)
    end
    note_str = note_str .. abc_duration(note.duration)
    return note_str
end

function abc_chord(chord)  
    -- return the represenation of a chord
   local chord_str = chord_case(chord.root)
   -- omit maj for major chords
   if chord.chord_type~='maj' then
      chord_str = chord_str..string.lower(chord.chord_type)
   end
   
   if chord.inversion then
        chord_str = chord_str .. '/' .. chord_case(chord.inversion)
    end    
    return string.format('"%s"', chord_str)
end

function abc_decoration(decoration)
    -- return the string of decoration for a note, replacing standard decorations like
    -- !roll! with the default user macro replacements
    local decorations = {}
    for i,v in ipairs(decoration) do
        table.insert(decorations,default_macros[string.lower(v)] or v)
    end
    return table.concat(decorations)
end

function abc_note(note)
    -- abc a note out
    -- Return the string version of the note definition
    -- Includes pitch and duration
    local note_str = ''
    
    -- grace notes (e.g. {gabE}e)
    if note.grace then
        note_str = note_str .. '{'
        if note.grace.acciacatura then
            note_str = note_str .. '/'
        end
        for i,v in ipairs(note.grace) do
            note_str = note_str .. abc_note_def(v)
        end
        note_str = note_str .. '}'
    end
    
    -- chords (e.g. "Cm")
    if note.chord then
        note_str = note_str  .. abc_chord(note.chord) 
    end
    
    -- text annotations (e.g ">hello")
    if note.text then
        note_str = note_str .. abc_text(note.text)
    end
    
    
    -- decorations (e.g. . for legato)
    if note.decoration then        
        note_str = note_str ..  abc_decoration(note.decoration)
    end
    
    -- pitch and duration
    note_str = note_str .. abc_note_def(note)
    
    -- ties
    if note.tie then
        note_str = note_str .. '-'
    end
    
    return note_str
end



function abc_text_element(text)
    return '"' .. (text.position or '').. text.text .. '"'
end

function abc_text(text)
    text_table = {}
    for i,v in ipairs(text) do
        table.insert(text_table, abc_text_element(v))
    end
    return table.concat(text_table)
end


function abc_bar(bar)
    -- Return a string representing a bar element
    -- a bar can be
    -- | single bar
    -- || double bar
    -- [| double thick-thin bar
    -- |] double thin-thick bar
    -- |: start repeat
    -- :| end repeat
    -- :|: mid repeat    
    
    local bar_str = ''
    
    local type_symbols = {plain='|', double='||', thickthin='[|', thinthick='|]'}
    
    for i,v in pairs(type_symbols) do
        if bar.type==i then 
            bar_str = v
        end
    end
    
    if bar.type=='start_repeat' then
        bar_str= '|' .. repeat_string(':', bar.start_reps)
    end
    
    if bar.type=='end_repeat' then
        bar_str= repeat_string(':', bar.end_reps) .. '|'
    end
    
    if bar.type=='mid_repeat' then
        bar_str= repeat_string(':', bar.end_reps) .. '|' .. repeat_string(':', bar.start_reps)
    end
    
    
    -- variant indicators (e.g. for  repeats :|1 x x x :|2 x x x ||)
    if bar.variant_range then      
        -- for part variants, can have multiple indicators
        for i,v in ipairs(bar.variant_range) do
            bar_str = bar_str .. v .. ','
        end
        -- remove last comma
        bar_str = string.sub(bar_str, 1, -2)
    end
    
    return bar_str
end


function abc_variant(variant)
    -- ABC representation of a part varaint [4 or [2,3,4-5
    
    local var_str = '['
    -- for part variants, can have multiple indicators
    for i,v in ipairs(variant.variant_range) do
        var_str = var_str .. v .. ','
    end
    -- remove last comma
    var_str = string.sub(var_str, 1, -2) 
    return var_str
end

local note_elements = {split=' ', split_line='\n', continue_line='\\\n', chord_begin='[', chord_end=']', slur_end=')', slur_begin='('}

function abc_note_element(element)
    -- Return a string representing a note element 
    -- can be a note, rest, bar symbol, variant
    -- chord group, slur group, triplet/tuplet
    -- line break, beam break or some inline text
    
    local static_element = note_elements[element.token]
    
    if static_element then return static_element end
    
    if element.token=='chord' and element.chord then
            return  abc_chord(element.chord) 
    end
    
    if element.token=='overlay' then
        return string.rep('&', element.bars)
    end
        
    if element.token=='text' then     
        return abc_text_element(element.text)
    end
    
    if element.token=='triplet' then
        return abc_triplet(element.triplet)
    end
    
    if element.token=='note' then
        return abc_note(element.note)
    end
    
    if element.token=='bar' then
        return abc_bar(element.bar)
    end
 
    if element.token=='variant' then
        return abc_variant(element.variant)
    end
 
    
    return nil
    
end
 
function abc_element(element)    
    -- return the abc representation of token_stream element
    
    return abc_note_element(element) or abc_field(element, element.inline)
    
end

function emit_abc(token_stream)
-- return the token_stream out as a valid ABC string
    local output = {}       
    for i,v in ipairs(token_stream) do
         table.insert(output, abc_element(v))
    end    
    -- concatenate into a single string
    return rtrim(table.concat(output))
end

function abc_from_songs(songs, creator)
    -- return the ABC representation of a table of songs
    -- the creator field can optionally be specified to identify
    -- the program that created this code
    local out = {}
    if creator then
        -- write out header
        table.insert(out, '%abc-2.1\n')
        table.insert(out, '%%abc-creator '..creator..'\n')
    end
   
    -- each song segment separated by two newlines
    for i,v in ipairs(songs) do
        table.insert(out, emit_abc(v.token_stream))
        table.insert(out, '\n\n')
    end
    return table.concat(out)
end





