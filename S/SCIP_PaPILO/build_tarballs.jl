# Note that this script can accept some limited command-line arguments, run
# `julia build_tarballs.jl --help` to see a usage message.
using BinaryBuilder, Pkg

name = "SCIP_PaPILO"

version = v"800.0.301"

sources = [
    ArchiveSource("https://scipopt.org/download/release/scipoptsuite-8.0.3.tgz", "5ad50eb42254c825d96f5747d8f3568dcbff0284dfbd1a727910c5a7c2899091"),
    DirectorySource("./bundled"),
]

# Bash recipe for building across all platforms
script = raw"""
cd scipoptsuite*

atomic_patch -p1 ${WORKSPACE}/srcdir/patches/findbliss.patch

mkdir build
cd build/
cmake -DCMAKE_INSTALL_PREFIX=$prefix\
  -DCMAKE_TOOLCHAIN_FILE=${CMAKE_TARGET_TOOLCHAIN}\
  -DCMAKE_BUILD_TYPE=Release\
  -DZIMPL=OFF\
  -DUG=0\
  -DAMPL=0\
  -DGCG=0\
  -DBOOST=ON\
  -DSYM=bliss\
  -DTPI=tny\
  -DIPOPT_DIR=${prefix} \
  -DIPOPT_LIBRARIES=${libdir} \
  -DBLISS_INCLUDE_DIR=${includedir} \
  -DBLISS_LIBRARY=bliss \
  ..
make -j${nproc} scip
make papilo-executable

make install
cp bin/papilo "${bindir}/papilo${exeext}"

mkdir -p ${prefix}/share/licenses/SCIP_PaPILO
for dir in scip soplex gcg; do
    cp $WORKSPACE/srcdir/scipoptsuite*/${dir}/LICENSE ${prefix}/share/licenses/SCIP_PaPILO/LICENSE_${dir}
done
cp $WORKSPACE/srcdir/scipoptsuite*/papilo/COPYING ${prefix}/share/licenses/SCIP_PaPILO/LICENSE_papilo
"""

# These are the platforms we will build for by default, unless further
# platforms are passed in on the command line
platforms = expand_gfortran_versions(expand_cxxstring_abis(supported_platforms(; experimental=true)))

filter!(platforms) do p
    arch(p) ∉ ("armv6l", "armv7l") && !Sys.iswindows(p) && libgfortran_version(p) >= v"4" && libc(p) != "musl"
end

# The products that we will ensure are always built
products = [
    ExecutableProduct("papilo", :papilo),
    ExecutableProduct("scip", :scip),
    LibraryProduct("libscip", :libscip),
]

dependencies = [
    Dependency(PackageSpec(name="bliss_jll", uuid="508c9074-7a14-5c94-9582-3d4bc1871065"), compat="=0.77.0"),
    Dependency(PackageSpec(name="boost_jll", uuid="28df3c45-c428-5900-9ff8-a3135698ca75"); compat="=1.76.0"),
    Dependency(PackageSpec(name="Bzip2_jll", uuid="6e34b625-4abd-537c-b88f-471c36dfa7a0"); compat="1.0.8"),
    Dependency(PackageSpec(name="CompilerSupportLibraries_jll", uuid="e66e0078-7015-5450-92f7-15fbd957f2ae")),
    Dependency(PackageSpec(name="GMP_jll", uuid="781609d7-10c4-51f6-84f2-b8444358ff6d"); compat="6.2.0"),
    Dependency(PackageSpec(name="Ipopt_jll", uuid="9cc047cb-c261-5740-88fc-0cf96f7bdcc7"); compat="=300.1400.400"),
    Dependency(PackageSpec(name="OpenBLAS32_jll", uuid="656ef2d0-ae68-5445-9ca0-591084a874a2"); compat="0.3.10"),
    Dependency(PackageSpec(name="oneTBB_jll", uuid="1317d2d5-d96f-522e-a858-c73665f53c3e"); compat="2021.4.1"),
    Dependency(PackageSpec(name="Readline_jll", uuid="05236dd9-4125-5232-aa7c-9ec0c9b2c25a")),
    Dependency(PackageSpec(name="Zlib_jll", uuid="83775a58-1f1d-513f-b197-d71354ab007a")),
]

# Build the tarballs, and possibly a `build.jl` as well.
build_tarballs(
    ARGS,
    name,
    version,
    sources,
    script,
    platforms,
    products,
    dependencies;
    preferred_gcc_version=v"7",
    julia_compat="1.6",
)
