function parse_range_list(range_list)
    -- parses a range identifier
    -- as a comma separated list of numbers or ranges
    -- (e.g. "1", "1,2", "2-3", "1-3,5-6")
    -- Returns each value in this range
    
    local range_pattern = [[
    range_list <- ((<range>) (',' <range>) *) -> {}
    range <- (   <range_id> / <number> ) -> {}
    range_id <- (<number> '-' <number>)
    number <- ({ [0-9]+ }) 
    ]]    
    local matches = re.match(range_list, range_pattern)    
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


function parse_bar(bar, song)
-- Parse a bar symbol and repeat/variant markers. Bars can be
-- plain bars (|)
-- bars with thick lines (][)
-- repeat begin (|:)
-- repeat end (:|)
-- repeat middle (:||: or :: or :|:)
-- variant markers [range

    local bar_pattern = [[
        bar <- (  
        {:mid_repeat: <mid_repeat> :} /  {:end_repeat: <end_repeat> :}  / {:start_repeat: <start_repeat> :} / {:double: <double> :}
        /  {:thickthin: <thickthin> :} / {:thinthick: <thinthick> :} /  / {:plain: <plain> :} / {:variant: <variant> :} / {:just_colons: <just_colons> :} ) -> {}        
        mid_repeat <- ({}<colons> {}<plain>{} <colons>{}) -> {}
        start_repeat <- (<plain> {} <colons> {} ) -> {}
        end_repeat <- ({}<colons> {} <plain> ) -> {}
        just_colons <- ({} ':' <colons>  {}) -> {}
        plain <- ('|')
        thickthin <- (('['/']') '|')
        thinthick <- ('|' ('[' / ']') )
        double <- ('|' '|')
        
        variant <- ('[')
        colons <- (':' +) 
    ]]
    
  
    local type_info = re.match(bar.type, bar_pattern)
    
    -- compute number of colons around bar (which is the number of repeats of this section)
    if type_info.mid_repeat then
        type_info.end_reps = type_info.mid_repeat[2]-type_info.mid_repeat[1]
        type_info.start_reps = type_info.mid_repeat[4]-type_info.mid_repeat[3]
    end
    
    if type_info.end_repeat then
        type_info.end_reps = type_info.end_repeat[2]-type_info.end_repeat[1]        
    end
    
    -- thick bars work like repeats with a count of one
    if type_info.thickthin or type_info.thinthick or type_info.double then
        type_info.end_reps = 0
        type_info.end_repeat = true
    end
    
    if type_info.start_repeat then
        type_info.start_reps = type_info.start_repeat[2]-type_info.start_repeat[1]        
    end        
    
    -- for a colon sequence, interpret :: as one start end repeat, :::: as two start, two end, etc.
    -- odd colon numbers without a bar symbol don't make sense!
    if type_info.just_colons then
       
        type_info.start_reps = type_info.just_colons[2]-type_info.just_colons[1] / 2
        type_info.start_reps = type_info.just_colons[4]-type_info.just_colons[3] / 2
        type_info.mid_repeat = type_info.just_colons -- this is a mid repeat
        type_info.just_colons = nil
    end
    
    
    local bar_types = {'mid_repeat', 'end_repeat', 'start_repeat', 'variant',
    'plain', 'double', 'thickthin', 'thinthick'}
    
    local parsed_bar = {}
    
    -- set type field
    for i,v in ipairs(bar_types) do
        if type_info[v] then
            parsed_bar.type = v
        end
    end
    
    -- convert ranges into a list of integers
    if bar.variant_range then     
         parsed_bar.variant_range = parse_range_list(bar.variant_range)
    end
    
    parsed_bar.end_reps = type_info.end_reps
    parsed_bar.start_reps = type_info.start_reps
    
    return parsed_bar           
end

