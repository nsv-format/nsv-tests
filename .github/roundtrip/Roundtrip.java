package org.nsvformat;

import java.nio.file.*;
import java.util.*;

public class Roundtrip {
    static List<List<String>> pathToSeqseq(String name) {
        String stem = name.endsWith(".nsv") ? name.substring(0, name.length() - 4) : name;
        if (stem.isEmpty()) return Collections.emptyList();
        int state = 0;
        List<List<String>> rows = new ArrayList<>();
        List<String> row = new ArrayList<>();
        StringBuilder cell = new StringBuilder();
        for (int i = 0; i < stem.length(); i++) {
            char ch = stem.charAt(i);
            switch (state) {
                case 0:
                    row = new ArrayList<>();
                    state = 1;
                    break;
                case 1:
                    if (ch == '0') { rows.add(row); state = 0; }
                    else if (ch == '1') { row.add(""); }
                    else if (ch == '2') { cell.setLength(0); state = 2; }
                    break;
                case 2:
                    if (ch == 'a') cell.append('a');
                    else if (ch == 'b') cell.append('\\');
                    else if (ch == 'n') cell.append('\n');
                    state = 3;
                    break;
                case 3:
                    if (ch == '1') { row.add(cell.toString()); cell.setLength(0); state = 1; }
                    else if (ch == 'a') cell.append('a');
                    else if (ch == 'b') cell.append('\\');
                    else if (ch == 'n') cell.append('\n');
                    break;
            }
        }
        if (state == 1) rows.add(row);
        return rows;
    }

    public static void main(String[] args) throws Exception {
        String mode = "roundtrip";
        int dirIdx = 0;
        if (args.length > 1 && (args[0].equals("roundtrip") || args[0].equals("decode-check"))) {
            mode = args[0]; dirIdx = 1;
        }
        Path dir = Paths.get(args[dirIdx]);
        int passed = 0, failed = 0;
        List<String> fails = new ArrayList<>();
        List<Path> files = Files.list(dir)
            .filter(p -> p.toString().endsWith(".nsv"))
            .sorted()
            .toList();
        for (Path p : files) {
            String name = p.getFileName().toString();
            String orig = Files.readString(p);
            boolean ok;
            if (mode.equals("decode-check"))
                ok = Nsv.decode(orig).equals(pathToSeqseq(name));
            else
                ok = Nsv.encode(Nsv.decode(orig)).equals(orig);
            if (ok) passed++;
            else { failed++; fails.add(name); }
        }
        System.out.printf("  %d/%d passed%n", passed, passed + failed);
        for (String f : fails) System.out.println("  " + f);
        if (failed > 0) System.exit(1);
    }
}
