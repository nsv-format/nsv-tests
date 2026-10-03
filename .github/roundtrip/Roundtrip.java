package org.nsvformat;

import java.nio.file.*;
import java.util.*;

public class Roundtrip {
    public static void main(String[] args) throws Exception {
        Path dir = Paths.get(args[0]);
        int passed = 0, failed = 0;
        List<String> fails = new ArrayList<>();
        List<Path> files = Files.list(dir)
            .filter(p -> p.toString().endsWith(".nsv"))
            .sorted()
            .toList();
        for (Path p : files) {
            String orig = Files.readString(p);
            if (Nsv.encode(Nsv.decode(orig)).equals(orig)) passed++;
            else { failed++; fails.add(p.getFileName().toString()); }
        }
        System.out.printf("  %d/%d passed%n", passed, passed + failed);
        for (String f : fails) System.out.println("  " + f);
        if (failed > 0) System.exit(1);
    }
}
