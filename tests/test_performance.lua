--- Test the performance of the various stages
require "abclua"

function test_performance(test_file)
    local f = io.open(test_file, 'r')
    local contents = f:read('*a')
    f:close()
    
    -- test split time
    local split_time = time_execution(function () songbook_block_iterator(contents) end, 100)
    
    -- test parse time
    local parse_time = 0
    local precompile_time = 0
    local compile_time = 0
    local n = 0
    local times = 1
    local parsed, original_parsed
    for i=1, times do
        for song_str in songbook_block_iterator(contents) do
            parse_time = parse_time + time_execution(function () parsed=parse_abc(song_str) end)
            original_parsed = deepcopy(parsed)
            precompile_time = precompile_time + time_execution(function () precompile_token_stream(parsed.token_stream) end)
            compile_time = compile_time + time_execution(function () compile_token_stream(original_parsed) end)
        end
    end
    
    print("Time to split file: "..split_time) 
    print("Time to parse file: "..parse_time/times) 
    print("Time to precompile file: "..precompile_time/times) 
    print("Time to compile file: "..compile_time/times) 
end

test_performance('tests/p_hardy.abc')