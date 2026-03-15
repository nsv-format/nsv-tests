use std::{fs, process};

fn main() {
    let dir = std::env::args().nth(1).expect("usage: roundtrip <dir>");
    let mut entries: Vec<_> = fs::read_dir(&dir).unwrap()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_name().to_string_lossy().ends_with(".nsv"))
        .collect();
    entries.sort_by_key(|e| e.file_name());
    let mut passed = 0u32;
    let mut fails = Vec::new();
    for entry in &entries {
        let path = entry.path();
        let orig = fs::read_to_string(&path).unwrap();
        if nsv::encode(&nsv::decode(&orig)) == orig {
            passed += 1;
        } else {
            fails.push(entry.file_name().to_string_lossy().to_string());
        }
    }
    let total = entries.len();
    println!("  {passed}/{total} passed");
    for f in &fails { println!("  {f}"); }
    if !fails.is_empty() { process::exit(1); }
}
