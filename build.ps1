if ($IsLinux) {
    if (-Not (Get-Command clang++ -ErrorAction SilentlyContinue)) {
        throw "Error: ensure clang is installed"
    }
    if (-Not (Get-Command llvm-ar -ErrorAction SilentlyContinue)) {
        throw "Error: ensure llvm is installed"
    }

    $CC = "clang++"
    $EXEARGS = @()
    $LD = "ld"
    $TEST = "./a.out"
    $TESTARGS = @()
} else {
    if (-Not (Get-Command emcc -ErrorAction SilentlyContinue)) {
        if (-Not (Test-Path emsdk)) {
            Write-Host "Downloading Emscripten installer"
            git clone https://github.com/emscripten-core/emsdk.git
           ./emsdk/emsdk.ps1 install 2.0.19
           ./emsdk/emsdk.ps1 activate 2.0.19
        }
        ./emsdk/emsdk_env.ps1
    }
    if (-Not (Get-Command wasm-ld -ErrorAction SilentlyContinue)) {
        throw "Error: ensure llvm is on your path"
    }

    $CC = "emcc"
    $EXEARGS = @("-s", "EXIT_RUNTIME=1")
    $LD = "wasm-ld"
    $TEST = "node"
    $TESTARGS = @("./a.out.js")
}

& $CC ourproto.cpp -c -fvisibility=hidden
llvm-ar rcs ourproto.a ourproto.o

& $CC theirproto.cpp -c -fvisibility=hidden
llvm-ar rcs theirproto.a theirproto.o

& $CC csa.cpp -c -fvisibility=hidden
llvm-ar rcs csa.a csa.o

# Merging
@"
CREATE csa_merged.a
ADDLIB csa.a
ADDLIB ourproto.a
SAVE
END
"@ | llvm-ar -M

# Prelinking
& $CC csa.cpp -c -fvisibility=hidden
& $LD -r csa.o ourproto.a -o csa_prelink.o
Write-Host "`nFunction visibility in prelink"
llvm-nm csa_prelink.o | sls protobuf

# Symbol hiding
llvm-objcopy --localize-hidden csa_prelink.o csa_prelink_hidden.o
Write-Host "`nFunction visibility after localize-hidden"
# This should be a "t" indicating that the hidden protobuf function is not exported.  But it stays "T" in WASM.due to https://github.com/llvm/llvm-project/issues/50623
llvm-nm csa_prelink_hidden.o | sls protobuf

Write-Host "`nJust libs (us first)"
& $CC main.cpp csa.a ourproto.a theirproto.a @EXEARGS
if ($LASTEXITCODE -eq 0) { & $TEST @TESTARGS }

Write-Host "`nJust libs (them first)"
& $CC main.cpp csa.a theirproto.a ourproto.a @EXEARGS
if ($LASTEXITCODE -eq 0) { & $TEST @TESTARGS }

Write-Host "`nMerge (us first)"
& $CC main.cpp csa_merged.a theirproto.a @EXEARGS
if ($LASTEXITCODE -eq 0) { & $TEST @TESTARGS }

Write-Host "`nMerge (them first)"
& $CC main.cpp theirproto.a csa_merged.a @EXEARGS
if ($LASTEXITCODE -eq 0) { & $TEST @TESTARGS }

Write-Host "`nPrelink (us first)"
& $CC main.cpp csa_prelink.o theirproto.a @EXEARGS
if ($LASTEXITCODE -eq 0) { & $TEST @TESTARGS }

Write-Host "`nPrelink (them first)"
& $CC main.cpp theirproto.a csa_prelink.o @EXEARGS
if ($LASTEXITCODE -eq 0) { & $TEST @TESTARGS }

Write-Host "`nPrelink with hiding (us first)"
& $CC main.cpp csa_prelink_hidden.o theirproto.a @EXEARGS
if ($LASTEXITCODE -eq 0) { & $TEST @TESTARGS }

Write-Host "`nPrelink with hiding (them first)"
& $CC main.cpp theirproto.a csa_prelink_hidden.o @EXEARGS
if ($LASTEXITCODE -eq 0) { & $TEST @TESTARGS }
