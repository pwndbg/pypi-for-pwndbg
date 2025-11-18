{
  runCommand,
  zig,
  llvm,
}:
# A workaround for ppc64 bug:
# https://github.com/ziglang/zig/issues/22081
runCommand "libclang_rt_ppc_builtins"
  {
    nativeBuildInputs = [
      zig
    ];
  }
  ''
    export ZIG_GLOBAL_CACHE_DIR=$TMPDIR
    mkdir preprocessed lib obj

    DIR=${llvm.monorepoSrc}/compiler-rt/lib/builtins/ppc/

    for f in $DIR/gcc_*.c; do
      base=$(basename "$f" .c)
      echo "Preprocessing $base..."
      zig cc -target powerpc64le-linux-gnu -E "$f" > "preprocessed/$base.c"
    done

    for f in preprocessed/*.c; do
      base=$(basename "$f" .c)
      echo "Compiling $f -> obj/$base.o"
      zig cc -target powerpc64le-linux-gnu -c "$f" -o "obj/$base.o" -fPIC -fno-sanitize=all
    done

    zig ar rcs lib/libclang_rt_ppc_builtins.a obj/*.o

    mkdir $out
    mv lib $out/
  ''
