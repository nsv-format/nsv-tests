package org.nsvformat;

import java.nio.file.*;
import java.util.*;

public class Coercion {
    public static void main(String[] args) throws Exception {
        String mode = args[0];
        Path indir = Paths.get(args[1]);
        Path outdir = Paths.get(args[2]);
        List<Path> files = Files.list(indir)
            .filter(p -> p.getFileName().toString().endsWith(".nsv"))
            .sorted()
            .toList();
        for (Path p : files) {
            Path out = outdir.resolve(p.getFileName().toString());
            if (mode.equals("batch")) {
                Files.writeString(out, Nsv.encode(Nsv.decode(Files.readString(p))));
            } else {
                try (java.io.Reader in = Files.newBufferedReader(p);
                     java.io.Writer w = Files.newBufferedWriter(out)) {
                    Reader reader = new Reader(in);
                    Writer writer = new Writer(w);
                    while (reader.hasNext()) writer.writeRow(reader.next());
                }
            }
        }
    }
}
