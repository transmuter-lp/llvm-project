//--------------------------------------------------------------------------------------------------
// WHEN CREATING A NEW TEST, PLEASE JUST COPY & PASTE WITHOUT EDITS.
//
// Set-up that's shared across all tests in this directory. In principle, this
// config could be moved to lit.local.cfg. However, there are downstream users that
//  do not use these LIT config files. Hence why this is kept inline.
//
// DEFINE: %{sparsifier_opts} = enable-runtime-library=true
// DEFINE: %{sparsifier_opts_sve} = enable-arm-sve=true %{sparsifier_opts}
// DEFINE: %{compile} = mlir-opt %s --sparsifier="%{sparsifier_opts}"
// DEFINE: %{compile_sve} = mlir-opt %s --sparsifier="%{sparsifier_opts_sve}"
// DEFINE: %{run_libs} = -shared-libs=%mlir_c_runner_utils,%mlir_runner_utils
// DEFINE: %{run_libs_sve} = -shared-libs=%native_mlir_runner_utils,%native_mlir_c_runner_utils
// DEFINE: %{run_opts} = -e main -entry-point-result=void
// DEFINE: %{run} = mlir-runner %{run_opts} %{run_libs}
// DEFINE: %{run_sve} = %mcr_aarch64_cmd --march=aarch64 --mattr="+sve" %{run_opts} %{run_libs_sve}

// DEFINE: %{env} =
//--------------------------------------------------------------------------------------------------

// RUN: %{compile} | %{run} | FileCheck %s
//
// Do the same run, but now with direct IR generation.
// REDEFINE: %{sparsifier_opts} = enable-runtime-library=false enable-buffer-initialization=true
// RUN: %{compile} | %{run} | FileCheck %s
//
// Do the same run, but now with direct IR generation and vectorization.
// REDEFINE: %{sparsifier_opts} = enable-runtime-library=false enable-buffer-initialization=true vl=4 reassociate-fp-reductions=true enable-index-optimizations=true
// RUN: %{compile} | %{run} | FileCheck %s

#MAT_C_C = #sparse_tensor.encoding<{map = (d0, d1) -> (d0 : compressed, d1 : compressed)}>
#MAT_D_C = #sparse_tensor.encoding<{map = (d0, d1) -> (d0 : dense, d1 : compressed)}>
#MAT_C_D = #sparse_tensor.encoding<{map = (d0, d1) -> (d0 : compressed, d1 : dense)}>
#MAT_D_D = #sparse_tensor.encoding<{
  map = (d0, d1) -> (d1 : dense, d0 : dense)
}>

#MAT_C_C_P = #sparse_tensor.encoding<{
  map = (d0, d1) -> (d1 : compressed, d0 : compressed)
}>

#MAT_C_D_P = #sparse_tensor.encoding<{
  map = (d0, d1) -> (d1 : compressed, d0 : dense)
}>

#MAT_D_C_P = #sparse_tensor.encoding<{
  map = (d0, d1) -> (d1 : dense, d0 : compressed)
}>

module {
  func.func private @printMemrefF64(%ptr : tensor<*xf64>)
  func.func private @printMemref1dF64(%ptr : memref<?xf64>) attributes { llvm.emit_c_interface }

  //
  // Tests without permutation (concatenate on dimension 1)
  //

  // Concats all sparse matrices (with different encodings) to a sparse matrix.
  func.func @concat_sparse_sparse_dim1(%arg0: tensor<4x2xf64, #MAT_C_C>, %arg1: tensor<4x3xf64, #MAT_C_D>, %arg2: tensor<4x4xf64, #MAT_D_C>) -> tensor<4x9xf64, #MAT_C_C> {
    %0 = sparse_tensor.concatenate %arg0, %arg1, %arg2 {dimension = 1 : index}
         : tensor<4x2xf64, #MAT_C_C>, tensor<4x3xf64, #MAT_C_D>, tensor<4x4xf64, #MAT_D_C> to tensor<4x9xf64, #MAT_C_C>
    return %0 : tensor<4x9xf64, #MAT_C_C>
  }

  // Concats all sparse matrices (with different encodings) to a dense matrix.
  func.func @concat_sparse_dense_dim1(%arg0: tensor<4x2xf64, #MAT_C_C>, %arg1: tensor<4x3xf64, #MAT_C_D>, %arg2: tensor<4x4xf64, #MAT_D_C>) -> tensor<4x9xf64> {
    %0 = sparse_tensor.concatenate %arg0, %arg1, %arg2 {dimension = 1 : index}
         : tensor<4x2xf64, #MAT_C_C>, tensor<4x3xf64, #MAT_C_D>, tensor<4x4xf64, #MAT_D_C> to tensor<4x9xf64>
    return %0 : tensor<4x9xf64>
  }

  // Concats mix sparse and dense matrices to a sparse matrix.
  func.func @concat_mix_sparse_dim1(%arg0: tensor<4x2xf64>, %arg1: tensor<4x3xf64, #MAT_C_D>, %arg2: tensor<4x4xf64, #MAT_D_C>) -> tensor<4x9xf64, #MAT_C_C> {
    %0 = sparse_tensor.concatenate %arg0, %arg1, %arg2 {dimension = 1 : index}
         : tensor<4x2xf64>, tensor<4x3xf64, #MAT_C_D>, tensor<4x4xf64, #MAT_D_C> to tensor<4x9xf64, #MAT_C_C>
    return %0 : tensor<4x9xf64, #MAT_C_C>
  }

  // Concats mix sparse and dense matrices to a dense matrix.
  func.func @concat_mix_dense_dim1(%arg0: tensor<4x2xf64>, %arg1: tensor<4x3xf64, #MAT_C_D>, %arg2: tensor<4x4xf64, #MAT_D_C>) -> tensor<4x9xf64> {
    %0 = sparse_tensor.concatenate %arg0, %arg1, %arg2 {dimension = 1 : index}
         : tensor<4x2xf64>, tensor<4x3xf64, #MAT_C_D>, tensor<4x4xf64, #MAT_D_C> to tensor<4x9xf64>
    return %0 : tensor<4x9xf64>
  }

  func.func @dump_mat_dense_4x9(%A: tensor<4x9xf64>) {
    %1 = tensor.cast %A : tensor<4x9xf64> to tensor<*xf64>
    call @printMemrefF64(%1) : (tensor<*xf64>) -> ()

    return
  }

  // Driver method to call and verify kernels.
  func.func @main() {
    %m42 = arith.constant dense<
      [ [ 1.0, 0.0 ],
        [ 3.1, 0.0 ],
        [ 0.0, 2.0 ],
        [ 0.0, 0.0 ] ]> : tensor<4x2xf64>
    %m43 = arith.constant dense<
      [ [ 1.0, 0.0, 1.0 ],
        [ 1.0, 0.0, 0.5 ],
        [ 0.0, 0.0, 1.0 ],
        [ 5.0, 2.0, 0.0 ] ]> : tensor<4x3xf64>
    %m44 = arith.constant dense<
      [ [ 0.0, 0.0, 1.5, 1.0],
        [ 0.0, 3.5, 0.0, 0.0],
        [ 1.0, 5.0, 2.0, 0.0],
        [ 1.0, 0.5, 0.0, 0.0] ]> : tensor<4x4xf64>

    %sm42cc = sparse_tensor.convert %m42 : tensor<4x2xf64> to tensor<4x2xf64, #MAT_C_C>
    %sm43cd = sparse_tensor.convert %m43 : tensor<4x3xf64> to tensor<4x3xf64, #MAT_C_D>
    %sm44dc = sparse_tensor.convert %m44 : tensor<4x4xf64> to tensor<4x4xf64, #MAT_D_C>

    //
    // CHECK:      ---- Sparse Tensor ----
    // CHECK-NEXT: nse = 18
    // CHECK-NEXT: dim = ( 4, 9 )
    // CHECK-NEXT: lvl = ( 4, 9 )
    // CHECK-NEXT: pos[0] : ( 0, 4 )
    // CHECK-NEXT: crd[0] : ( 0, 1, 2, 3 )
    // CHECK-NEXT: pos[1] : ( 0, 5, 9, 14, 18 )
    // CHECK-NEXT: crd[1] : ( 0, 2, 4, 7, 8, 0, 2, 4, 6, 1, 4, 5, 6, 7, 2, 3, 5, 6 )
    // CHECK-NEXT: values : ( 1, 1, 1, 1.5, 1, 3.1, 1, 0.5, 3.5, 2, 1, 1, 5, 2, 5, 2, 1, 0.5 )
    // CHECK-NEXT: ----
    //
    %8 = call @concat_sparse_sparse_dim1(%sm42cc, %sm43cd, %sm44dc)
               : (tensor<4x2xf64, #MAT_C_C>, tensor<4x3xf64, #MAT_C_D>, tensor<4x4xf64, #MAT_D_C>) -> tensor<4x9xf64, #MAT_C_C>
    sparse_tensor.print %8 : tensor<4x9xf64, #MAT_C_C>

    // CHECK:      {{\[}}[1,   0,   1,   0,   1,   0,   0,   1.5,   1],
    // CHECK-NEXT:  [3.1,   0,   1,   0,   0.5,   0,   3.5,   0,   0],
    // CHECK-NEXT:  [0,   2,   0,   0,   1,   1,   5,   2,   0],
    // CHECK-NEXT:  [0,   0,   5,   2,   0,   1,   0.5,   0,   0]]
    %9 = call @concat_sparse_dense_dim1(%sm42cc, %sm43cd, %sm44dc)
               : (tensor<4x2xf64, #MAT_C_C>, tensor<4x3xf64, #MAT_C_D>, tensor<4x4xf64, #MAT_D_C>) -> tensor<4x9xf64>
    call @dump_mat_dense_4x9(%9) : (tensor<4x9xf64>) -> ()

    //
    // CHECK:      ---- Sparse Tensor ----
    // CHECK-NEXT: nse = 18
    // CHECK-NEXT: dim = ( 4, 9 )
    // CHECK-NEXT: lvl = ( 4, 9 )
    // CHECK-NEXT: pos[0] : ( 0, 4 )
    // CHECK-NEXT: crd[0] : ( 0, 1, 2, 3 )
    // CHECK-NEXT: pos[1] : ( 0, 5, 9, 14, 18 )
    // CHECK-NEXT: crd[1] : ( 0, 2, 4, 7, 8, 0, 2, 4, 6, 1, 4, 5, 6, 7, 2, 3, 5, 6 )
    // CHECK-NEXT: values : ( 1, 1, 1, 1.5, 1, 3.1, 1, 0.5, 3.5, 2, 1, 1, 5, 2, 5, 2, 1, 0.5 )
    // CHECK-NEXT: ----
    //
    %10 = call @concat_mix_sparse_dim1(%m42, %sm43cd, %sm44dc)
               : (tensor<4x2xf64>, tensor<4x3xf64, #MAT_C_D>, tensor<4x4xf64, #MAT_D_C>) -> tensor<4x9xf64, #MAT_C_C>
    sparse_tensor.print %10 : tensor<4x9xf64, #MAT_C_C>

    // CHECK:      {{\[}}[1,   0,   1,   0,   1,   0,   0,   1.5,   1],
    // CHECK-NEXT:  [3.1,   0,   1,   0,   0.5,   0,   3.5,   0,   0],
    // CHECK-NEXT:  [0,   2,   0,   0,   1,   1,   5,   2,   0],
    // CHECK-NEXT:  [0,   0,   5,   2,   0,   1,   0.5,   0,   0]]
    %11 = call @concat_mix_dense_dim1(%m42, %sm43cd, %sm44dc)
               : (tensor<4x2xf64>, tensor<4x3xf64, #MAT_C_D>, tensor<4x4xf64, #MAT_D_C>) -> tensor<4x9xf64>
    call @dump_mat_dense_4x9(%11) : (tensor<4x9xf64>) -> ()

    // Release resources.
    bufferization.dealloc_tensor %sm42cc  : tensor<4x2xf64, #MAT_C_C>
    bufferization.dealloc_tensor %sm43cd  : tensor<4x3xf64, #MAT_C_D>
    bufferization.dealloc_tensor %sm44dc  : tensor<4x4xf64, #MAT_D_C>

    bufferization.dealloc_tensor %8  : tensor<4x9xf64, #MAT_C_C>
    bufferization.dealloc_tensor %9  : tensor<4x9xf64>
    bufferization.dealloc_tensor %10 : tensor<4x9xf64, #MAT_C_C>
    bufferization.dealloc_tensor %11 : tensor<4x9xf64>
    return
  }
}
