#{
  import "@local/wut-thesis:0.1.10": simple-doc, wut-thesis, acknowledgements, figure-outline, table-outline, appendix
  import "utils.typ": flex-caption-styles, todo, glossary-outline
  import "glossary.typ": glossary
  import "@preview/glossarium:0.5.8": make-glossary, register-glossary
  import "@preview/drafting:0.2.2": note-outline, set-margin-note-defaults

  show: make-glossary
  register-glossary(glossary)
  show: flex-caption-styles
  /** Drafting

    The "draft" variable is used to change the coloring of links, show TODOs (both in
    the thesis and TODO outline), as well as DRAFT in the header and the title. This
    should be true until the final version is handed-in.

    The "in-print" variable is used to generate a PDF file for physical printing (it adds
    bigger margins on the binding part of the page and changes the numbering placement).
    It should be set to `false` unless you want to create a version of the PDF file for
    physical print, in which case set it to `true`. To prepare a PDF file for the
    final hand-in (that is to upload it to APD/onedrive) please set this variable to
    `false`. variable to false.

  **/
  let draft = true
  set-margin-note-defaults(hidden: not draft)

  show: simple-doc.with(
    doc-type: "project",
    title: "Operacja splotu na obrazie z wykorzystaniem filtra do wykrywania krawędzi",
    author: ("Jakub Bliźniuk", "Mateusz Szyperek", "Kalina Białek"),
    course: "PORR 25Z",
    instructor: "dr. Mateusz Koryciński",
    date: datetime.today(),
    lang: "pl",
    show-toc: true,
    show-figures: true,
    draft: true, // Set to false for final version
    logo: align(right, image("images/Logo.png", width: 30%))
  )

  // --- Custom Settings ---
  // if you want to override any settings from the template here is the place to do so,
  // e.g.:
  // set text(font: "Comic Sans MS")


  // --- Main Chapters ---
  include "content/Introduction.typ"
  include "content/Implementation.typ"
  include "content/Conclusion.typ"

  
  // --- Bibliography ---
  bibliography("items.bib", style: "ieee")

  // List of Acronyms - comment out, if not needed (no abbreviations were used).
  glossary-outline(glossary)

  // List of figures - comment out, if not needed.
  figure-outline()

  // List of tables - comment out, if not needed.
  table-outline()

  // --- Appendices ---
  // Comment out if not needed.
  // appendix(lang.thesis, include "content/Appendix.typ")

  if draft {
    set heading(numbering: none)
    note-outline(title: "TODOs")
  }
}
