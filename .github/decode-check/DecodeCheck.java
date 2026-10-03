package org.nsvformat;

import java.nio.file.*;
import java.util.*;

public class DecodeCheck {
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
        Path dir = Paths.get(args[0]);
        int passed = 0, failed = 0;
        List<String> fails = new ArrayList<>();
        List<Path> files = Files.list(dir)
            .filter(p -> p.toString().endsWith(".nsv"))
            .sorted()
            .toList();
        for (Path p : files) {
            String orig = Files.readString(p);
            if (Nsv.decode(orig).equals(pathToSeqseq(p.getFileName().toString()))) passed++;
            else { failed++; fails.add(p.getFileName().toString()); }
        }
        System.out.printf("  %d/%d passed%n", passed, passed + failed);
        for (String f : fails) System.out.println("  " + f);
        if (failed > 0) System.exit(1);
    }
}
