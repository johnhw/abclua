## Description
Simple ABC parsing for Lua. This library can read a reasonable
subset of ABC 2.1 and generate Lua tables representing the song structure.

It can transform ABC source into a token stream, transform a token 
stream into an ABC string, transform a token stream into an event stream
(with timing, repeats expanded etc.), and transform these event streams into MIDI.

### Requires: 
* [Lua 5.1+](http://www.lua.org)
* [LPeg](http://www.inf.puc-rio.br/~roberto/lpeg)

### Optional:    
* [MIDI.lua](http://www.pjb.com.au/comp/lua/MIDI.html)

### Demo
    lua abc_to_midi.lua <file.abc>

See docs/abclua.txt for full documentation.

## LICENSE    
    Licensened under the BSD 3 clause license.
        
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
     
