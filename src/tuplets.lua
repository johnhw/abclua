-- Functions for dealing with tuplets

function update_triplet_ratio(song)
    -- compute the current compression ratio
    -- The product of all active triplets
    local ratio = 1
    for i,v in ipairs(song.context.timing.triplet_state) do
        ratio = ratio / v.ratio
    end
    song.context.timing.triplet_compress = ratio
end

function push_triplet(song, p, q, r)
    -- push a new triplet onto the stack
    table.insert(song.context.timing.triplet_state, {count=r, ratio=p/q})
    update_triplet_ratio(song)
end

function update_tuplet_state(song)
    -- a note has occured; change tuplet state
    -- update tuplet counters; if back to zero, remove that triplet
    
    local actives = {}
    for i,v in ipairs(song.context.timing.triplet_state) do
        v.count = v.count-1
        -- keep only triplets with counters > 0
        if v.count > 0 then
            table.insert(actives, v)
        end
    end    
    song.context.timing.triplet_state = actives
        
    -- update the time compression
    update_triplet_ratio(song)

end

function apply_triplet(song, triplet)
    -- set the triplet fields in the song
    local p,q,r
    
    if triplet.q == 'n' then
        -- check if compound time -- if so
        -- the default timing for (5 (7 and (9 changes
        if is_compound_time(song) then
            q = 3
        else    
            q = 2
        end
    else
        q = triplet.q
    end
    p = triplet.p
    r = triplet.r 
    
    -- set compression and number of notes to apply this to    
    push_triplet(song, triplet.p, triplet.q, triplet.r)
    
end



function parse_triplet(triplet, song)
-- parse a triplet/tuplet definition, which specifies the contraction of the following
-- n notes. General form of p notes in the time of q for the next r notes

    local n, p, q, r
    q=-1
    r=-1
            
    -- simple triplet of form (3:
    if #triplet==1 then
        p = triplet[1]+0                
    end
    
    -- triplet of form (3:2
    if #triplet==2 then
        p = triplet[1]+0                
        q = triplet[2]+0
    end
    
    -- triplet of form (3:2:3 or (3::2 or (3::
    if #triplet==3 then
        p = triplet[1]+0
        if triplet[2] and string.len(triplet[2])>0 then
            q = triplet[2]+0
        end
        if triplet[3] and string.len(triplet[3])>0 then
            r = triplet[3]+0
        end
    end
       
    -- default: r is equal to p
    if r==-1 then
        r = p
    end

    -- allow long triplets
    -- if p>9 then
        -- warn("Bad triplet length (p>9)")
    -- end
    
    -- default to choosing q from the table
    local q_table = {-1,3,2,3,'n',2,'n',3,'n'}
    if q==-1 then
        q = q_table[p]
    end
        
    return {p=p, q=q, r=r}
end