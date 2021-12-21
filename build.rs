fn main()
{
    println!("cargo:rustc-link-arg=-Tsrc/linker.ld");
    println!("cargo:rerun-if-changed=build.rs");
}
