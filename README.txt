== README

bookface.rb - a script to generate a PDF file of a given number of Facebook
profile photos in sequential order. Starting with Mark Zuckerberg.

=== Ruby version

Tested on version 2.0.0p247 on OSX Mavericks.

=== System dependencies

The script depends on ImageMagick

A simple installer for Mac is available here: http://cactuslab.com/imagemagick/
Or use Homebrew: http://brew.sh/

More information for other platforms is available here: http://www.imagemagick.org/

Required gems are also documented in the script.

=== HowTo

Pass in count of number of profile photos to download

Example: ruby bookface.rb -c 100

Note all counts should be multiples of 100, any numbers will be rounded up to
a multiple of 100
