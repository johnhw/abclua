set ABCLUA_VERSION=0.2.2
del /Q /S dist
mkdir dist
mkdir dist\src
mkdir dist\docs
mkdir dist\tests
mkdir dist\examples
mkdir dist\midi
mkdir dist\out

copy src\*.* dist\src\*.*
cd docs
call make_docs.bat
cd ..
copy readme.txt dist
copy abclua.lua dist
copy abc_to_midi.lua dist
copy test_abclua.lua dist
copy docs\abclua.txt dist\docs\abclua.txt
copy docs\abclua.html dist\docs\abclua.html
copy docs\abcluamidi.txt dist\docs\abcluamidi.txt
copy docs\abcluamidi.html dist\docs\abcluamidi.html
copy docs\buttondown.css dist\docs\buttondown.css
copy tests\*.lua dist\tests\*.lua
copy tests\*.abc dist\tests\*.abc
lua make_abclua.lua
copy abclua_all.lua dist\abclua_all_original.lua
copy make_abclua.lua dist\make_abclua.lua
xcopy /E midi\*.* dist\midi
lua squish --minify --gzip
copy abclua_small.lua.gzipped dist\abclua_all.lua
cd dist
zip -r abclua-%ABCLUA_VERSION%.zip .
cd ..
move dist\abclua-%ABCLUA_VERSION%.zip .