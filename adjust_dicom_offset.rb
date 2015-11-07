require 'pp'
require 'highline/import'

require './dicom_lib'

def prompt_for(prompt,valid_options=nil,options={})
  options = {
    exit_value:"0",
    split_value:" - ",
    ignore_case:true,
    show_options:false
  }.merge options
  prompt = "#{prompt}#{options[:show_options] ? " (#{valid_options.join("/")})" : ""}: "
  value = ask prompt
  value = value.split(options[:split_value])[0] if value.include? options[:split_value]
  while true
    exit if value == options[:exit_value]
    break if valid_options.nil?
    break if valid_options.include? value
    break if options[:ignore_case] and valid_options.map(&:downcase).include? value.downcase
    puts "Invalid option: #{value}"
    value = ask prompt
  end
  value
end



print "\nLoading DICOM files."; STDOUT.flush

filename = ARGV[0].nil? ? "DICOM" : ARGV[0]

begin
  d = DicomLib.new(filename)
rescue
  puts "\nError loading files. Ensure the folder contains DICOM files only"
  exit
end

d.print_dicom_summary

puts ""
series_id = prompt_for("Series ID to view (0 to quit)",d.series_ids)


puts "\nDICOM Files with position information:"
d.print_dicom_series series_id

puts ""
axis = prompt_for("Axis to shift (0 to quit)",["X","Y","Z"], show_options:true)
delta = prompt_for("Amount to shift(in mm) (0 to quit)").to_f

d.apply_offset(series_id,axis,delta)
puts "\nMODIFIED position information:"
d.print_dicom_series series_id

puts ""
save = prompt_for("Save changes?",["Y","N"], show_options:true)

d.save_series(series_id) if save.downcase == "y"
