if exists("b:current_syntax")
  finish
endif

syntax case ignore

syntax match ranoteSize /\[.\{-}\]/
syntax match ranoteKey /Bit\d\+/
syntax match ranoteKey /0x[0-9a-fA-F]\+/

hi def link ranoteSize Keyword
hi def link ranoteKey  Number

let b:current_syntax = "ranote"