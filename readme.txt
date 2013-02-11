ABC Lua 0.1

Simple ABC parsing for Lua. This library can read a reasonable
subset of ABC and generate tables representing the song structure.

Requires: 
    Lua 5.2     http://www.lua.org
    LPeg        http://www.inf.puc-rio.br/~roberto/lpeg/
Optional:    
    MIDI.lua    http://www.pjb.com.au/comp/lua/MIDI.html

NOTE: You can use this file just by requiring abclua_all.lua. For developers, 
the individual sub-components are in separate lua files in src.

If you want to modify the source, modify the files in src and rebuild abclua.lua by
running "lua make_abclua.lua". Do *not* edit abclua.lua directly!

Example:

require "abclua_all"
require "MIDI" -- Peter J. Billam's MIDI.lua
tunes = abclua.parse_abc_file('skye.abc')
opus = abclua.song_to_opus(tunes[1])
midi.opus2midi(opus)


License: BSD 3 clause license
    
* Copyright (c) 2013, John Williamson
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
*     * Redistributions of source code must retain the above copyright
*       notice, this list of conditions and the following disclaimer.
*     * Redistributions in binary form must reproduce the above copyright
*       notice, this list of conditions and the following disclaimer in the
*       documentation and/or other materials provided with the distribution.
*     * Neither the name of the <organization> nor the
*       names of its contributors may be used to endorse or promote products
*       derived from this software without specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY <copyright holder> ``AS IS'' AND ANY
* EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL <copyright holder> BE LIABLE FOR ANY
* DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
* LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
* ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.**
 
