local range_matcher = re.compile([[
    range_list <- ((<range>) (',' <range>) *) -> {}
    range <- (   <range_id> / <number> ) -> {}
    range_id <- (<number> '-' <number>)
    number <- ({ [0-9]+ }) 
    ]])

function parse_range_list(range_list)
    -- parses a range identifier
    -- as a comma separated list of numbers or ranges
    -- (e.g. "1", "1,2", "2-3", "1-3,5-6")
    -- Returns each value in this range
    
    local matches = range_matcher:match(range_list)    
    assert(#matches>0, "Range could not be parsed in bar variant.")
    
    local sequence = {}    
    -- append each element of the range list
    for i,v in ipairs(matches) do
        -- single number
        if #v==1 then
            table.insert(sequence, v[1]+0)
        end
        
        -- range of values
        if #v==2 then            
            for j=v[1]+0,v[2]+0 do
                table.insert(sequence, j)
            end
        end    
    end
    
    
    return sequence

end


local bar_matcher = re.compile([[bar <- (  
        {:mid_repeat: <mid_repeat> :} /  {:end_repeat: <end_repeat> :}  / {:start_repeat: <start_repeat> :} / {:double: <double> :}
        /  {:thickthin: <thickthin> :} / {:thinthick: <thinthick> :} /  {:plain: <plain> :} / {:variant: <variant> :} / {:just_colons: <just_colons> :} ) -> {}        
        mid_repeat <- ({}<colons> {}(<plain>+){} <colons>{}) -> {}
        start_repeat <- (<plain> {} <colons> {} ) -> {}
        end_repeat <- ({}<colons> {} <plain> ) -> {}
        just_colons <- ({} ':' <colons>  {}) -> {}
        plain <- ('|')
        thickthin <- (('[' / ']') '|')
        thinthick <- ('|' ('[' / ']') )
        double <- ('|' '|')
        
        variant <- ('[')
        colons <- (':' +) 
]])

function parse_bar(bar, song)
-- Parse a bar symbol and repeat/variant markers. Bars can be
-- plain bars (|)
-- bars with thick lines (][)
-- repeat begin (|:)
-- repeat end (:|)
-- repeat middle (:||: or :: or :|:)
-- variant markers [range
   local type_info = bar_matcher:match(bar.type)
    
    assert(type_info~=nil, "Bar could not be parsed.")
    -- compute number of colons around bar (which is the number of repeats of this section)
    if type_info.mid_repeat then
        type_info.end_reps = type_info.mid_repeat[2]-type_info.mid_repeat[1]
        type_info.start_reps = type_info.mid_repeat[4]-type_info.mid_repeat[3]
    
    
    elseif type_info.end_repeat then
        type_info.end_reps = type_info.end_repeat[2]-type_info.end_repeat[1]        
    
    
    -- thick bars work like repeats with a count of one
    elseif type_info.thickthin or type_info.thinthick or type_info.double then
        type_info.end_reps = 0
        type_info.end_repeat = true
    
    
    elseif type_info.start_repeat then
        type_info.start_reps = type_info.start_repeat[2]-type_info.start_repeat[1]        
           
    
    -- for a colon sequence, interpret :: as one start end repeat, :::: as two start, two end, etc.
    -- odd colon numbers without a bar symbol don't make sense!
    elseif type_info.just_colons then
        local colons = type_info.just_colons[2]-type_info.just_colons[1]
        assert(colons%2==0, "Bad number of colons in :: repeat bar.")
        type_info.start_reps = colons / 2
        type_info.end_reps = colons / 2
        type_info.mid_repeat = type_info.just_colons -- this is a mid repeat
        type_info.just_colons = nil
    end
    
    
    local bar_types = {'mid_repeat', 'end_repeat', 'start_repeat', 'variant',
    'plain', 'double', 'thickthin', 'thinthick'}
    
    local parsed_bar = {}
    
    -- set type field
    for i=1,#bar_types  do
        local v = bar_types[i]
        if type_info[v] then
            parsed_bar.type = v
        end
    end
    
    assert(parsed_bar.type, "Bar parsed incorrectly.")
    
    -- convert ranges into a list of integers
    if bar.variant_range then     
         parsed_bar.variant_range = parse_range_list(bar.variant_range)
    end
    
    parsed_bar.end_reps = type_info.end_reps
    parsed_bar.start_reps = type_info.start_reps
    
    
    return parsed_bar           
end

