-- functions for writing out text represenatations of the song journal
local field_tags = {key = 'K'
,title = 'T'
,ref =  'X'
,area =  'A'
,book =  'B'
,composer =  'C'
,discography =   'D'
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

function abc_meter(meter)
    -- return the string representation of a meter
    -- e.g. {num=3, den=4} becomes 'M:3/4'
    -- if there is an explicit emphasis then this produces
    -- a compound numerator (e.g. M:(2+3+2)/4)
    local num = ''
    
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
    
    
    -- abc out the tempo units
    for i,v in ipairs(tempo) do
        q = q .. string.format('%s/%s ', v.num..'', v.den..'')
    end
    
    -- strip trailing space
    q = string.sub(q, 1, -2)
    
    -- the rate as =140
    q = q .. '=' .. tempo.div_rate
    
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
    local name = key.naming
    
    -- root and modal modifier
    local root = string.upper(key.naming.root) 
    if key.naming.mode then     
        root = root .. key.naming.mode
    end

    -- accidentals
    if key.naming.accidentals then
        acc = ' '
        for i,v in ipairs(key.naming.accidentals) do
            acc = acc .. v
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


function abc_field(v)
    -- abc out a field entry (either inline [x:stuff] or 
    -- as its own line 
    -- X:stuff
    
    -- plain text events
    if v.event=='append_field_text' then 
        return  '+' .. ':' .. v.content
    end
    
    if v.event=='field_text' then 
        return field_tags[v.name] .. ':' .. v.content
    end
    
    -- key, tempo, meter
    if v.event=='meter' then
        return abc_meter(v.meter)
    end
    
    if v.event=='key' then
        return abc_key(v.key) 
    end

    if v.event=='tempo' then
        return abc_tempo(v.tempo)
    end
    
    if v.event=='parts' then
        return abc_parts(v.parts)
    end
    
    if v.event=='words' then
        return abc_lyrics(v.lyrics)
    end
    
    if v.event=='note_length' then
        return abc_note_length(v.note_length)
    end
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
    
    return triplet_string .. ' ' -- must include trailing space separator!
end


function abc_pitch(note_pitch)
    -- get the string represenation of a pitch table
    -- pitch; lowercase = +1 octave
    
    -- root note
    pitch = note_pitch.note
    
    -- octave shifts
    if note_pitch.octave then
        if note_pitch.octave==1 then
            pitch = string.lower(note_pitch.note)
        end
        -- increase octave with '
        if note_pitch.octave>1 then
            for i=2,note_pitch.octave do
                pitch = pitch + "'"
            end
        end 
        -- decrease octave with ,
        if note_pitch.octave<0 then
            for i=1,-note_pitch.octave do
                pitch = pitch + ","
            end
        end
    end
    
    if note_pitch.accidental then
        -- accidentals
        if note_pitch.accidental==1 then
            pitch = '^' + pitch
        end
        
        if note_pitch.accidental==2 then
            pitch = '^^' + pitch
        end
        
        if note_pitch.accidental==-1 then
            pitch = '_' + pitch
        end
        
        if note_pitch.accidental==-2 then
            pitch = '__' + pitch
        end
        
        if note_pitch.accidental==0 then
            pitch = '=' + pitch
        end  
    end
    return pitch
end


function abc_duration(note_duration)
    -- get the string representation of the duration of the note
    -- e.g. as a fraction (A/4 or A2/3 or A>)

    local duration = ''
 
    -- work out the duration form
    -- nothing if fraction is 1/1
    -- just a if fraction is a/1
    -- just /b if fraction is 1/a
    -- a/b otherwise
    if note_duration.num~=1 then
        duration = duration .. note_duration.num
    end
    if note_duration.den~=1 then
        duration = duration .. '/' .. note_duration.den
    end

    -- add broken rhythm symbols (< and >)
    -- broken, this note shortened
    if note_duration.broken < 0 then
        for i=1,-note_duration.broken do
            duration = duration..'<'
        end
    end
   
    -- broken, this note lengthened
    if note_duration.broken > 0 then
        for i=1,note_duration.broken do
            duration = duration..'>'
        end
    end
   
    return duration
end


function abc_note_def(note)
    local note_str = ''
    
    -- measure rests
    if note.measure_rest then
        if note.measure_rest.bars==1 then
            return 'Z'
        else
            return 'Z' .. note.measure_rest.bars
        end
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

function abc_note(note)
    -- abc a note out
    -- Return the string version of the note definition
    -- Includes pitch and duration
    local note_str = ''
    
    -- grace notes (e.g. {gabE}e)
    if note.grace then
        note_str = note_str .. '{'
        for i,v in ipairs(note.grace) do
            note_str = note_str .. abc_note_def(v)
        end
        note_str = note_str .. '}'
    end
    
    -- chords (e.g. "Cm")
    if note.chord then
        note_str = note_str .. '"' .. note.chord .. '"'
    end
    
    -- decorations (e.g. . for legato)
    if note.decoration then
        note_str = note_str ..  note.decoration
    end
    
    -- pitch and duration
    note_str = note_str .. abc_note_def(note.note_def)
    
    -- ties
    if note.tie then
        note_str = note_str .. '-'
    end
    
    return note_str
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
    -- [n start variant
    
    local bar_str = ''
    
    local type_symbols = {plain='|', double='||', thickthin=']|', thinthick='[|',
    variant='['}
    
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
    
    if bar.type=='variant' then 
        bar_str = '[' 
    end
    
    -- variant indicators (e.g. for parts [4 or for repeats :|1 x x x :|2 x x x ||)
    if bar.variant_range then
        -- for part variants, can have multiple indicators
        if bar.variant then
            for i,v in ipairs(bar.variant_range) do
                bar_str = bar_str .. v .. ','
            end
            -- remove last comma
            bar_str = string.sub(bar_str, 1, -1)
        else
            -- can only have one variant indicator
            bar_str = bar_str .. bar.variant_range[1]
        end
    end
    
    return bar_str
end


function abc_note_element(element)
    -- Return a string representing a note element 
    -- can be a note, rest, bar symbol
    -- chord group, slur group, triplet/tuplet
    -- line break, beam break or some inline text
    if element.event=='split' then
        return ' '
    end
    
    if element.event=='split_line' then
        return '\n'
    end
    
    if element.event=='chord_begin' then
        return '['
    end
    
    if element.event=='chord_end' then
        return ']'
    end
    
    if element.event=='slur_begin' then
        return '('
    end
    if element.event=='slur_end' then
        return ')'
    end
    
    if element.event=='text' then
        return '"' .. element.text .. '"'
    end
    
    if element.event=='triplet' then
        return abc_triplet(element.triplet)
    end
    
    if element.event=='note' then
        return abc_note(element.note)
    end
    
    if element.event=='bar' then
        return abc_bar(element.bar)
    end
    
    
    
    return ''
    
end
 
function journal_to_abc(journal)
-- return the journal out as a valid ABC string
    local output = {}
    
    for i,v in ipairs(journal) do
    
        
        if v.field then 
            if v.inline then
                table.insert(output, '[')
            end
        
            table.insert(output, abc_field(v))
            
            if v.inline then
                table.insert(output, ']')
            else
                table.insert(output, '\n')
            end
        else
           
            table.insert(output, abc_note_element(v))
        end
    end
    -- concatenate into a single string
    return table.concat(output)
end