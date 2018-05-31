open Core
open Async
module Html = Rwo_html
module Import = Rwo_import
module References = Rwo_references
module Index = Rwo_index
module Scripts = Rwo_scripts
module Toc = Rwo_toc
let (/) = Filename.concat

(******************************************************************************)
(* HTML fragments                                                             *)
(******************************************************************************)
let head_item : Html.item =
  let open Html in
  head [
    meta ~a:["charset","utf-8"] [];
    meta ~a:[
      "name","viewport";
      "content","width=device-width, initial-scale=1.0"
    ] [];
    title [`Data "Real World OCaml"];
    link ~a:["rel","stylesheet"; "href","css/app.css"] [];
    script ~a:["src","js/min/modernizr-min.js"] [];
    script ~a:["src","//use.typekit.net/gfj8wez.js"] [];
    script [`Data "try{Typekit.load();}catch(e){}"];
  ]

let title_bar,title_bar_frontpage =
  let open Html in
  let nav = nav [
    a ~a:["href","index.html"] [`Data "Home"];
    a ~a:["href","toc.html"] [`Data "Table of Contents"];
    a ~a:["href","faqs.html"] [`Data "FAQs"];
    a ~a:["href","install.html"] [`Data "Install"];
    a ~a:["href","https://ocaml.janestreet.com/ocaml-core/"]
      [`Data "API Docs"];
  ]
  in
  let h1 = h1 [`Data "Real World OCaml"] in
  let h4 = h4 [`Data "Functional programming for the masses"] in
  let h5 = h5 [`Data "2"; sup [`Data "nd"]; `Data " Edition (in progress)"] in
  let title_bar =
    div ~a:["class","title-bar"] [
      div ~a:["class","title"] [h1; h5; nav]
    ]
  in
  let title_bar_frontpage =
    div ~a:["class","splash"] [
      div ~a:["class","image"] [];
      div ~a:["class","title"] [h1; h4; h5; nav]
    ]
  in
  title_bar,title_bar_frontpage

let footer_item : Html.item =
  let open Html in
  let links = [
    "http://twitter.com/realworldocaml", "@realworldocaml";
    "http://twitter.com/yminsky", "@yminsky";
    "http://twitter.com/avsm", "@avsm";
    "https://plus.google.com/111219778721183890368", "+hickey";
    "https://github.com/realworldocaml", "GitHub";
    "http://www.goodreads.com/book/show/16087552-real-world-ocaml", "goodreads";
  ]
  |> List.map ~f:(fun (href,text) -> li [a ~a:["href",href] [`Data text]])
  |> ul
  in
  footer [
    div ~a:["class","content"] [
      links;
      p [`Data "Copyright 2012-2014 \
         Jason Hickey, Anil Madhavapeddy and Yaron Minsky."];
    ]
  ]

let toc chapters : Html.item list =
  let open Html in
  let open Toc in
  let parts = Toc.of_chapters chapters in
  List.map parts ~f:(fun {info;chapters} ->
    let ul = ul ~a:["class","toc-full"] (List.map chapters ~f:(fun chapter ->
      li [
        a ~a:["href",chapter.filename] [
          h2 [`Data (
            if chapter.number = 0
            then sprintf "%s" chapter.title
            else sprintf "%d. %s" chapter.number chapter.title
          )]
        ];
        ul ~a:["class","children"] (
          List.map chapter.sections ~f:(fun (sect1,sect2s) ->
            let href = sprintf "%s#%s" chapter.filename sect1.id in
            li [
              a ~a:["href",href] [h5 [`Data sect1.title]];
              ul ~a:["class","children"] (
                List.map sect2s ~f:(fun (sect2,sect3s) ->
                  let href = sprintf "%s#%s" chapter.filename sect2.id in
                  li [
                    a ~a:["href",href] [`Data sect2.title];
                    ul ~a:["class","children"] (
                      List.map sect3s ~f:(fun sect3 ->
                        let href = sprintf "%s#%s" chapter.filename sect3.id in
                        li [a ~a:["href",href] [`Data sect3.title]]
                      ) );
                  ]
                ) );
            ]
          ) );
      ]
    ) )
    in
    match info with
    | None -> [ul]
    | Some x -> [
      h5 ~a:["class","part-link"] [
        `Data (sprintf "Part %d: %s" x.number x.title)
      ];
      ul;
    ]
  )
  |> List.concat

let next_chapter_footer next_chapter : Html.item option =
  let open Html in
  let open Toc in
  match next_chapter with
  | None -> None
  | Some x -> Some (
    a ~a:["class","next-chapter"; "href", x.filename] [
      div ~a:["class","content"] [
        h1 [
          small [`Data (sprintf "Next: Chapter %02d" x.number)];
          `Data x.title
        ]
      ]
    ]
  )

(** Insert [content] into main template. The title bar differs on
    front page and only chapter pages contain links to a next chapter,
    so these are additional arguments. *)
let main_template ?(next_chapter_footer=None)
    ~title_bar ~content () : Html.t =
  let open Html in
  [html ~a:["class", "js flexbox fontface"; "lang", "en"; "style", ""] [
    head [head_item];
    body (List.filter_map ~f:Fn.id [
      Some title_bar;
      Some (div ~a:["class","wrap"] content);
      next_chapter_footer;
      Some footer_item;
      Some (Html.script ~a:["src","js/jquery.min.js"] []);
      Some (Html.script ~a:["src","js/min/app-min.js"] []);
      Some (Html.script ~a:["src","js/discourse.js"] []);
    ])
  ]]

(******************************************************************************)
(* Make Pages                                                                 *)
(******************************************************************************)
let make_frontpage ?(repo_root=".") () : Html.t Deferred.t =
  let part_items {Toc.info; chapters} = List.filter_map ~f:Fn.id [
    Option.map info ~f:(fun x -> Html.h4 [`Data x.Toc.title]);
    Some (Html.ul (List.map chapters ~f:(fun x ->
      Html.li [Html.a ~a:["href",x.Toc.filename] [`Data x.title]])))
  ]
  in
  let file = repo_root/"book"/"index.html" in
  (
    Toc.get ~repo_root () >>| function
    | [a;b;c;d] -> a,b,c,d
    | _ -> failwith "frontpage design expects exactly 3 parts"
  ) >>= fun (prologue,part1,part2,part3) ->
  let column1 = [Html.div ~a:["class","index-toc"]
    ((part_items prologue)@(part_items part1))]
  in
  let column2 = [Html.div ~a:["class","index-toc"] (part_items part2)] in
  let column3 = [Html.div ~a:["class","index-toc"] (part_items part3)] in
  Html.of_file file >>| fun html ->
  let content =
    Html.get_body_childs ~filename:file html
    |> Html.replace_id_node_with ~id:"part1" ~with_:column1
    |> Html.replace_id_node_with ~id:"part2" ~with_:column2
    |> Html.replace_id_node_with ~id:"part3" ~with_:column3
  in
  main_template ~title_bar:title_bar_frontpage ~content ()

let make_toc_page ?(repo_root=".") () : Html.t Deferred.t =
  Toc.get_chapters ~repo_root () >>| fun chapters ->
  let content = Html.[
    div ~a:["class","left-column"] [];
    article ~a:["class","main-body"] (toc chapters);
  ]
  in
  main_template ~title_bar:title_bar ~content ()

let make_chapter_page ?code_dir ?pygmentize ?(run_nondeterministic=false)
    repo_root chapters chapter_file
    : Html.t Deferred.t
    =

  let chapter = List.find_exn chapters ~f:(fun x ->
    x.Toc.filename = Filename.basename chapter_file)
  in

  let next_chapter_footer =
    next_chapter_footer (Toc.get_next_chapter chapters chapter)
  in

  let import_node_to_html scripts (i:Import.t) : Html.item Deferred.t =
    (
      match i.Import.alt with
      | None ->
	 return (Scripts.find_exn scripts ~filename:i.href ?part:i.part)
      | Some alt ->
	 Reader.file_contents (repo_root/"book"/alt) >>| fun x ->
      Scripts.exn_of_filename alt x
    ) >>=
    Scripts.script_part_to_html ?pygmentize
  in
  let rec loop scripts html : Html.t Deferred.t =
    (Deferred.List.map html ~f:(fun item ->
      if Import.is_import_html item then
        import_node_to_html scripts (ok_exn (Import.of_html item))
      else if References.is_reference item then
        return (References.add_reference chapter_file item)
      else match item with
      | `Data _ -> return item
      | `Element {Html.name; attrs; childs} -> (
        Deferred.List.map childs ~f:(fun x -> loop scripts [x])
        >>| List.concat
        >>| fun childs -> `Element {Html.name; attrs; childs}
      )
     )
    )
  in

  Html.of_file chapter_file >>= fun html ->
  let html = Html.get_body_childs ~filename:chapter_file html in
  Scripts.of_html ?code_dir ~run_nondeterministic ~filename:chapter_file html >>|
  ok_exn >>= fun scripts ->
  loop scripts html >>| fun content ->
  let content = Html.[
    div ~a:["class","left-column"] [
      a ~a:["href","toc.html"; "class","to-chapter"] [
        small [`Data "Back"];
        h5 [`Data "Table of Contents"];
      ]
    ];
    article ~a:["class","main-body"] content;
  ]
  in
  let content = Index.idx_to_indexterm content in
  main_template ~title_bar:title_bar ~next_chapter_footer ~content ()

let make_simple_page file =
  Html.of_file file >>= fun content ->
  let content = Html.[
    div ~a:["class","left-column"] [];
    article ~a:["class","main-body"] (
      get_body_childs ~filename:file content;
    )
  ]
  in
  return (main_template ~title_bar:title_bar ~content ())


(******************************************************************************)
(* Main Functions                                                             *)
(******************************************************************************)
type src = [
| `Chapter of string
| `Frontpage
| `Toc_page
| `FAQs
| `Install
]

let make ?pygmentize ?run_nondeterministic ?(repo_root=".") ?(code_dir="examples") ~out_dir = function
  | `Frontpage -> (
    let base = "index.html" in
    let out_file = out_dir/base in
    Log.Global.info "making %s" out_file;
    make_frontpage ~repo_root () >>= fun html ->
    return (Html.to_string html) >>= fun contents ->
    Writer.save out_file ~contents
  )
  | `Toc_page -> (
    let base = "toc.html" in
    let out_file = out_dir/base in
    Log.Global.info "making %s" out_file;
    make_toc_page ~repo_root () >>= fun html ->
    return (Html.to_string html) >>= fun contents ->
    Writer.save out_file ~contents
  )
  | `Chapter in_file -> (
    let base = Filename.basename in_file in
    let out_file = out_dir/base in
    Log.Global.info "making %s" out_file;
    Toc.get_chapters ~repo_root () >>= fun chapters ->
    make_chapter_page ~code_dir ?pygmentize ?run_nondeterministic
      repo_root chapters in_file >>= fun html ->
    return (Html.to_string html) >>= fun contents ->
    Writer.save out_file ~contents
  )
  | `FAQs -> (
    let base = "faqs.html" in
    let in_file = repo_root/"book"/base in
    let out_file = out_dir/base in
    Log.Global.info "making %s" out_file;
    make_simple_page in_file >>= fun html ->
    return (Html.to_string html) >>= fun contents ->
    Writer.save out_file ~contents
  )
  | `Install -> (
    let base = "install.html" in
    let in_file = repo_root/"book"/base in
    let out_file = out_dir/base in
    Log.Global.info "making %s" out_file;
    make_simple_page in_file >>= fun html ->
    return (Html.to_string html) >>= fun contents ->
    Writer.save out_file ~contents
  )
