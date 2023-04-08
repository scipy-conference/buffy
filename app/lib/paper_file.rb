require 'bibtex'

class PaperFile
  attr_accessor :paper_path
  attr_accessor :bibtex_entries
  attr_accessor :bibtex_error

  def initialize(path=nil)
    @paper_path = path
    @bibtex_error = "No paper file path" if @paper_path.nil?
  end

  def bib
    return @bib unless @bib.nil?

    parsed_bib = BibTeX.open(bibtex_path, filter: :latex)
    no_filter_bib = BibTeX.open(bibtex_path)

    parsed_bib.data.each_with_index do |entry, i|
      entry.doi = no_filter_bib.data[i].doi if entry.is_a?(BibTeX::Entry) && entry.has_field?('doi')
    end

    @bib = parsed_bib
  end

  def bibtex_entries
    @bibtex_entries ||= bib.data
    @bibtex_entries.keep_if { |entry| !entry.comment? && !entry.preamble? && !entry.string? }

    unless bib.errors.empty?
      @bibtex_error = "Lexical or syntactical errors: \n\n"
      @bibtex_error += bib.errors.map(&:content).join("\n")
    end

    @bibtex_entries
  rescue BibTeX::ParseError => e
    @bibtex_error = e.message
    []
  end

  def bibtex_path
    # TODO this is listed in a yaml header in the .rst file -- ideally, we
    # will be reading it from there, but we'll search near the paper for now
    search_directory = File.dirname(paper_path)
    bibtex_path = nil
    Find.find(search_directory).each do |path|
      if path =~ /.*\.bib$/
        puts "found bibtex name #{path}"
        bibtex_path = path
      end
    end
    if bibtex_path.nil?
      @bibtex_error = "Couldn't find bibliography entry"
    end
    @bibtex_filename = bibtex_path
    bibtex_path
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

    if Dir.exist? search_path
      Find.find(search_path).each do |path|
        # the example papers are 00_vanderwalt and 00_bibderwalt
        unless path.include?("00_vanderwalt") || path.include?("00_bibderwalt")
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