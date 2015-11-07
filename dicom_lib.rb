require 'dicom'
require 'highline/import'

DICOM.logger = Logger.new('dicom.log')

class DicomLib
  def initialize(path,num_files=-1)
    patients = {}
    series = {}
    loaded_files = 0
    Dir.foreach(path) do |dicom_file|
      next if dicom_file == '.' or dicom_file == '..'
      next if num_files != -1 and loaded_files >= num_files
      print "."; STDOUT.flush

      dcm = DICOM::DObject.read("#{path}/#{dicom_file}")
      # puts dcm["0010,0010"].inspect #patient name
      # puts dcm["0010,0020"].inspect #patient id
      # puts dcm["0010,0030"].inspect #patient birthday
      # puts dcm["0010,0040"].inspect #patient sex
      #
      # puts dcm["0020,000D"].inspect #study UID
      #
      # puts dcm["0020,000E"].inspect #series UID
      # puts dcm["0020,0011"].inspect #series number
      #
      # puts dcm["0020,0013"].inspect #instance number
      #
      # puts dcm["0020,0032"].inspect

      patients[dcm["0010,0020"].value] ||= {}
      patients[dcm["0010,0020"].value].merge! dcm["0010,0010"].to_hash
      patients[dcm["0010,0020"].value].merge! dcm["0010,0020"].to_hash
      patients[dcm["0010,0020"].value].merge! dcm["0010,0030"].to_hash
      patients[dcm["0010,0020"].value].merge! dcm["0010,0040"].to_hash

      patients[dcm["0010,0020"].value]["studies"] ||= {}
      patients[dcm["0010,0020"].value]["studies"][dcm["0020,000D"].value] ||= {}
      patients[dcm["0010,0020"].value]["studies"][dcm["0020,000D"].value].merge! dcm["0008,1030"].to_hash
      patients[dcm["0010,0020"].value]["studies"][dcm["0020,000D"].value]["series"] ||= {}
      patients[dcm["0010,0020"].value]["studies"][dcm["0020,000D"].value]["series"][dcm["0020,000E"].value]||= {}
      patients[dcm["0010,0020"].value]["studies"][dcm["0020,000D"].value]["series"][dcm["0020,000E"].value].merge! dcm["0020,000E"].to_hash
      patients[dcm["0010,0020"].value]["studies"][dcm["0020,000D"].value]["series"][dcm["0020,000E"].value].merge! dcm["0020,0011"].to_hash
      patients[dcm["0010,0020"].value]["studies"][dcm["0020,000D"].value]["series"][dcm["0020,000E"].value].merge! dcm["0008,103E"].to_hash
      patients[dcm["0010,0020"].value]["studies"][dcm["0020,000D"].value]["series"][dcm["0020,000E"].value]["instances"] ||= {}
      patients[dcm["0010,0020"].value]["studies"][dcm["0020,000D"].value]["series"][dcm["0020,000E"].value]["instances"][dcm["0020,0013"].value] ||={}
      patients[dcm["0010,0020"].value]["studies"][dcm["0020,000D"].value]["series"][dcm["0020,000E"].value]["instances"][dcm["0020,0013"].value].merge! dcm["0020,0013"].to_hash
      patients[dcm["0010,0020"].value]["studies"][dcm["0020,000D"].value]["series"][dcm["0020,000E"].value]["instances"][dcm["0020,0013"].value].merge! dcm["0020,0032"].to_hash if dcm["0020,0032"]
      patients[dcm["0010,0020"].value]["studies"][dcm["0020,000D"].value]["series"][dcm["0020,000E"].value]["instances"][dcm["0020,0013"].value].merge!({"file" => "#{path}/#{dicom_file}"})
      patients[dcm["0010,0020"].value]["studies"][dcm["0020,000D"].value]["series"][dcm["0020,000E"].value]["instances"][dcm["0020,0013"].value].merge!({"fileref" => dcm})

      series.merge!  patients[dcm["0010,0020"].value]["studies"][dcm["0020,000D"].value]["series"]
    #  patients[dcm["0010,0020"].value]["studies"][dcm["0020,000D"].value]["series"][dcm["0020,000E"].value]["instances"][dcm["0020,0013"].value].merge! dcm["0018,0024"].to_hash
      loaded_files += 1
    end
    puts "\nDone loading #{loaded_files} DICOM files."
    puts ""
    @dicom_data = {patients:patients,series:series}
  end

  def print_dicom_summary
    puts "Patients:"
    puts "-" * 80
    patient_names =  @dicom_data[:patients].map {|k,p| "#{k} - #{p["Patient's Name"]}" }
    patient_names.each {|pn| puts pn}
    puts ""
    puts "Patients Detail:"
    puts "-" * 80
    @dicom_data[:patients].each do |patient_id,patient|
      puts "#{patient_id} - #{patient["Patient's Name"]}"
      patient["studies"].each do |study_id,study|
        puts "  #{study_id} - #{study["Study Description"]}"
        study["series"].each do |series_id,series|
          puts "    #{series_id} - #{series["Series Description"]}"
        end
      end

    end
  end

  def print_dicom_series(series_id)
    @dicom_data[:series][series_id]["instances"].each do |instance_id,instance|
      next if instance["Image Position (Patient)"].nil?
      xyz = instance["Image Position (Patient)"].split("\\")
      puts "  #{'%3.3s' % instance_id}    X:#{'%-8.8s' % xyz[0]}   Y:#{'%-8.8s' % xyz[1]}   Z:#{'%-8.8s' % xyz[2]}"
    end
  end

  def apply_offset(series_id,axis,delta)
    @dicom_data[:series][series_id]["instances"].each do |instance_id,instance|
      next if instance["Image Position (Patient)"].nil?
      xyz = instance["Image Position (Patient)"].split("\\")
      idx = {x:0,y:1,z:2}[axis.downcase.to_sym]

      xyz[idx] = xyz[idx].to_f + delta.to_f

      instance["fileref"]["0020,0032"].value = "#{'%8s' % xyz[0]}\\#{'%8s' % xyz[1]}\\#{'%8s' % xyz[2]}"
      instance["Image Position (Patient)"] = "#{xyz[0]}\\#{xyz[1]}\\#{xyz[2]}"
    end
  end

  def save_series(series_id)
    @dicom_data[:series][series_id]["instances"].each do |instance_id,instance|
      instance["fileref"].write(instance["file"])
    end
    puts "Series: #{series_id} saved."
  end

  def valid_series?(series_id)
    @dicom_data[:series].keys.include? series_id
  end

  def series_ids
    @dicom_data[:series].keys
  end
end
