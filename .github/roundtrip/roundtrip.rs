use std::{fs, process};

fn path_to_seqseq(name: &str) -> Vec<Vec<String>> {
    let stem = name.strip_suffix(".nsv").unwrap_or(name);
    if stem.is_empty() { return vec![]; }
    let mut state = 0u8;
    let mut rows: Vec<Vec<String>> = vec![];
    let mut row: Vec<String> = vec![];
    let mut cell = String::new();
    for ch in stem.chars() {
        match (state, ch) {
            (0, _) => { row = vec![]; state = 1; }
            (1, '0') => { rows.push(std::mem::take(&mut row)); state = 0; }
            (1, '1') => { row.push(String::new()); }
            (1, '2') => { cell.clear(); state = 2; }
            (2 | 3, 'a') => { cell.push('a'); state = 3; }
            (2 | 3, 'b') => { cell.push('\\'); state = 3; }
            (2 | 3, 'n') => { cell.push('\n'); state = 3; }
            (3, '1') => { row.push(std::mem::take(&mut cell)); state = 1; }
            _ => {}
        }
    }
    if state == 1 { rows.push(row); }
    rows
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let (mode, dir_idx) = if args.len() > 2 && args[1] == "decode-check" {
        ("decode-check", 2)
    } else {
        ("roundtrip", 1)
    };
    let dir = &args[dir_idx];
    let mut entries: Vec<_> = fs::read_dir(dir).unwrap()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_name().to_string_lossy().ends_with(".nsv"))
        .collect();
    entries.sort_by_key(|e| e.file_name());
    let mut passed = 0u32;
    let mut fails = Vec::new();
    for entry in &entries {
        let path = entry.path();
        let orig = fs::read_to_string(&path).unwrap();
        let name = entry.file_name().to_string_lossy().to_string();
        let ok = if mode == "decode-check" {
            nsv::decode(&orig) == path_to_seqseq(&name)
        } else {
            nsv::encode(&nsv::decode(&orig)) == orig
        };
        if ok { passed += 1; } else { fails.push(name); }
    }
    let total = entries.len();
    println!("  {passed}/{total} passed");
    for f in &fails { println!("  {f}"); }
    if !fails.is_empty() { process::exit(1); }
}
