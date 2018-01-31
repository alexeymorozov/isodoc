module IsoDoc
  class Convert
    def self.iso_bibitem_ref_code(b)
      isocode = b.at(ns("./docidentifier"))
      isodate = b.at(ns("./publishdate"))
      reference = "ISO #{isocode.text}"
      reference += ": #{isodate.text}" if isodate
      reference
    end

    def self.date_note_process(b, ref)
      date_note = b.xpath(ns("./note[text()][contains(.,'ISO DATE:')]"))
      unless date_note.empty?
        date_note.first.content =
          date_note.first.content.gsub(/ISO DATE: /, "")
        date_note.wrap("<p></p>")
        footnote_parse(date_note.first, ref)
      end
    end

    def self.iso_bibitem_entry(list, b, ordinal, biblio)
      attrs = { id: b["id"], class: biblio ? "Biblio" : nil }
      list.p **attr_code(attrs) do |ref|
        if biblio
          ref << "[#{ordinal}]"
          insert_tab(ref, 1)
        end
        ref << iso_bibitem_ref_code(b)
        date_note_process(b, ref)
        ref << ", " if biblio
        ref.i { |i| i << " #{b.at(ns('./name')).text}" }
      end
    end

    def self.ref_entry_code(r, ordinal, t)
      if /^\d+$/.match?(t)
        r << "[#{t}]"
        insert_tab(r, 1)
      else
        r << "[#{ordinal}]"
        insert_tab(r, 1)
        r << "#{t},"
      end
    end

    def self.ref_entry(list, b, ordinal, bibliography)
      ref = b.at(ns("./ref"))
      para = b.at(ns("./p"))
      list.p **attr_code("id": ref["id"], class: "Biblio") do |r|
        ref_entry_code(r, ordinal, ref.text.gsub(/[\[\]]/, ""))
        para.children.each { |n| parse(n, r) }
      end
    end

    def self.noniso_bibitem(list, b, ordinal, bibliography)
      ref = b.at(ns("./docidentifier"))
      para = b.at(ns("./formatted"))
      list.p **attr_code("id": b["id"], class: "Biblio") do |r|
        ref_entry_code(r, ordinal, ref.text.gsub(/[\[\]]/, ""))
        para.children.each { |n| parse(n, r) }
      end
    end

    def self.split_bibitems(f)
      iso_bibitem = []
      non_iso_bibitem = []
      f.xpath(ns("./bibitem")).each do |x|
        if x.at(ns("./publisher/affiliation[name = 'ISO']")).nil?
          non_iso_bibitem << x
        else
          iso_bibitem << x
        end
      end
      { iso: iso_bibitem, noniso: non_iso_bibitem }
    end

    def self.biblio_list(f, div, bibliography)
      bibitems = split_bibitems(f)
      bibitems[:iso].each_with_index do |b, i|
        iso_bibitem_entry(div, b, (i + 1), bibliography)
      end
      bibitems[:noniso].each_with_index do |b, i|
        noniso_bibitem(div, b, (i + 1 + bibitems[:iso].size), bibliography)
      end
    end

    @@norm_with_refs_pref = <<~BOILERPLATE
          The following documents are referred to in the text in such a way
          that some or all of their content constitutes requirements of this
          document. For dated references, only the edition cited applies.
          For undated references, the latest edition of the referenced
          document (including any amendments) applies.
    BOILERPLATE

    @@norm_empty_pref =
      "There are no normative references in this document."

    def self.norm_ref_preface(f, div)
      refs = f.elements.select do |e|
        ["reference", "bibitem"].include? e.name
      end
      pref = refs.empty? ? @@norm_empty_pref : @@norm_with_refs_pref
      div.p pref
    end

    def self.norm_ref(isoxml, out)
      q = "//sections/references[title = 'Normative References']"
      f = isoxml.at(ns(q)) or return
      out.div do |div|
        clause_name("2.", "Normative References", div)
        norm_ref_preface(f, div)
        biblio_list(f, div, false)
      end
    end

    def self.bibliography(isoxml, out)
      q = "//sections/references[title = 'Bibliography']"
      f = isoxml.at(ns(q)) or return
      page_break(out)
      out.div do |div|
        div.h1 "Bibliography", **{ class: "Section3" }
        f.elements.reject do |e|
          ["reference", "title", "bibitem"].include? e.name
        end.each { |e| parse(e, div) }
        biblio_list(f, div, true)
      end
    end
  end
end