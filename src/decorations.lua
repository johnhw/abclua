-- functions for rendering decorations into the stream
-- decorations can
--  create grace notes
--  slide timing
--  insert MIDI renderable CC changes 

local decorations = {
    ['.'] = 'staccato',
    ~ = 'roll', 
    H = 'fermata',
    M = 'lowermordernt',
    O = 'coda'
    P = 'uppermordent'
    S = 'segno',
    T = 'trill',
    u = 'up-bow',
    v = 'down-bow',
    
}

function render_decorations(stream)
    -- return a new stream with decorations applied
    local out = {}
    for i,v in ipairs(stream)
        table.insert(out, v)
    end
end