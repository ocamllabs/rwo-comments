(alias
 (name   runtest)
 (deps   (:x README.md)
         (:y8 ../../examples/code/error-handling/blow_up/blow_up.ml)
         (:y7 ../../examples/code/error-handling/blow_up/dune)
         (:y6 ../../examples/code/error-handling/blow_up/dune-project)
         (:y5 ../../examples/code/error-handling/blow_up/dune-workspace)
         (:y4 ../../examples/code/error-handling/exn_cost/dune)
         (:y3 ../../examples/code/error-handling/exn_cost/dune-project)
         (:y2 ../../examples/code/error-handling/exn_cost/dune-workspace)
         (:y1 ../../examples/code/error-handling/exn_cost/exn_cost.ml)
         (:y0 ../../examples/code/error-handling/result.mli)
         prelude.ml
         (package mdx))
 (action (progn
           (run mdx test --prelude=prelude.ml --direction=to-ml %{x})
           (diff? %{x} %{x}.corrected)
           (diff? %{y8} %{y8}.corrected)
           (diff? %{y7} %{y7}.corrected)
           (diff? %{y6} %{y6}.corrected)
           (diff? %{y5} %{y5}.corrected)
           (diff? %{y4} %{y4}.corrected)
           (diff? %{y3} %{y3}.corrected)
           (diff? %{y2} %{y2}.corrected)
           (diff? %{y1} %{y1}.corrected)
           (diff? %{y0} %{y0}.corrected))))
(alias
 (name   runtest-all)
 (deps   (:x README.md)
         (:y8 ../../examples/code/error-handling/blow_up/blow_up.ml)
         (:y7 ../../examples/code/error-handling/blow_up/dune)
         (:y6 ../../examples/code/error-handling/blow_up/dune-project)
         (:y5 ../../examples/code/error-handling/blow_up/dune-workspace)
         (:y4 ../../examples/code/error-handling/exn_cost/dune)
         (:y3 ../../examples/code/error-handling/exn_cost/dune-project)
         (:y2 ../../examples/code/error-handling/exn_cost/dune-workspace)
         (:y1 ../../examples/code/error-handling/exn_cost/exn_cost.ml)
         (:y0 ../../examples/code/error-handling/result.mli)
         prelude.ml
         (package mdx))
 (action (progn
           (run mdx test --prelude=prelude.ml --direction=to-ml --non-deterministic %{x})
           (diff? %{x} %{x}.corrected)
           (diff? %{y8} %{y8}.corrected)
           (diff? %{y7} %{y7}.corrected)
           (diff? %{y6} %{y6}.corrected)
           (diff? %{y5} %{y5}.corrected)
           (diff? %{y4} %{y4}.corrected)
           (diff? %{y3} %{y3}.corrected)
           (diff? %{y2} %{y2}.corrected)
           (diff? %{y1} %{y1}.corrected)
           (diff? %{y0} %{y0}.corrected))))