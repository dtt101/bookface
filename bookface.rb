#!/usr/bin/ruby

# program: bookface.rb
# usage:   ruby bookface.rb [options]

# Use the Facebook API to download square profile photos of the first 100 Facebook users.
# Mark Zuckerberg should be the first one.
# Combine the photos into a single montage of 100 images laid out in a 10x10 grid
# Generate a one-page PDF with the finished image in the centre of the page
# Output should be a single PDF

# depends on imagemagick: http://cactuslab.com/imagemagick/
# gem install RMagick and prawn

gem 'rmagick', '2.13.2'
gem 'prawn', '0.15.0'

require 'optparse'
require 'fileutils'
require 'open-uri'
require 'RMagick'
require 'prawn'

# we are using the open graph to get profile photos
# the first picture is Mark Zuckerberg, with the ID of 4
FACEBOOK_START_ID = 4
# number of photos per page
PHOTOS_PER_PAGE = 100
# temporary directory name
TMP_DIR_NAME = 'tmp'

# parse options for number of faces to show
options = {:count => nil}

parser = OptionParser.new do |opts|
    opts.banner = 'cat <options> <file>'
    opts.separator ''

    opts.on('-c', '--count count', Integer, 'Count') do |count|
      options[:count] = count;
    end

   opts.on( '-h', '--help', 'Displays this message' ) do
     puts opts
     exit
   end
end

parser.parse!(ARGV)

if options[:count] == nil
  print 'Enter number of faces: '
  options[:count] = gets.chomp
end


# new logic
# count up facebook ids indefinitely
# for each id get profile data: http://graph.facebook.com/8/picture?redirect=0&height=100&type=normal&width=100
# {
#    "data": {
#       "url": "http://static.ak.fbcdn.net/rsrc.php/v2/yL/r/HsTZSDw4avx.gif",
#       "is_silhouette": true
#    }
# }
# {
#    "data": {
#       "url": "http://profile.ak.fbcdn.net/hprofile-ak-frc3/t1/c14.4.153.153/s100x100/1939620_10101266232851011_437577509_a.jpg",
#       "width": 100,
#       "height": 100,
#       "is_silhouette": false
#    }
# }
# if is not a silhouette, save image
# when we have 100 saved images pass directory to make page
# make montage, save as pdf
# return to main loop and continue until we hit count

# create temporary directory unless it already exists
if File.directory?(TMP_DIR_NAME)
  puts "Temporary directory '#{TMP_DIR_NAME}' exists. Please remove and try again"
  exit
else
  FileUtils.mkdir(TMP_DIR_NAME)
end

# class to hold page make method
class BookFacePages

  def self.make_page(page_number, page_start_id, page_end_id)
    # create directory to store this pages images
    page_dir = FileUtils.mkdir(TMP_DIR_NAME + "/#{page_number}")[0]

    FileUtils.cd(page_dir) do

      page_start_id.upto(page_end_id) do |id|

        # download images for each id
        File.open("#{id}.png", 'wb') do |fo|
          fo.write open("http://graph.facebook.com/#{id}/picture?height=100&type=normal&width=100").read
        end
      end

      # grab images as sorted numerical array
      profile_images = Dir.glob("*.*").sort_by(&:to_i)
      # create ImageList object from filenames
      images_list = Magick::ImageList.new(*profile_images)

      # create montage image and save
      montage = images_list.montage {
        rows = 10
        self.filename = "demo"
        self.geometry = "100x100+0+0"
        self.tile = "10x10"
      }
      montage.write("page-#{page_number}.jpg")

      # generate pdf in pdf folder with page id
      Prawn::Document.generate("#{page_number}.pdf") do |pdf|
        # TODO - draw images - I think back to montage
        # pdf.image = 'path to image'
        pdf.image "page-#{page_number}.jpg", :position => :center, :width => 500
      end

    end

    # TODO - move pdf into a page_images folder

  end

  self.
end

# START

# set number of photos from input
photo_total = options[:count]
# set number of pages, ensuring we round up
page_total = photo_total.fdiv(PHOTOS_PER_PAGE).ceil

# set photo profile ids to control loop
page_start_id = FACEBOOK_START_ID # holds current photo
page_end_id = page_start_id + (PHOTOS_PER_PAGE - 1) # set first page end ID
end_id = photo_total + FACEBOOK_START_ID # final ID to download

puts "page_total: #{page_total}"

# loop round each page
page_total.times do |page_number|

  # test if we are at the final page and adjust loop variable
  if page_end_id >= end_id
    page_end_id = end_id
  end

  # make the page - start at id, end at id
  BookFacePages.make_page(page_number, page_start_id, page_end_id)

  puts "in loop"
  puts "page_number #{page_number}"
  puts "page_start_id #{page_start_id}"
  puts "page_end_id #{page_end_id}"

  # increment start and end ids by total per page for next run
  page_start_id += PHOTOS_PER_PAGE
  page_end_id += PHOTOS_PER_PAGE

end

# now munge all pages together with prawn using pdf directory
# output to same dir as script not TMP_DIR_NAME


# cleanup - remove temporary directory
#FileUtils.rm_rf TMP_DIR_NAME


