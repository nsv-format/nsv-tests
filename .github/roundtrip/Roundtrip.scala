package org.nsvformat

import java.nio.file.{Files, Paths}

object Roundtrip:
  def main(args: Array[String]): Unit =
    val dir = Paths.get(args(0))
    var passed = 0; var failed = 0
    val fails = collection.mutable.ArrayBuffer[String]()
    Files.list(dir).sorted.forEach: p =>
      if p.toString.endsWith(".nsv") then
        val tmp = Files.createTempFile("nsv-rt-", ".nsv")
        try
          val reader = Reader.fromPath(p)
          val bw = new java.io.BufferedWriter(new java.io.FileWriter(tmp.toFile))
          val writer = new Writer(bw)
          while reader.hasNext do writer.writeRow(reader.next())
          bw.close()
          if Files.mismatch(p, tmp) == -1L then passed += 1
          else { failed += 1; fails += p.getFileName.toString }
        finally Files.deleteIfExists(tmp)
    println(s"  $passed/${passed + failed} passed")
    fails.foreach(f => println(s"  $f"))
    if failed > 0 then System.exit(1)
