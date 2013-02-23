require "abclua"
require "profiler"

function test_file()
    local songs = abclua.parse_abc_file('tests/p_hardy.abc')
        
end

profiler = newProfiler()
profiler:start()
test_file()
profiler:stop()
local outfile = io.open( "profile.txt", "w+" )
profiler:report( outfile )
outfile:close()

