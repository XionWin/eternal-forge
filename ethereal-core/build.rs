fn main() -> Result<(), Box<dyn std::error::Error>> {
    tonic_build::configure()
        .out_dir("src/proto")
        .file_descriptor_set_path("proto/service_descriptor.bin")
        .compile_protos(&["user.proto"], &["proto/"])
        .expect("Failed to compile protos");
    Ok(())
}
