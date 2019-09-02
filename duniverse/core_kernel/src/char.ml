open! Import

type t = char [@@deriving typerep]

module Z =
  Identifiable.Extend
    (Base.Char)
    (struct
      type t = char [@@deriving bin_io]
    end)

include (
  Z :
    module type of struct
    include Z
  end
  with module Replace_polymorphic_compare := Z.Replace_polymorphic_compare)

(* include [Base.Char] after the application of [Identifiable.Extend] to replace the
   [Comparable] functions with the pervasive versions *)
include (
  Base.Char :
    module type of struct
    include Base.Char
  end
  with type t := t)

module Replace_polymorphic_compare = Base.Char

let quickcheck_generator = Base_quickcheck.Generator.char
let quickcheck_observer = Base_quickcheck.Observer.char
let quickcheck_shrinker = Base_quickcheck.Shrinker.char
let gen_digit = Base_quickcheck.Generator.char_digit
let gen_lowercase = Base_quickcheck.Generator.char_lowercase
let gen_uppercase = Base_quickcheck.Generator.char_uppercase
let gen_alpha = Base_quickcheck.Generator.char_alpha
let gen_alphanum = Base_quickcheck.Generator.char_alphanum
let gen_print = Base_quickcheck.Generator.char_print
let gen_whitespace = Base_quickcheck.Generator.char_whitespace
let gen_uniform_inclusive = Base_quickcheck.Generator.char_uniform_inclusive
