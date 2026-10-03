package org.nsvformat

import java.nio.file.{Files, Paths}

object Roundtrip:
  def main(args: Array[String]): Unit =
    val dir = Paths.get(args(0))
    val failures = collection.mutable.ArrayBuffer[String]()

    Files.list(dir).filter(_.toString.endsWith(".nsv")).sorted.forEach { p =>
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
