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
    let dir = std::env::args().nth(1).expect("usage: decode_check <dir>");
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
        let name = entry.file_name().to_string_lossy().to_string();
        if nsv::decode(&orig) == path_to_seqseq(&name) {
            passed += 1;
        } else {
            fails.push(name);
        }
    }
    let total = entries.len();
    println!("  {passed}/{total} passed");
    for f in &fails { println!("  {f}"); }
    if !fails.is_empty() { process::exit(1); }
}
