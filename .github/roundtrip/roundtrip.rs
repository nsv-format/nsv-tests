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
    let (mode, dir) = if args.len() > 2 && (args[1] == "roundtrip" || args[1] == "decode-check") {
        (args[1].as_str(), &args[2])
    } else {
        ("roundtrip", &args[1])
    };

    let mut entries: Vec<_> = fs::read_dir(dir).unwrap()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_name().to_string_lossy().ends_with(".nsv"))
        .collect();
    entries.sort_by_key(|e| e.file_name());

    let mut passed = 0u32;
    let mut fails = Vec::new();

    for entry in &entries {
        let name = entry.file_name().to_string_lossy().to_string();
        let orig = fs::read_to_string(entry.path()).unwrap();
        let ok = match mode {
            "decode-check" => nsv::decode(&orig) == path_to_seqseq(&name),
            _ => nsv::encode(&nsv::decode(&orig)) == orig,
        };
        if ok { passed += 1; } else { fails.push(name); }
    }

    println!("  {passed}/{} passed", entries.len());
    for f in &fails { println!("  {f}"); }
    if !fails.is_empty() { process::exit(1); }
}
