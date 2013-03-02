print()
print("Testing parser/emitter")
require "tests/test_parsing"
print()
print("Testing transposing")
require "tests/test_transpose"
print("Testing tools")
require "tests/test_tools"
print()
print("Testing durations")
require "tests/test_durations"
print()
print("Testing chords")
require "tests/test_chords"
print()
print("Testing pitches")
require "tests/test_pitches"
print()
print("Testing symbol lines")
require "tests/test_symbols"
print()
print("Testing lyrics")
require "tests/test_lyrics"
print()
print("Testing repeats")
require "tests/test_repeats"
print()
print("Testing timing")
require "tests/test_timing"
print()
print "Running additional tests"
require "tests/test_abc_silent"
print()
print "Creating test MIDI files..."
require "midi/test_midi"
print()
print "Testing all keys"
require "tests/test_all_keys"