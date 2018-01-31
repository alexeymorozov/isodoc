#require "nokogiri"
#require "asciimath"
#require "xml/xslt"
#require "uuidtools"
#require "base64"
#require "mime/types"
#require "image_size"
#require "isodoc/postprocessing"
#require "isodoc/utils"
#require "isodoc/metadata"
#require "isodoc/section"
#require "isodoc/references"
#require "isodoc/terms"
#require "isodoc/blocks"
#require "isodoc/lists"
#require "isodoc/table"
#require "isodoc/inline"
#require "isodoc/xref_gen"
require "pp"

module IsoDoc
  class Convert
  #module ISO2WordHTML
    #include ::IsoDoc::Postprocessing
    #include ::IsoDoc::Utils
    #include ::IsoDoc::Metadata
    #include ::IsoDoc::Section
    #include ::IsoDoc::References
    #include ::IsoDoc::Terms
    #include ::IsoDoc::Blocks
    #include ::IsoDoc::Lists
    #include ::IsoDoc::Table
    #include ::IsoDoc::Inline
    #include ::IsoDoc::XrefGen

    def self.init_file(filename)
      filename = filename.gsub(%r{\.[^/.]+$}, "")
      dir = "#{filename}_files"
      Dir.mkdir(dir) unless File.exists?(dir)
      system "rm -r #{dir}/*"
      [filename, dir]
    end

    def self.make_body(xml, docxml)
      body_attr = { lang: "EN-US", link: "blue", vlink: "#954F72" }
      xml.body **body_attr do |body|
        make_body1(body, docxml)
        make_body2(body, docxml)
        make_body3(body, docxml)
      end
    end

    def self.make_body1(body, docxml)
      body.div **{ class: "WordSection1" } do |div1|
        titlepage docxml, div1
      end
      section_break(body)
    end

    def self.make_body2(body, docxml)
      body.div **{ class: "WordSection2" } do |div2|
        info docxml, div2
      end
      section_break(body)
    end

    def self.make_body3(body, docxml)
      body.div **{ class: "WordSection3" } do |div3|
        middle docxml, div3
        footnotes div3
        comments div3
      end
    end

    def self.info(isoxml, out)
      fn = File.join(File.dirname(__FILE__), "iso_intro.html")
      intropage = File.read(fn, encoding: "UTF-8")
      out.parent.add_child intropage
      title isoxml, out
      subtitle isoxml, out
      id isoxml, out
      author isoxml, out
      version isoxml, out
      foreword isoxml, out
      introduction isoxml, out
    end

    def self.middle_title(out)
      m = get_metadata
      out.p **{ class: "zzSTDTitle1" } { |p| p << m[:doctitle] }
    end

    def self.middle(isoxml, out)
      middle_title(out)
      scope isoxml, out
      norm_ref isoxml, out
      terms_defs isoxml, out
      symbols_abbrevs isoxml, out
      clause isoxml, out
      annex isoxml, out
      bibliography isoxml, out
    end

    def self.smallcap_parse(node, xml)
      xml.span **{style: "font-variant:small-caps;"} do |s|
        s << node.text
      end
    end

    def self.text_parse(node, out)
      text = node.text
      text.gsub!("\n", "<br/>").gsub!(" ", "&nbsp;") if in_sourcecode
      out << text
    end

    def self.parse(node, out)
      if node.text?
        text_parse(node, out)
      else
        case node.name
        when "em" then out.i { |e| e << node.text }
        when "strong" then out.b { |e| e << node.text }
        when "sup" then out.sup { |e| e << node.text }
        when "sub" then out.sub { |e| e << node.text }
        when "tt" then out.tt { |e| e << node.text }
        when "strike" then out.s { |e| e << node.text }
        when "smallcap" then smallcap_parse(node, out)
        when "br" then out.br
        when "hr" then out.hr
        when "pagebreak" then pagebreak_parse(node, out)
        when "callout" then callout_parse(node, out)
        when "stem" then stem_parse(node, out)
        when "clause" then clause_parse(node, out)
        when "subsection" then clause_parse(node, out)
        when "xref" then xref_parse(node, out)
        when "eref" then eref_parse(node, out)
        when "origin" then eref_parse(node, out)
        when "link" then link_parse(node, out)
        when "ul" then ul_parse(node, out)
        when "ol" then ol_parse(node, out)
        when "li" then li_parse(node, out)
        when "dl" then dl_parse(node, out)
        when "fn" then footnote_parse(node, out)
        when "p" then para_parse(node, out)
        when "quote" then quote_parse(node, out)
        when "tr" then tr_parse(node, out)
        when "note" then note_parse(node, out)
        when "review" then review_note_parse(node, out)
        when "admonition" then admonition_parse(node, out)
        when "formula" then formula_parse(node, out)
        when "table" then table_parse(node, out)
        when "figure" then figure_parse(node, out)
        when "image" then image_parse(node["src"], out, nil)
        when "sourcecode" then sourcecode_parse(node, out)
        when "annotation" then annotation_parse(node, out)
        when "term" then termdef_parse(node, out)
        when "preferred" then term_parse(node, out)
        when "admitted" then admitted_term_parse(node, out)
        when "deprecates" then deprecated_term_parse(node, out)
        when "domain" then set_termdomain(node.text)
        when "definition" then definition_parse(node, out)
        when "termsource" then termref_parse(node, out)
        when "isosection"
          out << "[ISOSECTION] #{node.text}"
        when "modification" then modification_parse(node, out)
        when "termnote" then termnote_parse(node, out)
        when "termexample" then termexample_parse(node, out)
        else
          error_parse(node, out)
        end
      end
    end
  end
end