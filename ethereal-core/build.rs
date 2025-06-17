fn main() -> Result<(), Box<dyn std::error::Error>> {
    tonic_build::configure()
        .out_dir("src/proto")
        .compile_protos(&["user.proto", "user_profile.proto"], &["proto/"])
        .expect("Failed to compile protos");
    Ok(())
}
