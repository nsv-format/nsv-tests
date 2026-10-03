package org.nsvformat

import java.nio.file.{Files, Paths}

object Roundtrip:
  def pathToSeqseq(name: String): Seq[Seq[String]] =
    val stem = if name.endsWith(".nsv") then name.dropRight(4) else name
    if stem.isEmpty then return Seq.empty
    var state = 0
    val rows = collection.mutable.ArrayBuffer[Seq[String]]()
    var row = collection.mutable.ArrayBuffer[String]()
    val cell = new StringBuilder
    val content = Map('a' -> 'a', 'b' -> '\\', 'n' -> '\n')
    for ch <- stem do
      state match
        case 0 => row = collection.mutable.ArrayBuffer(); state = 1
        case 1 => ch match
          case '0' => rows += row.toSeq; state = 0
          case '1' => row += ""
          case '2' => cell.clear(); state = 2
          case _ =>
        case 2 => cell += content(ch); state = 3
        case 3 => if ch == '1' then { row += cell.toString; cell.clear(); state = 1 }
                  else cell += content(ch)
        case _ =>
    if state == 1 then rows += row.toSeq
    rows.toSeq

  def main(args: Array[String]): Unit =
    val mode = if args.length > 1 && args(0) == "decode-check" then "decode-check" else null
    val dir = Paths.get(if mode != null then args(1) else args(0))
    val failures = collection.mutable.ArrayBuffer[String]()

    Files.list(dir).filter(_.toString.endsWith(".nsv")).sorted.forEach { p =>
      if mode == "decode-check" then
        val orig = Files.readString(p)
        if Nsv.decode(orig) != pathToSeqseq(p.getFileName.toString) then
          failures += p.getFileName.toString
      else
        val tempFile = Files.createTempFile("nsv-rt-", ".nsv")
        val reader = Reader.fromPath(p)
        val bw = new java.io.BufferedWriter(new java.io.FileWriter(tempFile.toFile))
        val writer = new Writer(bw)

        while reader.hasNext do writer.writeRow(reader.next())

        bw.close()
        if (Files.mismatch(p, tempFile) != -1L) { failures += p.getFileName.toString }
        Files.deleteIfExists(tempFile)
    }

    if (failures.nonEmpty) {
      println(s"  ${failures.length} failed")
      failures.foreach(f => println(s"  $f"))
      System.exit(1)
    }
