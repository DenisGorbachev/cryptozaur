locals_without_parens = []

[
  inputs: ["mix.exs", "{config,lib,test,priv,rel}/**/*.{ex,exs}"],
  line_length: 100500,
  locals_without_parens: locals_without_parens,
  export: [
    [
      locals_without_parens: locals_without_parens
    ]
  ]
]
