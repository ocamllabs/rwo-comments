open! Import
open Std_internal

(* the module [T] serves to enforce the invariant that all Blang.t values are in a
   normal form whereby boolean constants True and False only appear as the topmost
   constructor -- in any other position they are simplified away using laws of
   boolean algebra.

   Note: this file deviates from the usual pattern of modules with Stable interfaces in
   that the Stable sub-module is not the first thing to be defined in the module.  The
   reason for this deviation is so that one can convince oneself of the aforementioned
   invariant after reading only this small amount of code.  After defining T we then
   immediately define its Stable interface.
*)
module T : sig
  type 'a t = private
    | True
    | False
    | And of 'a t * 'a t
    | Or of 'a t * 'a t
    | Not of 'a t
    | If of 'a t * 'a t * 'a t
    | Base of 'a
  [@@deriving bin_io, compare, hash]

  val invariant : 'a t -> unit
  val true_ : 'a t
  val false_ : 'a t
  val not_ : 'a t -> 'a t
  val andalso : 'a t -> 'a t -> 'a t
  val orelse : 'a t -> 'a t -> 'a t
  val if_ : 'a t -> 'a t -> 'a t -> 'a t
  val base : 'a -> 'a t
end = struct
  type 'a t =
    | True
    | False
    | And of 'a t * 'a t
    | Or of 'a t * 'a t
    | Not of 'a t
    | If of 'a t * 'a t * 'a t
    | Base of 'a
  [@@deriving bin_io, compare, hash]

  let invariant =
    let subterms = function
      | True | False | Base _ -> []
      | Not t1 -> [ t1 ]
      | And (t1, t2)
      | Or (t1, t2) -> [ t1; t2 ]
      | If (t1, t2, t3) -> [ t1; t2; t3 ]
    in
    let rec contains_no_constants = function
      | True | False -> assert false
      | t -> List.iter ~f:contains_no_constants (subterms t)
    in
    fun t -> List.iter ~f:contains_no_constants (subterms t)
  ;;

  let true_ = True
  let false_ = False
  let base v = Base v

  let not_ = function
    | True -> False
    | False -> True
    | Not t -> t
    | t -> Not t
  ;;

  let andalso t1 t2 =
    match t1, t2 with
    | _, False
    | False, _ -> False
    | other, True
    | True, other -> other
    | _ -> And (t1, t2)
  ;;

  let orelse t1 t2 =
    match t1, t2 with
    | _, True
    | True, _ -> True
    | other, False
    | False, other -> other
    | _ -> Or (t1, t2)
  ;;

  let if_ a b c =
    match a with
    | True -> b
    | False -> c
    | _ ->
      (match b, c with
       | True, _ -> orelse a c
       | _, False -> andalso a b
       | _, True -> orelse (not_ a) b
       | False, _ -> andalso (not_ a) c
       | _ -> If (a, b, c))
  ;;
end

include T

module Stable = struct
  module V1 : sig
    (* THIS TYPE AND ITS SERIALIZATIONS SHOULD NEVER BE CHANGED - PLEASE SPEAK WITH
       ANOTHER DEVELOPER IF YOU NEED MORE DETAIL *)

    type 'a t = 'a T.t = private
      | True
      | False
      | And of 'a t * 'a t
      | Or of 'a t * 'a t
      | Not of 'a t
      | If of 'a t * 'a t * 'a t
      | Base of 'a
    [@@deriving bin_io, compare, hash, sexp]

    (* the remainder of this signature consists of functions used in the definitions
       of sexp conversions that are also useful more generally *)

    val and_ : 'a t list -> 'a t
    val or_ : 'a t list -> 'a t
    val gather_conjuncts : 'a t -> 'a t list
    val gather_disjuncts : 'a t -> 'a t list
  end = struct
    type 'a t = 'a T.t = private
      | True
      | False
      | And of 'a t * 'a t
      | Or of 'a t * 'a t
      | Not of 'a t
      | If of 'a t * 'a t * 'a t
      | Base of 'a

    include (
      T :
      sig
        type 'a t [@@deriving bin_io, compare, hash]
      end
      with type 'a t := 'a t)

    type sexp = Sexp.t =
      | Atom of string
      | List of sexp list

    (* cheap import *)

    (* flatten out nested and's *)
    let gather_conjuncts t =
      let rec loop acc = function
        | True :: ts -> loop acc ts
        | And (t1, t2) :: ts -> loop acc (t1 :: t2 :: ts)
        | t :: ts -> loop (t :: acc) ts
        | [] -> List.rev acc
      in
      loop [] [ t ]
    ;;

    (* flatten out nested or's *)
    let gather_disjuncts t =
      let rec loop acc = function
        | False :: ts -> loop acc ts
        | Or (t1, t2) :: ts -> loop acc (t1 :: t2 :: ts)
        | t :: ts -> loop (t :: acc) ts
        | [] -> List.rev acc
      in
      loop [] [ t ]
    ;;

    let and_ ts =
      let rec loop acc = function
        | [] -> acc
        | False :: _ -> false_ (* short circuit evaluation *)
        | t :: ts -> loop (andalso acc t) ts
      in
      loop true_ ts
    ;;

    let or_ ts =
      let rec loop acc = function
        | [] -> acc
        | True :: _ -> true_ (* short circuit evaluation *)
        | t :: ts -> loop (orelse acc t) ts
      in
      loop false_ ts
    ;;

    let unary name args sexp =
      match args with
      | [ x ] -> x
      | _ ->
        let n = List.length args in
        of_sexp_error (sprintf "%s expects one argument, %d found" name n) sexp
    ;;

    let ternary name args sexp =
      match args with
      | [ x; y; z ] -> x, y, z
      | _ ->
        let n = List.length args in
        of_sexp_error (sprintf "%s expects three arguments, %d found" name n) sexp
    ;;

    let sexp_of_t sexp_of_value t =
      let rec aux t =
        match t with
        | Base x -> sexp_of_value x
        | True -> Atom "true"
        | False -> Atom "false"
        | Not t -> List [ Atom "not"; aux t ]
        | If (t1, t2, t3) -> List [ Atom "if"; aux t1; aux t2; aux t3 ]
        | And _ as t ->
          let ts = gather_conjuncts t in
          List (Atom "and" :: List.map ~f:aux ts)
        | Or _ as t ->
          let ts = gather_disjuncts t in
          List (Atom "or" :: List.map ~f:aux ts)
      in
      aux t
    ;;

    let t_of_sexp base_of_sexp sexp =
      let base sexp = base (base_of_sexp sexp) in
      let rec aux sexp =
        match sexp with
        | Atom kw ->
          (match String.lowercase kw with
           | "true" -> true_
           | "false" -> false_
           | _ -> base sexp)
        | List (Atom kw :: args) ->
          (match String.lowercase kw with
           | "and" -> and_ (List.map ~f:aux args)
           | "or" -> or_ (List.map ~f:aux args)
           | "not" -> not_ (aux (unary "not" args sexp))
           | "if" ->
             let x, y, z = ternary "if" args sexp in
             if_ (aux x) (aux y) (aux z)
           | _ -> base sexp)
        | _ -> base sexp
      in
      aux sexp
    ;;
  end
end

include (Stable.V1 : module type of Stable.V1 with type 'a t := 'a t)

let constant b = if b then true_ else false_

module type Constructors = sig
  val base : 'a -> 'a t
  val true_ : _ t
  val false_ : _ t
  val constant : bool -> _ t
  val not_ : 'a t -> 'a t
  val and_ : 'a t list -> 'a t
  val or_ : 'a t list -> 'a t
  val if_ : 'a t -> 'a t -> 'a t -> 'a t
end

module O = struct
  include T

  let not = not_
  let and_ = and_
  let or_ = or_
  let constant = constant
  let ( && ) = andalso
  let ( || ) = orelse
  let ( ==> ) a b = not a || b
end

let constant_value = function
  | True -> Some true
  | False -> Some false
  | _ -> None
;;

(* [values t] lists the base predicates in [t] from left to right *)
let values t =
  let rec loop acc = function
    | Base v :: ts -> loop (v :: acc) ts
    | True :: ts -> loop acc ts
    | False :: ts -> loop acc ts
    | Not t1 :: ts -> loop acc (t1 :: ts)
    | And (t1, t2) :: ts -> loop acc (t1 :: t2 :: ts)
    | Or (t1, t2) :: ts -> loop acc (t1 :: t2 :: ts)
    | If (t1, t2, t3) :: ts -> loop acc (t1 :: t2 :: t3 :: ts)
    | [] -> List.rev acc
  in
  loop [] [ t ]
;;

module C = Container.Make (struct
    type 'a t = 'a T.t

    let fold t ~init ~f =
      let rec loop acc t pending =
        match t with
        | Base a -> next (f acc a) pending
        | True | False -> next acc pending
        | Not t -> loop acc t pending
        | And (t1, t2)
        | Or (t1, t2) -> loop acc t1 (t2 :: pending)
        | If (t1, t2, t3) -> loop acc t1 (t2 :: t3 :: pending)
      and next acc = function
        | [] -> acc
        | t :: ts -> loop acc t ts
      in
      loop init t []
    ;;

    let iter = `Define_using_fold
    let length = `Define_using_fold
  end)

let count = C.count
let sum = C.sum
let exists = C.exists
let find = C.find
let find_map = C.find_map
let fold = C.fold
let for_all = C.for_all
let is_empty = C.is_empty
let iter = C.iter
let length = C.length
let mem = C.mem
let to_array = C.to_array
let to_list = C.to_list
let min_elt = C.min_elt
let max_elt = C.max_elt
let fold_result = C.fold_result
let fold_until = C.fold_until

include Monad.Make (struct
    type 'a t = 'a T.t

    let return = base

    let rec bind t ~f:k =
      match t with
      | Base v -> k v
      | True -> true_
      | False -> false_
      | Not t1 -> not_ (bind t1 ~f:k)
      (* Unfortunately we need to duplicate some of the short-circuiting from [andalso] and
         friends here. In principle we could do something involving [Lazy.t] but the
         overhead probably wouldn't be worth it. *)
      | And (t1, t2) ->
        (match bind t1 ~f:k with
         | False -> false_
         | other -> andalso other (bind t2 ~f:k))
      | Or (t1, t2) ->
        (match bind t1 ~f:k with
         | True -> true_
         | other -> orelse other (bind t2 ~f:k))
      | If (t1, t2, t3) ->
        (match bind t1 ~f:k with
         | True -> bind t2 ~f:k
         | False -> bind t3 ~f:k
         | other -> if_ other (bind t2 ~f:k) (bind t3 ~f:k))
    ;;

    let map = `Define_using_bind
  end)

(* semantics *)

let eval t base_eval =
  let rec eval = function
    | True -> true
    | False -> false
    | And (t1, t2) -> eval t1 && eval t2
    | Or (t1, t2) -> eval t1 || eval t2
    | Not t -> not (eval t)
    | If (t1, t2, t3) -> if eval t1 then eval t2 else eval t3
    | Base x -> base_eval x
  in
  eval t
;;

let specialize t f =
  bind t ~f:(fun v ->
    match f v with
    | `Known c -> constant c
    | `Unknown -> base v)
;;

let eval_set ~universe:all set_of_base =
  let rec aux (b : _ t) =
    match b with
    | True -> force all
    | False -> Set.Using_comparator.empty ~comparator:(Set.comparator (force all))
    | And (a, b) -> Set.inter (aux a) (aux b)
    | Or (a, b) -> Set.union (aux a) (aux b)
    | Not a -> Set.diff (force all) (aux a)
    | Base a -> set_of_base a
    | If (cond, a, b) ->
      let cond = aux cond in
      Set.union (Set.inter cond (aux a)) (Set.inter (Set.diff (force all) cond) (aux b))
  in
  aux
;;
