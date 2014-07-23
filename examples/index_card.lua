--------------------------------------------------------------------
-- Produce a simplified, "index card" version of a tune
---------------------------------------------------------------------

require "abclua"
require "examples/instrument_model"



function print_rhythm(song)
    local tied = false
    local bars = 0
	local use_vowels = false
    local last_dash = ''
    for i,v in ipairs(song.tokens) do
		print(v)
        if v.event=='note' then
            local dur = v.note.play_notes*4            
            -- if we know the name of this note...
            if names[dur] then 
                local name = names[dur]   
                -- remove consonant at start on tied notes
                if tied then name=name:gsub('[bdtk]', '') end
                tied=false
				if use_vowels then
					-- use vowels as crude pitch
					if v.note.play_pitch>=72 then name=name:gsub('a', 'e') end
					if v.note.play_pitch>=68 then name=name:gsub('a', 'u') end
					if v.note.play_pitch<=54 then name=name:gsub('a', 'o') end
				end
				
                if v.note.tie then tied=true end
                -- only write dashes between long notes
                if last_dash then io.write(last_dash) end
                if dur>=0.5 then
                    last_dash = '-' 
                end
                
                io.write(name)
            else
                print(dur)
            end
        end
        
        -- write bar spaces
        if v.event=='bar' then
            last_dash = ''
            -- if tied across a bar, then use a dash instead of a space
            if tied then io.write('') else io.write(' | ') end            
            -- break line after 6 bars
            bars = bars + 1
            if bars==6 then
                bars = 0
                io.write('\n')
            end
        
        end
        
    end
end

function fit_to(s, n, r)
	
	-- make s fit into exactly n characters
	if s==nil then
		return string.rep(r, n)
	end
	
	if #s>n then
		return s:sub(1, n)
	end
	
	if #s<n then
		return s..string.rep(r, (n-#s))
	end
	
	return s
end

chars_per_line = 155
title_length = 40
rhythm_length = 15
meter_length = 5
key_length = 18
tempo_length = 20

function title_line(i,v)
	-- create a title line for the song
	-- [title] [rhythm] [time signature] [key (sharps/flats)]	
	
	line = fit_to("", 2, "-")
	
    
    
	key = v.metadata.key						
    
	key = string.sub(abc_key(key), 3)
	sharps = create_key_structure(v.metadata.key)
    
	key_sig = ""
	for k,v in pairs(sharps) do
		if v==1 then
			key_sig = key_sig .. k:upper() .. "# "
		end
		
		if v==-1 then
			key_sig = key_sig .. k:upper() .. "b "
		end								
	end
	
	--key = "Key:"..key
	if #key_sig>0 then
		key_acc = "(" .. key_sig:sub(1,#key_sig-1) .. ")"
		line = line .. fit_to(key.." "..key_acc, key_length, "-")			
	else
		line = line .. fit_to(key, key_length, "-")
	end
	
	line = line .. fit_to(v.metadata.meter, meter_length, "-")			
	
	
	if v.metadata.rhythm then
		line = line .. fit_to(v.metadata.rhythm[1], rhythm_length, "-")
	else
		line = line .. fit_to(nil, rhythm_length, "-")
	end
	
	--line = line..fit_to(v.metadata.length, tempo_length, "-")
    
	--title = fit_to(v.metadata.title[1], l, "-")
	title = " "..rtrim(v.metadata.title[1])
	
	line = fit_to(line, chars_per_line-#(title), "-")
	line = line .. title
	
	return line
end

function filter_tokens(t)
	tokens = {}
	for i,v in ipairs(t) do
		if v.token=='note' or v.token=='bar' or v.token=='split' or v.token=='triplet' or v.token=='slur_begin' or v.token=='slur_end' then
			if v.note then
				v.note.chord = nil
			end
			table.insert(tokens, v)
		end
	end
	return tokens	
end

function center(s, n)
	
	pad = (n - #s) / 2
	pad = math.floor(pad)
	s = string.rep(" ", pad) .. s .. string.rep(" ", pad)
	if #s<n then
		s = s.." "
	end	
	
	return s
end


function emit(t, bar_length, bars_per_line)
	local elts = {}
	local bars = 0
	
	
	local max_line = 0
	local line_ctr = 0
	local bar_string = ""
	for i,v in ipairs(t) do						
		element = abc_note_element(v)
		
		if v.penalty and v.penalty==-1 then
			element = "!"..element
		end
        
        if v.penalty and v.penalty>10 then
			element = "*"..element
		end
		
						
		if v.token=='bar' then								
			if #bar_string>0 then			
				if #bar_string>bar_length-2 then
					return emit(t, bar_length+1, bars_per_line)					
				end								
				bars = bars + 1								
				bar_string = center(bar_string, bar_length-#element)			
				bar_string = bar_string .. element
				line_ctr = line_ctr + #bar_string
				if line_ctr>max_line then
					max_line = line_ctr
				end
				table.insert(elts, bar_string)
				bar_string = ""
			else
				bar_string = bar_string .. element
			end						
			
			if (bars>bars_per_line and bars_per_line>0) then -- or ((v.bar.type=='end_repeat' or v.bar.type=="double") and v.bar.variant_range==nil) then
				bars = 0				
				line_ctr = 0
				table.insert(elts, "\n")
			end			
		else			
			bar_string = bar_string .. element			
		end
	end
	
	n = #elts
	while elts[n]=='\n' do
		table.remove(elts, n)
		n = #elts
	end
			
	
	return table.concat(elts), max_line
end

function rhythm(fname)
    local songs = parse_abc_file(fname)    
    local nbars, output, tokens
	local line
	local bar_length = 8
	local bar_per_line = 16
	local lines_per_page = 46
	local line_ctr = 0
	local whistle =  make_whistle()
	local page_no = 1
	local page_str
    local index = {}
    
    local document = {}
    local id = 0
    
    for i,v in ipairs(songs) do
		
		
        if v.metadata.title then				
            table.insert(index, {page=page_no, tune=v.metadata.title[1], id=id})
            id = id + 1
			
			optimal_transpose(v, whistle)	       
            for i,t in ipairs(v.token_stream) do
                if t.token=='key' then                    
                    v.metadata.key = t.key
                end
            end
                
            
			precompile_token_stream(v.token_stream)
			mark_instrument(v.token_stream, whistle)
		    title_string = title_line(i,v)
			tokens = filter_tokens(v.token_stream)
			nbars = bar_per_line
			
			output, line = emit(tokens, bar_length, nbars)
			
			while line>chars_per_line and nbars>1 do
				nbars = math.floor(nbars - 1)				
				output, line = emit(tokens, bar_length, nbars)				
			end
			
			-- form feed if needed
			local _, count = string.gsub(output, "\n", "")
			if line_ctr+count+2>lines_per_page then
				while line_ctr<lines_per_page-1 do
                    table.insert(document, "\n")
					
					line_ctr = line_ctr + 1
				end
				page_str = ""..page_no
				page_line = string.rep(" ",(chars_per_line-#page_str)/2).."["..page_str.."]"..string.rep(" ",(chars_per_line-#page_str)/2) 
                --table.insert(document, page_line.."\n")
                                
				page_no = page_no + 1
				table.insert(document, "\f\n")
				line_ctr = 0			
			else
				line_ctr = line_ctr + count + 2
			end
			
            table.insert(document, title_string.."\n")
            
            table.insert(document, output.."\n")
			
        end
	
    end
    page_str = ""..page_no
    page_line = string.rep(" ",(chars_per_line-#page_str)/2).."["..page_str.."]"..string.rep(" ",(chars_per_line-#page_str)/2) 
    --table.insert(document, page_line.."\n")
    
    
    -- for i,v in ipairs(index) do
        -- print(fit_to(v.tune,chars_per_line-10,".")..v.page)        
    -- end
    print(table.concat(document))
    
    
end

if #arg~=1 then
	print(#arg)
    print("Usage: hum_rhythm.lua <file.abc>")
  else
    rhythm(arg[1])
	
end

