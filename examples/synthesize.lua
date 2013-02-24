-- Really simple and ineffecient synthesizer for ABC tunes.
-- "Plays" the tunes on a tin whistle.
-- Synthesizes only the first tune in a song file into a WAV file.
-- Very primitive sounds and no polyphony.
--
-- There's no good reason to use Lua for this -- it's just a demo.

require "abclua"

function write_dword(file, value)
    -- write little endian dword to a binary file
    file:write(string.char(math.floor(value%256)))
    file:write(string.char(math.floor((value/256)%256)))
    file:write(string.char(math.floor((value/65536)%256)))
    file:write(string.char(math.floor((value/16777216)%256)))
end


function write_word(file, value)
    -- write little endian word to a binary file
    file:write(string.char(math.floor(value%256)))
    file:write(string.char(math.floor((value/256)%256)))
end

function write_wav_header(file, samples, sr)
    -- write a wav header containing a block
    -- of <samples> 8 bit unsigned values
    local chunk_size = 36 + samples
    file:write('RIFF')
    write_dword(file, chunk_size)
    file:write('WAVE')
    file:write('fmt ')
    write_dword(file, 16)
    write_word(file, 1) -- PCM
    write_word(file, 1) -- one channel
    write_dword(file, sr) -- sample rate
    write_dword(file, sr) -- byte rate
    write_word(file, 1) -- block align
    write_word(file, 8)
    file:write('data')
    write_dword(file, samples) -- data block length
end

function synthesize(fname)
    local wav_name = string.lower(fname):gsub('.abc', '.wav')
    local songs = parse_abc_file(fname)    
    local song = songs[1]
    local notes = songs[1].voices['default'].stream 
    local meter = songs[1].voices['default'].context.meter.num
    local wav = io.open(wav_name, 'wb')
    local duration = duration_stream(notes)
    local sr = 22100
    local sample_time = 1e6/sr
    local samples = math.floor(sr*duration/1e6)
    write_wav_header(wav, samples, sr)
    local t = 0
    local sample_duration
    local level, velocity, amp, vamp, mamp, decay, w, vib
    decay = 3000
    for i,v in ipairs(notes) do
        if v.event=='note' or v.event=='rest' then
            if t<v.t then
                --advance pointer, writing out 0 values 
                wav:write(string.rep(string.char(127), ((v.t-t)/sample_time)))
                t = v.t
            end                       
            -- write the note out
            sample_duration = v.duration / sample_time
            
            -- whistle tune: up one octave and slightly flat high notes
            if v.note.play_pitch then
                f = 2*midi_to_frequency(v.note.play_pitch*0.999)/sr
            else
                f = 0 -- rest
            end
            
            -- reset envelope
            amp = 0.01
            vamp = 0.01
            mamp = 0.01
            
            -- emphasise first beat, and strong beats in the meter
            if v.note.play_bar_time==0 then 
                velocity = 1.0 
                sample_duration = sample_duration * 1.05
            else    
                t = meter*v.note.play_bar_time
                if math.abs(t-math.floor(t))<0.01 then
                    velocity = 0.85
                    sample_duration = sample_duration * 0.95
                else
                    velocity = 0.7
                    sample_duration = sample_duration * 0.9
                end
            end
            
            local vsquared = velocity * velocity
            -- simulate hitting the note slightly flat to begin 
            local fr = 0.9*f
            -- there's no point in being efficient here: Lua is not
            -- the right choice anyway!
            for i=1,sample_duration do  
                -- compute simple fm oscillator with vibrato
                vib = math.sin(i/1500)*vamp
                value =  math.sin(i*fr*2*math.pi+vib+math.sin(i*fr*4*math.pi)*0.5*vsquared*(1-mamp))*amp
                fr = 0.997*fr + 0.003*f
                -- update envelope
                value = (value/2 * 127) + 128
                if vamp<1.8 then vamp = vamp * 1.0008 end
                if mamp<1 then mamp = mamp * 1.006 end
             
                if sample_duration-i<decay then
                    amp = amp * 0.999
                else
                    if amp<velocity then amp=amp*(1+0.01*vsquared) end                
                end
                wav:write(string.char(value))                
            end     
            t = v.t+sample_duration*sample_time
        end
    end
    wav:close()
end

if #arg~=1 then
    print("Usage: synthesize.lua <file.abc>")
else
    synthesize(arg[1])
end

