-- Functions for dealing with parts, repeats and sub-patterns
local re = require "re"



function start_new_part(song, name)
    -- start a new part with the given name. writes the old part into the part table
    -- and clears the current section
    
    add_section(song, 1) -- add any left over section    
    song.internal.part_map[song.internal.current_part] = song.internal.pattern_map
    song.internal.pattern_map = {}
    song.internal.current_part = name
    song.internal.in_variant = nil
    song.temp_part = {}
    song.opus = song.temp_part   
end

local variant_tag



function start_variant_part(song, bar)
    -- start a variant part. The variant specifier indicates the ranges that 
    -- this variant will apply to.
    -- Enters a part called (current_part).N where N is each range this part applies to
    -- and registers the sub-part in the variants table
    
    -- parse the variant list
    endings = bar.variant_range
    
    -- if we are not already in a variant, record the arent part
    if not song.in_variant_part then
        song.internal.parent_part = song.internal.current_part
        song.in_variant_part = true
    end
        
    -- generate new ID for this tag
    local part_tag = song.internal.parent_part .. '.' .. variant_tag
    start_new_part(song, part_tag)
    variant_tag = variant_tag + 1
    
    -- fill in the variants in the parent part map
    local variant_map = song.part_map[song.internal.parent_part].variants
    
    for i,v in ipairs(endings) do
        variant_map[v] = part_tag
    end
                
    
    
end

function compose_parts(song)
    -- Compose each of the parts in the song into one single event stream
    -- using the parts indicator. If no parts indicator, just uses the default part
    -- Combines all repeats etc. inside each part into a stream as well
    -- The final stream is a fresh copy of all the events
    
    
    start_new_part(song, nil)
    
    local variant_counts = {}
    
    if song.internal.part_seqeunce then                 
        song.stream = {}
        for c in song.internal.part_sequence:gmatch"." do            
            append_table(song.stream, deepcopy(expand_patterns(song.internal.part_map[c])))
            
            -- count repetitions of this part
            if not variant_counts[c] then
                variant_counts[c] = 1
            else
                variant_counts[c] = variant_counts[c] + 1
            end
            
            -- expand the variants
            local vc = variant_counts[c]
            if song.internal.part_map[c].variants and song.internal.part_map[c].variants[vc] then
                -- find the name of this variant ending
                variant_part_name = song.internal.part_map[c].variants[vc]
            
                append_table(song.stream, deepcopy(expand_patterns(song.internal.part_map[variant_part_name])))
            
            end            
            
        end        
    else
        -- no parts indicator
        song.stream = deepcopy(expand_patterns(song.internal.part_map['default']))
    end
    
end


function expand_patterns(patterns)
    -- expand a pattern list table into a single event stream
    local result = {}
    
    for i,v in ipairs(patterns) do
        
        for i=1,v.repeats do
            -- repeated measures (including single repeats!)
            append_table(result, v.section)    
            
            -- append variant endings
            if #v.variants>=i then
                append_table(result, v.variants[i])    
            
            end
        end
    end
    
    return result        
end




function add_section(song, repeats)
    -- add the current temporary buffer to the song as a new pattern
    -- repeat it repeat times
    repeats = repeats or 1
        
    if not song.internal.in_variant then
        table.insert(song.internal.pattern_map, {section=song.opus, repeats=repeats, variants={}})
    else
        table.insert(song.internal.pattern_map[#song.internal.pattern_map].variants, song.opus)
    end
    
    song.temp_part = {}
    song.opus = song.temp_part
    
end
    

