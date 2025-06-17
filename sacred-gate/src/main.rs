fn main() {
    let r = ethereal_core::proto::GetUserByIdRequest {
        id: String::from("1")
    };
    println!("Hello, {r:#?}!");
    let r = ethereal_core::proto::GetUserProfileByIdRequest {
        id: String::from("1")
    };
    println!("Hello, {r:#?}!");
    println!("Hello, world!");
}
