// CV Helper Functions for Typst
// Provides styling functions equivalent to resume.cls

// LaTeX spacing equivalents:
// \smallskip ≈ 3pt ≈ 0.25em
// \medskip ≈ 6pt ≈ 0.5em
// \bigskip ≈ 12pt ≈ 1em

// Section header with horizontal rule (matches rSection)
#let section(title, content) = {
  v(6pt)  // \sectionskip = \medskip
  text(weight: "bold", size: 11pt, upper(title))
  v(6pt)  // \sectionlineskip = \medskip
  line(length: 100%, stroke: 0.5pt)
  v(3pt)  // \smallskip equivalent after hrule
  block(inset: (left: 1.5em))[
    #content
  ]
}

// Job entry with company, dates, title (matches rSubsection)
// company: Company name (bold, left-aligned)
// dates: Employment dates (right-aligned)
// title: Job title (italic, optional)
// title-dates: Secondary date range for title (optional)
// content: Bullet points
#let job(company, dates, title: none, title-dates: none, content) = {
  // Company and primary dates row
  if company != "" {
    grid(
      columns: (1fr, auto),
      text(weight: "bold")[#company],
      text[#dates]
    )
  }

  // Job title row (if provided)
  if title != none {
    linebreak()
    grid(
      columns: (1fr, auto),
      text(style: "italic")[#title],
      if title-dates != none { text(style: "italic")[#title-dates] }
    )
  }

  v(3pt)  // \smallskip

  // Content (bullet points)
  content

  v(6pt)  // 0.5em space after bullet list
}

// Continuation job entry (no company name, just title)
// Used for multiple roles at same company
#let job-continuation(title, dates, content) = {
  grid(
    columns: (1fr, auto),
    text(style: "italic")[#title],
    text(style: "italic")[#dates]
  )

  v(3pt)  // \smallskip
  content
  v(6pt)
}

// Skills subsection (category with items)
#let skill-category(category, items) = {
  text(weight: "bold")[#category]
  linebreak()
  text[#items]
  linebreak()
}

// Education entry
#let education(institution, dates, details) = {
  grid(
    columns: (1fr, auto),
    text(weight: "bold")[#institution],
    text[#dates]
  )
  linebreak()
  text[#details]
}

// Certification entry (inline format)
#let certifications(items) = {
  items
}
