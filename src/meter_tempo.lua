

local tempo_matcher = re.compile([[
tempo <- (

    (["] {:name: [^"]* :} ["] %s *) ?
    ( 
    (  (  (div (%s + div) *)  )  %s * '=' %s * {:tempo_rate: number:} )  /
    (  'C=' {:tempo_rate: number:} ) /
    (  {:tempo_rate: number :} ) 
    ) ?
    (%s + ["] {:name: [^"]* :} ["] %s *) ?
) -> {}

div <- ({:num: number:} %s * '/' %s * {:den: number:}) -> {}
number <- ( [0-9] + )
]])

-- standard tempo names
local tempo_names = {
larghissimo=40,
moderato=104,
adagissimo= 44,
allegro= 120,
allegretto= 112,
lentissimo= 48,
largo=        56,
vivace =168,
adagio=59,
vivo=180,
lento=62,
presto=192,
larghetto=66,
allegrissimo=208,
adagietto=76,
vivacissimo=220,
andante=88,
prestissimo=240,
andantino=96
}

function parse_tempo(l)
    -- Parse a tempo string
    -- Returns a tempo table, with an (optional) name and tempo_rate field
    -- tempo_rate is in units per second
    -- the numbered elements specify the unit lengths to be played up to that point
    -- each element has a "num" and "den" field to specify the numerator and denominator
    local captures = tempo_matcher:match(l)        
    if captures and captures.name and not captures.tempo_rate then    
        -- fill in rate / division if we just have a name        
        if tempo_names[string.lower(captures.name)] then
           captures.tempo_rate = tempo_names[string.lower(captures.name)]
           captures[1] = {num=1, den=4}
        end
    end
    
    return captures
end

local length_matcher = re.compile("('1' ('/' {[0-9] +}) ?) -> {}")
function parse_length(l)
    -- Parse a string giving note length, as a fraction "1/n" (or plain "1")
    -- Returns integer representing denominator.
    local captures = length_matcher:match(l)             
    if captures[1] then
        return captures[1]+0
    else
        return 1    
    end
end



function get_simplified_meter(meter)
    -- return meter as a simple num/den form
    -- with the beat emphasis separate
    -- by summing up all num elements
    -- (e.g. (2+3+2)/8 becomes 7/8)
    -- the beat emphasis is stored as
    -- emphasis = {1,3,5}

    if meter.common then
        return {num=4, den=4, emphasis={0}}
    end
    
    if meter.cut then
        return {num=2, den=2, emphasis={0}}
    end
    
    if meter.none then
        return {num=0, den=0, emphasis={0}}
    end
    
    local total_num = 0
    local emphasis = {}
    for i,v in ipairs(meter.num) do
        table.insert(emphasis, total_num)
        total_num = total_num + v
    end
    return {num=total_num, den=meter.den, emphasis=emphasis}
end

local meter_matcher = re.compile([[
    meter <- (fraction / cut / common / none) 
    common <- ({:common: 'C' :}) -> {}
    cut <- ({:cut: 'C|' :}) -> {}
    none <- ({:none: 'none' / '' :})  -> {}    
    fraction <- ({:num: complex :} %s * '/' %s * {:den: [0-9]+ :}) -> {}    
    complex <- ( '(' ? ((number + '+') * number) ->{} ')' ? )
    number <- {([0-9]+)}     
    ]])

function parse_meter(m)
    -- Parse a string giving the meter definition
    -- Returns fraction as a two element table
    local captures = meter_matcher:match(m)    
    return get_simplified_meter(captures)
    
end

