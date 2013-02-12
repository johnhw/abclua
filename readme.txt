ABCLua 0.1

Requires: 
    Lua 5.2     http://www.lua.org
    LPeg        http://www.inf.puc-rio.br/~roberto/lpeg/
Optional:    
    MIDI.lua    http://www.pjb.com.au/comp/lua/MIDI.html

DESCRIPTION
    Simple ABC parsing for Lua. This library can read a reasonable
    subset of ABC 2.1 and generate tables representing the song structure.

    It can transform ABC source into a token stream, transform a token 
    stream into an ABC string, transform a token stream into an event stream
    (with timing, repeats expanded etc.), and event streams into MIDI.
    
USAGE
    You can use this file just by requiring abclua_all.lua, which has all the
    functions in one single file as a convenience.
    
TEST/EXAMPLES
    tests/reproduce_abc.lua takes a filename as an argument, and creates a file called
    <filename>_reproduced.abc which is the result of parsing the given file and
    writing out the ABC representation of the token stream. It should leave files
    basically unchanged (but see the LIMITIATIONS section for processing of macros
    and abc-include)
    
    tests/abc_to_midi.lua converts an ABC file to a simple MIDI file. It should render
    most files correctly.
            

DEVELOPMENT
    For developers, the individual sub-components are in separate .lua files in src. 
    Require "abclua" instead of "abclua_all" to load the files with these subcomponents.

    If you want to modify the source and still use abclua_all.lua, modify the files in 
    src and rebuild abclua_all.lua by running "lua make_abclua.lua". 
    Do *not* edit abclua_all.lua directly!

EXAMPLE
    require "abclua_all"
    -- Assuming you have Peter J. Billam's MIDI.lua
    tunes = abclua.parse_abc_file('skye.abc')
    opus = abclua.make_midi(tunes[1], 'skye.mid')   

SUPPORTED FEATURES
    
    ABCLua supports most of the 2.1 standard; tested features include:
    
    + Complex meters M:(1+4+2)/8
    + Full key definitions K:C locrian ^c _g alto t=-2
    + Multi-tune songbooks
    + Tuplets (3 abc (5:2:7 abcdefg
    + Aligned lyrics    
    + Grace notes, decorations {cf}!fermata!~G
    + Slurs and chords (ABC) and [Ceg]
    + Named chords "Cm7"
    + Repeats (with variable counts, such as |::: :::|) and variant endings |: abc :|1 def |2 fed ||
    + Parts with variant endings 
    + Multi-voice songs (V:v1)
    + Voice overlay with &
    + Macros, user macros and transposing macros
    + abc-include to include files

    See tests/test_abc.lua for examples of these in use.
    
LIMITATIONS

    transposing macros
        Transposing macros are supported, but only work with notes without explicit octave
        symbols. For example:
        
            m:~n2={op}n2
            A2 b2 c'2    
        produces
            {Bc}A2 {c'd'}b2 c'2 
            
        because the macro does not match n'2.        
        

    Expansion:
    
     macros
        macros are expanded as they are read, so they will appear in the token stream expanded. The 
        macro definitions are stripped from the song. So reproduce_abc.lua will turn        
            m:a=g
            abc        
        into
            gbc
        
    abc-include
        I:abc-include file.abc
        will include the file.abc. But note that the instruction 
        field will not appear in the token stream -- instead the contents of "file.abc" 
        will appear in place. If a file is included more than once inside a song, all 
        includes except the first are ignored. This eliminates recursive includes but
        might have confounding effects.
        
        
    Macro expansion and abc-include can be disabled by setting no_expand=true in the options passed to 
    parse_abc_multisong(), parse_abc_file() or parse_abc_fragment(). Example
    parse_abc_file('macros.abc', {no_expand=false}) -- parses the file with macros enabled
    parse_abc_file('macros.abc', {no_expand=true}) -- parses the file with macros disabled, macro fields are passed through


LICENSE    
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
     
