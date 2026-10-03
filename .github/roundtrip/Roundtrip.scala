package org.nsvformat

import java.nio.file.{Files, Paths}
import scala.collection.mutable.ArrayBuffer

object Roundtrip:
  def pathToSeqseq(name: String): Seq[Seq[String]] =
    val stem = if name.endsWith(".nsv") then name.dropRight(4) else name
    if stem.isEmpty then return Seq.empty
    var state = 0
    val rows = ArrayBuffer[Seq[String]]()
    var row = ArrayBuffer[String]()
    val cell = new StringBuilder
    val content = Map('a' -> 'a', 'b' -> '\\', 'n' -> '\n')
    for ch <- stem do
      state match
        case 0 => row = ArrayBuffer(); state = 1
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
    val (mode, dirIdx) =
      if args.length > 1 && (args(0) == "roundtrip" || args(0) == "decode-check") then (args(0), 1)
      else ("roundtrip", 0)
    val dir = Paths.get(args(dirIdx))
    val failures = ArrayBuffer[String]()
    var passed = 0

    Files.list(dir).filter(_.toString.endsWith(".nsv")).sorted.forEach { p =>
      val name = p.getFileName.toString
      val ok = mode match
        case "decode-check" =>
          val orig = Files.readString(p)
          Nsv.decode(orig) == pathToSeqseq(name)
        case _ =>
          val tempFile = Files.createTempFile("nsv-rt-", ".nsv")
          val reader = Reader.fromPath(p)
          val bw = new java.io.BufferedWriter(new java.io.FileWriter(tempFile.toFile))
          val writer = new Writer(bw)
          while reader.hasNext do writer.writeRow(reader.next())
          bw.close()
          val match_ = Files.mismatch(p, tempFile) == -1L
          Files.deleteIfExists(tempFile)
          match_

      if ok then passed += 1 else failures += name
    }

    val total = passed + failures.length
    println(s"  $passed/$total passed")
    failures.foreach(f => println(s"  $f"))
    if failures.nonEmpty then System.exit(1)
