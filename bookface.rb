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

      # generate pdf in pdf folder with page id
      Prawn::Document.generate("#{page_number}.pdf") do |pdf|
        # TODO - draw images - I think back to montage
        # pdf.image = 'path to image'
        pdf.image "page-#{page_number}.jpg", :position => :center, :width => 500
      end

    end

    # TODO - move pdf into export_dir

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
# new logic
# count up facebook ids indefinitely

# when we have 100 saved images pass directory to make page
# make montage, save as pdf
# return to main loop and continue until we hit count


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
  puts 'in main while'
  while batch_count < batch_limit
    puts 'batch count and limit'
    puts batch_count
    puts batch_limit
    downloaded = BookFacePages.download_profile(image_dir, profile_id)
    if downloaded
      batch_count += 1
      photos_downloaded += 1
    end
    profile_id += 1
  end

  # we now have reached a batch count so make a page
  BookFacePages.make_page(page_number, image_dir, export_dir)
  # move pdf to exports
  FileUtils.move("#{image_dir}/#{page_number}.pdf", export_dir)
  # delete all files from image_dir
  FileUtils.rm_rf("#{image_dir}/.", secure: true)

  # update to next batch
  batch_count = 0
  page_number += 1

end

class PdfMerger

  def merge(pdf_paths, destination)

    first_pdf_path = pdf_paths.delete_at(0)

    Prawn::Document.generate(destination, :template => first_pdf_path) do |pdf|

      pdf_paths.each do |pdf_path|
        pdf.go_to_page(pdf.page_count)

        template_page_count = count_pdf_pages(pdf_path)
        (1..template_page_count).each do |template_page_number|
          pdf.start_new_page(:template => pdf_path, :template_page => template_page_number)
        end
      end

    end

  end

  private

  def count_pdf_pages(pdf_file_path)
    pdf = Prawn::Document.new(:template => pdf_file_path)
    pdf.page_count
  end

end

# now munge all pages in exports together with prawn using pdf directory
# output to same dir as script not TMP_DIR_NAME
FileUtils.cd(export_dir) do
  pdf_file_paths = Dir.glob("*.pdf").sort_by(&:to_i)
  puts 'paths'
  puts pdf_file_paths
  m = PdfMerger.new
  m.merge(pdf_file_paths, export_dir)
end

# cleanup - remove temporary directory
# FileUtils.rm_rf TMP_DIR_NAME


