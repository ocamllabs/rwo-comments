type foo =
  | A
  | B of unit

(* No argument. *)
let _ =
  A

(* With argument. *)
let _ =
  B (print_endline "foo")
