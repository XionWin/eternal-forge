fn main() -> Result<(), Box<dyn std::error::Error>> {
    tonic_build::configure()
        .file_descriptor_set_path("proto/my_service_descriptor.bin")
        .out_dir("src/proto")
        .compile_protos(&["user.proto", "user_profile.proto"], &["proto/"])
        .expect("Failed to compile protos");
    Ok(())
}
