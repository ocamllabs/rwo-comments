(alias
 (name   runtest)
 (deps   (:x README.md)
         (:y1 ../../examples/code/guided-tour/recursion.ml)
         (:y0 ../../examples/code/guided-tour/sum/sum.ml)
         ../prelude.ml
         (package mdx))
 (action (progn
           (run mdx test --prelude=../prelude.ml --direction=infer-timestamp %{x})
           (diff? %{x} %{x}.corrected)
           (diff? %{y1} %{y1}.corrected)
           (diff? %{y0} %{y0}.corrected))))