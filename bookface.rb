#!/usr/bin/ruby

# program: bookface.rb
# usage:   ruby bookface.rb [options]

gem 'rmagick', '2.13.2'
gem 'prawn', '0.15.0'

require 'optparse'
require 'fileutils'
require 'json'
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

    opts.on('-c', '--count count', Integer, 'Count (multiple of 100)') do |count|
      options[:count] = count;
    end

   opts.on( '-h', '--help', 'Displays this message' ) do
     puts opts
     exit
   end
end

parser.parse!(ARGV)

if options[:count] == nil
  print 'Enter number of faces (multiple of 100): '
  options[:count] = gets.chomp
end

# create temporary directory unless it already exists
if File.directory?(TMP_DIR_NAME)
  puts "Temporary directory '#{TMP_DIR_NAME}' exists. Please remove and try again"
  exit
else
  FileUtils.mkdir(TMP_DIR_NAME)
end

# class to hold page make method
class BookFacePages

  def self.make_page(page_number, image_dir, export_dir)

    FileUtils.cd(image_dir) do

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

    end

  end

  def self.download_profile(image_dir, profile_id)
    # download only real profile images for id
    # returns true if an image has been downloaded and false if not
    FileUtils.cd(image_dir) do
      image_json = JSON.load(open(
        "http://graph.facebook.com/#{profile_id}/picture?redirect=0&height=100&type=normal&width=100"
      ))
      if image_json["data"]["is_silhouette"] == false
        File.open("#{profile_id}.png", 'wb') do |fo|
          fo.write open(image_json["data"]["url"]).read
        end
        return true
      else
        return false
      end
    end
  end

end

# START
photo_total = options[:count] # amount of profile photos required
profile_id = FACEBOOK_START_ID # holds current photo
photos_downloaded = 0 # number of square profile photos downloaded
batch_count = 0 # holds number downloaded for current batch
batch_limit = PHOTOS_PER_PAGE # amount to be downloaded for each batch
page_number = 1 # starting page number

# make tmp dir for each batch of photos
image_dir = FileUtils.mkdir(TMP_DIR_NAME + "/batch")[0]
# make tmp dir for each batch pdf export
export_dir = FileUtils.mkdir(TMP_DIR_NAME + "/exports")[0]

# main loop
while photos_downloaded < photo_total

  puts "Downloading pictures for page #{page_number}"

  while batch_count < batch_limit
    # get square profile photo
    downloaded = BookFacePages.download_profile(image_dir, profile_id)
    if downloaded
      batch_count += 1
      photos_downloaded += 1
    end
    profile_id += 1
  end

  # we now have reached a batch count so make a page
  puts "Making page #{page_number}"
  BookFacePages.make_page(page_number, image_dir, export_dir)
  # move montage jpg to exports
  FileUtils.move("#{image_dir}/page-#{page_number}.jpg", export_dir)
  # delete all files from image_dir
  FileUtils.rm_rf("#{image_dir}/.", secure: true)

  # start next batch
  batch_count = 0
  page_number += 1

end

# generate pdf from saved images
page_count = page_number-1 # offset pages to be actual number

Prawn::Document.generate("bookface.pdf") do |pdf|
  1.upto(page_count) do |i|
    pdf.image "#{export_dir}/page-#{i}.jpg", :position => :center, :vposition => :center, :width => 500
    if i != page_count
      pdf.start_new_page
    end
  end
end

# cleanup - remove temporary directory
FileUtils.rm_rf TMP_DIR_NAME
