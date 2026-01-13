#import "@preview/drafting:0.2.2": inline-note
#import "@preview/glossarium:0.5.8": print-glossary
#import "@preview/lovelace:0.3.0": *

#let glossary-outline(glossary) = {
  context {
    let lang = text.lang
    let glossary-text = if lang == "en" { "List of Symbols and Abbreviations" } else { "Wykaz symboli i skrótów" }
    heading(numbering: none, glossary-text)
    print-glossary(glossary, show-all: true, disable-back-references: true)
  }
}

#let todo(it) = [
  #let caution-rect = rect.with(inset: 1em, radius: 0.5em)
  #inline-note(rect: caution-rect, stroke: color.fuchsia, fill: color.fuchsia.lighten(80%))[
    #align(center + horizon)[#text(fill: color.fuchsia, weight: "extrabold")[TODO:] #it]
  ]
]

#let silentheading(level, body) = [
  #heading(outlined: false, level: level, numbering: none, bookmarked: true)[#body]
]

#let in-outline = state("in-outline", false)

#let flex-caption-styles = rest => {
  show outline: it => {
    in-outline.update(true)
    it
    in-outline.update(false)
  }
  rest
}

#let flex-caption(long, short) = (
  context (
    if in-outline.get() {
      short
    } else {
      long
    }
  )
)

#let code-listing-figure(caption: none, content) = {
  figure(
    caption: caption,
    rect(
      stroke: (y: 1pt + black),
      align(left, content),
    ),
  )
}

#let code-listing-file(filename, caption: none, listings-directory: "listings/") = {
  let extension = filename.split(".").last()
  code-listing-figure(raw(block: true, lang: extension, read(listings-directory + filename)), caption: caption)
}

#let algorithm(content, caption: none, ..args) = {
  figure(
    pseudocode-list(..args, booktabs: true, hooks: .5em, content),
    caption: caption,
    kind: "algorithm",
    supplement: context { if text.lang == "en" [Algorithm] else if text.lang == "pl" [Algorytm] },
  )
}

#let comment(body) = {
  text(size: .85em, fill: gray.darken(30%), sym.triangle.stroked.r + sym.space + body)
}



// from https://github.com/typst/typst/issues/779#issuecomment-2453436459
#let _state-referable-enum = state("--state-referable-enum", none)
#let _counter-referable-enum = counter("--counter-referable-enum")
// Both arguments assumed to be strings.
#let _get-greatest-suffix(sample1, sample2) = {
    let suffix = ("",)
    for (c1, c2) in sample1.rev().split("").zip(sample2.rev().split("")) {
        if c1 == c2 {
            suffix.push(c1)
        } else {
            break
        }
    }
    suffix.rev().join("")
}
#let _remove-suffix(x, suffix) = {
    assert(x.ends-with(suffix))
    x.slice(0, x.len() - suffix.len())
}

/// *Example:*
///
/// ```typst
/// #show: enable-referable-enums
/// #set enum(numbering: "a.", full: true)
/// #referable-enum("Step")[
/// + foo
/// + bar <baz>
/// ]
/// @baz  // Renders as 'Step b'
/// ```
///
/// - supplement (str): The name to use when referencing this enum, e.g. the 'Step' in 'Step 1'.
/// - doc (content): Content
/// -> content
#let referable-enum(supplement, doc) = context {
    let current-numbering = enum.numbering
    assert(enum.full, message: "Only `enum.full = true` is supported right now. Add `#set enum(full: true)`.")
    let wrap-numbering(..it) = {
        _counter-referable-enum.update(it.pos())
        numbering(current-numbering, ..it)
    }
    set enum(numbering: wrap-numbering)

    let sample1 = numbering(current-numbering, 1)
    let sample2 = numbering(current-numbering, 2)
    let suffix = _get-greatest-suffix(sample1, sample2)

    _state-referable-enum.update((supplement, suffix, current-numbering))
    doc
}


/// Referable enums.
/// Use as e.g. `#show: enable-referable-enums`
#let enable-referable-enums(doc) = {
    show ref: it => {
        let el = it.element
        let loc = el.location()
        if el != none and el.func() == text and _state-referable-enum.at(loc) != none {
            let (supplement, suffix, current-numbering) = _state-referable-enum.at(loc)
            let numbers = numbering(current-numbering, .._counter-referable-enum.at(loc))
            // Override enum references.
            link(loc, supplement + " " + numbers)
        } else {
            // Other references as usual.
            it
        }
    }
    doc
}