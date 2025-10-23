; Extended highlights for JavaScript/TypeScript with italic/bold styling

; Keywords - bold + italic
(
  [
    "function"
    "class"
    "return"
    "async"
    "await"
    "const"
    "let"
    "var"
  ] @keyword (#set! "italic")
       (#set! "bold")
)

; Conditionals - italic
(
  [
    "if"
    "else"
    "for"
    "while"
    "switch"
    "case"
  ] @keyword.conditional (#set! "italic")
)

; Import/export - italic
(
  [
    "import"
    "export"
    "from"
    "as"
    "default"
  ] @keyword.import (#set! "italic")
)

; Function names - italic
(function_declaration
  name: (identifier) @function (#set! "italic"))

(method_definition
  name: (property_identifier) @function.method (#set! "italic"))

; Comments - italic
(comment) @comment (#set! "italic")

; Booleans - bold
(
  [
    (true)
    (false)
    (null)
    (undefined)
  ] @boolean (#set! "bold")
)
