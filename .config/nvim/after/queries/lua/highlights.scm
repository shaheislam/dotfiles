; Extended highlights for Lua with italic/bold styling

; Keywords - bold + italic
(
  [
    "function"
    "local"
    "return"
    "end"
  ] @keyword (#set! "italic")
       (#set! "bold")
)

; Conditionals - italic
(
  [
    "if"
    "then"
    "elseif"
    "else"
    "for"
    "while"
    "repeat"
    "until"
  ] @keyword.conditional (#set! "italic")
)

; Function names - italic
(function_declaration
  name: (identifier) @function (#set! "italic"))

(function_call
  name: (identifier) @function.call (#set! "italic"))

; Comments - italic
(comment) @comment (#set! "italic")

; Booleans - bold
(
  [
    (true)
    (false)
    (nil)
  ] @boolean (#set! "bold")
)
