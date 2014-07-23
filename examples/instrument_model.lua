abclua = require "abclua"


function set_instrument_score(instrument, notes, score)
    -- Set the score for each specified note in notes to the     
    -- score given. Notes are specified as if they were in the
    -- key of C; all flats and sharps must be explicitly stated
    local fragment = abclua.parse_abc_fragment(notes)
    for i,v in ipairs(fragment) do
        if v.token=='note' then
            local index = abclua.midi_note_from_note(nil,v.note)
            instrument[index] = {difficulty=score}
        end
    end	
end

function transpose_instrument(instrument, offset)
    -- Transpose an instrument definition by the given number
    -- of semitones. e.g. transpose_instrument_score(d_whistle, -2)
    -- returns a high c whistle definition
    local transposed = {}
    for i,v in pairs(instrument) do
        transposed[i+offset] = v 
    end
    return transposed
end

function check_instrument(stream, instrument, offset)
    -- check how well a stream matches a given instrument
    -- instrument specifies the penalties for playing different pitches
    -- (given in MIDI note numbers)
    -- 0=most desirable, 1=less desirable, etc. If not specified
    -- then that instrument cannot play that note
    --
    -- returns: total_unplayable, total_penalty
    -- modifies stream so that note elements have a penalty field (equals -1 if unplayable)
   
    local total_unplayable = 0
    local total_penalty = 0
    local pitch
    for i,v in ipairs(stream) do
		
        if v.token=='note' and v.note.play_pitch then
			
            pitch = v.note.play_pitch+offset
            
            -- check if playable at all
            if not instrument[pitch]  then
                total_unplayable = total_unplayable + 1                                
            else
                -- accumulate penalty
                total_penalty = total_penalty + instrument[pitch].difficulty                                                
            end
        end     
    end    
    return total_unplayable, total_penalty    
end


function mark_instrument(stream, instrument)
    -- check how well a stream matches a given instrument
    -- instrument specifies the penalties for playing different pitches
    -- (given in MIDI note numbers)
    -- 0=most desirable, 1=less desirable, etc. If not specified
    -- then that instrument cannot play that note
    --
    -- returns: total_unplayable, total_penalty
    -- modifies stream so that note elements have a penalty field (equals -1 if unplayable)
   
    local pitch	
    for i,v in ipairs(stream) do		
		
        if v.token=='note' and v.note.play_pitch then						
            pitch = v.note.play_pitch            		
            -- check if playable at all
            if not instrument[pitch]  then           
				v.penalty = -1
            else
                -- accumulate penalty
                v.penalty = instrument[pitch].difficulty                
            end
        end     
    end        
end


function optimal_transpose(stream, instrument)   
    -- find the transposition that minimises the unplayable/difficult notes
    -- for the given instrument, and transpose the token stream to that key
    local scores = {}
	
	precompile_token_stream(stream.token_stream)    
    
    -- try each transposition in a +/- 2 octave range
    for i=-12,12 do
        local unplayable, penalty
        unplayable, penalty = check_instrument(stream.token_stream, instrument, i)
        table.insert(scores, {unplayable*200 + penalty + math.abs(i), i})
    end    
    -- sort by score
    table.sort(scores, function(a,b) return a[1]<b[1] end)
	
    local optimal = scores[1][2]	
	diatonic_transpose(stream.token_stream, optimal)	
    return stream
end

function make_whistle()
    -- create a basic instrument which has penalties for playing on a high D whistle
    local d_whistle = {}
    set_instrument_score(d_whistle, "DE^FGAB^cd", 0)
    set_instrument_score(d_whistle, "e^fgabc'd'=c=c'", 5)    
    set_instrument_score(d_whistle, "^D=F^G^A=f^d^g^a", 50)
    --set_instrument_score(d_whistle, "d'e'^f'g", 100)       
    return d_whistle
end

