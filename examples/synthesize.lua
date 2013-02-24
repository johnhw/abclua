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
    local chunk_size = 36 + samples*2
    file:write('RIFF')
    write_dword(file, chunk_size)
    file:write('WAVE')
    file:write('fmt ')
    write_dword(file, 16)
    write_word(file, 1) -- PCM
    write_word(file, 1) -- one channel
    write_dword(file, sr) -- sample rate
    write_dword(file, sr*2) -- byte rate
    write_word(file, 1) -- block align
    write_word(file, 16)
    file:write('data')
    write_dword(file, samples*2) -- data block length
end

function synthesize_note(wav, sr, duration, pitch, beat_time, tempo)
    local f, fr, amp, vamp, t, velocity, attack
    local decay = 500
    
        if pitch then
            f = 2*midi_to_frequency(pitch)/sr
             -- reset envelope
            amp, vamp = 0.01, 0.01
        else
            f = 0 -- rest
            amp, vamp = 0, 0 
        end
        
        -- dodgy swing
        if math.floor(beat_time)%2 == 0 then
            duration = duration * 1.05
        else
            duration = duration * 0.95
        end
        
        -- emphasise first beat, and strong beats in the meter
        if beat_time==0 then 
            velocity = 1.0
        else    
            -- emphasize "on beat" notes
            if math.abs(beat_time-math.floor(beat_time))<0.01 then
                velocity = 0.7
                -- duration = duration * 0.95
            else
                velocity = 0.5
                -- duration = duration * 0.9
            end
        end
        
        local vsquared = velocity * velocity
        -- simulate hitting the note slightly flat to begin 
        local fr = 0.94*f
        attack = true
            
        -- there's no point in being efficient here: Lua is not
        -- the right choice anyway!
        for i=1,duration do  
            -- compute simple fm oscillator with vibrato
            vib = math.sin(i/1100)*vamp 
            value =  math.sin(i*fr*2*math.pi*(1+vib/1400)) * amp * (1+vib/3) 
            value = (value/2 * 32767) 
            
            if value<0 then value = 65536+value end
            
            -- update envelope
            fr = 0.998*fr + 0.002*f
            if vamp<1.8 then vamp = vamp * 1.0004 end
         
            if duration-i<decay then
                amp = amp * 0.97
            else
                if attack and amp<velocity then amp=amp*(1+0.015*vsquared) else attack = false end
                if not attack and amp>0.6 then amp=amp*0.9997 end
            end
            wav:write(string.char(math.floor(value%256)))
            wav:write(string.char(math.floor((value/256)%256)))
        end     
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
    local tempo = songs[1].voices['default'].context.tempo.tempo_rate
    local sample_time = 1e6/sr
    local samples = math.floor(sr*duration/1e6)
    local t = 0
    local sample_duration
    local velocity, amp, vamp, decay, vib
    
    write_wav_header(wav, samples, sr)
    decay = 300
    for i,v in ipairs(notes) do
        if v.event=='note' or v.event=='rest' then
            -- if t<v.t then
                -- advance pointer, writing out 0 values 
                -- for i=1,(v.t-t)/sample_time do
                    -- write_word(wav, 0)
                -- end
                -- t = v.t
            -- end                       
            -- write the note out
            sample_duration = v.duration / sample_time
  
            synthesize_note(wav, sr, sample_duration, v.note.play_pitch, v.note.play_bar_time*meter, tempo)
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

