del /Q /S dist
mkdir dist
mkdir dist\src
mkdir dist\docs
mkdir dist\tests
mkdir dist\midi
mkdir dist\out

copy src\*.* dist\src\*.*
copy docs\abclua.txt dist\docs\abclua.txt
copy docs\abclua.html dist\docs\abclua.html
copy docs\buttondown.css dist\docs\buttondown.css
copy tests\*.lua dist\tests\*.lua
copy tests\*.abc dist\tests\*.abc
lua make_abclua.lua
copy abclua_all.lua dist\abclua_all.lua
copy make_abclua.lua dist\make_abclua.lua
xcopy /E midi\*.* dist\midi
