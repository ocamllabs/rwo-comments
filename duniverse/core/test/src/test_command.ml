open! Core
open! Import
open! Expect_test_helpers_kernel
open! Command
open! Command.Private

module Expect_test_config = Core.Expect_test_config

let%test_module "word wrap" =
  (module struct
    let word_wrap = Format.V1.word_wrap

    let%test _ = word_wrap "" 10 = []

    let short_word = "abcd"

    let%test _ = word_wrap short_word (String.length short_word) = [short_word]

    let%test _ = word_wrap "abc\ndef\nghi" 100 = ["abc"; "def"; "ghi"]

    let long_text =
      "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vivamus \
       fermentum condimentum eros, sit amet pulvinar dui ultrices in."

    let%test _ = word_wrap long_text 1000 =
                 ["Lorem ipsum dolor sit amet, consectetur adipiscing elit. Vivamus \
                   fermentum condimentum eros, sit amet pulvinar dui ultrices in."]

    let%test _ = word_wrap long_text 39 =
      (*
                    .........1.........2.........3.........4
                    1234567890123456789012345678901234567890
                 *)
                 ["Lorem ipsum dolor sit amet, consectetur";
                  "adipiscing elit. Vivamus fermentum";
                  "condimentum eros, sit amet pulvinar dui";
                  "ultrices in."]

    (* no guarantees: too-long words just overhang the soft bound *)
    let%test _ = word_wrap long_text 2 =
                 ["Lorem"; "ipsum"; "dolor"; "sit"; "amet,"; "consectetur";
                  "adipiscing"; "elit."; "Vivamus"; "fermentum"; "condimentum";
                  "eros,"; "sit"; "amet"; "pulvinar"; "dui"; "ultrices"; "in."]

  end)

let%test_unit _ =
  let path =
    Path.empty
    |> Path.append ~subcommand:"foo/bar.exe"
    |> Path.append ~subcommand:"bar"
    |> Path.append ~subcommand:"bar"
    |> Path.append ~subcommand:"baz"
  in
  [%test_result: string list] (Path.parts path) ~expect:["foo/bar.exe"; "bar"; "bar"; "baz"];
  let path = Path.replace_first path ~from:"bar" ~to_:"qux" in
  [%test_result: string list] (Path.parts path) ~expect:["foo/bar.exe"; "qux"; "bar"; "baz"];
  ()

let%expect_test "[Path.to_string], [Path.to_string_dots]" =
  let path =
    Path.create ~path_to_exe:"foo/bar/baz.exe"
    |> Path.append ~subcommand:"qux"
    |> Path.append ~subcommand:"foo"
    |> Path.append ~subcommand:"bar"
  in
  print_string (Path.to_string path);
  [%expect {| baz.exe qux foo bar |}];
  print_string (Path.to_string_dots path);
  [%expect {| . . . bar |}];
  ()

let%test_module "[Anons]" =
  (module struct
    open Private.Anons

    let%test _ = String.equal (normalize "file")   "FILE"
    let%test _ = String.equal (normalize "FiLe")   "FILE"
    let%test _ = String.equal (normalize "<FiLe>") "<FiLe>"
    let%test _ = String.equal (normalize "(FiLe)") "(FiLe)"
    let%test _ = String.equal (normalize "[FiLe]") "[FiLe]"
    let%test _ = String.equal (normalize "{FiLe}") "{FiLe}"
    let%test _ = String.equal (normalize "<file" ) "<file"
    let%test _ = String.equal (normalize "<fil>a") "<fil>a"
    let%test _ = try ignore (normalize ""        ); false with _ -> true
    let%test _ = try ignore (normalize " file "  ); false with _ -> true
    let%test _ = try ignore (normalize "file "   ); false with _ -> true
    let%test _ = try ignore (normalize " file"   ); false with _ -> true
  end)

let%test_module "Cmdline.extend" =
  (module struct
    let path_of_list subcommands =
      List.fold subcommands
        ~init:(Path.create ~path_to_exe:"exe")
        ~f:(fun path subcommand ->
          Path.append path ~subcommand)

    let extend path =
      match path with
      | ["foo"; "bar"] -> ["-foo"; "-bar"]
      | ["foo"; "baz"] -> ["-foobaz"]
      | _ -> ["default"]

    let test path args expected =
      let expected = Cmdline.of_list expected in
      let observed =
        let path = path_of_list path in
        let args = Cmdline.of_list args in
        Cmdline.extend args ~extend ~path
      in
      [%compare.equal:Cmdline.t] expected observed

    let%test _ = test ["foo"; "bar"] ["anon"; "-flag"] ["anon"; "-flag"; "-foo"; "-bar"]
    let%test _ = test ["foo"; "baz"] []                ["-foobaz"]
    let%test _ = test ["zzz"]        ["x"; "y"; "z"]   ["x"; "y"; "z"; "default"]
  end)

let%expect_test "[choose_one] duplicate name" =
  show_raise ~hide_positions:true (fun () ->
    let open Param in
    choose_one
      [ flag "-foo" (optional int) ~doc:""
      ; flag "-foo" (optional int) ~doc:""
      ]
      ~if_nothing_chosen:`Raise);
  [%expect {|
    (raised (
      "Command.Spec.choose_one called with duplicate name"
      -foo
      lib/core_kernel/src/command.ml:LINE:COL)) |}];
;;

let%expect_test "[choose_one]" =
  let test ?default arguments =
    Command.run ~argv:("__exe_name__" :: arguments)
      (Command.basic ~summary:""
         (let open Command.Let_syntax in
          let%map_open arg =
            choose_one
              ~if_nothing_chosen:
                (match default with
                 | Some x -> `Default_to x
                 | None -> `Raise)
              (List.map [ "-foo"; "-bar" ] ~f:(fun name ->
                 match%map flag name no_arg ~doc:"" with
                 | true -> Some name
                 | false -> None))
          in
          fun () ->
            print_s [%message (arg : string)]))
  in
  test [];
  [%expect {|
    Error parsing command line.  Run with -help for usage information.
    Must pass one of these: -foo; -bar
    ("exit called" (status 1)) |}];
  test [] ~default:"default";
  [%expect {| (arg default) |}];
  test [ "-foo" ];
  [%expect {| (arg -foo) |}];
  test [ "-bar" ];
  [%expect {| (arg -bar) |}];
  test [ "-foo"; "-bar" ];
  [%expect {|
    Error parsing command line.  Run with -help for usage information.
    Cannot pass both -bar and -foo
    ("exit called" (status 1)) |}]
;;

let%expect_test "nested [choose_one]" =
  let test arguments =
    Command.run ~argv:("__exe_name__" :: arguments)
      (Command.basic ~summary:""
         (let open Command.Let_syntax in
          let%map_open arg =
            choose_one ~if_nothing_chosen:`Raise
              [ (let%map foo = flag "foo" no_arg ~doc:""
                 and bar = flag "bar" no_arg ~doc:""
                 in
                 if foo || bar
                 then Some (`Foo_bar (foo, bar))
                 else None)
              ; (let%map baz = flag "baz" no_arg ~doc:""
                 and qux = flag "qux" no_arg ~doc:""
                 in
                 if baz || qux
                 then Some (`Baz_qux (baz, qux))
                 else None) ]
          in
          fun () ->
            print_s
              [%message (arg : [`Foo_bar of bool * bool | `Baz_qux of bool * bool])]))
  in
  test [];
  [%expect {|
    Error parsing command line.  Run with -help for usage information.
    Must pass one of these: -bar,-foo; -baz,-qux
    ("exit called" (status 1)) |}];
  test [ "-foo"; "-baz" ];
  [%expect {|
    Error parsing command line.  Run with -help for usage information.
    Cannot pass both -baz,-qux and -bar,-foo
    ("exit called" (status 1)) |}];
  test [ "-foo" ];
  [%expect {| (arg (Foo_bar (true false))) |}];
  test [ "-bar" ];
  [%expect {| (arg (Foo_bar (false true))) |}]
;;

let%test_unit _ = [
  "/",    "./foo",         "/foo";
  "/tmp", "/usr/bin/grep", "/usr/bin/grep";
  "/foo", "bar",           "/foo/bar";
  "foo",  "bar",           "foo/bar";
  "foo",  "../bar",        "foo/../bar";
] |> List.iter ~f:(fun (dir, path, expected) ->
  [%test_eq: string] (abs_path ~dir path) expected)
;;

let%expect_test "choose_one strings" =
  let open Param in
  let to_string = Spec.to_string_for_choose_one in
  print_string (to_string begin
    flag "-a" no_arg ~doc:""
  end);
  [%expect {| -a |} ];
  print_string (to_string begin
    map2 ~f:Tuple2.create
      (flag "-a" no_arg ~doc:"")
      (flag "-b" no_arg ~doc:"")
  end);
  [%expect {| -a,-b |} ];
  print_string (to_string begin
    map2 ~f:Tuple2.create
      (flag "-a" no_arg ~doc:"")
      (flag "-b" (optional int) ~doc:"")
  end);
  [%expect {| -a,-b |} ];
  printf !"%{sexp: string Or_error.t}"
    (Or_error.try_with (fun () ->
       to_string begin
         map2 ~f:Tuple2.create
           (flag "-a" no_arg ~doc:"")
           (flag "-b,c" (optional int) ~doc:"")
       end));
  [%expect {|
    (Error
     ("For simplicity, [Command.Spec.choose_one] does not support names with commas."
      (-b,c) *)) (glob) |}];
  print_string (to_string begin
    map2 ~f:Tuple2.create
      (anon ("FOO" %: string))
      (flag "-a" no_arg ~doc:"")
  end);
  [%expect {| -a,FOO |} ];
  print_string (to_string begin
    map2 ~f:Tuple2.create
      (anon ("FOO" %: string))
      (map2 ~f:Tuple2.create
         (flag "-a" no_arg ~doc:"")
         (flag "-b" no_arg ~doc:""))
  end);
  [%expect {| -a,-b,FOO |} ];
  print_string (to_string begin
    map2 ~f:Tuple2.create
      (anon (maybe ("FOO" %: string)))
      (flag "-a" no_arg ~doc:"")
  end);
  [%expect {| -a,FOO |} ];
  print_string (to_string begin
    map2 ~f:Tuple2.create
      (anon ("fo{}O" %: string))
      (flag "-a" no_arg ~doc:"")
  end);
  [%expect {| -a,fo{}O |} ];
;;

let%test_unit "multiple runs" =
  let r = ref (None, "not set") in
  let command =
    let open Let_syntax in
    basic ~summary:"test"
      [%map_open
        let a = flag "int" (optional int) ~doc:"INT some number"
        and b = anon ("string" %: string)
        in
        fun () -> r := (a, b)
      ]
  in
  let test args expect =
    run command ~argv:(Sys.argv.(0) :: args);
    [%test_result: int option * string] !r ~expect
  in
  test ["foo"; "-int"; "23"] (Some 23, "foo");
  test ["-int"; "17"; "bar"] (Some 17, "bar");
  test ["baz"]               (None,    "baz");
;;

let%expect_test "[?verbose_on_parse_error]" =
  let test ?verbose_on_parse_error ( )=
    Command.run ~argv:["__exe_name__"] ?verbose_on_parse_error
      (Command.basic ~summary:""
         (let open Command.Let_syntax in
          let%map_open () =
            let%map () = return () in
            raise_s [%message "Fail!"]
          in
          fun () -> ()))
  in
  test ?verbose_on_parse_error:None ();
  [%expect {|
    Error parsing command line.  Run with -help for usage information.
    Fail!
    ("exit called" (status 1)) |}];
  test ~verbose_on_parse_error:true ();
  [%expect {|
    Error parsing command line.  Run with -help for usage information.
    Fail!
    ("exit called" (status 1)) |}];
  test ~verbose_on_parse_error:false ();
  [%expect {|
    Fail!
    ("exit called" (status 1)) |}];
;;
