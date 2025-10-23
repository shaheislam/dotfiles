; Extended highlights for Python with italic/bold styling
; This overrides default tree-sitter highlights to add consistent styling

; Keywords - bold + italic
(
  [
    "def"
    "class"
    "return"
    "yield"
    "lambda"
    "async"
    "await"
  ] @keyword (#set! "italic")
       (#set! "bold")
)

; Conditionals and loops - italic
(
  [
    "if"
    "elif"
    "else"
    "for"
    "while"
    "break"
    "continue"
  ] @keyword.conditional (#set! "italic")
)

; Import statements - italic
(
  [
    "import"
    "from"
    "as"
  ] @keyword.import (#set! "italic")
)

; Function definitions - italic
(function_definition
  name: (identifier) @function (#set! "italic"))

; Type annotations - bold + italic
(type (identifier) @type (#set! "italic") (#set! "bold"))

; Comments - italic
(comment) @comment (#set! "italic")

; Booleans - bold
(
  [
    (true)
    (false)
    (none)
  ] @boolean (#set! "bold")
)
