require 'bibtex'

class PaperFile
  attr_accessor :paper_path
  attr_accessor :bibtex_entries
  attr_accessor :bibtex_error

  def initialize(path=nil)
    @paper_path = path
    @bibtex_error = "No paper file path" if @paper_path.nil?
  end

  def bibtex_entries
    @bibtex_entries ||= BibTeX.open(bibtex_path, filter: :latex).data
    @bibtex_entries.keep_if { |entry| !entry.comment? && !entry.preamble? && !entry.string? }
  rescue BibTeX::ParseError => e
    @bibtex_error = e.message
    []
  end

  def bibtex_path
    @bibtex_path ||= "#{File.dirname(paper_path)}/#{bibtex_filename}"
    puts "found bibtex path #{@bibtex_path}"
  end

  def bibtex_filename
    # TODO this is listed in a yaml header in the .rst file -- ideally, we
    # will be reading it from there
    metadata = YAML.load_file(metadata_path) rescue {}
    filename = metadata['bibliography']
    if filename.to_s.strip.empty?
      @bibtex_error = "Bad bibliography entry in the paper's metadata"
    end
    if filename.nil?
      @bibtex_error = "Couldn't find bibliography entry in the paper's metadata"
    end
    @bibtex_filename = "#{filename}.bib"
    puts "found bibtex name #{@bibtex_filename}"
    @bibtext_filename
  end

  def metadata_path
    if paper_path.end_with?('.tex')
      "#{File.dirname(paper_path)}/paper.yml"
    else
      paper_path
    end
  end

  def self.find(search_path)
    paper_path = nil

    # the example papers are 00_vanderwalt and 00_bibderwalt
    unless search_path.start_with? "00"
      if Dir.exist? search_path
        Find.find(search_path).each do |path|
          # currently, SciPy only supports restructered text, although hopefully
          # this will change in the future
          if path =~ /.*\.rst$/
            puts "found paper path #{path}"
            paper_path = path
            break
          end
        end
      end
    end
    PaperFile.new paper_path
  end

  def text
    return "" if @paper_path.nil? || @paper_path.empty?
    File.open(@paper_path).read
  end

end