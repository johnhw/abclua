
function repeat_string(str, times)
    -- return the concatenation of a string a given number of times
    -- e.g. repeat_string('abc', '3') = 'abcabcabc'
    return string.rep(str, times)       
end

-- return the greatest common divisor of a and b
function gcd(a, b)
  while a ~= 0 do
    a,b = (b%a),a
  end
  return b
end

function first_difference_string(a,b)
    -- Determines where the mismatch in two strings is
    -- Returns the mismatch point or nil is there isn't one
    local mismatch 
    for i=1,string.len(a) do
        if i>string.len(b) or string.sub(a,1,i)~=string.sub(b,1,i) then
            mismatch = i
            break
        end    
    end
    return mismatch
end


-- set a field of the whole table
function set_property(t, key, value)
    for i,v in pairs(t) do
        v[key] = value
    end
end

function copy_array(orig)
    -- copy an array (only integer keys are copied)
    local copy = {}
    for i=1,#orig do
        copy[i] = orig[i]
    end
    return copy
end

function copy_table(orig)
    -- shallow copy a table (does not copy the contents)
    local copy = {}
    for i,v in pairs(orig) do
        copy[i] = v
    end
    return copy   
end


-- copy a table completely (excluding metatables)
-- don't copy keys, just values
function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[orig_key] = deepcopy(orig_value)
        end        
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end


function time_execution(fn, times)
    -- time the execution of a function
    times = times or 1
    local start_t = os.clock()
    for i=1,times do
        fn()
    end
    local end_t = os.clock() - start_t    
    return end_t/times
end

-- Right trim a string
function rtrim(s)
  local n = #s
  while n > 0 and s:find("^%s", n) do n = n - 1 end
  return s:sub(1, n)
end

-- Print anything - including nested tables
function verbose_table_print (tt, indent, done)
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
    for key, value in pairs (tt) do
      io.write(string.rep (" ", indent)) -- indent it
      if type (value) == "table" and not done [value] then
        done [value] = true
        io.write(string.format("[%s] => table\n", tostring (key)));
        io.write(string.rep (" ", indent+4)) -- indent it
        io.write("(\n");
        table_print (value, indent + 7, done)
        io.write(string.rep (" ", indent+4)) -- indent it
        io.write(")\n");
      else
        io.write(string.format("[%s] => %s\n",
            tostring (key), tostring(value)))
      end
    end
  else
    io.write(tt .. "\n")
  end
end

-- Print anything - including nested tables
function table_print (tt, indent, done)
  if tt==nil then
    io.write('nil\n')
    return
  end
  done = done or {}
  indent = indent or 0
  if type(tt) == "table" then
    for key, value in pairs (tt) do
      io.write(string.rep (" ", indent)) -- indent it
      if type (value) == "table" and not done [value] then
        done [value] = true
        io.write(string.format("%s = \n", tostring (key)));
        io.write(string.rep (" ", indent+4)) -- indent it
        io.write("{\n");
        table_print (value, indent + 7, done)
        io.write(string.rep (" ", indent+4)) -- indent it
        io.write("}\n");
      else
        io.write(string.format("%s=%s\n",
            tostring (key), tostring(value)))
      end
    end
  else
    io.write(tt .. "\n")
  end
end


-- Print anything - including nested tables
function table_str (tt, indent, done)
  if tt==nil then
    return('nil')    
  end
  local result = {}
  local done = done or {}
  local indent = indent or 0
  if type(tt) == "table" then
    table.insert(result, '{')
    
    -- enforce consistent key ordering
    local keys = {}
    for i,v in pairs(tt) do
        table.insert(keys, i)
    end
    table.sort(keys)
    
    
    for i,key in ipairs (keys) do            
      local value = tt[key]
      if type (value) == "table" and not done [value] then
        done [value] = true        
        table.insert(result, string.format("%s=%s,", tostring (key), table_str(value,0,done)))        
      else
        table.insert(result, string.format("%s=%s,", tostring (key), tostring(value)))
      end      
    end
    table.insert(result, '}')
    return table.concat(result)
  else
    return tostring(value)
  end
end

function invert_table(t)
    -- invert a table so that values map to keys
    local n = {}
    for i,v in pairs(t) do
        n[v] = i
    end
    return n
end


function append_table(a, b)
    -- Append b to a. Operates in-place, and returns a copy
    -- of the modified array
    for i,v in ipairs(b) do    
        table.insert(a,v)
    end
    return a
end

-- Compatibility: Lua-5.1
function split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
	 table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end

function is_in(str, tab)
-- return true if str is in the given table of strings
    for i,v in ipairs(tab) do
        if str==v then
            return true
        end
    end
    return false
end


function warn(message)
-- print a warning message
    print(message)
end

function find_first_match(t, match)
    -- Find the first element of t, where all of the given field=value pairs match
    -- or nil, if no match
    local is_match
   for i,v in ipairs(t) do
     is_match = true
     -- check all fields of match
     for j,n in pairs(match) do
        if not v[j] or v[j]~=n then
            is_match = false
        end
     end
     -- if we matched, we found it!
     if is_match then
        return i
    end
   end
   return nil
end

function swap(t, a, b)
    -- swap the indices of t so that t[a] = t[b] and t[b] = t[a]
    local ta, tb = t[a], t[b]
    t[b] = ta
    t[a] = tb
end