use std::io::Write;
use std::{fs, io, path::Path};

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let (mode, indir, outdir) = (&args[1], &args[2], &args[3]);
    let mut entries: Vec<_> = fs::read_dir(indir).unwrap()
        .filter_map(|e| e.ok())
        .filter(|e| e.file_name().to_string_lossy().ends_with(".nsv"))
        .collect();
    entries.sort_by_key(|e| e.file_name());
    for entry in &entries {
        let out = Path::new(outdir).join(entry.file_name());
        if mode == "batch" {
            let orig = fs::read_to_string(entry.path()).unwrap();
            fs::write(out, nsv::encode(&nsv::decode(&orig))).unwrap();
        } else {
            let mut reader = nsv::Reader::new(fs::File::open(entry.path()).unwrap());
            let buf = io::BufWriter::new(fs::File::create(out).unwrap());
            let mut writer = nsv::Writer::new(buf);
            while let Some(row) = reader.next_row().unwrap() {
                writer.write_row(&row).unwrap();
            }
            writer.into_inner().flush().unwrap();
        }
    }
}
